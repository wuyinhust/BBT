import Foundation
import SwiftUI

// MARK: - Immutable snapshot

enum BBBriefDataStatus: String, Codable, Hashable {
    case hasData
    case empty
}

enum BBBriefNightStatus: String, Codable, Hashable {
    case recorded
    case insufficient
    case notRecorded
}

enum BBBriefStoryTone: String, Codable, Hashable {
    case unrecorded
    case gentle
    case bright
    case settled
    case active
    case rested
    case sleepy
    case needsComfort
}

enum BBBriefRhythmKind: String, Codable, Hashable {
    case sleep
    case bottle
    case breast
    case solid
    case diaper
    case activity
}

struct BBBriefRhythmSpan: Codable, Equatable, Hashable {
    let startAt: Date
    let endAt: Date
    let kinds: [BBBriefRhythmKind]
    let isEstimated: Bool
    let isPoint: Bool
}

struct BBBriefEatSnapshot: Codable, Equatable {
    let feedingCount: Int
    let bottleAmountML: Int
    let breastMinutes: Int
    let solidAmountG: Int
}

struct BBBriefActivitySnapshot: Codable, Equatable {
    let activityCount: Int
    let diaperCount: Int
    let peeCount: Int
    let poopCount: Int
    let lastPoopAt: Date?
    let lastPoopTitle: String?

    init(
        activityCount: Int,
        diaperCount: Int,
        peeCount: Int,
        poopCount: Int,
        lastPoopAt: Date? = nil,
        lastPoopTitle: String? = nil
    ) {
        self.activityCount = activityCount
        self.diaperCount = diaperCount
        self.peeCount = peeCount
        self.poopCount = poopCount
        self.lastPoopAt = lastPoopAt
        self.lastPoopTitle = lastPoopTitle
    }
}

struct BBBriefSleepSnapshot: Codable, Equatable {
    let daySleepMinutes: Int
    let nightStatus: BBBriefNightStatus
    let bedtime: Date?
    let wakeTime: Date?
    let nightSleepMinutes: Int
    let nightSegmentCount: Int
    let sevenDayAverageNightSleepMinutes: Int?
    let sevenDayNightSampleCount: Int?

    init(
        daySleepMinutes: Int,
        nightStatus: BBBriefNightStatus,
        bedtime: Date?,
        wakeTime: Date?,
        nightSleepMinutes: Int,
        nightSegmentCount: Int,
        sevenDayAverageNightSleepMinutes: Int? = nil,
        sevenDayNightSampleCount: Int? = nil
    ) {
        self.daySleepMinutes = daySleepMinutes
        self.nightStatus = nightStatus
        self.bedtime = bedtime
        self.wakeTime = wakeTime
        self.nightSleepMinutes = nightSleepMinutes
        self.nightSegmentCount = nightSegmentCount
        self.sevenDayAverageNightSleepMinutes = sevenDayAverageNightSleepMinutes
        self.sevenDayNightSampleCount = sevenDayNightSampleCount
    }
}

struct BBBriefYearningSnapshot: Codable, Equatable {
    let recordCount: Int
    let latestBabyState: BabySubjectiveState?
    let dominantBabyState: BabySubjectiveState?
}

/// One finalized BBBrief for one local report day. Every field is a value so
/// source record edits can never mutate an already-generated brief.
struct DailyReportSnapshot: Identifiable, Codable, Equatable {
    static let currentSchemaVersion = 2

    var id: String { reportKey }

    let schemaVersion: Int
    let reportKey: String
    let reportDate: Date
    let timeZoneIdentifier: String
    let generatedAt: Date
    let dayWindow: DateInterval
    let nightWindow: DateInterval
    let dataStatus: BBBriefDataStatus
    let storyTone: BBBriefStoryTone
    let eat: BBBriefEatSnapshot
    let activity: BBBriefActivitySnapshot
    let sleep: BBBriefSleepSnapshot
    let yearning: BBBriefYearningSnapshot
    let rhythm: [BBBriefRhythmSpan]
    let sourceRecordCount: Int
}

// MARK: - Snapshot generation

enum BBBriefGenerator {
    static let availabilityHour = 9

    static func makeSnapshot(
        reportDate: Date,
        feedingSessions: [FeedingSession],
        careRecords: [CareRecord],
        subjectiveCheckIns: [SubjectiveStateCheckIn],
        babyAgeMonths: Int?,
        timeZoneIdentifier: String,
        generatedAt: Date = Date()
    ) -> DailyReportSnapshot {
        let calendar = reportCalendar(timeZoneIdentifier: timeZoneIdentifier)
        let dayStart = calendar.startOfDay(for: reportDate)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        let nightStart = calendar.date(bySettingHour: NightSleepAnalyzer.eveningStartHour, minute: 0, second: 0, of: dayStart) ?? dayStart
        let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayEnd
        let nightEnd = calendar.date(bySettingHour: NightSleepAnalyzer.morningStartCutoffHour, minute: 0, second: 0, of: nextDay) ?? nextDay

        let daySessions = feedingSessions.filter { $0.eventDate >= dayStart && $0.eventDate < dayEnd }
        let dayCareRecords = careRecords.filter { $0.recordedAt >= dayStart && $0.recordedAt < dayEnd }
        let dayCheckIns = subjectiveCheckIns.filter { $0.recordedAt >= dayStart && $0.recordedAt < dayEnd }
        let sleepRecords = careRecords.filter { $0.kind == .sleep }
        let daySleepMinutes = mergedSleepMinutes(
            records: sleepRecords,
            clippedTo: DateInterval(start: dayStart, end: dayEnd)
        )

        let nightWindow = DateInterval(start: nightStart, end: nightEnd)
        let nightRecords = sleepRecords.filter { record in
            guard let minutes = SleepRecordFormatter.durationMinutes(from: record.detail) else { return false }
            let endAt = SleepRecordFormatter.endTime(start: record.recordedAt, durationMinutes: minutes)
            return record.recordedAt < nightWindow.end && endAt > nightWindow.start
        }
        let nightEpisode = NightSleepAnalyzer.episodes(
            records: sleepRecords,
            from: nightWindow.start,
            to: nightWindow.end,
            calendar: calendar
        ).first { calendar.isDate($0.anchor, inSameDayAs: dayStart) }

        let sevenDayStartDay = calendar.date(byAdding: .day, value: -6, to: dayStart) ?? dayStart
        let sevenDayNightStart = calendar.date(
            bySettingHour: NightSleepAnalyzer.eveningStartHour,
            minute: 0,
            second: 0,
            of: sevenDayStartDay
        ) ?? sevenDayStartDay
        let sevenDayEpisodes = NightSleepAnalyzer.episodes(
            records: sleepRecords,
            from: sevenDayNightStart,
            to: nightWindow.end,
            calendar: calendar
        ).filter { episode in
            let anchorDay = calendar.startOfDay(for: episode.anchor)
            return anchorDay >= sevenDayStartDay && anchorDay <= dayStart
        }
        let sevenDayNightAverage = sevenDayEpisodes.isEmpty
            ? nil
            : Int((Double(sevenDayEpisodes.reduce(0) { $0 + $1.sleepMinutes }) / Double(sevenDayEpisodes.count)).rounded())

        let diapers = dayCareRecords.filter { $0.kind == .diaper }
        let lastPoop = careRecords
            .filter {
                $0.kind == .diaper
                    && $0.recordedAt < dayEnd
                    && DiaperRecordType.type(for: $0.title) == .poop
            }
            .max(by: { $0.recordedAt < $1.recordedAt })
        let latestBabyState = dayCheckIns.reversed().compactMap(\.babyState).first
        let dominantBabyState = dominantState(in: dayCheckIns)
        let hasAnyData = !daySessions.isEmpty
            || !dayCareRecords.isEmpty
            || !dayCheckIns.isEmpty
            || daySleepMinutes > 0
            || !nightRecords.isEmpty

        let eat = BBBriefEatSnapshot(
            feedingCount: daySessions.count,
            bottleAmountML: daySessions.reduce(0) { $0 + $1.totalBottleAmount },
            breastMinutes: daySessions.reduce(0) { $0 + $1.totalBreastDuration },
            solidAmountG: Int(daySessions.reduce(0.0) { $0 + $1.totalSolidAmount }.rounded())
        )
        let activity = BBBriefActivitySnapshot(
            activityCount: dayCareRecords.filter { $0.kind == .activity }.count,
            diaperCount: diapers.count,
            peeCount: diapers.filter { DiaperRecordType.type(for: $0.title) == .pee }.count,
            poopCount: diapers.filter { DiaperRecordType.type(for: $0.title) == .poop }.count,
            lastPoopAt: lastPoop?.recordedAt,
            lastPoopTitle: lastPoop?.title
        )
        let sleep = BBBriefSleepSnapshot(
            daySleepMinutes: daySleepMinutes,
            nightStatus: nightEpisode != nil ? .recorded : (nightRecords.isEmpty ? .notRecorded : .insufficient),
            bedtime: nightEpisode?.bedtime,
            wakeTime: nightEpisode?.wakeTime,
            nightSleepMinutes: nightEpisode?.sleepMinutes ?? 0,
            nightSegmentCount: nightEpisode?.segments.count ?? nightRecords.count,
            sevenDayAverageNightSleepMinutes: sevenDayNightAverage,
            sevenDayNightSampleCount: sevenDayEpisodes.count
        )
        let yearning = BBBriefYearningSnapshot(
            recordCount: dayCheckIns.count,
            latestBabyState: latestBabyState,
            dominantBabyState: dominantBabyState
        )

        return DailyReportSnapshot(
            schemaVersion: DailyReportSnapshot.currentSchemaVersion,
            reportKey: reportKey(for: dayStart, timeZoneIdentifier: timeZoneIdentifier),
            reportDate: dayStart,
            timeZoneIdentifier: timeZoneIdentifier,
            generatedAt: generatedAt,
            dayWindow: DateInterval(start: dayStart, end: dayEnd),
            nightWindow: nightWindow,
            dataStatus: hasAnyData ? .hasData : .empty,
            storyTone: storyTone(
                hasAnyData: hasAnyData,
                activity: activity,
                sleep: sleep,
                babyState: dominantBabyState ?? latestBabyState
            ),
            eat: eat,
            activity: activity,
            sleep: sleep,
            yearning: yearning,
            rhythm: rhythmSpans(
                reportDate: dayStart,
                sessions: daySessions,
                careRecords: careRecords,
                babyAgeMonths: babyAgeMonths,
                calendar: calendar
            ),
            sourceRecordCount: daySessions.count + dayCareRecords.count + dayCheckIns.count
        )
    }

    static func latestEligibleReportDate(
        now: Date,
        timeZoneIdentifier: String
    ) -> Date? {
        let calendar = reportCalendar(timeZoneIdentifier: timeZoneIdentifier)
        let today = calendar.startOfDay(for: now)
        let isReady = calendar.component(.hour, from: now) >= availabilityHour
        return calendar.date(byAdding: .day, value: isReady ? -1 : -2, to: today)
    }

    static func nextAvailabilityDate(
        after now: Date,
        timeZoneIdentifier: String
    ) -> Date {
        let calendar = reportCalendar(timeZoneIdentifier: timeZoneIdentifier)
        let today = calendar.startOfDay(for: now)
        let todayBoundary = calendar.date(
            bySettingHour: availabilityHour,
            minute: 0,
            second: 0,
            of: today
        ) ?? now.addingTimeInterval(60)
        if todayBoundary > now { return todayBoundary }
        return calendar.date(byAdding: .day, value: 1, to: todayBoundary) ?? now.addingTimeInterval(86_400)
    }

    static func reportKey(for date: Date, timeZoneIdentifier: String) -> String {
        let formatter = DateFormatter()
        formatter.calendar = reportCalendar(timeZoneIdentifier: timeZoneIdentifier)
        formatter.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return "bbbrief:\(timeZoneIdentifier):\(formatter.string(from: date))"
    }

    static func reportCalendar(timeZoneIdentifier: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .current
        return calendar
    }

    private static func dominantState(in checkIns: [SubjectiveStateCheckIn]) -> BabySubjectiveState? {
        let states = checkIns.compactMap { item in item.babyState.map { ($0, item.recordedAt) } }
        let grouped = Dictionary(grouping: states, by: \.0)
        return grouped.max { lhs, rhs in
            if lhs.value.count == rhs.value.count {
                return (lhs.value.map(\.1).max() ?? .distantPast) < (rhs.value.map(\.1).max() ?? .distantPast)
            }
            return lhs.value.count < rhs.value.count
        }?.key
    }

    private static func storyTone(
        hasAnyData: Bool,
        activity: BBBriefActivitySnapshot,
        sleep: BBBriefSleepSnapshot,
        babyState: BabySubjectiveState?
    ) -> BBBriefStoryTone {
        guard hasAnyData else { return .unrecorded }
        switch babyState {
        case .crying, .fussy:
            return .needsComfort
        case .sleepy:
            return .sleepy
        case .curious, .happy:
            return .bright
        case .calm:
            return .settled
        case nil:
            if activity.activityCount >= 3 { return .active }
            if sleep.nightStatus == .recorded { return .rested }
            return .gentle
        }
    }

    private static func rhythmSpans(
        reportDate: Date,
        sessions: [FeedingSession],
        careRecords: [CareRecord],
        babyAgeMonths: Int?,
        calendar: Calendar
    ) -> [BBBriefRhythmSpan] {
        let dayStart = calendar.startOfDay(for: reportDate)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart

        let feedingSpans = sessions.compactMap { session -> BBBriefRhythmSpan? in
            let kinds = Set(session.entries.map(\.type)).compactMap { type -> BBBriefRhythmKind? in
                switch type {
                case .bottle: return .bottle
                case .breast: return .breast
                case .solid: return .solid
                }
            }
            guard !kinds.isEmpty else { return nil }
            let span = session.resolvedTimeSpan(ageMonths: babyAgeMonths)
            return clippedSpan(
                startAt: span.startAt,
                endAt: span.endAt,
                kinds: kinds.sorted { $0.rawValue < $1.rawValue },
                isEstimated: span.isEstimated,
                isPoint: span.isPoint,
                dayStart: dayStart,
                dayEnd: dayEnd
            )
        }

        let careSpans = careRecords.compactMap { record -> BBBriefRhythmSpan? in
            switch record.kind {
            case .diaper:
                return clippedSpan(
                    startAt: record.recordedAt,
                    endAt: record.recordedAt,
                    kinds: [.diaper],
                    isEstimated: false,
                    isPoint: true,
                    dayStart: dayStart,
                    dayEnd: dayEnd
                )
            case .activity:
                return clippedSpan(
                    startAt: record.recordedAt,
                    endAt: record.recordedAt,
                    kinds: [.activity],
                    isEstimated: false,
                    isPoint: true,
                    dayStart: dayStart,
                    dayEnd: dayEnd
                )
            case .sleep:
                guard let minutes = SleepRecordFormatter.durationMinutes(from: record.detail) else { return nil }
                return clippedSpan(
                    startAt: record.recordedAt,
                    endAt: SleepRecordFormatter.endTime(start: record.recordedAt, durationMinutes: minutes),
                    kinds: [.sleep],
                    isEstimated: false,
                    isPoint: false,
                    dayStart: dayStart,
                    dayEnd: dayEnd
                )
            }
        }

        return (feedingSpans + careSpans).sorted { $0.startAt < $1.startAt }
    }

    private static func clippedSpan(
        startAt: Date,
        endAt: Date,
        kinds: [BBBriefRhythmKind],
        isEstimated: Bool,
        isPoint: Bool,
        dayStart: Date,
        dayEnd: Date
    ) -> BBBriefRhythmSpan? {
        if isPoint {
            guard startAt >= dayStart && startAt < dayEnd else { return nil }
            return BBBriefRhythmSpan(
                startAt: startAt,
                endAt: startAt,
                kinds: kinds,
                isEstimated: isEstimated,
                isPoint: true
            )
        }

        let clippedStart = max(startAt, dayStart)
        let clippedEnd = min(endAt, dayEnd)
        guard clippedEnd > clippedStart else { return nil }
        return BBBriefRhythmSpan(
            startAt: clippedStart,
            endAt: clippedEnd,
            kinds: kinds,
            isEstimated: isEstimated,
            isPoint: false
        )
    }

    private static func mergedSleepMinutes(records: [CareRecord], clippedTo interval: DateInterval) -> Int {
        let spans = records.compactMap { record -> DateInterval? in
            guard let minutes = SleepRecordFormatter.durationMinutes(from: record.detail) else { return nil }
            let endAt = SleepRecordFormatter.endTime(start: record.recordedAt, durationMinutes: minutes)
            let start = max(record.recordedAt, interval.start)
            let end = min(endAt, interval.end)
            guard end > start else { return nil }
            return DateInterval(start: start, end: end)
        }.sorted { $0.start < $1.start }

        guard var current = spans.first else { return 0 }
        var merged: [DateInterval] = []
        for span in spans.dropFirst() {
            if span.start <= current.end {
                current = DateInterval(start: current.start, end: max(current.end, span.end))
            } else {
                merged.append(current)
                current = span
            }
        }
        merged.append(current)
        let seconds = merged.reduce(0.0) { $0 + $1.duration }
        return max(Int((seconds / 60).rounded()), 0)
    }
}

// MARK: - Canonical store

@MainActor
final class BBBriefStore: ObservableObject {
    static let shared = BBBriefStore()

    @Published private(set) var snapshots: [DailyReportSnapshot] = []

    private let snapshotsKey = "bbbrief_daily_report_snapshots_v1"
    private let firstEligibleDateKey = "bbbrief_first_eligible_report_date_v1"
    private let timeZoneKey = "bbbrief_home_timezone_v1"
    private let openedKeysKey = "bbbrief_opened_report_keys_v1"
    private let defaults: UserDefaults
    private(set) var timeZoneIdentifier: String
    private var openedReportKeys: Set<String> = []

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let stored = defaults.string(forKey: timeZoneKey), TimeZone(identifier: stored) != nil {
            timeZoneIdentifier = stored
        } else {
            timeZoneIdentifier = TimeZone.current.identifier
            defaults.set(timeZoneIdentifier, forKey: timeZoneKey)
        }
        load()
    }

    func snapshot(for key: String) -> DailyReportSnapshot? {
        snapshots.first { $0.reportKey == key }
    }

    func snapshot(on date: Date) -> DailyReportSnapshot? {
        snapshot(for: BBBriefGenerator.reportKey(for: date, timeZoneIdentifier: timeZoneIdentifier))
    }

    func latestSnapshot() -> DailyReportSnapshot? {
        snapshots.first
    }

    func wasOpened(_ reportKey: String) -> Bool {
        openedReportKeys.contains(reportKey)
    }

    func markOpened(_ reportKey: String) {
        guard openedReportKeys.insert(reportKey).inserted else { return }
        if openedReportKeys.count > 2_000 {
            let validKeys = Set(snapshots.prefix(1_500).map(\.reportKey))
            openedReportKeys.formIntersection(validKeys)
        }
        persistOpenedKeys()
    }

    @discardableResult
    func insertIfAbsent(_ snapshot: DailyReportSnapshot) -> DailyReportSnapshot {
        if let existing = self.snapshot(for: snapshot.reportKey) {
            return existing
        }
        snapshots.append(snapshot)
        snapshots = Array(snapshots.sorted { $0.reportDate > $1.reportDate }.prefix(2_000))
        persistSnapshots()
        return snapshot
    }

    @discardableResult
    func reconcile(
        now: Date = Date(),
        feedingSessions: [FeedingSession],
        careRecords: [CareRecord],
        subjectiveCheckIns: [SubjectiveStateCheckIn],
        babyAgeMonths: Int?,
        legacyReports: [YesterdayReport] = []
    ) -> DailyReportSnapshot? {
        guard let latestEligible = BBBriefGenerator.latestEligibleReportDate(
            now: now,
            timeZoneIdentifier: timeZoneIdentifier
        ) else { return latestSnapshot() }

        let calendar = BBBriefGenerator.reportCalendar(timeZoneIdentifier: timeZoneIdentifier)
        let persistedStart = defaults.object(forKey: firstEligibleDateKey) as? Date
        let oldestLegacyDate = legacyReports.map(\.date).min().map { calendar.startOfDay(for: $0) }
        let requestedStartDate: Date
        if let persistedStart {
            requestedStartDate = calendar.startOfDay(for: persistedStart)
        } else {
            requestedStartDate = min(oldestLegacyDate ?? latestEligible, latestEligible)
            defaults.set(requestedStartDate, forKey: firstEligibleDateKey)
        }
        let earliestRetainedDate = calendar.date(byAdding: .day, value: -1_999, to: latestEligible) ?? latestEligible
        let startDate = max(requestedStartDate, earliestRetainedDate)

        var cursor = startDate
        var generated: [DailyReportSnapshot] = []
        var count = 0
        while cursor <= latestEligible, count < 2_000 {
            let key = BBBriefGenerator.reportKey(for: cursor, timeZoneIdentifier: timeZoneIdentifier)
            if snapshot(for: key) == nil {
                generated.append(BBBriefGenerator.makeSnapshot(
                    reportDate: cursor,
                    feedingSessions: feedingSessions,
                    careRecords: careRecords,
                    subjectiveCheckIns: subjectiveCheckIns,
                    babyAgeMonths: babyAgeMonths,
                    timeZoneIdentifier: timeZoneIdentifier,
                    generatedAt: now
                ))
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
            count += 1
        }

        if !generated.isEmpty {
            snapshots.append(contentsOf: generated)
            var seen = Set<String>()
            snapshots = Array(
                snapshots
                    .sorted { $0.reportDate > $1.reportDate }
                    .filter { seen.insert($0.reportKey).inserted }
                    .prefix(2_000)
            )
            persistSnapshots()
        }
        return snapshot(on: latestEligible) ?? latestSnapshot()
    }

    func nextAvailabilityDate(after now: Date = Date()) -> Date {
        BBBriefGenerator.nextAvailabilityDate(after: now, timeZoneIdentifier: timeZoneIdentifier)
    }

    private func load() {
        if let data = defaults.data(forKey: snapshotsKey),
           data.count <= BBBDataSafetyLimits.maxJSONDataBytes,
           let decoded = try? JSONDecoder().decode([DailyReportSnapshot].self, from: data) {
            var seen = Set<String>()
            snapshots = Array(
                decoded
                    .filter { $0.schemaVersion <= DailyReportSnapshot.currentSchemaVersion }
                    .sorted { $0.reportDate > $1.reportDate }
                    .filter { !$0.reportKey.isEmpty && seen.insert($0.reportKey).inserted }
                    .prefix(2_000)
            )
        }
        if let data = defaults.data(forKey: openedKeysKey),
           data.count <= BBBDataSafetyLimits.maxJSONDataBytes,
           let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) {
            openedReportKeys = Set(decoded.filter { !$0.isEmpty }.prefix(2_000))
        }
    }

    private func persistSnapshots() {
        guard let data = try? JSONEncoder().encode(snapshots),
              data.count <= BBBDataSafetyLimits.maxJSONDataBytes else { return }
        defaults.set(data, forKey: snapshotsKey)
    }

    private func persistOpenedKeys() {
        guard let data = try? JSONEncoder().encode(openedReportKeys),
              data.count <= BBBDataSafetyLimits.maxJSONDataBytes else { return }
        defaults.set(data, forKey: openedKeysKey)
    }
}

// MARK: - Copy

enum BBBriefCopy {
    static var brand: String { "BBBrief" }
    static var archiveTitle: String { text("BBBrief", "BBBrief", "BBBrief") }
    static var archiveSubtitle: String { text("每天一份宝宝简报", "每天一份寶寶簡報", "A brief about baby's day") }
    static var question: String { text("这一天，宝宝过得怎么样？", "這一天，寶寶過得怎麼樣？", "How was baby's day?") }
    static var finalized: String { text("这份简报已经定稿，之后修改记录不会改变它。", "這份簡報已經定稿，之後修改記錄不會改變它。", "This brief is final. Later record edits will not change it.") }
    static var emptyTitle: String { text("这一天还没有足够的记录", "這一天還沒有足夠的記錄", "There were not enough records for this day") }
    static var emptyBody: String { text("我们不会把“未记录”说成宝宝没有吃、没有活动或没有睡。接下来可以继续从任何一次照护开始。", "我們不會把「未記錄」說成寶寶沒有吃、沒有活動或沒有睡。接下來可以繼續從任何一次照護開始。", "Missing records do not mean baby did not eat, move, or sleep. You can continue with any care moment next.") }
    static var rhythmTitle: String { text("一天的节奏", "一天的節奏", "The day's rhythm") }
    static var rhythmEmpty: String { text("这一天还没有形成可见的记录节奏", "這一天還沒有形成可見的記錄節奏", "No visible care rhythm was recorded") }
    static var nightTitle: String { text("前一夜睡眠", "前一夜睡眠", "Previous night") }
    static var nightRecorded: String { text("记录到一段完整夜睡", "記錄到一段完整夜睡", "A complete night sleep was recorded") }
    static var nightInsufficient: String { text("有睡眠记录，但还不足以形成完整夜睡", "有睡眠記錄，但還不足以形成完整夜睡", "Sleep was recorded, but not enough to form a complete night") }
    static var nightMissing: String { text("暂未记录到可分析的完整夜睡", "暫未記錄到可分析的完整夜睡", "No complete night sleep was recorded") }
    static var unrecorded: String { text("未记录", "未記錄", "Not recorded") }
    static var noBriefs: String { text("还没有 BBBrief", "還沒有 BBBrief", "No BBBrief yet") }
    static var noBriefsDetail: String { text("第一份简报会在早上 09:00 后生成，即使前一天没有记录。", "第一份簡報會在早上 09:00 後生成，即使前一天沒有記錄。", "The first brief appears after 09:00, even when the previous day has no records.") }
    static var rewardTitle: String { text("今日 BBBrief 已读", "今日 BBBrief 已讀", "Today's BBBrief read") }
    static var rewardSubtitle: String { text("认真回看宝宝的一天，也是一份照护", "認真回看寶寶的一天，也是一份照護", "Looking back on baby's day is care, too") }

    static func storyTitle(for tone: BBBriefStoryTone) -> String {
        switch tone {
        case .unrecorded: return emptyTitle
        case .gentle: return text("宝宝度过了有迹可循的一天", "寶寶度過了有跡可循的一天", "Baby had a day you can trace")
        case .bright: return text("宝宝这一天有不少明亮的时刻", "寶寶這一天有不少明亮的時刻", "Baby had some bright moments")
        case .settled: return text("宝宝这一天整体平静安稳", "寶寶這一天整體平靜安穩", "Baby's day was mostly calm")
        case .active: return text("宝宝这一天很愿意活动和探索", "寶寶這一天很願意活動和探索", "Baby was ready to move and explore")
        case .rested: return text("睡眠为宝宝的一天托住了节奏", "睡眠為寶寶的一天托住了節奏", "Sleep gave baby's day a steady rhythm")
        case .sleepy: return text("宝宝这一天有些困倦", "寶寶這一天有些睏倦", "Baby seemed a little sleepy")
        case .needsComfort: return text("宝宝这一天更需要安抚和陪伴", "寶寶這一天更需要安撫和陪伴", "Baby needed more comfort and closeness")
        }
    }

    static func storyBody(for snapshot: DailyReportSnapshot) -> String {
        guard snapshot.dataStatus == .hasData else { return emptyBody }
        let feed = snapshot.eat.feedingCount
        let activities = snapshot.activity.activityCount
        switch snapshot.storyTone {
        case .bright:
            return text("从记录里能看到宝宝的好奇或满足。吃、活动和睡眠共同组成了这一天。", "從記錄裡能看到寶寶的好奇或滿足。吃、活動和睡眠共同組成了這一天。", "The records show curiosity or contentment, with eating, activity, and sleep shaping the day.")
        case .settled:
            return text("平静是这一天最清楚的线索。继续按现在的方式记录，就能慢慢看见宝宝自己的节奏。", "平靜是這一天最清楚的線索。繼續按現在的方式記錄，就能慢慢看見寶寶自己的節奏。", "Calm was the clearest signal. Continuing to record will reveal baby's own rhythm over time.")
        case .active:
            return text("活动记录比较集中，宝宝用身体认识周围。也可以结合睡眠看看活动后的恢复。", "活動記錄比較集中，寶寶用身體認識周圍。也可以結合睡眠看看活動後的恢復。", "Activity clustered through the day. Sleep can add context about recovery afterward.")
        case .rested:
            return text("前一夜形成了完整记录。睡眠只是线索，不是评分；把它和白天的状态放在一起看更有意义。", "前一夜形成了完整記錄。睡眠只是線索，不是評分；把它和白天的狀態放在一起看更有意義。", "The previous night formed a complete record. Sleep is a clue, not a score, and is most useful beside daytime signals.")
        case .sleepy:
            return text("困倦是这一天比较明显的需求。简报只呈现已记录的线索，不替宝宝下结论。", "睏倦是這一天比較明顯的需求。簡報只呈現已記錄的線索，不替寶寶下結論。", "Sleepiness was a noticeable need. This brief shows recorded clues without drawing conclusions for baby.")
        case .needsComfort:
            return text("哭闹或烦躁并不是“表现不好”，更像宝宝在表达需求。你的回应和陪伴也是这一天的一部分。", "哭鬧或煩躁並不是「表現不好」，更像寶寶在表達需求。你的回應和陪伴也是這一天的一部分。", "Crying or fussiness is not poor performance; it is often a way to express needs. Your response is part of the day, too.")
        case .gentle:
            return text("记录到 %d 次喂养和 %d 次活动。数字只是线索，真正重要的是它们共同讲出的日常。", "記錄到 %d 次餵養和 %d 次活動。數字只是線索，真正重要的是它們共同說出的日常。", "There were %d feeding records and %d activity records. Numbers are clues; the day they describe matters more.", feed, activities)
        case .unrecorded:
            return emptyBody
        }
    }

    static func generatedText(_ date: Date) -> String {
        text("定稿于 %@", "定稿於 %@", "Finalized %@", "\(AppDateTimeFormat.date(date)) \(AppDateTimeFormat.time(date))")
    }

    private static func text(_ simplified: String, _ traditional: String, _ english: String, _ arguments: CVarArg...) -> String {
        let format: String
        switch AppLocalization.language {
        case .simplifiedChinese: format = simplified
        case .traditionalChinese: format = traditional
        case .english: format = english
        }
        guard !arguments.isEmpty else { return format }
        return String(format: format, locale: AppLocalization.locale, arguments: arguments)
    }
}

// MARK: - Canonical full-screen page

/// The single presentation surface for every BBBrief entry point. The page
/// reads frozen snapshots only; it never reaches back into live care stores.
struct BBBriefPage: View {
    @EnvironmentObject private var recruitmentStore: CompanionRecruitmentStore
    @EnvironmentObject private var briefStore: BBBriefStore
    @State private var selectedReportKey: String?
    @State private var checkedRewardKeys = Set<String>()
    @State private var preparedRewardTransactionID: String?

    let snapshot: DailyReportSnapshot
    var snapshots: [DailyReportSnapshot] = []
    let lastPresentedReportRewardTransactionID: String
    let onRewardReady: (BBBuckTransaction) -> Void
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    dateHeader
                    reportCalendar
                    rhythmCard
                    nightCard
                    lastPoopCard
                    interpretationCard
                    finalizedFooter
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 36)
                .frame(maxWidth: 620, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(HomeSoftBackground().ignoresSafeArea())
            .navigationTitle(BBBriefCopy.brand)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    AppPageCloseButton(action: dismissBrief)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .onAppear {
            selectedReportKey = snapshot.reportKey
        }
        .onDisappear {
            prepareRewardForDismissal()
        }
        .task(id: displayedSnapshot.reportKey) {
            await Task.yield()
            guard !Task.isCancelled else { return }
            briefStore.markOpened(displayedSnapshot.reportKey)
            awardRewardIfNeeded()
        }
    }

    private var dateHeader: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(AppDateTimeFormat.date(displayedSnapshot.reportDate))
                .font(BBBFont.font(size: 28, weight: .heavy))
                .foregroundStyle(DesignToken.textPrimary)
                .monospacedDigit()

            Text(BBBriefCopy.question)
                .font(BBBFont.font(size: 14, weight: .bold))
                .foregroundStyle(DesignToken.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var reportCalendar: some View {
        HStack(spacing: 6) {
            ForEach(calendarDeck) { item in
                let isSelected = item.reportKey == displayedSnapshot.reportKey
                Button {
                    selectedReportKey = item.reportKey
                } label: {
                    VStack(spacing: 2) {
                        Text(weekdayText(item.reportDate))
                            .font(BBBFont.font(size: 9, weight: .bold))
                        Text(dayText(item.reportDate))
                            .font(BBBFont.font(size: 14, weight: .heavy))
                            .monospacedDigit()
                    }
                    .foregroundStyle(isSelected ? DesignToken.onPrimary : DesignToken.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                            .fill(isSelected ? DesignToken.primary : DesignToken.surfaceRaised.opacity(0.78))
                            .overlay(
                                RoundedRectangle(cornerRadius: 17, style: .continuous)
                                    .stroke(
                                        isSelected ? DesignToken.primary.opacity(0.42) : DesignToken.glassStroke.opacity(0.68),
                                        lineWidth: 1
                                    )
                            )
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(AppDateTimeFormat.date(item.reportDate))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var rhythmCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(DesignToken.onPrimary)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(DesignToken.primary))

                Text(BBBriefCopy.todayRhythmTitle)
                    .font(BBBFont.font(size: 16, weight: .bold))
                    .foregroundStyle(DesignToken.textPrimary)
            }

            ZStack {
                TodayRhythmMinimalTimeline(
                    date: displayedSnapshot.reportDate,
                    spans: rhythmTimelineSpans,
                    height: 88
                )
                .opacity(displayedSnapshot.rhythm.isEmpty ? 0.16 : 1)

                if displayedSnapshot.rhythm.isEmpty {
                    Text(BBBriefCopy.rhythmEmpty)
                        .font(BBBFont.font(size: 11, weight: .bold))
                        .foregroundStyle(DesignToken.textMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 34)
                }
            }

            easyTileRow
        }
        .padding(16)
        .background(homeCardSurface(accent: DesignToken.primary))
        .accessibilityElement(children: .contain)
    }

    private var easyTileRow: some View {
        HStack(spacing: 8) {
            RhythmMetricTile(
                badge: "E",
                title: "喂养",
                value: compactEatValue,
                color: DesignToken.easyEat,
                style: .light
            )
            RhythmMetricTile(
                badge: "A",
                title: "活动",
                value: compactActivityValue,
                color: DesignToken.easyActivity,
                style: .light
            )
            RhythmMetricTile(
                badge: "S",
                title: "睡眠",
                value: displayedSnapshot.sleep.daySleepMinutes > 0
                    ? AppQuantityFormat.compactDuration(displayedSnapshot.sleep.daySleepMinutes)
                    : "--",
                color: DesignToken.easySleep,
                style: .light
            )
            RhythmSubjectiveStateTile(
                babyState: displayedSnapshot.yearning.dominantBabyState ?? displayedSnapshot.yearning.latestBabyState,
                style: .light
            )
        }
        .frame(height: 44)
    }

    private var nightCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(BBBriefCopy.nightTitle, systemImage: "moon.stars.fill", color: DesignToken.easySleep)

            switch displayedSnapshot.sleep.nightStatus {
            case .recorded:
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(nightTimeRange)
                        .font(BBBFont.font(size: 20, weight: .heavy))
                        .foregroundStyle(DesignToken.textPrimary)
                    Spacer(minLength: 8)
                    Text(AppQuantityFormat.compactDuration(displayedSnapshot.sleep.nightSleepMinutes))
                        .font(BBBFont.font(size: 16, weight: .heavy))
                        .foregroundStyle(DesignToken.easySleep)
                }
            case .insufficient:
                statusRow(BBBriefCopy.nightInsufficient, systemImage: "moon.zzz")
            case .notRecorded:
                statusRow(BBBriefCopy.nightMissing, systemImage: "moon.zzz")
            }

            Divider().overlay(DesignToken.easySleep.opacity(0.14))

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(BBBriefCopy.sevenDayAverageTitle)
                        .font(BBBFont.font(size: 10, weight: .bold))
                        .foregroundStyle(DesignToken.textMuted)
                    Text(nightAverage.map { AppQuantityFormat.compactDuration($0.minutes) } ?? "--")
                        .font(BBBFont.font(size: 15, weight: .heavy))
                        .foregroundStyle(DesignToken.textPrimary)
                }

                Spacer(minLength: 8)

                Text(nightComparisonText)
                    .font(BBBFont.font(size: 10, weight: .heavy))
                    .foregroundStyle(DesignToken.easySleep)
                    .padding(.horizontal, 10)
                    .frame(minHeight: 30)
                    .background(Capsule().fill(DesignToken.easySleepSoft.opacity(0.72)))
            }
        }
        .padding(16)
        .background(homeCardSurface(accent: DesignToken.easySleep))
        .accessibilityElement(children: .combine)
    }

    private var lastPoopCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            sectionHeader(BBBriefCopy.lastPoopTitle, systemImage: "circle.dotted", color: DesignToken.easyActivity)

            if let lastPoopAt = displayedSnapshot.activity.lastPoopAt {
                Text(lastPoopTimeText(lastPoopAt))
                    .font(BBBFont.font(size: 18, weight: .heavy))
                    .foregroundStyle(DesignToken.textPrimary)
                    .monospacedDigit()
                Text(displayedSnapshot.activity.lastPoopTitle ?? BBBriefCopy.poopRecorded)
                    .font(BBBFont.font(size: 12, weight: .medium))
                    .foregroundStyle(DesignToken.textMuted)
            } else if displayedSnapshot.activity.poopCount > 0 {
                Text(BBBriefCopy.poopCountFallback(displayedSnapshot.activity.poopCount))
                    .font(BBBFont.font(size: 14, weight: .bold))
                    .foregroundStyle(DesignToken.textPrimary)
            } else {
                statusRow(BBBriefCopy.poopMissing, systemImage: "minus.circle")
            }
        }
        .padding(16)
        .background(homeCardSurface(accent: DesignToken.easyActivity))
        .accessibilityElement(children: .combine)
    }

    private var interpretationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "sun.horizon.fill")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(DesignToken.onPrimary)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(DesignToken.onPrimary.opacity(0.18)))

                Text(BBBriefCopy.interpretationTitle)
                    .font(BBBFont.font(size: 16, weight: .bold))
                    .foregroundStyle(DesignToken.onPrimary)
            }

            VStack(alignment: .leading, spacing: 5) {
                ForEach(Array(interpretationLines.enumerated()), id: \.offset) { _, line in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Circle()
                            .fill(DesignToken.onPrimary.opacity(0.72))
                            .frame(width: 3, height: 3)
                        Text(line)
                            .font(BBBFont.font(size: 11, weight: .semibold))
                            .foregroundStyle(DesignToken.onPrimary.opacity(0.95))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignToken.largeCardRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [DesignToken.primary, DesignToken.primary.opacity(0.74)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignToken.largeCardRadius, style: .continuous)
                        .stroke(DesignToken.onPrimary.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: DesignToken.primary.opacity(0.16), radius: 14, y: 7)
        )
        .accessibilityElement(children: .combine)
    }

    private var finalizedFooter: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(DesignToken.rewardText)
            VStack(alignment: .leading, spacing: 3) {
                Text(BBBriefCopy.generatedText(displayedSnapshot.generatedAt))
                    .font(BBBFont.font(size: 11, weight: .bold))
                    .foregroundStyle(DesignToken.textSecondary)
                Text(BBBriefCopy.finalized)
                    .font(BBBFont.font(size: 10.5, weight: .medium))
                    .foregroundStyle(DesignToken.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 2)
    }

    private func sectionHeader(_ title: String, systemImage: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(color)
            Text(title)
                .font(BBBFont.font(size: 14, weight: .heavy))
                .foregroundStyle(DesignToken.textPrimary)
        }
    }

    private func statusRow(_ text: String, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: systemImage)
                .foregroundStyle(DesignToken.textMuted)
                .frame(width: 22)
            Text(text)
                .font(BBBFont.font(size: 12, weight: .medium))
                .foregroundStyle(DesignToken.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func homeCardSurface(accent: Color) -> some View {
        RoundedRectangle(cornerRadius: DesignToken.largeCardRadius, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: DesignToken.largeCardRadius, style: .continuous)
                    .fill(DesignToken.glassFill.opacity(0.62))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignToken.largeCardRadius, style: .continuous)
                    .stroke(accent.opacity(0.20), lineWidth: 1)
            )
            .shadow(color: accent.opacity(0.06), radius: 12, y: 5)
    }

    private var reportDeck: [DailyReportSnapshot] {
        var seen = Set<String>()
        var source = snapshots
        if !source.contains(where: { $0.reportKey == snapshot.reportKey }) {
            source.append(snapshot)
        }
        if source.isEmpty { source = [snapshot] }
        return source
            .filter { seen.insert($0.reportKey).inserted }
            .sorted { $0.reportDate < $1.reportDate }
    }

    private var displayedSnapshot: DailyReportSnapshot {
        let selected = reportDeck.first { $0.reportKey == selectedReportKey } ?? snapshot
        return briefStore.snapshot(for: selected.reportKey) ?? selected
    }

    private var calendarDeck: [DailyReportSnapshot] {
        guard reportDeck.count > 7,
              let index = reportDeck.firstIndex(where: { $0.reportKey == displayedSnapshot.reportKey }) else {
            return reportDeck
        }
        let lower = min(max(index - 3, 0), reportDeck.count - 7)
        return Array(reportDeck[lower..<(lower + 7)])
    }

    private var rhythmTimelineSpans: [RhythmTimelineSpan] {
        displayedSnapshot.rhythm.map { span in
            RhythmTimelineSpan(
                startAt: span.startAt,
                endAt: span.endAt,
                kinds: span.kinds.map(\.timelineKind),
                isEstimated: span.isEstimated,
                isPoint: span.isPoint
            )
        }
    }

    private var compactEatValue: String {
        var values: [String] = []
        if displayedSnapshot.eat.bottleAmountML > 0 {
            values.append(AppMeasurementFormat.volume(Double(displayedSnapshot.eat.bottleAmountML)))
        }
        if displayedSnapshot.eat.breastMinutes > 0 {
            values.append(AppQuantityFormat.compactDuration(displayedSnapshot.eat.breastMinutes))
        }
        if displayedSnapshot.eat.solidAmountG > 0 {
            values.append(AppMeasurementFormat.mass(Double(displayedSnapshot.eat.solidAmountG)))
        }
        return values.isEmpty ? "--" : values.joined(separator: " ")
    }

    private var compactActivityValue: String {
        let value = displayedSnapshot.activity
        var parts: [String] = []
        if value.poopCount > 0 { parts.append("\(value.poopCount)拉") }
        if value.peeCount > 0 { parts.append("\(value.peeCount)尿") }
        if value.activityCount > 0 { parts.append("\(value.activityCount)玩") }
        return parts.isEmpty ? "--" : parts.joined(separator: " · ")
    }

    private var nightTimeRange: String {
        guard let bedtime = displayedSnapshot.sleep.bedtime,
              let wakeTime = displayedSnapshot.sleep.wakeTime else { return "--" }
        return "\(AppDateTimeFormat.time(bedtime))–\(AppDateTimeFormat.time(wakeTime))"
    }

    private var nightAverage: (minutes: Int, count: Int)? {
        if let minutes = displayedSnapshot.sleep.sevenDayAverageNightSleepMinutes,
           let count = displayedSnapshot.sleep.sevenDayNightSampleCount,
           count > 0 {
            return (minutes, count)
        }

        let candidates = reportDeck
            .filter {
                $0.reportDate <= displayedSnapshot.reportDate
                    && $0.sleep.nightStatus == .recorded
                    && $0.sleep.nightSleepMinutes > 0
            }
            .suffix(7)
        guard !candidates.isEmpty else { return nil }
        let average = Int((Double(candidates.reduce(0) { $0 + $1.sleep.nightSleepMinutes }) / Double(candidates.count)).rounded())
        return (average, candidates.count)
    }

    private var nightComparisonText: String {
        guard displayedSnapshot.sleep.nightStatus == .recorded,
              let average = nightAverage else { return BBBriefCopy.noComparison }
        let delta = displayedSnapshot.sleep.nightSleepMinutes - average.minutes
        if abs(delta) <= 15 { return BBBriefCopy.closeToAverage }
        return delta > 0
            ? BBBriefCopy.aboveAverage(abs(delta))
            : BBBriefCopy.belowAverage(abs(delta))
    }

    private var interpretationLines: [String] {
        BBBriefCopy.interpretationLines(for: displayedSnapshot)
    }

    private func lastPoopTimeText(_ date: Date) -> String {
        let calendar = BBBriefGenerator.reportCalendar(timeZoneIdentifier: displayedSnapshot.timeZoneIdentifier)
        if calendar.isDate(date, inSameDayAs: displayedSnapshot.reportDate) {
            return BBBriefCopy.todayAt(AppDateTimeFormat.time(date))
        }
        return "\(AppDateTimeFormat.date(date)) · \(AppDateTimeFormat.time(date))"
    }

    private func weekdayText(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated).locale(AppLocalization.locale))
    }

    private func dayText(_ date: Date) -> String {
        date.formatted(.dateTime.day().locale(AppLocalization.locale))
    }

    private func awardRewardIfNeeded(now: Date = Date()) {
        let active = displayedSnapshot
        guard checkedRewardKeys.insert(active.reportKey).inserted else { return }
        _ = recruitmentStore.awardDailyTask(
            .viewReport,
            eventDate: now,
            referenceID: active.reportKey,
            now: now
        )
    }

    private func dismissBrief() {
        prepareRewardForDismissal()
        onDismiss()
    }

    private func prepareRewardForDismissal(now: Date = Date()) {
        awardRewardIfNeeded(now: now)
        let transaction = recruitmentStore.transactions
            .filter {
                $0.source == .dailyTask
                    && $0.taskID == .viewReport
                    && $0.referenceID.map(checkedRewardKeys.contains) == true
                    && Calendar.current.isDate($0.createdAt, inSameDayAs: now)
                    && $0.id != lastPresentedReportRewardTransactionID
            }
            .max(by: { $0.createdAt < $1.createdAt })
        guard let transaction, preparedRewardTransactionID != transaction.id else { return }
        preparedRewardTransactionID = transaction.id
        onRewardReady(transaction)
    }
}

// Legacy renderer kept private only so older worktree references remain easy
// to compare during migration. Production entry points use BBBriefPage.

private struct LegacyBBBriefOverlay: View {
    @EnvironmentObject private var recruitmentStore: CompanionRecruitmentStore
    @EnvironmentObject private var briefStore: BBBriefStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selectedReportKey: String?
    @State private var checkedRewardKeys = Set<String>()
    @State private var preparedRewardTransactionID: String?

    let snapshot: DailyReportSnapshot
    var snapshots: [DailyReportSnapshot] = []
    let lastPresentedReportRewardTransactionID: String
    let onRewardReady: (BBBuckTransaction) -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            AppModalBackdrop(bodyColor: DesignToken.surfaceSoft, accent: DesignToken.reward)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: dismissBrief)

            ScrollView(showsIndicators: false) {
                briefCard
                    .padding(.horizontal, 18)
                    .padding(.top, 24)
                    .padding(.bottom, 80)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .accessibilityElement(children: .contain)
        .onAppear {
            selectedReportKey = displayedSnapshot.reportKey
        }
        .onDisappear {
            prepareRewardForDismissal()
        }
        .task(id: displayedSnapshot.reportKey) {
            await Task.yield()
            guard !Task.isCancelled else { return }
            briefStore.markOpened(displayedSnapshot.reportKey)
            awardRewardIfNeeded()
        }
    }

    private var briefCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            storySection
            rhythmSection
            metricSection
            nightSection
            finalizedSection

            if reportDeck.count > 1 {
                CardCarouselIndicator(
                    index: selectedReportIndex,
                    total: reportDeck.count,
                    tint: DesignToken.reward,
                    accessibilityTitle: "BBBrief"
                )
                .frame(maxWidth: .infinity)
            }
        }
        .padding(dynamicTypeSize.isAccessibilitySize ? 18 : 22)
        .frame(maxWidth: 560, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(DesignToken.surfaceRaised.opacity(0.96))
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(DesignToken.reward.opacity(0.28), lineWidth: 1)
                )
                .shadow(color: DesignToken.shadowColor.opacity(0.18), radius: 28, y: 14)
        )
        .contentShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .simultaneousGesture(reportSwipeGesture)
        .onTapGesture {}
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    Image(systemName: "sun.horizon.fill")
                        .foregroundStyle(DesignToken.rewardText)
                    Text(BBBriefCopy.brand)
                        .font(BBBFont.font(size: 12, weight: .heavy))
                        .tracking(1.1)
                        .foregroundStyle(DesignToken.rewardText)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(DesignToken.rewardSoft.opacity(0.88)))

                Text(AppDateTimeFormat.date(displayedSnapshot.reportDate))
                    .font(BBBFont.font(size: 28, weight: .heavy))
                    .foregroundStyle(DesignToken.textPrimary)

                Text(BBBriefCopy.question)
                    .font(BBBFont.font(size: 14, weight: .bold))
                    .foregroundStyle(DesignToken.textSecondary)
            }

            Spacer(minLength: 8)

            Button(action: dismissBrief) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(DesignToken.textSecondary)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(DesignToken.surfaceSoft))
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(BBBriefCopy.textForAccessibilityClose)
        }
    }

    private var storySection: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(BBBriefCopy.storyTitle(for: displayedSnapshot.storyTone))
                .font(BBBFont.font(size: 21, weight: .heavy))
                .foregroundStyle(DesignToken.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(BBBriefCopy.storyBody(for: displayedSnapshot))
                .font(BBBFont.font(size: 14, weight: .medium))
                .foregroundStyle(DesignToken.textMuted)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(DesignToken.rewardSoft.opacity(0.42))
        )
    }

    private var rhythmSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(BBBriefCopy.rhythmTitle, systemImage: "waveform.path.ecg")

            ZStack {
                TodayRhythmMinimalTimeline(
                    date: displayedSnapshot.reportDate,
                    spans: rhythmTimelineSpans,
                    height: 92
                )
                .opacity(displayedSnapshot.rhythm.isEmpty ? 0.18 : 1)

                if displayedSnapshot.rhythm.isEmpty {
                    Text(BBBriefCopy.rhythmEmpty)
                        .font(BBBFont.font(size: 12, weight: .bold))
                        .foregroundStyle(DesignToken.textMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(DesignToken.iconSoftBG.opacity(0.46))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(DesignToken.glassStroke.opacity(0.65), lineWidth: 0.8)
                    )
            )
        }
    }

    @ViewBuilder
    private var metricSection: some View {
        let columns = dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible(), spacing: 10)]
            : [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

        LazyVGrid(columns: columns, spacing: 10) {
            metricCard(
                badge: "E",
                title: BBBriefCopy.eatTitle,
                value: eatValue,
                detail: eatDetail,
                color: DesignToken.easyEat
            )
            metricCard(
                badge: "A",
                title: BBBriefCopy.activityTitle,
                value: activityValue,
                detail: activityDetail,
                color: DesignToken.easyActivity
            )
            metricCard(
                badge: "S",
                title: BBBriefCopy.sleepTitle,
                value: displayedSnapshot.sleep.daySleepMinutes > 0
                    ? AppQuantityFormat.compactDuration(displayedSnapshot.sleep.daySleepMinutes)
                    : BBBriefCopy.unrecorded,
                detail: BBBriefCopy.daySleepDetail,
                color: DesignToken.easySleep
            )
            metricCard(
                badge: "Y",
                title: BBBriefCopy.yearningTitle,
                value: yearningValue,
                detail: yearningDetail,
                color: DesignToken.easyYearning
            )
        }
    }

    private func metricCard(
        badge: String,
        title: String,
        value: String,
        detail: String,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                Text(badge)
                    .font(BBBFont.font(size: 11, weight: .heavy))
                    .foregroundStyle(color)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(color.opacity(0.14)))

                Text(title)
                    .font(BBBFont.font(size: 13, weight: .heavy))
                    .foregroundStyle(DesignToken.textSecondary)
            }

            Text(value)
                .font(BBBFont.font(size: 17, weight: .heavy))
                .foregroundStyle(DesignToken.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(detail)
                .font(BBBFont.font(size: 11, weight: .medium))
                .foregroundStyle(DesignToken.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 126, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(color.opacity(0.075))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(color.opacity(0.18), lineWidth: 0.8)
                )
        )
        .accessibilityElement(children: .combine)
    }

    private var nightSection: some View {
        VStack(alignment: .leading, spacing: 11) {
            sectionTitle(BBBriefCopy.nightTitle, systemImage: "moon.stars.fill")

            switch displayedSnapshot.sleep.nightStatus {
            case .recorded:
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(nightTimeRange)
                        .font(BBBFont.font(size: 20, weight: .heavy))
                        .foregroundStyle(DesignToken.textPrimary)
                    Spacer(minLength: 8)
                    Text(AppQuantityFormat.compactDuration(displayedSnapshot.sleep.nightSleepMinutes))
                        .font(BBBFont.font(size: 15, weight: .heavy))
                        .foregroundStyle(DesignToken.easySleep)
                }
                Text(BBBriefCopy.nightRecorded)
                    .font(BBBFont.font(size: 12, weight: .medium))
                    .foregroundStyle(DesignToken.textMuted)
            case .insufficient:
                emptyNightRow(BBBriefCopy.nightInsufficient)
            case .notRecorded:
                emptyNightRow(BBBriefCopy.nightMissing)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(DesignToken.easySleepSoft.opacity(0.46))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(DesignToken.easySleep.opacity(0.18), lineWidth: 0.8)
                )
        )
    }

    private func emptyNightRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "moon.zzz")
                .foregroundStyle(DesignToken.easySleep)
                .frame(width: 24)
            Text(text)
                .font(BBBFont.font(size: 13, weight: .medium))
                .foregroundStyle(DesignToken.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var finalizedSection: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(DesignToken.rewardText)
            VStack(alignment: .leading, spacing: 3) {
                Text(BBBriefCopy.generatedText(displayedSnapshot.generatedAt))
                    .font(BBBFont.font(size: 11, weight: .bold))
                    .foregroundStyle(DesignToken.textSecondary)
                Text(BBBriefCopy.finalized)
                    .font(BBBFont.font(size: 10.5, weight: .medium))
                    .foregroundStyle(DesignToken.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, 2)
    }

    private func sectionTitle(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
                .foregroundStyle(DesignToken.rewardText)
            Text(title)
                .font(BBBFont.font(size: 14, weight: .heavy))
                .foregroundStyle(DesignToken.textPrimary)
        }
    }

    private var reportDeck: [DailyReportSnapshot] {
        var seen = Set<String>()
        var source = snapshots
        if !source.contains(where: { $0.reportKey == snapshot.reportKey }) {
            source.insert(snapshot, at: 0)
        }
        if source.isEmpty { source = [snapshot] }
        return source.filter { seen.insert($0.reportKey).inserted }
    }

    private var displayedSnapshot: DailyReportSnapshot {
        let selected = reportDeck.first { $0.reportKey == selectedReportKey } ?? snapshot
        return briefStore.snapshot(for: selected.reportKey) ?? selected
    }

    private var selectedReportIndex: Int {
        reportDeck.firstIndex { $0.reportKey == displayedSnapshot.reportKey } ?? 0
    }

    private var rhythmTimelineSpans: [RhythmTimelineSpan] {
        displayedSnapshot.rhythm.map { span in
            RhythmTimelineSpan(
                startAt: span.startAt,
                endAt: span.endAt,
                kinds: span.kinds.map(\.timelineKind),
                isEstimated: span.isEstimated,
                isPoint: span.isPoint
            )
        }
    }

    private var eatValue: String {
        var values: [String] = []
        if displayedSnapshot.eat.bottleAmountML > 0 {
            values.append(AppMeasurementFormat.volume(Double(displayedSnapshot.eat.bottleAmountML)))
        }
        if displayedSnapshot.eat.breastMinutes > 0 {
            values.append(AppQuantityFormat.compactDuration(displayedSnapshot.eat.breastMinutes))
        }
        if displayedSnapshot.eat.solidAmountG > 0 {
            values.append(AppMeasurementFormat.mass(Double(displayedSnapshot.eat.solidAmountG)))
        }
        return values.isEmpty ? BBBriefCopy.unrecorded : values.joined(separator: " · ")
    }

    private var eatDetail: String {
        displayedSnapshot.eat.feedingCount > 0
            ? BBBriefCopy.countDetail(displayedSnapshot.eat.feedingCount)
            : BBBriefCopy.basedOnRecordedCare
    }

    private var activityValue: String {
        let total = displayedSnapshot.activity.activityCount + displayedSnapshot.activity.diaperCount
        return total > 0 ? BBBriefCopy.countDetail(total) : BBBriefCopy.unrecorded
    }

    private var activityDetail: String {
        let value = displayedSnapshot.activity
        guard value.activityCount + value.diaperCount > 0 else { return BBBriefCopy.basedOnRecordedCare }
        return BBBriefCopy.activityDetail(
            activity: value.activityCount,
            pee: value.peeCount,
            poop: value.poopCount
        )
    }

    private var yearningValue: String {
        guard let state = displayedSnapshot.yearning.dominantBabyState ?? displayedSnapshot.yearning.latestBabyState else {
            return BBBriefCopy.unrecorded
        }
        return "\(state.emoji) \(state.title)"
    }

    private var yearningDetail: String {
        displayedSnapshot.yearning.recordCount > 0
            ? BBBriefCopy.yearningDetail(displayedSnapshot.yearning.recordCount)
            : BBBriefCopy.basedOnRecordedCare
    }

    private var nightTimeRange: String {
        guard let bedtime = displayedSnapshot.sleep.bedtime,
              let wakeTime = displayedSnapshot.sleep.wakeTime else { return "--" }
        return "\(AppDateTimeFormat.time(bedtime))–\(AppDateTimeFormat.time(wakeTime))"
    }

    private var reportSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height
                guard reportDeck.count > 1,
                      abs(horizontal) > abs(vertical),
                      abs(horizontal) > 52 else { return }
                let next = (selectedReportIndex + (horizontal < 0 ? 1 : -1) + reportDeck.count) % reportDeck.count
                withAnimation(reduceMotion ? nil : .spring(response: 0.30, dampingFraction: 0.86)) {
                    selectedReportKey = reportDeck[next].reportKey
                }
            }
    }

    private func awardRewardIfNeeded(now: Date = Date()) {
        let active = displayedSnapshot
        guard checkedRewardKeys.insert(active.reportKey).inserted else { return }
        _ = recruitmentStore.awardDailyTask(
            .viewReport,
            eventDate: now,
            referenceID: active.reportKey,
            now: now
        )
    }

    private func dismissBrief() {
        prepareRewardForDismissal()
        onDismiss()
    }

    private func prepareRewardForDismissal(now: Date = Date()) {
        awardRewardIfNeeded(now: now)
        let transaction = recruitmentStore.transactions
            .filter {
                $0.source == .dailyTask
                    && $0.taskID == .viewReport
                    && $0.referenceID.map(checkedRewardKeys.contains) == true
                    && Calendar.current.isDate($0.createdAt, inSameDayAs: now)
                    && $0.id != lastPresentedReportRewardTransactionID
            }
            .max(by: { $0.createdAt < $1.createdAt })
        guard let transaction, preparedRewardTransactionID != transaction.id else { return }
        preparedRewardTransactionID = transaction.id
        onRewardReady(transaction)
    }
}

private extension BBBriefRhythmKind {
    var timelineKind: RhythmTimelineKind {
        switch self {
        case .sleep: return .sleep
        case .bottle: return .bottle
        case .breast: return .breast
        case .solid: return .solid
        case .diaper: return .diaper
        case .activity: return .activity
        }
    }
}

extension BBBriefCopy {
    static var textForAccessibilityClose: String { text("关闭 BBBrief", "關閉 BBBrief", "Close BBBrief") }
    static var todayRhythmTitle: String { text("当日节奏", "當日節奏", "Daily rhythm") }
    static var sevenDayAverageTitle: String { text("近 7 夜平均", "近 7 夜平均", "7-night average") }
    static var noComparison: String { text("暂无可比数据", "暫無可比資料", "No comparison yet") }
    static var closeToAverage: String { text("接近平均", "接近平均", "Near average") }
    static var lastPoopTitle: String { text("上一次 💩", "上一次 💩", "Last poop 💩") }
    static var poopRecorded: String { text("记录到一次便便", "記錄到一次便便", "A poop was recorded") }
    static var poopMissing: String { text("截至这一天还没有便便记录", "截至這一天還沒有便便記錄", "No poop had been recorded by this day") }
    static var interpretationTitle: String { text("这一天的解读", "這一天的解讀", "Reading this day") }
    static var eatTitle: String { text("吃 · Eat", "吃 · Eat", "Eat") }
    static var activityTitle: String { text("动 · Activity", "動 · Activity", "Activity") }
    static var sleepTitle: String { text("睡 · Sleep", "睡 · Sleep", "Sleep") }
    static var yearningTitle: String { text("需 · Yearning", "需 · Yearning", "Yearning") }
    static var daySleepDetail: String { text("报告日 00:00–24:00 记录睡眠", "報告日 00:00–24:00 記錄睡眠", "Recorded sleep from 00:00–24:00") }
    static var basedOnRecordedCare: String { text("基于已记录的照护", "基於已記錄的照護", "Based on recorded care") }

    static func countDetail(_ count: Int) -> String {
        text("共 %d 次记录", "共 %d 次記錄", "%d records", count)
    }

    static func activityDetail(activity: Int, pee: Int, poop: Int) -> String {
        text("活动 %d · 尿布 %d尿 %d拉", "活動 %d · 尿布 %d尿 %d拉", "Activity %d · Diapers %d wet %d dirty", activity, pee, poop)
    }

    static func yearningDetail(_ count: Int) -> String {
        text("从 %d 次 Y 状态中看到", "從 %d 次 Y 狀態中看到", "Seen across %d Y check-ins", count)
    }

    static func aboveAverage(_ minutes: Int) -> String {
        text("比平均多 %@", "比平均多 %@", "%@ above average", AppQuantityFormat.compactDuration(minutes))
    }

    static func belowAverage(_ minutes: Int) -> String {
        text("比平均少 %@", "比平均少 %@", "%@ below average", AppQuantityFormat.compactDuration(minutes))
    }

    static func todayAt(_ time: String) -> String {
        text("当天 %@", "當天 %@", "That day at %@", time)
    }

    static func poopCountFallback(_ count: Int) -> String {
        text("当天记录了 %d 次便便", "當天記錄了 %d 次便便", "%d poop records that day", count)
    }

    static func interpretationLines(for snapshot: DailyReportSnapshot) -> [String] {
        let recordedDayCategories = [
            snapshot.eat.feedingCount > 0,
            snapshot.activity.activityCount + snapshot.activity.diaperCount > 0,
            snapshot.sleep.daySleepMinutes > 0,
            snapshot.yearning.recordCount > 0
        ].filter { $0 }.count
        guard recordedDayCategories > 0 else {
            return [text("当天还没有足够的 E/A/S/Y 记录，解读只保留空状态，不替宝宝下结论。", "當天還沒有足夠的 E/A/S/Y 記錄，解讀只保留空狀態，不替寶寶下結論。", "There were not enough E/A/S/Y records that day, so the reading stays empty rather than drawing conclusions.")]
        }

        var lines = [
            recordedDayCategories >= 2
                ? text("从当天记录里，已经能看到宝宝吃、活动、睡眠或需求之间的日常节奏。", "從當天記錄裡，已經能看到寶寶吃、活動、睡眠或需求之間的日常節奏。", "That day's records begin to show baby's everyday rhythm across eating, activity, sleep, and needs.")
                : text("当天记录还比较少，下面只描述已经留下的照护线索。", "當天記錄還比較少，下面只描述已經留下的照護線索。", "That day's records were still limited, so this reading only describes the care signals that were recorded.")
        ]
        if snapshot.eat.feedingCount > 0 {
            var amounts: [String] = []
            if snapshot.eat.bottleAmountML > 0 {
                amounts.append(AppMeasurementFormat.volume(Double(snapshot.eat.bottleAmountML)))
            }
            if snapshot.eat.breastMinutes > 0 {
                amounts.append(AppQuantityFormat.compactDuration(snapshot.eat.breastMinutes))
            }
            if snapshot.eat.solidAmountG > 0 {
                amounts.append(AppMeasurementFormat.mass(Double(snapshot.eat.solidAmountG)))
            }
            let amountText = amounts.isEmpty ? "" : text("，合计 %@", "，合計 %@", ", totaling %@", amounts.joined(separator: " · "))
            lines.append(text("当天记录了 %d 次喂养%@。", "當天記錄了 %d 次餵養%@。", "%d feedings were recorded%@.", snapshot.eat.feedingCount, amountText))
        }

        let activityCount = snapshot.activity.activityCount
        let diaperCount = snapshot.activity.diaperCount
        if activityCount + diaperCount > 0 {
            lines.append(text("当天有 %d 次活动、%d 次尿布记录。", "當天有 %d 次活動、%d 次尿布記錄。", "That day had %d activity and %d diaper records.", activityCount, diaperCount))
        }

        if snapshot.sleep.daySleepMinutes > 0 {
            lines.append(text("00:00–24:00 共记录睡眠 %@。", "00:00–24:00 共記錄睡眠 %@。", "%@ of sleep was recorded from 00:00–24:00.", AppQuantityFormat.compactDuration(snapshot.sleep.daySleepMinutes)))
        }

        if let state = snapshot.yearning.dominantBabyState ?? snapshot.yearning.latestBabyState {
            lines.append(text("当天记录里较明显的状态是 %@ %@。", "當天記錄裡較明顯的狀態是 %@ %@。", "The clearest recorded state was %@ %@.", state.emoji, state.title))
        }
        return Array(lines.prefix(5))
    }
}

// MARK: - Archive

struct BBBriefArchiveView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var briefStore: BBBriefStore
    @State private var selectedSnapshot: DailyReportSnapshot?
    @State private var pendingReward: BBBuckTransaction?
    @AppStorage("daily_report_celebration_last_transaction_id_v1")
    private var lastPresentedReportRewardTransactionID = ""

    var body: some View {
        NavigationStack {
            Group {
                if briefStore.snapshots.isEmpty {
                    emptyState
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 12) {
                            ForEach(briefStore.snapshots) { snapshot in
                                Button { selectedSnapshot = snapshot } label: {
                                    archiveRow(snapshot)
                                }
                                .buttonStyle(ScaleButtonStyle())
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 16)
                    }
                }
            }
            .background(HomeSoftBackground().ignoresSafeArea())
            .navigationTitle(BBBriefCopy.archiveTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    AppPageCloseButton { dismiss() }
                }
            }
            .fullScreenCover(item: $selectedSnapshot, onDismiss: presentPendingReward) { snapshot in
                BBBriefPage(
                    snapshot: snapshot,
                    snapshots: briefStore.snapshots,
                    lastPresentedReportRewardTransactionID: lastPresentedReportRewardTransactionID,
                    onRewardReady: { pendingReward = $0 },
                    onDismiss: { selectedSnapshot = nil }
                )
            }
        }
        .appFeedbackHost(AppFeedbackCenter.shared, isEmbedded: true)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(BBBriefCopy.noBriefs, systemImage: "sun.horizon")
        } description: {
            Text(BBBriefCopy.noBriefsDetail)
        }
    }

    private func archiveRow(_ snapshot: DailyReportSnapshot) -> some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(spacing: 2) {
                Text(dayNumber(snapshot.reportDate))
                    .font(BBBFont.font(size: 22, weight: .heavy))
                    .foregroundStyle(DesignToken.rewardText)
                Text(monthText(snapshot.reportDate))
                    .font(BBBFont.font(size: 10, weight: .heavy))
                    .foregroundStyle(DesignToken.textSecondary)
            }
            .frame(width: 52, height: 58)
            .background(RoundedRectangle(cornerRadius: 17, style: .continuous).fill(DesignToken.rewardSoft.opacity(0.76)))

            VStack(alignment: .leading, spacing: 5) {
                Text(BBBriefCopy.storyTitle(for: snapshot.storyTone))
                    .font(BBBFont.font(size: 15, weight: .heavy))
                    .foregroundStyle(DesignToken.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(snapshot.dataStatus == .empty ? BBBriefCopy.unrecorded : compactMetrics(snapshot))
                    .font(BBBFont.font(size: 11, weight: .medium))
                    .foregroundStyle(DesignToken.textMuted)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(DesignToken.textSecondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(DesignToken.surfaceRaised.opacity(0.92))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(DesignToken.glassStroke.opacity(0.72), lineWidth: 0.8))
        )
        .accessibilityElement(children: .combine)
    }

    private func compactMetrics(_ snapshot: DailyReportSnapshot) -> String {
        [
            "E \(snapshot.eat.feedingCount)",
            "A \(snapshot.activity.activityCount + snapshot.activity.diaperCount)",
            "S \(snapshot.sleep.daySleepMinutes > 0 ? AppQuantityFormat.compactDuration(snapshot.sleep.daySleepMinutes) : BBBriefCopy.unrecorded)",
            "Y \(snapshot.yearning.dominantBabyState?.emoji ?? snapshot.yearning.latestBabyState?.emoji ?? "–")"
        ].joined(separator: "  ·  ")
    }

    private func dayNumber(_ date: Date) -> String {
        date.formatted(.dateTime.day().locale(AppLocalization.locale))
    }

    private func monthText(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).locale(AppLocalization.locale))
    }

    private func presentPendingReward() {
        guard let transaction = pendingReward else { return }
        pendingReward = nil
        BBBriefRewardFeedback.present(transaction)
        lastPresentedReportRewardTransactionID = transaction.id
    }
}

enum BBBriefRewardFeedback {
    @MainActor
    static func present(_ transaction: BBBuckTransaction) {
        AppFeedbackCenter.shared.presentReward(
            amount: transaction.amount,
            title: BBBriefCopy.rewardTitle,
            subtitle: BBBriefCopy.rewardSubtitle,
            deduplicationKey: "bbbrief-reward:\(transaction.id)"
        )
    }
}
