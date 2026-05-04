import Foundation

struct BabyCompanion: Identifiable, Hashable {
    let id: String
    let name: String
    let species: String

    var previewAssetName: String {
        "\(id)_idle"
    }

    func videoName(for action: BabyAction) -> String {
        "\(id)_\(action.rawValue)"
    }
}

enum BabyAction: String, CaseIterable, Identifiable {
    case nursing
    case diaper
    case sleep
    case tap
    case shake

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nursing: return "喝奶"
        case .diaper: return "换尿布"
        case .sleep: return "睡觉"
        case .tap: return "戳一戳"
        case .shake: return "摇一摇"
        }
    }

    var systemImage: String {
        switch self {
        case .nursing: return "drop.fill"
        case .diaper: return "leaf.fill"
        case .sleep: return "moon.stars.fill"
        case .tap: return "hand.tap.fill"
        case .shake: return "iphone.radiowaves.left.and.right"
        }
    }
}

struct ActivityLog: Identifiable {
    let id = UUID()
    let action: BabyAction
    let timestamp: Date
}
