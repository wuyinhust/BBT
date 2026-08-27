import Foundation
import SwiftUI

@MainActor
final class FeedingDraftStore: ObservableObject {
    @Published var type: FeedingType = .bottle
    @Published var mood: BabyMood = .happy
    @Published var entries: [FeedingEntry] = []
    @Published var note = ""
    @Published var imageData: Data?
    var currentTime = Date()
    @Published var didSave = false
    @Published var breastMode: BreastFeedingMode = .nursing
    @Published var leftBaseSeconds = 0
    @Published var rightBaseSeconds = 0
    @Published var activeBreastSide: BreastSide?
    @Published var activeBreastStartAt: Date?
    @Published var breastTimingStartedAt: Date?
    @Published var hitMilestones: Set<Int> = []
    @Published var expressedAmount = 80.0

    @Published var milkType: MilkType = .formula
    @Published var bottleAmount = 60.0
    @Published var bottleMinutes = 0.0
    @Published var bottleIsTimed = false
    @Published var bottleTimerStartedAt: Date?
    @Published var bottleTimingStartedAt: Date?

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
        breastTimingStartedAt != nil || bottleTimingStartedAt != nil
    }

    var activeTimingItem: ActiveTimingItem? {
        if let startedAt = breastTimingStartedAt {
            return ActiveTimingItem(
                kind: .nursing,
                startedAt: startedAt,
                detail: "左 \(durationText(leftSeconds)) · 右 \(durationText(rightSeconds))"
            )
        }
        if let startedAt = bottleTimingStartedAt {
            return ActiveTimingItem(
                kind: .bottle,
                startedAt: startedAt,
                detail: totalBottleMinutes > 0 ? "已计时 \(max(Int(totalBottleMinutes), 1)) 分钟" : "计时中"
            )
        }
        return nil
    }

    var activeTimingStateID: String {
        guard let item = activeTimingItem else { return "none" }
        return "\(item.kind.rawValue)-\(item.startedAt.timeIntervalSince1970)"
    }

    private var hasMetadataDraft: Bool {
        !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        imageData != nil ||
        mood != .happy
    }

    private var hasBreastDraft: Bool {
        type == .breast &&
        (leftSeconds > 0 || rightSeconds > 0 || activeBreastSide != nil || breastTimingStartedAt != nil)
    }

    private var hasBottleDraft: Bool {
        type == .bottle &&
        (
            totalBottleMinutes > 0 ||
            bottleTimerStartedAt != nil ||
            bottleTimingStartedAt != nil ||
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
        case .breast: return "亲喂".localized
        case .bottle: return milkType.localizedDisplayName
        case .solid: return "辅食".localized
        }
    }

    var statusDetail: String {
        let totalSeconds = leftSeconds + rightSeconds
        if totalSeconds > 0 {
            return durationText(totalSeconds)
        }
        if totalBottleMinutes > 0 {
            return AppQuantityFormat.minutes(max(Int(totalBottleMinutes), 1))
        }
        if !entries.isEmpty {
            return AppQuantityFormat.records(entries.count)
        }
        switch type {
        case .breast:
            return "进行中".localized
        case .bottle:
            return AppMeasurementFormat.volume(bottleAmount)
        case .solid:
            switch solidUnit {
            case .g:
                return AppMeasurementFormat.mass(solidAmount)
            case .ml:
                return AppMeasurementFormat.volume(solidAmount)
            default:
                return "\(Int(solidAmount)) \(solidUnit.localizedDisplayName)"
            }
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

    func toggleBreastTimer(_ side: BreastSide, at date: Date = Date()) {
        commitActiveBreastElapsed(at: date)
        if activeBreastSide == side {
            activeBreastSide = nil
            activeBreastStartAt = nil
        } else {
            type = .breast
            breastMode = .nursing
            breastTimingStartedAt = breastTimingStartedAt ?? date
            activeBreastSide = side
            activeBreastStartAt = date
        }
        currentTime = date
        persistDraft()
    }

    func pauseBreastTimer(at date: Date = Date()) {
        guard activeBreastSide != nil else { return }
        commitActiveBreastElapsed(at: date)
        activeBreastSide = nil
        activeBreastStartAt = nil
        currentTime = date
        persistDraft()
    }

    func setBreastTiming(leftSeconds: Int, rightSeconds: Int, startedAt: Date?) {
        activeBreastSide = nil
        activeBreastStartAt = nil
        leftBaseSeconds = max(leftSeconds, 0)
        rightBaseSeconds = max(rightSeconds, 0)
        breastTimingStartedAt = startedAt
        type = .breast
        breastMode = .nursing
        persistDraft()
    }

    func commitActiveBreastElapsed(at date: Date = Date()) {
        guard let side = activeBreastSide, let startedAt = activeBreastStartAt else { return }
        let elapsed = max(Int(date.timeIntervalSince(startedAt)), 0)
        if side == .left {
            leftBaseSeconds += elapsed
        } else {
            rightBaseSeconds += elapsed
        }
        activeBreastStartAt = date
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
        let safeEntries = Array(
            entries
                .prefix(BBBDataSafetyLimits.maxFeedingEntries)
                .compactMap { $0.sanitized() }
        )
        let safeNote = String(
            note
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\n", with: " ")
                .prefix(2_000)
        )
        let safeImageData = imageData.flatMap {
            $0.count <= BBBDataSafetyLimits.maxImageDataBytes ? $0 : nil
        }
        let draft = FeedingDraft(
            type: type,
            mood: mood,
            entries: safeEntries,
            note: safeNote,
            imageData: safeImageData,
            breastMode: breastMode,
            leftBaseSeconds: leftBaseSeconds,
            rightBaseSeconds: rightBaseSeconds,
            activeBreastSide: activeBreastSide,
            activeBreastStartAt: activeBreastStartAt,
            breastTimingStartedAt: breastTimingStartedAt,
            hitMilestones: Set(hitMilestones.filter { (0...64).contains($0) }.prefix(64)),
            expressedAmount: Self.clampedFinite(expressedAmount, fallback: 80, range: 0...2_000),
            milkType: milkType,
            bottleAmount: Self.clampedFinite(bottleAmount, fallback: 60, range: 0...2_000),
            bottleMinutes: Self.clampedFinite(bottleMinutes, fallback: 0, range: 0...1_440),
            bottleIsTimed: bottleIsTimed,
            bottleTimerStartedAt: bottleTimerStartedAt,
            bottleTimingStartedAt: bottleTimingStartedAt,
            solidFood: solidFood,
            solidFoods: solidFoods,
            solidAmount: Self.clampedFinite(solidAmount, fallback: 30, range: 0...2_000),
            solidUnit: solidUnit,
            updatedAt: Date()
        )
        guard let data = try? JSONEncoder().encode(draft) else { return }
        UserDefaults.standard.set(data, forKey: draftKey)
        UserDefaults(suiteName: WidgetStorageKey.appGroupID)?.set(data, forKey: draftKey)
        persistActiveTimingSnapshot()
    }

    func restoreDraft() {
        let data = UserDefaults.standard.data(forKey: draftKey)
            ?? UserDefaults(suiteName: WidgetStorageKey.appGroupID)?.data(forKey: draftKey)
        guard let data else { return }
        guard data.count <= BBBDataSafetyLimits.maxDraftDataBytes else {
            clearPersistedDraft()
            return
        }
        guard let draft = try? JSONDecoder().decode(FeedingDraft.self, from: data) else {
            return
        }
        let migratedBottleDraft = draft.type == .breast && draft.breastMode == .expressedBottle && draft.expressedAmount > 0
        type = migratedBottleDraft ? .bottle : draft.type
        mood = draft.mood
        entries = Array(
            draft.entries
                .prefix(BBBDataSafetyLimits.maxFeedingEntries)
                .compactMap { $0.sanitized() }
        )
        note = String(
            draft.note
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\n", with: " ")
                .prefix(2_000)
        )
        imageData = draft.imageData.flatMap {
            $0.count <= BBBDataSafetyLimits.maxImageDataBytes ? $0 : nil
        }
        breastMode = migratedBottleDraft ? .nursing : draft.breastMode
        leftBaseSeconds = min(max(draft.leftBaseSeconds, 0), 86_400)
        rightBaseSeconds = min(max(draft.rightBaseSeconds, 0), 86_400)
        activeBreastSide = draft.activeBreastSide
        activeBreastStartAt = draft.activeBreastStartAt
        breastTimingStartedAt = draft.breastTimingStartedAt
        hitMilestones = Set(draft.hitMilestones.filter { (0...64).contains($0) }.prefix(64))
        expressedAmount = Self.clampedFinite(draft.expressedAmount, fallback: 80, range: 0...2_000)
        milkType = migratedBottleDraft ? .expressed : draft.milkType
        bottleAmount = migratedBottleDraft
            ? Self.clampedFinite(draft.expressedAmount, fallback: 80, range: 0...2_000)
            : Self.clampedFinite(draft.bottleAmount, fallback: 60, range: 0...2_000)
        bottleMinutes = Self.clampedFinite(draft.bottleMinutes, fallback: 0, range: 0...1_440)
        bottleIsTimed = draft.bottleIsTimed
        bottleTimerStartedAt = draft.bottleTimerStartedAt
        bottleTimingStartedAt = draft.bottleTimingStartedAt
        solidFood = draft.solidFood
        solidFoods = Self.normalizedSolidFoods(draft.solidFoods ?? [draft.solidFood])
        solidFood = solidFoods.first ?? draft.solidFood
        solidAmount = Self.clampedFinite(draft.solidAmount, fallback: 30, range: 0...2_000)
        solidUnit = draft.solidUnit
        if !hasDraft {
            resetDraft()
        } else {
            persistActiveTimingSnapshot()
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
        breastTimingStartedAt = nil
        hitMilestones = []
        expressedAmount = 80
        milkType = .formula
        bottleAmount = 60
        bottleMinutes = 0
        bottleIsTimed = false
        bottleTimerStartedAt = nil
        bottleTimingStartedAt = nil
        solidFood = .rice
        solidFoods = [.rice]
        solidAmount = 30
        solidUnit = .g
        clearPersistedDraft()
    }

    private func clearPersistedDraft() {
        UserDefaults.standard.removeObject(forKey: draftKey)
        UserDefaults(suiteName: WidgetStorageKey.appGroupID)?.removeObject(forKey: draftKey)
        ActiveTimingStorage.update(feeding: nil, replaceFeeding: true)
        refreshSystemSurfaces()
    }

    private func persistActiveTimingSnapshot() {
        ActiveTimingStorage.update(feeding: activeTimingItem, replaceFeeding: true)
        refreshSystemSurfaces()
    }

    private func refreshSystemSurfaces() {
        CareRecencyCoordinator.refreshFromSharedStorage(
            babyAgeMonths: BabyProfileStore.shared.currentProfile.ageMonths
        )
    }

    private func durationText(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    private static func normalizedSolidFoods(_ foods: [SolidFood]) -> [SolidFood] {
        var seen: Set<SolidFood> = []
        let normalized = foods
            .prefix(16)
            .filter { seen.insert($0).inserted }
        return normalized.isEmpty ? [.rice] : normalized
    }

    private static func clampedFinite(
        _ value: Double,
        fallback: Double,
        range: ClosedRange<Double>
    ) -> Double {
        guard value.isFinite else { return fallback }
        return min(max(value, range.lowerBound), range.upperBound)
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
    var breastTimingStartedAt: Date?
    var hitMilestones: Set<Int>
    var expressedAmount: Double
    var milkType: MilkType
    var bottleAmount: Double
    var bottleMinutes: Double
    var bottleIsTimed: Bool
    var bottleTimerStartedAt: Date?
    var bottleTimingStartedAt: Date?
    var solidFood: SolidFood
    var solidFoods: [SolidFood]?
    var solidAmount: Double
    var solidUnit: SolidUnit
    var updatedAt: Date
}
