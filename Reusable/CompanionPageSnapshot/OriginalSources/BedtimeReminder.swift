import Foundation
import UserNotifications

enum BedtimeReminderLookback: Int, CaseIterable, Identifiable {
    case sevenDays = 7
    case fourteenDays = 14

    var id: Int { rawValue }

    var title: String {
        AppLocalization.format("bedtime.reminder.lookback.days", rawValue)
    }
}

struct BedtimeReminderSettings {
    static let enabledKey = "local_bedtime_reminder_enabled_v1"
    static let lookbackDaysKey = "local_bedtime_reminder_lookback_days_v1"

    let isEnabled: Bool
    let lookback: BedtimeReminderLookback

    init(defaults: UserDefaults = .standard) {
        isEnabled = defaults.bool(forKey: Self.enabledKey)
        lookback = BedtimeReminderLookback(
            rawValue: defaults.integer(forKey: Self.lookbackDaysKey)
        ) ?? .sevenDays
    }

    init(isEnabled: Bool, lookback: BedtimeReminderLookback) {
        self.isEnabled = isEnabled
        self.lookback = lookback
    }
}

struct BedtimePrediction: Equatable {
    static let minimumNightCount = 3
    static let reminderLeadMinutes = 30

    let lookbackDays: Int
    let validNightCount: Int
    let expectedBedtime: Date
    let reminderDate: Date
}

enum BedtimePredictor {
    private static let morningEndHour = NightSleepAnalyzer.morningStartCutoffHour
    private static let roundingMinutes = 5

    static func prediction(
        records: [CareRecord],
        lookbackDays: Int,
        now: Date = Date(),
        calendar sourceCalendar: Calendar = .autoupdatingCurrent
    ) -> BedtimePrediction? {
        guard lookbackDays > 0 else { return nil }

        var calendar = sourceCalendar
        if sourceCalendar.timeZone == .current || sourceCalendar.timeZone == .autoupdatingCurrent {
            calendar.timeZone = .autoupdatingCurrent
        }

        let today = calendar.startOfDay(for: now)
        let firstNightAnchor = calendar.date(byAdding: .day, value: -lookbackDays, to: today)
            ?? today.addingTimeInterval(TimeInterval(-lookbackDays * 24 * 60 * 60))
        let bedtimeMinutes = NightSleepAnalyzer.episodes(
            records: records,
            from: firstNightAnchor,
            to: now,
            calendar: calendar
        )
        .filter { $0.anchor >= firstNightAnchor && $0.anchor < today }
        .map { NightSleepAnalyzer.bedtimeMinute(for: $0, calendar: calendar) }
        guard bedtimeMinutes.count >= BedtimePrediction.minimumNightCount else { return nil }

        guard let typicalMinute = NightSleepAnalyzer.median(bedtimeMinutes) else { return nil }
        let roundedMinute = Int((Double(typicalMinute) / Double(roundingMinutes)).rounded()) * roundingMinutes
        let expectedBedtime = nextExpectedBedtime(
            extendedMinute: roundedMinute,
            now: now,
            calendar: calendar
        )
        let reminderDate = calendar.date(
            byAdding: .minute,
            value: -BedtimePrediction.reminderLeadMinutes,
            to: expectedBedtime
        ) ?? expectedBedtime.addingTimeInterval(-TimeInterval(BedtimePrediction.reminderLeadMinutes * 60))

        return BedtimePrediction(
            lookbackDays: lookbackDays,
            validNightCount: bedtimeMinutes.count,
            expectedBedtime: expectedBedtime,
            reminderDate: reminderDate
        )
    }

    private static func nextExpectedBedtime(
        extendedMinute: Int,
        now: Date,
        calendar: Calendar
    ) -> Date {
        let today = calendar.startOfDay(for: now)
        let currentHour = calendar.component(.hour, from: now)
        var anchor = currentHour < morningEndHour
            ? (calendar.date(byAdding: .day, value: -1, to: today) ?? today)
            : today

        func expectedDate(on anchor: Date) -> Date {
            calendar.date(byAdding: .minute, value: extendedMinute, to: anchor)
                ?? anchor.addingTimeInterval(TimeInterval(extendedMinute * 60))
        }

        var expected = expectedDate(on: anchor)
        let reminderLead = TimeInterval(BedtimePrediction.reminderLeadMinutes * 60)
        if expected.addingTimeInterval(-reminderLead) <= now {
            anchor = calendar.date(byAdding: .day, value: 1, to: anchor)
                ?? anchor.addingTimeInterval(24 * 60 * 60)
            expected = expectedDate(on: anchor)
        }
        return expected
    }
}

enum BedtimeReminderCoordinator {
    static let requestIdentifier = "bb.local.bedtime"

    static func canScheduleNotifications(with status: UNAuthorizationStatus) -> Bool {
        switch status {
        case .authorized, .provisional:
            return true
        #if os(iOS)
        case .ephemeral:
            return true
        #endif
        default:
            return false
        }
    }

    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    static func reconcile(
        records: [CareRecord],
        settings: BedtimeReminderSettings = BedtimeReminderSettings(),
        now: Date = Date(),
        calendar: Calendar = .autoupdatingCurrent
    ) async {
        guard !Task.isCancelled else { return }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [requestIdentifier])

        guard settings.isEnabled else {
            center.removeDeliveredNotifications(withIdentifiers: [requestIdentifier])
            return
        }

        let authorization = await center.notificationSettings().authorizationStatus
        guard !Task.isCancelled else { return }
        guard canScheduleNotifications(with: authorization) else {
            return
        }

        guard let prediction = BedtimePredictor.prediction(
            records: records,
            lookbackDays: settings.lookback.rawValue,
            now: now,
            calendar: calendar
        ), prediction.reminderDate > now else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = AppLocalization.string("bedtime.reminder.notification.title")
        content.body = AppLocalization.format(
            "bedtime.reminder.notification.body",
            prediction.lookbackDays,
            AppDateTimeFormat.time(prediction.expectedBedtime)
        )
        content.sound = .default

        var triggerComponents = calendar.dateComponents(
            [.hour, .minute],
            from: prediction.reminderDate
        )
        triggerComponents.second = 0
        let request = UNNotificationRequest(
            identifier: requestIdentifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: true)
        )
        guard !Task.isCancelled else { return }
        try? await center.add(request)
    }
}
