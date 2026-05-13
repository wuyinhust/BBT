import Foundation
import SwiftUI

enum CareRecordKind: String, Codable {
    case diaper
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

@MainActor
final class ActivityStore: ObservableObject {
    @Published private(set) var logs: [ActivityLog] = []
    @Published private(set) var careRecords: [CareRecord] = [] {
        didSet { persistCareRecords() }
    }

    private let careRecordsKey = "care_records_v1"

    init() {
        loadCareRecords()
    }

    func record(_ action: BabyAction) {
        logs.insert(ActivityLog(action: action, timestamp: Date()), at: 0)
    }

    func recordDiaper(type: String, note: String, recordedAt: Date) {
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let careRecord = CareRecord(
            kind: .diaper,
            title: type,
            detail: trimmedNote.isEmpty ? "尿布护理" : trimmedNote,
            note: trimmedNote,
            recordedAt: recordedAt
        )
        saveCareRecord(careRecord)
        record(.diaper)
    }

    func recordSleep(durationMinutes: Int, note: String, startTime: Date) {
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let durationText = "\(durationMinutes) 分钟"
        let careRecord = CareRecord(
            kind: .sleep,
            title: "睡眠",
            detail: trimmedNote.isEmpty ? durationText : "\(durationText) · \(trimmedNote)",
            note: trimmedNote,
            recordedAt: startTime
        )
        saveCareRecord(careRecord)
        record(.sleep)
    }

    var todayCareRecords: [CareRecord] {
        careRecords(on: Date())
    }

    func careRecords(on date: Date) -> [CareRecord] {
        careRecords
            .filter { Calendar.current.isDate($0.recordedAt, inSameDayAs: date) }
            .sorted { $0.recordedAt > $1.recordedAt }
    }

    private func saveCareRecord(_ record: CareRecord) {
        careRecords.append(record)
        careRecords.sort { $0.recordedAt > $1.recordedAt }
    }

    private func loadCareRecords() {
        guard let data = UserDefaults.standard.data(forKey: careRecordsKey),
              let decoded = try? JSONDecoder().decode([CareRecord].self, from: data) else {
            return
        }
        careRecords = decoded.sorted { $0.recordedAt > $1.recordedAt }
    }

    private func persistCareRecords() {
        guard let data = try? JSONEncoder().encode(careRecords) else { return }
        UserDefaults.standard.set(data, forKey: careRecordsKey)
    }
}
