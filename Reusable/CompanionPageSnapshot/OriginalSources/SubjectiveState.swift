import SwiftUI
import UIKit

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

        let statePrompts = prompts.first?[self] ?? []
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
        let feedbackReferenceID = context.sourceRecordID?.uuidString.lowercased()
            ?? context.checkInID?.uuidString.lowercased()
            ?? "\(Calendar.current.startOfDay(for: now).timeIntervalSince1970)"
        let reward = CompanionRecruitmentStore.shared.awardDailyTask(
            .subjectiveState,
            eventDate: context.recordedAt,
            referenceID: feedbackReferenceID,
            now: now
        )
        if reward.status == .awarded {
            AppFeedbackCenter.shared.presentReward(
                amount: reward.amount,
                title: "Y 状态已记录".localized,
                subtitle: "看见宝宝，也照顾到了此刻的自己".localized,
                deduplicationKey: "subjective-state-reward:\(feedbackReferenceID)"
            )
        }
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
        checkIns = sanitized(Array(values.prefix(BBBDataSafetyLimits.maxCareRecords)))
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
        // Y is the final EASY phase and is part of the V2 widget rhythm
        // snapshot. Refresh the shared system-surface state whenever a
        // subjective check-in is created, edited, or removed.
        CareRecencyCoordinator.refreshFromSharedStorage(
            babyAgeMonths: BabyProfileStore.shared.currentProfile.ageMonths
        )
        FamilyCloudStore.shared.scheduleUpload(reason: reason)
    }

    private func sanitized(_ values: [SubjectiveStateCheckIn]) -> [SubjectiveStateCheckIn] {
        let now = Date().addingTimeInterval(60)
        var byID: [UUID: SubjectiveStateCheckIn] = [:]
        for value in values where value.recordedAt <= now && (value.babyState != nil || value.parentState != nil) {
            if let current = byID[value.id], current.updatedAt > value.updatedAt { continue }
            byID[value.id] = value
        }
        return Array(
            byID.values
                .sorted { $0.recordedAt < $1.recordedAt }
                .prefix(BBBDataSafetyLimits.maxCareRecords)
        )
    }

    private func load() {
        let groupDefaults = UserDefaults(suiteName: appGroupID)
        guard let data = UserDefaults.standard.data(forKey: storageKey)
                ?? groupDefaults?.data(forKey: storageKey),
              data.count <= BBBDataSafetyLimits.maxJSONDataBytes,
              let decoded = try? JSONDecoder().decode([SubjectiveStateCheckIn].self, from: data) else {
            return
        }
        checkIns = sanitized(Array(decoded.prefix(BBBDataSafetyLimits.maxCareRecords)))
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
                Image(state.assetName)
                    .resizable()
                    .scaledToFit()
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var store = SubjectiveStateStore.shared
    @State private var visibleMonth = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()
    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @State private var showsYearOverview = false
    @State private var shareItem: SubjectiveStateShareItem?

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    calendarHeader
                    if showsYearOverview {
                        yearOverview
                            .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
                    } else {
                        monthCalendar
                            .transition(.opacity)
                        selectedDayCard
                    }
                }
                .padding(.horizontal, DesignToken.screenHorizontalPadding)
                .padding(.top, 10)
                .padding(.bottom, 28)
            }
            .background(DesignToken.background.ignoresSafeArea())
            .navigationTitle(SubjectiveStateCopy.detailTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    AppPageCloseButton { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("分享本周".localized, systemImage: "calendar.badge.clock") { share(.week) }
                        Button("分享全年".localized, systemImage: "calendar") { share(.year) }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 15, weight: .heavy))
                    }
                    .accessibilityLabel("分享状态日历".localized)
                }
            }
            .sheet(item: $shareItem) { item in
                SubjectiveStateSystemShareSheet(activityItems: [item.image])
            }
        }
    }

    private var calendarHeader: some View {
        HStack(spacing: 10) {
            navigationButton("chevron.left", direction: -1)
            Spacer(minLength: 0)
            Button {
                withAnimation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.88)) {
                    showsYearOverview.toggle()
                }
            } label: {
                HStack(spacing: 7) {
                    Text(showsYearOverview ? yearText : monthText)
                        .font(BBBFont.font(size: 19, weight: .heavy))
                        .foregroundStyle(DesignToken.textPrimary)
                    Image(systemName: showsYearOverview ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(DesignToken.textSecondary)
                }
                .frame(minHeight: 40)
            }
            .buttonStyle(.plain)
            Spacer(minLength: 0)
            navigationButton("chevron.right", direction: 1)
        }
    }

    private func navigationButton(_ name: String, direction: Int) -> some View {
        Button {
            let component: Calendar.Component = showsYearOverview ? .year : .month
            let target = Calendar.current.date(byAdding: component, value: direction, to: visibleMonth) ?? visibleMonth
            visibleMonth = target
            if !showsYearOverview { selectedDate = target }
        } label: {
            Image(systemName: name)
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(DesignToken.textPrimary.opacity(0.74))
                .frame(width: 38, height: 38)
                .background(Circle().fill(DesignToken.surfaceRaised.opacity(0.66)))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var monthCalendar: some View {
        VStack(spacing: 9) {
            HStack(spacing: 4) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(BBBFont.font(size: 10, weight: .bold))
                        .foregroundStyle(DesignToken.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 8) {
                ForEach(monthSlots) { slot in
                    if let date = slot.date {
                        dayCell(date)
                    } else {
                        Color.clear.frame(height: 54)
                    }
                }
            }
        }
        .padding(14)
        .background(cardBackground(cornerRadius: 24))
    }

    private func dayCell(_ date: Date) -> some View {
        let state = store.latestBabyState(on: date)
        let selected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
        return Button {
            selectedDate = date
        } label: {
            VStack(spacing: 3) {
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(BBBFont.font(size: 9, weight: selected ? .heavy : .bold))
                    .foregroundStyle(selected ? DesignToken.easyYearning : DesignToken.textSecondary)
                if let state {
                    SubjectiveStateIcon(kind: .baby(state), size: 34)
                } else {
                    Circle()
                        .fill(DesignToken.surfaceSoft.opacity(0.74))
                        .frame(width: 34, height: 34)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(selected ? DesignToken.easyYearning.opacity(0.72) : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(dayAccessibilityLabel(date, state: state))
    }

    private var selectedDayCard: some View {
        let entries = store.checkIns(on: selectedDate).reversed()
        return VStack(alignment: .leading, spacing: 0) {
            Text(AppDateTimeFormat.date(selectedDate))
                .font(BBBFont.font(size: 14, weight: .heavy))
                .foregroundStyle(DesignToken.textPrimary)
                .padding(.bottom, 7)

            if entries.isEmpty {
                Text(SubjectiveStateCopy.noRecords)
                    .font(BBBFont.font(size: 12, weight: .semibold))
                    .foregroundStyle(DesignToken.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
            } else {
                ForEach(Array(entries)) { entry in
                    HStack(spacing: 10) {
                        Text(AppDateTimeFormat.time(entry.recordedAt))
                            .font(BBBFont.font(size: 11, weight: .heavy))
                            .foregroundStyle(DesignToken.textSecondary)
                            .frame(width: 44, alignment: .leading)
                        if let baby = entry.babyState {
                            stateChip(icon: .baby(baby), title: baby.title)
                        }
                        if let parent = entry.parentState {
                            stateChip(icon: .parent(parent), title: parent.title)
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(minHeight: 46)
                    .overlay(alignment: .bottom) { Divider().opacity(0.30) }
                }
            }
        }
        .padding(16)
        .background(cardBackground(cornerRadius: 22))
    }

    private var yearOverview: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
            ForEach(1...12, id: \.self) { month in
                Button {
                    let year = Calendar.current.component(.year, from: visibleMonth)
                    visibleMonth = Calendar.current.date(from: DateComponents(year: year, month: month, day: 1)) ?? visibleMonth
                    selectedDate = visibleMonth
                    withAnimation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.88)) {
                        showsYearOverview = false
                    }
                } label: {
                    MiniSubjectiveStateMonth(
                        monthStart: monthStart(year: Calendar.current.component(.year, from: visibleMonth), month: month),
                        checkIns: store.checkIns
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func stateChip(icon: SubjectiveStateIcon.Kind, title: String) -> some View {
        HStack(spacing: 4) {
            SubjectiveStateIcon(kind: icon, size: 20)
            Text(title).font(BBBFont.font(size: 10, weight: .heavy)).lineLimit(1)
        }
        .padding(.horizontal, 8)
        .frame(height: 30)
        .background(Capsule().fill(DesignToken.easyYearningSoft.opacity(0.55)))
    }

    private func cardBackground(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(DesignToken.surfaceRaised.opacity(0.76))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).stroke(DesignToken.glassStroke.opacity(0.76), lineWidth: 1))
    }

    private var monthSlots: [SubjectiveStateCalendarSlot] {
        SubjectiveStateCalendarSlot.slots(for: visibleMonth)
    }

    private var weekdaySymbols: [String] {
        let formatter = DateFormatter()
        formatter.locale = AppLocalization.locale
        let symbols = formatter.veryShortStandaloneWeekdaySymbols ?? formatter.veryShortWeekdaySymbols ?? []
        let first = max(Calendar.current.firstWeekday - 1, 0)
        return Array(symbols[first...] + symbols[..<first])
    }

    private var monthText: String { Self.monthFormatter.string(from: visibleMonth) }
    private var yearText: String { Self.yearFormatter.string(from: visibleMonth) }

    private static var monthFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = AppLocalization.locale
        formatter.setLocalizedDateFormatFromTemplate("yyyyMMMM")
        return formatter
    }

    private static var yearFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = AppLocalization.locale
        formatter.setLocalizedDateFormatFromTemplate("yyyy")
        return formatter
    }

    private func monthStart(year: Int, month: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: 1)) ?? visibleMonth
    }

    private func dayAccessibilityLabel(_ date: Date, state: BabySubjectiveState?) -> String {
        let stateText = state?.title ?? SubjectiveStateCopy.noRecords
        return "\(AppDateTimeFormat.date(date))，\(stateText)"
    }

    @MainActor
    private func share(_ scope: SubjectiveStateShareScope) {
        let content = SubjectiveStateShareCard(
            scope: scope,
            referenceDate: scope == .week ? selectedDate : visibleMonth,
            checkIns: store.checkIns
        )
            .frame(width: 720)
            .fixedSize(horizontal: false, vertical: true)
            .environment(\.colorScheme, .light)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        guard let image = renderer.uiImage else { return }
        shareItem = SubjectiveStateShareItem(image: image)
    }
}

private struct SubjectiveStateCalendarSlot: Identifiable {
    let id: Int
    let date: Date?

    static func slots(for month: Date) -> [SubjectiveStateCalendarSlot] {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .month, for: month),
              let dayRange = calendar.range(of: .day, in: .month, for: month) else { return [] }
        let weekday = calendar.component(.weekday, from: interval.start)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        var values = (0..<leading).map { SubjectiveStateCalendarSlot(id: $0, date: nil) }
        for day in dayRange {
            let date = calendar.date(byAdding: .day, value: day - 1, to: interval.start)
            values.append(SubjectiveStateCalendarSlot(id: values.count, date: date))
        }
        return values
    }
}

private struct MiniSubjectiveStateMonth: View {
    let monthStart: Date
    let checkIns: [SubjectiveStateCheckIn]

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(monthName)
                .font(BBBFont.font(size: 13, weight: .heavy))
                .foregroundStyle(DesignToken.textPrimary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 3) {
                ForEach(SubjectiveStateCalendarSlot.slots(for: monthStart)) { slot in
                    if let date = slot.date {
                        if let state = latestState(on: date) {
                            SubjectiveStateIcon(kind: .baby(state), size: 17)
                        } else {
                            Text("\(Calendar.current.component(.day, from: date))")
                                .font(.system(size: 6, weight: .medium))
                                .foregroundStyle(DesignToken.textSecondary.opacity(0.72))
                                .frame(width: 17, height: 17)
                        }
                    } else {
                        Color.clear.frame(width: 17, height: 17)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(DesignToken.surfaceRaised.opacity(0.72))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(DesignToken.glassStroke.opacity(0.68), lineWidth: 1))
        )
    }

    private var monthName: String {
        let formatter = DateFormatter()
        formatter.locale = AppLocalization.locale
        formatter.setLocalizedDateFormatFromTemplate("MMM")
        return formatter.string(from: monthStart)
    }

    private func latestState(on date: Date) -> BabySubjectiveState? {
        checkIns.filter { Calendar.current.isDate($0.recordedAt, inSameDayAs: date) }.reversed().compactMap(\.babyState).first
    }
}

private enum SubjectiveStateShareScope: Equatable { case week, year }

private struct SubjectiveStateShareItem: Identifiable {
    let id = UUID()
    let image: UIImage
}

private struct SubjectiveStateSystemShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        controller.popoverPresentationController?.sourceView = controller.view
        controller.popoverPresentationController?.sourceRect = CGRect(x: 1, y: 1, width: 1, height: 1)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct SubjectiveStateShareCard: View {
    let scope: SubjectiveStateShareScope
    let referenceDate: Date
    let checkIns: [SubjectiveStateCheckIn]

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            HStack(spacing: 14) {
                Text("BB")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 54, height: 54)
                    .background(RoundedRectangle(cornerRadius: 17).fill(Color(red: 0.20, green: 0.16, blue: 0.38)))
                VStack(alignment: .leading, spacing: 2) {
                    Text("BBBuddy")
                        .font(.system(size: 25, weight: .black, design: .rounded))
                    Text(scope == .week ? "宝宝本周状态".localized : "宝宝年度状态".localized)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.secondary)
                }
                Spacer()
                Text(title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
            }

            if scope == .week { weekContent } else { yearContent }
        }
        .padding(34)
        .foregroundStyle(Color(red: 0.13, green: 0.12, blue: 0.17))
        .background(
            LinearGradient(
                colors: [Color(red: 0.96, green: 0.94, blue: 1), Color(red: 0.93, green: 0.98, blue: 0.96)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var weekContent: some View {
        HStack(alignment: .top, spacing: 10) {
            ForEach(weekDays, id: \.self) { date in
                VStack(spacing: 10) {
                    Text(Self.weekdayFormatter.string(from: date))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.secondary)
                    if let state = latestState(on: date) {
                        SubjectiveStateIcon(kind: .baby(state), size: 72)
                        Text(state.title)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    } else {
                        Circle().fill(Color.white.opacity(0.62)).frame(width: 72, height: 72)
                        Text("--").font(.system(size: 11, weight: .bold))
                    }
                    Text("\(Calendar.current.component(.day, from: date))")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(24)
        .background(RoundedRectangle(cornerRadius: 28).fill(Color.white.opacity(0.72)))
    }

    private var yearContent: some View {
        VStack(spacing: 18) {
            ForEach(0..<6, id: \.self) { row in
                HStack(alignment: .top, spacing: 18) {
                    shareMonth(row * 2 + 1)
                    shareMonth(row * 2 + 2)
                }
            }
        }
    }

    private func shareMonth(_ month: Int) -> some View {
        let start = Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: referenceDate), month: month, day: 1)) ?? referenceDate
        return VStack(alignment: .leading, spacing: 8) {
            Text(Self.monthFormatter.string(from: start))
                .font(.system(size: 16, weight: .bold, design: .rounded))
            VStack(spacing: 4) {
                ForEach(0..<6, id: \.self) { row in
                    HStack(spacing: 4) {
                        ForEach(0..<7, id: \.self) { column in
                            let index = row * 7 + column
                            let slots = SubjectiveStateCalendarSlot.slots(for: start)
                            if slots.indices.contains(index), let date = slots[index].date {
                                if let state = latestState(on: date) {
                                    SubjectiveStateIcon(kind: .baby(state), size: 27)
                                } else {
                                    Text("\(Calendar.current.component(.day, from: date))")
                                        .font(.system(size: 7, weight: .medium))
                                        .foregroundStyle(Color.secondary)
                                        .frame(width: 27, height: 27)
                                }
                            } else {
                                Color.clear.frame(width: 27, height: 27)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 22).fill(Color.white.opacity(0.72)))
    }

    private var title: String {
        if scope == .year { return "\(Calendar.current.component(.year, from: referenceDate))" }
        guard let first = weekDays.first, let last = weekDays.last else { return "" }
        return "\(AppDateTimeFormat.date(first))–\(AppDateTimeFormat.date(last))"
    }

    private var weekDays: [Date] {
        let interval = Calendar.current.dateInterval(of: .weekOfYear, for: referenceDate)
        let start = interval?.start ?? Calendar.current.startOfDay(for: referenceDate)
        return (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: start) }
    }

    private func latestState(on date: Date) -> BabySubjectiveState? {
        checkIns.filter { Calendar.current.isDate($0.recordedAt, inSameDayAs: date) }.reversed().compactMap(\.babyState).first
    }

    private static var weekdayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = AppLocalization.locale
        formatter.setLocalizedDateFormatFromTemplate("EEE")
        return formatter
    }

    private static var monthFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = AppLocalization.locale
        formatter.setLocalizedDateFormatFromTemplate("MMM")
        return formatter
    }
}
