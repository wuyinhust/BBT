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

    func sanitized(referenceDate: Date = Date()) -> CareRecord? {
        let latestAcceptedDate = referenceDate.addingTimeInterval(5 * 60)
        guard recordedAt <= latestAcceptedDate else { return nil }

        var value = self
        value.recordedAt = min(recordedAt, referenceDate)
        value.title = String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(100))
        value.detail = String(detail.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1_000))
        value.note = String(note.trimmingCharacters(in: .whitespacesAndNewlines).prefix(2_000))
        return value
    }
}

enum DiaperRecordType: String, CaseIterable, Identifiable {
    case pee = "尿了"
    case poop = "拉了"

    var id: String { rawValue }

    var accent: Color {
        switch self {
        case .pee:
            return DesignToken.accentBlue
        case .poop:
            return DesignToken.activityDiaper
        }
    }

    var softFill: Color {
        switch self {
        case .pee:
            return DesignToken.easySleepSoft
        case .poop:
            return DesignToken.activityDiaperSoft
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

    static func defaultDetail(for title: String) -> String {
        type(for: title) == .poop ? "糊状便" : "尿了不少💧💧"
    }

    static func displayDetail(title: String, detail: String) -> String {
        let cleaned = detail
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
        switch type(for: title) {
        case .pee:
            if cleaned.contains("一点") || cleaned.contains("尿量：少") || cleaned == "尿量少" {
                return "尿了一点💧"
            }
            if cleaned.contains("很多") || cleaned.contains("尿量：多") || cleaned == "尿量多" {
                return "尿了很多💧💧💧"
            }
            if cleaned.contains("不少") || cleaned.contains("尿量：中") || cleaned == "尿量中" {
                return "尿了不少💧💧"
            }
            return cleaned.isEmpty || cleaned == "尿布护理" ? "尿了不少💧💧" : cleaned
        case .poop:
            break
        }
        if cleaned.contains("糊状便") || cleaned.contains("便便：糊") {
            return "糊状便"
        }
        if cleaned.contains("成型便") || cleaned.contains("便便：条") {
            return "成型便"
        }
        if cleaned.contains("稀水便") || cleaned.contains("便便：稀") {
            return "稀水便"
        }
        if cleaned.contains("黏液便") || cleaned.contains("便便：黏") {
            return "黏液便"
        }
        if cleaned.contains("硬结便") || cleaned.contains("便便：硬") {
            return "硬结便"
        }
        return cleaned.isEmpty || cleaned == "尿布护理" ? "糊状便" : cleaned
    }
}

enum SleepRecordFormatter {
    static let maximumDurationMinutes = 18 * 60

    static func durationMinutes(start: Date, end: Date) -> Int {
        let seconds = end.timeIntervalSince(start)
        guard seconds.isFinite, seconds > 0 else { return 1 }
        return min(max(Int(seconds / 60), 1), maximumDurationMinutes)
    }

    static func endTime(start: Date, durationMinutes: Int) -> Date {
        let safeMinutes = min(max(durationMinutes, 1), maximumDurationMinutes)
        return start.addingTimeInterval(TimeInterval(safeMinutes) * 60)
    }

    static func normalizedWindow(
        startTime: Date,
        endTime: Date,
        anchorDate: Date,
        now: Date = Date()
    ) -> (start: Date, end: Date)? {
        let calendar = Calendar.current
        let anchorDay = calendar.startOfDay(for: anchorDate)
        let start = date(onSameDayAs: anchorDay, usingTimeFrom: startTime)
        let end = date(onSameDayAs: anchorDay, usingTimeFrom: endTime)

        if end > start {
            let cappedEnd = min(end, now)
            guard start < cappedEnd else { return nil }
            return (start, cappedEnd)
        }

        let forwardEnd = calendar.date(byAdding: .day, value: 1, to: end) ?? end.addingTimeInterval(24 * 60 * 60)
        if forwardEnd <= now {
            return (start, forwardEnd)
        }

        let backwardStart = calendar.date(byAdding: .day, value: -1, to: start) ?? start.addingTimeInterval(-24 * 60 * 60)
        guard backwardStart < end, end <= now else { return nil }
        return (backwardStart, end)
    }

    static func normalizedStart(
        startTime: Date,
        endTime: Date,
        anchorDate: Date,
        now: Date = Date()
    ) -> Date? {
        normalizedWindow(startTime: startTime, endTime: endTime, anchorDate: anchorDate, now: now)?.start
    }

    private static func date(onSameDayAs anchor: Date, usingTimeFrom timeSource: Date) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: anchor)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: timeSource)
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        components.second = 0
        return calendar.date(from: components) ?? anchor
    }

    static func durationMinutes(from detail: String) -> Int? {
        guard let parsed = rawDurationMinutes(from: detail), parsed > 0 else {
            return nil
        }
        return min(parsed, maximumDurationMinutes)
    }

    static func rawDurationMinutes(from detail: String) -> Int? {
        detail
            .split(separator: " ")
            .first
            .flatMap { Int($0) }
    }

    static func durationText(minutes: Int) -> String {
        AppQuantityFormat.hoursAndMinutes(minutes)
    }

    static func sleepTitle(start: Date, end: Date) -> String {
        let duration = durationMinutes(start: start, end: end)
        if duration >= 240 || crossesNightWindow(start: start, end: end) {
            return "夜睡".localized
        }
        return "小睡".localized
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

    @discardableResult
    func recordDiaper(type: String, detail: String = "", note: String, recordedAt: Date) -> CareRecord? {
        guard recordedAt <= Date() else { return nil }
        let resolvedDetail = detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? DiaperRecordType.defaultDetail(for: type)
            : detail
        let trimmedNote = note
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
        let careRecord = CareRecord(
            kind: .diaper,
            title: type,
            detail: resolvedDetail,
            note: trimmedNote,
            recordedAt: recordedAt
        )
        saveCareRecord(careRecord)
        EasyCycleStore.shared.trackCareRecord(careRecord)
        record(.diaper)
        return careRecord
    }

    @discardableResult
    func recordActivity(title: String, durationMinutes: Int, recordedAt: Date, note: String = "") -> CareRecord? {
        recordActivity(title: title, recordedAt: recordedAt, note: note)
    }

    @discardableResult
    func recordActivity(title: String, recordedAt: Date, note: String = "") -> CareRecord? {
        guard recordedAt <= Date() else { return nil }
        let trimmedNote = note
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
        let careRecord = CareRecord(
            kind: .activity,
            title: title,
            detail: "",
            note: trimmedNote,
            recordedAt: recordedAt
        )
        saveCareRecord(careRecord)
        EasyCycleStore.shared.trackCareRecord(careRecord)
        return careRecord
    }

    @discardableResult
    func recordSleep(durationMinutes: Int, note: String, startTime: Date) -> CareRecord? {
        recordSleep(startTime: startTime, endTime: SleepRecordFormatter.endTime(start: startTime, durationMinutes: durationMinutes), note: note)
    }

    @discardableResult
    func recordSleep(startTime: Date, endTime: Date, note: String) -> CareRecord? {
        let cappedEndTime = min(endTime, Date())
        guard startTime <= Date(), cappedEndTime > startTime,
              cappedEndTime.timeIntervalSince(startTime) <= TimeInterval(SleepRecordFormatter.maximumDurationMinutes * 60) else {
            return nil
        }
        let trimmedNote = note
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
        let durationMinutes = SleepRecordFormatter.durationMinutes(start: startTime, end: cappedEndTime)
        if let existing = careRecords.first(where: { record in
            guard record.kind == .sleep,
                  abs(record.recordedAt.timeIntervalSince(startTime)) < 1,
                  let existingMinutes = SleepRecordFormatter.durationMinutes(from: record.detail) else {
                return false
            }
            return existingMinutes == durationMinutes
        }) {
            return existing
        }
        guard !hasOverlappingSleep(start: startTime, end: cappedEndTime) else { return nil }
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
        record(.sleep)
        return careRecord
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
        updateActivityRecord(
            record,
            title: record.title,
            durationMinutes: SleepRecordFormatter.durationMinutes(from: record.detail) ?? 1,
            recordedAt: recordedAt,
            note: record.note
        )
    }

    func updateActivityRecord(
        _ record: CareRecord,
        title: String,
        durationMinutes: Int,
        recordedAt: Date,
        note: String
    ) {
        updateActivityRecord(record, title: title, recordedAt: recordedAt, note: note)
    }

    func updateActivityRecord(
        _ record: CareRecord,
        title: String,
        recordedAt: Date,
        note: String
    ) {
        guard recordedAt <= Date() else { return }
        let trimmedNote = note
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
        updateCareRecord(CareRecord(
            id: record.id,
            kind: .activity,
            title: title,
            detail: "",
            note: trimmedNote,
            recordedAt: recordedAt
        ))
    }

    func updateSleepRecord(_ record: CareRecord, durationMinutes: Int, note: String, startTime: Date) {
        updateSleepRecord(record, startTime: startTime, endTime: SleepRecordFormatter.endTime(start: startTime, durationMinutes: durationMinutes), note: note)
    }

    func updateSleepRecord(_ record: CareRecord, startTime: Date, endTime: Date, note: String) {
        let cappedEndTime = min(endTime, Date())
        guard startTime <= Date(), cappedEndTime > startTime,
              cappedEndTime.timeIntervalSince(startTime) <= TimeInterval(SleepRecordFormatter.maximumDurationMinutes * 60) else {
            return
        }
        let trimmedNote = note
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
        let durationMinutes = SleepRecordFormatter.durationMinutes(start: startTime, end: cappedEndTime)
        guard !hasOverlappingSleep(start: startTime, end: cappedEndTime, excluding: record.id) else { return }
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

    private func hasOverlappingSleep(start: Date, end: Date, excluding excludedID: UUID? = nil) -> Bool {
        careRecords.contains { record in
            guard record.id != excludedID,
                  record.kind == .sleep,
                  let minutes = SleepRecordFormatter.durationMinutes(from: record.detail) else {
                return false
            }
            let existingEnd = SleepRecordFormatter.endTime(start: record.recordedAt, durationMinutes: minutes)
            return start < existingEnd && end > record.recordedAt
        }
    }

    func deleteCareRecord(_ record: CareRecord) {
        careRecords.removeAll { $0.id == record.id }
        EasyCycleStore.shared.removeRecordLink(type: .care, recordID: record.id)
        SubjectiveStateStore.shared.deleteLinked(sourceType: .care, sourceRecordID: record.id)
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
        careRecords = sanitizedCareRecords(records)
    }

    private func saveCareRecord(_ record: CareRecord) {
        guard let record = record.sanitized() else { return }
        careRecords = (careRecords + [record]).sorted { $0.recordedAt > $1.recordedAt }
    }

    private func updateCareRecord(_ record: CareRecord) {
        guard let record = record.sanitized() else { return }
        guard let index = careRecords.firstIndex(where: { $0.id == record.id }) else {
            saveCareRecord(record)
            EasyCycleStore.shared.trackCareRecord(record)
            return
        }
        var updatedRecords = careRecords
        updatedRecords[index] = record
        careRecords = updatedRecords.sorted { $0.recordedAt > $1.recordedAt }
        EasyCycleStore.shared.removeRecordLink(type: .care, recordID: record.id)
        EasyCycleStore.shared.trackCareRecord(record)
        SubjectiveStateStore.shared.updateLinkedRecord(
            sourceType: .care,
            sourceRecordID: record.id,
            recordedAt: record.recordedAt
        )
    }

    private func loadCareRecords() {
        let appGroupDefaults = UserDefaults(suiteName: WidgetStorageKey.appGroupID)
        guard let data = appGroupDefaults?.data(forKey: WidgetStorageKey.careRecords)
                ?? UserDefaults.standard.data(forKey: careRecordsKey),
              let decoded = try? JSONDecoder().decode([CareRecord].self, from: data) else {
            return
        }
        careRecords = sanitizedCareRecords(decoded)
    }

    private func sanitizedCareRecords(_ records: [CareRecord], referenceDate: Date = Date()) -> [CareRecord] {
        let candidates = records
            .compactMap { $0.sanitized(referenceDate: referenceDate) }
            .filter { record in
                guard record.kind == .sleep else { return true }
                guard let rawMinutes = SleepRecordFormatter.rawDurationMinutes(from: record.detail) else {
                    return false
                }
                return (1...SleepRecordFormatter.maximumDurationMinutes).contains(rawMinutes)
            }
            .sorted { lhs, rhs in
                if lhs.recordedAt != rhs.recordedAt { return lhs.recordedAt < rhs.recordedAt }
                return lhs.id.uuidString < rhs.id.uuidString
            }

        var accepted: [CareRecord] = []
        var sleepWindows: [(start: Date, end: Date)] = []
        for record in candidates {
            guard record.kind == .sleep,
                  let minutes = SleepRecordFormatter.rawDurationMinutes(from: record.detail) else {
                accepted.append(record)
                continue
            }

            let end = record.recordedAt.addingTimeInterval(TimeInterval(minutes) * 60)
            guard end <= referenceDate.addingTimeInterval(5 * 60) else { continue }
            guard !sleepWindows.contains(where: { record.recordedAt < $0.end && end > $0.start }) else {
                continue
            }
            sleepWindows.append((record.recordedAt, end))
            accepted.append(record)
        }
        return accepted.sorted { $0.recordedAt > $1.recordedAt }
    }

    private func persistCareRecords() {
        guard let data = try? JSONEncoder().encode(careRecords) else { return }
        UserDefaults.standard.set(data, forKey: careRecordsKey)
        UserDefaults(suiteName: WidgetStorageKey.appGroupID)?.set(data, forKey: WidgetStorageKey.careRecords)
        CareRecencyCoordinator.refreshFromSharedStorage(
            babyAgeMonths: BabyProfileStore.shared.currentProfile.ageMonths
        )
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetStorageKey.lastFeedingWidgetKind)
        #endif
    }
}
