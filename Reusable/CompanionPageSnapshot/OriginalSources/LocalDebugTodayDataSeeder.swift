import Foundation

#if LOCAL_DEBUG_UNLOCKS
@MainActor
enum LocalDebugTodayDataSeeder {
    static func seedTodayIfNeeded(
        feedingStore: FeedingStore,
        activityStore: ActivityStore,
        easyCycleStore: EasyCycleStore
    ) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let token = dateToken(for: today, calendar: calendar)
        let defaults = UserDefaults.standard
        let seededKey = "local_debug_seeded_today_data_dates_v2"
        var seededDates = Set(defaults.stringArray(forKey: seededKey) ?? [])

        if !seededDates.contains(token) {
            let seededSessions = localDebugFeedingSessions(on: today, calendar: calendar)
            let seededCareRecords = localDebugCareRecords(on: today, calendar: calendar)
            let seededCycles = localDebugEasyCycles(
                sessions: seededSessions,
                careRecords: seededCareRecords,
                on: today,
                calendar: calendar
            )

            feedingStore.importSessions((feedingStore.exportSessions() + seededSessions).sorted { $0.createdAt > $1.createdAt })
            activityStore.importCareRecords((activityStore.exportCareRecords() + seededCareRecords).sorted { $0.recordedAt > $1.recordedAt })
            easyCycleStore.importCycles(seededCycles)

            seededDates.insert(token)
            defaults.set(Array(seededDates).sorted(), forKey: seededKey)
        }

        ensureOvernightSleepBridge(on: today, calendar: calendar, activityStore: activityStore)
    }

    private static func localDebugFeedingSessions(on dayStart: Date, calendar: Calendar) -> [FeedingSession] {
        [
            mixedFeed(at: (7, 0), nursingMinutes: 20, formulaML: 75, formulaMinutes: 10, on: dayStart, calendar: calendar),
            mixedFeed(at: (9, 50), nursingMinutes: 18, formulaML: 80, formulaMinutes: 10, on: dayStart, calendar: calendar),
            mixedFeed(at: (12, 40), nursingMinutes: 18, formulaML: 80, formulaMinutes: 10, on: dayStart, calendar: calendar),
            mixedFeed(at: (15, 30), nursingMinutes: 18, formulaML: 80, formulaMinutes: 10, on: dayStart, calendar: calendar),
            nursing(at: (17, 35), durationMinutes: 18, on: dayStart, calendar: calendar),
            bottle(at: (19, 0), amountML: 145, durationMinutes: 18, on: dayStart, calendar: calendar),
            bottle(at: (23, 0), amountML: 105, durationMinutes: 14, on: dayStart, calendar: calendar),
            nursing(at: (4, 0), durationMinutes: 15, on: dayStart, calendar: calendar)
        ]
    }

    private static func localDebugCareRecords(on dayStart: Date, calendar: Calendar) -> [CareRecord] {
        let diapers: [CareRecord] = [
            diaper(at: (4, 0), title: DiaperRecordType.pee.rawValue, on: dayStart, calendar: calendar),
            diaper(at: (7, 0), title: DiaperRecordType.pee.rawValue, on: dayStart, calendar: calendar),
            diaper(at: (10, 20), title: DiaperRecordType.poop.rawValue, on: dayStart, calendar: calendar),
            diaper(at: (13, 10), title: DiaperRecordType.pee.rawValue, on: dayStart, calendar: calendar),
            diaper(at: (16, 0), title: DiaperRecordType.pee.rawValue, on: dayStart, calendar: calendar),
            diaper(at: (18, 10), title: DiaperRecordType.pee.rawValue, on: dayStart, calendar: calendar),
            diaper(at: (19, 0), title: DiaperRecordType.pee.rawValue, on: dayStart, calendar: calendar),
            diaper(at: (23, 0), title: DiaperRecordType.pee.rawValue, on: dayStart, calendar: calendar)
        ]

        let sleeps: [CareRecord] = [
            sleep(from: (23, 0), to: (4, 0), startDayOffset: -1, on: dayStart, calendar: calendar),
            sleep(from: (4, 30), to: (7, 0), on: dayStart, calendar: calendar),
            sleep(from: (8, 20), to: (9, 50), on: dayStart, calendar: calendar),
            sleep(from: (11, 10), to: (12, 40), on: dayStart, calendar: calendar),
            sleep(from: (14, 0), to: (15, 30), on: dayStart, calendar: calendar),
            sleep(from: (16, 50), to: (17, 35), on: dayStart, calendar: calendar),
            sleep(from: (19, 30), to: (23, 0), on: dayStart, calendar: calendar),
            sleep(from: (23, 20), to: (4, 0), endDayOffset: 1, on: dayStart, calendar: calendar),
            sleep(from: (4, 20), to: (7, 0), startDayOffset: 1, endDayOffset: 1, on: dayStart, calendar: calendar)
        ]

        return diapers + sleeps
    }

    private static func localDebugEasyCycles(
        sessions: [FeedingSession],
        careRecords: [CareRecord],
        on dayStart: Date,
        calendar: Calendar
    ) -> [EasyCycle] {
        let cycleRanges: [
            (start: (hour: Int, minute: Int), end: (hour: Int, minute: Int), endDayOffset: Int, status: EasyCycleStatus, published: (hour: Int, minute: Int)?)
        ] = [
            ((7, 0), (9, 50), 0, .published, (9, 54)),
            ((9, 50), (12, 40), 0, .published, (12, 45)),
            ((12, 40), (15, 30), 0, .published, (15, 35)),
            ((15, 30), (17, 35), 0, .published, (17, 40)),
            ((17, 35), (23, 0), 0, .readyToPublish, nil),
            ((23, 0), (7, 0), 1, .active, nil)
        ]

        return cycleRanges.map { range in
            let start = date(range.start, on: dayStart, calendar: calendar)
            let endBase = calendar.date(byAdding: .day, value: range.endDayOffset, to: dayStart) ?? dayStart
            let end = date(range.end, on: endBase, calendar: calendar)
            let publishedAt = range.published.map { date($0, on: dayStart, calendar: calendar) }
            let links = easyCycleLinks(
                start: start,
                end: end,
                sessions: sessions,
                careRecords: careRecords
            )

            return EasyCycle(
                startedAt: start,
                endedAt: range.status == .active ? nil : end,
                currentPhase: range.status == .active ? .sleep : .yearning,
                status: range.status,
                activityStartedAt: calendar.date(byAdding: .minute, value: 30, to: start),
                activityEndedAt: calendar.date(byAdding: .minute, value: 80, to: start),
                note: "",
                linkedRecords: links,
                publishedAt: publishedAt,
                updatedAt: publishedAt ?? end
            )
        }
    }

    private static func easyCycleLinks(
        start: Date,
        end: Date,
        sessions: [FeedingSession],
        careRecords: [CareRecord]
    ) -> [EasyCycleRecordLink] {
        let feedingLinks = sessions
            .filter { $0.createdAt >= start && $0.createdAt <= end }
            .map { EasyCycleRecordLink(type: .feeding, recordID: $0.id, phase: .eat) }

        let careLinks = careRecords
            .filter { record in
                record.recordedAt >= start && record.recordedAt <= end
            }
            .map { record in
                EasyCycleRecordLink(
                    type: .care,
                    recordID: record.id,
                    phase: record.kind == .sleep ? .sleep : .activity
                )
            }

        return feedingLinks + careLinks
    }

    private static func ensureOvernightSleepBridge(
        on dayStart: Date,
        calendar: Calendar,
        activityStore: ActivityStore
    ) {
        let bridgeEnd = date((4, 0), on: dayStart, calendar: calendar)
        let hasBridge = activityStore.exportCareRecords().contains { record in
            guard record.kind == .sleep,
                  let minutes = SleepRecordFormatter.durationMinutes(from: record.detail) else {
                return false
            }
            let sleepEnd = SleepRecordFormatter.endTime(start: record.recordedAt, durationMinutes: minutes)
            return record.recordedAt < bridgeEnd && sleepEnd > dayStart
        }

        guard !hasBridge else { return }

        let bridge = sleep(from: (23, 0), to: (4, 0), startDayOffset: -1, on: dayStart, calendar: calendar)
        activityStore.importCareRecords((activityStore.exportCareRecords() + [bridge]).sorted { $0.recordedAt > $1.recordedAt })
    }

    private static func bottle(
        at time: (hour: Int, minute: Int),
        amountML: Int,
        durationMinutes: Int,
        on dayStart: Date,
        calendar: Calendar
    ) -> FeedingSession {
        let start = date(time, on: dayStart, calendar: calendar)
        let end = calendar.date(byAdding: .minute, value: durationMinutes, to: start) ?? start
        return FeedingSession(
            entries: [
                FeedingEntry(
                    type: .bottle,
                    milkType: .formula,
                    bottleAmount: amountML,
                    bottleDuration: durationMinutes
                )
            ],
            createdAt: end,
            startAt: start,
            endAt: end,
            timeSpanSource: .confirmed
        )
    }

    private static func mixedFeed(
        at time: (hour: Int, minute: Int),
        nursingMinutes: Int,
        formulaML: Int,
        formulaMinutes: Int,
        on dayStart: Date,
        calendar: Calendar
    ) -> FeedingSession {
        let start = date(time, on: dayStart, calendar: calendar)
        let totalMinutes = nursingMinutes + formulaMinutes
        let end = calendar.date(byAdding: .minute, value: totalMinutes, to: start) ?? start
        return FeedingSession(
            entries: [
                FeedingEntry(
                    type: .breast,
                    breastMode: .nursing,
                    breastSide: .left,
                    breastDuration: nursingMinutes / 2
                ),
                FeedingEntry(
                    type: .breast,
                    breastMode: .nursing,
                    breastSide: .right,
                    breastDuration: nursingMinutes - nursingMinutes / 2
                ),
                FeedingEntry(
                    type: .bottle,
                    milkType: .formula,
                    bottleAmount: formulaML,
                    bottleDuration: formulaMinutes
                )
            ],
            createdAt: end,
            startAt: start,
            endAt: end,
            timeSpanSource: .confirmed
        )
    }

    private static func nursing(
        at time: (hour: Int, minute: Int),
        durationMinutes: Int,
        on dayStart: Date,
        calendar: Calendar
    ) -> FeedingSession {
        let start = date(time, on: dayStart, calendar: calendar)
        let end = calendar.date(byAdding: .minute, value: durationMinutes, to: start) ?? start
        return FeedingSession(
            entries: [
                FeedingEntry(
                    type: .breast,
                    breastMode: .nursing,
                    breastSide: .left,
                    breastDuration: durationMinutes / 2
                ),
                FeedingEntry(
                    type: .breast,
                    breastMode: .nursing,
                    breastSide: .right,
                    breastDuration: durationMinutes - durationMinutes / 2
                )
            ],
            createdAt: end,
            startAt: start,
            endAt: end,
            timeSpanSource: .confirmed
        )
    }

    private static func diaper(
        at time: (hour: Int, minute: Int),
        title: String,
        on dayStart: Date,
        calendar: Calendar
    ) -> CareRecord {
        CareRecord(
            kind: .diaper,
            title: title,
            detail: "尿布护理",
            recordedAt: date(time, on: dayStart, calendar: calendar)
        )
    }

    private static func sleep(
        from startTime: (hour: Int, minute: Int),
        to endTime: (hour: Int, minute: Int),
        startDayOffset: Int = 0,
        endDayOffset: Int = 0,
        on dayStart: Date,
        calendar: Calendar
    ) -> CareRecord {
        let startBase = calendar.date(byAdding: .day, value: startDayOffset, to: dayStart) ?? dayStart
        let start = date(startTime, on: startBase, calendar: calendar)
        let endBase = calendar.date(byAdding: .day, value: endDayOffset, to: dayStart) ?? dayStart
        let end = date(endTime, on: endBase, calendar: calendar)
        let duration = SleepRecordFormatter.durationMinutes(start: start, end: end)
        return CareRecord(
            kind: .sleep,
            title: SleepRecordFormatter.sleepTitle(start: start, end: end),
            detail: "\(duration) 分钟",
            recordedAt: start
        )
    }

    private static func date(
        _ time: (hour: Int, minute: Int),
        on dayStart: Date,
        calendar: Calendar
    ) -> Date {
        calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: dayStart) ?? dayStart
    }

    private static func dateToken(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}
#endif
