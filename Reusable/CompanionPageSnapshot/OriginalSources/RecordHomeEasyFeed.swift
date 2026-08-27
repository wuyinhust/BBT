import Foundation
import SwiftUI

struct RecordHomeDayKey: Hashable, Sendable {
    let dayStart: Date

    init(_ date: Date, calendar: Calendar = .autoupdatingCurrent) {
        dayStart = calendar.startOfDay(for: date)
    }
}

struct EasyCycleFeedDayState: Equatable, Sendable {
    var loadedCount: Int
    var topVisibleCycleID: UUID?

    init(
        loadedCount: Int = EasyCycleFeedState.pageSize,
        topVisibleCycleID: UUID? = nil
    ) {
        self.loadedCount = loadedCount
        self.topVisibleCycleID = topVisibleCycleID
    }
}

struct EasyCycleFeedState: Equatable, Sendable {
    static let pageSize = 3

    private(set) var days: [RecordHomeDayKey: EasyCycleFeedDayState] = [:]

    func visibleCount(for day: RecordHomeDayKey, totalCount: Int) -> Int {
        min(max(days[day]?.loadedCount ?? Self.pageSize, 0), max(totalCount, 0))
    }

    func anchor(for day: RecordHomeDayKey) -> UUID? {
        days[day]?.topVisibleCycleID
    }

    mutating func ensureDay(_ day: RecordHomeDayKey) {
        if days[day] == nil {
            days[day] = EasyCycleFeedDayState()
        }
    }

    @discardableResult
    mutating func loadNextPage(for day: RecordHomeDayKey, totalCount: Int) -> Bool {
        ensureDay(day)
        let currentCount = visibleCount(for: day, totalCount: totalCount)
        let nextCount = min(currentCount + Self.pageSize, max(totalCount, 0))
        guard nextCount > currentCount else { return false }
        days[day]?.loadedCount = nextCount
        return true
    }

    mutating func rememberTopVisibleCycle(_ id: UUID?, for day: RecordHomeDayKey) {
        ensureDay(day)
        days[day]?.topVisibleCycleID = id
    }

    mutating func trim(keeping keys: Set<RecordHomeDayKey>, limit: Int = 14) {
        guard days.count > limit else { return }
        let removableKeys = days.keys.filter { !keys.contains($0) }
        for key in removableKeys.prefix(max(days.count - limit, 0)) {
            days.removeValue(forKey: key)
        }
    }
}

struct RecordHomeEasyFeedInput: @unchecked Sendable {
    let dates: [Date]
    let cycles: [EasyCycle]
    let feedingSessions: [FeedingSession]
    let careRecords: [CareRecord]
    let subjectiveCheckIns: [SubjectiveStateCheckIn]
    let referenceDate: Date
    let revision: Int
}

struct RecordHomeDaySnapshot: Identifiable, @unchecked Sendable {
    let key: RecordHomeDayKey
    let revision: Int
    let cards: [EasyCycleCardModel]

    var id: RecordHomeDayKey { key }
}

struct EasyCycleCardModel: Identifiable, Equatable, @unchecked Sendable {
    let id: UUID
    let revision: Int
    let cycle: EasyCycle
    let ordinalText: String
    let headerTimeText: String
    let completion: EasyCycleCardCompletion
    let rows: [EasyCycleTimelineRow]
    let babyStates: [BabySubjectiveState]
    let showsYearning: Bool
    let parentState: ParentSubjectiveState?
    let parentPrompt: String
    let yearningPlaceholderText: String

    static func == (lhs: EasyCycleCardModel, rhs: EasyCycleCardModel) -> Bool {
        lhs.id == rhs.id && lhs.revision == rhs.revision
    }
}

enum RecordHomeEasyFeedSnapshotBuilder {
    static func build(_ input: RecordHomeEasyFeedInput) -> [RecordHomeDayKey: RecordHomeDaySnapshot] {
        let calendar = Calendar.autoupdatingCurrent
        // Imported and CloudKit-replayed data can transiently contain duplicate
        // IDs. Dictionary(uniqueKeysWithValues:) traps in that case, so keep the
        // most recently supplied value instead of crashing the feed builder.
        let sessionsByID = dictionaryByID(input.feedingSessions) { $0.id }
        let careRecordsByID = dictionaryByID(input.careRecords) { $0.id }
        var snapshots: [RecordHomeDayKey: RecordHomeDaySnapshot] = [:]

        for date in input.dates {
            if Task.isCancelled { break }
            let key = RecordHomeDayKey(date, calendar: calendar)
            guard snapshots[key] == nil else { continue }

            let dayCycles = input.cycles
                .filter(\.isCurrentVersion)
                .filter { calendar.isDate($0.startedAt, inSameDayAs: key.dayStart) }
                .filter { cycle in
                    cycle.linkedRecords.isEmpty
                        || cycle.linkedRecords.contains { $0.phase == .eat || $0.phase == .activity }
                }
                .sorted { $0.startedAt > $1.startedAt }

            let associations = dayCycles.compactMap { cycle -> CycleAssociation? in
                let sessions = cycle.linkedRecords
                    .filter { $0.type == .feeding }
                    .compactMap { sessionsByID[$0.recordID] }
                    .sorted { $0.eventDate < $1.eventDate }
                let careRecords = cycle.linkedRecords
                    .filter { $0.type == .care }
                    .compactMap { careRecordsByID[$0.recordID] }
                    .sorted { $0.recordedAt < $1.recordedAt }
                guard !sessions.isEmpty || !careRecords.isEmpty else { return nil }
                return CycleAssociation(cycle: cycle, sessions: sessions, careRecords: careRecords)
            }

            let ascendingCycles = associations.sorted { $0.cycle.startedAt < $1.cycle.startedAt }
            var ordinalByID: [UUID: Int] = [:]
            var nextStartByID: [UUID: Date] = [:]
            for (index, association) in ascendingCycles.enumerated() {
                ordinalByID[association.cycle.id] = index + 1
                if index + 1 < ascendingCycles.count {
                    nextStartByID[association.cycle.id] = ascendingCycles[index + 1].cycle.startedAt
                }
            }
            let recency = recencySnapshot(
                for: key.dayStart,
                input: input,
                calendar: calendar
            )

            let cards = associations.map { association in
                makeCard(
                    association,
                    ordinal: ordinalByID[association.cycle.id],
                    nextCycleStart: nextStartByID[association.cycle.id],
                    recency: recency,
                    day: key.dayStart,
                    input: input,
                    calendar: calendar
                )
            }

            snapshots[key] = RecordHomeDaySnapshot(
                key: key,
                revision: input.revision,
                cards: cards
            )
        }

        return snapshots
    }

    private struct CycleAssociation {
        let cycle: EasyCycle
        let sessions: [FeedingSession]
        let careRecords: [CareRecord]
    }

    private struct RecencyValues {
        let feeding: Date?
        let activity: Date?
        let sleep: Date?
    }

    private static func makeCard(
        _ association: CycleAssociation,
        ordinal: Int?,
        nextCycleStart: Date?,
        recency: RecencyValues,
        day: Date,
        input: RecordHomeEasyFeedInput,
        calendar: Calendar
    ) -> EasyCycleCardModel {
        let cycle = association.cycle
        let activityRecords = association.careRecords.filter { $0.kind != .sleep }
        let sleepRecords = association.careRecords.filter { $0.kind == .sleep }
        let boundary = cycle.endedAt ?? nextCycleStart
        let effectiveEnd: Date
        if let boundary {
            effectiveEnd = boundary
        } else if calendar.isDate(day, inSameDayAs: input.referenceDate) {
            effectiveEnd = input.referenceDate
        } else {
            effectiveEnd = calendar.date(byAdding: .day, value: 1, to: day) ?? day
        }
        let reference = calendar.isDate(day, inSameDayAs: input.referenceDate)
            ? input.referenceDate
            : effectiveEnd

        let rows = [
            EasyCycleTimelineRow(
                step: .eat,
                title: association.sessions.isEmpty
                    ? AppLocalization.format("%@ %@", "喂养".localized, "待记录".localized)
                    : AppLocalization.format("喂养 %d 次", association.sessions.count),
                primaryText: association.sessions.isEmpty ? "醒来先吃 吃得饱饱".localized : "",
                secondaryText: "",
                timeText: association.sessions.isEmpty
                    ? emptyElapsedText(since: recency.feeding, relativeTo: reference)
                    : feedingTotalText(association.sessions),
                detailItems: association.sessions.isEmpty ? [] : feedingDetails(association.sessions)
            ),
            EasyCycleTimelineRow(
                step: .activity,
                title: activityRecords.isEmpty
                    ? AppLocalization.format("%@ %@", "活动".localized, "待记录".localized)
                    : AppLocalization.format("活动 %@", AppQuantityFormat.records(activityRecords.count)),
                primaryText: activityRecords.isEmpty ? "清醒活动 玩得开心".localized : "",
                secondaryText: "",
                timeText: activityRecords.isEmpty
                    ? emptyElapsedText(since: recency.activity, relativeTo: reference)
                    : AppLocalization.format("共 %d 项", Set(activityRecords.map(activityTypeName)).count),
                detailItems: activityRecords.isEmpty ? [] : activityDetails(activityRecords)
            ),
            EasyCycleTimelineRow(
                step: .sleep,
                title: sleepRecords.isEmpty
                    ? AppLocalization.format("%@ %@", "睡眠".localized, "待记录".localized)
                    : AppLocalization.format("睡眠 %@", AppQuantityFormat.records(sleepRecords.count)),
                primaryText: sleepRecords.isEmpty ? "大脑升级 睡得香甜".localized : "",
                secondaryText: "",
                timeText: sleepRecords.isEmpty
                    ? emptyElapsedText(since: recency.sleep, relativeTo: reference)
                    : sleepTotalText(sleepRecords),
                detailItems: sleepRecords.isEmpty ? [] : sleepDetails(sleepRecords)
            ),
            EasyCycleTimelineRow(
                step: .yearning,
                title: "",
                primaryText: "",
                secondaryText: "",
                timeText: "",
                detailItems: []
            )
        ]

        let cycleCheckIns = checkIns(
            for: association,
            startingAt: cycle.startedAt,
            endingAt: effectiveEnd,
            from: input.subjectiveCheckIns
        )
        let babySequence = collapsedSequence(cycleCheckIns.compactMap(\.babyState))
        let parentState = collapsedSequence(cycleCheckIns.compactMap(\.parentState)).last
        let explorationReady: Set<BabySubjectiveState> = [.curious, .happy, .calm]
        let needsDownshift: Set<BabySubjectiveState> = [.fussy, .crying, .sleepy]
        let allBabyStates = cycleCheckIns.compactMap(\.babyState)
        let showsYearning = allBabyStates.last.map(explorationReady.contains) == true
            && allBabyStates.contains(where: explorationReady.contains)
            && !allBabyStates.contains(where: needsDownshift.contains)

        let completion: EasyCycleCardCompletion
        if !association.sessions.isEmpty && !activityRecords.isEmpty && !sleepRecords.isEmpty {
            completion = .complete
        } else {
            completion = .partial
        }
        let headerTimeText = AppDateTimeFormat.timeRange(
            from: cycle.startedAt,
            to: boundary
        )

        return EasyCycleCardModel(
            id: cycle.id,
            revision: input.revision,
            cycle: cycle,
            ordinalText: ordinal.map { AppLocalization.format("第 %d 轮循环", $0) } ?? "本轮循环".localized,
            headerTimeText: headerTimeText,
            completion: completion,
            rows: rows,
            babyStates: babySequence,
            showsYearning: showsYearning,
            parentState: parentState,
            parentPrompt: parentState?.carePrompt(at: cycle.startedAt).localized ?? "",
            yearningPlaceholderText: "记录这一刻的状态".localized
        )
    }

    private static func recencySnapshot(
        for day: Date,
        input: RecordHomeEasyFeedInput,
        calendar: Calendar
    ) -> RecencyValues {
        let isToday = calendar.isDate(day, inSameDayAs: input.referenceDate)
        let daySessions = input.feedingSessions.filter {
            calendar.isDate($0.eventDate, inSameDayAs: day)
        }
        let dayCareRecords = input.careRecords.filter {
            calendar.isDate($0.recordedAt, inSameDayAs: day)
        }
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: day) ?? day
        let sleepSummaryRecords = input.careRecords.filter { record in
            if calendar.isDate(record.recordedAt, inSameDayAs: day) {
                return true
            }
            guard record.kind == .sleep,
                  let duration = SleepRecordFormatter.durationMinutes(from: record.detail) else {
                return false
            }
            let sleepEnd = SleepRecordFormatter.endTime(start: record.recordedAt, durationMinutes: duration)
            return record.recordedAt < dayEnd && sleepEnd > day
        }
        let feedingSnapshot = CareRecencyCalculator.snapshot(
            feedingSessions: isToday ? input.feedingSessions : daySessions,
            careRecords: [],
            referenceDate: input.referenceDate
        )
        let careSnapshot = CareRecencyCalculator.snapshot(
            feedingSessions: [],
            careRecords: isToday ? input.careRecords : dayCareRecords,
            referenceDate: input.referenceDate
        )
        let sleepSnapshot = CareRecencyCalculator.snapshot(
            feedingSessions: [],
            careRecords: isToday ? input.careRecords : sleepSummaryRecords,
            referenceDate: input.referenceDate
        )
        return RecencyValues(
            feeding: feedingSnapshot.feeding.completedAt,
            activity: [careSnapshot.pee.completedAt, careSnapshot.poop.completedAt]
                .compactMap { $0 }
                .max(),
            sleep: sleepSnapshot.sleep.completedAt
        )
    }

    private static func collapsedSequence<Value: Equatable>(_ values: [Value]) -> [Value] {
        values.reduce(into: [Value]()) { result, value in
            if result.last != value {
                result.append(value)
            }
        }
    }

    private static func dictionaryByID<Value, ID: Hashable>(
        _ values: [Value],
        id: (Value) -> ID
    ) -> [ID: Value] {
        values.reduce(into: [:]) { result, value in
            result[id(value)] = value
        }
    }

    private static func checkIns(
        for association: CycleAssociation,
        startingAt start: Date,
        endingAt end: Date,
        from allCheckIns: [SubjectiveStateCheckIn]
    ) -> [SubjectiveStateCheckIn] {
        let linkedRecordIDs = Set(association.sessions.map(\.id))
            .union(association.careRecords.map(\.id))

        return allCheckIns
            .filter { checkIn in
                // State collected as part of a saved E/A/S record must follow
                // that record, even when a later cycle shares the same clock
                // boundary. Truly manual Y entries remain time-bound.
                if let sourceRecordID = checkIn.sourceRecordID {
                    return linkedRecordIDs.contains(sourceRecordID)
                }
                return checkIn.recordedAt >= start && checkIn.recordedAt < end
            }
            .sorted { $0.recordedAt < $1.recordedAt }
    }

    private static func emptyElapsedText(since date: Date?, relativeTo reference: Date) -> String {
        guard let date else { return "距上次暂无".localized }
        let elapsed = CareRecencyTimeFormatter.liveCompactText(
            since: date,
            relativeTo: reference,
            emptyText: "暂无"
        )
        return AppLocalization.format("距上次 %@", elapsed)
    }

    private static func feedingTotalText(_ sessions: [FeedingSession]) -> String {
        let bottleAmount = sessions.reduce(0) { $0 + $1.totalBottleAmount }
        let breastMinutes = sessions.reduce(0) { $0 + $1.totalBreastDuration }
        let solidAmount = sessions.reduce(0) { $0 + $1.totalSolidAmount }
        var parts: [String] = []
        if bottleAmount > 0 { parts.append(AppMeasurementFormat.volume(Double(bottleAmount))) }
        if breastMinutes > 0 { parts.append(AppQuantityFormat.compactDuration(breastMinutes)) }
        if solidAmount > 0 {
            parts.append(AppLocalization.format("辅食 %@", AppMeasurementFormat.mass(solidAmount)))
        }
        return parts.isEmpty ? "已记录".localized : parts.joined(separator: " · ")
    }

    private static func feedingDetails(_ sessions: [FeedingSession]) -> [EasyCycleTimelineDetailItem] {
        sessions
            .sorted { $0.eventDate < $1.eventDate }
            .flatMap(feedingDetails)
    }

    private static func feedingDetails(_ session: FeedingSession) -> [EasyCycleTimelineDetailItem] {
        let eventTime = AppDateTimeFormat.time(session.eventDate)
        let item = RecordHomeTimelineItem.feeding(session)
        var details: [EasyCycleTimelineDetailItem] = []

        let breastEntries = session.entries.filter { $0.type == .breast }
        let leftMinutes = breastEntries
            .filter { $0.breastSide == .left }
            .compactMap(\.breastDuration)
            .reduce(0, +)
        let rightMinutes = breastEntries
            .filter { $0.breastSide == .right }
            .compactMap(\.breastDuration)
            .reduce(0, +)
        let totalBreastMinutes = breastEntries.compactMap(\.breastDuration).reduce(0, +)
        if totalBreastMinutes > 0 {
            let sideText = [
                leftMinutes > 0 ? AppLocalization.format("左 %@", AppQuantityFormat.compactDuration(leftMinutes)) : "",
                rightMinutes > 0 ? AppLocalization.format("右 %@", AppQuantityFormat.compactDuration(rightMinutes)) : ""
            ]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            let breastText = sideText.isEmpty
                ? AppLocalization.format("亲喂 %@", AppQuantityFormat.compactDuration(totalBreastMinutes))
                : AppLocalization.format("亲喂 %@ %@", AppQuantityFormat.compactDuration(totalBreastMinutes), sideText)
            details.append(EasyCycleTimelineDetailItem(
                id: "\(session.id.uuidString)-breast",
                timeText: eventTime,
                bodyText: breastText,
                item: item
            ))
        }

        let bottleGroups = Dictionary(
            grouping: session.entries.filter { $0.type == .bottle },
            by: { $0.milkType ?? .formula }
        )
        for (milkType, entries) in bottleGroups.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            let amount = entries.compactMap(\.bottleAmount).reduce(0, +)
            guard amount > 0 else { continue }
            let label = (milkType == .expressed ? "母乳瓶喂" : "瓶喂").localized
            details.append(EasyCycleTimelineDetailItem(
                id: "\(session.id.uuidString)-bottle-\(milkType.rawValue)",
                timeText: eventTime,
                bodyText: "\(label) \(AppMeasurementFormat.volume(Double(amount)))",
                item: item
            ))
        }

        for (index, entry) in session.entries.filter({ $0.type == .solid }).enumerated() {
            let food = entry.solidFood?.displayName ?? "辅食".localized
            let amount: String
            if let canonicalAmount = entry.solidAmount {
                switch entry.solidUnit ?? .g {
                case .g:
                    amount = AppMeasurementFormat.mass(canonicalAmount)
                case .ml:
                    amount = AppMeasurementFormat.volume(canonicalAmount)
                default:
                    amount = "\(AppMeasurementFormat.inputNumber(canonicalAmount)) \((entry.solidUnit ?? .g).localizedDisplayName)"
                }
            } else {
                amount = ""
            }
            details.append(EasyCycleTimelineDetailItem(
                id: "\(session.id.uuidString)-solid-\(index)",
                timeText: eventTime,
                bodyText: "\(food) \(amount)",
                item: item
            ))
        }

        if details.isEmpty {
            details.append(EasyCycleTimelineDetailItem(
                id: "\(session.id.uuidString)-feeding",
                timeText: eventTime,
                bodyText: "喂养已记录".localized,
                item: item
            ))
        }
        return details
    }

    private static func activityTypeName(_ record: CareRecord) -> String {
        switch record.kind {
        case .diaper:
            return "尿布".localized
        case .activity:
            return record.title
        case .sleep:
            return "睡眠".localized
        }
    }

    private static func activityDetails(_ records: [CareRecord]) -> [EasyCycleTimelineDetailItem] {
        records
            .sorted { $0.recordedAt < $1.recordedAt }
            .map { record in
                let bodyText: String
                switch record.kind {
                case .diaper:
                    bodyText = DiaperRecordType.displayDetail(title: record.title, detail: record.detail)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                case .activity:
                    let compactTitle = ActivityRecordDisplayFormatter.compactSummary(from: record.title)
                    let detail = record.detail
                        .replacingOccurrences(of: " 分钟", with: "分钟")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    bodyText = record.title.hasPrefix("宝宝完成") || detail.isEmpty
                        ? compactTitle
                        : "\(compactTitle) \(detail)"
                case .sleep:
                    bodyText = "睡眠".localized
                }
                return EasyCycleTimelineDetailItem(
                    id: record.id.uuidString,
                    timeText: AppDateTimeFormat.time(record.recordedAt),
                    bodyText: bodyText,
                    item: .care(record)
                )
            }
    }

    private static func sleepTotalText(_ records: [CareRecord]) -> String {
        let totalMinutes = records.reduce(0) {
            $0 + (SleepRecordFormatter.durationMinutes(from: $1.detail) ?? 0)
        }
        return AppQuantityFormat.compactDuration(totalMinutes)
    }

    private static func sleepDetails(_ records: [CareRecord]) -> [EasyCycleTimelineDetailItem] {
        records
            .sorted { $0.recordedAt < $1.recordedAt }
            .map { record in
                let item = RecordHomeTimelineItem.care(record)
                guard let minutes = SleepRecordFormatter.durationMinutes(from: record.detail) else {
                    return EasyCycleTimelineDetailItem(
                        id: record.id.uuidString,
                        timeText: AppDateTimeFormat.time(record.recordedAt),
                        bodyText: "睡眠已记录".localized,
                        item: item
                    )
                }
                let end = SleepRecordFormatter.endTime(start: record.recordedAt, durationMinutes: minutes)
                let title = SleepRecordFormatter.sleepTitle(start: record.recordedAt, end: end)
                return EasyCycleTimelineDetailItem(
                    id: record.id.uuidString,
                    timeText: AppDateTimeFormat.time(record.recordedAt),
                    bodyText: AppLocalization.format(
                        "%@ %@ %@ 醒来",
                        title,
                        AppQuantityFormat.compactDuration(minutes),
                        AppDateTimeFormat.time(end)
                    ),
                    item: item
                )
            }
    }
}

final class RecordHomeEasyFeedVisibilityRuntime: ObservableObject {
    var visibleCycleIDs: [UUID] = []
    var needsSnapshotRefresh = false
}

struct EasyCycleTimelineCardView: View, Equatable {
    let model: EasyCycleCardModel
    let onOpenStep: (EasyCycleStep) -> Void
    let onEdit: (RecordHomeTimelineItem) -> Void
    let onDelete: (RecordHomeTimelineItem) -> Void

    private var bodyTextColor: Color { DesignToken.textMuted }
    private var metaTextColor: Color { DesignToken.textFaint }
    private var statusColor: Color { DesignToken.primary }

    static func == (lhs: EasyCycleTimelineCardView, rhs: EasyCycleTimelineCardView) -> Bool {
        lhs.model == rhs.model
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            header
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(model.rows.enumerated()), id: \.element.id) { index, row in
                    timelineRow(row, isLast: index == model.rows.count - 1)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: DesignToken.largeCardRadius, style: .continuous)
                .fill(DesignToken.glassFill.opacity(0.74))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignToken.largeCardRadius, style: .continuous)
                        .stroke(DesignToken.glassStroke.opacity(0.74), lineWidth: 1)
                )
                .shadow(color: DesignToken.shadowColor.opacity(0.16), radius: 16, y: 8)
        )
        .contentShape(RoundedRectangle(cornerRadius: DesignToken.largeCardRadius, style: .continuous))
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            Text(model.ordinalText)
                .font(BBBFont.font(size: 12, weight: .heavy))
                .foregroundStyle(DesignToken.onPrimary)
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [DesignToken.primary, DesignToken.feedingBreast],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(Capsule().stroke(DesignToken.onPrimary.opacity(0.42), lineWidth: 1))
                        .shadow(color: DesignToken.shadowColor.opacity(0.20), radius: 9, y: 4)
                )

            Rectangle()
                .fill(DesignToken.primary.opacity(0.12))
                .frame(height: 1)

            Text(model.headerTimeText)
                .font(BBBFont.font(size: 11, weight: .heavy))
                .foregroundStyle(statusColor)
                .monospacedDigit()
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(Capsule().fill(statusColor.opacity(0.14)))
        }
    }

    private func timelineRow(_ row: EasyCycleTimelineRow, isLast: Bool) -> some View {
        let detailCount = max(row.detailItems.count, 1)
        let connectorHeight = max(24, CGFloat(detailCount) * 30 - 18)

        return HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                if row.step == .yearning {
                    Button {
                        onOpenStep(.yearning)
                    } label: {
                        timelineNode(row)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityLabel("状态，记录这一刻".localized)
                } else {
                    Button {
                        onOpenStep(row.step)
                    } label: {
                        timelineNode(row)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityLabel("\(row.step.title)，继续记录")
                }

                if !isLast {
                    Rectangle()
                        .fill(row.step.color.opacity(0.22))
                        .frame(width: 1.2, height: connectorHeight)
                        .padding(.top, 4)
                        .padding(.bottom, 4)
                }
            }
            .frame(width: 40)

            VStack(alignment: .leading, spacing: 7) {
                if row.step != .yearning {
                    timelineRowHeader(row)
                }

                if row.step == .yearning {
                    subjectiveStateContent
                        .padding(.top, model.babyStates.isEmpty ? 9 : 0)
                } else if row.detailItems.isEmpty {
                    Text(row.primaryText.localized)
                        .font(BBBFont.font(size: 12, weight: .semibold))
                        .foregroundStyle(bodyTextColor)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(1)
                } else {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(row.detailItems) { detail in
                            detailRow(detail)
                        }
                    }
                }

                if !row.secondaryText.isEmpty {
                    Text(row.secondaryText.localized)
                        .font(BBBFont.font(size: 11, weight: .semibold))
                        .foregroundStyle(metaTextColor)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(1)
                }
            }
            .padding(.top, row.step == .yearning ? 0 : 1)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.bottom, isLast ? 0 : 7)
    }

    private func timelineRowHeader(_ row: EasyCycleTimelineRow) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if !row.title.isEmpty {
                Text(row.title.localized)
                    .font(BBBFont.font(size: 13.5, weight: .heavy))
                    .foregroundStyle(DesignToken.textPrimary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if !row.timeText.isEmpty {
                Text(row.timeText.localized)
                    .font(BBBFont.font(size: 10.5, weight: .heavy))
                    .foregroundStyle(metaTextColor)
                    .monospacedDigit()
                    .lineLimit(1)
            }
        }
    }

    private func timelineNode(_ row: EasyCycleTimelineRow) -> some View {
        ZStack {
            Circle()
                .fill(row.step.color.opacity(0.16))
                .frame(width: 36, height: 36)
                .overlay(Circle().stroke(row.step.color.opacity(0.84), lineWidth: 1.25))
                .shadow(color: row.step.color.opacity(0.08), radius: 7, y: 4)

            Text(row.step.letter)
                .font(BBBFont.font(size: 14, weight: .heavy))
                .foregroundStyle(row.step.color)
                .frame(width: 36, height: 36)
        }
    }

    private var subjectiveStateContent: some View {
        VStack(alignment: .leading, spacing: 7) {
            if model.babyStates.isEmpty, model.parentState == nil {
                Text(model.yearningPlaceholderText.localized)
                    .font(BBBFont.font(size: 12, weight: .semibold))
                    .foregroundStyle(metaTextColor)
                    .lineLimit(1)
                    .accessibilityLabel("暂无状态，点击 Y 记录")
            } else if !model.babyStates.isEmpty {
                EasyCycleStateFlowLayout(horizontalSpacing: 8, verticalSpacing: 7) {
                    ForEach(Array(model.babyStates.enumerated()), id: \.offset) { _, state in
                        SubjectiveStateIcon(kind: .baby(state), size: 48)
                    }
                    if model.showsYearning {
                        Text("Yearning!".localized)
                            .font(BBBFont.font(size: 11.5, weight: .heavy))
                            .foregroundStyle(DesignToken.easyYearning)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .offset(y: -6)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                    (
                        model.babyStates.map(\.accessibilityLabel)
                            + (model.showsYearning ? ["Yearning!".localized] : [])
                    )
                    .joined(separator: ", ")
                )
            }

            if let parentState = model.parentState {
                Text(
                    "\(Text(AppLocalization.format("You %@ · ", parentState.title.localized)).font(BBBFont.font(size: 10.5, weight: .heavy)).foregroundColor(bodyTextColor))\(Text(model.parentPrompt).font(BBBFont.font(size: 10.5, weight: .semibold)).foregroundColor(metaTextColor))"
                )
                .lineLimit(1)
                .truncationMode(.tail)
                .minimumScaleFactor(0.88)
                .accessibilityLabel("\(parentState.accessibilityLabel)，\(model.parentPrompt)")
            }
        }
    }

    private func detailRow(_ detail: EasyCycleTimelineDetailItem) -> some View {
        HStack(alignment: .center, spacing: 7) {
            Text(detail.timeText.localized)
                .font(BBBFont.font(size: 7.8, weight: .semibold))
                .foregroundStyle(metaTextColor)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(width: 40, height: 15)
                .background(
                    Capsule()
                        .fill(metaTextColor.opacity(0.065))
                        .overlay(Capsule().stroke(metaTextColor.opacity(0.14), lineWidth: 0.7))
                )

            Text(detail.bodyText.localized)
                .font(BBBFont.font(size: 11.8, weight: .semibold))
                .foregroundStyle(bodyTextColor)
                .lineLimit(detail.item.isActivityRecord ? 1 : 2)
                .truncationMode(.tail)
                .minimumScaleFactor(0.78)
                .lineSpacing(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            Menu {
                Button {
                    onEdit(detail.item)
                } label: {
                    Label("修改", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    onDelete(detail.item)
                } label: {
                    Label("删除", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(metaTextColor.opacity(0.82))
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("更多操作")
        }
        .padding(.vertical, 2)
        .padding(.trailing, 2)
        .frame(minHeight: 28)
        .background(
            RoundedRectangle(cornerRadius: DesignToken.smallCornerRadius, style: .continuous)
                .fill(DesignToken.glassFill.opacity(0.18))
        )
        .contentShape(RoundedRectangle(cornerRadius: DesignToken.smallCornerRadius, style: .continuous))
    }
}

private struct EasyCycleStateFlowLayout: Layout {
    struct Cache {
        var sizes: [CGSize] = []
    }

    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat

    func makeCache(subviews: Subviews) -> Cache {
        Cache(sizes: subviews.map { $0.sizeThatFits(.unspecified) })
    }

    func updateCache(_ cache: inout Cache, subviews: Subviews) {
        cache.sizes = subviews.map { $0.sizeThatFits(.unspecified) }
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Cache
    ) -> CGSize {
        arrangement(maxWidth: proposal.width, sizes: cache.sizes).size
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Cache
    ) {
        let result = arrangement(maxWidth: bounds.width, sizes: cache.sizes)
        for (index, origin) in result.origins.enumerated() where index < subviews.count {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y),
                anchor: .topLeading,
                proposal: ProposedViewSize(cache.sizes[index])
            )
        }
    }

    private func arrangement(maxWidth proposedWidth: CGFloat?, sizes: [CGSize]) -> (
        size: CGSize,
        origins: [CGPoint]
    ) {
        guard !sizes.isEmpty else { return (.zero, []) }

        let maxWidth = proposedWidth.map { max($0, 0) } ?? .greatestFiniteMagnitude
        var lines: [[Int]] = []
        var lineWidths: [CGFloat] = []
        var lineHeights: [CGFloat] = []
        var currentLine: [Int] = []
        var currentWidth: CGFloat = 0
        var currentHeight: CGFloat = 0

        for (index, size) in sizes.enumerated() {
            let candidateWidth = currentLine.isEmpty
                ? size.width
                : currentWidth + horizontalSpacing + size.width
            if !currentLine.isEmpty, candidateWidth > maxWidth {
                lines.append(currentLine)
                lineWidths.append(currentWidth)
                lineHeights.append(currentHeight)
                currentLine = [index]
                currentWidth = size.width
                currentHeight = size.height
            } else {
                currentLine.append(index)
                currentWidth = candidateWidth
                currentHeight = max(currentHeight, size.height)
            }
        }

        lines.append(currentLine)
        lineWidths.append(currentWidth)
        lineHeights.append(currentHeight)

        var origins = Array(repeating: CGPoint.zero, count: sizes.count)
        var y: CGFloat = 0
        for lineIndex in lines.indices {
            var x: CGFloat = 0
            for itemIndex in lines[lineIndex] {
                let size = sizes[itemIndex]
                origins[itemIndex] = CGPoint(
                    x: x,
                    y: y + (lineHeights[lineIndex] - size.height) / 2
                )
                x += size.width + horizontalSpacing
            }
            y += lineHeights[lineIndex]
            if lineIndex < lines.count - 1 {
                y += verticalSpacing
            }
        }

        return (
            CGSize(
                width: lineWidths.max() ?? 0,
                height: y
            ),
            origins
        )
    }
}
