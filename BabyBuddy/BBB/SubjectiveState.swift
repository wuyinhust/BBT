import SwiftUI

private let defaultSubjectiveStateBabyID = "current-baby"

private enum SubjectiveStateCopy {
    static var promptTitle: String { text("记录此刻状态", "記錄此刻狀態", "Check In") }
    static var skip: String { text("跳过", "跳過", "Skip") }
    static var save: String { text("保存", "儲存", "Save") }
    static var selected: String { text("已选中", "已選取", "Selected") }
    static var range: String { text("范围", "範圍", "Range") }
    static var sevenDays: String { text("近7日", "近7日", "7 Days") }
    static var thirtyDays: String { text("近30日", "近30日", "30 Days") }
    static var detailTitle: String { text("状态记录", "狀態記錄", "State Check-ins") }
    static var distributionTitle: String { text("状态分布", "狀態分佈", "Distribution") }
    static var timelineTitle: String { text("时间线", "時間線", "Timeline") }
    static var noRecords: String { text("还没有状态记录", "還沒有狀態記錄", "No check-ins yet") }
    static var noCategoryRecords: String { text("暂无", "暫無", "None yet") }
    static var timelineEmpty: String {
        text(
            "记录宝宝和你的此刻状态，变化会显示在这里。",
            "記錄寶寶和你的此刻狀態，變化會顯示在這裡。",
            "Record how baby and you feel; changes will appear here."
        )
    }
    static var babySectionTitle: String { text("宝宝状态 · Yearning", "寶寶狀態 · Yearning", "Yearning · Baby") }
    static var parentSectionTitle: String { text("我的状态 · You", "我的狀態 · You", "You") }

    private static func text(_ simplified: String, _ traditional: String, _ english: String) -> String {
        switch AppLocalization.language {
        case .simplifiedChinese: return simplified
        case .traditionalChinese: return traditional
        case .english: return english
        }
    }
}

enum BabySubjectiveState: String, CaseIterable, Codable, Identifiable, Hashable {
    case curious
    case happy
    case calm
    case fussy
    case crying
    case sleepy

    var id: String { rawValue }

    var title: String {
        switch AppLocalization.language {
        case .simplifiedChinese:
            return [
                .curious: "好奇探索", .happy: "开心满足", .calm: "平静安稳",
                .fussy: "有点烦躁", .crying: "正在哭闹", .sleepy: "困倦想睡"
            ][self] ?? rawValue
        case .traditionalChinese:
            return [
                .curious: "好奇探索", .happy: "開心滿足", .calm: "平靜安穩",
                .fussy: "有點煩躁", .crying: "正在哭鬧", .sleepy: "困倦想睡"
            ][self] ?? rawValue
        case .english:
            return rawValue.capitalized
        }
    }

    var accessibilityLabel: String {
        switch AppLocalization.language {
        case .simplifiedChinese: return "宝宝状态：\(title)"
        case .traditionalChinese: return "寶寶狀態：\(title)"
        case .english: return "Baby is \(title.lowercased())"
        }
    }

    // Keep the state-to-visual mapping in the model so regenerated artwork can
    // replace this presentation layer without changing stored state values.
    var emoji: String {
        switch self {
        case .curious: return "👀"
        case .happy: return "😊"
        case .calm: return "😌"
        case .fussy: return "😣"
        case .crying: return "😭"
        case .sleepy: return "😴"
        }
    }

    var assetName: String { "y_baby_\(rawValue)" }
}

enum ParentSubjectiveState: String, CaseIterable, Codable, Identifiable, Hashable {
    case relaxed
    case okay
    case tired
    case exhausted
    case help

    var id: String { rawValue }

    var title: String {
        switch AppLocalization.language {
        case .simplifiedChinese:
            return [
                .relaxed: "轻松有余", .okay: "状态还行", .tired: "有些累了",
                .exhausted: "身心俱疲", .help: "需要帮忙"
            ][self] ?? rawValue
        case .traditionalChinese:
            return [
                .relaxed: "輕鬆有餘", .okay: "狀態還行", .tired: "有些累了",
                .exhausted: "身心俱疲", .help: "需要幫忙"
            ][self] ?? rawValue
        case .english:
            return [
                .relaxed: "Relaxed", .okay: "Okay", .tired: "Tired",
                .exhausted: "Exhausted", .help: "Need Help"
            ][self] ?? rawValue
        }
    }

    var carePrompt: String {
        carePrompt(at: Date())
    }

    func carePrompt(at date: Date) -> String {
        let prompts: [[ParentSubjectiveState: [String]]] = [[
            .relaxed: [
                "陪宝宝轻松活动一会儿",
                "也给自己留点时间",
                "不用把事情做满",
                "陪宝宝看看、说说吧"
            ],
            .okay: [
                "慢一点也没关系",
                "先做重要的，其他可以等等",
                "喝口水，松松肩膀",
                "不用追求完美"
            ],
            .tired: [
                "能简化就简化",
                "宝宝安静时先歇会儿",
                "少做一件也没关系",
                "陪伴已经足够"
            ],
            .exhausted: [
                "先把标准放低",
                "今天只做必要的事",
                "先照顾好自己",
                "休息也是正事"
            ],
            .help: [
                "请身边的人接手一会儿",
                "把需求说具体",
                "让别人抱会儿宝宝",
                "联系可信赖的人"
            ]
        ]]

        let statePrompts = prompts[0][self] ?? []
        guard !statePrompts.isEmpty else { return "慢一点也没关系，你已经做得很好" }
        let index = abs(Int(date.timeIntervalSinceReferenceDate / 1_800)) % statePrompts.count
        return statePrompts[index]
    }

    var accessibilityLabel: String {
        switch AppLocalization.language {
        case .simplifiedChinese: return "我的状态：\(title)"
        case .traditionalChinese: return "我的狀態：\(title)"
        case .english: return "You feel \(title.lowercased())"
        }
    }

}

enum SubjectiveStateSourceType: String, Codable, Hashable {
    case feeding
    case care
    case manual
}

struct SubjectiveStateCheckIn: Codable, Identifiable, Hashable {
    var id: UUID
    var babyID: String
    var recordedAt: Date
    var babyState: BabySubjectiveState?
    var parentState: ParentSubjectiveState?
    var sourceType: SubjectiveStateSourceType?
    var sourceRecordID: UUID?
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        babyID: String = defaultSubjectiveStateBabyID,
        recordedAt: Date,
        babyState: BabySubjectiveState?,
        parentState: ParentSubjectiveState?,
        sourceType: SubjectiveStateSourceType? = nil,
        sourceRecordID: UUID? = nil,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.babyID = babyID
        self.recordedAt = recordedAt
        self.babyState = babyState
        self.parentState = parentState
        self.sourceType = sourceType
        self.sourceRecordID = sourceRecordID
        self.updatedAt = updatedAt
    }
}

struct SubjectiveStatePromptContext: Identifiable, Equatable {
    let id = UUID()
    var checkInID: UUID? = nil
    var sourceType: SubjectiveStateSourceType
    var sourceRecordID: UUID?
    var recordedAt: Date

    static func manual(at date: Date = Date()) -> SubjectiveStatePromptContext {
        SubjectiveStatePromptContext(checkInID: nil, sourceType: .manual, sourceRecordID: nil, recordedAt: date)
    }

    static func editing(_ checkIn: SubjectiveStateCheckIn) -> SubjectiveStatePromptContext {
        SubjectiveStatePromptContext(
            checkInID: checkIn.id,
            sourceType: checkIn.sourceType ?? .manual,
            sourceRecordID: checkIn.sourceRecordID,
            recordedAt: checkIn.recordedAt
        )
    }
}

struct SubjectiveStateSequence<State> {
    let values: [State]
    let hasHiddenPrefix: Bool
}

@MainActor
final class SubjectiveStateStore: ObservableObject {
    static let shared = SubjectiveStateStore()

    @Published private(set) var checkIns: [SubjectiveStateCheckIn] = []

    private let storageKey = "subjective_state_check_ins_v1"
    private let appGroupID = WidgetStorageKey.appGroupID

    private init() {
        load()
    }

    func checkIns(on date: Date) -> [SubjectiveStateCheckIn] {
        checkIns.filter { Calendar.current.isDate($0.recordedAt, inSameDayAs: date) }
            .sorted { $0.recordedAt < $1.recordedAt }
    }

    func checkIns(from start: Date, to end: Date) -> [SubjectiveStateCheckIn] {
        checkIns.filter { $0.recordedAt >= start && $0.recordedAt < end }
            .sorted { $0.recordedAt < $1.recordedAt }
    }

    func linkedCheckIn(sourceType: SubjectiveStateSourceType, sourceRecordID: UUID) -> SubjectiveStateCheckIn? {
        checkIns.first { $0.sourceType == sourceType && $0.sourceRecordID == sourceRecordID }
    }

    func checkIn(id: UUID) -> SubjectiveStateCheckIn? {
        checkIns.first { $0.id == id }
    }

    func save(
        context: SubjectiveStatePromptContext,
        babyState: BabySubjectiveState?,
        parentState: ParentSubjectiveState?
    ) {
        guard babyState != nil || parentState != nil else { return }
        let now = Date()
        if let checkInID = context.checkInID,
           let index = checkIns.firstIndex(where: { $0.id == checkInID }) {
            checkIns[index].recordedAt = context.recordedAt
            checkIns[index].babyState = babyState
            checkIns[index].parentState = parentState
            checkIns[index].sourceType = context.sourceType
            checkIns[index].sourceRecordID = context.sourceRecordID
            checkIns[index].updatedAt = now
        } else if let sourceRecordID = context.sourceRecordID,
           let index = checkIns.firstIndex(where: {
               $0.sourceType == context.sourceType && $0.sourceRecordID == sourceRecordID
           }) {
            checkIns[index].recordedAt = context.recordedAt
            checkIns[index].babyState = babyState
            checkIns[index].parentState = parentState
            checkIns[index].updatedAt = now
        } else {
            checkIns.append(SubjectiveStateCheckIn(
                recordedAt: context.recordedAt,
                babyState: babyState,
                parentState: parentState,
                sourceType: context.sourceType,
                sourceRecordID: context.sourceRecordID,
                updatedAt: now
            ))
        }
        normalizeAndPersist(reason: "subjective-state-save")
    }

    func updateLinkedRecord(
        sourceType: SubjectiveStateSourceType,
        sourceRecordID: UUID,
        recordedAt: Date
    ) {
        guard let index = checkIns.firstIndex(where: {
            $0.sourceType == sourceType && $0.sourceRecordID == sourceRecordID
        }) else { return }
        checkIns[index].recordedAt = recordedAt
        checkIns[index].updatedAt = Date()
        normalizeAndPersist(reason: "subjective-state-source-update")
    }

    func deleteLinked(sourceType: SubjectiveStateSourceType, sourceRecordID: UUID) {
        let removed = checkIns.filter {
            $0.sourceType == sourceType && $0.sourceRecordID == sourceRecordID
        }
        guard !removed.isEmpty else { return }
        checkIns.removeAll { item in removed.contains(where: { $0.id == item.id }) }
        removed.forEach { FamilyCloudStore.shared.markSubjectiveStateCheckInDeleted($0.id) }
        normalizeAndPersist(reason: "subjective-state-source-delete")
    }

    func delete(_ checkIn: SubjectiveStateCheckIn) {
        checkIns.removeAll { $0.id == checkIn.id }
        FamilyCloudStore.shared.markSubjectiveStateCheckInDeleted(checkIn.id)
        normalizeAndPersist(reason: "subjective-state-delete")
    }

    func latest(on date: Date) -> SubjectiveStateCheckIn? {
        checkIns(on: date).last
    }

    func latestBabyState(on date: Date) -> BabySubjectiveState? {
        checkIns(on: date).reversed().compactMap(\.babyState).first
    }

    func latestParentState(on date: Date) -> ParentSubjectiveState? {
        checkIns(on: date).reversed().compactMap(\.parentState).first
    }

    func latestBabyState(from start: Date, to end: Date) -> BabySubjectiveState? {
        checkIns(from: start, to: end).reversed().compactMap(\.babyState).first
    }

    func showsYearningMarker(from start: Date, to end: Date) -> Bool {
        let states = checkIns(from: start, to: end).compactMap(\.babyState)
        guard let latest = states.last else { return false }

        let explorationReady: Set<BabySubjectiveState> = [.curious, .happy, .calm]
        let needsDownshift: Set<BabySubjectiveState> = [.fussy, .crying, .sleepy]
        return states.contains(where: explorationReady.contains)
            && !states.contains(where: needsDownshift.contains)
            && explorationReady.contains(latest)
    }

    func dominantBabyState(from start: Date, to end: Date) -> BabySubjectiveState? {
        dominantState(
            checkIns(from: start, to: end).compactMap { item in item.babyState.map { ($0, item.recordedAt) } }
        )
    }

    func dominantParentState(from start: Date, to end: Date) -> ParentSubjectiveState? {
        dominantState(
            checkIns(from: start, to: end).compactMap { item in item.parentState.map { ($0, item.recordedAt) } }
        )
    }

    func babySequence(from start: Date, to end: Date, limit: Int = 3) -> [BabySubjectiveState] {
        collapsedSequence(checkIns(from: start, to: end).compactMap(\.babyState), limit: limit)
    }

    func parentSequence(from start: Date, to end: Date, limit: Int = 3) -> [ParentSubjectiveState] {
        collapsedSequence(checkIns(from: start, to: end).compactMap(\.parentState), limit: limit)
    }

    func babySequenceSummary(from start: Date, to end: Date, limit: Int = 3) -> SubjectiveStateSequence<BabySubjectiveState> {
        sequenceSummary(checkIns(from: start, to: end).compactMap(\.babyState), limit: limit)
    }

    func parentSequenceSummary(from start: Date, to end: Date, limit: Int = 3) -> SubjectiveStateSequence<ParentSubjectiveState> {
        sequenceSummary(checkIns(from: start, to: end).compactMap(\.parentState), limit: limit)
    }

    func exportCheckIns() -> [SubjectiveStateCheckIn] { checkIns }

    func importCheckIns(_ values: [SubjectiveStateCheckIn]) {
        checkIns = sanitized(values)
        persist()
    }

    private func dominantState<State: Hashable>(_ values: [(State, Date)]) -> State? {
        let grouped = Dictionary(grouping: values) { $0.0 }
        return grouped.max { lhs, rhs in
            if lhs.value.count != rhs.value.count { return lhs.value.count < rhs.value.count }
            let lhsLatest = lhs.value.map(\.1).max() ?? .distantPast
            let rhsLatest = rhs.value.map(\.1).max() ?? .distantPast
            return lhsLatest < rhsLatest
        }?.key
    }

    private func collapsedSequence<State: Equatable>(_ values: [State], limit: Int) -> [State] {
        sequenceSummary(values, limit: limit).values
    }

    private func sequenceSummary<State: Equatable>(_ values: [State], limit: Int) -> SubjectiveStateSequence<State> {
        let collapsed = values.reduce(into: [State]()) { result, value in
            if result.last != value { result.append(value) }
        }
        let safeLimit = max(limit, 1)
        return SubjectiveStateSequence(
            values: Array(collapsed.suffix(safeLimit)),
            hasHiddenPrefix: collapsed.count > safeLimit
        )
    }

    private func normalizeAndPersist(reason: String) {
        checkIns = sanitized(checkIns)
        persist()
        FamilyCloudStore.shared.scheduleUpload(reason: reason)
    }

    private func sanitized(_ values: [SubjectiveStateCheckIn]) -> [SubjectiveStateCheckIn] {
        let now = Date().addingTimeInterval(60)
        var byID: [UUID: SubjectiveStateCheckIn] = [:]
        for value in values where value.recordedAt <= now && (value.babyState != nil || value.parentState != nil) {
            if let current = byID[value.id], current.updatedAt > value.updatedAt { continue }
            byID[value.id] = value
        }
        return byID.values.sorted { $0.recordedAt < $1.recordedAt }
    }

    private func load() {
        let groupDefaults = UserDefaults(suiteName: appGroupID)
        guard let data = UserDefaults.standard.data(forKey: storageKey)
                ?? groupDefaults?.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([SubjectiveStateCheckIn].self, from: data) else {
            return
        }
        checkIns = sanitized(decoded)
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(checkIns) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
        UserDefaults(suiteName: appGroupID)?.set(data, forKey: storageKey)
    }
}

struct SubjectiveStateIcon: View {
    enum Kind {
        case baby(BabySubjectiveState)
        case parent(ParentSubjectiveState)
    }

    let kind: Kind
    var size: CGFloat = 32

    private var label: String {
        switch kind {
        case .baby(let state): return state.accessibilityLabel
        case .parent(let state): return state.accessibilityLabel
        }
    }

    var body: some View {
        Group {
            switch kind {
            case .baby(let state):
                Text(state.emoji)
                    .font(.system(size: size * 0.84))
                    .minimumScaleFactor(0.72)
                    .lineLimit(1)
                    .frame(width: size, height: size)
            case .parent:
                Text("Y")
                    .font(BBBFont.font(size: size * 0.42, weight: .heavy))
                    .foregroundStyle(DesignToken.onPrimary)
                    .frame(width: size, height: size)
                    .background(Circle().fill(DesignToken.easyYearning))
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(label)
    }
}

struct SubjectiveStatePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = SubjectiveStateStore.shared

    let context: SubjectiveStatePromptContext
    var title: String

    @State private var babyState: BabySubjectiveState?
    @State private var parentState: ParentSubjectiveState?

    init(context: SubjectiveStatePromptContext, title: String? = nil) {
        self.context = context
        self.title = title ?? SubjectiveStateCopy.promptTitle
        let existing = context.checkInID.flatMap { SubjectiveStateStore.shared.checkIn(id: $0) }
            ?? context.sourceRecordID.flatMap {
                SubjectiveStateStore.shared.linkedCheckIn(sourceType: context.sourceType, sourceRecordID: $0)
            }
        _babyState = State(initialValue: existing?.babyState)
        _parentState = State(initialValue: existing?.parentState)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    stateSection(
                        title: babySectionTitle,
                        items: BabySubjectiveState.allCases,
                        selection: $babyState,
                        icon: { SubjectiveStateIcon(kind: .baby($0), size: 34) },
                        label: { $0.title }
                    )

                    stateSection(
                        title: parentSectionTitle,
                        items: ParentSubjectiveState.allCases,
                        selection: $parentState,
                        icon: { SubjectiveStateIcon(kind: .parent($0), size: 34) },
                        label: { $0.title }
                    )
                }
                .padding(DesignToken.screenHorizontalPadding)
            }
            .background(DesignToken.background.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(SubjectiveStateCopy.skip) { dismiss() }
                        .foregroundStyle(DesignToken.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(SubjectiveStateCopy.save) {
                        store.save(context: context, babyState: babyState, parentState: parentState)
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .disabled(babyState == nil && parentState == nil)
                }
            }
        }
    }

    private var babySectionTitle: String { SubjectiveStateCopy.babySectionTitle }

    private var parentSectionTitle: String { SubjectiveStateCopy.parentSectionTitle }

    private func stateSection<Item: Identifiable & Hashable, Icon: View>(
        title: String,
        items: [Item],
        selection: Binding<Item?>,
        @ViewBuilder icon: @escaping (Item) -> Icon,
        label: @escaping (Item) -> String
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(BBBFont.font(size: 17, weight: .heavy))
                .foregroundStyle(DesignToken.textPrimary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(items) { item in
                    let isSelected = selection.wrappedValue == item
                    Button {
                        selection.wrappedValue = isSelected ? nil : item
                    } label: {
                        VStack(spacing: 6) {
                            icon(item)
                            Text(label(item))
                                .font(BBBFont.font(size: 11.5, weight: .heavy))
                                .foregroundStyle(DesignToken.textPrimary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 76)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(isSelected ? DesignToken.easyYearningSoft.opacity(0.72) : DesignToken.surfaceRaised.opacity(0.72))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(isSelected ? DesignToken.easyYearning : DesignToken.glassStroke.opacity(0.72), lineWidth: isSelected ? 2 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(title), \(label(item))")
                    .accessibilityValue(isSelected ? SubjectiveStateCopy.selected : "")
                }
            }
        }
    }
}

struct SubjectiveStateDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = SubjectiveStateStore.shared
    @State private var rangeDays = 7

    private var range: (Date, Date) {
        let calendar = Calendar.current
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date())) ?? Date()
        let start = calendar.date(byAdding: .day, value: -rangeDays, to: end) ?? end
        return (start, end)
    }

    private var entries: [SubjectiveStateCheckIn] {
        Array(store.checkIns(from: range.0, to: range.1).reversed())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    Picker(SubjectiveStateCopy.range, selection: $rangeDays) {
                        Text(SubjectiveStateCopy.sevenDays).tag(7)
                        Text(SubjectiveStateCopy.thirtyDays).tag(30)
                    }
                    .pickerStyle(.segmented)

                    distributionCard
                    timelineCard
                }
                .padding(DesignToken.screenHorizontalPadding)
            }
            .background(DesignToken.background.ignoresSafeArea())
            .navigationTitle(SubjectiveStateCopy.detailTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    AppPageCloseButton { dismiss() }
                }
            }
        }
    }

    private var distributionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(SubjectiveStateCopy.distributionTitle)
                .font(BBBFont.font(size: 17, weight: .heavy))
            distributionRows
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(cardBackground)
    }

    @ViewBuilder
    private var distributionRows: some View {
        let values = store.checkIns(from: range.0, to: range.1)
        let totalBaby = max(values.compactMap(\.babyState).count, 1)
        let totalParent = max(values.compactMap(\.parentState).count, 1)
        if values.isEmpty {
            Text(SubjectiveStateCopy.noRecords)
                .font(BBBFont.font(size: 13, weight: .semibold))
                .foregroundStyle(DesignToken.textSecondary)
        } else {
            distributionSectionTitle(SubjectiveStateCopy.babySectionTitle)
            let babyValues = values.compactMap(\.babyState)
            if babyValues.isEmpty {
                emptyDistributionCategory
            } else {
                ForEach(BabySubjectiveState.allCases) { state in
                    let count = babyValues.filter { $0 == state }.count
                    if count > 0 {
                        distributionRow(icon: .baby(state), title: state.title, count: count, total: totalBaby)
                    }
                }
            }

            Divider().overlay(DesignToken.line.opacity(0.4))
            distributionSectionTitle(SubjectiveStateCopy.parentSectionTitle)
            let parentValues = values.compactMap(\.parentState)
            if parentValues.isEmpty {
                emptyDistributionCategory
            } else {
                ForEach(ParentSubjectiveState.allCases) { state in
                    let count = parentValues.filter { $0 == state }.count
                    if count > 0 {
                        distributionRow(icon: .parent(state), title: state.title, count: count, total: totalParent)
                    }
                }
            }
        }
    }

    private func distributionSectionTitle(_ title: String) -> some View {
        Text(title)
            .font(BBBFont.font(size: 12.5, weight: .heavy))
            .foregroundStyle(DesignToken.textSecondary)
    }

    private var emptyDistributionCategory: some View {
        Text(SubjectiveStateCopy.noCategoryRecords)
            .font(BBBFont.font(size: 12, weight: .semibold))
            .foregroundStyle(DesignToken.textSecondary.opacity(0.72))
    }

    private func distributionRow(icon: SubjectiveStateIcon.Kind, title: String, count: Int, total: Int) -> some View {
        HStack(spacing: 10) {
            SubjectiveStateIcon(kind: icon, size: 24)
            Text(title).font(BBBFont.font(size: 13, weight: .heavy))
            GeometryReader { proxy in
                Capsule()
                    .fill(DesignToken.easyYearningSoft.opacity(0.48))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(DesignToken.easyYearning.opacity(0.72))
                            .frame(width: proxy.size.width * CGFloat(count) / CGFloat(total))
                    }
            }
            .frame(height: 7)
            Text("\(count)")
                .font(BBBFont.font(size: 12, weight: .heavy))
                .foregroundStyle(DesignToken.textSecondary)
        }
    }

    private var timelineCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(SubjectiveStateCopy.timelineTitle)
                .font(BBBFont.font(size: 17, weight: .heavy))
                .padding(.bottom, 8)

            if entries.isEmpty {
                Text(SubjectiveStateCopy.timelineEmpty)
                    .font(BBBFont.font(size: 13, weight: .semibold))
                    .foregroundStyle(DesignToken.textSecondary)
                    .padding(.vertical, 16)
            } else {
                ForEach(Array(entries)) { item in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(AppDateTimeFormat.date(item.recordedAt))
                                .font(BBBFont.font(size: 9, weight: .semibold))
                            Text(AppDateTimeFormat.time(item.recordedAt))
                                .font(BBBFont.font(size: 11, weight: .heavy))
                        }
                        .foregroundStyle(DesignToken.textSecondary)
                        .frame(width: 58, alignment: .leading)
                        if let baby = item.babyState {
                            stateChip(icon: .baby(baby), title: baby.title)
                        }
                        if let parent = item.parentState {
                            stateChip(icon: .parent(parent), title: parent.title)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 9)
                    .overlay(alignment: .bottom) { Divider().opacity(0.35) }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(cardBackground)
    }

    private func stateChip(icon: SubjectiveStateIcon.Kind, title: String) -> some View {
        HStack(spacing: 4) {
            SubjectiveStateIcon(kind: icon, size: 18)
            Text(title).font(BBBFont.font(size: 11, weight: .heavy))
        }
        .padding(.horizontal, 8)
        .frame(height: 28)
        .background(Capsule().fill(DesignToken.easyYearningSoft.opacity(0.55)))
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(DesignToken.surfaceRaised.opacity(0.76))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(DesignToken.glassStroke.opacity(0.76), lineWidth: 1)
            )
    }
}
