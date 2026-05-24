import PhotosUI
import SwiftUI

struct FeedingSheet: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var feedingStore: FeedingStore
    @EnvironmentObject private var draftStore: FeedingDraftStore
    @Binding var isPresented: Bool

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showManualBreastInput = false
    @State private var showCustomBottleAmount = false
    @State private var showMoreInfo = false
    @State private var selectedKind: FeedingKind = .nursing
    @State private var manualLeftMinutes = 0.0
    @State private var manualRightMinutes = 0.0
    @State private var customBottleAmountText = ""

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let bottleRange: ClosedRange<Double> = 0...330
    private var isCompactHeight: Bool {
        UIScreen.main.bounds.height < 760
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
        NavigationStack {
            ZStack(alignment: .bottom) {
                LinearGradient(
                    colors: [
                        Color(hex: "#FBF9FF"),
                        Color(hex: "#F7F3FF"),
                        Color(hex: "#FFF7FB")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: isCompactHeight ? 8 : 12) {
                        topSummary
                        Spacer(minLength: 0)
                        stageArea
                        entriesPreview
                        Spacer(minLength: 0)
                }
                .padding(.horizontal, isCompactHeight ? 14 : 16)
                .padding(.top, isCompactHeight ? 8 : 16)
                .padding(.bottom, isCompactHeight ? 132 : 152)

                bottomDock
            }
            .navigationTitle("记录喂养")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        persistDraft()
                        isPresented = false
                    }
                }
            }
        }
        .presentationDragIndicator(.visible)
        .onReceive(timer) { date in
            draftStore.updateCurrentTime(date)
            checkBreastMilestones()
            persistDraftIfNeeded()
        }
        .onAppear {
            restoreDraft()
            if type == .breast { breastMode = .nursing }
            selectedKind = FeedingKind.kindFor(type: type, solidFood: solidFood)
            draftStore.didSave = false
            draftStore.updateCurrentTime(Date())
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
        .sheet(isPresented: $showManualBreastInput) {
            manualBreastInputSheet
        }
        .sheet(isPresented: $showCustomBottleAmount) {
            customBottleAmountSheet
        }
        .popover(isPresented: $showMoreInfo, attachmentAnchor: .point(.bottomTrailing), arrowEdge: .bottom) {
            moreInfoPopover
                .presentationCompactAdaptation(.popover)
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

    @ViewBuilder
    private var stageArea: some View {
        switch selectedKind {
        case .nursing:
            breastStage
        case .bottle:
            bottleStage
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
        VStack(spacing: isCompactHeight ? 8 : 12) {
            Picker("奶瓶类型", selection: milkTypeBinding) {
                ForEach(MilkType.allCases) { item in
                    Text(item.displayName).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 18)

            InteractiveBottleView(amount: bottleAmountBinding, range: bottleRange, step: 10, tint: selectedKind.accent)
                .frame(width: isCompactHeight ? 230 : 280, height: isCompactHeight ? 230 : 280)
                .frame(maxWidth: .infinity)

            BottleAmountScrubber(amount: bottleAmountBinding, range: bottleRange, step: 10, tint: selectedKind.accent)
        }
        .padding(.vertical, isCompactHeight ? 10 : 14)
        .padding(.horizontal, 14)
        .background(cardBackground)
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
                tint: selectedKind.accent
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
            HStack(spacing: 10) {
                ForEach(FeedingKind.allCases) { kind in
                    Button {
                        selectKind(kind)
                    } label: {
                        VStack(spacing: 7) {
                            Text(kind.emoji)
                                .font(.system(size: isCompactHeight ? 20 : 23))
                            Text(kind.label)
                                .font(BBBFont.font(size: isCompactHeight ? 11 : 12, weight: .heavy))
                                .lineLimit(1)
                        }
                        .foregroundStyle(selectedKind == kind ? .white : DesignToken.textSecondary)
                        .frame(width: isCompactHeight ? 62 : 70, height: isCompactHeight ? 56 : 64)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(selectedKind == kind ? kind.accent : .white)
                                .shadow(color: Color(hex: "#4D4B70").opacity(selectedKind == kind ? 0.12 : 0.05), radius: 12, y: 6)
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .padding(.horizontal, isCompactHeight ? 14 : 16)
            .padding(.vertical, 4)
        }
        .padding(.horizontal, isCompactHeight ? -14 : -16)
    }

    private var moreInfoPopover: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("更多信息")
                    .font(BBBFont.font(size: 15, weight: .bold))
                    .foregroundStyle(DesignToken.textPrimary)
                Spacer()
                Button {
                    showMoreInfo = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(DesignToken.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(DesignToken.iconSoftBG))
                }
                .buttonStyle(ScaleButtonStyle())
            }

            VStack(alignment: .leading, spacing: 12) {
                extraActionButton(title: manualButtonTitle, icon: "square.and.pencil") {
                    showMoreInfo = false
                    openManualEntry()
                }

                if selectedKind == .bottle {
                    extraActionButton(
                        title: bottleTimerStartedAt == nil ? "开始计时" : "暂停计时",
                        icon: bottleTimerStartedAt == nil ? "play.fill" : "pause.fill"
                    ) {
                        toggleBottleTimer()
                    }
                }
            }

            Divider()

            moodSelector
            notesAndPhoto
        }
        .padding(16)
        .frame(maxWidth: 320)
        .background(Color(hex: "#F8F7FB"))
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
            Label("备注", systemImage: "note.text")
                .font(BBBFont.font(size: 15, weight: .bold))
                .foregroundStyle(DesignToken.textPrimary)

            TextField("吐奶、拒奶、过敏、喜欢程度等", text: noteBinding, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)

            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Label(imageData == nil ? "添加图片" : "已选择图片", systemImage: "photo.fill")
            }
            .buttonStyle(.bordered)
            .tint(DesignToken.primary)
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
                        leftBaseSeconds = Int(manualLeftMinutes * 60)
                        rightBaseSeconds = Int(manualRightMinutes * 60)
                        activeBreastSide = nil
                        activeBreastStartAt = nil
                        hitMilestones.removeAll()
                        persistDraft()
                        showManualBreastInput = false
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
                    .shadow(color: Color(hex: "#4D4B70").opacity(0.15), radius: 18, y: 8)
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
            .shadow(color: Color(hex: "#7E5DE8").opacity(0.06), radius: 12, y: 5)
    }

    private var appGradient: LinearGradient {
        DesignToken.primaryGradient
    }

    private var leftSeconds: Int { breastSeconds(for: .left) }
    private var rightSeconds: Int { breastSeconds(for: .right) }
    private var totalBottleMinutes: Double { draftStore.totalBottleMinutes }

    private var canSave: Bool {
        !entries.isEmpty || leftSeconds + rightSeconds > 0 || (type == .bottle && bottleAmount > 0) || (type == .solid && solidAmount > 0)
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
        if !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append("有备注")
        }
        if imageData != nil {
            parts.append("有图片")
        }
        if mood != .happy {
            parts.append("已选反应")
        }
        return parts.isEmpty ? "可选" : parts.joined(separator: " · ")
    }

    private var lastIntervalText: String {
        guard let last = feedingStore.lastFeedingTime() else { return "距上次喂养 暂无" }
        let minutes = max(Int(currentTime.timeIntervalSince(last) / 60), 0)
        if minutes < 60 { return "距上次 \(minutes) 分钟" }
        return "距上次 \(minutes / 60)小时\(minutes % 60)分"
    }

    private func breastTimer(_ side: BreastSide, seconds: Int) -> some View {
        Button { toggleBreastTimer(side) } label: {
            VStack(spacing: 10) {
                ZStack {
                    Circle().stroke(Color(hex: "#F0EDF7"), lineWidth: 10)
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
        if kind != .nursing {
            commitActiveBreastElapsed()
            activeBreastSide = nil
            activeBreastStartAt = nil
        }

        withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
            selectedKind = kind
            switch kind {
            case .nursing:
                type = .breast
                breastMode = .nursing
            case .bottle:
                type = .bottle
            case .rice, .porridge, .vegetable, .fruit, .meat, .fish, .egg, .noodle, .yogurt:
                type = .solid
                if let food = kind.solidFood {
                    solidFood = food
                    solidUnit = food.suggestedUnit
                }
            }
        }
        persistDraft()
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
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        commitActiveBreastElapsed()
        if bottleTimerStartedAt != nil { commitBottleElapsed() }
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
            finalEntries.append(FeedingEntry(type: .solid, solidFood: solidFood, solidAmount: solidAmount, solidUnit: solidUnit))
        }

        guard !finalEntries.isEmpty else { return }
        feedingStore.saveSession(FeedingSession(entries: finalEntries, notes: note, imageData: imageData, babyMood: mood))
        didSave = true
        draftStore.resetDraft()
        didSave = true
        isPresented = false
    }
}

private enum FeedingKind: String, CaseIterable, Identifiable {
    case nursing
    case bottle
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
        case .nursing, .bottle:
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
            switch solidFood {
            case .rice: return .rice
            case .porridge: return .porridge
            case .vegetable: return .vegetable
            case .fruit: return .fruit
            case .meat: return .meat
            case .fish: return .fish
            case .egg: return .egg
            case .noodle: return .noodle
            case .yogurt: return .yogurt
            case .bread, .other: return .rice
            }
        }
    }
}

private struct InteractiveBottleView: View {
    @Binding var amount: Double
    let range: ClosedRange<Double>
    let step: Double
    let tint: Color

    private let bottleFillTop: CGFloat = 0.302
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
                    .scaledToFit()
                    .opacity(0.92)

                Image("feeding_bottle_full")
                    .resizable()
                    .scaledToFit()
                    .mask(alignment: .bottom) {
                        BottleMilkMask(
                            progress: progress,
                            topRatio: bottleFillTop,
                            bottomRatio: bottleFillBottom
                        )
                    }
                    .opacity(0.96)
                    .allowsHitTesting(false)

                Image("feeding_bottle_empty")
                    .resizable()
                    .scaledToFit()
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
                        amount = snapped(rawValue)
                    }
            )
        }
        .accessibilityLabel("奶瓶量")
        .accessibilityValue("\(Int(amount))ml")
    }

    private func snapped(_ value: Double) -> Double {
        let snappedValue = (value / step).rounded() * step
        return min(max(snappedValue, range.lowerBound), range.upperBound)
    }
}

private struct BottleMilkMask: Shape {
    let progress: Double
    let topRatio: CGFloat
    let bottomRatio: CGFloat

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

private struct BottleAmountScrubber: View {
    @Binding var amount: Double
    let range: ClosedRange<Double>
    let step: Double
    let tint: Color

    var body: some View {
        HStack(spacing: 16) {
            Button {
                amount = max(range.lowerBound, amount - step)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 29, weight: .bold))
            }

            Text("\(Int(amount))ml")
                .font(BBBFont.font(size: UIScreen.main.bounds.height < 760 ? 24 : 28, weight: .heavy))
                .foregroundStyle(DesignToken.textPrimary)
                .frame(minWidth: UIScreen.main.bounds.height < 760 ? 92 : 112)

            Button {
                amount = min(range.upperBound, amount + step)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 29, weight: .bold))
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

    var body: some View {
        HStack(spacing: 16) {
            Button {
                value = max(range.lowerBound, value - step)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 29, weight: .bold))
            }

            Text("\(Int(value))\(unit)")
                .font(BBBFont.font(size: UIScreen.main.bounds.height < 760 ? 24 : 28, weight: .heavy))
                .foregroundStyle(DesignToken.textPrimary)
                .frame(minWidth: UIScreen.main.bounds.height < 760 ? 92 : 112)

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
