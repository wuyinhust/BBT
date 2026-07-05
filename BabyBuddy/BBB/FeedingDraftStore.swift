import Foundation
import SwiftUI

@MainActor
final class FeedingDraftStore: ObservableObject {
    @Published var type: FeedingType = .bottle
    @Published var mood: BabyMood = .happy
    @Published var entries: [FeedingEntry] = []
    @Published var note = ""
    @Published var imageData: Data?
    @Published var currentTime = Date()
    @Published var didSave = false

    @Published var breastMode: BreastFeedingMode = .nursing
    @Published var leftBaseSeconds = 0
    @Published var rightBaseSeconds = 0
    @Published var activeBreastSide: BreastSide?
    @Published var activeBreastStartAt: Date?
    @Published var hitMilestones: Set<Int> = []
    @Published var expressedAmount = 80.0

    @Published var milkType: MilkType = .formula
    @Published var bottleAmount = 60.0
    @Published var bottleMinutes = 0.0
    @Published var bottleIsTimed = false
    @Published var bottleTimerStartedAt: Date?

    @Published var solidFood: SolidFood = .rice
    @Published var solidFoods: [SolidFood] = [.rice]
    @Published var solidAmount = 30.0
    @Published var solidUnit: SolidUnit = .g

    private let draftKey = "feeding_sheet_draft_v4"

    var hasDraft: Bool {
        hasRecordDraft
    }

    private var hasRecordDraft: Bool {
        !entries.isEmpty ||
        hasBreastDraft ||
        hasBottleDraft ||
        hasSolidDraft
    }

    var isRecording: Bool {
        (type == .breast && (activeBreastSide != nil || leftSeconds + rightSeconds > 0)) ||
        bottleTimerStartedAt != nil ||
        totalBottleMinutes > 0
    }

    private var hasMetadataDraft: Bool {
        !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        imageData != nil ||
        mood != .happy
    }

    private var hasBreastDraft: Bool {
        type == .breast &&
        (leftSeconds > 0 || rightSeconds > 0 || activeBreastSide != nil)
    }

    private var hasBottleDraft: Bool {
        type == .bottle &&
        (
            totalBottleMinutes > 0 ||
            bottleTimerStartedAt != nil ||
            milkType != .formula ||
            bottleAmount != 60 ||
            (hasMetadataDraft && bottleAmount > 0)
        )
    }

    private var hasSolidDraft: Bool {
        type == .solid &&
        (
            solidFood != .rice ||
            solidFoods != [.rice] ||
            solidAmount != 30 ||
            solidUnit != .g ||
            (hasMetadataDraft && solidAmount > 0)
        )
    }

    var leftSeconds: Int {
        breastSeconds(for: .left)
    }

    var rightSeconds: Int {
        breastSeconds(for: .right)
    }

    var totalBottleMinutes: Double {
        bottleMinutes + currentBottleElapsedMinutes
    }

    var currentBottleElapsedMinutes: Double {
        guard let bottleTimerStartedAt else { return 0 }
        return max(currentTime.timeIntervalSince(bottleTimerStartedAt) / 60, 0)
    }

    var statusTitle: String {
        switch type {
        case .breast: return "亲喂"
        case .bottle: return milkType.displayName
        case .solid: return "辅食"
        }
    }

    var statusDetail: String {
        let totalSeconds = leftSeconds + rightSeconds
        if totalSeconds > 0 {
            return durationText(totalSeconds)
        }
        if totalBottleMinutes > 0 {
            return "\(max(Int(totalBottleMinutes), 1)) 分钟"
        }
        if !entries.isEmpty {
            return "\(entries.count) 条"
        }
        switch type {
        case .breast:
            return "进行中"
        case .bottle:
            return "\(Int(bottleAmount))ml"
        case .solid:
            return "\(Int(solidAmount))\(solidUnit.displayName)"
        }
    }

    var statusIcon: String {
        switch type {
        case .breast: return "heart.fill"
        case .bottle: return "waterbottle.fill"
        case .solid: return "fork.knife"
        }
    }

    init() {
        restoreDraft()
    }

    func updateCurrentTime(_ date: Date) {
        currentTime = date
    }

    func breastSeconds(for side: BreastSide, at date: Date = Date()) -> Int {
        let base = side == .left ? leftBaseSeconds : rightBaseSeconds
        guard activeBreastSide == side, let activeBreastStartAt else { return base }
        return base + max(Int(date.timeIntervalSince(activeBreastStartAt)), 0)
    }

    func persistDraftIfNeeded() {
        guard activeBreastSide != nil || bottleTimerStartedAt != nil || hasDraft else {
            clearPersistedDraft()
            return
        }
        persistDraft()
    }

    func persistDraft() {
        guard hasDraft else {
            clearPersistedDraft()
            return
        }
        let draft = FeedingDraft(
            type: type,
            mood: mood,
            entries: entries,
            note: note,
            imageData: imageData,
            breastMode: breastMode,
            leftBaseSeconds: leftBaseSeconds,
            rightBaseSeconds: rightBaseSeconds,
            activeBreastSide: activeBreastSide,
            activeBreastStartAt: activeBreastStartAt,
            hitMilestones: hitMilestones,
            expressedAmount: expressedAmount,
            milkType: milkType,
            bottleAmount: bottleAmount,
            bottleMinutes: bottleMinutes,
            bottleIsTimed: bottleIsTimed,
            bottleTimerStartedAt: bottleTimerStartedAt,
            solidFood: solidFood,
            solidFoods: solidFoods,
            solidAmount: solidAmount,
            solidUnit: solidUnit,
            updatedAt: Date()
        )
        guard let data = try? JSONEncoder().encode(draft) else { return }
        UserDefaults.standard.set(data, forKey: draftKey)
        UserDefaults(suiteName: WidgetStorageKey.appGroupID)?.set(data, forKey: draftKey)
    }

    func restoreDraft() {
        let data = UserDefaults.standard.data(forKey: draftKey)
            ?? UserDefaults(suiteName: WidgetStorageKey.appGroupID)?.data(forKey: draftKey)
        guard let data, let draft = try? JSONDecoder().decode(FeedingDraft.self, from: data) else { return }
        let migratedBottleDraft = draft.type == .breast && draft.breastMode == .expressedBottle && draft.expressedAmount > 0
        type = migratedBottleDraft ? .bottle : draft.type
        mood = draft.mood
        entries = draft.entries
        note = draft.note
        imageData = draft.imageData
        breastMode = migratedBottleDraft ? .nursing : draft.breastMode
        leftBaseSeconds = draft.leftBaseSeconds
        rightBaseSeconds = draft.rightBaseSeconds
        activeBreastSide = draft.activeBreastSide
        activeBreastStartAt = draft.activeBreastStartAt
        hitMilestones = draft.hitMilestones
        expressedAmount = draft.expressedAmount
        milkType = migratedBottleDraft ? .expressed : draft.milkType
        bottleAmount = migratedBottleDraft ? draft.expressedAmount : draft.bottleAmount
        bottleMinutes = draft.bottleMinutes
        bottleIsTimed = draft.bottleIsTimed
        bottleTimerStartedAt = draft.bottleTimerStartedAt
        solidFood = draft.solidFood
        solidFoods = Self.normalizedSolidFoods(draft.solidFoods ?? [draft.solidFood])
        solidFood = solidFoods.first ?? draft.solidFood
        solidAmount = draft.solidAmount
        solidUnit = draft.solidUnit
        if !hasDraft {
            resetDraft()
        }
    }

    func resetDraft() {
        type = .bottle
        mood = .happy
        entries = []
        note = ""
        imageData = nil
        currentTime = Date()
        didSave = false
        breastMode = .nursing
        leftBaseSeconds = 0
        rightBaseSeconds = 0
        activeBreastSide = nil
        activeBreastStartAt = nil
        hitMilestones = []
        expressedAmount = 80
        milkType = .formula
        bottleAmount = 60
        bottleMinutes = 0
        bottleIsTimed = false
        bottleTimerStartedAt = nil
        solidFood = .rice
        solidFoods = [.rice]
        solidAmount = 30
        solidUnit = .g
        clearPersistedDraft()
    }

    private func clearPersistedDraft() {
        UserDefaults.standard.removeObject(forKey: draftKey)
        UserDefaults(suiteName: WidgetStorageKey.appGroupID)?.removeObject(forKey: draftKey)
    }

    private func durationText(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    private static func normalizedSolidFoods(_ foods: [SolidFood]) -> [SolidFood] {
        var seen: Set<SolidFood> = []
        let normalized = foods.filter { seen.insert($0).inserted }
        return normalized.isEmpty ? [.rice] : normalized
    }
}

private struct FeedingDraft: Codable {
    var type: FeedingType
    var mood: BabyMood
    var entries: [FeedingEntry]
    var note: String
    var imageData: Data?
    var breastMode: BreastFeedingMode
    var leftBaseSeconds: Int
    var rightBaseSeconds: Int
    var activeBreastSide: BreastSide?
    var activeBreastStartAt: Date?
    var hitMilestones: Set<Int>
    var expressedAmount: Double
    var milkType: MilkType
    var bottleAmount: Double
    var bottleMinutes: Double
    var bottleIsTimed: Bool
    var bottleTimerStartedAt: Date?
    var solidFood: SolidFood
    var solidFoods: [SolidFood]?
    var solidAmount: Double
    var solidUnit: SolidUnit
    var updatedAt: Date
}
