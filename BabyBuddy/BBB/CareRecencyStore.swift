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
        persist(snapshot)
        LiveActivityManager.shared.startOrUpdate(
            snapshot: snapshot,
            activeTiming: ActiveTimingStorage.load(),
            babyAgeMonths: babyAgeMonths
        )
    }

    static func refreshFromSharedStorage(babyAgeMonths: Int?) {
        let defaults = UserDefaults(suiteName: WidgetStorageKey.appGroupID)
        let sessions = defaults?.data(forKey: WidgetStorageKey.feedingSessions)
            .flatMap { try? JSONDecoder().decode([FeedingSession].self, from: $0) } ?? []
        let records = defaults?.data(forKey: WidgetStorageKey.careRecords)
            .flatMap { try? JSONDecoder().decode([CareRecord].self, from: $0) } ?? []
        refresh(feedingSessions: sessions, careRecords: records, babyAgeMonths: babyAgeMonths)
    }

    private static func persist(_ snapshot: CareRecencySnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults(suiteName: WidgetStorageKey.appGroupID)?.set(data, forKey: WidgetStorageKey.careRecencySnapshot)
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetStorageKey.lastFeedingWidgetKind)
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
        guard snapshot.hasAnyRecord || activeTiming.hasActiveTiming else {
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
        let content = ActivityContent(state: state, staleDate: nil)

        if let current = activities.first {
            await current.update(content)
            for duplicate in activities.dropFirst() {
                await duplicate.end(nil, dismissalPolicy: .immediate)
            }
        } else {
            let attributes = FeedingActivityAttributes(babyAgeMonths: babyAgeMonths)
            _ = try? Activity.request(attributes: attributes, content: content)
        }
    }
}
