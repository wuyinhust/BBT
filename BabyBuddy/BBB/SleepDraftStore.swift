import Foundation

@MainActor
final class SleepDraftStore: ObservableObject {
    @Published var activeSleepStartAt: Date?
    @Published var note = ""
    @Published var currentTime = Date()

    private let draftKey = "sleep_sheet_draft_v1"

    var isRecording: Bool {
        activeSleepStartAt != nil
    }

    var elapsedSeconds: Int {
        guard let activeSleepStartAt else { return 0 }
        return max(Int(currentTime.timeIntervalSince(activeSleepStartAt)), 0)
    }

    var statusDetail: String {
        SleepRecordFormatter.durationText(minutes: max(elapsedSeconds / 60, 0))
    }

    init() {
        restoreDraft()
    }

    func start(at date: Date = Date()) {
        activeSleepStartAt = date
        currentTime = date
        persistDraft()
    }

    func updateCurrentTime(_ date: Date) {
        currentTime = date
        if isRecording {
            persistDraft()
        }
    }

    func updateStartTime(_ date: Date) {
        activeSleepStartAt = date
        persistDraft()
    }

    func updateNote(_ value: String) {
        note = value
        persistDraft()
    }

    func resetDraft() {
        activeSleepStartAt = nil
        note = ""
        currentTime = Date()
        clearPersistedDraft()
    }

    private func persistDraft() {
        guard activeSleepStartAt != nil || !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            clearPersistedDraft()
            return
        }
        let draft = SleepDraft(activeSleepStartAt: activeSleepStartAt, note: note, updatedAt: Date())
        guard let data = try? JSONEncoder().encode(draft) else { return }
        UserDefaults.standard.set(data, forKey: draftKey)
        UserDefaults(suiteName: WidgetStorageKey.appGroupID)?.set(data, forKey: draftKey)
    }

    private func restoreDraft() {
        let data = UserDefaults.standard.data(forKey: draftKey)
            ?? UserDefaults(suiteName: WidgetStorageKey.appGroupID)?.data(forKey: draftKey)
        guard let data, let draft = try? JSONDecoder().decode(SleepDraft.self, from: data) else { return }
        activeSleepStartAt = draft.activeSleepStartAt
        note = draft.note
        currentTime = Date()
    }

    private func clearPersistedDraft() {
        UserDefaults.standard.removeObject(forKey: draftKey)
        UserDefaults(suiteName: WidgetStorageKey.appGroupID)?.removeObject(forKey: draftKey)
    }
}

private struct SleepDraft: Codable {
    var activeSleepStartAt: Date?
    var note: String
    var updatedAt: Date
}
