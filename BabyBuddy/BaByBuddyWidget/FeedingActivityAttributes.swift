import ActivityKit
import Foundation
import SwiftUI

enum FeedingIntervalStatus: Int, Codable, CaseIterable, Hashable {
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
        guard let months = babyAgeMonths else { return (1.5, 2.5, 4, 5, 6) }
        if months < 1 { return (0.75, 1.25, 2, 3, 4) }
        if months < 3 { return (1, 2, 3, 4, 5) }
        if months < 6 { return (1.5, 2.5, 4, 5, 6) }
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

struct FeedingActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var lastFeedingDate: Date
        var status: FeedingIntervalStatus
    }

    var babyAgeMonths: Int?
}

extension Color {
    init(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        var number: UInt64 = 0
        Scanner(string: value).scanHexInt64(&number)
        self.init(
            .sRGB,
            red: Double((number & 0xFF0000) >> 16) / 255,
            green: Double((number & 0x00FF00) >> 8) / 255,
            blue: Double(number & 0x0000FF) / 255,
            opacity: 1
        )
    }
}
