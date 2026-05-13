import SwiftUI

@main
struct BBBApp: App {
    @StateObject private var feedingStore = FeedingStore()
    @StateObject private var feedingDraftStore = FeedingDraftStore()
    @StateObject private var companionStore = CompanionStore()
    @StateObject private var achievementStickerStore = AchievementStickerStore()
    @StateObject private var temperamentStore = TemperamentProfileStore()
    @State private var profileStore = BabyProfileStore.shared
    @StateObject private var activityStore = ActivityStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(feedingStore)
                .environmentObject(feedingDraftStore)
                .environmentObject(companionStore)
                .environmentObject(achievementStickerStore)
                .environmentObject(temperamentStore)
                .environment(profileStore)
                .environmentObject(activityStore)
        }
    }
}
