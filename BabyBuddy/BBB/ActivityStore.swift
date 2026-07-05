import Foundation
import SwiftUI
#if canImport(WidgetKit)
import WidgetKit
#endif

enum CareRecordKind: String, Codable {
    case diaper
    case activity
    case sleep
}

struct CareRecord: Identifiable, Codable {
    let id: UUID
    var kind: CareRecordKind
    var title: String
    var detail: String
    var note: String
    var recordedAt: Date

    init(
        id: UUID = UUID(),
        kind: CareRecordKind,
        title: String,
        detail: String,
        note: String = "",
        recordedAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.detail = detail
        self.note = note
        self.recordedAt = recordedAt
    }
}

enum DiaperRecordType: String, CaseIterable, Identifiable {
    case pee = "尿了"
    case poop = "拉了"

    var id: String { rawValue }

    var accent: Color {
        switch self {
        case .pee:
            return Color(hex: "#66B8FF")
        case .poop:
            return Color(hex: "#C88A46")
        }
    }

    var softFill: Color {
        switch self {
        case .pee:
            return Color(hex: "#DDF0FF")
        case .poop:
            return Color(hex: "#F6E1C4")
        }
    }

    static func normalizedTitle(_ title: String) -> String {
        switch title {
        case Self.pee.rawValue, "湿尿布":
            return Self.pee.rawValue
        case Self.poop.rawValue, "便便", "混合":
            return Self.poop.rawValue
        default:
            return title
        }
    }

    static func type(for title: String) -> DiaperRecordType {
        normalizedTitle(title) == Self.pee.rawValue ? .pee : .poop
    }
}

enum SleepRecordFormatter {
    static func durationMinutes(start: Date, end: Date) -> Int {
        max(Int(end.timeIntervalSince(start) / 60), 1)
    }

    static func endTime(start: Date, durationMinutes: Int) -> Date {
        start.addingTimeInterval(TimeInterval(max(durationMinutes, 1) * 60))
    }

    static func durationMinutes(from detail: String) -> Int? {
        detail
            .split(separator: " ")
            .first
            .flatMap { Int($0) }
    }

    static func durationText(minutes: Int) -> String {
        let minutes = max(minutes, 0)
        if minutes < 60 {
            return "\(minutes)分钟"
        }
        let hours = minutes / 60
        let remaining = minutes % 60
        return remaining == 0 ? "\(hours)小时" : "\(hours)小时\(remaining)分"
    }

    static func sleepTitle(start: Date, end: Date) -> String {
        let duration = durationMinutes(start: start, end: end)
        if duration >= 240 || crossesNightWindow(start: start, end: end) {
            return "夜睡"
        }
        return "小睡"
    }

    private static func crossesNightWindow(start: Date, end: Date) -> Bool {
        let calendar = Calendar.current
        var cursor = start
        while cursor < end {
            let hour = calendar.component(.hour, from: cursor)
            if hour >= 20 || hour < 8 {
                return true
            }
            guard let nextHour = calendar.date(byAdding: .hour, value: 1, to: cursor) else {
                break
            }
            cursor = min(nextHour, end)
        }
        return false
    }
}

@MainActor
final class ActivityStore: ObservableObject {
    @Published private(set) var logs: [ActivityLog] = []
    @Published private(set) var careRecords: [CareRecord] = [] {
        didSet {
            persistCareRecords()
            FamilyCloudStore.shared.scheduleUpload(reason: "care")
        }
    }

    private let careRecordsKey = "care_records_v1"

    init() {
        loadCareRecords()
        persistCareRecords()
    }

    func record(_ action: BabyAction) {
        logs.insert(ActivityLog(action: action, timestamp: Date()), at: 0)
    }

    func recordDiaper(type: String, detail: String = "尿布护理", note: String, recordedAt: Date) {
        guard recordedAt <= Date() else { return }
        let trimmedNote = note
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
        let careRecord = CareRecord(
            kind: .diaper,
            title: type,
            detail: detail,
            note: trimmedNote,
            recordedAt: recordedAt
        )
        saveCareRecord(careRecord)
        EasyCycleStore.shared.trackCareRecord(careRecord)
        CompanionRecruitmentStore.shared.awardBBBucks(forRecord: .diaper, recordedAt: recordedAt)
        record(.diaper)
    }

    func recordActivity(title: String, durationMinutes: Int, recordedAt: Date, note: String = "") {
        guard recordedAt <= Date() else { return }
        let minutes = max(durationMinutes, 1)
        let trimmedNote = note
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
        let careRecord = CareRecord(
            kind: .activity,
            title: title,
            detail: "\(minutes) 分钟",
            note: trimmedNote,
            recordedAt: recordedAt
        )
        saveCareRecord(careRecord)
        EasyCycleStore.shared.trackCareRecord(careRecord)
    }

    func recordSleep(durationMinutes: Int, note: String, startTime: Date) {
        recordSleep(startTime: startTime, endTime: SleepRecordFormatter.endTime(start: startTime, durationMinutes: durationMinutes), note: note)
    }

    func recordSleep(startTime: Date, endTime: Date, note: String) {
        let cappedEndTime = min(endTime, Date())
        guard startTime <= Date(), cappedEndTime > startTime else { return }
        let trimmedNote = note
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
        let durationMinutes = SleepRecordFormatter.durationMinutes(start: startTime, end: cappedEndTime)
        let durationText = "\(durationMinutes) 分钟"
        let careRecord = CareRecord(
            kind: .sleep,
            title: SleepRecordFormatter.sleepTitle(start: startTime, end: cappedEndTime),
            detail: trimmedNote.isEmpty ? durationText : "\(durationText) · \(trimmedNote)",
            note: trimmedNote,
            recordedAt: startTime
        )
        saveCareRecord(careRecord)
        EasyCycleStore.shared.trackCareRecord(careRecord)
        CompanionRecruitmentStore.shared.awardBBBucks(forRecord: .sleep, recordedAt: startTime)
        record(.sleep)
    }

    func updateDiaperRecord(_ record: CareRecord, type: String, detail: String, note: String, recordedAt: Date) {
        guard recordedAt <= Date() else { return }
        let trimmedNote = note
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
        updateCareRecord(CareRecord(
            id: record.id,
            kind: .diaper,
            title: type,
            detail: detail,
            note: trimmedNote,
            recordedAt: recordedAt
        ))
    }

    func updateActivityRecord(_ record: CareRecord, recordedAt: Date) {
        guard recordedAt <= Date() else { return }
        updateCareRecord(CareRecord(
            id: record.id,
            kind: .activity,
            title: record.title,
            detail: record.detail,
            note: record.note,
            recordedAt: recordedAt
        ))
    }

    func updateSleepRecord(_ record: CareRecord, durationMinutes: Int, note: String, startTime: Date) {
        updateSleepRecord(record, startTime: startTime, endTime: SleepRecordFormatter.endTime(start: startTime, durationMinutes: durationMinutes), note: note)
    }

    func updateSleepRecord(_ record: CareRecord, startTime: Date, endTime: Date, note: String) {
        let cappedEndTime = min(endTime, Date())
        guard startTime <= Date(), cappedEndTime > startTime else { return }
        let trimmedNote = note
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
        let durationMinutes = SleepRecordFormatter.durationMinutes(start: startTime, end: cappedEndTime)
        let durationText = "\(durationMinutes) 分钟"
        updateCareRecord(CareRecord(
            id: record.id,
            kind: .sleep,
            title: SleepRecordFormatter.sleepTitle(start: startTime, end: cappedEndTime),
            detail: trimmedNote.isEmpty ? durationText : "\(durationText) · \(trimmedNote)",
            note: trimmedNote,
            recordedAt: startTime
        ))
    }

    func deleteCareRecord(_ record: CareRecord) {
        careRecords.removeAll { $0.id == record.id }
        EasyCycleStore.shared.removeRecordLink(type: .care, recordID: record.id)
        FamilyCloudStore.shared.markCareRecordDeleted(record.id)
    }

    var todayCareRecords: [CareRecord] {
        careRecords(on: Date())
    }

    func careRecords(on date: Date) -> [CareRecord] {
        careRecords
            .filter { Calendar.current.isDate($0.recordedAt, inSameDayAs: date) }
            .sorted { $0.recordedAt > $1.recordedAt }
    }

    func careRecordsForSleepSummary(on date: Date) -> [CareRecord] {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? date
        return careRecords
            .filter { record in
                if calendar.isDate(record.recordedAt, inSameDayAs: date) {
                    return true
                }
                guard record.kind == .sleep,
                      let duration = SleepRecordFormatter.durationMinutes(from: record.detail) else {
                    return false
                }
                let sleepEnd = SleepRecordFormatter.endTime(start: record.recordedAt, durationMinutes: duration)
                return record.recordedAt < dayEnd && sleepEnd > dayStart
            }
            .sorted { $0.recordedAt > $1.recordedAt }
    }

    func exportCareRecords() -> [CareRecord] {
        careRecords
    }

    func importCareRecords(_ records: [CareRecord]) {
        careRecords = records.sorted { $0.recordedAt > $1.recordedAt }
    }

    private func saveCareRecord(_ record: CareRecord) {
        careRecords.append(record)
        careRecords.sort { $0.recordedAt > $1.recordedAt }
    }

    private func updateCareRecord(_ record: CareRecord) {
        guard let index = careRecords.firstIndex(where: { $0.id == record.id }) else {
            saveCareRecord(record)
            EasyCycleStore.shared.trackCareRecord(record)
            return
        }
        careRecords[index] = record
        careRecords.sort { $0.recordedAt > $1.recordedAt }
        EasyCycleStore.shared.removeRecordLink(type: .care, recordID: record.id)
        EasyCycleStore.shared.trackCareRecord(record)
    }

    private func loadCareRecords() {
        let appGroupDefaults = UserDefaults(suiteName: WidgetStorageKey.appGroupID)
        guard let data = UserDefaults.standard.data(forKey: careRecordsKey)
                ?? appGroupDefaults?.data(forKey: WidgetStorageKey.careRecords),
              let decoded = try? JSONDecoder().decode([CareRecord].self, from: data) else {
            return
        }
        careRecords = decoded.sorted { $0.recordedAt > $1.recordedAt }
    }

    private func persistCareRecords() {
        guard let data = try? JSONEncoder().encode(careRecords) else { return }
        UserDefaults.standard.set(data, forKey: careRecordsKey)
        UserDefaults(suiteName: WidgetStorageKey.appGroupID)?.set(data, forKey: WidgetStorageKey.careRecords)
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetStorageKey.lastFeedingWidgetKind)
        #endif
    }
}
