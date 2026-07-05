import AVFoundation
import SwiftUI
import Foundation
import Observation
import UIKit
#if canImport(ActivityKit)
import ActivityKit
#endif
#if canImport(WidgetKit)
import WidgetKit
#endif

// MARK: - Design

enum DesignToken {
    static let canvas = Color(hex: "#FAFAFC")
    static let surface = Color.white
    static let surfaceSoft = Color(hex: "#F6F2FF")
    static let borderSubtle = Color(hex: "#E5E3EC")
    static let textStrong = Color(hex: "#282738")
    static let textMuted = Color(hex: "#737286")

    static let primary = Color(hex: "#BDA6F2")
    static let primarySoft = Color(hex: "#F4C7D9")
    static let accentBlue = Color(hex: "#A5C8FF")
    static let grayNeutral = Color(hex: "#EAEAF2")
    static let background = canvas
    static let textTitle = textStrong
    static let textBody = textMuted
    static let cardBackground = surface
    static let errorRed = Color(hex: "#FF6B6B")

    static let bg = background
    static let card = cardBackground
    static let textPrimary = textTitle
    static let textSecondary = textBody
    static let line = borderSubtle
    static let iconSoftBG = Color(hex: "#F0EEF8")

    // E/A/S/Y flower colors: Iris, Camellia, Delphinium, Viburnum.
    static let easyEat = Color(hex: "#7C5CFF")
    static let easyEatSoft = Color(hex: "#EDE7FF")
    static let easyActivity = Color(hex: "#FF7A90")
    static let easyActivitySoft = Color(hex: "#FFE8EE")
    static let easySleep = Color(hex: "#2F80ED")
    static let easySleepSoft = Color(hex: "#E7F1FF")
    static let easyYearning = Color(hex: "#29B87A")
    static let easyYearningSoft = Color(hex: "#E4F8EE")

    static let feedingBottle = Color(hex: "#7C5CFF")
    static let feedingBottleSoft = Color(hex: "#EDE7FF")
    static let feedingBreast = Color(hex: "#B56CFF")
    static let feedingBreastSoft = Color(hex: "#F3E8FF")
    static let feedingSolid = Color(hex: "#8E4DFF")
    static let feedingSolidSoft = Color(hex: "#EFE7FF")

    static let activityDiaper = Color(hex: "#F59A6B")
    static let activityDiaperSoft = Color(hex: "#FFF0E8")
    static let activityBath = Color(hex: "#FF9AAE")
    static let activityBathSoft = Color(hex: "#FFEAF0")
    static let activityTummyTime = Color(hex: "#FF7A90")
    static let activityComfort = Color(hex: "#FF7A90")

    static let primaryGradient = LinearGradient(
        colors: [primary, primarySoft],
        startPoint: .leading,
        endPoint: .trailing
    )
    static let primaryGradientVertical = LinearGradient(
        colors: [primary, primarySoft],
        startPoint: .top,
        endPoint: .bottom
    )

    static let cardCornerRadius: CGFloat = 16
    static let buttonCornerRadius: CGFloat = 20
    static let smallCornerRadius: CGFloat = 10
    static let standardPadding: CGFloat = 20
    static let cardPadding: CGFloat = 16
    static let elementSpacing: CGFloat = 12

    static let cardRadius: CGFloat = cardCornerRadius
    static let pillRadius: CGFloat = buttonCornerRadius
    static let tabRadius: CGFloat = 34
}

enum RecordHomeMode: String, CaseIterable, Identifiable {
    case basic
    case easy

    static let storageKey = "record_home_mode_v1"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .basic: return "基础记录"
        case .easy: return "EASY 循环"
        }
    }

    var subtitle: String {
        switch self {
        case .basic: return "适合快速记录单项喂养、尿布、睡眠。"
        case .easy: return "适合按吃、玩、睡维护完整照护节奏。"
        }
    }

    var shortTitle: String {
        switch self {
        case .basic: return "基础"
        case .easy: return "EASY"
        }
    }
}

enum EasyCyclePhase: String, Codable, CaseIterable, Identifiable {
    case eat
    case activity
    case sleep
    case yearning

    var id: String { rawValue }

    var title: String {
        switch self {
        case .eat: return "喂养"
        case .activity: return "活动"
        case .sleep: return "睡眠"
        case .yearning: return "状态"
        }
    }

    var letter: String {
        switch self {
        case .eat: return "E"
        case .activity: return "A"
        case .sleep: return "S"
        case .yearning: return "Y"
        }
    }

    var next: EasyCyclePhase? {
        switch self {
        case .eat: return .activity
        case .activity: return .sleep
        case .sleep: return .yearning
        case .yearning: return nil
        }
    }
}

enum EasyCycleStatus: String, Codable {
    case active
    case readyToPublish
    case published
}

private extension EasyCyclePhase {
    var progressionRank: Int {
        switch self {
        case .eat: return 0
        case .activity: return 1
        case .sleep: return 2
        case .yearning: return 3
        }
    }
}

enum EasyCycleLinkedRecordType: String, Codable {
    case feeding
    case care
}

struct EasyCycleRecordLink: Identifiable, Codable, Hashable {
    var id: String { "\(type.rawValue)-\(recordID.uuidString)" }
    var type: EasyCycleLinkedRecordType
    var recordID: UUID
    var phase: EasyCyclePhase
}

struct EasyCycle: Identifiable, Codable, Hashable {
    let id: UUID
    var startedAt: Date
    var endedAt: Date?
    var currentPhase: EasyCyclePhase
    var status: EasyCycleStatus
    var activityStartedAt: Date?
    var activityEndedAt: Date?
    var note: String
    var linkedRecords: [EasyCycleRecordLink]
    var publishedAt: Date?
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        currentPhase: EasyCyclePhase = .eat,
        status: EasyCycleStatus = .active,
        activityStartedAt: Date? = nil,
        activityEndedAt: Date? = nil,
        note: String = "",
        linkedRecords: [EasyCycleRecordLink] = [],
        publishedAt: Date? = nil,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.currentPhase = currentPhase
        self.status = status
        self.activityStartedAt = activityStartedAt
        self.activityEndedAt = activityEndedAt
        self.note = note
        self.linkedRecords = linkedRecords
        self.publishedAt = publishedAt
        self.updatedAt = updatedAt
    }

    var isOpen: Bool {
        status != .published
    }
}

@MainActor
final class EasyCycleStore: ObservableObject {
    static let shared = EasyCycleStore()

    @Published private(set) var cycles: [EasyCycle] = [] {
        didSet { persist() }
    }

    private let key = "easy_cycles_v1"
    private let feedingCycleTimeout: TimeInterval = 2 * 60 * 60
    private let minimumSleepMinutesForCycle = 5

    init() {
        loadCycles()
    }

    func rebuild(from feedingSessions: [FeedingSession], careRecords: [CareRecord]) {
        var existingByID: [UUID: EasyCycle] = [:]
        for cycle in cycles {
            existingByID[cycle.id] = cycle
        }
        var rebuiltCycles = buildCycles(from: feedingSessions, careRecords: careRecords)
            .map { rebuilt in
                guard let existing = existingByID[rebuilt.id] else { return rebuilt }
                return rebuilt.preservingUserState(from: existing)
            }
        rebuiltCycles.append(contentsOf: manualCyclesToKeep(afterRebuilding: rebuiltCycles))
        rebuiltCycles.sort { $0.startedAt > $1.startedAt }
        guard cycles != rebuiltCycles else { return }
        cycles = rebuiltCycles
    }

    func cycles(on date: Date) -> [EasyCycle] {
        cycles
            .filter { Calendar.current.isDate($0.startedAt, inSameDayAs: date) }
            .filter { $0.linkedRecords.isEmpty || hasStarterRecord($0) }
            .sorted { $0.startedAt > $1.startedAt }
    }

    func currentCycle(on date: Date = Date()) -> EasyCycle? {
        cycles
            .filter { Calendar.current.isDate($0.startedAt, inSameDayAs: date) }
            .filter { $0.linkedRecords.isEmpty || hasStarterRecord($0) }
            .sorted { $0.startedAt > $1.startedAt }
            .first
    }

    func performPrimaryAction(now: Date = Date(), startedAt: Date? = nil) {
        if let index = primaryActionCycleIndex(on: now) {
            advanceCycle(at: index, now: now)
        } else {
            cycles.insert(EasyCycle(startedAt: startedAt ?? now, updatedAt: now), at: 0)
        }
        sortCycles()
    }

    func updateNote(for id: UUID, note: String) {
        guard let index = cycles.firstIndex(where: { $0.id == id }) else { return }
        cycles[index].note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        cycles[index].updatedAt = Date()
    }

    func replaceLinks(for id: UUID, links: [EasyCycleRecordLink]) {
        guard let index = cycles.firstIndex(where: { $0.id == id }) else { return }
        cycles[index].linkedRecords = Array(Set(links)).sorted { $0.id < $1.id }
        normalizePhaseProgress(at: index, eventDate: Date())
        cycles[index].updatedAt = Date()
        awardIfCompleteCycle(at: index)
    }

    func ensureCycle(on date: Date, startedAt: Date, links: [EasyCycleRecordLink]) {
        let normalizedLinks = Array(Set(links)).sorted { $0.id < $1.id }
        guard !normalizedLinks.isEmpty else { return }
        guard normalizedLinks.contains(where: { $0.phase == .eat || $0.phase == .activity }) else { return }

        let calendar = Calendar.current
        if let index = cycles.indices
            .filter({ calendar.isDate(cycles[$0].startedAt, inSameDayAs: date) })
            .sorted(by: { cycles[$0].startedAt > cycles[$1].startedAt })
            .first {
            guard Set(cycles[index].linkedRecords) != Set(normalizedLinks) else { return }
            cycles[index].linkedRecords = normalizedLinks
            cycles[index].startedAt = min(cycles[index].startedAt, startedAt)
            normalizePhaseProgress(at: index, eventDate: startedAt)
            cycles[index].updatedAt = Date()
            awardIfCompleteCycle(at: index)
            sortCycles()
            return
        }

        var cycle = EasyCycle(startedAt: startedAt, linkedRecords: normalizedLinks, updatedAt: Date())
        normalizePhaseProgress(for: &cycle, eventDate: startedAt)
        cycles.insert(cycle, at: 0)
        sortCycles()
        if let index = cycles.firstIndex(where: { $0.id == cycle.id }) {
            awardIfCompleteCycle(at: index)
        }
    }

    func trackFeedingSession(_ session: FeedingSession) {
        // EASY cycles are derived from the full record set. Record stores trigger
        // a rebuild from RecordHomeView, so this legacy incremental hook is inert.
    }

    func trackCareRecord(_ record: CareRecord) {
        // EASY cycles are derived from the full record set. Record stores trigger
        // a rebuild from RecordHomeView, so this legacy incremental hook is inert.
    }

    func removeRecordLink(type: EasyCycleLinkedRecordType, recordID: UUID) {
        // Deletions are handled by a full rebuild from the remaining fact records.
    }

    func importCycles(_ incomingCycles: [EasyCycle]) {
        let existingIDs = Set(cycles.map(\.id))
        cycles = (cycles + incomingCycles.filter { !existingIDs.contains($0.id) })
            .sorted { $0.startedAt > $1.startedAt }
    }

    private func advanceCycle(at index: Int, now: Date) {
        switch cycles[index].currentPhase {
        case .eat:
            cycles[index].currentPhase = .activity
            cycles[index].activityStartedAt = cycles[index].activityStartedAt ?? now
        case .activity:
            cycles[index].currentPhase = .sleep
            cycles[index].activityEndedAt = cycles[index].activityEndedAt ?? now
        case .sleep:
            cycles[index].currentPhase = .yearning
            cycles[index].endedAt = cycles[index].endedAt ?? now
            cycles[index].status = .readyToPublish
        case .yearning:
            cycles[index].status = .published
            cycles[index].publishedAt = cycles[index].publishedAt ?? now
            cycles[index].endedAt = cycles[index].endedAt ?? now
        }
        cycles[index].updatedAt = now
    }

    private func primaryActionCycleIndex(on date: Date) -> Int? {
        let calendar = Calendar.current
        let dayIndices = cycles.indices
            .filter { calendar.isDate(cycles[$0].startedAt, inSameDayAs: date) && cycles[$0].status != .published }
            .sorted { cycles[$0].startedAt > cycles[$1].startedAt }
        guard let latestIndex = dayIndices.first else { return nil }

        if cycles[latestIndex].status == .readyToPublish || cycleHasSleep(at: latestIndex) {
            return latestIndex
        }

        if date.timeIntervalSince(cycles[latestIndex].startedAt) > hardCycleTimeout(asOf: date) {
            closeTimedOutCycle(at: latestIndex, before: date)
            return nil
        }

        return latestIndex
    }

    private func manualCyclesToKeep(afterRebuilding rebuiltCycles: [EasyCycle]) -> [EasyCycle] {
        let calendar = Calendar.current
        return cycles.filter { cycle in
            guard cycle.linkedRecords.isEmpty else { return false }
            return !rebuiltCycles.contains { rebuilt in
                calendar.isDate(rebuilt.startedAt, inSameDayAs: cycle.startedAt)
                    && rebuilt.startedAt >= cycle.startedAt
            }
        }
    }

    private func currentOpenCycleIndex(on date: Date) -> Int? {
        let calendar = Calendar.current
        let dayIndices = cycles.indices
            .filter { calendar.isDate(cycles[$0].startedAt, inSameDayAs: date) && cycles[$0].status != .published }
            .sorted { cycles[$0].startedAt > cycles[$1].startedAt }
        guard let latestIndex = dayIndices.first else { return nil }
        guard !cycleHasSleep(at: latestIndex) else { return nil }

        if date.timeIntervalSince(cycles[latestIndex].startedAt) > hardCycleTimeout(asOf: date) {
            closeTimedOutCycle(at: latestIndex, before: date)
            return nil
        }

        return latestIndex
    }

    private func closeTimedOutCycle(at index: Int, before date: Date) {
        guard cycles.indices.contains(index), !cycleHasSleep(at: index) else { return }
        let end = max(cycles[index].startedAt, date.addingTimeInterval(-1))
        cycles[index].endedAt = cycles[index].endedAt ?? end
        cycles[index].currentPhase = .sleep
        cycles[index].updatedAt = max(cycles[index].updatedAt, end)
    }

    private func appendRecordLink(
        _ link: EasyCycleRecordLink,
        eventDate: Date,
        updatedAt: Date,
        canCreateCycle: Bool = true,
        endedAt: Date? = nil
    ) {
        guard eventDate <= Date() else { return }
        let index: Int
        if let existingIndex = currentOpenCycleIndex(on: eventDate) {
            index = existingIndex
        } else {
            guard canCreateCycle else { return }
            cycles.insert(EasyCycle(startedAt: eventDate, updatedAt: updatedAt), at: 0)
            sortCycles()
            guard let createdIndex = cycles.firstIndex(where: {
                Calendar.current.isDate($0.startedAt, inSameDayAs: eventDate) && $0.startedAt == eventDate
            }) else { return }
            index = createdIndex
        }

        if !cycles[index].linkedRecords.contains(link) {
            cycles[index].linkedRecords.append(link)
        }
        cycles[index].linkedRecords = Array(Set(cycles[index].linkedRecords)).sorted { $0.id < $1.id }
        normalizePhaseProgress(at: index, eventDate: eventDate)
        if let endedAt {
            cycles[index].endedAt = endedAt
        }
        cycles[index].updatedAt = max(updatedAt, cycles[index].updatedAt)
        awardIfCompleteCycle(at: index)
        sortCycles()
    }

    private func buildCycles(from feedingSessions: [FeedingSession], careRecords: [CareRecord]) -> [EasyCycle] {
        var completedDrafts: [EasyCycleDraft] = []
        var currentDraft: EasyCycleDraft?

        for event in easyCycleEvents(from: feedingSessions, careRecords: careRecords) {
            switch event.phase {
            case .eat, .activity:
                if let draft = currentDraft {
                    if draft.hasSleep {
                        completedDrafts.append(draft)
                        currentDraft = nil
                    } else if shouldStartNewCycle(for: event, after: draft) {
                        completedDrafts.append(draft.closedForMissingSleep(before: event.startAt))
                        currentDraft = nil
                    }
                }

                if currentDraft == nil {
                    currentDraft = EasyCycleDraft(startedAt: event.startAt)
                }

                currentDraft?.append(event)

            case .sleep:
                guard var draft = currentDraft,
                      draft.hasStarterRecord,
                      !draft.hasSleep,
                      event.startAt >= draft.startedAt else {
                    continue
                }
                draft.append(event)
                completedDrafts.append(draft)
                currentDraft = nil

            case .yearning:
                continue
            }
        }

        if let currentDraft {
            completedDrafts.append(currentDraft)
        }

        let cycles = completedDrafts
            .compactMap { $0.finalizedCycle(id: stableCycleID(for: $0)) }
            .filter(hasStarterRecord)
            .sorted { $0.startedAt > $1.startedAt }

        return cycles
    }

    private func shouldStartNewCycle(for event: EasyCycleEvent, after draft: EasyCycleDraft) -> Bool {
        let calendar = Calendar.current
        if !calendar.isDate(event.startAt, inSameDayAs: draft.startedAt) {
            return true
        }

        if event.startAt.timeIntervalSince(draft.lastStarterAt) > hardCycleTimeout(asOf: event.startAt) {
            return true
        }

        if event.phase == .eat,
           let lastEatAt = draft.lastEatAt,
           event.startAt.timeIntervalSince(lastEatAt) > feedingCycleTimeout {
            return true
        }

        return false
    }

    private func easyCycleEvents(
        from feedingSessions: [FeedingSession],
        careRecords: [CareRecord]
    ) -> [EasyCycleEvent] {
        let feedingEvents = feedingSessions.compactMap { session -> EasyCycleEvent? in
            guard session.hasData else { return nil }
            let startAt = session.startAt ?? session.createdAt
            guard startAt <= Date() else { return nil }
            let endAt = max(session.endAt ?? session.createdAt, startAt)
            return EasyCycleEvent(
                link: EasyCycleRecordLink(type: .feeding, recordID: session.id, phase: .eat),
                phase: .eat,
                startAt: startAt,
                endAt: endAt
            )
        }

        let careEvents = careRecords.compactMap { record -> EasyCycleEvent? in
            guard record.recordedAt <= Date() else { return nil }
            switch record.kind {
            case .diaper, .activity:
                return EasyCycleEvent(
                    link: EasyCycleRecordLink(type: .care, recordID: record.id, phase: .activity),
                    phase: .activity,
                    startAt: record.recordedAt,
                    endAt: record.recordedAt
                )
            case .sleep:
                guard let duration = SleepRecordFormatter.durationMinutes(from: record.detail),
                      duration >= minimumSleepMinutesForCycle else {
                    return nil
                }
                let endAt = SleepRecordFormatter.endTime(start: record.recordedAt, durationMinutes: duration)
                return EasyCycleEvent(
                    link: EasyCycleRecordLink(type: .care, recordID: record.id, phase: .sleep),
                    phase: .sleep,
                    startAt: record.recordedAt,
                    endAt: max(endAt, record.recordedAt)
                )
            }
        }

        return (feedingEvents + careEvents).sorted { lhs, rhs in
            if lhs.startAt != rhs.startAt {
                return lhs.startAt < rhs.startAt
            }
            return lhs.sortPriority < rhs.sortPriority
        }
    }

    private func normalizePhaseProgress(at index: Int, eventDate: Date) {
        guard cycles.indices.contains(index) else { return }
        normalizePhaseProgress(for: &cycles[index], eventDate: eventDate)
    }

    private func normalizePhaseProgress(for cycle: inout EasyCycle, eventDate: Date) {
        let phases = Set(cycle.linkedRecords.map(\.phase))
        if phases.contains(.sleep) {
            cycle.currentPhase = .yearning
            return
        }
        if phases.contains(.activity) {
            cycle.currentPhase = .sleep
            cycle.endedAt = nil
            cycle.activityEndedAt = cycle.activityEndedAt ?? eventDate
            return
        }
        if phases.contains(.eat) {
            cycle.currentPhase = .activity
            cycle.endedAt = nil
            cycle.activityStartedAt = cycle.activityStartedAt ?? eventDate
            return
        }
        cycle.currentPhase = .eat
        cycle.endedAt = nil
    }

    private func awardIfCompleteCycle(at index: Int) {
        guard cycles.indices.contains(index) else { return }
        let phases = Set(cycles[index].linkedRecords.map(\.phase))
        guard phases.contains(.eat),
              phases.contains(.activity),
              phases.contains(.sleep) else {
            return
        }
        let completedAt = cycles[index].endedAt ?? cycles[index].updatedAt
        CompanionRecruitmentStore.shared.awardBBBucks(
            forEasyCycle: cycles[index].id,
            completedAt: completedAt
        )
    }

    private func cycleHasSleep(at index: Int) -> Bool {
        guard cycles.indices.contains(index) else { return false }
        return cycles[index].linkedRecords.contains { $0.phase == .sleep }
    }

    private func hasStarterRecord(_ cycle: EasyCycle) -> Bool {
        cycle.linkedRecords.contains { $0.phase == .eat || $0.phase == .activity }
    }

    private func hardCycleTimeout(asOf date: Date) -> TimeInterval {
        TimeInterval(Self.maxWakeWindowMinutes(ageMonths: babyAgeMonths(asOf: date)) * 60)
    }

    private func babyAgeMonths(asOf date: Date) -> Int {
        let birthDate = BabyProfileStore.shared.currentProfile.birthDate
        return max(Calendar.current.dateComponents([.month], from: birthDate, to: date).month ?? 0, 0)
    }

    private static func maxWakeWindowMinutes(ageMonths: Int) -> Int {
        switch max(ageMonths, 0) {
        case 0...1:
            return 60
        case 2:
            return 75
        case 3:
            return 90
        case 4:
            return 120
        case 5:
            return 135
        case 6:
            return 150
        case 7:
            return 165
        case 8...9:
            return 180
        case 10:
            return 195
        case 11:
            return 210
        case 12...13:
            return 240
        case 14:
            return 270
        case 15:
            return 270
        case 16:
            return 300
        case 17:
            return 300
        case 18:
            return 330
        case 19...20:
            return 360
        case 21...24:
            return 360
        case 25...30:
            return 390
        default:
            return 420
        }
    }

    private func stableCycleID(for draft: EasyCycleDraft) -> UUID {
        let starterID = draft.links.first(where: { $0.phase == .eat || $0.phase == .activity })?.id ?? draft.links.first?.id ?? "empty"
        let dayStart = Calendar.current.startOfDay(for: draft.startedAt).timeIntervalSince1970
        return UUID.stableEasyCycleUUID(seed: "\(dayStart)|\(starterID)")
    }

    private func sortCycles() {
        cycles.sort { $0.startedAt > $1.startedAt }
    }

    private func loadCycles() {
        let appGroupDefaults = UserDefaults(suiteName: WidgetStorageKey.appGroupID)
        guard let data = UserDefaults.standard.data(forKey: key)
            ?? appGroupDefaults?.data(forKey: key),
              let decoded = try? JSONDecoder().decode([EasyCycle].self, from: data) else {
            return
        }
        cycles = decoded.sorted { $0.startedAt > $1.startedAt }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(cycles) else { return }
        UserDefaults.standard.set(data, forKey: key)
        UserDefaults(suiteName: WidgetStorageKey.appGroupID)?.set(data, forKey: key)
    }
}

private struct EasyCycleEvent {
    let link: EasyCycleRecordLink
    let phase: EasyCyclePhase
    let startAt: Date
    let endAt: Date

    var sortPriority: Int {
        switch phase {
        case .eat: return 0
        case .activity: return 1
        case .sleep: return 2
        case .yearning: return 3
        }
    }
}

private struct EasyCycleDraft {
    var startedAt: Date
    var endedAt: Date?
    var activityStartedAt: Date?
    var activityEndedAt: Date?
    var links: [EasyCycleRecordLink] = []
    var updatedAt: Date
    var lastStarterAt: Date
    var lastEatAt: Date?

    init(startedAt: Date) {
        self.startedAt = startedAt
        self.updatedAt = startedAt
        self.lastStarterAt = startedAt
        self.lastEatAt = nil
    }

    var hasStarterRecord: Bool {
        links.contains { $0.phase == .eat || $0.phase == .activity }
    }

    var hasEat: Bool {
        links.contains { $0.phase == .eat }
    }

    var hasActivity: Bool {
        links.contains { $0.phase == .activity }
    }

    var hasSleep: Bool {
        links.contains { $0.phase == .sleep }
    }

    mutating func append(_ event: EasyCycleEvent) {
        if !links.contains(event.link) {
            links.append(event.link)
        }

        startedAt = min(startedAt, event.startAt)
        updatedAt = max(updatedAt, event.endAt)

        switch event.phase {
        case .eat:
            lastStarterAt = event.startAt
            lastEatAt = event.startAt
        case .activity:
            lastStarterAt = event.startAt
            activityStartedAt = activityStartedAt ?? event.startAt
            activityEndedAt = event.startAt
        case .sleep:
            endedAt = event.endAt
        case .yearning:
            break
        }
    }

    func closedForMissingSleep(before date: Date) -> EasyCycleDraft {
        var copy = self
        let fallbackEnd = max(lastStarterAt, date.addingTimeInterval(-1))
        copy.endedAt = copy.endedAt ?? fallbackEnd
        copy.updatedAt = max(copy.updatedAt, fallbackEnd)
        return copy
    }

    func finalizedCycle(id: UUID) -> EasyCycle? {
        guard hasStarterRecord else { return nil }

        let phase: EasyCyclePhase
        if hasSleep {
            phase = .yearning
        } else if hasActivity {
            phase = .sleep
        } else if hasEat {
            phase = .activity
        } else {
            phase = .eat
        }

        return EasyCycle(
            id: id,
            startedAt: startedAt,
            endedAt: endedAt,
            currentPhase: phase,
            status: hasSleep ? .readyToPublish : .active,
            activityStartedAt: activityStartedAt,
            activityEndedAt: activityEndedAt,
            linkedRecords: Array(Set(links)).sorted { $0.id < $1.id },
            updatedAt: updatedAt
        )
    }
}

private extension EasyCycle {
    func preservingUserState(from existing: EasyCycle) -> EasyCycle {
        var cycle = self
        cycle.note = existing.note
        cycle.activityStartedAt = cycle.activityStartedAt ?? existing.activityStartedAt
        cycle.activityEndedAt = cycle.activityEndedAt ?? existing.activityEndedAt
        cycle.publishedAt = existing.publishedAt

        switch existing.status {
        case .published:
            cycle.status = .published
            cycle.currentPhase = .yearning
            cycle.endedAt = existing.endedAt ?? cycle.endedAt ?? existing.updatedAt
            cycle.publishedAt = existing.publishedAt ?? existing.updatedAt
        case .readyToPublish:
            cycle.status = .readyToPublish
            cycle.currentPhase = .yearning
            cycle.endedAt = existing.endedAt ?? cycle.endedAt
        case .active:
            if existing.currentPhase.progressionRank > cycle.currentPhase.progressionRank {
                cycle.currentPhase = existing.currentPhase
                cycle.endedAt = existing.endedAt ?? cycle.endedAt
            }
        }

        cycle.updatedAt = max(cycle.updatedAt, existing.updatedAt)
        return cycle
    }
}

private extension UUID {
    static func stableEasyCycleUUID(seed: String) -> UUID {
        let first = fnv1a64(seed: "easy-cycle-a|\(seed)")
        let second = fnv1a64(seed: "easy-cycle-b|\(seed)")
        var bytes = [UInt8]()

        for shift in stride(from: 56, through: 0, by: -8) {
            bytes.append(UInt8((first >> UInt64(shift)) & 0xff))
        }
        for shift in stride(from: 56, through: 0, by: -8) {
            bytes.append(UInt8((second >> UInt64(shift)) & 0xff))
        }

        bytes[6] = (bytes[6] & 0x0f) | 0x50
        bytes[8] = (bytes[8] & 0x3f) | 0x80

        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    private static func fnv1a64(seed: String) -> UInt64 {
        var hash: UInt64 = 14695981039346656037
        for byte in seed.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }
        return hash
    }
}

extension Color {
    init(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }

        var number: UInt64 = 0
        Scanner(string: value).scanHexInt64(&number)

        switch value.count {
        case 6:
            self.init(
                .sRGB,
                red: Double((number & 0xFF0000) >> 16) / 255,
                green: Double((number & 0x00FF00) >> 8) / 255,
                blue: Double(number & 0x0000FF) / 255,
                opacity: 1
            )
        case 8:
            self.init(
                .sRGB,
                red: Double((number & 0xFF000000) >> 24) / 255,
                green: Double((number & 0x00FF0000) >> 16) / 255,
                blue: Double((number & 0x0000FF00) >> 8) / 255,
                opacity: Double(number & 0x000000FF) / 255
            )
        default:
            self = .clear
        }
    }
}

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: DesignToken.cardCornerRadius)
                    .fill(DesignToken.cardBackground)
                    .shadow(color: .black.opacity(0.05), radius: 12, y: 6)
            )
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: configuration.isPressed)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardModifier())
    }

    func primaryButtonStyle() -> some View {
        foregroundStyle(.white)
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .background(Capsule().fill(DesignToken.primaryGradient))
    }
}

// MARK: - Companion

enum CompanionRarity: String, Codable, CaseIterable, Hashable {
    case common
    case uncommon
    case rare
    case precious

    var title: String {
        switch self {
        case .common: return "普通"
        case .uncommon: return "少见"
        case .rare: return "稀有"
        case .precious: return "珍稀"
        }
    }

    var friendshipTarget: Int {
        switch self {
        case .common: return 30
        case .uncommon: return 60
        case .rare: return 100
        case .precious: return 160
        }
    }

    var dailyServingLimit: Int { 3 }

    var visitWeight: Double {
        switch self {
        case .common: return 1
        case .uncommon: return 0.46
        case .rare: return 0.2
        case .precious: return 0.1
        }
    }
}

struct BabyCompanion: Identifiable, Codable, Hashable {
    let id: String
    let chineseName: String
    let englishName: String
    let species: String
    let intro: String
    let emoji: String
    var rarity: CompanionRarity = .common
    var preferenceTags: [String] = []
    var specialConditionTags: [String] = []

    var name: String { englishName }
    var subtitle: String { "\(chineseName) · \(species)" }
    var description: String { intro }
    var portraitAssetName: String { "companion_\(englishName.lowercased())_portrait" }
    var catalogNumber: String {
        guard let index = Self.all.firstIndex(where: { $0.id == id }) else { return "C--" }
        return "C\(String(format: "%02d", index + 1))"
    }
    var temperamentLabel: String {
        switch id {
        case "bunny_lulu", "fawn_mimi", "cal", "samoyed_momo", "piggy", "alpaca_minta", "capybara_cappy", "panda_pandy", "beardie_beardy":
            return "稳定亲近"
        case "otter_tangtang", "fenny", "redpanda_youyou", "ferry", "raccoon_rocky", "seal_poro", "meerkat_meeko", "arcticfox_arki", "seaotter_otta", "macaque_maki", "kinkajou_kinka", "ringtail_ringo":
            return "节奏多变"
        case "koala_anan", "sloth_nono", "hedgehog_lili", "penguin_pino", "quokka_quoki", "chinchilla_chilla", "wombat_womby", "crane_crany", "tibetanfox_tibe", "manedwolf_maney", "moose_moosy":
            return "慢热观察"
        case "chipmunk_huohuo", "lemur_mika", "hamster_shushu", "sugar_glider_taffy", "sandcat_sandy", "flyingsquirrel_glidy", "pallascat_pally", "tapir_tapi":
            return "高敏感"
        default:
            return "温柔陪伴"
        }
    }
    var temperamentStyle: (tint: Color, text: Color) {
        switch temperamentLabel {
        case "稳定亲近":
            return (Color(hex: "#A8DCC5"), Color(hex: "#4E806A"))
        case "节奏多变":
            return (Color(hex: "#F0C77C"), Color(hex: "#966B22"))
        case "慢热观察":
            return (Color(hex: "#AFC7F4"), Color(hex: "#536FAD"))
        case "高敏感":
            return (Color(hex: "#F2B8C8"), Color(hex: "#A25670"))
        default:
            return (Color(hex: "#D7D0EA"), Color(hex: "#6D6388"))
        }
    }
    var worldDistribution: String {
        switch id {
        case "bunny_lulu": return "荷兰培育，现随宠物与展示饲养分布于多地。"
        case "fawn_mimi": return "原产东亚，见于中国、日本、朝鲜半岛与俄罗斯远东等地。"
        case "cal": return "欧洲培育的展示鸭品种，随观赏饲养分布。"
        case "samoyed_momo": return "源自西伯利亚萨摩耶人地区，现作为家犬在全球多地饲养。"
        case "otter_tangtang": return "野外原产南亚和东南亚湿地、河流、红树林等生境。"
        case "fenny": return "野外分布于撒哈拉及北非干旱荒漠。"
        case "redpanda_youyou": return "野外局限于喜马拉雅东段和中国西南山地。"
        case "koala_anan": return "野外分布于澳大利亚东部和东南部桉树林。"
        case "sloth_nono": return "野外分布于中美洲至南美洲部分热带森林。"
        case "chipmunk_huohuo": return "野外广布于北亚和东北亚森林。"
        case "piggy": return "家养小型猪品系，主要见于实验、宠物和保育饲养。"
        case "ferry": return "家养雪貂品系，现欧美及多地作为宠物饲养。"
        case "alpaca_minta": return "南美安第斯家养驼类，现全球牧场饲养。"
        case "raccoon_rocky": return "原产北美，现北美广泛分布，并被引入欧洲、日本等地。"
        case "seal_poro": return "广布北半球温带和亚寒带沿海水域。"
        case "hedgehog_lili": return "刺猬类分布于欧洲、亚洲、非洲。"
        case "penguin_pino": return "以小企鹅为参考，原产澳大利亚和新西兰沿海。"
        case "lemur_mika": return "以环尾狐猴为参考，野外仅见于马达加斯加南部和西南部。"
        case "hamster_shushu": return "以叙利亚仓鼠为参考，野外原产叙利亚、土耳其一带。"
        case "sugar_glider_taffy": return "原产澳大利亚、新几内亚及周边岛屿。"
        case "capybara_cappy": return "原产南美洲，主要分布于湿地、河流和沼泽区域。"
        case "quokka_quoki": return "野外分布于澳大利亚西南部少数岛屿和沿海灌丛。"
        case "meerkat_meeko": return "原产非洲南部干旱草原和沙漠边缘。"
        case "sandcat_sandy": return "原产北非和中东的沙漠地带。"
        case "arcticfox_arki": return "原产北极圈附近苔原地带。"
        case "seaotter_otta": return "原产北太平洋沿岸海域。"
        case "flyingsquirrel_glidy": return "以亚洲大型鼯鼠为参考，主要生活在森林树冠层。"
        case "chinchilla_chilla": return "野外原产南美洲安第斯山脉高海拔地区。"
        case "pallascat_pally": return "原产中亚高原和干旱草原、岩石地带。"
        case "wombat_womby": return "原产澳大利亚东南部和塔斯马尼亚。"
        case "panda_pandy": return "原产中国西南山区竹林。"
        case "crane_crany": return "原产东亚湿地，迁徙经过东北亚多地。"
        case "macaque_maki": return "猕猴广泛分布于亚洲多地，常见于山地、林缘与河谷环境。"
        case "beardie_beardy": return "原产澳大利亚中部和东部干旱林地。"
        case "tibetanfox_tibe": return "原产青藏高原及周边高寒草甸、荒漠草原地带。"
        case "manedwolf_maney": return "原产南美洲草原和灌丛地带。"
        case "kinkajou_kinka": return "原产中美洲和南美洲热带雨林。"
        case "ringtail_ringo": return "原产北美西南部干旱林地和岩石区域。"
        case "tapir_tapi": return "以低地貘为参考，原产南美洲森林和湿地。"
        case "moose_moosy": return "分布于北半球寒温带森林和湿地。"
        default: return "更多分布资料整理中。"
        }
    }
    var friendshipTarget: Int { rarity.friendshipTarget }
    var dailyServingLimit: Int { rarity.dailyServingLimit }
    var visitAffinityTags: Set<String> {
        var tags = Set(preferenceTags)

        switch temperamentLabel {
        case "稳定亲近":
            tags.formUnion(["feeding", "sleep", "steady"])
        case "节奏多变":
            tags.formUnion(["feeding", "active"])
        case "慢热观察":
            tags.formUnion(["sleep", "steady"])
        case "高敏感":
            tags.formUnion(["diaper", "quiet"])
        default:
            tags.insert("steady")
        }

        if rarity == .rare || rarity == .precious {
            tags.insert("special")
        }

        return tags
    }
    var lockedMaskAssetName: String? {
        "companion_\(englishName.lowercased())_locked_mask"
    }

    static let all: [BabyCompanion] = [
        .init(id: "bunny_lulu", chineseName: "洛噗", englishName: "Loppy", species: "荷兰垂耳兔宝宝", intro: "稳定亲近、反应柔和，是容易被轻轻引导的小甜心。", emoji: "🐰", rarity: .common),
        .init(id: "fawn_mimi", chineseName: "西咔", englishName: "Sika", species: "梅花鹿宝宝", intro: "安静细腻、喜欢熟悉节奏，需要被温柔守护。", emoji: "🦌", rarity: .common),
        .init(id: "cal", chineseName: "柯噜", englishName: "Cal", species: "柯尔鸭宝宝", intro: "圆滚滚、步伐慢半拍，擅长把普通日常变得可爱。", emoji: "🦆", rarity: .uncommon),
        .init(id: "samoyed_momo", chineseName: "摩耶", englishName: "Moye", species: "萨摩耶宝宝", intro: "亲和稳定、适应力强，像随时给人安心的陪伴。", emoji: "🐶", rarity: .common),
        .init(id: "otter_tangtang", chineseName: "欧缇", englishName: "Ottie", species: "亚洲小爪水獭宝宝", intro: "状态丰富、节奏多变，需要弹性和耐心配合。", emoji: "🦦", rarity: .rare),
        .init(id: "fenny", chineseName: "芬灵", englishName: "Fenny", species: "耳廓狐宝宝", intro: "敏锐聪明、先观察再靠近，对环境里的细节特别有感觉。", emoji: "🦊", rarity: .uncommon),
        .init(id: "redpanda_youyou", chineseName: "瑞迪", englishName: "Reddy", species: "小熊猫宝宝", intro: "柔软但有主见，喜欢按自己的方式慢慢进入状态。", emoji: "🐾", rarity: .precious),
        .init(id: "koala_anan", chineseName: "阿考", englishName: "Ako", species: "昆士兰考拉宝宝", intro: "慢热谨慎、观察力强，安全感足够后会认真靠近。", emoji: "🐨", rarity: .rare),
        .init(id: "sloth_nono", chineseName: "霍菲", englishName: "Hoffy", species: "霍氏树懒宝宝", intro: "慢节奏、低刺激偏好，需要更从容的过渡时间。", emoji: "🌿", rarity: .uncommon),
        .init(id: "chipmunk_huohuo", chineseName: "奇比", englishName: "Chippy", species: "西伯利亚花栗鼠宝宝", intro: "感受强烈、反应很快，需要更多安抚和提前预告。", emoji: "✨", rarity: .common),
        .init(id: "piggy", chineseName: "尤卡", englishName: "Yuca", species: "尤卡坦迷你猪宝宝", intro: "爱睡觉也爱贴贴，是小木屋里最松弛的暖心伙伴。", emoji: "🐷", rarity: .uncommon),
        .init(id: "ferry", chineseName: "雪溜", englishName: "Ferry", species: "安格鲁貂宝宝", intro: "软绵灵活、好奇心强，喜欢在日常缝隙里发现小惊喜。", emoji: "🦦", rarity: .common),
        .init(id: "alpaca_minta", chineseName: "绵塔", englishName: "Minta", species: "羊驼宝宝", intro: "温顺松弛、节奏稳定，是会把紧张气氛慢慢变软的小伙伴。", emoji: "🦙", rarity: .common),
        .init(id: "raccoon_rocky", chineseName: "洛奇", englishName: "Rocky", species: "浣熊宝宝", intro: "聪明好奇、很有小主意，是喜欢在日常角落里发现新鲜事的小侦探。", emoji: "🦝", rarity: .common),
        .init(id: "seal_poro", chineseName: "泡露", englishName: "Poro", species: "小海豹宝宝", intro: "亲近爱撒娇、状态切换丰富，是今天想贴贴、明天想探索的小浪花。", emoji: "🦭", rarity: .common),
        .init(id: "hedgehog_lili", chineseName: "栗栗", englishName: "Lili", species: "小刺猬宝宝", intro: "谨慎慢热、内心柔软，是熟悉之后才会悄悄靠近的小暖球。", emoji: "🦔", rarity: .uncommon),
        .init(id: "penguin_pino", chineseName: "皮诺", englishName: "Pino", species: "小企鹅宝宝", intro: "慢热认真、需要安全感，是先站稳再一步步靠近世界的小朋友。", emoji: "🐧", rarity: .uncommon),
        .init(id: "lemur_mika", chineseName: "米卡", englishName: "Mika", species: "小狐猴宝宝", intro: "眼神敏锐、反应很快，是很容易感受到环境变化的小观察家。", emoji: "🐾", rarity: .precious),
        .init(id: "hamster_shushu", chineseName: "咻咻", englishName: "Shushu", species: "小仓鼠宝宝", intro: "感受细腻、动作很快，是紧张时想躲一躲、安心后会主动贴近的小伙伴。", emoji: "🐹", rarity: .rare),
        .init(id: "sugar_glider_taffy", chineseName: "糖飞", englishName: "Taffy", species: "小蜜袋鼯宝宝", intro: "黏人敏感、很需要陪伴，是分开时会想念、靠近时会放松的小夜星。", emoji: "🐾", rarity: .rare),
        .init(id: "capybara_cappy", chineseName: "卡皮", englishName: "Cappy", species: "水豚宝宝", intro: "佛系松弛、节奏很慢，是任何时候都不会着急的温柔大个子。", emoji: "🐾", rarity: .uncommon),
        .init(id: "quokka_quoki", chineseName: "阔奇", englishName: "Quoki", species: "短尾矮袋鼠宝宝", intro: "天然笑脸、慢热谨慎，是笑着观察很久才愿意靠近的小太阳。", emoji: "🐾", rarity: .rare),
        .init(id: "meerkat_meeko", chineseName: "米寇", englishName: "Meeko", species: "狐獴宝宝", intro: "好奇勇敢、团队意识强，是探头看看世界又会回头确认同伴的小哨兵。", emoji: "🐾", rarity: .uncommon),
        .init(id: "sandcat_sandy", chineseName: "砂迪", englishName: "Sandy", species: "沙丘猫宝宝", intro: "耳朵很大、感受力很强，是安静环境里才能放松的细腻小耳朵。", emoji: "🐾", rarity: .rare),
        .init(id: "arcticfox_arki", chineseName: "阿奇", englishName: "Arki", species: "北极狐宝宝", intro: "会随环境慢慢调整状态，是适应力强又有自己节奏的雪地小精灵。", emoji: "🐾", rarity: .uncommon),
        .init(id: "seaotter_otta", chineseName: "奥塔", englishName: "Otta", species: "海獭宝宝", intro: "活泼爱互动、动手能力强，是喜欢用小手探索世界的水中开心果。", emoji: "🐾", rarity: .rare),
        .init(id: "flyingsquirrel_glidy", chineseName: "格莱", englishName: "Glidy", species: "大鼯鼠宝宝", intro: "大眼睛、动作快，是容易受惊但滑翔起来特别优雅的夜空小星星。", emoji: "🐾", rarity: .uncommon),
        .init(id: "chinchilla_chilla", chineseName: "奇拉", englishName: "Chilla", species: "长毛龙猫宝宝", intro: "毛茸茸、胆子小，是需要很安静才能放松下来的蓬松小团子。", emoji: "🐾", rarity: .uncommon),
        .init(id: "pallascat_pally", chineseName: "帕利", englishName: "Pally", species: "兔狲宝宝", intro: "天生表情酷酷的，但内心很敏感，是需要慢慢靠近的小方脸。", emoji: "🐾", rarity: .rare),
        .init(id: "wombat_womby", chineseName: "旺比", englishName: "Womby", species: "袋熊宝宝", intro: "方方正正、慢吞吞，是踏踏实实走每一步的澳洲小土墩。", emoji: "🐾", rarity: .uncommon),
        .init(id: "panda_pandy", chineseName: "潘迪", englishName: "Pandy", species: "大熊猫宝宝", intro: "圆滚滚、慢吞吞，是让紧张日常慢慢软下来的黑白小团子。", emoji: "🐾", rarity: .precious),
        .init(id: "crane_crany", chineseName: "克瑞", englishName: "Crany", species: "丹顶鹤宝宝", intro: "优雅安静、节奏很慢，是先远远看着再慢慢走近的白色小伙伴。", emoji: "🐾", rarity: .precious),
        .init(id: "macaque_maki", chineseName: "玛奇", englishName: "Maki", species: "猕猴宝宝", intro: "红脸蛋、好奇心强，是喜欢观察别人也有自己主意的社交小暖猴。", emoji: "🐾", rarity: .uncommon),
        .init(id: "beardie_beardy", chineseName: "比迪", englishName: "Beardy", species: "中部鬃狮蜥宝宝", intro: "看起来有点酷但其实很温和，是喜欢安静晒太阳的淡定小伙伴。", emoji: "🐾", rarity: .uncommon),
        .init(id: "tibetanfox_tibe", chineseName: "提布", englishName: "Tibe", species: "藏狐宝宝", intro: "表情淡定、慢热观察，是确认安全后才把柔软一面露出来的高原小伙伴。", emoji: "🐾", rarity: .uncommon),
        .init(id: "manedwolf_maney", chineseName: "曼耶", englishName: "Maney", species: "鬃狼宝宝", intro: "步子很轻、距离感强，是确认安全后才慢慢靠近的安静小影子。", emoji: "🐾", rarity: .rare),
        .init(id: "kinkajou_kinka", chineseName: "金卡", englishName: "Kinka", species: "蜜熊宝宝", intro: "夜晚才活跃、节奏特别，是安静夜色里慢慢探索的甜蜜小伙伴。", emoji: "🐾", rarity: .rare),
        .init(id: "ringtail_ringo", chineseName: "林果", englishName: "Ringo", species: "环尾猫宝宝", intro: "尾巴一圈一圈、好奇又灵巧，是喜欢在角落里发现秘密的小伙伴。", emoji: "🐾", rarity: .uncommon),
        .init(id: "tapir_tapi", chineseName: "塔皮", englishName: "Tapi", species: "小貘宝宝", intro: "鼻子软软、感受细腻，是先闻闻世界再决定靠近的小森林朋友。", emoji: "🐾", rarity: .rare),
        .init(id: "moose_moosy", chineseName: "穆西", englishName: "Moosy", species: "小驼鹿宝宝", intro: "大耳朵、慢半拍，是需要宽宽空间和慢慢节奏的温和大朋友。", emoji: "🐾", rarity: .uncommon)
    ]

    static let defaultUnlockedIDs: Set<String> = ["piggy", "fenny", "ferry", "cal"]
    static let previewLockedIDs: Set<String> = []

    static func companion(for id: String) -> BabyCompanion {
        all.first(where: { $0.id == id }) ?? all[2]
    }

    static func canonicalID(_ id: String) -> String {
        id
    }

    static func unlockedIDs(selectedID: String, temperamentAnimalID: String?) -> Set<String> {
        if AppVariant.unlocksAllBuddiesForLocalRun {
            return Set(all.map { canonicalID($0.id) })
        }

        var ids = Set(defaultUnlockedIDs.map(canonicalID))
        ids.insert(canonicalID(selectedID))

        if let temperamentAnimalID {
            ids.insert(canonicalID(temperamentAnimalID))
        }

        ids.subtract(previewLockedIDs.map(canonicalID))
        return ids
    }

    func isUnlocked(selectedID: String, temperamentAnimalID: String?) -> Bool {
        Self.unlockedIDs(selectedID: selectedID, temperamentAnimalID: temperamentAnimalID)
            .contains(Self.canonicalID(id))
    }

    static func companionPageAnimals(selectedID: String, temperamentAnimalID: String?, recruitedIDs: Set<String> = []) -> [CompanionAnimalPresence] {
        all.map { companion in
            let isResident = companion.isUnlocked(selectedID: selectedID, temperamentAnimalID: temperamentAnimalID)
                || recruitedIDs.contains(companion.id)
            return CompanionAnimalPresence(
                companion: companion,
                role: isResident ? .resident : .visitor
            )
        }
    }
}

enum CompanionAnimalRole: String, Codable, Hashable {
    case resident
    case visitor

    var title: String {
        switch self {
        case .resident: return "常驻"
        case .visitor: return "来访"
        }
    }
}

struct CompanionAnimalPresence: Identifiable, Hashable {
    let companion: BabyCompanion
    let role: CompanionAnimalRole

    var id: String { companion.id }
    var isResident: Bool { role == .resident }
}

@MainActor
final class CompanionStore: ObservableObject {
    @Published var selectedID: String {
        didSet {
            UserDefaults.standard.set(selectedID, forKey: "selected_companion_id")
            FamilyCloudStore.shared.scheduleUpload(reason: "companion")
        }
    }

    init() {
        self.selectedID = UserDefaults.standard.string(forKey: "selected_companion_id") ?? "cal"
    }

    var selected: BabyCompanion {
        BabyCompanion.all.first(where: { $0.id == selectedID }) ?? BabyCompanion.all[3]
    }

    func importSelectedID(_ id: String) {
        guard BabyCompanion.all.contains(where: { $0.id == id }) else { return }
        selectedID = id
    }
}

struct YesterdayReport: Identifiable, Codable, Equatable {
    var id: String { reportKey }
    var reportKey: String
    var date: Date
    var dateText: String
    var feedingCount: Int
    var bottleAmount: Int
    var breastMinutes: Int
    var solidAmount: Int
    var diaperCount: Int
    var sleepMinutes: Int
    var feedingHours: Set<Int>
    var diaperHours: Set<Int>
    var sleepHours: Set<Int>
    var rhythmText: String
    var analysisText: String
    var earnedBBBucks: Int
    var visitorCompanionID: String
    var visitorCompanionIDs: [String]
    var fedCompanionID: String?
    var fedBBBucks: Int
    var feedings: [YesterdayBuddyFeeding]
    var createdAt: Date

    var visitorIDs: [String] {
        let ids = visitorCompanionIDs.isEmpty ? [visitorCompanionID] : visitorCompanionIDs
        return Array(NSOrderedSet(array: ids).compactMap { $0 as? String })
    }

    init(
        reportKey: String,
        date: Date,
        dateText: String,
        feedingCount: Int,
        bottleAmount: Int,
        breastMinutes: Int,
        solidAmount: Int,
        diaperCount: Int,
        sleepMinutes: Int,
        feedingHours: Set<Int>,
        diaperHours: Set<Int>,
        sleepHours: Set<Int>,
        rhythmText: String,
        analysisText: String,
        earnedBBBucks: Int,
        visitorCompanionID: String,
        visitorCompanionIDs: [String]? = nil,
        fedCompanionID: String? = nil,
        fedBBBucks: Int = 0,
        feedings: [YesterdayBuddyFeeding]? = nil,
        createdAt: Date
    ) {
        self.reportKey = reportKey
        self.date = date
        self.dateText = dateText
        self.feedingCount = feedingCount
        self.bottleAmount = bottleAmount
        self.breastMinutes = breastMinutes
        self.solidAmount = solidAmount
        self.diaperCount = diaperCount
        self.sleepMinutes = sleepMinutes
        self.feedingHours = feedingHours
        self.diaperHours = diaperHours
        self.sleepHours = sleepHours
        self.rhythmText = rhythmText
        self.analysisText = analysisText
        self.earnedBBBucks = earnedBBBucks
        self.visitorCompanionID = visitorCompanionID
        let visitors = visitorCompanionIDs ?? [visitorCompanionID]
        self.visitorCompanionIDs = visitors.isEmpty ? [visitorCompanionID] : visitors
        self.fedCompanionID = fedCompanionID
        self.fedBBBucks = fedBBBucks
        if let feedings {
            self.feedings = feedings
        } else if let fedCompanionID, fedBBBucks > 0 {
            self.feedings = [
                YesterdayBuddyFeeding(
                    companionID: fedCompanionID,
                    servings: fedBBBucks,
                    spentBBBucks: fedBBBucks,
                    bonusServings: 0
                )
            ]
        } else {
            self.feedings = []
        }
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case reportKey
        case date
        case dateText
        case feedingCount
        case bottleAmount
        case breastMinutes
        case solidAmount
        case diaperCount
        case sleepMinutes
        case feedingHours
        case diaperHours
        case sleepHours
        case rhythmText
        case analysisText
        case earnedBBBucks
        case visitorCompanionID
        case visitorCompanionIDs
        case fedCompanionID
        case fedBBBucks
        case feedings
        case createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        reportKey = try container.decode(String.self, forKey: .reportKey)
        date = try container.decode(Date.self, forKey: .date)
        dateText = try container.decode(String.self, forKey: .dateText)
        feedingCount = try container.decode(Int.self, forKey: .feedingCount)
        bottleAmount = try container.decode(Int.self, forKey: .bottleAmount)
        breastMinutes = try container.decode(Int.self, forKey: .breastMinutes)
        solidAmount = try container.decode(Int.self, forKey: .solidAmount)
        diaperCount = try container.decode(Int.self, forKey: .diaperCount)
        sleepMinutes = try container.decode(Int.self, forKey: .sleepMinutes)
        feedingHours = try container.decode(Set<Int>.self, forKey: .feedingHours)
        diaperHours = try container.decode(Set<Int>.self, forKey: .diaperHours)
        sleepHours = try container.decode(Set<Int>.self, forKey: .sleepHours)
        rhythmText = try container.decode(String.self, forKey: .rhythmText)
        analysisText = try container.decode(String.self, forKey: .analysisText)
        earnedBBBucks = try container.decode(Int.self, forKey: .earnedBBBucks)
        visitorCompanionID = try container.decode(String.self, forKey: .visitorCompanionID)
        visitorCompanionIDs = try container.decodeIfPresent([String].self, forKey: .visitorCompanionIDs) ?? [visitorCompanionID]
        if visitorCompanionIDs.isEmpty {
            visitorCompanionIDs = [visitorCompanionID]
        }
        fedCompanionID = try container.decodeIfPresent(String.self, forKey: .fedCompanionID)
        fedBBBucks = try container.decodeIfPresent(Int.self, forKey: .fedBBBucks) ?? 0
        if let decodedFeedings = try container.decodeIfPresent([YesterdayBuddyFeeding].self, forKey: .feedings) {
            feedings = decodedFeedings
        } else if let fedCompanionID, fedBBBucks > 0 {
            feedings = [
                YesterdayBuddyFeeding(
                    companionID: fedCompanionID,
                    servings: fedBBBucks,
                    spentBBBucks: fedBBBucks,
                    bonusServings: 0
                )
            ]
        } else {
            feedings = []
        }
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }
}

struct YesterdayBuddyFeeding: Identifiable, Codable, Equatable {
    var id: String { companionID }
    var companionID: String
    var servings: Int
    var spentBBBucks: Int
    var bonusServings: Int
}

struct CompanionVisitContext {
    let reportKey: String
    let feedingCount: Int
    let diaperCount: Int
    let sleepMinutes: Int
    let earnedBBBucks: Int
    let activeHourCount: Int

    var affinityTags: Set<String> {
        var tags: Set<String> = []

        if feedingCount >= 2 {
            tags.insert("feeding")
        }
        if diaperCount >= 2 {
            tags.insert("diaper")
        }
        if sleepMinutes >= 60 {
            tags.insert("sleep")
        }
        if earnedBBBucks >= 5 || activeHourCount >= 4 {
            tags.insert("active")
        }
        if activeHourCount <= 2 {
            tags.insert("steady")
        }

        return tags
    }
}

@MainActor
final class CompanionRecruitmentStore: ObservableObject {
    static let shared = CompanionRecruitmentStore()
    static let currencyName = "BB Bucks"
    static let dailyEarnLimit = 5
    static let dailyBuddyFeedLimit = 1
    static let bonusFriendshipChance = 0.22

    static func currencyText(_ amount: Int) -> String {
        amount == 1 ? "1 BB Buck" : "\(amount) BB Bucks"
    }

    @Published private(set) var bbBucks: Int = 0 {
        didSet { persistIfLoaded() }
    }
    @Published private(set) var friendshipProgress: [String: Double] = [:] {
        didSet { persistIfLoaded() }
    }
    @Published private(set) var recruitedIDs: Set<String> = [] {
        didSet { persistIfLoaded() }
    }
    @Published private(set) var reports: [YesterdayReport] = [] {
        didSet { persistIfLoaded() }
    }
    @Published private(set) var dailyEarnings: [String: Int] = [:] {
        didSet { persistIfLoaded() }
    }
    @Published private(set) var awardedEasyCycleIDs: Set<UUID> = [] {
        didSet { persistIfLoaded() }
    }

    private let bbBucksKey = "companion_recruitment_bb_bucks_v1"
    private let friendshipKey = "companion_recruitment_friendship_v1"
    private let recruitedKey = "companion_recruitment_recruited_ids_v1"
    private let reportsKey = "companion_recruitment_yesterday_reports_v1"
    private let dailyEarningsKey = "companion_recruitment_daily_earnings_v1"
    private let awardedEasyCycleIDsKey = "companion_recruitment_awarded_easy_cycle_ids_v1"
    private var isLoading = false

    init() {
        isLoading = true
        load()
        isLoading = false
    }

    @discardableResult
    func awardBBBucks(forRecord action: BabyAction, recordedAt: Date) -> Bool {
        guard action == .nursing || action == .diaper || action == .sleep else { return false }
        let key = Self.dayKey(for: recordedAt)
        let earnedToday = dailyEarnings[key] ?? 0
        guard earnedToday < Self.dailyEarnLimit else { return false }
        dailyEarnings[key] = earnedToday + 1
        bbBucks += 1
        return true
    }

    @discardableResult
    func awardBBBucks(forEasyCycle cycleID: UUID, completedAt: Date) -> Bool {
        guard !awardedEasyCycleIDs.contains(cycleID) else { return false }
        let key = Self.dayKey(for: completedAt)
        let earnedToday = dailyEarnings[key] ?? 0
        guard earnedToday < Self.dailyEarnLimit else { return false }
        dailyEarnings[key] = earnedToday + 1
        awardedEasyCycleIDs.insert(cycleID)
        bbBucks += 1
        return true
    }

    func earnedBBBucks(on date: Date) -> Int {
        dailyEarnings[Self.dayKey(for: date)] ?? 0
    }

    func remainingEarnableBBBucks(on date: Date) -> Int {
        max(Self.dailyEarnLimit - earnedBBBucks(on: date), 0)
    }

    func report(for key: String) -> YesterdayReport? {
        reports.first { $0.reportKey == key }
    }

    func latestReport() -> YesterdayReport? {
        reports.sorted { $0.date > $1.date }.first
    }

    func storeReport(_ report: YesterdayReport) {
        if let index = reports.firstIndex(where: { $0.reportKey == report.reportKey }) {
            var merged = report
            merged.visitorCompanionIDs = reports[index].visitorIDs
            merged.fedCompanionID = reports[index].fedCompanionID
            merged.fedBBBucks = reports[index].fedBBBucks
            merged.feedings = reports[index].feedings
            reports[index] = merged
        } else {
            reports.append(report)
        }
        reports.sort { $0.date > $1.date }
    }

    func markReportFed(_ report: YesterdayReport, companionID: String, spentBucks: Int) {
        guard let index = reports.firstIndex(where: { $0.reportKey == report.reportKey }) else { return }
        var updated = reports[index]
        updated.fedCompanionID = companionID
        updated.fedBBBucks = spentBucks
        reports[index] = updated
    }

    func markReportFeeding(_ report: YesterdayReport, companionID: String, spentBucks: Int, bonusServings: Int) {
        guard let index = reports.firstIndex(where: { $0.reportKey == report.reportKey }) else { return }
        var updated = reports[index]
        if let feedingIndex = updated.feedings.firstIndex(where: { $0.companionID == companionID }) {
            updated.feedings[feedingIndex].servings += 1
            updated.feedings[feedingIndex].spentBBBucks += spentBucks
            updated.feedings[feedingIndex].bonusServings += bonusServings
        } else {
            updated.feedings.append(YesterdayBuddyFeeding(
                companionID: companionID,
                servings: 1,
                spentBBBucks: spentBucks,
                bonusServings: bonusServings
            ))
        }
        updated.fedCompanionID = updated.feedings.last?.companionID
        updated.fedBBBucks = updated.feedings.reduce(0) { $0 + $1.spentBBBucks }
        reports[index] = updated
    }

    func visitorCompanion(for reportKey: String) -> BabyCompanion {
        visitorCompanions(for: reportKey).first ?? BabyCompanion.all[0]
    }

    func visitorCompanions(for reportKey: String, context: CompanionVisitContext? = nil, limit: Int? = nil) -> [BabyCompanion] {
        var candidates = lockedRecruitmentCandidates()
        if candidates.isEmpty {
            candidates = BabyCompanion.all
        }

        let targetLimit = limit ?? CompanionRecruitmentStore.dailyBuddyFeedLimit
        var selected: [BabyCompanion] = []
        var remaining = candidates
        let recentIDs = recentVisitorIDs(excluding: reportKey)
        var seed = deterministicSeed(for: "\(reportKey)-visitors-v2")

        if let followUp = weightedFollowUpCompanion(in: remaining, reportKey: reportKey, context: context, recentIDs: recentIDs, seed: seed) {
            selected.append(followUp)
            remaining.removeAll { $0.id == followUp.id }
            seed = nextSeed(seed)
        }

        while !remaining.isEmpty && selected.count < targetLimit {
            let index = weightedIndex(in: remaining, seed: seed) { companion in
                visitWeight(for: companion, context: context, recentIDs: recentIDs)
            }
            selected.append(remaining.remove(at: index))
            seed = nextSeed(seed)
        }
        return selected
    }

    func lockedVisitorCompanion(for reportKey: String) -> BabyCompanion? {
        lockedVisitorCompanions(for: reportKey).first
    }

    func lockedVisitorCompanions(for reportKey: String, limit: Int? = nil) -> [BabyCompanion] {
        let candidates = lockedRecruitmentCandidates()
        guard !candidates.isEmpty else { return [] }

        let targetLimit = limit ?? CompanionRecruitmentStore.dailyBuddyFeedLimit
        var selected: [BabyCompanion] = []
        var remaining = candidates
        let recentIDs = recentVisitorIDs(excluding: reportKey)
        var seed = deterministicSeed(for: "\(reportKey)-locked-visitors-v2")
        while !remaining.isEmpty && selected.count < targetLimit {
            let index = weightedIndex(in: remaining, seed: seed) { companion in
                visitWeight(for: companion, context: nil, recentIDs: recentIDs)
            }
            selected.append(remaining.remove(at: index))
            seed = nextSeed(seed)
        }
        return selected
    }

    func isRecruited(_ companionID: String) -> Bool {
        recruitedIDs.contains(companionID)
    }

    func isUnlocked(_ companion: BabyCompanion, selectedID: String, temperamentAnimalID: String?) -> Bool {
        guard !BabyCompanion.previewLockedIDs.contains(BabyCompanion.canonicalID(companion.id)) else {
            return false
        }
        return companion.isUnlocked(selectedID: selectedID, temperamentAnimalID: temperamentAnimalID) || isRecruited(companion.id)
    }

    func friendshipPercent(for companionID: String) -> Double {
        min(max(friendshipProgress[companionID] ?? 0, 0), 1)
    }

    func feeding(for companionID: String, in report: YesterdayReport) -> YesterdayBuddyFeeding? {
        let currentReport = self.report(for: report.reportKey) ?? report
        return currentReport.feedings.first { $0.companionID == companionID }
    }

    func servingsFed(to companionID: String, in report: YesterdayReport) -> Int {
        feeding(for: companionID, in: report)?.servings ?? 0
    }

    func remainingServings(for companionID: String, in report: YesterdayReport) -> Int {
        let companion = BabyCompanion.companion(for: companionID)
        return max(companion.dailyServingLimit - servingsFed(to: companionID, in: report), 0)
    }

    func fedBuddyCount(in report: YesterdayReport) -> Int {
        let currentReport = self.report(for: report.reportKey) ?? report
        return currentReport.feedings.filter { $0.servings > 0 }.count
    }

    func remainingFeedBuddySlots(in report: YesterdayReport) -> Int {
        max(Self.dailyBuddyFeedLimit - fedBuddyCount(in: report), 0)
    }

    func canFeed(companionID: String, from report: YesterdayReport) -> Bool {
        let currentReport = self.report(for: report.reportKey) ?? report
        let hasFedCompanion = currentReport.feedings.contains { $0.companionID == companionID && $0.servings > 0 }
        return currentReport.visitorIDs.contains(companionID)
            && bbBucks > 0
            && remainingServings(for: companionID, in: currentReport) > 0
            && (hasFedCompanion || remainingFeedBuddySlots(in: currentReport) > 0)
    }

    func feedButtonTitle(for companionID: String, in report: YesterdayReport) -> String {
        let currentReport = self.report(for: report.reportKey) ?? report
        guard bbBucks > 0 else { return "暂无 BB Bucks" }
        if remainingServings(for: companionID, in: currentReport) <= 0 {
            return "\(BabyCompanion.companion(for: companionID).chineseName)吃饱啦"
        }
        if !(currentReport.feedings.contains { $0.companionID == companionID && $0.servings > 0 }),
           remainingFeedBuddySlots(in: currentReport) <= 0 {
            return "今日照顾满了"
        }
        return "喂 1 份"
    }

    func feedableBBBucks(for report: YesterdayReport) -> Int {
        let currentReport = self.report(for: report.reportKey) ?? report
        return min(bbBucks, currentReport.visitorIDs.reduce(0) { total, companionID in
            total + remainingServings(for: companionID, in: currentReport)
        })
    }

    @discardableResult
    func feedVisitor(companionID: String, from report: YesterdayReport) -> CompanionFeedingResult? {
        if self.report(for: report.reportKey) == nil {
            storeReport(report)
        }

        let currentReport = self.report(for: report.reportKey) ?? report
        guard canFeed(companionID: companionID, from: currentReport) else { return nil }

        let companion = BabyCompanion.companion(for: companionID)
        let spend = 1
        bbBucks -= 1
        let isBonus = bonusTriggered(reportKey: currentReport.reportKey, companionID: companionID, servingIndex: servingsFed(to: companionID, in: currentReport) + 1)
        let friendshipServings = isBonus ? 3 : 1
        let current = friendshipPercent(for: companion.id)
        let increment = Double(friendshipServings) / Double(max(companion.friendshipTarget, 1))
        let next = min(current + increment, 1)
        friendshipProgress[companion.id] = next
        if next >= 1 {
            recruitedIDs.insert(companion.id)
        }
        markReportFeeding(currentReport, companionID: companion.id, spentBucks: spend, bonusServings: isBonus ? 2 : 0)
        return CompanionFeedingResult(
            companionID: companion.id,
            spentBucks: spend,
            friendshipServings: friendshipServings,
            progress: next,
            didRecruit: next >= 1,
            isBonus: isBonus
        )
    }

    private func load() {
        let defaults = UserDefaults.standard
        bbBucks = defaults.integer(forKey: bbBucksKey)
        if let data = defaults.data(forKey: friendshipKey),
           let decoded = try? JSONDecoder().decode([String: Double].self, from: data) {
            friendshipProgress = decoded
        }
        if let data = defaults.data(forKey: recruitedKey),
           let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) {
            recruitedIDs = decoded
        }
        if let data = defaults.data(forKey: reportsKey),
           let decoded = try? JSONDecoder().decode([YesterdayReport].self, from: data) {
            reports = decoded.sorted { $0.date > $1.date }
        }
        if let data = defaults.data(forKey: dailyEarningsKey),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
            dailyEarnings = decoded
        }
        if let data = defaults.data(forKey: awardedEasyCycleIDsKey),
           let decoded = try? JSONDecoder().decode(Set<UUID>.self, from: data) {
            awardedEasyCycleIDs = decoded
        }
    }

    private func persistIfLoaded() {
        guard !isLoading else { return }
        persist()
    }

    private func persist() {
        let defaults = UserDefaults.standard
        defaults.set(bbBucks, forKey: bbBucksKey)
        if let data = try? JSONEncoder().encode(friendshipProgress) {
            defaults.set(data, forKey: friendshipKey)
        }
        if let data = try? JSONEncoder().encode(recruitedIDs) {
            defaults.set(data, forKey: recruitedKey)
        }
        if let data = try? JSONEncoder().encode(reports) {
            defaults.set(data, forKey: reportsKey)
        }
        if let data = try? JSONEncoder().encode(dailyEarnings) {
            defaults.set(data, forKey: dailyEarningsKey)
        }
        if let data = try? JSONEncoder().encode(awardedEasyCycleIDs) {
            defaults.set(data, forKey: awardedEasyCycleIDsKey)
        }
    }

    private func lockedRecruitmentCandidates() -> [BabyCompanion] {
        guard !AppVariant.unlocksAllBuddiesForLocalRun else { return [] }

        return BabyCompanion.all.filter { companion in
            !isRecruited(companion.id) && !BabyCompanion.defaultUnlockedIDs.contains(companion.id)
        }
    }

    private func recentVisitorIDs(excluding reportKey: String, lookbackCount: Int = 3) -> Set<String> {
        let recentReports = reports
            .filter { $0.reportKey != reportKey }
            .sorted { $0.date > $1.date }
            .prefix(lookbackCount)

        return Set(recentReports.flatMap(\.visitorIDs))
    }

    private static func dayKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func deterministicSeed(for key: String) -> Int {
        let raw = key.unicodeScalars.reduce(17) { seed, scalar in
            seed &* 31 &+ Int(scalar.value) &+ 7
        }
        return raw & 0x7fffffff
    }

    private func nextSeed(_ seed: Int) -> Int {
        abs((seed &* 1_103_515_245 &+ 12_345) & 0x7fffffff)
    }

    private func weightedIndex(in companions: [BabyCompanion], seed: Int, weight: (BabyCompanion) -> Double) -> Int {
        let totalWeight = companions.reduce(0) { $0 + max(weight($1), 0.01) }
        let ticket = (Double(seed % 10_000) / 10_000.0) * totalWeight
        var cursor = 0.0
        for (index, companion) in companions.enumerated() {
            cursor += max(weight(companion), 0.01)
            if ticket <= cursor {
                return index
            }
        }
        return max(companions.count - 1, 0)
    }

    private func weightedFollowUpCompanion(
        in companions: [BabyCompanion],
        reportKey: String,
        context: CompanionVisitContext?,
        recentIDs: Set<String>,
        seed: Int
    ) -> BabyCompanion? {
        let followUpCandidates = companions.filter {
            let progress = friendshipPercent(for: $0.id)
            return progress > 0 && progress < 1
        }
        guard !followUpCandidates.isEmpty else { return nil }

        let index = weightedIndex(in: followUpCandidates, seed: deterministicSeed(for: "\(reportKey)-follow-up-\(seed)")) { companion in
            let progress = friendshipPercent(for: companion.id)
            return visitWeight(for: companion, context: context, recentIDs: recentIDs) * (1.5 + progress)
        }
        return followUpCandidates[index]
    }

    private func visitWeight(for companion: BabyCompanion, context: CompanionVisitContext?, recentIDs: Set<String>) -> Double {
        var weight = max(companion.rarity.visitWeight, 0.01)
        let progress = friendshipPercent(for: companion.id)

        if progress > 0 {
            weight *= 1.35 + progress * 1.25
        }

        if recentIDs.contains(companion.id) {
            weight *= progress >= 0.65 ? 0.70 : 0.34
        }

        if let context {
            let matchedTags = companion.visitAffinityTags.intersection(context.affinityTags).count
            if matchedTags > 0 {
                weight *= 1.0 + Double(matchedTags) * 0.16
            }

            if context.earnedBBBucks == 0 {
                weight *= 0.82
            } else if context.earnedBBBucks >= Self.dailyEarnLimit {
                weight *= companion.rarity == .rare || companion.rarity == .precious ? 1.18 : 1.04
            }
        }

        return weight
    }

    private func bonusTriggered(reportKey: String, companionID: String, servingIndex: Int) -> Bool {
        let seed = deterministicSeed(for: "\(reportKey)-\(companionID)-\(servingIndex)-snack")
        let roll = Double(seed % 10_000) / 10_000.0
        return roll < Self.bonusFriendshipChance
    }
}

struct CompanionFeedingResult {
    let companionID: String
    let spentBucks: Int
    let friendshipServings: Int
    let progress: Double
    let didRecruit: Bool
    let isBonus: Bool
}

// MARK: - Tabs

enum RootTab: Int, CaseIterable {
    case record
    case companion
    case growth

    var title: String {
        switch self {
        case .record: return "记录"
        case .companion: return "陪伴"
        case .growth: return "成长"
        }
    }

    var icon: String {
        switch self {
        case .record: return "book.fill"
        case .companion: return "heart.fill"
        case .growth: return "trophy.fill"
        }
    }

    var assetIconName: String {
        switch self {
        case .record: return "nav_record_icon"
        case .companion: return "nav_companion_icon"
        case .growth: return "nav_growth_icon"
        }
    }
}

// MARK: - Actions

enum BabyAction: String, CaseIterable, Identifiable, Codable {
    case idle
    case shake
    case pet
    case poke
    case listen
    case nursing
    case diaper
    case breastfeed
    case sleep

    var id: String { rawValue }

    var title: String {
        switch self {
        case .idle: return "待机"
        case .shake: return "摇一摇"
        case .pet: return "抚摸"
        case .poke: return "戳一戳"
        case .listen: return "听"
        case .nursing: return "记录喂养"
        case .diaper: return "记录尿布"
        case .breastfeed: return "记录吸乳"
        case .sleep: return "记录睡眠"
        }
    }

    var emojiIcon: String {
        switch self {
        case .idle: return "💤"
        case .shake: return "🫨"
        case .pet: return "🤲"
        case .poke: return "👉"
        case .listen: return "👂"
        case .nursing: return "🍼"
        case .diaper: return "🧷"
        case .breastfeed: return "∞"
        case .sleep: return "🌙"
        }
    }

    var systemImage: String {
        switch self {
        case .idle: return "sparkles"
        case .shake: return "iphone.radiowaves.left.and.right"
        case .pet: return "hand.draw.fill"
        case .poke: return "hand.tap.fill"
        case .listen: return "mic.fill"
        case .nursing: return "babybottle.fill"
        case .diaper: return "drop.fill"
        case .breastfeed: return "infinity"
        case .sleep: return "moon.fill"
        }
    }

    var duration: TimeInterval {
        switch self {
        case .idle: return 0
        case .shake: return 2.5
        case .pet: return 2.0
        case .poke: return 1.5
        case .listen: return 3.0
        case .nursing, .diaper, .breastfeed, .sleep: return 1.8
        }
    }

    var isBasicInteraction: Bool {
        switch self {
        case .shake, .pet, .poke, .listen: return true
        default: return false
        }
    }

    var isRecordable: Bool {
        switch self {
        case .nursing, .diaper, .breastfeed, .sleep: return true
        default: return false
        }
    }
}

struct ActivityLog: Identifiable, Codable {
    let id: UUID
    let action: BabyAction
    let timestamp: Date

    init(id: UUID = UUID(), action: BabyAction, timestamp: Date = Date()) {
        self.id = id
        self.action = action
        self.timestamp = timestamp
    }
}

// MARK: - Baby Profile

enum BabyGender: String, Codable, CaseIterable, Identifiable {
    case boy = "Boy"
    case girl = "Girl"

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .boy: return "👦🏻"
        case .girl: return "👧🏻"
        }
    }
}

struct WidgetBabyInfo: Codable {
    var name: String
    var birthDate: Date

    func ageMonths(asOf date: Date = Date()) -> Int {
        max(Calendar.current.dateComponents([.month], from: birthDate, to: date).month ?? 0, 0)
    }
}

enum WidgetStorageKey {
    static let appGroupID = "group.73AUQDMCJ2.babybuddy"
    static let feedingSessions = "feeding_sessions"
    static let careRecords = "care_records_v1"
    static let babyInfo = "baby_info"
    static let lastFeedingWidgetKind = "v.babybuddy.LastFeeding"
}

enum BabyAvatarSourceKind: String, Codable, Hashable {
    case emoji
    case photo
    case companion
    case video
}

struct BabyAvatarSnapshot: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var sourceKind: BabyAvatarSourceKind
    var emoji: String?
    var imageData: Data?
    var companionID: String?
    var videoFilename: String?
    var createdAt: Date = Date()
}

struct BabyProfileData: Codable {
    var name: String
    var gender: BabyGender
    var birthDate: Date
    var heightCm: Double? = nil
    var weightKg: Double? = nil
    var avatarEmoji: String?
    var avatarImageData: Data?
    var avatarCompanionID: String? = nil
    var avatarVideoFilename: String? = nil
    var avatarHistory: [BabyAvatarSnapshot]? = nil
    var avatarMotionEnabled: Bool? = nil

    var displayAvatar: String {
        avatarEmoji ?? gender.emoji
    }

    var avatarSourceKind: BabyAvatarSourceKind {
        if avatarVideoFilename != nil {
            return .video
        }
        if avatarImageData != nil {
            return .photo
        }
        if avatarCompanionID != nil {
            return .companion
        }
        return .emoji
    }

    var avatarHistoryItems: [BabyAvatarSnapshot] {
        avatarHistory ?? []
    }

    var isAvatarMotionEnabled: Bool {
        avatarMotionEnabled ?? true
    }

    var avatarSnapshot: BabyAvatarSnapshot {
        BabyAvatarSnapshot(
            sourceKind: avatarSourceKind,
            emoji: avatarEmoji,
            imageData: avatarImageData,
            companionID: avatarCompanionID,
            videoFilename: avatarVideoFilename,
            createdAt: Date()
        )
    }

    var ageMonths: Int {
        max(Calendar.current.dateComponents([.month], from: birthDate, to: Date()).month ?? 0, 0)
    }

    var ageDays: Int {
        max(Calendar.current.dateComponents([.day], from: birthDate, to: Date()).day ?? 0, 0)
    }

    var ageDisplayText: String {
        if ageDays < 60 {
            return "\(ageDays) days"
        }
        let months = ageDays / 30
        let days = ageDays % 30
        return "\(months)m, \(days)d"
    }

    func widgetInfo() -> WidgetBabyInfo {
        WidgetBabyInfo(name: name, birthDate: birthDate)
    }
}

extension BabyAvatarSnapshot {
    var isRenderable: Bool {
        switch sourceKind {
        case .photo:
            return imageData != nil
        case .companion:
            return companionID != nil
        case .video:
            return videoFilename != nil
        case .emoji:
            return emoji != nil
        }
    }

    func isSameAvatar(as other: BabyAvatarSnapshot) -> Bool {
        sourceKind == other.sourceKind
            && emoji == other.emoji
            && imageData == other.imageData
            && companionID == other.companionID
            && videoFilename == other.videoFilename
    }
}

struct BabyProfileAvatarView: View {
    let profile: BabyProfileData
    var size: CGFloat
    var emojiSize: CGFloat
    var lineWidth: CGFloat = 1.5
    var motionScale: CGFloat = 1

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        BabyAvatarContentView(
            sourceKind: profile.avatarSourceKind,
            emoji: profile.displayAvatar,
            imageData: profile.avatarImageData,
            companionID: profile.avatarCompanionID,
            videoFilename: profile.avatarVideoFilename,
            size: size,
            emojiSize: emojiSize,
            lineWidth: lineWidth,
            motionEnabled: profile.isAvatarMotionEnabled && !reduceMotion,
            motionScale: motionScale
        )
    }
}

struct BabyAvatarSnapshotView: View {
    let snapshot: BabyAvatarSnapshot
    let fallbackEmoji: String
    var size: CGFloat
    var emojiSize: CGFloat
    var isSelected: Bool = false

    var body: some View {
        BabyAvatarContentView(
            sourceKind: snapshot.sourceKind,
            emoji: snapshot.emoji ?? fallbackEmoji,
            imageData: snapshot.imageData,
            companionID: snapshot.companionID,
            videoFilename: snapshot.videoFilename,
            size: size,
            emojiSize: emojiSize,
            lineWidth: isSelected ? 2.5 : 1.2,
            motionEnabled: true,
            motionScale: 0.8
        )
    }
}

private struct BabyAvatarContentView: View {
    let sourceKind: BabyAvatarSourceKind
    let emoji: String
    let imageData: Data?
    let companionID: String?
    let videoFilename: String?
    let size: CGFloat
    let emojiSize: CGFloat
    let lineWidth: CGFloat
    let motionEnabled: Bool
    let motionScale: CGFloat

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { context in
            let phase = motionEnabled
                ? avatarPhase(at: context.date)
                : (offset: CGFloat.zero, rotation: 0.0, scale: CGFloat.zero)

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.98),
                                DesignToken.primary.opacity(0.16),
                                DesignToken.accentBlue.opacity(0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color(hex: "#4D4B70").opacity(size > 52 ? 0.10 : 0.05), radius: size > 52 ? 12 : 5, y: size > 52 ? 6 : 2)

                avatarImage
                    .scaleEffect(1 + phase.scale)
                    .rotationEffect(.degrees(phase.rotation))
                    .offset(y: phase.offset)
                    .animation(nil, value: phase.offset)
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.95),
                                DesignToken.primary.opacity(0.70)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: lineWidth
                    )
            )
            .contentShape(Circle())
        }
        .frame(width: size, height: size)
    }

    @ViewBuilder
    private var avatarImage: some View {
        switch sourceKind {
        case .photo:
            if let imageData,
               let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Text(emoji).font(.system(size: emojiSize))
            }
        case .companion:
            if let companionID {
                Image(BabyCompanion.companion(for: companionID).portraitAssetName)
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.09)
            } else {
                Text(emoji).font(.system(size: emojiSize))
            }
        case .emoji:
            Text(emoji)
                .font(.system(size: emojiSize))
        case .video:
            if let videoFilename,
               let url = BabyAvatarVideoStore.url(for: videoFilename) {
                LoopingAvatarVideoView(url: url)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Text(emoji)
                    .font(.system(size: emojiSize))
            }
        }
    }

    private func avatarPhase(at date: Date) -> (offset: CGFloat, rotation: Double, scale: CGFloat) {
        let elapsed = date.timeIntervalSinceReferenceDate
        let wave = sin(elapsed * 2.4)
        let secondary = sin(elapsed * 1.25 + 0.7)
        return (
            offset: CGFloat(wave) * 1.3 * motionScale,
            rotation: secondary * 1.8 * Double(motionScale),
            scale: CGFloat((wave + 1) * 0.006) * motionScale
        )
    }
}

enum BabyAvatarVideoStore {
    private static let directoryName = "BabyAvatarVideos"

    static func saveVideo(from temporaryURL: URL) throws -> String {
        let filename = "avatar-\(UUID().uuidString).mov"
        let destination = try directoryURL().appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: temporaryURL, to: destination)
        return filename
    }

    static func url(for filename: String) -> URL? {
        guard let directory = try? directoryURL() else { return nil }
        let url = directory.appendingPathComponent(filename)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private static func directoryURL() throws -> URL {
        let base = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appendingPathComponent(directoryName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }
}

private struct LoopingAvatarVideoView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.configure(url: url)
        return view
    }

    func updateUIView(_ uiView: PlayerView, context: Context) {
        uiView.configure(url: url)
    }

    final class PlayerView: UIView {
        private var playerLayer = AVPlayerLayer()
        private var player: AVQueuePlayer?
        private var looper: AVPlayerLooper?
        private var currentURL: URL?

        override init(frame: CGRect) {
            super.init(frame: frame)
            playerLayer.videoGravity = .resizeAspectFill
            layer.addSublayer(playerLayer)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            playerLayer.frame = bounds
        }

        func configure(url: URL) {
            guard currentURL != url else { return }
            currentURL = url

            let item = AVPlayerItem(url: url)
            let queuePlayer = AVQueuePlayer()
            queuePlayer.isMuted = true
            queuePlayer.actionAtItemEnd = .none
            playerLayer.player = queuePlayer
            looper = AVPlayerLooper(player: queuePlayer, templateItem: item)
            player = queuePlayer
            queuePlayer.play()
        }
    }
}

struct BabyProfile: Codable {
    var name: String
    var gender: String
    var birthDate: Date

    var ageDays: Int {
        max(Calendar.current.dateComponents([.day], from: birthDate, to: Date()).day ?? 0, 0)
    }

    var ageMonths: Int {
        max(Calendar.current.dateComponents([.month], from: birthDate, to: Date()).month ?? 0, 0)
    }

    var data: BabyProfileData {
        BabyProfileData(
            name: name,
            gender: gender == BabyGender.girl.rawValue ? .girl : .boy,
            birthDate: birthDate,
            heightCm: nil,
            weightKg: nil,
            avatarEmoji: nil,
            avatarImageData: nil
        )
    }
}

@MainActor
final class BabyProfileStore: Observable {
    static let shared = BabyProfileStore()

    var profile: BabyProfileData? {
        get {
            access(keyPath: \.profile)
            return _profile
        }
        set {
            withMutation(keyPath: \.profile) {
                _profile = newValue
                save()
            }
        }
    }

    private let _$observationRegistrar = ObservationRegistrar()
    private var _profile: BabyProfileData?
    private let key = "baby_profile"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode(BabyProfileData.self, from: data) {
            _profile = decoded
        } else if let data = UserDefaults.standard.data(forKey: key),
                  let decoded = try? JSONDecoder().decode(BabyProfile.self, from: data) {
            _profile = decoded.data
        } else {
            _profile = Self.defaultProfile
        }
        save()
    }

    nonisolated func access<Member>(keyPath: KeyPath<BabyProfileStore, Member>) {
        _$observationRegistrar.access(self, keyPath: keyPath)
    }

    nonisolated func withMutation<Member, MutationResult>(
        keyPath: KeyPath<BabyProfileStore, Member>,
        _ mutation: () throws -> MutationResult
    ) rethrows -> MutationResult {
        try _$observationRegistrar.withMutation(of: self, keyPath: keyPath, mutation)
    }

    var currentProfile: BabyProfileData {
        profile ?? Self.defaultProfile
    }

    private func save() {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: key)
        }
        syncToAppGroup(currentProfile)
        FamilyCloudStore.shared.scheduleUpload(reason: "profile")
    }

    func updateName(_ name: String) {
        var updated = currentProfile
        updated.name = name
        profile = updated
    }

    func updateGender(_ gender: BabyGender) {
        var updated = currentProfile
        updated.gender = gender
        profile = updated
    }

    func updateBirthDate(_ birthDate: Date) {
        var updated = currentProfile
        updated.birthDate = birthDate
        profile = updated
    }

    func updateBodyMetrics(heightCm: Double?, weightKg: Double?) {
        var updated = currentProfile
        updated.heightCm = heightCm
        updated.weightKg = weightKg
        profile = updated
    }

    func updateAvatar(_ avatarEmoji: String?) {
        var updated = currentProfile
        updated.rememberCurrentAvatar()
        updated.avatarEmoji = avatarEmoji
        updated.avatarImageData = nil
        updated.avatarCompanionID = nil
        updated.avatarVideoFilename = nil
        profile = updated
    }

    func updateAvatarImageData(_ imageData: Data?) {
        var updated = currentProfile
        updated.rememberCurrentAvatar()
        updated.avatarImageData = imageData
        if imageData != nil {
            updated.avatarEmoji = nil
            updated.avatarCompanionID = nil
            updated.avatarVideoFilename = nil
        }
        profile = updated
    }

    func updateAvatarCompanion(_ companionID: String?) {
        var updated = currentProfile
        updated.rememberCurrentAvatar()
        updated.avatarCompanionID = companionID
        if companionID != nil {
            updated.avatarEmoji = nil
            updated.avatarImageData = nil
            updated.avatarVideoFilename = nil
        }
        profile = updated
    }

    func updateAvatarVideo(filename: String?) {
        var updated = currentProfile
        updated.rememberCurrentAvatar()
        updated.avatarVideoFilename = filename
        if filename != nil {
            updated.avatarEmoji = nil
            updated.avatarImageData = nil
            updated.avatarCompanionID = nil
        }
        profile = updated
    }

    func create(
        name: String,
        gender: BabyGender,
        birthDate: Date,
        heightCm: Double? = nil,
        weightKg: Double? = nil,
        avatarEmoji: String? = nil,
        avatarImageData: Data? = nil,
        avatarCompanionID: String? = nil,
        avatarVideoFilename: String? = nil,
        avatarHistory: [BabyAvatarSnapshot]? = nil,
        avatarMotionEnabled: Bool? = nil
    ) {
        profile = BabyProfileData(
            name: name,
            gender: gender,
            birthDate: birthDate,
            heightCm: heightCm,
            weightKg: weightKg,
            avatarEmoji: avatarEmoji,
            avatarImageData: avatarImageData,
            avatarCompanionID: avatarCompanionID,
            avatarVideoFilename: avatarVideoFilename,
            avatarHistory: avatarHistory?.prefix(8).map { $0 },
            avatarMotionEnabled: avatarMotionEnabled
        )
    }

    func importProfile(_ profileData: BabyProfileData) {
        profile = profileData
    }

    var isOnboarded: Bool {
        guard let profile else { return false }
        return !profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func syncToAppGroup(_ profileData: BabyProfileData) {
        guard let defaults = UserDefaults(suiteName: WidgetStorageKey.appGroupID),
              let data = try? JSONEncoder().encode(profileData.widgetInfo()) else {
            return
        }
        defaults.set(data, forKey: WidgetStorageKey.babyInfo)
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetStorageKey.lastFeedingWidgetKind)
        #endif
        let ageMonths = profileData.ageMonths
        if let last = FeedingStore.sharedLastFeedingTime() {
            Task { @MainActor in
                LiveActivityManager.shared.startOrUpdate(lastFeedingDate: last, babyAgeMonths: ageMonths)
            }
        }
    }

    private static var defaultProfile: BabyProfileData {
        BabyProfileData(
            name: "33",
            gender: .boy,
            birthDate: Calendar.current.date(byAdding: .day, value: -22, to: Date()) ?? Date(),
            heightCm: nil,
            weightKg: nil,
            avatarEmoji: nil,
            avatarImageData: nil
        )
    }
}

private extension BabyProfileData {
    mutating func rememberCurrentAvatar() {
        let snapshot = avatarSnapshot
        guard snapshot.isRenderable else { return }

        var items = avatarHistoryItems.filter { !$0.isSameAvatar(as: snapshot) }
        items.insert(snapshot, at: 0)
        avatarHistory = Array(items.prefix(8))
    }
}

// MARK: - Temperament

enum TemperamentDimension: String, Codable, CaseIterable, Identifiable {
    case activityLevel = "activity_level"
    case regularity
    case approach
    case adaptability
    case intensity
    case mood
    case attentionPersistence = "attention_persistence"
    case distractibility
    case sensorySensitivity = "sensory_sensitivity"

    var id: String { rawValue }
}

enum TemperamentType: String, Codable, CaseIterable, Identifiable {
    case easy
    case intermediate
    case slowToWarmUp = "slow_to_warm_up"
    case highSensitivity = "high_sensitivity"

    var id: String { rawValue }
}

struct BabyTemperamentResult: Codable, Hashable {
    var animalID: String
    var type: TemperamentType
    var scores: [TemperamentDimension: Double]
    var completedAt: Date
}

@MainActor
final class TemperamentProfileStore: ObservableObject {
    @Published private(set) var result: BabyTemperamentResult? {
        didSet {
            save()
            FamilyCloudStore.shared.scheduleUpload(reason: "temperament")
        }
    }

    private let key = "baby_temperament_result"

    init() {
        guard
            let data = UserDefaults.standard.data(forKey: key),
            let decoded = try? JSONDecoder().decode(BabyTemperamentResult.self, from: data)
        else { return }
        result = decoded
    }

    func update(_ result: BabyTemperamentResult) {
        self.result = result
    }

    func exportResult() -> BabyTemperamentResult? {
        result
    }

    func importResult(_ result: BabyTemperamentResult?) {
        self.result = result
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(result) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

// MARK: - Feeding

enum FeedingType: String, Codable, CaseIterable {
    case breast
    case bottle
    case solid

    var displayName: String {
        switch self {
        case .breast: return "母乳（亲喂）"
        case .bottle: return "奶粉（瓶喂）"
        case .solid: return "辅食"
        }
    }

    /// 根据瓶喂中的母乳/奶粉区分显示名
    func displayName(withMilkType milkType: MilkType?) -> String {
        switch self {
        case .breast: return "母乳（亲喂）"
        case .bottle:
            if milkType == .expressed { return "母乳（瓶喂）" }
            return "奶粉（瓶喂）"
        case .solid: return "辅食"
        }
    }

    var accent: Color {
        switch self {
        case .bottle: return DesignToken.feedingBottle
        case .breast: return DesignToken.feedingBreast
        case .solid: return DesignToken.feedingSolid
        }
    }
}

enum MilkType: String, Codable, CaseIterable, Identifiable {
    case expressed
    case formula

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .expressed: return "母乳"
        case .formula: return "奶粉"
        }
    }
}

enum BabyMood: String, Codable, CaseIterable {
    case happy = "😊"
    case neutral = "😐"
    case sad = "☹️"
}

enum BreastSide: String, Codable, CaseIterable, Identifiable {
    case left
    case right

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .left: return "左"
        case .right: return "右"
        }
    }
}

enum BreastFeedingMode: String, Codable, CaseIterable, Identifiable {
    case nursing
    case expressedBottle
    case pumping

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .nursing: return "亲喂"
        case .expressedBottle: return "瓶喂母乳"
        case .pumping: return "吸乳"
        }
    }

    var systemImage: String {
        switch self {
        case .nursing: return "heart.fill"
        case .expressedBottle: return "drop.fill"
        case .pumping: return "timer"
        }
    }
}

enum SolidUnit: String, Codable, CaseIterable, Identifiable {
    case g
    case oz
    case ml
    case mg
    case flOz = "fl_oz"
    case drop
    case piece
    case tsp
    case tbsp

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .g: return "g"
        case .oz: return "oz"
        case .ml: return "ml"
        case .mg: return "mg"
        case .flOz: return "fl oz"
        case .drop: return "滴"
        case .piece: return "块"
        case .tsp: return "小勺"
        case .tbsp: return "大勺"
        }
    }
}

enum SolidFood: String, Codable, CaseIterable, Identifiable {
    case rice
    case porridge
    case vegetable
    case fruit
    case meat
    case fish
    case egg
    case noodle
    case bread
    case yogurt
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .rice: return "米糊"
        case .porridge: return "粥"
        case .vegetable: return "蔬菜"
        case .fruit: return "水果"
        case .meat: return "肉类"
        case .fish: return "鱼肉"
        case .egg: return "鸡蛋"
        case .noodle: return "面条"
        case .bread: return "面包"
        case .yogurt: return "酸奶"
        case .other: return "其他"
        }
    }

    var emoji: String {
        switch self {
        case .rice: return "🍚"
        case .porridge: return "🥣"
        case .vegetable: return "🥬"
        case .fruit: return "🍎"
        case .meat: return "🥩"
        case .fish: return "🐟"
        case .egg: return "🥚"
        case .noodle: return "🍜"
        case .bread: return "🍞"
        case .yogurt: return "🥛"
        case .other: return "🍽️"
        }
    }

    var suggestedUnit: SolidUnit {
        switch self {
        case .yogurt: return .ml
        default: return .g
        }
    }
}

struct FeedingEntry: Identifiable, Codable {
    let id: UUID
    var type: FeedingType
    var breastMode: BreastFeedingMode?
    var breastSide: BreastSide?
    var breastDuration: Int?
    var milkType: MilkType?
    var bottleAmount: Int?
    var bottleDuration: Int?
    var solidFood: SolidFood?
    var solidAmount: Double?
    var solidUnit: SolidUnit?

    init(
        id: UUID = UUID(),
        type: FeedingType,
        breastMode: BreastFeedingMode? = nil,
        breastSide: BreastSide? = nil,
        breastDuration: Int? = nil,
        milkType: MilkType? = nil,
        bottleAmount: Int? = nil,
        bottleDuration: Int? = nil,
        solidFood: SolidFood? = nil,
        solidAmount: Double? = nil,
        solidUnit: SolidUnit? = nil
    ) {
        self.id = id
        self.type = type
        self.breastMode = breastMode
        self.breastSide = breastSide
        self.breastDuration = breastDuration
        self.milkType = milkType
        self.bottleAmount = bottleAmount
        self.bottleDuration = bottleDuration
        self.solidFood = solidFood
        self.solidAmount = solidAmount
        self.solidUnit = solidUnit
    }
}

enum FeedingTimeSpanSource: String, Codable {
    case confirmed
    case recordedDuration
    case estimated
    case estimatedSkipped
    case point

    var isEstimated: Bool {
        self == .estimated || self == .estimatedSkipped
    }
}

struct FeedingResolvedTimeSpan {
    let startAt: Date
    let endAt: Date
    let source: FeedingTimeSpanSource

    var isPoint: Bool {
        endAt <= startAt
    }

    var isEstimated: Bool {
        source.isEstimated
    }
}

struct FeedingSession: Identifiable, Codable {
    let id: UUID
    var entries: [FeedingEntry]
    var notes: String
    var imageData: Data?
    var babyMood: BabyMood
    var createdAt: Date
    var startAt: Date?
    var endAt: Date?
    var timeSpanSource: FeedingTimeSpanSource?

    init(
        id: UUID = UUID(),
        entries: [FeedingEntry],
        notes: String = "",
        imageData: Data? = nil,
        babyMood: BabyMood = .happy,
        createdAt: Date = Date(),
        startAt: Date? = nil,
        endAt: Date? = nil,
        timeSpanSource: FeedingTimeSpanSource? = nil
    ) {
        self.id = id
        self.entries = entries
        self.notes = notes
        self.imageData = imageData
        self.babyMood = babyMood
        self.createdAt = createdAt
        self.startAt = startAt
        self.endAt = endAt
        self.timeSpanSource = timeSpanSource
    }

    init(
        id: UUID = UUID(),
        type: FeedingType,
        amountML: Int? = nil,
        durationMin: Int? = nil,
        solidsKind: String? = nil,
        solidsGram: Int? = nil,
        mood: BabyMood = .happy,
        note: String = "",
        createdAt: Date = Date(),
        startAt: Date? = nil,
        endAt: Date? = nil,
        timeSpanSource: FeedingTimeSpanSource? = nil
    ) {
        let entry: FeedingEntry
        switch type {
        case .breast:
            entry = FeedingEntry(type: .breast, breastSide: .left, breastDuration: durationMin)
        case .bottle:
            entry = FeedingEntry(type: .bottle, milkType: .formula, bottleAmount: amountML)
        case .solid:
            let food = SolidFood.allCases.first { $0.displayName == solidsKind } ?? .rice
            entry = FeedingEntry(type: .solid, solidFood: food, solidAmount: solidsGram.map(Double.init), solidUnit: .g)
        }
        self.init(
            id: id,
            entries: [entry],
            notes: note,
            babyMood: mood,
            createdAt: createdAt,
            startAt: startAt,
            endAt: endAt,
            timeSpanSource: timeSpanSource
        )
    }

    var type: FeedingType {
        entries.first?.type ?? .bottle
    }

    /// 瓶喂时的奶类型（用于区分母乳瓶喂/奶粉瓶喂）
    var bottleMilkType: MilkType? {
        entries.first(where: { $0.type == .bottle })?.milkType
    }

    /// 区分母乳亲喂/母乳瓶喂/奶粉瓶喂的显示名
    var displayName: String {
        type.displayName(withMilkType: bottleMilkType)
    }

    var amountML: Int? {
        entries.compactMap(\.bottleAmount).first
    }

    var durationMin: Int? {
        entries.compactMap(\.breastDuration).first
    }

    var bottleDurationMin: Int? {
        entries.compactMap(\.bottleDuration).first
    }

    var solidsKind: String? {
        entries.compactMap { $0.solidFood?.displayName }.first
    }

    var solidsGram: Int? {
        entries.compactMap { $0.solidAmount.map(Int.init) }.first
    }

    var mood: BabyMood { babyMood }
    var note: String { notes }

    var totalBreastDuration: Int {
        entries.compactMap(\.breastDuration).reduce(0, +)
    }

    var totalBottleAmount: Int {
        entries.compactMap(\.bottleAmount).reduce(0, +)
    }

    var totalBottleDuration: Int {
        entries.compactMap(\.bottleDuration).reduce(0, +)
    }

    var totalSolidAmount: Double {
        entries.compactMap(\.solidAmount).reduce(0, +)
    }

    var hasData: Bool {
        entries.contains { entry in
            switch entry.type {
            case .breast:
                return (entry.breastDuration ?? 0) > 0
            case .bottle:
                return (entry.bottleAmount ?? 0) > 0
            case .solid:
                return (entry.solidAmount ?? 0) > 0
            }
        }
    }

    func resolvedTimeSpan(ageMonths: Int?) -> FeedingResolvedTimeSpan {
        let resolvedEnd = endAt ?? createdAt

        if let startAt, let endAt, startAt < endAt {
            return FeedingResolvedTimeSpan(
                startAt: startAt,
                endAt: endAt,
                source: timeSpanSource ?? .confirmed
            )
        }

        if recordedDurationMinutes > 0 {
            let start = resolvedEnd.addingTimeInterval(TimeInterval(-recordedDurationMinutes * 60))
            return FeedingResolvedTimeSpan(startAt: start, endAt: resolvedEnd, source: .recordedDuration)
        }

        if let estimatedMinutes = estimatedDurationMinutes(ageMonths: ageMonths), estimatedMinutes > 0 {
            let start = resolvedEnd.addingTimeInterval(TimeInterval(-estimatedMinutes * 60))
            return FeedingResolvedTimeSpan(
                startAt: start,
                endAt: resolvedEnd,
                source: timeSpanSource?.isEstimated == true ? timeSpanSource! : .estimated
            )
        }

        return FeedingResolvedTimeSpan(startAt: resolvedEnd, endAt: resolvedEnd, source: .point)
    }

    var recordedDurationMinutes: Int {
        totalBreastDuration + totalBottleDuration
    }

    func estimatedDurationMinutes(ageMonths: Int?) -> Int? {
        var estimated = 0

        for entry in entries {
            switch entry.type {
            case .breast:
                break
            case .bottle:
                guard let amount = entry.bottleAmount, amount > 0 else { break }
                let profile = Self.bottlePaceProfile(ageMonths: ageMonths)
                let rawMinutes = Int(ceil(Double(amount) / profile.mlPerMinute))
                estimated += min(max(rawMinutes, profile.minMinutes), profile.maxMinutes)
            case .solid:
                guard let amount = entry.solidAmount, amount > 0 else { break }
                let normalizedAmount = Self.normalizedSolidAmount(amount, unit: entry.solidUnit ?? .g)
                let rawMinutes = Int(ceil(normalizedAmount / 12.0))
                estimated += min(max(rawMinutes, 5), 20)
            }
        }

        return estimated > 0 ? min(estimated, 60) : nil
    }

    private static func bottlePaceProfile(ageMonths: Int?) -> (mlPerMinute: Double, minMinutes: Int, maxMinutes: Int) {
        let months = max(ageMonths ?? 3, 0)
        switch months {
        case 0:
            return (4, 8, 30)
        case 1..<3:
            return (6, 6, 25)
        case 3..<6:
            return (8, 5, 20)
        case 6..<12:
            return (10, 5, 18)
        default:
            return (12, 4, 15)
        }
    }

    private static func normalizedSolidAmount(_ amount: Double, unit: SolidUnit) -> Double {
        switch unit {
        case .g, .ml:
            return amount
        case .mg:
            return amount / 1000
        case .oz, .flOz:
            return amount * 30
        case .drop:
            return amount * 0.05
        case .piece:
            return amount * 10
        case .tsp:
            return amount * 5
        case .tbsp:
            return amount * 15
        }
    }
}

struct FeedingSummary {
    var date: Date
    var totalSessions: Int
    var breastCount: Int
    var breastDuration: Int
    var bottleCount: Int
    var bottleAmount: Int
    var solidCount: Int
    var solidAmount: Double
}

enum GrowthMetricKind: String, Codable, CaseIterable, Identifiable {
    case weight
    case height

    var id: String { rawValue }

    var title: String {
        switch self {
        case .weight: return "体重"
        case .height: return "身高"
        }
    }

    var unit: String {
        switch self {
        case .weight: return "kg"
        case .height: return "cm"
        }
    }

    var accent: Color {
        switch self {
        case .weight: return Color(hex: "#8E93F6")
        case .height: return Color(hex: "#A66FF2")
        }
    }

    var icon: String {
        switch self {
        case .weight: return "scalemass.fill"
        case .height: return "ruler.fill"
        }
    }

    var heroAssetName: String {
        switch self {
        case .weight: return "record_weight_scale_hero"
        case .height: return "record_height_meter_hero"
        }
    }
}

struct GrowthMetricRecord: Identifiable, Codable, Hashable {
    let id: UUID
    var kind: GrowthMetricKind
    var value: Double
    var note: String
    var recordedAt: Date

    init(
        id: UUID = UUID(),
        kind: GrowthMetricKind,
        value: Double,
        note: String = "",
        recordedAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.value = value
        self.note = note
        self.recordedAt = recordedAt
    }

    var unit: String { kind.unit }
}

@MainActor
final class GrowthMetricStore: ObservableObject {
    @Published private(set) var records: [GrowthMetricRecord] = [] {
        didSet {
            persist()
            FamilyCloudStore.shared.scheduleUpload(reason: "growth")
        }
    }

    private let key = "growth_metric_records_v1"

    init() {
        loadRecords()
        syncLatestProfileMetrics()
    }

    func saveRecord(kind: GrowthMetricKind, value: Double, note: String = "", recordedAt: Date = Date()) {
        guard value > 0, recordedAt <= Date() else { return }
        let cleanedNote = clean(note)
        records.append(GrowthMetricRecord(kind: kind, value: value, note: cleanedNote, recordedAt: recordedAt))
        records.sort { $0.recordedAt > $1.recordedAt }
        syncLatestProfileMetrics()
    }

    func updateRecord(_ record: GrowthMetricRecord, value: Double, note: String, recordedAt: Date) {
        guard value > 0, recordedAt <= Date() else { return }
        let updated = GrowthMetricRecord(
            id: record.id,
            kind: record.kind,
            value: value,
            note: clean(note),
            recordedAt: recordedAt
        )
        guard let index = records.firstIndex(where: { $0.id == record.id }) else {
            records.append(updated)
            records.sort { $0.recordedAt > $1.recordedAt }
            syncLatestProfileMetrics()
            return
        }
        records[index] = updated
        records.sort { $0.recordedAt > $1.recordedAt }
        syncLatestProfileMetrics()
    }

    func deleteRecord(_ record: GrowthMetricRecord) {
        records.removeAll { $0.id == record.id }
        FamilyCloudStore.shared.markGrowthMetricRecordDeleted(record.id)
        syncLatestProfileMetrics()
    }

    func records(on date: Date) -> [GrowthMetricRecord] {
        records
            .filter { Calendar.current.isDate($0.recordedAt, inSameDayAs: date) }
            .sorted { $0.recordedAt > $1.recordedAt }
    }

    func records(kind: GrowthMetricKind) -> [GrowthMetricRecord] {
        records
            .filter { $0.kind == kind }
            .sorted { $0.recordedAt > $1.recordedAt }
    }

    func latest(kind: GrowthMetricKind) -> GrowthMetricRecord? {
        records(kind: kind).first
    }

    func previous(before record: GrowthMetricRecord) -> GrowthMetricRecord? {
        records(kind: record.kind).first {
            $0.id != record.id && $0.recordedAt < record.recordedAt
        }
    }

    func changeInLast30Days(kind: GrowthMetricKind, from date: Date = Date()) -> Double? {
        let kindRecords = records(kind: kind)
        guard let latest = kindRecords.first else { return nil }
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: -30, to: date) ?? date
        let baseline = kindRecords
            .filter { $0.recordedAt <= cutoff }
            .first ?? kindRecords.last
        guard let baseline else { return nil }
        return latest.value - baseline.value
    }

    func exportRecords() -> [GrowthMetricRecord] {
        records
    }

    func importRecords(_ records: [GrowthMetricRecord]) {
        self.records = records.sorted { $0.recordedAt > $1.recordedAt }
        syncLatestProfileMetrics()
    }

    private func loadRecords() {
        let appGroupDefaults = UserDefaults(suiteName: WidgetStorageKey.appGroupID)
        guard let data = UserDefaults.standard.data(forKey: key)
                ?? appGroupDefaults?.data(forKey: key),
              let decoded = try? JSONDecoder().decode([GrowthMetricRecord].self, from: data) else {
            return
        }
        records = decoded.sorted { $0.recordedAt > $1.recordedAt }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(data, forKey: key)
        UserDefaults(suiteName: WidgetStorageKey.appGroupID)?.set(data, forKey: key)
    }

    private func syncLatestProfileMetrics() {
        let profileStore = BabyProfileStore.shared
        let latestHeight = latest(kind: .height)?.value
        let latestWeight = latest(kind: .weight)?.value
        profileStore.updateBodyMetrics(heightCm: latestHeight, weightKg: latestWeight)
    }

    private func clean(_ note: String) -> String {
        note
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
    }
}

// MARK: - Live Activity

enum FeedingIntervalStatus: Int, Codable, CaseIterable {
    case justFed = 0
    case tooSoon = 1
    case safe = 2
    case maybeHungry = 3
    case definitelyHungry = 4
    case warning = 5

    init(lastFeedingDate: Date, babyAgeMonths: Int?, now: Date = Date()) {
        let hours = now.timeIntervalSince(lastFeedingDate) / 3600
        let thresholds = FeedingIntervalStatus.thresholds(for: babyAgeMonths)

        if hours < thresholds.justFed {
            self = .justFed
        } else if hours < thresholds.tooSoon {
            self = .tooSoon
        } else if hours < thresholds.safe {
            self = .safe
        } else if hours < thresholds.maybeHungry {
            self = .maybeHungry
        } else if hours < thresholds.definitelyHungry {
            self = .definitelyHungry
        } else {
            self = .warning
        }
    }

    static func thresholds(for babyAgeMonths: Int?) -> (justFed: Double, tooSoon: Double, safe: Double, maybeHungry: Double, definitelyHungry: Double) {
        guard let months = babyAgeMonths else {
            return (1.5, 2.5, 4, 5, 6)
        }
        if months < 1 {
            return (0.75, 1.25, 2, 3, 4)
        }
        if months < 3 {
            return (1, 2, 3, 4, 5)
        }
        if months < 6 {
            return (1.5, 2.5, 4, 5, 6)
        }
        return (2, 3, 5, 6.5, 8)
    }

    var label: String {
        switch self {
        case .justFed: return "刚喂过"
        case .tooSoon: return "还不饿"
        case .safe: return "状态正好"
        case .maybeHungry: return "可能饿了"
        case .definitelyHungry: return "饿了"
        case .warning: return "尽快喂养"
        }
    }

    var emoji: String {
        switch self {
        case .justFed: return "😌"
        case .tooSoon: return "🙂"
        case .safe: return "😊"
        case .maybeHungry: return "🥺"
        case .definitelyHungry: return "😢"
        case .warning: return "⚠️"
        }
    }

    var backgroundColorHex: String {
        switch self {
        case .justFed: return "#DFF5E5"
        case .tooSoon: return "#E8F4FF"
        case .safe: return "#FFF7D6"
        case .maybeHungry: return "#FFE9D6"
        case .definitelyHungry: return "#FFE0DE"
        case .warning: return "#FFD6D6"
        }
    }

    var accentColorHex: String {
        switch self {
        case .justFed: return "#34C759"
        case .tooSoon: return "#64A9FF"
        case .safe: return "#F6C453"
        case .maybeHungry: return "#F6A04D"
        case .definitelyHungry: return "#FF7A70"
        case .warning: return "#FF5A5A"
        }
    }
}

#if canImport(ActivityKit)
struct FeedingActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var lastFeedingDate: Date
        var babyAgeMonths: Int?
        var status: FeedingIntervalStatus
    }

    var babyAgeMonths: Int?
}
#endif

@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private init() {}

    private var pendingUpdate = false

    func startOrUpdate(lastFeedingDate: Date, babyAgeMonths: Int?) {
        #if canImport(ActivityKit)
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        guard !pendingUpdate else { return }
        pendingUpdate = true
        let status = FeedingIntervalStatus(lastFeedingDate: lastFeedingDate, babyAgeMonths: babyAgeMonths)
        let state = FeedingActivityAttributes.ContentState(lastFeedingDate: lastFeedingDate, babyAgeMonths: babyAgeMonths, status: status)
        let content = ActivityContent(state: state, staleDate: lastFeedingDate.addingTimeInterval(24 * 60 * 60))

        Task {
            defer { pendingUpdate = false }
            let activities = Activity<FeedingActivityAttributes>.activities
            if activities.isEmpty {
                let attributes = FeedingActivityAttributes(babyAgeMonths: babyAgeMonths)
                _ = try? Activity.request(attributes: attributes, content: content)
                return
            }

            let shouldRecreate = activities.count > 1 || activities.contains { activity in
                abs(activity.content.state.lastFeedingDate.timeIntervalSince(lastFeedingDate)) > 1
            }

            if shouldRecreate {
                for activity in activities {
                    await activity.end(nil, dismissalPolicy: .immediate)
                }
                let attributes = FeedingActivityAttributes(babyAgeMonths: babyAgeMonths)
                _ = try? Activity.request(attributes: attributes, content: content)
            } else {
                for activity in activities {
                    await activity.update(content)
                }
            }
        }
        #endif
    }

    func endCurrentActivity() {
        #if canImport(ActivityKit)
        Task {
            for activity in Activity<FeedingActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        #endif
    }
}

@MainActor
final class FeedingStore: ObservableObject {
    @Published var sessions: [FeedingSession] = [] {
        didSet {
            persist()
            FamilyCloudStore.shared.scheduleUpload(reason: "feeding")
        }
    }

    private let key = "feeding_sessions_v2"

    init() {
        if
            let data = Self.loadInitialData(key: key),
            let decoded = try? JSONDecoder().decode([FeedingSession].self, from: data)
        {
            sessions = decoded.sorted { $0.createdAt > $1.createdAt }
        } else {
            sessions = []
        }
    }

    var todaySessions: [FeedingSession] {
        sessions(on: Date())
    }

    var allSessions: [FeedingSession] {
        sessions
    }

    func sessions(on date: Date) -> [FeedingSession] {
        let calendar = Calendar.current
        return sessions.filter { calendar.isDate($0.createdAt, inSameDayAs: date) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func feedCount(on date: Date) -> Int {
        sessions(on: date).count
    }

    func breastDuration(on date: Date) -> Int {
        sessions(on: date).reduce(0) { total, session in
            total + session.totalBreastDuration
        }
    }

    func formulaML(on date: Date) -> Int {
        sessions(on: date).reduce(0) { total, session in
            total + session.entries
                .filter { $0.type == .bottle && ($0.milkType ?? .formula) == .formula }
                .compactMap(\.bottleAmount)
                .reduce(0, +)
        }
    }

    func solidsGram(on date: Date) -> Int {
        sessions(on: date).reduce(0) { total, session in
            total + session.entries
                .filter { $0.type == .solid }
                .compactMap { $0.solidAmount.map(Int.init) }
                .reduce(0, +)
        }
    }

    var feedCountToday: Int { feedCount(on: Date()) }

    var breastCount: Int {
        sessionCount(in: todaySessions) { $0.type == .breast }
    }

    var breastDuration: Int {
        breastDuration(on: Date())
    }

    var formulaCount: Int {
        sessionCount(in: todaySessions) { $0.type == .bottle && ($0.milkType ?? .formula) == .formula }
    }

    var formulaML: Int {
        formulaML(on: Date())
    }

    var expressedMilkCount: Int {
        sessionCount(in: todaySessions) { $0.type == .bottle && $0.milkType == .expressed }
    }

    var expressedMilkML: Int {
        todaySessions.reduce(0) { total, session in
            total + session.entries
                .filter { $0.type == .bottle && $0.milkType == .expressed }
                .compactMap(\.bottleAmount)
                .reduce(0, +)
        }
    }

    var solidsCount: Int {
        sessionCount(in: todaySessions) { $0.type == .solid }
    }

    var solidsGram: Int {
        solidsGram(on: Date())
    }

    func add(_ session: FeedingSession) {
        saveSession(session)
    }

    func saveSession(_ session: FeedingSession) {
        guard session.createdAt <= Date() else { return }
        sessions.append(session)
        sessions.sort { $0.createdAt > $1.createdAt }
        EasyCycleStore.shared.trackFeedingSession(session)
        CompanionRecruitmentStore.shared.awardBBBucks(forRecord: .nursing, recordedAt: session.createdAt)
    }

    func deleteSession(_ session: FeedingSession) {
        sessions.removeAll { $0.id == session.id }
        EasyCycleStore.shared.removeRecordLink(type: .feeding, recordID: session.id)
        FamilyCloudStore.shared.markFeedingSessionDeleted(session.id)
    }

    func updateSession(_ session: FeedingSession) {
        guard session.createdAt <= Date() else { return }
        guard let index = sessions.firstIndex(where: { $0.id == session.id }) else {
            saveSession(session)
            return
        }
        sessions[index] = session
        sessions.sort { $0.createdAt > $1.createdAt }
        EasyCycleStore.shared.removeRecordLink(type: .feeding, recordID: session.id)
        EasyCycleStore.shared.trackFeedingSession(session)
    }

    func exportSessions() -> [FeedingSession] {
        sessions
    }

    func importSessions(_ sessions: [FeedingSession]) {
        self.sessions = sessions.sorted { $0.createdAt > $1.createdAt }
    }

    func todaySummary(for date: Date = Date()) -> FeedingSummary {
        let calendar = Calendar.current
        let daySessions = sessions.filter { calendar.isDate($0.createdAt, inSameDayAs: date) }
        return FeedingSummary(
            date: date,
            totalSessions: daySessions.count,
            breastCount: sessionCount(in: daySessions) { $0.type == .breast },
            breastDuration: daySessions.map(\.totalBreastDuration).reduce(0, +),
            bottleCount: sessionCount(in: daySessions) { $0.type == .bottle },
            bottleAmount: daySessions.map(\.totalBottleAmount).reduce(0, +),
            solidCount: sessionCount(in: daySessions) { $0.type == .solid },
            solidAmount: daySessions.map(\.totalSolidAmount).reduce(0, +)
        )
    }

    private func sessionCount(in sessions: [FeedingSession], where matches: (FeedingEntry) -> Bool) -> Int {
        sessions.filter { session in
            session.entries.contains(where: matches)
        }.count
    }

    func lastFeedingTime() -> Date? {
        sessions
            .filter { $0.createdAt <= Date() }
            .sorted { $0.createdAt > $1.createdAt }
            .first?.createdAt
    }

    nonisolated static func sharedLastFeedingTime() -> Date? {
        let appGroupDefaults = UserDefaults(suiteName: WidgetStorageKey.appGroupID)
        let data = appGroupDefaults?.data(forKey: WidgetStorageKey.feedingSessions)
            ?? appGroupDefaults?.data(forKey: "feeding_sessions_v2")
            ?? UserDefaults.standard.data(forKey: "feeding_sessions_v2")
        guard
            let data,
            let sessions = try? JSONDecoder().decode([FeedingSession].self, from: data)
        else {
            return nil
        }
        return sessions
            .filter { $0.createdAt <= Date() }
            .max { $0.createdAt < $1.createdAt }?
            .createdAt
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: key)
            let appGroupDefaults = UserDefaults(suiteName: WidgetStorageKey.appGroupID)
            appGroupDefaults?.set(data, forKey: key)
            appGroupDefaults?.set(data, forKey: WidgetStorageKey.feedingSessions)
            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadTimelines(ofKind: WidgetStorageKey.lastFeedingWidgetKind)
            #endif
        }
        if let last = lastFeedingTime() {
            LiveActivityManager.shared.startOrUpdate(lastFeedingDate: last, babyAgeMonths: BabyProfileStore.shared.currentProfile.ageMonths)
        } else {
            LiveActivityManager.shared.endCurrentActivity()
        }
    }

    private static func loadInitialData(key: String) -> Data? {
        let appGroupDefaults = UserDefaults(suiteName: WidgetStorageKey.appGroupID)
        if let data = appGroupDefaults?.data(forKey: key) ?? appGroupDefaults?.data(forKey: WidgetStorageKey.feedingSessions) {
            if UserDefaults.standard.data(forKey: key) == nil {
                UserDefaults.standard.set(data, forKey: key)
            }
            return data
        }
        if let data = UserDefaults.standard.data(forKey: key) {
            appGroupDefaults?.set(data, forKey: key)
            appGroupDefaults?.set(data, forKey: WidgetStorageKey.feedingSessions)
            return data
        }
        return nil
    }

}
