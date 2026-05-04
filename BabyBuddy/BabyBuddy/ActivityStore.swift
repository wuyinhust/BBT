import Foundation
import SwiftUI

@MainActor
final class ActivityStore: ObservableObject {
    @Published private(set) var logs: [ActivityLog] = []

    func record(_ action: BabyAction) {
        logs.insert(ActivityLog(action: action, timestamp: Date()), at: 0)
    }
}
