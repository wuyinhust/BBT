import PhotosUI
import SwiftUI
import UIKit

struct FeedingSheet: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(BabyProfileStore.self) private var profileStore
    @EnvironmentObject private var feedingStore: FeedingStore
    @EnvironmentObject private var draftStore: FeedingDraftStore
    @Binding var isPresented: Bool

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showManualBreastInput = false
    @State private var showCustomBottleAmount = false
    @State private var showMoreInfo = false
    @State private var selectedKind: FeedingKind = .bottle
    @State private var manualLeftMinutes = 0.0
    @State private var manualRightMinutes = 0.0
    @State private var customBottleAmountText = ""
    @State private var showRecordTimePicker = false
    @State private var showBottleMilkTypePicker = false
    @State private var showSolidFoodPicker = false
    @State private var pendingBreastPresetMinutes: Int?
    @State private var showBreastPresetOverwriteConfirmation = false
    @State private var showManualBreastOverwriteConfirmation = false
    @State private var showTimeSpanConfirmation = false
    @State private var pendingSave: PendingFeedingSave?
    @State private var timeSpanStart = Date()
    @State private var timeSpanEnd = Date()
    @State private var hasManualTimeSpan = false
    @State private var manualTimeSpanStart = Date()
    @State private var manualTimeSpanEnd = Date()
    @State private var recordTime = Date()
    @State private var layoutHeight: CGFloat = 800

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let bottleRange: ClosedRange<Double> = 0...260
    private var isCompactHeight: Bool {
        layoutHeight < 760
    }

    private var type: FeedingType {
        get { draftStore.type }
        nonmutating set { draftStore.type = newValue }
    }
    private var mood: BabyMood {
        get { draftStore.mood }
        nonmutating set { draftStore.mood = newValue }
    }
    private var entries: [FeedingEntry] {
        get { draftStore.entries }
        nonmutating set { draftStore.entries = newValue }
    }
    private var note: String {
        get { draftStore.note }
        nonmutating set { draftStore.note = newValue }
    }
    private var noteBinding: Binding<String> { binding(\.note) }
    private var imageData: Data? {
        get { draftStore.imageData }
        nonmutating set { draftStore.imageData = newValue }
    }
    private var currentTime: Date {
        get { draftStore.currentTime }
        nonmutating set { draftStore.currentTime = newValue }
    }
    private var didSave: Bool {
        get { draftStore.didSave }
        nonmutating set { draftStore.didSave = newValue }
    }
    private var breastMode: BreastFeedingMode {
        get { draftStore.breastMode }
        nonmutating set { draftStore.breastMode = newValue }
    }
    private var leftBaseSeconds: Int {
        get { draftStore.leftBaseSeconds }
        nonmutating set { draftStore.leftBaseSeconds = newValue }
    }
    private var rightBaseSeconds: Int {
        get { draftStore.rightBaseSeconds }
        nonmutating set { draftStore.rightBaseSeconds = newValue }
    }
    private var activeBreastSide: BreastSide? {
        get { draftStore.activeBreastSide }
        nonmutating set { draftStore.activeBreastSide = newValue }
    }
    private var activeBreastStartAt: Date? {
        get { draftStore.activeBreastStartAt }
        nonmutating set { draftStore.activeBreastStartAt = newValue }
    }
    private var hitMilestones: Set<Int> {
        get { draftStore.hitMilestones }
        nonmutating set { draftStore.hitMilestones = newValue }
    }
    private var milkType: MilkType {
        get { draftStore.milkType }
        nonmutating set { draftStore.milkType = newValue }
    }
    private var milkTypeBinding: Binding<MilkType> { binding(\.milkType) }
    private var bottleAmount: Double {
        get { draftStore.bottleAmount }
        nonmutating set { draftStore.bottleAmount = newValue }
    }
    private var bottleAmountBinding: Binding<Double> { binding(\.bottleAmount) }
    private var bottleMinutes: Double {
        get { draftStore.bottleMinutes }
        nonmutating set { draftStore.bottleMinutes = newValue }
    }
    private var bottleTimerStartedAt: Date? {
        get { draftStore.bottleTimerStartedAt }
        nonmutating set { draftStore.bottleTimerStartedAt = newValue }
    }
    private var solidFood: SolidFood {
        get { draftStore.solidFood }
        nonmutating set { draftStore.solidFood = newValue }
    }
    private var selectedSolidFoods: [SolidFood] {
        get {
            normalizedSolidFoods(draftStore.solidFoods.isEmpty ? [solidFood] : draftStore.solidFoods)
        }
        nonmutating set {
            let foods = normalizedSolidFoods(newValue)
            draftStore.solidFoods = foods
            solidFood = foods.first ?? .rice
            if foods.count == 1, let food = foods.first {
                solidUnit = food.suggestedUnit
            }
        }
    }
    private var solidAmount: Double {
        get { draftStore.solidAmount }
        nonmutating set { draftStore.solidAmount = newValue }
    }
    private var solidAmountBinding: Binding<Double> { binding(\.solidAmount) }
    private var solidUnit: SolidUnit {
        get { draftStore.solidUnit }
        nonmutating set { draftStore.solidUnit = newValue }
    }
    private var solidUnitBinding: Binding<SolidUnit> { binding(\.solidUnit) }

    private func binding<Value>(_ keyPath: ReferenceWritableKeyPath<FeedingDraftStore, Value>) -> Binding<Value> {
        Binding {
            draftStore[keyPath: keyPath]
        } set: { value in
            draftStore[keyPath: keyPath] = value
            draftStore.persistDraft()
        }
    }

    var body: some View {
        feedingGlassRenderedLayout
        .ignoresSafeArea(.keyboard)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.height
        } action: { height in
            layoutHeight = height
        }
        .presentationDragIndicator(.visible)
        .onReceive(timer) { date in
            draftStore.updateCurrentTime(date)
            checkBreastMilestones()
            persistDraftIfNeeded()
        }
        .onAppear {
            restoreDraft()
            selectedKind = FeedingKind.kindFor(type: type, solidFood: solidFood)
            draftStore.didSave = false
            draftStore.updateCurrentTime(Date())
            recordTime = Date()
        }
        .onDisappear {
            if !didSave {
                persistDraft()
            }
        }
        .onChange(of: selectedPhoto) {
            Task { await loadSelectedPhoto() }
        }
        .onChange(of: scenePhase) { persistDraft() }
        .onChange(of: showMoreInfo) { _, isShown in
            if isShown {
                prepareManualTimeSpanDefaults(force: false)
            }
        }
        .sheet(isPresented: $showManualBreastInput) {
            manualBreastInputSheet
        }
        .sheet(isPresented: $showCustomBottleAmount) {
            customBottleAmountSheet
        }
        .sheet(isPresented: $showSolidFoodPicker) {
            solidFoodPickerSheet
                .presentationDetents([.height(isCompactHeight ? 430 : 500)])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
                .presentationCornerRadius(34)
        }
        .sheet(isPresented: $showTimeSpanConfirmation) {
            timeSpanConfirmationSheet
                .presentationDetents([.height(390)])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
                .presentationCornerRadius(34)
        }
        .alert("覆盖当前亲喂时间？", isPresented: $showBreastPresetOverwriteConfirmation) {
            Button("取消", role: .cancel) {
                pendingBreastPresetMinutes = nil
            }
            Button("覆盖", role: .destructive) {
                if let pendingBreastPresetMinutes {
                    applyBreastPreset(minutes: pendingBreastPresetMinutes)
                }
                pendingBreastPresetMinutes = nil
            }
        } message: {
            Text("当前已有左右胸计时记录，使用快捷操作会替换为预设时间。")
        }
    }

    private var topSummary: some View {
        VStack(spacing: 6) {
            Text(primarySummary)
                .font(BBBFont.font(size: isCompactHeight ? 34 : 40, weight: .heavy))
                .foregroundStyle(selectedKind.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(secondarySummary)
                .font(BBBFont.font(size: isCompactHeight ? 13 : 15, weight: .bold))
                .foregroundStyle(DesignToken.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .frame(maxWidth: .infinity)
    }

    private var feedingGlassRenderedLayout: some View {
        RecordGlassRecorderShell(
            title: "记录喂养",
            stats: feedingTopStats,
            showMore: $showMoreInfo,
            moreHeight: 500,
            saveTitle: "保存",
            isSaveEnabled: canSave,
            onClose: {
                persistDraft()
                isPresented = false
            },
            onSave: save
        ) { metrics in
            feedingGlassStage(metrics)
        } primaryControls: { metrics in
            feedingGlassPrimaryControls(metrics)
        } modeControls: { metrics in
            bottleModeSelector(W: metrics.W, S: metrics.S)
        } leadingDock: { metrics in
            feedingGlassDockLeading(metrics)
        } moreContent: {
            moreInfoPopover
        }
        .sheet(isPresented: $showRecordTimePicker) {
            recordTimePickerSheet
                .presentationDetents([.height(320)])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
                .presentationCornerRadius(34)
        }
        .confirmationDialog("选择奶源", isPresented: $showBottleMilkTypePicker, titleVisibility: .visible) {
            ForEach(MilkType.allCases) { item in
                Button(item.displayName) {
                    setBottleMilkType(item)
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("当前：\(milkType.displayName)")
        }
    }

    @ViewBuilder
    private func feedingGlassStage(_ metrics: RecordGlassRecorderMetrics) -> some View {
        Group {
            switch selectedKind {
            case .nursing:
                nursingGlassStage(metrics)
            case .bottle:
                bottleGlassStage(metrics)
            default:
                solidsGlassStage(metrics)
            }
        }
        .id("stage-\(selectedKind.id)")
        .transition(feedingKindTransition)
    }

    @ViewBuilder
    private func feedingGlassPrimaryControls(_ metrics: RecordGlassRecorderMetrics) -> some View {
        Group {
            if selectedKind == .bottle {
                bottleGlassAmountControls(metrics)
            } else if selectedKind == .nursing {
                nursingGlassTimerControls(metrics)
            } else {
                solidsGlassAmountControls(metrics)
            }
        }
        .id("primary-\(selectedKind.id)")
        .transition(feedingKindTransition)
    }

    @ViewBuilder
    private func feedingGlassDockLeading(_ metrics: RecordGlassRecorderMetrics) -> some View {
        Group {
            if selectedKind == .bottle {
                bottleDoseCapsule(W: metrics.W, S: metrics.S)
                    .frame(width: metrics.W * 0.43, height: 56 * metrics.S)
            } else if selectedKind == .nursing {
                nursingPresetCapsule(W: metrics.W, S: metrics.S)
                    .frame(width: metrics.W * 0.43, height: 56 * metrics.S)
            } else {
                solidsDoseCapsule(W: metrics.W, S: metrics.S)
                    .frame(width: metrics.W * 0.43, height: 56 * metrics.S)
            }
        }
        .id("dock-\(selectedKind.id)")
        .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .center)))
    }

    private var feedingKindTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.965, anchor: .center)).combined(with: .offset(y: 10)),
            removal: .opacity.combined(with: .scale(scale: 1.015, anchor: .center)).combined(with: .offset(y: -8))
        )
    }

    private func nursingGlassStage(_ metrics: RecordGlassRecorderMetrics) -> some View {
        let S = metrics.S
        let stageHeight = min(max(metrics.stageHeight, 370 * S), 440 * S)
        let arcHeight = min(286 * S, stageHeight * 0.78)
        let heroHeight = min(268 * S, stageHeight * 0.72)
        let bottleLayout = bottleGlassLayout(metrics)
        let centerY = stageHeight * 0.5 + (bottleLayout.bottleY - metrics.stageY)
        let sideButtonY = centerY + 18 * S
        let arcInset = 106 * S
        let arcWidth = 92 * S

        return ZStack {
            BreastMinuteArcScale(
                side: .left,
                seconds: leftSeconds,
                accent: DesignToken.feedingBreast,
                S: S
            ) { minutes in
                setBreastMinutes(.left, minutes: minutes)
            }
            .frame(width: arcWidth, height: arcHeight)
            .position(x: arcInset, y: centerY)

            BreastMinuteArcScale(
                side: .right,
                seconds: rightSeconds,
                accent: DesignToken.feedingBottle,
                S: S
            ) { minutes in
                setBreastMinutes(.right, minutes: minutes)
            }
            .frame(width: arcWidth, height: arcHeight)
            .position(x: metrics.W - arcInset, y: centerY)

            nursingHeroArt(S: S)
                .frame(width: metrics.W * 0.60, height: heroHeight)
                .position(x: metrics.W * 0.5, y: centerY)

            bottleSideIconButton(systemIcon: "square.and.pencil", S: S) {
                openManualInput()
            }
            .position(x: 44 * S, y: sideButtonY)
            .zIndex(20)

            bottleSideIconButton(systemIcon: "clock", S: S) {
                showRecordTimePicker = true
            }
            .position(x: metrics.W - 44 * S, y: sideButtonY)
            .zIndex(20)
        }
        .frame(width: metrics.W, height: stageHeight)
    }

    @ViewBuilder
    private func nursingHeroArt(S: CGFloat) -> some View {
        if UIImage(named: "record_nursing_hero") != nil {
            Image("record_nursing_hero")
                .resizable()
                .scaledToFit()
                .opacity(0.68)
        } else {
            Text("🤱")
                .font(.system(size: 168 * S))
                .opacity(0.68)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.12))
                        .blur(radius: 22 * S)
                )
        }
    }

    private func nursingGlassTimerControls(_ metrics: RecordGlassRecorderMetrics) -> some View {
        let S = metrics.S
        let controlOffsetY = bottleGlassLayout(metrics).amountY - metrics.primaryY
        return ZStack {
            nursingTimerButton(side: .left, seconds: leftSeconds, S: S)
                .position(x: metrics.W * 0.24, y: 30 * S)

            HStack(alignment: .firstTextBaseline, spacing: 2 * S) {
                Text("\(max((leftSeconds + rightSeconds) / 60, 0))")
                    .font(BBBFont.font(size: 36 * S, weight: .bold))
                Text("min")
                    .font(BBBFont.font(size: 18 * S, weight: .medium))
            }
            .foregroundStyle(DesignToken.feedingBreast)
            .monospacedDigit()
            .position(x: metrics.W * 0.5, y: 30 * S)

            nursingTimerButton(side: .right, seconds: rightSeconds, S: S)
                .position(x: metrics.W * 0.76, y: 30 * S)
        }
        .frame(width: metrics.W, height: 60 * S)
        .offset(y: controlOffsetY)
    }

    private func nursingTimerButton(side: BreastSide, seconds: Int, S: CGFloat) -> some View {
        let active = activeBreastSide == side
        return Button {
            toggleBreastTimer(side)
        } label: {
            VStack(spacing: 2 * S) {
                HStack(spacing: 3 * S) {
                    Text(side == .left ? "左" : "右")
                        .font(BBBFont.font(size: 8 * S, weight: .medium))
                    Image(systemName: activeBreastSide == side ? "pause.fill" : "play.fill")
                        .font(.system(size: 8 * S, weight: .bold))
                }
                Text(durationText(seconds))
                    .font(BBBFont.font(size: 9 * S, weight: .semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .foregroundStyle(active ? DesignToken.feedingBreast : DesignToken.textSecondary.opacity(0.82))
            .frame(width: 52 * S, height: 52 * S)
            .glassEffect(
                .regular
                    .tint(Color.white.opacity(active ? 0.23 : 0.12))
                    .interactive(),
                in: .circle
            )
            .overlay(Circle().stroke(Color.white.opacity(active ? 0.50 : 0.30), lineWidth: 1))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func nursingPresetCapsule(W: CGFloat, S: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach([5, 10, 15], id: \.self) { minutes in
                nursingPresetButton(minutes: minutes, S: S)
            }
        }
        .padding(5 * S)
        .contentShape(Capsule(style: .continuous))
        .glassEffect(.regular.tint(Color.white.opacity(0.16)), in: .capsule)
        .overlay(Capsule(style: .continuous).fill(Color.white.opacity(0.055)).allowsHitTesting(false))
        .overlay(Capsule(style: .continuous).stroke(Color.white.opacity(0.30), lineWidth: 1).allowsHitTesting(false))
    }

    private func nursingPresetButton(minutes: Int, S: CGFloat) -> some View {
        let selected = abs(leftSeconds - minutes * 60) < 30 && abs(rightSeconds - minutes * 60) < 30
        return Button {
            requestBreastPreset(minutes: minutes)
        } label: {
            VStack(spacing: 1 * S) {
                Text("左\(minutes)")
                    .font(BBBFont.font(size: 12 * S, weight: selected ? .bold : .semibold))
                Text("右\(minutes)")
                    .font(BBBFont.font(size: 12 * S, weight: selected ? .bold : .semibold))
            }
            .foregroundStyle(selected ? DesignToken.feedingBreast : DesignToken.textSecondary.opacity(0.76))
            .frame(maxWidth: .infinity)
            .frame(height: 48 * S)
            .scaleEffect(selected ? 1.045 : 1)
            .offset(y: selected ? -1 * S : 0)
            .background(
                Capsule(style: .continuous)
                    .fill(selected ? Color.white.opacity(0.43) : Color.clear)
                    .overlay(Capsule(style: .continuous).stroke(selected ? Color.white.opacity(0.50) : Color.clear, lineWidth: 1))
            )
            .animation(.spring(response: 0.26, dampingFraction: 0.76), value: selected)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func bottleGlassStage(_ metrics: RecordGlassRecorderMetrics) -> some View {
        let S = metrics.S
        let bottleLayout = bottleGlassLayout(metrics)
        let bottleHeight = bottleLayout.bottleHeight
        let stageHeight = bottleHeight + 80 * S
        let bottleCenterY = stageHeight * 0.5 + (bottleLayout.bottleY - metrics.stageY)

        return ZStack {
            InteractiveBottleView(amount: bottleAmountBinding, range: bottleRange, step: 10, tint: selectedKind.accent)
                .frame(width: bottleHeight * 0.56, height: bottleHeight)
                .position(x: metrics.W * 0.5, y: bottleCenterY)

            bottleMilkSwitchButton(S: S) {
                showBottleMilkTypePicker = true
            }
            .position(x: 44 * S, y: bottleCenterY + 18 * S)

            bottleSideIconButton(systemIcon: "clock", S: S) {
                showRecordTimePicker = true
            }
            .position(x: metrics.W - 44 * S, y: bottleCenterY + 18 * S)
        }
        .frame(width: metrics.W, height: stageHeight)
    }

    private func bottleGlassAmountControls(_ metrics: RecordGlassRecorderMetrics) -> some View {
        let S = metrics.S
        let amountOffsetY = bottleGlassLayout(metrics).amountY - metrics.primaryY
        return HStack(spacing: 22 * S) {
            bottleAmountButton(systemIcon: "minus", S: S) {
                withAnimation(.spring(response: 0.24, dampingFraction: 0.76)) {
                    bottleAmount = max(bottleRange.lowerBound, bottleAmount - 10)
                }
                persistDraft()
            }

            BottleAmountReadout(amount: bottleAmount, unit: "ml", S: S)
                .frame(minWidth: 110 * S)

            bottleAmountButton(systemIcon: "plus", S: S) {
                withAnimation(.spring(response: 0.24, dampingFraction: 0.76)) {
                    bottleAmount = min(bottleRange.upperBound, bottleAmount + 10)
                }
                persistDraft()
            }
        }
        .offset(y: amountOffsetY)
    }

    private func solidsGlassStage(_ metrics: RecordGlassRecorderMetrics) -> some View {
        let S = metrics.S
        let bottleLayout = bottleGlassLayout(metrics)
        let stageHeight = min(max(metrics.stageHeight, 370 * S), 440 * S)
        let centerY = stageHeight * 0.5 + (bottleLayout.bottleY - metrics.stageY)
        let heroHeight = min(max(metrics.W * 0.44, 172 * S), 240 * S)

        return ZStack {
            solidsHeroArt(S: S)
                .frame(width: metrics.W * 0.62, height: heroHeight)
                .position(x: metrics.W * 0.5, y: centerY)

            solidFoodGlassMenu(S: S)
                .position(x: 44 * S, y: centerY + 18 * S)
                .zIndex(20)

            bottleSideIconButton(systemIcon: "clock", S: S) {
                showRecordTimePicker = true
            }
            .position(x: metrics.W - 44 * S, y: centerY + 18 * S)
            .zIndex(20)
        }
        .frame(width: metrics.W, height: stageHeight)
    }

    @ViewBuilder
    private func solidsHeroArt(S: CGFloat) -> some View {
        if UIImage(named: "record_solids_bowl_hero") != nil {
            Image("record_solids_bowl_hero")
                .resizable()
                .scaledToFit()
                .opacity(0.86)
        } else {
            ZStack {
                Ellipse()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.42),
                                DesignToken.feedingSolid.opacity(0.18)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 188 * S, height: 82 * S)
                    .offset(y: 26 * S)
                    .blur(radius: 2 * S)

                Text("🥣")
                    .font(.system(size: 108 * S))
                    .shadow(color: Color.white.opacity(0.45), radius: 10 * S, y: -2 * S)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                Circle()
                    .fill(Color.white.opacity(0.16))
                    .blur(radius: 22 * S)
            )
        }
    }

    private func solidFoodGlassMenu(S: CGFloat) -> some View {
        Button {
            showSolidFoodPicker = true
        } label: {
            ZStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 16 * S, weight: .medium))
                    .foregroundStyle(DesignToken.feedingSolid.opacity(0.78))
                    .shadow(color: Color.white.opacity(0.46), radius: 5, y: -1)

                if selectedSolidFoods.count > 1 {
                    Text("\(selectedSolidFoods.count)")
                        .font(BBBFont.font(size: 10 * S, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(width: 18 * S, height: 18 * S)
                        .background(Circle().fill(FeedingType.solid.accent.opacity(0.92)))
                        .offset(x: 15 * S, y: -15 * S)
                }
            }
            .frame(width: 56 * S, height: 56 * S)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private var solidFoodPickerSheet: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("选择辅食")
                        .font(BBBFont.font(size: 20, weight: .heavy))
                        .foregroundStyle(DesignToken.textPrimary)
                    Text("\(solidFoodSummary) · 共 \(Int(solidAmount))\(solidUnit.displayName)")
                        .font(BBBFont.font(size: 12, weight: .bold))
                        .foregroundStyle(DesignToken.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                Spacer()

                Button("完成") {
                    showSolidFoodPicker = false
                }
                .font(BBBFont.font(size: 14, weight: .heavy))
                .foregroundStyle(DesignToken.feedingSolid)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(SolidFood.allCases) { food in
                    solidFoodChip(food)
                }
            }

            Text("多选时保存为同一次辅食，当前总量会平均分配到所选食材，统计总量不会重复累计。")
                .font(BBBFont.font(size: 11, weight: .semibold))
                .foregroundStyle(DesignToken.textSecondary.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 20)
        .padding(.top, 22)
        .padding(.bottom, 18)
        .background(DesignToken.canvas.opacity(0.78))
    }

    private func solidFoodChip(_ food: SolidFood) -> some View {
        let selected = selectedSolidFoods.contains(food)
        return Button {
            toggleSolidFood(food)
        } label: {
            VStack(spacing: 7) {
                Text(food.emoji)
                    .font(.system(size: 22))
                Text(food.displayName)
                    .font(BBBFont.font(size: 12, weight: .heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(selected ? DesignToken.textStrong : DesignToken.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: 74)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(selected ? FeedingType.solid.accent.opacity(0.20) : Color.white.opacity(0.58))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(selected ? FeedingType.solid.accent.opacity(0.46) : Color.white.opacity(0.44), lineWidth: 1.2)
                    )
            )
            .overlay(alignment: .topTrailing) {
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(FeedingType.solid.accent)
                        .padding(7)
                }
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func solidsGlassAmountControls(_ metrics: RecordGlassRecorderMetrics) -> some View {
        let S = metrics.S
        let amountOffsetY = bottleGlassLayout(metrics).amountY - metrics.primaryY
        return HStack(spacing: 22 * S) {
            bottleAmountButton(systemIcon: "minus", S: S) {
                solidAmount = max(5, solidAmount - 5)
                persistDraft()
            }

            HStack(alignment: .firstTextBaseline, spacing: 2 * S) {
                Text("\(Int(solidAmount))")
                    .font(BBBFont.font(size: 36 * S, weight: .bold))
                Text(solidUnit.displayName)
                    .font(BBBFont.font(size: 18 * S, weight: .medium))
            }
            .foregroundStyle(DesignToken.feedingSolid)
            .monospacedDigit()
            .frame(minWidth: 110 * S)

            bottleAmountButton(systemIcon: "plus", S: S) {
                solidAmount = min(300, solidAmount + 5)
                persistDraft()
            }
        }
        .offset(y: amountOffsetY)
    }

    private func solidsDoseCapsule(W: CGFloat, S: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach([60, 90, 120], id: \.self) { amount in
                solidsDoseButton(amount: amount, S: S)
            }
        }
        .padding(5 * S)
        .contentShape(Capsule(style: .continuous))
        .glassEffect(.regular.tint(Color.white.opacity(0.16)), in: .capsule)
        .overlay(Capsule(style: .continuous).fill(Color.white.opacity(0.055)).allowsHitTesting(false))
        .overlay(Capsule(style: .continuous).stroke(Color.white.opacity(0.30), lineWidth: 1).allowsHitTesting(false))
    }

    private func solidsDoseButton(amount: Int, S: CGFloat) -> some View {
        let selected = abs(Double(amount) - solidAmount) < 0.5
        return Button {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.86)) {
                solidAmount = Double(amount)
            }
            persistDraft()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            VStack(spacing: 0) {
                Text("\(amount)")
                    .font(BBBFont.font(size: 14 * S, weight: selected ? .bold : .semibold))
                Text(solidUnit.displayName)
                    .font(BBBFont.font(size: 10 * S, weight: .bold))
            }
            .foregroundStyle(selected ? DesignToken.feedingSolid : DesignToken.textPrimary.opacity(0.76))
            .frame(maxWidth: .infinity)
            .frame(height: 48 * S)
            .contentShape(Capsule(style: .continuous))
            .background(
                Capsule(style: .continuous)
                    .fill(selected ? Color.white.opacity(0.43) : Color.clear)
                    .overlay(Capsule(style: .continuous).stroke(selected ? Color.white.opacity(0.50) : Color.clear, lineWidth: 1))
                    .shadow(color: selected ? Color.white.opacity(0.16) : .clear, radius: 7, y: 0)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func bottleGlassLayout(_ metrics: RecordGlassRecorderMetrics) -> (bottleHeight: CGFloat, amountY: CGFloat, bottleY: CGFloat) {
        let S = metrics.S
        let stageTop = metrics.statsY + metrics.statsHeight * 0.5 + 18 * S
        let stageBottom = metrics.modeY - metrics.modeHeight * 0.5 - 24 * S
        let stageCenter = (stageTop + stageBottom) * 0.5
        let bottleHeight = min(max(metrics.W * 0.86, 315 * S), 370 * S)
        let amountGap = 34 * S
        let amountY = min(stageBottom - 24 * S, stageCenter + bottleHeight * 0.5 + amountGap - 30 * S)
        let bottleY = amountY - bottleHeight * 0.5 - amountGap
        return (bottleHeight, amountY, bottleY)
    }

    private var bottleRenderedLayout: some View {
        GeometryReader { geometry in
            let W = geometry.size.width
            let H = geometry.size.height
            let S = W / 393.0
            let horizontalPadding = 24 * S
            let headerHeight = 40 * S
            let statsHeight = 54 * S
            let modeHeight = 96 * S
            let dockHeight = 72 * S
            let headerY = 62 * S
            let statsY = 126 * S
            let dockY = H - 70 * S
            let modeY = dockY - 90 * S
            let stageTop = statsY + statsHeight * 0.5 + 18 * S
            let stageBottom = modeY - modeHeight * 0.5 - 24 * S
            let stageCenter = (stageTop + stageBottom) * 0.5
            let bottleHeight = min(max(W * 0.86, 315 * S), 370 * S)
            let amountGap = 34 * S
            let amountY = min(stageBottom - 24 * S, stageCenter + bottleHeight * 0.5 + amountGap - 30 * S)
            let bottleY = amountY - bottleHeight * 0.5 - amountGap

            ZStack {
                FeedingPastelBackground()

                bottleFloatingButton(systemIcon: "chevron.left", size: headerHeight, iconSize: 16 * S) {
                    persistDraft()
                    isPresented = false
                }
                .position(x: horizontalPadding + headerHeight * 0.5, y: headerY)

                Text("记录喂养")
                    .font(BBBFont.font(size: 18 * S, weight: .bold))
                    .foregroundStyle(DesignToken.textPrimary)
                    .lineLimit(1)
                    .position(x: W * 0.5, y: headerY)

                bottleFloatingButton(systemIcon: "ellipsis", size: headerHeight, iconSize: 16 * S) {
                    showMoreInfo = true
                }
                .position(x: W - horizontalPadding - headerHeight * 0.5, y: headerY)

                bottleStatsBar(W: W, H: H, S: S)
                    .frame(height: statsHeight)
                    .position(x: W * 0.5, y: statsY)

                bottleStageGlow(W: W, S: S)
                    .position(x: W * 0.5, y: bottleY + bottleHeight * 0.18)

                InteractiveBottleView(amount: bottleAmountBinding, range: bottleRange, step: 10, tint: selectedKind.accent)
                    .frame(width: bottleHeight * 0.56, height: bottleHeight)
                    .position(x: W * 0.5, y: bottleY)

                bottleMilkSwitchButton(S: S) {
                    toggleBottleMilkType()
                }
                .position(x: 44 * S, y: bottleY + 18 * S)
                .zIndex(20)

                bottleSideIconButton(systemIcon: "clock", S: S) {
                    showRecordTimePicker = true
                }
                .position(x: W - 44 * S, y: bottleY + 18 * S)
                .zIndex(20)

                HStack(spacing: 22 * S) {
                    bottleAmountButton(systemIcon: "minus", S: S) {
                        bottleAmount = max(bottleRange.lowerBound, bottleAmount - 10)
                        persistDraft()
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 2 * S) {
                        Text("\(Int(bottleAmount))")
                            .font(BBBFont.font(size: 36 * S, weight: .bold))
                        Text("ml")
                            .font(BBBFont.font(size: 18 * S, weight: .medium))
                    }
                    .foregroundStyle(DesignToken.feedingBottle)
                    .monospacedDigit()
                    .frame(minWidth: 110 * S)

                    bottleAmountButton(systemIcon: "plus", S: S) {
                        bottleAmount = min(bottleRange.upperBound, bottleAmount + 10)
                        persistDraft()
                    }
                }
                .position(x: W * 0.5, y: amountY)

                bottleModeSelector(W: W, S: S)
                    .frame(height: modeHeight)
                    .position(x: W * 0.5, y: modeY)

                bottleBottomGlassDock(W: W, S: S)
                    .frame(height: dockHeight)
                    .position(x: W * 0.5, y: dockY)
            }
            .frame(width: W, height: H)
            .ignoresSafeArea()
        }
        .statusBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $showRecordTimePicker) {
            recordTimePickerSheet
                .presentationDetents([.height(320)])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
                .presentationCornerRadius(34)
        }
        .sheet(isPresented: $showMoreInfo) {
            moreInfoPopover
                .presentationDetents([.height(260)])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
                .presentationCornerRadius(34)
        }
    }

    private func bottleHeader(W: CGFloat, H: CGFloat, S: CGFloat) -> some View {
        ZStack {
            bottleFloatingButton(systemIcon: "chevron.left", size: 48 * S, iconSize: 24 * S) {
                persistDraft()
                isPresented = false
            }
            .position(x: W * 0.11, y: H * 0.065)

            Text("记录喂养")
                .font(BBBFont.font(size: 20 * S, weight: .bold))
                .foregroundStyle(DesignToken.textPrimary)
                .shadow(color: .white.opacity(0.58), radius: 1.5, y: 1)
                .position(x: W * 0.5, y: H * 0.075)

            bottleFloatingButton(systemIcon: "ellipsis", size: 48 * S, iconSize: 22 * S) {
                showMoreInfo = true
            }
            .position(x: W * 0.89, y: H * 0.065)
        }
    }

    private func bottleStatsBar(W: CGFloat, H: CGFloat, S: CGFloat) -> some View {
        let totalWidth = W - 48 * S
        let dividerWidth = 1 * S
        let columnWidth = (totalWidth - 3 * dividerWidth) / 4
        let stats = [
            ("今日瓶喂", "\(todayKindCount)次"),
            ("今日奶量", todayAmountValue),
            ("距离上次", lastIntervalStatText),
            ("当前时间", timeString(recordTime))
        ]

        return HStack(spacing: 0) {
            ForEach(Array(stats.enumerated()), id: \.offset) { index, stat in
                VStack(spacing: 6 * S) {
                    Text(stat.1)
                        .font(BBBFont.font(size: 12 * S, weight: .semibold))
                        .foregroundStyle(DesignToken.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.62)
                        .allowsTightening(true)
                        .monospacedDigit()

                    Text(stat.0)
                        .font(BBBFont.font(size: 10 * S, weight: .regular))
                        .foregroundStyle(DesignToken.textSecondary.opacity(0.68))
                        .lineLimit(1)
                }
                .frame(width: columnWidth)
                .clipped()

                if index < 3 {
                    Rectangle()
                        .fill(DesignToken.borderSubtle.opacity(0.72))
                        .frame(width: dividerWidth, height: 32 * S)
                }
            }
        }
        .frame(width: totalWidth, height: 54 * S)
    }

    private func bottleAmountLayer(W: CGFloat, H: CGFloat, S: CGFloat) -> some View {
        ZStack {
            bottleAmountButton(systemIcon: "minus", S: S) {
                bottleAmount = max(bottleRange.lowerBound, bottleAmount - 10)
                persistDraft()
            }
            .position(x: W * 0.24, y: H * 0.69)

            HStack(alignment: .firstTextBaseline, spacing: 2 * S) {
                Text("\(Int(bottleAmount))")
                    .font(BBBFont.font(size: 48 * S, weight: .bold))
                Text("ml")
                    .font(BBBFont.font(size: 24 * S, weight: .semibold))
            }
            .foregroundStyle(DesignToken.feedingBottle)
            .monospacedDigit()
            .position(x: W * 0.5, y: H * 0.69)

            bottleAmountButton(systemIcon: "plus", S: S) {
                bottleAmount = min(bottleRange.upperBound, bottleAmount + 10)
                persistDraft()
            }
            .position(x: W * 0.76, y: H * 0.69)

            Text("\(milkType.displayName)量 · \(lastIntervalText)")
                .font(BBBFont.font(size: 15 * S, weight: .semibold))
                .foregroundStyle(DesignToken.textSecondary.opacity(0.92))
                .lineLimit(1)
                .minimumScaleFactor(0.74)
                .position(x: W * 0.5, y: H * 0.74)
        }
    }

    private func bottleAmountButton(systemIcon: String, S: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemIcon)
                .font(.system(size: 16 * S, weight: .bold))
                .foregroundStyle(selectedKind.accent)
                .frame(width: 40 * S, height: 40 * S)
                .contentShape(Circle())
                .glassEffect(.regular.tint(Color.white.opacity(0.32)).interactive(), in: .circle)
                .overlay(Circle().stroke(Color.white.opacity(0.62), lineWidth: 1).allowsHitTesting(false))
                .shadow(color: Color.white.opacity(0.34), radius: 8, y: -1)
                .shadow(color: DesignToken.easyEat.opacity(0.10), radius: 9, y: 5)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func bottleFloatingButton(systemIcon: String, size: CGFloat, iconSize: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemIcon)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(selectedKind.accent.opacity(0.88))
                .frame(width: size, height: size)
                .glassEffect(
                    .regular
                        .tint(Color.white.opacity(0.10))
                        .interactive(),
                    in: .circle
                )
                .overlay(Circle().fill(Color.white.opacity(0.075)))
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.36), lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    Circle()
                        .stroke(Color.white.opacity(0.24), lineWidth: 1)
                        .blur(radius: 0.5)
                        .padding(3)
                }
                .shadow(color: Color.white.opacity(0.28), radius: 8, y: -1)
                .shadow(color: DesignToken.easyEat.opacity(0.075), radius: 11, y: 5)
        }
        .buttonStyle(.plain)
    }

    private func bottleSideIconButton(systemIcon: String, S: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Color.clear
                .frame(width: 56 * S, height: 56 * S)
                .overlay {
                    Image(systemName: systemIcon)
                        .font(.system(size: 16 * S, weight: .medium))
                        .foregroundStyle(selectedKind.accent.opacity(0.78))
                        .shadow(color: Color.white.opacity(0.46), radius: 5, y: -1)
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private func bottleMilkSwitchButton(S: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 16 * S, weight: .medium))
                    .foregroundStyle((milkType == .formula ? DesignToken.feedingBottle : DesignToken.feedingBreast).opacity(0.78))
                    .shadow(color: Color.white.opacity(0.46), radius: 5, y: -1)

                Text(milkType == .formula ? "粉" : "母")
                    .font(BBBFont.font(size: 7 * S, weight: .heavy))
                    .foregroundStyle(.white.opacity(0.96))
                    .frame(width: 18 * S, height: 13 * S)
                    .background(
                        Capsule(style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: milkType == .formula
                                        ? [Color(hex: "#C49A5E"), Color(hex: "#E0B276")]
                                        : [Color(hex: "#78BDEB"), Color(hex: "#9FD6F7")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(Capsule(style: .continuous).stroke(Color.white.opacity(0.52), lineWidth: 0.6))
                    )
                    .shadow(color: DesignToken.easyEat.opacity(0.12), radius: 4, y: 2)
                    .offset(x: 4 * S, y: 3 * S)
            }
            .frame(width: 56 * S, height: 56 * S)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .id(milkType.id)
    }

    private func bottleStageGlow(W: CGFloat, S: CGFloat) -> some View {
        ZStack {
            Ellipse()
                .fill(Color.white.opacity(0.24))
                .frame(width: W * 0.72, height: 116 * S)
                .blur(radius: 30 * S)

            RadialGradient(
                colors: [
                    Color.white.opacity(0.34),
                    DesignToken.easyEat.opacity(0.12),
                    .clear
                ],
                center: .center,
                startRadius: 12 * S,
                endRadius: 150 * S
            )
            .frame(width: W * 0.76, height: 210 * S)
        }
        .allowsHitTesting(false)
    }

    private func bottleModeSelector(W: CGFloat, S: CGFloat) -> some View {
        RecordGlassModeSelector(items: [FeedingKind.nursing, .bottle, .solids], selected: selectedKind, S: S) { kind in
            selectKind(kind)
        } content: { kind, isSelected in
            VStack(spacing: 4 * S) {
                Text(kind.emoji)
                    .font(.system(size: 20 * S))
                Text(kind.label)
                    .font(BBBFont.font(size: 12 * S, weight: isSelected ? .bold : .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? .white : DesignToken.textSecondary.opacity(0.56))
        }
    }

    private func bottleBottomGlassDock(W: CGFloat, S: CGFloat) -> some View {
        let trayWidth = W - 48 * S
        return GlassEffectContainer(spacing: 7 * S) {
            HStack(spacing: 7 * S) {
                bottleDoseCapsule(W: W, S: S)
                    .frame(width: W * 0.43, height: 56 * S)

                bottleSaveButton(W: W, S: S)
            }
        }
        .padding(8 * S)
        .frame(width: trayWidth, height: 72 * S)
        .glassEffect(.regular.tint(Color.white.opacity(0.18)), in: .capsule)
        .overlay(Capsule(style: .continuous).stroke(Color.white.opacity(0.56), lineWidth: 1))
        .shadow(color: Color.white.opacity(0.42), radius: 14, y: -2)
        .shadow(color: DesignToken.easyEat.opacity(0.14), radius: 22, y: 9)
    }

    private func bottleSaveButton(W: CGFloat, S: CGFloat) -> some View {
        Button(action: save) {
            Text("保存")
                .font(BBBFont.font(size: 18 * S, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(maxWidth: .infinity)
                .frame(height: 56 * S)
                .glassEffect(
                    .regular
                        .tint(DesignToken.easyEat.opacity(0.84))
                        .interactive(),
                    in: .capsule
                )
                .overlay(
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    DesignToken.easyEat,
                                    DesignToken.feedingBreast
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .overlay(Capsule(style: .continuous).stroke(Color.white.opacity(0.66), lineWidth: 1))
                .shadow(color: DesignToken.easyEat.opacity(0.28), radius: 18, y: 7)
        }
        .disabled(!canSave)
        .opacity(canSave ? 1 : 0.58)
        .buttonStyle(ScaleButtonStyle())
    }

    private func bottleMoreButton(S: CGFloat) -> some View {
        Button {
            showMoreInfo = true
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 22 * S, weight: .bold))
                .foregroundStyle(DesignToken.textSecondary.opacity(0.88))
                .frame(width: 64 * S, height: 64 * S)
                .glassEffect(.regular.tint(Color.white.opacity(0.28)).interactive(), in: .circle)
                .overlay(Circle().stroke(Color.white.opacity(0.58), lineWidth: 1))
                .shadow(color: Color.white.opacity(0.34), radius: 10, y: -1)
                .shadow(color: DesignToken.easyEat.opacity(0.12), radius: 14, y: 7)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func bottleDoseCapsule(W: CGFloat, S: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach([60, 90, 120], id: \.self) { amount in
                bottleDoseButton(amount: amount, S: S)
            }
        }
        .padding(5 * S)
        .contentShape(Capsule(style: .continuous))
        .glassEffect(.regular.tint(Color.white.opacity(0.16)), in: .capsule)
        .overlay(Capsule(style: .continuous).fill(Color.white.opacity(0.055)).allowsHitTesting(false))
        .overlay(Capsule(style: .continuous).stroke(Color.white.opacity(0.30), lineWidth: 1).allowsHitTesting(false))
    }

    private func bottleDoseButton(amount: Int, S: CGFloat) -> some View {
        let selected = abs(Double(amount) - bottleAmount) < 0.5
        return Button {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.74)) {
                bottleAmount = Double(amount)
            }
            persistDraft()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            bottleDoseLabel(amount: amount, selected: selected, S: S)
                .scaleEffect(selected ? 1.055 : 1.0)
                .offset(y: selected ? -1.5 * S : 0)
                .background(
                    Capsule(style: .continuous)
                        .fill(selected ? Color.white.opacity(0.43) : Color.clear)
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(selected ? Color.white.opacity(0.50) : Color.clear, lineWidth: 1)
                        )
                        .shadow(color: selected ? Color.white.opacity(0.16) : .clear, radius: 7, y: 0)
                )
                .overlay(alignment: .top) {
                    if selected {
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.52))
                            .frame(width: 18 * S, height: 2 * S)
                            .padding(.top, 6 * S)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.24, dampingFraction: 0.74), value: selected)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func bottleDoseLabel(amount: Int, selected: Bool, S: CGFloat) -> some View {
        VStack(spacing: 0) {
            Text("\(amount)")
                .font(BBBFont.font(size: 14 * S, weight: selected ? .bold : .semibold))
            Text("ml")
                .font(BBBFont.font(size: 10 * S, weight: .bold))
        }
        .foregroundStyle(selected ? selectedKind.accent : DesignToken.textPrimary.opacity(0.76))
        .frame(maxWidth: .infinity)
        .frame(height: 48 * S)
        .contentShape(Capsule(style: .continuous))
    }

    private var feedingTopStats: [RecordTopStat] {
        [
            RecordTopStat(title: todayCountTitle, value: "\(todayKindCount)次"),
            RecordTopStat(title: todayAmountTitle, value: todayAmountValue),
            RecordTopStat(title: "距离上次", value: lastIntervalStatText),
            RecordTopStat(title: "当前时间", value: timeString(recordTime))
        ]
    }

    private func feedingStatsDockButton(S: CGFloat) -> some View {
        RecordGlassDockActionButton(
            title: "记录统计",
            systemIcon: "chart.line.uptrend.xyaxis",
            S: S
        ) {
            showMoreInfo = true
        }
    }

    private var feedingStatsButton: some View {
        Button {
            showMoreInfo = true
        } label: {
            Label("记录统计", systemImage: "chart.line.uptrend.xyaxis")
                .font(BBBFont.font(size: 13, weight: .heavy))
                .foregroundStyle(DesignToken.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(width: 112, height: 58)
                .background(Capsule(style: .continuous).fill(Color.white.opacity(0.50)))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var bottleQuickAmountDock: some View {
        HStack(spacing: 2) {
            ForEach([60, 90, 120, 150], id: \.self) { amount in
                Button {
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.86)) {
                        bottleAmount = Double(amount)
                    }
                    persistDraft()
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    VStack(spacing: 0) {
                        Text("\(amount)")
                            .font(BBBFont.font(size: amount == Int(bottleAmount) ? 18 : 15, weight: .heavy))
                            .foregroundStyle(amount == Int(bottleAmount) ? selectedKind.accent : DesignToken.textStrong.opacity(0.80))
                        Text("ml")
                            .font(BBBFont.font(size: 9, weight: .bold))
                            .foregroundStyle(amount == Int(bottleAmount) ? selectedKind.accent.opacity(0.86) : DesignToken.textMuted.opacity(0.74))
                    }
                    .frame(width: amount == Int(bottleAmount) ? 48 : 40, height: 52)
                    .background(
                        Capsule(style: .continuous)
                            .fill(amount == Int(bottleAmount) ? Color.white.opacity(0.76) : Color.clear)
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(amount == Int(bottleAmount) ? .white.opacity(0.82) : .clear, lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(4)
        .frame(width: 176, height: 58)
        .background(Capsule(style: .continuous).fill(Color.white.opacity(0.28)))
    }

    private var todayCountTitle: String {
        switch selectedKind {
        case .nursing: return "今日亲喂"
        case .bottle: return "今日瓶喂"
        default: return "今日辅食"
        }
    }

    private var todayAmountTitle: String {
        switch selectedKind {
        case .nursing: return "今日时长"
        case .bottle: return "今日奶量"
        default: return "今日辅食量"
        }
    }

    private var todayKindCount: Int {
        feedingStore.todaySessions.filter { session in
            session.entries.contains { entry in
                switch selectedKind {
                case .nursing:
                    return entry.type == .breast
                case .bottle:
                    return entry.type == .bottle
                default:
                    return entry.type == .solid
                }
            }
        }.count
    }

    private var todayAmountValue: String {
        switch selectedKind {
        case .nursing:
            return "\(feedingStore.breastDuration)min"
        case .bottle:
            return "\(feedingStore.formulaML + feedingStore.expressedMilkML)ml"
        default:
            return "\(feedingStore.solidsGram)g"
        }
    }

    @ViewBuilder
    private var stageArea: some View {
        switch selectedKind {
        case .nursing:
            breastStage
        case .bottle:
            bottleStage
        case .solids:
            solidsBowlStage
        default:
            solidStage
        }
    }

    private var breastStage: some View {
        VStack(spacing: isCompactHeight ? 10 : 14) {
            HStack(spacing: 12) {
                breastTimer(.left, seconds: leftSeconds)
                breastTimer(.right, seconds: rightSeconds)
            }

            Text("左边 \(durationText(leftSeconds))，右边 \(durationText(rightSeconds))")
                .font(BBBFont.font(size: 13, weight: .semibold))
                .foregroundStyle(DesignToken.textSecondary)
                .lineLimit(1)
        }
        .padding(isCompactHeight ? 10 : 14)
        .background(cardBackground)
    }

    private var bottleStage: some View {
        VStack(spacing: isCompactHeight ? 6 : 8) {
            ZStack {
                InteractiveBottleView(amount: bottleAmountBinding, range: bottleRange, step: 10, tint: selectedKind.accent)
                    .frame(width: isCompactHeight ? 268 : 312, height: isCompactHeight ? 268 : 312)
                    .frame(maxWidth: .infinity)

                HStack {
                    // 左侧：奶粉/母乳切换
                    milkTypeMenu
                    Spacer()
                    // 右侧：时间调整
                    recordTimeButton
                }
                .padding(.horizontal, isCompactHeight ? 8 : 10)
                .padding(.top, isCompactHeight ? 82 : 96)
            }

            BottleAmountScrubber(
                amount: bottleAmountBinding,
                range: bottleRange,
                step: 10,
                tint: selectedKind.accent,
                isCompactHeight: isCompactHeight
            )

            Text("\(milkType.displayName)量 · \(lastIntervalText)")
                .font(BBBFont.font(size: 14, weight: .bold))
                .foregroundStyle(DesignToken.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .padding(.top, isCompactHeight ? 0 : 2)
        .sheet(isPresented: $showRecordTimePicker) {
            recordTimePickerSheet
                .presentationDetents([.height(320)])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Solids bowl stage (mirrors bottleStage)

    private var solidsBowlStage: some View {
        VStack(spacing: isCompactHeight ? 10 : 14) {
            ZStack {
                // 碗 emoji 占位（后续替换素材）
                Text("🥣")
                    .font(.system(size: isCompactHeight ? 152 : 180))
                    .frame(width: isCompactHeight ? 286 : 340, height: isCompactHeight ? 286 : 340)
                    .frame(maxWidth: .infinity)
                    .background(
                        Circle()
                            .fill(selectedKind.accent.opacity(0.08))
                            .frame(width: isCompactHeight ? 220 : 260, height: isCompactHeight ? 220 : 260)
                    )

                HStack {
                    // 左侧：辅食种类选择
                    solidFoodMenu
                    Spacer()
                    // 右侧：时间调整
                    recordTimeButton
                }
                .padding(.horizontal, isCompactHeight ? 8 : 12)
            }

            AmountStepperControl(
                value: solidAmountBinding,
                range: 5...300,
                step: 5,
                unit: solidUnit.displayName,
                tint: selectedKind.accent,
                isCompactHeight: isCompactHeight
            )

            // 单位切换
            Picker("单位", selection: solidUnitBinding) {
                ForEach(SolidUnit.allCases) { unit in
                    Text(unit.displayName).tag(unit)
                }
            }
            .pickerStyle(.menu)
            .tint(selectedKind.accent)

            Text("\(solidFoodSummary) · \(Int(solidAmount))\(solidUnit.displayName) · \(lastIntervalText)")
                .font(BBBFont.font(size: 13, weight: .bold))
                .foregroundStyle(DesignToken.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .padding(.top, isCompactHeight ? 0 : 8)
        .sheet(isPresented: $showRecordTimePicker) {
            recordTimePickerSheet
                .presentationDetents([.height(320)])
                .presentationDragIndicator(.visible)
        }
    }

    private var solidFoodMenu: some View {
        Button {
            showSolidFoodPicker = true
        } label: {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 25, weight: .bold))
                .foregroundStyle(.white.opacity(0.92))
                .frame(width: 62, height: 62)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(Circle().fill(Color.white.opacity(0.22)))
                        .overlay(Circle().stroke(.white.opacity(0.72), lineWidth: 1.1))
                        .shadow(color: DesignToken.easyEat.opacity(0.10), radius: 16, y: 7)
                )
                .overlay(alignment: .topTrailing) {
                    if selectedSolidFoods.count > 1 {
                        Text("\(selectedSolidFoods.count)")
                            .font(BBBFont.font(size: 11, weight: .heavy))
                            .foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                            .background(Circle().fill(FeedingType.solid.accent.opacity(0.92)))
                            .offset(x: 2, y: -2)
                    }
                }
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func sidePillButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .heavy))
                Text(title)
                    .font(BBBFont.font(size: 15, weight: .heavy))
            }
            .foregroundStyle(DesignToken.textPrimary)
            .padding(.horizontal, 16)
            .frame(height: 52)
            .background(
                Capsule(style: .continuous)
                    .fill(.white.opacity(0.84))
                    .overlay(Capsule(style: .continuous).stroke(.white.opacity(0.92), lineWidth: 1))
                    .shadow(color: DesignToken.textStrong.opacity(0.06), radius: 12, y: 5)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Bottle side controls

    private var milkTypeMenu: some View {
        Menu {
            ForEach(MilkType.allCases) { type in
                Button {
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                        milkType = type
                    }
                    persistDraft()
                } label: {
                    Label(type.displayName, systemImage: milkType == type ? "checkmark" : "")
                }
            }
        } label: {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(DesignToken.textSecondary.opacity(0.55))
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(.white.opacity(0.84))
                        .shadow(color: DesignToken.textStrong.opacity(0.04), radius: 8, y: 4)
                )
        }
    }

    private var recordTimeButton: some View {
        Button {
            showRecordTimePicker = true
        } label: {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 25, weight: .bold))
                .foregroundStyle(.white.opacity(0.92))
                .frame(width: 62, height: 62)
            .background(
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(Circle().fill(Color.white.opacity(0.22)))
                    .overlay(Circle().stroke(.white.opacity(0.72), lineWidth: 1.1))
                    .shadow(color: DesignToken.easyEat.opacity(0.10), radius: 16, y: 7)
            )
        }
    }

    private var recordTimePickerSheet: some View {
        VStack(spacing: 0) {
            // 顶部标题栏
            HStack {
                Button("取消") {
                    showRecordTimePicker = false
                }
                .font(BBBFont.font(size: 15, weight: .medium))
                .foregroundStyle(DesignToken.textSecondary)

                Spacer()

                Text("调整喂养时间")
                    .font(BBBFont.font(size: 16, weight: .bold))
                    .foregroundStyle(DesignToken.textPrimary)

                Spacer()

                Button("确认") {
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                        // currentTime already bound to DatePicker
                    }
                    persistDraft()
                    showRecordTimePicker = false
                }
                .font(BBBFont.font(size: 15, weight: .bold))
                .foregroundStyle(DesignToken.primary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            Divider()
                .padding(.horizontal, 16)

            DatePicker(
                "",
                selection: Binding(
                    get: { recordTime },
                    set: {
                        recordTime = min($0, Date())
                        hasManualTimeSpan = false
                    }
                ),
                in: ...Date(),
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .environment(\.locale, Locale(identifier: "zh_Hans_CN"))
            .padding(.horizontal, 8)
            .padding(.top, 4)
        }
        .background(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(Color.white.opacity(0.14))
        )
    }

    private var timeSpanConfirmationSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("确认喂养时段")
                        .font(BBBFont.font(size: 18, weight: .heavy))
                        .foregroundStyle(DesignToken.textPrimary)
                    Text(timeSpanConfirmationSubtitle)
                        .font(BBBFont.font(size: 12, weight: .bold))
                        .foregroundStyle(DesignToken.textSecondary)
                }

                Spacer()

                Button {
                    showTimeSpanConfirmation = false
                    pendingSave = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(DesignToken.textSecondary)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(.white.opacity(0.72)))
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 10) {
                DatePicker(
                    "开始",
                    selection: Binding(
                        get: { timeSpanStart },
                        set: { timeSpanStart = min($0, timeSpanEnd) }
                    ),
                    in: ...timeSpanEnd,
                    displayedComponents: [.date, .hourAndMinute]
                )
                DatePicker(
                    "结束",
                    selection: Binding(
                        get: { timeSpanEnd },
                        set: {
                            let newEnd = min($0, Date())
                            timeSpanEnd = max(newEnd, timeSpanStart)
                        }
                    ),
                    in: timeSpanStart...Date(),
                    displayedComponents: [.date, .hourAndMinute]
                )
            }
            .font(BBBFont.font(size: 14, weight: .bold))
            .datePickerStyle(.compact)
            .environment(\.locale, Locale(identifier: "zh_Hans_CN"))
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.white.opacity(0.76))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.84), lineWidth: 1))
            )

            Text("首页和统计分析会按这个时间段绘制节奏。")
                .font(BBBFont.font(size: 12, weight: .semibold))
                .foregroundStyle(DesignToken.textSecondary)

            HStack(spacing: 12) {
                Button {
                    completePendingSave(confirmTimeSpan: false)
                } label: {
                    Text("跳过")
                        .font(BBBFont.font(size: 15, weight: .heavy))
                        .foregroundStyle(DesignToken.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Capsule(style: .continuous).fill(.white.opacity(0.66)))
                }
                .buttonStyle(.plain)

                Button {
                    completePendingSave(confirmTimeSpan: true)
                } label: {
                    Text("确认")
                        .font(BBBFont.font(size: 15, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Capsule(style: .continuous).fill(selectedKind.accent))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 22)
        .padding(.bottom, 18)
        .background(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(Color.white.opacity(0.14))
        )
    }

    private var timeSpanConfirmationSubtitle: String {
        guard let pendingSave else { return "根据当前记录生成预计时段" }
        let span = pendingSave.session.resolvedTimeSpan(ageMonths: profileStore.currentProfile.ageMonths)
        switch span.source {
        case .confirmed:
            return "使用已确认的时段"
        case .recordedDuration:
            return "根据已记录时长生成"
        case .estimated, .estimatedSkipped:
            return "根据月龄和喂养量推测，可手动调整"
        case .point:
            return "当前记录缺少可推算的时长"
        }
    }

    private func prepareManualTimeSpanDefaults(force: Bool) {
        guard force || !hasManualTimeSpan else { return }
        let previewSession = FeedingSession(
            entries: finalFeedingEntries(),
            notes: "",
            imageData: imageData,
            babyMood: mood,
            createdAt: recordTime
        )
        let span = previewSession.resolvedTimeSpan(ageMonths: profileStore.currentProfile.ageMonths)
        manualTimeSpanStart = span.startAt
        manualTimeSpanEnd = max(span.endAt, span.startAt)
    }

    private var solidStage: some View {
        VStack(spacing: isCompactHeight ? 9 : 14) {
            VStack(spacing: isCompactHeight ? 5 : 8) {
                Text(selectedKind.emoji)
                    .font(.system(size: isCompactHeight ? 38 : 48))
                    .frame(width: isCompactHeight ? 78 : 102, height: isCompactHeight ? 78 : 102)
                    .background(Circle().fill(selectedKind.accent.opacity(0.14)))

                Text(selectedKind.label)
                    .font(BBBFont.font(size: 14, weight: .semibold))
                    .foregroundStyle(DesignToken.textSecondary)
            }

            AmountStepperControl(
                value: solidAmountBinding,
                range: 5...300,
                step: 5,
                unit: solidUnit.displayName,
                tint: selectedKind.accent,
                isCompactHeight: isCompactHeight
            )

            Picker("单位", selection: solidUnitBinding) {
                ForEach(SolidUnit.allCases) { unit in
                    Text(unit.displayName).tag(unit)
                }
            }
            .pickerStyle(.menu)
            .tint(selectedKind.accent)
        }
        .padding(.vertical, isCompactHeight ? 10 : 16)
        .padding(.horizontal, 14)
        .background(cardBackground)
    }

    private var kindCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach([FeedingKind.nursing, .bottle, .solids]) { kind in
                    Button {
                        selectKind(kind)
                    } label: {
                        VStack(spacing: 7) {
                            Text(kind.emoji)
                                .font(.system(size: isCompactHeight ? 22 : 25))
                            Text(kind.label)
                                .font(BBBFont.font(size: isCompactHeight ? 14 : 16, weight: .heavy))
                                .lineLimit(1)
                        }
                        .foregroundStyle(selectedKind == kind ? .white : DesignToken.textSecondary)
                        .frame(width: isCompactHeight ? 72 : 84, height: isCompactHeight ? 66 : 76)
                        .background(
                            RoundedRectangle(cornerRadius: 21, style: .continuous)
                                .fill(selectedKind == kind ? kind.accent : Color.white.opacity(0.76))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 21, style: .continuous)
                                        .stroke(.white.opacity(selectedKind == kind ? 0.70 : 0.86), lineWidth: 1.2)
                                )
                                .shadow(color: DesignToken.textStrong.opacity(selectedKind == kind ? 0.14 : 0.06), radius: 15, y: 7)
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .padding(.horizontal, isCompactHeight ? 10 : 14)
            .padding(.vertical, 4)
        }
        .padding(.horizontal, isCompactHeight ? -14 : -16)
    }

    private var moreInfoPopover: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("更多信息")
                    .font(BBBFont.font(size: 16, weight: .bold))
                    .foregroundStyle(DesignToken.textPrimary)
                Spacer()
                Button {
                    showMoreInfo = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(DesignToken.textSecondary)
                        .frame(width: 28, height: 28)
                        .glassEffect(.regular.tint(Color.white.opacity(0.34)).interactive(), in: .circle)
                }
                .buttonStyle(ScaleButtonStyle())
            }

            manualTimeSpanSection
            notesAndPhoto
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(Color.white.opacity(0.16))
        )
    }

    private func extraActionButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(BBBFont.font(size: 14, weight: .semibold))
                .foregroundStyle(DesignToken.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var manualTimeSpanSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("精确时间段", systemImage: "clock.badge.checkmark")
                    .font(BBBFont.font(size: 15, weight: .bold))
                    .foregroundStyle(DesignToken.textPrimary)

                Spacer()

                if hasManualTimeSpan {
                    Button("清除") {
                        hasManualTimeSpan = false
                        prepareManualTimeSpanDefaults(force: true)
                    }
                    .font(BBBFont.font(size: 12, weight: .bold))
                    .foregroundStyle(DesignToken.textSecondary)
                }
            }

            VStack(spacing: 10) {
                DatePicker(
                    "开始",
                    selection: Binding(
                        get: { manualTimeSpanStart },
                        set: {
                            hasManualTimeSpan = true
                            manualTimeSpanStart = min($0, manualTimeSpanEnd)
                        }
                    ),
                    in: ...manualTimeSpanEnd,
                    displayedComponents: [.date, .hourAndMinute]
                )

                DatePicker(
                    "结束",
                    selection: Binding(
                        get: { manualTimeSpanEnd },
                        set: {
                            hasManualTimeSpan = true
                            let newEnd = min($0, Date())
                            manualTimeSpanEnd = max(newEnd, manualTimeSpanStart)
                            recordTime = manualTimeSpanEnd
                        }
                    ),
                    in: manualTimeSpanStart...Date(),
                    displayedComponents: [.date, .hourAndMinute]
                )
            }
            .font(BBBFont.font(size: 14, weight: .bold))
            .datePickerStyle(.compact)
            .environment(\.locale, Locale(identifier: "zh_Hans_CN"))
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.56))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(hasManualTimeSpan ? 0.80 : 0.56), lineWidth: 1)
                    )
            )

            Text(hasManualTimeSpan ? "保存时优先使用这个时间段。" : "未手动设置时，保存会按时长或喂养量生成预计时间段。")
                .font(BBBFont.font(size: 11, weight: .semibold))
                .foregroundStyle(DesignToken.textSecondary)
        }
    }

    private var moodSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("宝宝反应")
                .font(BBBFont.font(size: 14, weight: .semibold))
                .foregroundStyle(DesignToken.textSecondary)
            HStack(spacing: 10) {
                ForEach(BabyMood.allCases, id: \.self) { item in
                    Button {
                        mood = item
                    } label: {
                        Text(item.rawValue)
                            .font(.system(size: 28))
                            .frame(width: 50, height: 40)
                            .background(Capsule().fill(mood == item ? DesignToken.primary.opacity(0.16) : DesignToken.iconSoftBG))
                            .overlay(Capsule().stroke(mood == item ? DesignToken.primary.opacity(0.55) : .clear, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var notesAndPhoto: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("图片", systemImage: "photo.fill")
                .font(BBBFont.font(size: 15, weight: .bold))
                .foregroundStyle(DesignToken.textPrimary)

            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Label(imageData == nil ? "添加图片" : "已选择图片", systemImage: "photo.fill")
                    .font(BBBFont.font(size: 14, weight: .semibold))
                    .foregroundStyle(DesignToken.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.42))
                            .overlay(Capsule(style: .continuous).stroke(Color.white.opacity(0.56), lineWidth: 1))
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private var entriesPreview: some View {
        Group {
            if !entries.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("本次记录", systemImage: "list.bullet.clipboard.fill")
                            .font(BBBFont.font(size: 15, weight: .bold))
                            .foregroundStyle(DesignToken.textPrimary)
                        Spacer()
                        Text("\(entries.count) 条")
                            .font(BBBFont.font(size: 14, weight: .semibold))
                            .foregroundStyle(DesignToken.textSecondary)
                    }

                ForEach(entries) { entry in
                    HStack(spacing: 12) {
                        Image(systemName: entryIcon(entry))
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(entryColor(entry))
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(entryColor(entry).opacity(0.14)))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entrySummary(entry))
                                .font(BBBFont.font(size: 15, weight: .semibold))
                                .foregroundStyle(DesignToken.textPrimary)
                            Text("本次喂养")
                                .font(BBBFont.font(size: 12, weight: .regular))
                                .foregroundStyle(DesignToken.textSecondary)
                        }
                        Spacer()
                        Button(role: .destructive) {
                            entries.removeAll { $0.id == entry.id }
                            persistDraft()
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(DesignToken.iconSoftBG))
                }
                }
                .padding(14)
                .background(cardBackground)
            }
        }
    }

    private var manualBreastInputSheet: some View {
        NavigationStack {
            Form {
                Section("左右侧时长") {
                    manualMinutesControl(title: "左乳", value: $manualLeftMinutes)
                    manualMinutesControl(title: "右乳", value: $manualRightMinutes)
                }
                Section {
                    Button {
                        submitManualBreastInput()
                    } label: {
                        Text("应用到当前计时")
                            .font(BBBFont.font(size: 17, weight: .bold))
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("手动输入")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { showManualBreastInput = false }
                }
            }
            .alert("覆盖当前亲喂时间？", isPresented: $showManualBreastOverwriteConfirmation) {
                Button("取消", role: .cancel) {}
                Button("覆盖", role: .destructive) {
                    applyManualBreastInput()
                }
            } message: {
                Text("当前已有左右胸计时记录，手动输入会替换现有时长。")
            }
        }
        .presentationDetents([.medium])
    }

    private var customBottleAmountSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        TextField("0", text: $customBottleAmountText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .font(BBBFont.font(size: 42, weight: .heavy))
                            .foregroundStyle(DesignToken.textPrimary)
                            .frame(width: 128)
                        Text("ml")
                            .font(BBBFont.font(size: 30, weight: .heavy))
                            .foregroundStyle(DesignToken.textPrimary)
                    }

                    Text("自定义量")
                        .font(BBBFont.font(size: 14, weight: .bold))
                        .foregroundStyle(DesignToken.textSecondary)
                }
                .padding(.top, 24)

                Button {
                    applyCustomBottleAmount()
                } label: {
                    Label("应用自定义量", systemImage: "checkmark.circle.fill")
                        .font(BBBFont.font(size: 17, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Capsule(style: .continuous).fill(selectedKind.accent))
                }
                .buttonStyle(ScaleButtonStyle())

                Spacer()
            }
            .padding(.horizontal, 28)
            .navigationTitle("自定义量")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { showCustomBottleAmount = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func manualMinutesControl(title: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int(value.wrappedValue)) 分钟")
                    .fontWeight(.bold)
                    .foregroundStyle(FeedingType.breast.accent)
            }
            Slider(value: value, in: 0...60, step: 1)
                .tint(FeedingType.breast.accent)
            Stepper("调整", value: value, in: 0...60, step: 1)
                .labelsHidden()
        }
    }

    private var bottomDock: some View {
        VStack(spacing: isCompactHeight ? 6 : 10) {
            kindCarousel

            HStack(spacing: 12) {
                Button {
                    save()
                } label: {
                    Label("保存记录", systemImage: "checkmark.circle.fill")
                        .font(BBBFont.font(size: 16, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: isCompactHeight ? 48 : 54)
                        .background(
                            Capsule(style: .continuous)
                                .fill(canSave ? appGradient : LinearGradient(colors: [.gray.opacity(0.58), .gray.opacity(0.58)], startPoint: .leading, endPoint: .trailing))
                        )
                }
                .disabled(!canSave)
                .buttonStyle(ScaleButtonStyle())

                Button {
                    showMoreInfo = true
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundStyle(DesignToken.textSecondary)
                        .frame(width: isCompactHeight ? 48 : 54, height: isCompactHeight ? 48 : 54)
                        .background(Circle().fill(.white.opacity(0.94)))
                }
                .buttonStyle(ScaleButtonStyle())
            }
            .padding(isCompactHeight ? 6 : 8)
            .background(
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(Capsule(style: .continuous).stroke(.white.opacity(0.7), lineWidth: 1))
                    .shadow(color: DesignToken.textStrong.opacity(0.15), radius: 18, y: 8)
            )
        }
        .padding(.horizontal, isCompactHeight ? 14 : 16)
        .padding(.bottom, isCompactHeight ? 8 : 12)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(.white.opacity(0.94))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(.white.opacity(0.84), lineWidth: 1.2)
            )
            .shadow(color: DesignToken.easyEat.opacity(0.06), radius: 12, y: 5)
    }

    private var appGradient: LinearGradient {
        DesignToken.primaryGradient
    }

    private var leftSeconds: Int { breastSeconds(for: .left) }
    private var rightSeconds: Int { breastSeconds(for: .right) }
    private var totalBottleMinutes: Double { draftStore.totalBottleMinutes }

    private var canSave: Bool {
        recordTime <= Date() && (!entries.isEmpty || leftSeconds + rightSeconds > 0 || (type == .bottle && bottleAmount > 0) || (type == .solid && solidAmount > 0))
    }

    private var manualButtonTitle: String {
        switch selectedKind {
        case .nursing: return "手动输入"
        case .bottle: return "自定义量"
        default: return "调整分量"
        }
    }

    private var primarySummary: String {
        switch selectedKind {
        case .nursing:
            return durationText(leftSeconds + rightSeconds)
        case .bottle:
            return "\(Int(bottleAmount))ml"
        default:
            return "\(Int(solidAmount))\(solidUnit.displayName)"
        }
    }

    private var secondarySummary: String {
        switch selectedKind {
        case .nursing:
            return "亲喂时长 · \(lastIntervalText)"
        case .bottle:
            let duration = totalBottleMinutes > 0 ? " · \(max(Int(totalBottleMinutes), 1))分钟" : ""
            return "\(milkType.displayName)量\(duration) · \(lastIntervalText)"
        default:
            return "\(selectedKind.label)分量 · \(lastIntervalText)"
        }
    }

    private var moreInfoSummary: String {
        var parts: [String] = []
        if imageData != nil {
            parts.append("有图片")
        }
        if mood != .happy {
            parts.append("已选反应")
        }
        return parts.isEmpty ? "可选" : parts.joined(separator: " · ")
    }

    private var lastIntervalText: String {
        guard let last = feedingStore.lastFeedingTime() else { return "距上次喂养暂无" }
        let minutes = max(Int(recordTime.timeIntervalSince(last) / 60), 0)
        if minutes < 60 { return "距上次喂养\(minutes)分钟" }
        return "距上次喂养\(minutes / 60)时\(minutes % 60)分"
    }

    private var lastIntervalStatText: String {
        guard let last = feedingStore.lastFeedingTime() else { return "暂无" }
        let minutes = max(Int(recordTime.timeIntervalSince(last) / 60), 0)
        if minutes < 60 { return "\(minutes)分钟" }
        return "\(minutes / 60)时\(minutes % 60)分"
    }

    private func breastTimer(_ side: BreastSide, seconds: Int) -> some View {
        Button { toggleBreastTimer(side) } label: {
            VStack(spacing: 10) {
                ZStack {
                    Circle().stroke(DesignToken.borderSubtle.opacity(0.68), lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: min(Double(seconds) / 1800, 1))
                        .stroke(FeedingType.breast.accent, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 5) {
                        Text(side.displayName)
                            .font(BBBFont.font(size: 14, weight: .bold))
                            .foregroundStyle(DesignToken.textSecondary)
                        Text(durationText(seconds))
                            .font(BBBFont.font(size: 20, weight: .bold))
                            .foregroundStyle(DesignToken.textPrimary)
                        Image(systemName: activeBreastSide == side ? "pause.fill" : "play.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(FeedingType.breast.accent)
                    }
                }
                .frame(height: 120)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(activeBreastSide == side ? DesignToken.primary.opacity(0.12) : DesignToken.iconSoftBG))
        }
        .buttonStyle(.plain)
    }

    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func breastSeconds(for side: BreastSide, at date: Date = Date()) -> Int {
        draftStore.breastSeconds(for: side, at: date)
    }

    private func toggleBreastTimer(_ side: BreastSide) {
        let now = Date()
        if activeBreastSide == side {
            commitActiveBreastElapsed(at: now)
            activeBreastSide = nil
            activeBreastStartAt = nil
        } else {
            commitActiveBreastElapsed(at: now)
            activeBreastSide = side
            activeBreastStartAt = now
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        persistDraft()
    }

    private func commitActiveBreastElapsed(at date: Date = Date()) {
        guard let activeBreastSide, let activeBreastStartAt else { return }
        let elapsed = max(Int(date.timeIntervalSince(activeBreastStartAt)), 0)
        switch activeBreastSide {
        case .left:
            leftBaseSeconds += elapsed
        case .right:
            rightBaseSeconds += elapsed
        }
        self.activeBreastStartAt = date
    }

    private func toggleBottleTimer() {
        let now = Date()
        if let started = bottleTimerStartedAt {
            bottleMinutes += max(now.timeIntervalSince(started) / 60, 0)
            bottleTimerStartedAt = nil
        } else {
            bottleTimerStartedAt = now
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        persistDraft()
    }

    private func toggleBottleMilkType() {
        milkType = milkType == .formula ? .expressed : .formula
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        persistDraft()
    }

    private func setBottleMilkType(_ item: MilkType) {
        guard milkType != item else { return }
        milkType = item
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        persistDraft()
    }

    private func commitBottleElapsed(at date: Date = Date()) {
        guard let bottleTimerStartedAt else { return }
        bottleMinutes += max(date.timeIntervalSince(bottleTimerStartedAt) / 60, 0)
        self.bottleTimerStartedAt = date
    }

    private func checkBreastMilestones() {
        guard let activeBreastSide else { return }
        checkMilestone(breastSeconds(for: activeBreastSide, at: currentTime))
    }

    private func checkMilestone(_ seconds: Int) {
        let milestones = [600, 900, 1200]
        guard milestones.contains(seconds), !hitMilestones.contains(seconds) else { return }
        hitMilestones.insert(seconds)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        persistDraft()
    }

    private func openManualInput() {
        guard type == .breast else { return }
        manualLeftMinutes = Double(max(leftSeconds / 60, 0))
        manualRightMinutes = Double(max(rightSeconds / 60, 0))
        showManualBreastInput = true
    }

    private func setBreastMinutes(_ side: BreastSide, minutes: Int) {
        let clampedMinutes = min(max(minutes, 5), 30)
        commitActiveBreastElapsed()
        withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
            switch side {
            case .left:
                leftBaseSeconds = clampedMinutes * 60
            case .right:
                rightBaseSeconds = clampedMinutes * 60
            }
        }
        if activeBreastSide == side {
            activeBreastStartAt = Date()
        }
        hitMilestones.removeAll()
        persistDraft()
    }

    private var hasBreastTimingRecord: Bool {
        leftSeconds > 0 || rightSeconds > 0 || activeBreastSide != nil
    }

    private func requestBreastPreset(minutes: Int) {
        if hasBreastTimingRecord {
            pendingBreastPresetMinutes = minutes
            showBreastPresetOverwriteConfirmation = true
        } else {
            applyBreastPreset(minutes: minutes)
        }
    }

    private func applyBreastPreset(minutes: Int) {
        let clampedMinutes = min(max(minutes, 5), 30)
        commitActiveBreastElapsed()
        withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
            leftBaseSeconds = clampedMinutes * 60
            rightBaseSeconds = clampedMinutes * 60
            activeBreastSide = nil
            activeBreastStartAt = nil
            hitMilestones.removeAll()
        }
        persistDraft()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func submitManualBreastInput() {
        if hasBreastTimingRecord {
            showManualBreastOverwriteConfirmation = true
        } else {
            applyManualBreastInput()
        }
    }

    private func applyManualBreastInput() {
        leftBaseSeconds = Int(manualLeftMinutes * 60)
        rightBaseSeconds = Int(manualRightMinutes * 60)
        activeBreastSide = nil
        activeBreastStartAt = nil
        hitMilestones.removeAll()
        persistDraft()
        showManualBreastInput = false
    }

    private func openManualEntry() {
        switch selectedKind {
        case .nursing:
            openManualInput()
        case .bottle:
            customBottleAmountText = "\(Int(bottleAmount))"
            showCustomBottleAmount = true
        default:
            solidAmount = min(300, solidAmount + 5)
            persistDraft()
        }
    }

    private func selectKind(_ kind: FeedingKind) {
        guard kind != selectedKind else { return }

        if kind != .nursing {
            commitActiveBreastElapsed()
            activeBreastSide = nil
            activeBreastStartAt = nil
        }

        withAnimation(.spring(response: 0.32, dampingFraction: 0.80)) {
            selectedKind = kind
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        switch kind {
        case .nursing:
            type = .breast
            breastMode = .nursing
        case .bottle:
            type = .bottle
        case .solids:
            type = .solid
        case .rice, .porridge, .vegetable, .fruit, .meat, .fish, .egg, .noodle, .yogurt:
            type = .solid
            if let food = kind.solidFood {
                selectedSolidFoods = [food]
            }
        }
        persistDraft()
    }

    private var solidFoodSummary: String {
        let foods = selectedSolidFoods
        if foods.count <= 2 {
            return foods.map(\.displayName).joined(separator: "、")
        }
        return foods.prefix(2).map(\.displayName).joined(separator: "、") + "等\(foods.count)种"
    }

    private func toggleSolidFood(_ food: SolidFood) {
        var foods = selectedSolidFoods
        if let index = foods.firstIndex(of: food) {
            guard foods.count > 1 else { return }
            foods.remove(at: index)
        } else {
            foods.append(food)
        }
        withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
            selectedSolidFoods = foods
        }
        persistDraft()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func normalizedSolidFoods(_ foods: [SolidFood]) -> [SolidFood] {
        var seen: Set<SolidFood> = []
        let normalized = foods.filter { seen.insert($0).inserted }
        return normalized.isEmpty ? [.rice] : normalized
    }

    private func applyCustomBottleAmount() {
        let filtered = customBottleAmountText.filter(\.isNumber)
        let value = Double(filtered) ?? 0
        bottleAmount = min(max(value, bottleRange.lowerBound), bottleRange.upperBound)
        persistDraft()
        showCustomBottleAmount = false
    }

    private func entrySummary(_ entry: FeedingEntry) -> String {
        switch entry.type {
        case .breast:
            let mode = entry.breastMode?.displayName ?? "亲喂"
            return "\(mode) \(entry.breastSide?.displayName ?? "") \(entry.breastDuration ?? 0)分钟"
        case .bottle:
            let name = entry.milkType?.displayName ?? "奶瓶"
            let minutes = entry.bottleDuration.map { " · \($0)分钟" } ?? ""
            return "\(name) \(entry.bottleAmount ?? 0)ml\(minutes)"
        case .solid:
            return "\(entry.solidFood?.emoji ?? "🍽️") \(entry.solidFood?.displayName ?? "辅食") \(Int(entry.solidAmount ?? 0))\(entry.solidUnit?.displayName ?? "g")"
        }
    }

    private func entryIcon(_ entry: FeedingEntry) -> String {
        switch entry.type {
        case .breast: return "heart.fill"
        case .bottle: return "babybottle.fill"
        case .solid: return "fork.knife"
        }
    }

    private func entryColor(_ entry: FeedingEntry) -> Color {
        switch entry.type {
        case .breast: return FeedingType.breast.accent
        case .bottle: return FeedingType.bottle.accent
        case .solid: return FeedingType.solid.accent
        }
    }

    private func durationText(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    private func loadSelectedPhoto() async {
        guard let selectedPhoto,
              let data = try? await selectedPhoto.loadTransferable(type: Data.self),
              let image = UIImage(data: data),
              let jpeg = image.jpegData(compressionQuality: 0.8) else {
            return
        }
        imageData = jpeg
        persistDraft()
    }

    private func save() {
        guard recordTime <= Date() else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        commitActiveBreastElapsed()
        if bottleTimerStartedAt != nil { commitBottleElapsed() }
        let finalEntries = finalFeedingEntries()
        guard !finalEntries.isEmpty else { return }

        let session = FeedingSession(
            entries: finalEntries,
            notes: "",
            imageData: imageData,
            babyMood: mood,
            createdAt: recordTime
        )

        if hasManualTimeSpan, manualTimeSpanEnd > manualTimeSpanStart {
            completeSave(
                FeedingSession(
                    id: session.id,
                    entries: session.entries,
                    notes: session.notes,
                    imageData: session.imageData,
                    babyMood: session.babyMood,
                    createdAt: manualTimeSpanEnd,
                    startAt: manualTimeSpanStart,
                    endAt: manualTimeSpanEnd,
                    timeSpanSource: .confirmed
                )
            )
            return
        }

        let resolvedSpan = session.resolvedTimeSpan(ageMonths: profileStore.currentProfile.ageMonths)
        pendingSave = PendingFeedingSave(session: session)
        timeSpanStart = resolvedSpan.startAt
        timeSpanEnd = resolvedSpan.endAt
        showTimeSpanConfirmation = true
    }

    private func finalFeedingEntries() -> [FeedingEntry] {
        var finalEntries = entries

        if type == .breast {
            if leftSeconds > 0 {
                finalEntries.append(FeedingEntry(type: .breast, breastMode: .nursing, breastSide: .left, breastDuration: max(leftSeconds / 60, 1)))
            }
            if rightSeconds > 0 {
                finalEntries.append(FeedingEntry(type: .breast, breastMode: .nursing, breastSide: .right, breastDuration: max(rightSeconds / 60, 1)))
            }
        }

        if type == .bottle, bottleAmount > 0 {
            finalEntries.append(FeedingEntry(type: .bottle, milkType: milkType, bottleAmount: Int(bottleAmount), bottleDuration: totalBottleMinutes > 0 ? max(Int(totalBottleMinutes), 1) : nil))
        }

        if type == .solid, solidAmount > 0 {
            let foods = selectedSolidFoods
            let amountPerFood = solidAmount / Double(max(foods.count, 1))
            finalEntries.append(contentsOf: foods.map { food in
                FeedingEntry(type: .solid, solidFood: food, solidAmount: amountPerFood, solidUnit: solidUnit)
            })
        }

        return finalEntries
    }

    private func completePendingSave(confirmTimeSpan: Bool) {
        guard let pendingSave else { return }
        let resolvedSpan = pendingSave.session.resolvedTimeSpan(ageMonths: profileStore.currentProfile.ageMonths)
        let selectedStart = min(timeSpanStart, timeSpanEnd)
        let selectedEnd = max(timeSpanStart, timeSpanEnd)
        let hasSelectedSpan = selectedEnd > selectedStart
        let source: FeedingTimeSpanSource

        if confirmTimeSpan, hasSelectedSpan {
            source = .confirmed
        } else if resolvedSpan.source.isEstimated, resolvedSpan.endAt > resolvedSpan.startAt {
            source = .estimatedSkipped
        } else {
            source = resolvedSpan.source
        }

        let shouldStoreSpan = hasSelectedSpan || resolvedSpan.endAt > resolvedSpan.startAt
        let startToStore = hasSelectedSpan ? selectedStart : resolvedSpan.startAt
        let endToStore = hasSelectedSpan ? selectedEnd : resolvedSpan.endAt

        let session = FeedingSession(
            id: pendingSave.session.id,
            entries: pendingSave.session.entries,
            notes: "",
            imageData: pendingSave.session.imageData,
            babyMood: pendingSave.session.babyMood,
            createdAt: endToStore,
            startAt: shouldStoreSpan ? startToStore : nil,
            endAt: shouldStoreSpan ? endToStore : nil,
            timeSpanSource: source
        )

        completeSave(session)
        self.pendingSave = nil
        showTimeSpanConfirmation = false
    }

    private func completeSave(_ session: FeedingSession) {
        feedingStore.saveSession(session)
        didSave = true
        draftStore.resetDraft()
        didSave = true
        hasManualTimeSpan = false
        isPresented = false
    }
}

private struct PendingFeedingSave: Identifiable {
    let id = UUID()
    let session: FeedingSession
}

private enum FeedingKind: String, CaseIterable, Identifiable {
    case nursing
    case bottle
    case solids
    case rice
    case porridge
    case vegetable
    case fruit
    case meat
    case fish
    case egg
    case noodle
    case yogurt

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .nursing: return "🤱"
        case .bottle: return "🍼"
        case .solids: return "🥣"
        case .rice: return "🍚"
        case .porridge: return "🥣"
        case .vegetable: return "🥬"
        case .fruit: return "🍎"
        case .meat: return "🥩"
        case .fish: return "🐟"
        case .egg: return "🥚"
        case .noodle: return "🍜"
        case .yogurt: return "🥛"
        }
    }

    var label: String {
        switch self {
        case .nursing: return "亲喂"
        case .bottle: return "瓶喂"
        case .solids: return "辅食"
        case .rice: return "米糊"
        case .porridge: return "粥"
        case .vegetable: return "蔬菜"
        case .fruit: return "水果"
        case .meat: return "肉泥"
        case .fish: return "鱼肉"
        case .egg: return "鸡蛋"
        case .noodle: return "面条"
        case .yogurt: return "酸奶"
        }
    }

    var title: String {
        "\(emoji) \(label)"
    }

    var accent: Color {
        switch self {
        case .nursing: return FeedingType.breast.accent
        case .bottle: return FeedingType.bottle.accent
        default: return FeedingType.solid.accent
        }
    }

    var solidFood: SolidFood? {
        switch self {
        case .nursing, .bottle, .solids:
            return nil
        case .rice:
            return .rice
        case .porridge:
            return .porridge
        case .vegetable:
            return .vegetable
        case .fruit:
            return .fruit
        case .meat:
            return .meat
        case .fish:
            return .fish
        case .egg:
            return .egg
        case .noodle:
            return .noodle
        case .yogurt:
            return .yogurt
        }
    }

    static func kindFor(type: FeedingType, solidFood: SolidFood) -> FeedingKind {
        switch type {
        case .breast:
            return .nursing
        case .bottle:
            return .bottle
        case .solid:
            return .solids
        }
    }
}

private struct BottleAmountReadout: View {
    let amount: Double
    let unit: String
    let S: CGFloat
    @State private var isPulsing = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 2 * S) {
            Text("\(Int(amount))")
                .font(BBBFont.font(size: 36 * S, weight: .bold))
                .contentTransition(.numericText(value: amount))

            Text(unit)
                .font(BBBFont.font(size: 18 * S, weight: .medium))
        }
        .foregroundStyle(DesignToken.feedingBottle)
        .monospacedDigit()
        .scaleEffect(isPulsing ? 1.055 : 1)
        .shadow(color: DesignToken.easyEat.opacity(isPulsing ? 0.20 : 0), radius: 10 * S, y: 2 * S)
        .animation(.spring(response: 0.22, dampingFraction: 0.68), value: isPulsing)
        .animation(.spring(response: 0.24, dampingFraction: 0.78), value: amount)
        .onChange(of: amount) { _, _ in
            isPulsing = true
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 150_000_000)
                isPulsing = false
            }
        }
    }
}

struct InteractiveBottleView: View {
    @Binding var amount: Double
    let range: ClosedRange<Double>
    let step: Double
    let tint: Color
    @State private var fillPulse = false

    private let bottleFillTop: CGFloat = 0.44
    private let bottleFillBottom: CGFloat = 0.954

    private var progress: Double {
        guard range.upperBound > range.lowerBound else { return 0 }
        return min(max((amount - range.lowerBound) / (range.upperBound - range.lowerBound), 0), 1)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                Image("feeding_bottle_empty")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .opacity(0.8)

                Image("feeding_bottle_full")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .scaleEffect(fillPulse ? 1.012 : 1, anchor: .bottom)
                    .mask(alignment: .bottom) {
                        BottleMilkMask(
                            progress: progress,
                            topRatio: bottleFillTop,
                            bottomRatio: bottleFillBottom
                        )
                    }
                    .opacity(0.8)
                    .allowsHitTesting(false)
                    .animation(.spring(response: 0.32, dampingFraction: 0.82), value: progress)

                BottleMilkSurfaceGlow(
                    progress: progress,
                    topRatio: bottleFillTop,
                    bottomRatio: bottleFillBottom,
                    tint: tint
                )
                .opacity(progress > 0.02 ? (fillPulse ? 0.58 : 0.30) : 0)
                .animation(.spring(response: 0.28, dampingFraction: 0.78), value: progress)
                .animation(.easeOut(duration: 0.16), value: fillPulse)
                .allowsHitTesting(false)

                Image("feeding_bottle_empty")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .blendMode(.multiply)
                    .opacity(0.34)
                    .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let fillTop = proxy.size.height * bottleFillTop
                        let fillBottom = proxy.size.height * bottleFillBottom
                        let ratio = 1 - min(max((value.location.y - fillTop) / max(fillBottom - fillTop, 1), 0), 1)
                        let rawValue = range.lowerBound + ratio * (range.upperBound - range.lowerBound)
                        withAnimation(.spring(response: 0.24, dampingFraction: 0.78)) {
                            amount = snapped(rawValue)
                        }
                    }
            )
        }
        .accessibilityLabel("奶瓶量")
        .accessibilityValue("\(Int(amount))ml")
        .onChange(of: amount) { _, _ in
            fillPulse = true
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 170_000_000)
                fillPulse = false
            }
        }
    }

    private func snapped(_ value: Double) -> Double {
        let snappedValue = (value / step).rounded() * step
        return min(max(snappedValue, range.lowerBound), range.upperBound)
    }
}

private struct BottleMilkMask: Shape {
    var progress: Double
    let topRatio: CGFloat
    let bottomRatio: CGFloat

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let clamped = min(max(progress, 0), 1)
        let fillTopLimit = rect.minY + rect.height * topRatio
        let fillBottom = rect.minY + rect.height * bottomRatio
        let fillTop = fillBottom - (fillBottom - fillTopLimit) * clamped
        let wave = rect.height * 0.01

        path.move(to: CGPoint(x: rect.minX, y: fillBottom))
        path.addLine(to: CGPoint(x: rect.minX, y: fillTop))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: fillTop),
            control1: CGPoint(x: rect.minX + rect.width * 0.38, y: fillTop + wave),
            control2: CGPoint(x: rect.minX + rect.width * 0.62, y: fillTop - wave)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: fillBottom))
        path.closeSubpath()
        return path
    }
}

private struct BottleMilkSurfaceGlow: View {
    let progress: Double
    let topRatio: CGFloat
    let bottomRatio: CGFloat
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            let clamped = min(max(progress, 0), 1)
            let fillTopLimit = proxy.size.height * topRatio
            let fillBottom = proxy.size.height * bottomRatio
            let y = fillBottom - (fillBottom - fillTopLimit) * clamped

            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.34),
                            tint.opacity(0.18),
                            Color.white.opacity(0.10)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: proxy.size.width * 0.58, height: max(2, proxy.size.height * 0.009))
                .blur(radius: proxy.size.height * 0.002)
                .position(x: proxy.size.width * 0.50, y: y)
        }
    }
}

private struct BottleAmountScrubber: View {
    @Binding var amount: Double
    let range: ClosedRange<Double>
    let step: Double
    let tint: Color
    let isCompactHeight: Bool

    var body: some View {
        HStack(spacing: 30) {
            Button {
                amount = max(range.lowerBound, amount - step)
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 25, weight: .heavy))
                    .frame(width: 54, height: 54)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .overlay(Circle().fill(Color.white.opacity(0.32)))
                            .overlay(Circle().stroke(.white.opacity(0.78), lineWidth: 1.1))
                            .shadow(color: tint.opacity(0.16), radius: 16, y: 7)
                    )
            }

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(Int(amount))")
                    .font(BBBFont.font(size: isCompactHeight ? 42 : 48, weight: .heavy))
                Text("ml")
                    .font(BBBFont.font(size: isCompactHeight ? 24 : 28, weight: .heavy))
            }
                .foregroundStyle(DesignToken.textPrimary)
                .frame(minWidth: isCompactHeight ? 98 : 112)

            Button {
                amount = min(range.upperBound, amount + step)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 27, weight: .heavy))
                    .frame(width: 54, height: 54)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .overlay(Circle().fill(Color.white.opacity(0.32)))
                            .overlay(Circle().stroke(.white.opacity(0.78), lineWidth: 1.1))
                            .shadow(color: tint.opacity(0.16), radius: 16, y: 7)
                    )
            }
        }
        .foregroundStyle(tint)
        .gesture(
            DragGesture(minimumDistance: 12)
                .onEnded { value in
                    if value.translation.width < -18 {
                        amount = min(range.upperBound, amount + step)
                    } else if value.translation.width > 18 {
                        amount = max(range.lowerBound, amount - step)
                    }
                }
        )
    }
}

private struct AmountStepperControl: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let unit: String
    let tint: Color
    let isCompactHeight: Bool

    var body: some View {
        HStack(spacing: 16) {
            Button {
                value = max(range.lowerBound, value - step)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 29, weight: .bold))
            }

            Text("\(Int(value))\(unit)")
                .font(BBBFont.font(size: isCompactHeight ? 24 : 28, weight: .heavy))
                .foregroundStyle(DesignToken.textPrimary)
                .frame(minWidth: isCompactHeight ? 92 : 112)

            Button {
                value = min(range.upperBound, value + step)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 29, weight: .bold))
            }
        }
        .foregroundStyle(tint)
    }
}

private struct BreastMinuteArcScale: View {
    let side: BreastSide
    let seconds: Int
    let accent: Color
    let S: CGFloat
    let onSetMinutes: (Int) -> Void

    private var currentMinutes: Int {
        min(max(Int(round(Double(seconds) / 60.0)), 5), 30)
    }

    private var hasValue: Bool {
        seconds > 0
    }

    private var progress: CGFloat {
        hasValue ? CGFloat(currentMinutes - 5) / 25.0 : 0
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let isLeft = side == .left

            ZStack {
                arcPath(width: width, height: height, isLeft: isLeft)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.22),
                                accent.opacity(0.16),
                                Color.white.opacity(0.14)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        style: StrokeStyle(lineWidth: 8 * S, lineCap: .round)
                    )

                arcPath(width: width, height: height, isLeft: isLeft)
                    .trimmedPath(from: max(0, 1 - progress), to: 1)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.34),
                                accent.opacity(0.92),
                                accent.opacity(0.62)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        style: StrokeStyle(lineWidth: 8 * S, lineCap: .round)
                    )
                    .shadow(color: accent.opacity(0.28), radius: 8 * S)
                    .animation(.spring(response: 0.34, dampingFraction: 0.78), value: progress)

                ForEach([5, 10, 15, 20, 25, 30], id: \.self) { minute in
                    let point = arcPoint(for: minute, width: width, height: height, isLeft: isLeft)
                    let tickLength = minute == 5 || minute == 15 || minute == 30 ? 15 * S : 8 * S
                    let tickCenterX = isLeft ? point.x - tickLength * 0.48 : point.x + tickLength * 0.48
                    let labelX = isLeft ? point.x - tickLength - 16 * S : point.x + tickLength + 16 * S
                    let highlighted = hasValue && minute == currentMinutes
                    let showsLabel = minute == 5 || minute == 30

                    Capsule(style: .continuous)
                        .fill(accent.opacity(highlighted ? 0.96 : 0.42))
                        .frame(width: tickLength, height: highlighted ? 3 * S : 2 * S)
                        .position(x: tickCenterX, y: point.y)
                        .animation(.spring(response: 0.26, dampingFraction: 0.78), value: highlighted)

                    if highlighted {
                        Circle()
                            .fill(accent.opacity(0.95))
                            .frame(width: 8 * S, height: 8 * S)
                            .overlay(Circle().stroke(Color.white.opacity(0.78), lineWidth: 1))
                            .shadow(color: accent.opacity(0.36), radius: 6 * S)
                            .position(x: point.x, y: point.y)
                            .transition(.scale(scale: 0.55).combined(with: .opacity))
                    }

                    if showsLabel {
                        Text("\(minute)")
                            .font(BBBFont.font(size: highlighted ? 12 * S : 10 * S, weight: .bold))
                            .foregroundStyle(accent.opacity(highlighted ? 0.98 : 0.68))
                            .monospacedDigit()
                            .frame(width: 25 * S, height: 19 * S)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.white.opacity(highlighted ? 0.44 : 0.20))
                                    .overlay(Capsule(style: .continuous).stroke(accent.opacity(highlighted ? 0.34 : 0.14), lineWidth: 1))
                            )
                            .position(x: labelX, y: point.y)
                            .animation(.spring(response: 0.26, dampingFraction: 0.78), value: highlighted)
                    }
                }
            }
            .animation(.spring(response: 0.34, dampingFraction: 0.78), value: currentMinutes)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        onSetMinutes(minute(for: value.location.y, height: height))
                    }
            )
        }
    }

    private func arcPath(width: CGFloat, height: CGFloat, isLeft: Bool) -> Path {
        var path = Path()
        if isLeft {
            path.move(to: CGPoint(x: width * 0.72, y: height * 0.04))
            path.addQuadCurve(
                to: CGPoint(x: width * 0.72, y: height * 0.96),
                control: CGPoint(x: width * 0.28, y: height * 0.50)
            )
        } else {
            path.move(to: CGPoint(x: width * 0.28, y: height * 0.04))
            path.addQuadCurve(
                to: CGPoint(x: width * 0.28, y: height * 0.96),
                control: CGPoint(x: width * 0.72, y: height * 0.50)
            )
        }
        return path
    }

    private func arcPoint(for minute: Int, width: CGFloat, height: CGFloat, isLeft: Bool) -> CGPoint {
        let normalized = CGFloat(minute - 5) / 25.0
        let t = 1 - normalized
        let start = CGPoint(x: width * (isLeft ? 0.72 : 0.28), y: height * 0.04)
        let control = CGPoint(x: width * (isLeft ? 0.28 : 0.72), y: height * 0.50)
        let end = CGPoint(x: width * (isLeft ? 0.72 : 0.28), y: height * 0.96)
        let oneMinusT = 1 - t
        return CGPoint(
            x: oneMinusT * oneMinusT * start.x + 2 * oneMinusT * t * control.x + t * t * end.x,
            y: oneMinusT * oneMinusT * start.y + 2 * oneMinusT * t * control.y + t * t * end.y
        )
    }

    private func minute(for y: CGFloat, height: CGFloat) -> Int {
        let normalized = min(max((height * 0.92 - y) / (height * 0.84), 0), 1)
        let raw = 5 + normalized * 25
        return min(max(Int(round(raw)), 5), 30)
    }
}

private struct FeedingPastelBackground: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    colors: [
                        DesignToken.easyEatSoft,
                        DesignToken.canvas,
                        DesignToken.surfaceSoft,
                        DesignToken.easySleepSoft.opacity(0.72)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                RadialGradient(
                    colors: [
                        Color.white.opacity(0.58),
                        DesignToken.easyEat.opacity(0.24),
                        .clear
                    ],
                    center: UnitPoint(x: 0.16, y: 0.10),
                    startRadius: 10,
                    endRadius: geo.size.width * 0.82
                )

                RadialGradient(
                    colors: [
                        DesignToken.surfaceSoft.opacity(0.72),
                        DesignToken.feedingBreast.opacity(0.18),
                        .clear
                    ],
                    center: UnitPoint(x: 0.84, y: 0.44),
                    startRadius: 20,
                    endRadius: geo.size.width * 0.82
                )

                RoundedRectangle(cornerRadius: geo.size.width * 0.28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                DesignToken.easySleep.opacity(0.10),
                                Color.white.opacity(0.62),
                                DesignToken.easyEat.opacity(0.12)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * 1.32, height: geo.size.height * 0.30)
                    .blur(radius: 58)
                    .position(x: geo.size.width * 0.50, y: geo.size.height * 0.50)

                RadialGradient(
                    colors: [
                        Color.white.opacity(0.82),
                        Color.white.opacity(0.34),
                        .clear
                    ],
                    center: UnitPoint(x: 0.52, y: 0.48),
                    startRadius: 20,
                    endRadius: geo.size.width * 0.64
                )

                Ellipse()
                    .fill(
                        LinearGradient(
                            colors: [
                                DesignToken.feedingSolid.opacity(0.14),
                                Color.white.opacity(0.72),
                                DesignToken.easyEatSoft.opacity(0.72)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * 1.42, height: geo.size.height * 0.16)
                    .blur(radius: 40)
                    .position(x: geo.size.width * 0.50, y: geo.size.height * 0.61)

                Ellipse()
                    .fill(Color.white.opacity(0.35))
                    .frame(width: geo.size.width * 0.82, height: geo.size.height * 0.055)
                    .blur(radius: 20)
                    .position(x: geo.size.width * 0.50, y: geo.size.height * 0.585)

                RadialGradient(
                    colors: [
                        DesignToken.feedingSolid.opacity(0.22),
                        .clear
                    ],
                    center: UnitPoint(x: 0.12, y: 0.78),
                    startRadius: 10,
                    endRadius: geo.size.width * 0.72
                )

                RadialGradient(
                    colors: [
                        DesignToken.easyEatSoft.opacity(0.58),
                        .clear
                    ],
                    center: UnitPoint(x: 0.80, y: 0.86),
                    startRadius: 20,
                    endRadius: geo.size.width * 0.70
                )

                VStack {
                    LinearGradient(
                        colors: [
                            DesignToken.easyEat.opacity(0.10),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: geo.size.height * 0.28)

                    Spacer()
                }

                FeedingNoiseOverlay(opacity: 0.045)
                    .blendMode(.softLight)
            }
            .ignoresSafeArea()
        }
    }
}

private struct FeedingNoiseOverlay: View {
    let opacity: Double

    private static let image: UIImage = {
        let size = 160
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))

        return renderer.image { context in
            let cgContext = context.cgContext

            for x in 0..<size {
                for y in 0..<size {
                    let white = CGFloat.random(in: 0.72...1.0)
                    let alpha = CGFloat.random(in: 0.035...0.12)

                    cgContext.setFillColor(UIColor(white: white, alpha: alpha).cgColor)
                    cgContext.fill(CGRect(x: x, y: y, width: 1, height: 1))
                }
            }
        }
    }()

    var body: some View {
        Image(uiImage: Self.image)
            .resizable(resizingMode: .tile)
            .opacity(opacity)
            .ignoresSafeArea()
    }
}

private extension FeedingSheet {
    func persistDraftIfNeeded() {
        draftStore.persistDraftIfNeeded()
    }

    func persistDraft() {
        draftStore.persistDraft()
    }

    func restoreDraft() {
        draftStore.restoreDraft()
    }
}
