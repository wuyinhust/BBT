import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

enum CareRecencyKind: String, Codable, CaseIterable, Hashable, Identifiable {
    case feeding
    case pee
    case poop
    case sleep

    var id: String { rawValue }

    var title: String {
        switch self {
        case .feeding: return "喂养".localized
        case .pee: return "尿尿".localized
        case .poop: return "粑粑".localized
        case .sleep: return "睡眠".localized
        }
    }

    var fullTitle: String { AppLocalization.format("care.last.title", title) }

    var systemImage: String {
        switch self {
        case .feeding: return "waterbottle.fill"
        case .pee: return "drop.fill"
        case .poop: return "circle.grid.2x2.fill"
        case .sleep: return "moon.zzz.fill"
        }
    }
}

struct CareRecencyItem: Codable, Hashable, Identifiable {
    var kind: CareRecencyKind
    var completedAt: Date?
    var detail: String

    var id: CareRecencyKind { kind }
}

struct CareRecencySnapshot: Codable, Hashable {
    var generatedAt: Date
    var feeding: CareRecencyItem
    var pee: CareRecencyItem
    var poop: CareRecencyItem
    var sleep: CareRecencyItem

    init(
        generatedAt: Date,
        feeding: CareRecencyItem,
        pee: CareRecencyItem,
        poop: CareRecencyItem,
        sleep: CareRecencyItem
    ) {
        self.generatedAt = generatedAt
        self.feeding = feeding
        self.pee = pee
        self.poop = poop
        self.sleep = sleep
    }

    static func empty(at date: Date = Date()) -> CareRecencySnapshot {
        CareRecencySnapshot(
            generatedAt: date,
            feeding: CareRecencyItem(kind: .feeding, completedAt: nil, detail: "暂无记录"),
            pee: CareRecencyItem(kind: .pee, completedAt: nil, detail: "暂无记录"),
            poop: CareRecencyItem(kind: .poop, completedAt: nil, detail: "暂无记录"),
            sleep: CareRecencyItem(kind: .sleep, completedAt: nil, detail: "暂无记录")
        )
    }

    var items: [CareRecencyItem] {
        [feeding, pee, poop, sleep]
    }

    func item(for kind: CareRecencyKind) -> CareRecencyItem {
        switch kind {
        case .feeding: return feeding
        case .pee: return pee
        case .poop: return poop
        case .sleep: return sleep
        }
    }

    var mostRecentItem: CareRecencyItem? {
        items
            .filter { $0.completedAt != nil }
            .max { lhs, rhs in
                (lhs.completedAt ?? .distantPast) < (rhs.completedAt ?? .distantPast)
            }
    }

    var hasAnyRecord: Bool {
        mostRecentItem != nil
    }
}

enum ActiveTimingKind: String, Codable, Hashable, Identifiable {
    case nursing
    case bottle
    case sleep

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nursing: return "母乳亲喂".localized
        case .bottle: return "瓶喂".localized
        case .sleep: return "睡眠".localized
        }
    }
}

struct ActiveTimingItem: Codable, Hashable, Identifiable {
    var kind: ActiveTimingKind
    var startedAt: Date
    var detail: String

    var id: ActiveTimingKind { kind }
}

struct ActiveTimingSnapshot: Codable, Hashable {
    var generatedAt: Date
    var feeding: ActiveTimingItem?
    var sleep: ActiveTimingItem?

    static func empty(at date: Date = Date()) -> ActiveTimingSnapshot {
        ActiveTimingSnapshot(generatedAt: date, feeding: nil, sleep: nil)
    }

    var items: [ActiveTimingItem] {
        [feeding, sleep].compactMap { $0 }
    }

    var hasActiveTiming: Bool {
        !items.isEmpty
    }
}

enum ActiveTimingStorage {
    static let appGroupID = "group.73AUQDMCJ2.babybuddy"
    static let snapshotKey = "active_timing_snapshot_v1"

    static func load() -> ActiveTimingSnapshot {
        guard let data = UserDefaults(suiteName: appGroupID)?.data(forKey: snapshotKey),
              let snapshot = try? JSONDecoder().decode(ActiveTimingSnapshot.self, from: data) else {
            return .empty()
        }
        return snapshot
    }

    static func update(feeding: ActiveTimingItem? = nil, replaceFeeding: Bool = false,
                       sleep: ActiveTimingItem? = nil, replaceSleep: Bool = false) {
        var snapshot = load()
        snapshot.generatedAt = Date()
        if replaceFeeding { snapshot.feeding = feeding }
        if replaceSleep { snapshot.sleep = sleep }
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults(suiteName: appGroupID)?.set(data, forKey: snapshotKey)
    }
}

enum CareRecencyTimeFormatter {
    static func elapsedMinutes(since date: Date?, relativeTo referenceDate: Date) -> Int? {
        guard let date, date <= referenceDate else { return nil }
        return max(Int(referenceDate.timeIntervalSince(date) / 60), 0)
    }

    static func compactText(since date: Date?, relativeTo referenceDate: Date, emptyText: String = "--") -> String {
        guard let minutes = elapsedMinutes(since: date, relativeTo: referenceDate) else {
            return emptyText
        }
        switch minutes {
        case ..<1:
            return "刚刚".localized
        case ..<60:
            return AppLocalization.format("duration.minute.compact", minutes)
        case ..<(24 * 60):
            let hours = minutes / 60
            let remainder = minutes % 60
            return remainder == 0
                ? AppLocalization.format("duration.hour.compact", hours)
                : AppLocalization.format("duration.hour_minute.compact", hours, remainder)
        default:
            let days = minutes / (24 * 60)
            let hours = (minutes % (24 * 60)) / 60
            return hours == 0
                ? AppQuantityFormat.days(days)
                : AppLocalization.format("duration.day_hour.compact", days, hours)
        }
    }

    static func liveCompactText(since date: Date?, relativeTo referenceDate: Date, emptyText: String = "--") -> String {
        guard let minutes = elapsedMinutes(since: date, relativeTo: referenceDate) else {
            return emptyText
        }
        switch minutes {
        case ..<1:
            return "刚刚".localized
        case ..<60:
            return "\(minutes)m"
        case ..<(24 * 60):
            let hours = minutes / 60
            let remainder = minutes % 60
            return remainder == 0 ? "\(hours)h" : "\(hours)h\(remainder)m"
        default:
            let days = minutes / (24 * 60)
            let hours = (minutes % (24 * 60)) / 60
            return hours == 0 ? "\(days)d" : "\(days)d\(hours)h"
        }
    }

    static func lockScreenPrimaryText(
        since date: Date?,
        relativeTo referenceDate: Date,
        emptyText: String = "--"
    ) -> String {
        guard let minutes = elapsedMinutes(since: date, relativeTo: referenceDate) else {
            return emptyText
        }
        switch minutes {
        case ..<1:
            return "刚刚".localized
        case ..<60:
            return "\(minutes)m"
        case ..<(24 * 60):
            let hours = minutes / 60
            let remainder = minutes % 60
            return remainder == 0 ? "\(hours)h" : "\(hours)h\(remainder)m"
        case 24 * 60:
            return "1d"
        default:
            return ">1d"
        }
    }

    static func distanceText(since date: Date?, relativeTo referenceDate: Date, emptyText: String = "暂无") -> String {
        guard let minutes = elapsedMinutes(since: date, relativeTo: referenceDate) else {
            return emptyText
        }
        switch minutes {
        case ..<1:
            return "刚刚".localized
        case ..<60:
            return AppQuantityFormat.minutes(minutes)
        case ..<(24 * 60):
            let hours = minutes / 60
            let remainder = minutes % 60
            return remainder == 0 ? AppQuantityFormat.hours(hours) : AppQuantityFormat.hoursAndMinutes(minutes)
        default:
            let days = minutes / (24 * 60)
            let hours = (minutes % (24 * 60)) / 60
            return hours == 0
                ? AppQuantityFormat.days(days)
                : AppLocalization.format("duration.day_hour", days, hours)
        }
    }
}

#if canImport(ActivityKit)
struct FeedingActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var snapshot: CareRecencySnapshot
        var activeTiming: ActiveTimingSnapshot
        var babyAgeMonths: Int?
    }

    var babyAgeMonths: Int?
}
#endif
