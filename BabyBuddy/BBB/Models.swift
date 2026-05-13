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

struct BabyCompanion: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let subtitle: String
    let description: String

    static let all: [BabyCompanion] = [
        .init(id: "piggy", name: "Piggy", subtitle: "粉咕 · 尤卡坦猪", description: "闭着眼打呼噜，睡得超香"),
        .init(id: "fenny", name: "Fenny", subtitle: "芬灵 · 阔耳狐", description: "大耳朵竖起来，机灵敏锐"),
        .init(id: "ferry", name: "Ferry", subtitle: "雪溜 · 安格鲁貂", description: "软绵绵滑溜溜，爱钻来钻去"),
        .init(id: "cal", name: "Cal", subtitle: "柯噜 · 柯尔鸭", description: "圆滚滚摇摇摆，嘎嘎叫不停")
    ]
}

@MainActor
final class CompanionStore: ObservableObject {
    @Published var selectedID: String {
        didSet { UserDefaults.standard.set(selectedID, forKey: "selected_companion_id") }
    }

    init() {
        self.selectedID = UserDefaults.standard.string(forKey: "selected_companion_id") ?? "cal"
    }

    var selected: BabyCompanion {
        BabyCompanion.all.first(where: { $0.id == selectedID }) ?? BabyCompanion.all[3]
    }
}

// MARK: - Tabs

enum RootTab: Int, CaseIterable {
    case record
    case companion

    var title: String {
        switch self {
        case .record: return "记录"
        case .companion: return "陪伴"
        }
    }

    var icon: String {
        switch self {
        case .record: return "book.fill"
        case .companion: return "trophy.fill"
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
            birthDate: birthDate
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

    func create(name: String, gender: BabyGender, birthDate: Date) {
        profile = BabyProfileData(name: name, gender: gender, birthDate: birthDate)
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
    }

    private static var defaultProfile: BabyProfileData {
        BabyProfileData(
            name: "33",
            gender: .boy,
            birthDate: Calendar.current.date(byAdding: .day, value: -22, to: Date()) ?? Date()
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
        didSet { save() }
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
        let state = FeedingActivityAttributes.ContentState(lastFeedingDate: lastFeedingDate, status: status)
        let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(8 * 3600))

        Task {
            if let activity = Activity<FeedingActivityAttributes>.activities.first {
                await activity.update(content)
            } else {
                let attributes = FeedingActivityAttributes(babyAgeMonths: babyAgeMonths)
                _ = try? Activity.request(attributes: attributes, content: content)
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
        didSet { persist() }
    }

    private let key = "feeding_sessions_v2"

    init() {
        if
            let data = Self.loadInitialData(key: key),
            let decoded = try? JSONDecoder().decode([FeedingSession].self, from: data)
        {
            sessions = decoded.sorted { $0.createdAt > $1.createdAt }
        } else {
            seedIfNeeded()
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
    }

    func deleteSession(_ session: FeedingSession) {
        sessions.removeAll { $0.id == session.id }
    }

    func updateSession(_ session: FeedingSession) {
        guard let index = sessions.firstIndex(where: { $0.id == session.id }) else {
            saveSession(session)
            return
        }
        sessions[index] = session
        sessions.sort { $0.createdAt > $1.createdAt }
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

    private func seedIfNeeded() {
        guard sessions.isEmpty else { return }
        let calendar = Calendar.current
        let now = Date()
        sessions = [
            FeedingSession(type: .bottle, amountML: 30, createdAt: calendar.date(byAdding: .minute, value: -20, to: now) ?? now),
            FeedingSession(type: .breast, durationMin: 11, createdAt: calendar.date(byAdding: .minute, value: -20, to: now) ?? now),
            FeedingSession(type: .bottle, amountML: 60, createdAt: calendar.date(byAdding: .minute, value: -110, to: now) ?? now),
            FeedingSession(type: .breast, durationMin: 2, createdAt: calendar.date(byAdding: .minute, value: -129, to: now) ?? now),
            FeedingSession(type: .bottle, amountML: 40, durationMin: 16, createdAt: calendar.date(byAdding: .minute, value: -279, to: now) ?? now),
            FeedingSession(type: .breast, durationMin: 3, createdAt: calendar.date(byAdding: .minute, value: -366, to: now) ?? now),
            FeedingSession(type: .bottle, amountML: 60, durationMin: 47, createdAt: calendar.date(byAdding: .minute, value: -500, to: now) ?? now),
            FeedingSession(type: .solid, solidsKind: "米糊", solidsGram: 30, createdAt: calendar.date(byAdding: .minute, value: -680, to: now) ?? now)
        ]
    }
}
