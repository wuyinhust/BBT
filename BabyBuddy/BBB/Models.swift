import SwiftUI
import Foundation
import Observation
#if canImport(ActivityKit)
import ActivityKit
#endif
#if canImport(WidgetKit)
import WidgetKit
#endif

// MARK: - Design

enum DesignToken {
    static let primary = Color(hex: "#BDA6F2")
    static let primarySoft = Color(hex: "#F4C7D9")
    static let accentBlue = Color(hex: "#A5C8FF")
    static let grayNeutral = Color(hex: "#EAEAF2")
    static let background = Color(hex: "#F8F7FB")
    static let textTitle = Color(hex: "#3A3A50")
    static let textBody = Color(hex: "#7A7A92")
    static let cardBackground = Color.white
    static let errorRed = Color(hex: "#FF6B6B")

    static let bg = background
    static let card = cardBackground
    static let textPrimary = textTitle
    static let textSecondary = textBody
    static let line = Color(hex: "#D6D4DF")
    static let iconSoftBG = Color(hex: "#F0EEF8")

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
    var friendshipTarget: Int { rarity.friendshipTarget }
    var dailyServingLimit: Int { rarity.dailyServingLimit }
    var lockedMaskAssetName: String? {
        switch id {
        case "fenny":
            return "companion_fenny_locked_mask"
        default:
            return nil
        }
    }

    static let all: [BabyCompanion] = [
        .init(id: "bunny_lulu", chineseName: "洛噗", englishName: "Loppy", species: "荷兰垂耳兔幼兔", intro: "稳定亲近、反应柔和，是容易被轻轻引导的小甜心。", emoji: "🐰"),
        .init(id: "fawn_mimi", chineseName: "西咔", englishName: "Sika", species: "梅花鹿幼崽", intro: "安静细腻、喜欢熟悉节奏，需要被温柔守护。", emoji: "🦌"),
        .init(id: "cal", chineseName: "柯噜", englishName: "Cal", species: "柯尔鸭幼鸭", intro: "圆滚滚、步伐慢半拍，擅长把普通日常变得可爱。", emoji: "🦆"),
        .init(id: "samoyed_momo", chineseName: "摩耶", englishName: "Moye", species: "萨摩耶幼犬", intro: "亲和稳定、适应力强，像随时给人安心的陪伴。", emoji: "🐶"),
        .init(id: "otter_tangtang", chineseName: "欧缇", englishName: "Ottie", species: "亚洲小爪水獭幼崽", intro: "状态丰富、节奏多变，需要弹性和耐心配合。", emoji: "🦦"),
        .init(id: "fenny", chineseName: "芬灵", englishName: "Fenny", species: "耳廓狐幼崽", intro: "敏锐聪明、先观察再靠近，对环境里的细节特别有感觉。", emoji: "🦊"),
        .init(id: "redpanda_youyou", chineseName: "瑞迪", englishName: "Reddy", species: "小熊猫幼崽", intro: "柔软但有主见，喜欢按自己的方式慢慢进入状态。", emoji: "🐾"),
        .init(id: "koala_anan", chineseName: "阿考", englishName: "Ako", species: "昆士兰考拉幼崽", intro: "慢热谨慎、观察力强，安全感足够后会认真靠近。", emoji: "🐨"),
        .init(id: "sloth_nono", chineseName: "霍菲", englishName: "Hoffy", species: "霍氏树懒幼崽", intro: "慢节奏、低刺激偏好，需要更从容的过渡时间。", emoji: "🌿"),
        .init(id: "chipmunk_huohuo", chineseName: "奇比", englishName: "Chippy", species: "西伯利亚花栗鼠幼崽", intro: "感受强烈、反应很快，需要更多安抚和提前预告。", emoji: "✨"),
        .init(id: "piggy", chineseName: "尤卡", englishName: "Yuca", species: "尤卡坦迷你猪幼崽", intro: "爱睡觉也爱贴贴，是小木屋里最松弛的暖心伙伴。", emoji: "🐷"),
        .init(id: "ferry", chineseName: "雪溜", englishName: "Ferry", species: "安格鲁貂幼崽", intro: "软绵灵活、好奇心强，喜欢在日常缝隙里发现小惊喜。", emoji: "🦦")
    ]

    static let defaultUnlockedIDs: Set<String> = ["piggy", "fenny", "ferry", "cal"]
    static let previewLockedIDs: Set<String> = ["fenny"]

    static func companion(for id: String) -> BabyCompanion {
        all.first(where: { $0.id == id }) ?? all[2]
    }

    static func canonicalID(_ id: String) -> String {
        id
    }

    static func unlockedIDs(selectedID: String, temperamentAnimalID: String?) -> Set<String> {
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

@MainActor
final class CompanionRecruitmentStore: ObservableObject {
    static let shared = CompanionRecruitmentStore()
    static let currencyName = "BB Bucks"
    static let dailyEarnLimit = 10
    static let dailyBuddyFeedLimit = 3
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

    private let bbBucksKey = "companion_recruitment_bb_bucks_v1"
    private let friendshipKey = "companion_recruitment_friendship_v1"
    private let recruitedKey = "companion_recruitment_recruited_ids_v1"
    private let reportsKey = "companion_recruitment_yesterday_reports_v1"
    private let dailyEarningsKey = "companion_recruitment_daily_earnings_v1"
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
        reports[index].fedCompanionID = companionID
        reports[index].fedBBBucks = spentBucks
    }

    func markReportFeeding(_ report: YesterdayReport, companionID: String, spentBucks: Int, bonusServings: Int) {
        guard let index = reports.firstIndex(where: { $0.reportKey == report.reportKey }) else { return }
        if let feedingIndex = reports[index].feedings.firstIndex(where: { $0.companionID == companionID }) {
            reports[index].feedings[feedingIndex].servings += 1
            reports[index].feedings[feedingIndex].spentBBBucks += spentBucks
            reports[index].feedings[feedingIndex].bonusServings += bonusServings
        } else {
            reports[index].feedings.append(YesterdayBuddyFeeding(
                companionID: companionID,
                servings: 1,
                spentBBBucks: spentBucks,
                bonusServings: bonusServings
            ))
        }
        reports[index].fedCompanionID = reports[index].feedings.last?.companionID
        reports[index].fedBBBucks = reports[index].feedings.reduce(0) { $0 + $1.spentBBBucks }
    }

    func visitorCompanion(for reportKey: String) -> BabyCompanion {
        visitorCompanions(for: reportKey).first ?? BabyCompanion.all[0]
    }

    func visitorCompanions(for reportKey: String, limit: Int? = nil) -> [BabyCompanion] {
        var candidates = lockedRecruitmentCandidates()
        if candidates.isEmpty {
            candidates = BabyCompanion.all
        }

        let targetLimit = limit ?? CompanionRecruitmentStore.dailyBuddyFeedLimit
        var selected: [BabyCompanion] = []
        var remaining = candidates
        var seed = deterministicSeed(for: reportKey)
        while !remaining.isEmpty && selected.count < targetLimit {
            let index = weightedIndex(in: remaining, seed: seed)
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
        var seed = deterministicSeed(for: reportKey)
        while !remaining.isEmpty && selected.count < targetLimit {
            let index = weightedIndex(in: remaining, seed: seed)
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
    }

    private func lockedRecruitmentCandidates() -> [BabyCompanion] {
        BabyCompanion.all.filter { companion in
            !isRecruited(companion.id) && !BabyCompanion.defaultUnlockedIDs.contains(companion.id)
        }
    }

    private static func dayKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func deterministicSeed(for key: String) -> Int {
        abs(key.unicodeScalars.reduce(17) { ($0 * 31 + Int($1.value)) &+ 7 })
    }

    private func nextSeed(_ seed: Int) -> Int {
        abs((seed &* 1_103_515_245 &+ 12_345) & 0x7fffffff)
    }

    private func weightedIndex(in companions: [BabyCompanion], seed: Int) -> Int {
        let totalWeight = companions.reduce(0) { $0 + max($1.rarity.visitWeight, 0.01) }
        let ticket = (Double(seed % 10_000) / 10_000.0) * totalWeight
        var cursor = 0.0
        for (index, companion) in companions.enumerated() {
            cursor += max(companion.rarity.visitWeight, 0.01)
            if ticket <= cursor {
                return index
            }
        }
        return max(companions.count - 1, 0)
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
    static let babyInfo = "baby_info"
    static let lastFeedingWidgetKind = "v.babybuddy.LastFeeding"
}

struct BabyProfileData: Codable {
    var name: String
    var gender: BabyGender
    var birthDate: Date
    var avatarEmoji: String?
    var avatarImageData: Data?

    var displayAvatar: String {
        avatarEmoji ?? gender.emoji
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

    func updateAvatar(_ avatarEmoji: String?) {
        var updated = currentProfile
        updated.avatarEmoji = avatarEmoji
        updated.avatarImageData = nil
        profile = updated
    }

    func updateAvatarImageData(_ imageData: Data?) {
        var updated = currentProfile
        updated.avatarImageData = imageData
        if imageData != nil {
            updated.avatarEmoji = nil
        }
        profile = updated
    }

    func create(name: String, gender: BabyGender, birthDate: Date, avatarEmoji: String? = nil, avatarImageData: Data? = nil) {
        profile = BabyProfileData(name: name, gender: gender, birthDate: birthDate, avatarEmoji: avatarEmoji, avatarImageData: avatarImageData)
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
            avatarEmoji: nil,
            avatarImageData: nil
        )
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

    static var legacyCases: [FeedingType] { [.breast, .bottle, .solid] }

    var displayName: String {
        switch self {
        case .breast: return "母乳"
        case .bottle: return "奶粉"
        case .solid: return "辅食"
        }
    }

    var accent: Color {
        switch self {
        case .bottle: return Color(hex: "#1E97FF")
        case .breast: return Color(hex: "#FF9E2F")
        case .solid: return Color(hex: "#32D262")
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

struct FeedingSession: Identifiable, Codable {
    let id: UUID
    var entries: [FeedingEntry]
    var notes: String
    var imageData: Data?
    var babyMood: BabyMood
    var createdAt: Date

    init(
        id: UUID = UUID(),
        entries: [FeedingEntry],
        notes: String = "",
        imageData: Data? = nil,
        babyMood: BabyMood = .happy,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.entries = entries
        self.notes = notes
        self.imageData = imageData
        self.babyMood = babyMood
        self.createdAt = createdAt
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
        createdAt: Date = Date()
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
        self.init(id: id, entries: [entry], notes: note, babyMood: mood, createdAt: createdAt)
    }

    var type: FeedingType {
        entries.first?.type ?? .bottle
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

    func startOrUpdate(lastFeedingDate: Date, babyAgeMonths: Int?) {
        #if canImport(ActivityKit)
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let status = FeedingIntervalStatus(lastFeedingDate: lastFeedingDate, babyAgeMonths: babyAgeMonths)
        let state = FeedingActivityAttributes.ContentState(lastFeedingDate: lastFeedingDate, babyAgeMonths: babyAgeMonths, status: status)
        let content = ActivityContent(state: state, staleDate: lastFeedingDate.addingTimeInterval(24 * 60 * 60))

        Task {
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
        todaySessions.reduce(0) { count, session in
            count + session.entries.filter { $0.type == .breast }.count
        }
    }

    var breastDuration: Int {
        breastDuration(on: Date())
    }

    var formulaCount: Int {
        todaySessions.reduce(0) { count, session in
            count + session.entries.filter { $0.type == .bottle && ($0.milkType ?? .formula) == .formula }.count
        }
    }

    var formulaML: Int {
        formulaML(on: Date())
    }

    var expressedMilkCount: Int {
        todaySessions.reduce(0) { count, session in
            count + session.entries.filter { $0.type == .bottle && $0.milkType == .expressed }.count
        }
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
        todaySessions.reduce(0) { count, session in
            count + session.entries.filter { $0.type == .solid }.count
        }
    }

    var solidsGram: Int {
        solidsGram(on: Date())
    }

    func add(_ session: FeedingSession) {
        saveSession(session)
    }

    func saveSession(_ session: FeedingSession) {
        sessions.append(session)
        sessions.sort { $0.createdAt > $1.createdAt }
        CompanionRecruitmentStore.shared.awardBBBucks(forRecord: .nursing, recordedAt: session.createdAt)
    }

    func deleteSession(_ session: FeedingSession) {
        sessions.removeAll { $0.id == session.id }
        FamilyCloudStore.shared.markFeedingSessionDeleted(session.id)
    }

    func updateSession(_ session: FeedingSession) {
        guard let index = sessions.firstIndex(where: { $0.id == session.id }) else {
            saveSession(session)
            return
        }
        sessions[index] = session
        sessions.sort { $0.createdAt > $1.createdAt }
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
            breastCount: daySessions.reduce(0) { $0 + $1.entries.filter { $0.type == .breast }.count },
            breastDuration: daySessions.map(\.totalBreastDuration).reduce(0, +),
            bottleCount: daySessions.reduce(0) { $0 + $1.entries.filter { $0.type == .bottle }.count },
            bottleAmount: daySessions.map(\.totalBottleAmount).reduce(0, +),
            solidCount: daySessions.reduce(0) { $0 + $1.entries.filter { $0.type == .solid }.count },
            solidAmount: daySessions.map(\.totalSolidAmount).reduce(0, +)
        )
    }

    func lastFeedingTime() -> Date? {
        sessions.sorted { $0.createdAt > $1.createdAt }.first?.createdAt
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
        return sessions.max { $0.createdAt < $1.createdAt }?.createdAt
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
