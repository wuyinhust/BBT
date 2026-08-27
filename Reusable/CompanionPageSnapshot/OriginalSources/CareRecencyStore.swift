import ActivityKit
import Foundation
import WidgetKit

enum CareRecencyCalculator {
    static func snapshot(
        feedingSessions: [FeedingSession],
        careRecords: [CareRecord],
        referenceDate: Date = Date()
    ) -> CareRecencySnapshot {
        CareRecencySnapshot(
            generatedAt: referenceDate,
            feeding: latestFeeding(in: feedingSessions, relativeTo: referenceDate),
            pee: latestDiaper(.pee, in: careRecords, relativeTo: referenceDate),
            poop: latestDiaper(.poop, in: careRecords, relativeTo: referenceDate),
            sleep: latestSleep(in: careRecords, relativeTo: referenceDate)
        )
    }

    static func feedingCompletedAt(_ session: FeedingSession) -> Date {
        if let startAt = session.startAt,
           let endAt = session.endAt,
           startAt <= endAt {
            return endAt
        }
        return session.createdAt
    }

    static func sleepCompletedAt(_ record: CareRecord) -> Date {
        guard record.kind == .sleep,
              let duration = SleepRecordFormatter.durationMinutes(from: record.detail) else {
            return record.recordedAt
        }
        return SleepRecordFormatter.endTime(start: record.recordedAt, durationMinutes: duration)
    }

    private static func latestFeeding(
        in sessions: [FeedingSession],
        relativeTo referenceDate: Date
    ) -> CareRecencyItem {
        let latest = sessions
            .filter(\.hasData)
            .compactMap { session -> (FeedingSession, Date)? in
                let completedAt = feedingCompletedAt(session)
                return completedAt <= referenceDate ? (session, completedAt) : nil
            }
            .max { $0.1 < $1.1 }

        return CareRecencyItem(
            kind: .feeding,
            completedAt: latest?.1,
            detail: latest.map { feedingDetail($0.0) } ?? "暂无记录"
        )
    }

    private static func latestDiaper(
        _ type: DiaperRecordType,
        in records: [CareRecord],
        relativeTo referenceDate: Date
    ) -> CareRecencyItem {
        let latest = records
            .filter { record in
                record.kind == .diaper
                    && record.recordedAt <= referenceDate
                    && diaperRecord(record, contains: type)
            }
            .max { $0.recordedAt < $1.recordedAt }

        let kind: CareRecencyKind = type == .pee ? .pee : .poop
        return CareRecencyItem(
            kind: kind,
            completedAt: latest?.recordedAt,
            detail: latest.map {
                DiaperRecordType.displayDetail(title: $0.title, detail: $0.detail)
            } ?? "暂无记录"
        )
    }

    private static func latestSleep(
        in records: [CareRecord],
        relativeTo referenceDate: Date
    ) -> CareRecencyItem {
        let latest = records
            .filter { $0.kind == .sleep }
            .compactMap { record -> (CareRecord, Date)? in
                let completedAt = sleepCompletedAt(record)
                return completedAt <= referenceDate ? (record, completedAt) : nil
            }
            .max { $0.1 < $1.1 }

        let detail = latest.map { record, _ in
            guard let duration = SleepRecordFormatter.durationMinutes(from: record.detail) else {
                return record.title
            }
            return "\(record.title) · \(SleepRecordFormatter.durationText(minutes: duration))"
        } ?? "暂无记录"

        return CareRecencyItem(kind: .sleep, completedAt: latest?.1, detail: detail)
    }

    private static func diaperRecord(_ record: CareRecord, contains type: DiaperRecordType) -> Bool {
        if record.title == "混合" {
            return true
        }
        return DiaperRecordType.type(for: record.title) == type
    }

    private static func feedingDetail(_ session: FeedingSession) -> String {
        if session.totalBottleAmount > 0 {
            return AppMeasurementFormat.volume(Double(session.totalBottleAmount))
        }
        if session.totalBreastDuration > 0 {
            return "\(session.totalBreastDuration)分钟"
        }
        if session.totalSolidAmount > 0 {
            return AppMeasurementFormat.mass(session.totalSolidAmount)
        }
        return "已记录"
    }
}

@MainActor
enum CareRecencyCoordinator {
    static func refresh(
        feedingSessions: [FeedingSession],
        careRecords: [CareRecord],
        babyAgeMonths: Int?,
        referenceDate: Date = Date()
    ) {
        let snapshot = CareRecencyCalculator.snapshot(
            feedingSessions: feedingSessions,
            careRecords: careRecords,
            referenceDate: referenceDate
        )
        persist(
            snapshot,
            feedingSessions: feedingSessions,
            careRecords: careRecords,
            referenceDate: referenceDate
        )
        LiveActivityManager.shared.startOrUpdate(
            snapshot: snapshot,
            activeTiming: ActiveTimingStorage.load(),
            babyAgeMonths: babyAgeMonths
        )
    }

    static func refreshFromSharedStorage(babyAgeMonths: Int?) {
        let defaults = UserDefaults(suiteName: WidgetStorageKey.appGroupID)
        let sessions: [FeedingSession]
        if let data = defaults?.data(forKey: WidgetStorageKey.feedingSessions),
           data.count <= BBBDataSafetyLimits.maxJSONDataBytes,
           let decoded = try? JSONDecoder().decode([FeedingSession].self, from: data) {
            sessions = Array(decoded.prefix(BBBDataSafetyLimits.maxFeedingSessions))
        } else {
            sessions = []
        }

        let records: [CareRecord]
        if let data = defaults?.data(forKey: WidgetStorageKey.careRecords),
           data.count <= BBBDataSafetyLimits.maxJSONDataBytes,
           let decoded = try? JSONDecoder().decode([CareRecord].self, from: data) {
            records = Array(decoded.prefix(BBBDataSafetyLimits.maxCareRecords))
        } else {
            records = []
        }
        refresh(feedingSessions: sessions, careRecords: records, babyAgeMonths: babyAgeMonths)
    }

    private static func persist(
        _ snapshot: CareRecencySnapshot,
        feedingSessions: [FeedingSession],
        careRecords: [CareRecord],
        referenceDate: Date
    ) {
        let activeTiming = ActiveTimingStorage.load()
        let surfaceSnapshot = WidgetSurfaceSnapshotV2(
            generatedAt: referenceDate,
            babyName: BabyProfileStore.shared.currentProfile.name,
            recency: snapshot,
            activeTiming: activeTiming,
            todayRhythm: todayRhythmSnapshot(
                feedingSessions: feedingSessions,
                careRecords: careRecords,
                referenceDate: referenceDate
            )
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        let defaults = UserDefaults(suiteName: WidgetStorageKey.appGroupID)
        defaults?.set(data, forKey: WidgetStorageKey.careRecencySnapshot)
        WidgetSurfaceStorage.save(surfaceSnapshot, defaults: defaults)
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetStorageKey.lastFeedingWidgetKind)
    }

    private static func todayRhythmSnapshot(
        feedingSessions: [FeedingSession],
        careRecords: [CareRecord],
        referenceDate: Date
    ) -> WidgetTodayRhythmSnapshot {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: referenceDate)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? referenceDate
        let daySessions = feedingSessions.filter {
            $0.hasData && $0.eventDate >= dayStart && $0.eventDate < dayEnd && $0.eventDate <= referenceDate
        }
        let dayCareRecords = careRecords.filter {
            $0.recordedAt >= dayStart && $0.recordedAt < dayEnd && $0.recordedAt <= referenceDate
        }
        let dayYearningCheckIns = SubjectiveStateStore.shared.checkIns(on: referenceDate)

        let events = daySessions.map { session in
            WidgetRhythmEvent(
                id: "feeding-\(session.id.uuidString)",
                phase: .eat,
                recordedAt: session.eventDate
            )
        } + dayCareRecords.compactMap { record -> WidgetRhythmEvent? in
            let phase: WidgetRhythmPhase
            switch record.kind {
            case .activity, .diaper:
                phase = .activity
            case .sleep:
                phase = .sleep
            }
            return WidgetRhythmEvent(
                id: "care-\(record.id.uuidString)",
                phase: phase,
                recordedAt: record.recordedAt
            )
        } + dayYearningCheckIns.map { checkIn in
            WidgetRhythmEvent(
                id: "yearning-\(checkIn.id.uuidString)",
                phase: .yearning,
                recordedAt: checkIn.recordedAt
            )
        }

        let recentEvents = events
            .sorted { $0.recordedAt > $1.recordedAt }
            .prefix(3)
            .map { $0 }

        let cycles = EasyCycleStore.shared.cycles(on: referenceDate)
        let currentCycle = EasyCycleStore.shared.currentCycle(on: referenceDate)
        let cycleNumber = currentCycle.flatMap { cycle in
            cycles.firstIndex { $0.id == cycle.id }.map { cycles.count - $0 }
        }
        let phase = currentCycle.flatMap { WidgetRhythmPhase(rawValue: $0.currentPhase.rawValue) }
        let phaseStartedAt = currentCycle.flatMap { cycle in
            rhythmPhaseStart(
                cycle: cycle,
                phase: cycle.currentPhase,
                feedingSessions: feedingSessions,
                careRecords: careRecords
            ) ?? cycle.updatedAt
        }

        return WidgetTodayRhythmSnapshot(
            dayStart: dayStart,
            currentCycleNumber: cycleNumber,
            currentPhase: phase,
            currentPhaseStartedAt: phaseStartedAt,
            completedCycleCount: cycles.filter { $0.endedAt != nil || $0.currentPhase == .yearning }.count,
            recentEvents: Array(recentEvents)
        )
    }

    private static func rhythmPhaseStart(
        cycle: EasyCycle,
        phase: EasyCyclePhase,
        feedingSessions: [FeedingSession],
        careRecords: [CareRecord]
    ) -> Date? {
        let links = cycle.linkedRecords.filter { $0.phase == phase }
        let feedingIDs = Set(links.filter { $0.type == .feeding }.map(\.recordID))
        let careIDs = Set(links.filter { $0.type == .care }.map(\.recordID))
        let feedingDates = feedingSessions
            .filter { feedingIDs.contains($0.id) }
            .map(\.eventDate)
        let careDates = careRecords
            .filter { careIDs.contains($0.id) }
            .map(\.recordedAt)
        return (feedingDates + careDates).min()
    }
}

@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var updateTask: Task<Void, Never>?

    private init() {}

    func startOrUpdate(
        snapshot: CareRecencySnapshot,
        activeTiming: ActiveTimingSnapshot,
        babyAgeMonths: Int?
    ) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        updateTask?.cancel()
        updateTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 120_000_000)
            guard !Task.isCancelled, self != nil else { return }
            await Self.apply(snapshot: snapshot, activeTiming: activeTiming, babyAgeMonths: babyAgeMonths)
        }
    }

    /// Retained for callers that explicitly close a recording flow. The
    /// normal timer-end path also reaches the same immediate dismissal via
    /// `startOrUpdate` when the shared timing snapshot is empty.
    func endCurrentActivity() {
        updateTask?.cancel()
        updateTask = Task {
            for activity in Activity<FeedingActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    private static func apply(
        snapshot: CareRecencySnapshot,
        activeTiming: ActiveTimingSnapshot,
        babyAgeMonths: Int?
    ) async {
        let activities = Activity<FeedingActivityAttributes>.activities
        guard LiveActivityPresentationPolicy.shouldPresent(activeTiming: activeTiming) else {
            for activity in activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            return
        }

        let state = FeedingActivityAttributes.ContentState(
            snapshot: snapshot,
            activeTiming: activeTiming,
            babyAgeMonths: babyAgeMonths
        )
        let content = ActivityContent(
            state: state,
            staleDate: LiveActivityPresentationPolicy.staleDate(for: activeTiming)
        )

        if let current = activities.first {
            await current.update(content)
            for duplicate in activities.dropFirst() {
                await duplicate.end(nil, dismissalPolicy: .immediate)
            }
        } else {
            let attributes = FeedingActivityAttributes(babyAgeMonths: babyAgeMonths)
            do {
                _ = try Activity.request(attributes: attributes, content: content)
            } catch {
                #if DEBUG
                print("Unable to start BBBuddy Live Activity: \(error)")
                #endif
            }
        }
    }
}

enum LiveActivityPresentationPolicy {
    static func shouldPresent(activeTiming: ActiveTimingSnapshot) -> Bool {
        activeTiming.hasActiveTiming
    }

    static func staleDate(for activeTiming: ActiveTimingSnapshot) -> Date? {
        activeTiming.items
            .map { item in
                let maximumDuration: TimeInterval = item.kind == .sleep
                    ? 18 * 60 * 60
                    : 4 * 60 * 60
                return item.startedAt.addingTimeInterval(maximumDuration)
            }
            .max()
    }
}
