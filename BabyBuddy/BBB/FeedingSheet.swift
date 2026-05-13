import PhotosUI
import SwiftUI

struct FeedingSheet: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var feedingStore: FeedingStore
    @EnvironmentObject private var draftStore: FeedingDraftStore
    @Binding var isPresented: Bool

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showManualBreastInput = false
    @State private var manualLeftMinutes = 0.0
    @State private var manualRightMinutes = 0.0

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    private var type: FeedingType {
        get { draftStore.type }
        nonmutating set { draftStore.type = newValue }
    }
    private var typeBinding: Binding<FeedingType> { binding(\.type) }
    private var mood: BabyMood {
        get { draftStore.mood }
        nonmutating set { draftStore.mood = newValue }
    }
    private var moodBinding: Binding<BabyMood> { binding(\.mood) }
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
    private var breastModeBinding: Binding<BreastFeedingMode> { binding(\.breastMode) }
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
    private var expressedAmount: Double {
        get { draftStore.expressedAmount }
        nonmutating set { draftStore.expressedAmount = newValue }
    }
    private var expressedAmountBinding: Binding<Double> { binding(\.expressedAmount) }
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
    private var bottleIsTimed: Bool {
        get { draftStore.bottleIsTimed }
        nonmutating set { draftStore.bottleIsTimed = newValue }
    }
    private var bottleIsTimedBinding: Binding<Bool> { binding(\.bottleIsTimed) }
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
                Color(hex: "#F8F7FB").ignoresSafeArea()
                backgroundBubbles

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        headerCard
                        sharedInfo
                        feedingInput
                        notesCard
                        entriesPreview
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 10)
                    .padding(.bottom, 112)
                }

                bottomStatus
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
    }

    private var backgroundBubbles: some View {
        ZStack {
            Circle()
                .fill(Color(hex: "#B7D5FF").opacity(0.18))
                .frame(width: 220, height: 220)
                .blur(radius: 24)
                .offset(x: -180, y: -310)
            Circle()
                .fill(Color(hex: "#F4C7D9").opacity(0.18))
                .frame(width: 280, height: 280)
                .blur(radius: 28)
                .offset(x: 210, y: 150)
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("记录喂养")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Color(hex: "#4D4B70"))
                }
                Spacer()
                Image(systemName: "fork.knife.circle.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(appGradient))
            }

            Picker("喂养类型", selection: typeBinding) {
                Label("母乳", systemImage: "heart.fill").tag(FeedingType.breast)
                Label("奶瓶", systemImage: "babybottle.fill").tag(FeedingType.bottle)
                Label("辅食", systemImage: "fork.knife").tag(FeedingType.solid)
            }
            .pickerStyle(.segmented)
        }
        .padding(18)
        .background(cardBackground)
    }

    private var sharedInfo: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(timeString(currentTime), systemImage: "clock.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color(hex: "#4D4B70"))
                Spacer()
                Text(lastIntervalText)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(hex: "#8B88A0"))
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("宝宝反应")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(hex: "#8B88A0"))
                HStack(spacing: 10) {
                    ForEach(BabyMood.allCases, id: \.self) { item in
                        Button {
                            mood = item
                        } label: {
                            Text(item.rawValue)
                                .font(.system(size: 28))
                                .frame(width: 54, height: 44)
                                .background(Capsule().fill(mood == item ? Color(hex: "#EEE8FF") : Color(hex: "#F3F1F7")))
                                .overlay(Capsule().stroke(mood == item ? DesignToken.primary.opacity(0.55) : .clear, lineWidth: 1.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(16)
        .background(cardBackground)
    }

    @ViewBuilder
    private var feedingInput: some View {
        switch type {
        case .breast:
            breastCard
        case .bottle:
            bottleCard
        case .solid:
            solidCard
        }
    }

    private var breastCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "母乳", icon: "heart.fill")

            Picker("母乳方式", selection: breastModeBinding) {
                ForEach(BreastFeedingMode.allCases) { mode in
                    Label(mode.displayName, systemImage: mode.systemImage).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if breastMode == .expressedBottle {
                amountInputCard(
                    title: "瓶喂母乳",
                    value: expressedAmountBinding,
                    range: 10...300,
                    step: 10,
                    unit: "ml",
                    systemImage: "drop.fill",
                    color: FeedingType.breast.accent
                )
                Button { addExpressedBreastEntry() } label: {
                    primaryActionLabel("加入本次记录", systemImage: "plus.circle.fill", color: FeedingType.breast.accent)
                }
            } else {
                HStack(spacing: 12) {
                    breastTimer(.left, seconds: leftSeconds)
                    breastTimer(.right, seconds: rightSeconds)
                }

                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(breastMode == .pumping ? "本次吸乳" : "本次亲喂")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color(hex: "#8B88A0"))
                        Text("合计 \(durationText(leftSeconds + rightSeconds)) · 左 \(durationText(leftSeconds)) / 右 \(durationText(rightSeconds))")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color(hex: "#4D4B70"))
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                    }
                    Spacer()
                    if activeBreastSide != nil {
                        Label("已保留", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color(hex: "#34C759"))
                            .labelStyle(.titleAndIcon)
                    }
                }

                breastSuggestion

                HStack(spacing: 12) {
                    Button {
                        manualLeftMinutes = Double(max(leftSeconds / 60, 0))
                        manualRightMinutes = Double(max(rightSeconds / 60, 0))
                        showManualBreastInput = true
                    } label: {
                        secondaryActionLabel("手动输入", systemImage: "square.and.pencil")
                    }

                    Button { addBreastEntry() } label: {
                        primaryActionLabel("加入本次记录", systemImage: "plus.circle.fill", color: FeedingType.breast.accent)
                    }
                    .disabled(leftSeconds + rightSeconds == 0)
                    .opacity(leftSeconds + rightSeconds == 0 ? 0.45 : 1)
                }

                Text("保存时会自动带上当前计时。")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(hex: "#8B88A0"))
            }
        }
        .padding(16)
        .background(cardBackground)
    }

    private var breastSuggestion: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.left.arrow.right.circle.fill")
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(FeedingType.breast.accent)
            Text(breastSwitchSuggestion)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(hex: "#6E6B83"))
            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(hex: "#FFF5EA")))
    }

    private var bottleCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "奶瓶", icon: "waterbottle.fill")

            Picker("奶瓶类型", selection: milkTypeBinding) {
                ForEach(MilkType.allCases) { item in
                    Text(item.displayName).tag(item)
                }
            }
            .pickerStyle(.segmented)

            amountInputCard(
                title: milkType == .formula ? "奶粉量" : "母乳量",
                value: bottleAmountBinding,
                range: 10...300,
                step: 10,
                unit: "ml",
                systemImage: "drop.degreesign.fill",
                color: FeedingType.bottle.accent
            )

            DisclosureGroup(isExpanded: bottleIsTimedBinding) {
                VStack(spacing: 12) {
                    HStack {
                        Text("喂奶时长")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color(hex: "#8B88A0"))
                        Spacer()
                        Text("\(Int(totalBottleMinutes)) 分钟")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(FeedingType.bottle.accent)
                    }
                    Slider(value: binding(\.bottleMinutes), in: 0...60, step: 1)
                        .tint(FeedingType.bottle.accent)
                    HStack {
                        Button { bottleMinutes = max(0, bottleMinutes - 1) } label: {
                            Image(systemName: "minus.circle.fill").font(.system(size: 32))
                        }
                        Spacer()
                        Button { toggleBottleTimer() } label: {
                            Label(bottleTimerStartedAt == nil ? "开始计时" : "暂停计时", systemImage: bottleTimerStartedAt == nil ? "play.fill" : "pause.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(FeedingType.bottle.accent)
                        Spacer()
                        Button { bottleMinutes = min(60, bottleMinutes + 1) } label: {
                            Image(systemName: "plus.circle.fill").font(.system(size: 32))
                        }
                    }
                    .foregroundStyle(FeedingType.bottle.accent)
                }
                .padding(.top, 8)
            } label: {
                Label("添加喂奶时长", systemImage: "timer")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(hex: "#4D4B70"))
            }

            Button { addBottleEntry() } label: {
                primaryActionLabel("加入本次记录", systemImage: "plus.circle.fill", color: FeedingType.bottle.accent)
            }
        }
        .padding(16)
        .background(cardBackground)
    }

    private var solidCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "辅食", icon: "fork.knife")

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(SolidFood.allCases) { food in
                    Button {
                        solidFood = food
                        solidUnit = food.suggestedUnit
                    } label: {
                        VStack(spacing: 6) {
                            Text(food.emoji)
                                .font(.system(size: 24))
                            Text(food.displayName)
                                .font(.system(size: 12, weight: .semibold))
                                .lineLimit(1)
                        }
                        .foregroundStyle(Color(hex: "#4D4B70"))
                        .frame(maxWidth: .infinity, minHeight: 68)
                        .background(RoundedRectangle(cornerRadius: 16).fill(solidFood == food ? Color(hex: "#EAF8ED") : Color(hex: "#F3F1F7")))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(solidFood == food ? FeedingType.solid.accent.opacity(0.55) : .clear, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                }
            }

            amountInputCard(
                title: "分量",
                value: solidAmountBinding,
                range: 5...300,
                step: 5,
                unit: solidUnit.rawValue,
                systemImage: "scalemass.fill",
                color: FeedingType.solid.accent
            )

            Picker("单位", selection: solidUnitBinding) {
                ForEach(SolidUnit.allCases) { unit in
                    Text(unit.displayName).tag(unit)
                }
            }
            .pickerStyle(.menu)
            .tint(FeedingType.solid.accent)

            Button { addSolidEntry() } label: {
                primaryActionLabel("加入本次记录", systemImage: "plus.circle.fill", color: FeedingType.solid.accent)
            }
        }
        .padding(16)
        .background(cardBackground)
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("备注", systemImage: "note.text")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color(hex: "#4D4B70"))

            TextField("吐奶、拒奶、过敏、喜欢程度等", text: noteBinding, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)

            HStack(spacing: 12) {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label(imageData == nil ? "添加图片" : "已选择图片", systemImage: "photo.fill")
                }
                .buttonStyle(.bordered)

                Button {} label: {
                    Label("语音输入", systemImage: "mic.fill")
                }
                .buttonStyle(.bordered)
                .disabled(true)
            }
            .tint(DesignToken.primary)
        }
        .padding(16)
        .background(cardBackground)
    }

    private var entriesPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("本次记录", systemImage: "list.bullet.clipboard.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color(hex: "#4D4B70"))
                Spacer()
                Text("\(entries.count) 条")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(hex: "#8B88A0"))
            }

            if entries.isEmpty {
                ContentUnavailableView("还没有记录", systemImage: "tray", description: Text("添加条目或直接保存。"))
                    .frame(minHeight: 116)
            } else {
                ForEach(entries) { entry in
                    HStack(spacing: 12) {
                        Image(systemName: entryIcon(entry))
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(entryColor(entry))
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(entryColor(entry).opacity(0.14)))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entrySummary(entry))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color(hex: "#4D4B70"))
                            Text("本次喂养")
                                .font(.caption)
                                .foregroundStyle(Color(hex: "#8B88A0"))
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
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color(hex: "#F8F7FB")))
                }
            }
        }
        .padding(16)
        .background(cardBackground)
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
                            .font(.system(size: 17, weight: .bold))
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

    private var bottomStatus: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(currentTime, format: .dateTime.month().day().weekday())
                        .font(.system(size: 15, weight: .semibold))
                    Text(bottomSummary)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color(hex: "#8B88A0"))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                Spacer()
                Button { save() } label: {
                    Text("保存")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 26)
                        .padding(.vertical, 13)
                        .background(Capsule().fill(canSave ? appGradient : LinearGradient(colors: [.gray.opacity(0.6), .gray.opacity(0.6)], startPoint: .leading, endPoint: .trailing)))
                }
                .disabled(!canSave)
            }
            .foregroundStyle(Color(hex: "#4D4B70"))
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 14)
            .background(.regularMaterial)
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(.white)
            .shadow(color: Color(hex: "#4D4B70").opacity(0.05), radius: 18, y: 8)
    }

    private var appGradient: LinearGradient {
        LinearGradient(colors: [Color(hex: "#BDA6F2"), Color(hex: "#E9B2D1")], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var leftSeconds: Int { breastSeconds(for: .left) }
    private var rightSeconds: Int { breastSeconds(for: .right) }
    private var totalBottleMinutes: Double { draftStore.totalBottleMinutes }

    private var canSave: Bool {
        !entries.isEmpty || leftSeconds + rightSeconds > 0 || (type == .bottle && bottleAmount > 0) || (type == .solid && solidAmount > 0) || (type == .breast && breastMode == .expressedBottle && expressedAmount > 0)
    }

    private var bottomSummary: String {
        "今日 母乳\(feedingStore.breastCount)次 / 奶粉\(feedingStore.formulaML)ml / 瓶喂母乳\(feedingStore.expressedMilkML)ml / 辅食\(feedingStore.solidsGram)g"
    }

    private var lastIntervalText: String {
        guard let last = feedingStore.lastFeedingTime() else { return "距上次喂养 暂无" }
        let minutes = max(Int(currentTime.timeIntervalSince(last) / 60), 0)
        if minutes < 60 { return "距上次 \(minutes) 分钟" }
        return "距上次 \(minutes / 60)小时\(minutes % 60)分"
    }

    private var breastSwitchSuggestion: String {
        if activeBreastSide == nil { return "可从上次较少的一侧开始。" }
        let activeSeconds = activeBreastSide == .left ? leftSeconds : rightSeconds
        if activeSeconds >= 15 * 60 {
            return "已超过 15 分钟，可换侧或结束。"
        }
        if activeSeconds >= 10 * 60 {
            return "已超过 10 分钟，注意宝宝节奏。"
        }
        return "计时中，你可以离开本页，进度不会丢失。"
    }

    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(Circle().fill(appGradient))
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color(hex: "#4D4B70"))
            Spacer()
        }
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
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color(hex: "#8B88A0"))
                        Text(durationText(seconds))
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Color(hex: "#4D4B70"))
                        Image(systemName: activeBreastSide == side ? "pause.fill" : "play.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(FeedingType.breast.accent)
                    }
                }
                .frame(height: 138)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 20).fill(activeBreastSide == side ? Color(hex: "#FFF5EA") : Color(hex: "#F8F7FB")))
        }
        .buttonStyle(.plain)
    }

    private func amountInputCard(title: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double, unit: String, systemImage: String, color: Color) -> some View {
        VStack(spacing: 14) {
            HStack {
                Label(title, systemImage: systemImage)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color(hex: "#4D4B70"))
                Spacer()
                Text("\(Int(value.wrappedValue)) \(unit)")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(color)
            }
            Slider(value: value, in: range, step: step)
                .tint(color)
            HStack {
                Button { value.wrappedValue = max(range.lowerBound, value.wrappedValue - step) } label: {
                    Image(systemName: "minus.circle.fill").font(.system(size: 32))
                }
                Spacer()
                Button { value.wrappedValue = min(range.upperBound, value.wrappedValue + step) } label: {
                    Image(systemName: "plus.circle.fill").font(.system(size: 32))
                }
            }
            .foregroundStyle(color)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color(hex: "#F8F7FB")))
    }

    private func primaryActionLabel(_ title: String, systemImage: String, color: Color) -> some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(RoundedRectangle(cornerRadius: 16).fill(color))
    }

    private func secondaryActionLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(Color(hex: "#4D4B70"))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(hex: "#F3F1F7")))
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

    private func addBreastEntry() {
        commitActiveBreastElapsed()
        if leftSeconds > 0 {
            entries.append(FeedingEntry(type: .breast, breastMode: breastMode, breastSide: .left, breastDuration: max(leftSeconds / 60, 1)))
        }
        if rightSeconds > 0 {
            entries.append(FeedingEntry(type: .breast, breastMode: breastMode, breastSide: .right, breastDuration: max(rightSeconds / 60, 1)))
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        leftBaseSeconds = 0
        rightBaseSeconds = 0
        activeBreastSide = nil
        hitMilestones.removeAll()
        persistDraft()
    }

    private func addExpressedBreastEntry() {
        entries.append(FeedingEntry(type: .bottle, milkType: .expressed, bottleAmount: Int(expressedAmount)))
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        expressedAmount = 0
        persistDraft()
    }

    private func addBottleEntry() {
        if bottleTimerStartedAt != nil { commitBottleElapsed() }
        entries.append(FeedingEntry(type: .bottle, milkType: milkType, bottleAmount: Int(bottleAmount), bottleDuration: totalBottleMinutes > 0 ? max(Int(totalBottleMinutes), 1) : nil))
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        bottleTimerStartedAt = nil
        bottleMinutes = 0
        bottleAmount = 0
        persistDraft()
    }

    private func addSolidEntry() {
        entries.append(FeedingEntry(type: .solid, solidFood: solidFood, solidAmount: solidAmount, solidUnit: solidUnit))
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        solidAmount = 0
        persistDraft()
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

        if type == .breast, breastMode == .expressedBottle, expressedAmount > 0 {
            finalEntries.append(FeedingEntry(type: .bottle, milkType: .expressed, bottleAmount: Int(expressedAmount)))
        } else {
            if leftSeconds > 0 {
                finalEntries.append(FeedingEntry(type: .breast, breastMode: breastMode, breastSide: .left, breastDuration: max(leftSeconds / 60, 1)))
            }
            if rightSeconds > 0 {
                finalEntries.append(FeedingEntry(type: .breast, breastMode: breastMode, breastSide: .right, breastDuration: max(rightSeconds / 60, 1)))
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
