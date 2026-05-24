import SwiftUI
import CloudKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = CloudSharingSceneDelegate.self
        return configuration
    }
}

final class CloudSharingSceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(_ windowScene: UIWindowScene, userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        Task { @MainActor in
            await FamilyCloudStore.shared.acceptShare(metadata: cloudKitShareMetadata)
        }
    }
}

@main
struct BBBApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var feedingStore = FeedingStore()
    @StateObject private var feedingDraftStore = FeedingDraftStore()
    @StateObject private var sleepDraftStore = SleepDraftStore()
    @StateObject private var companionStore = CompanionStore()
    @StateObject private var recruitmentStore = CompanionRecruitmentStore.shared
    @StateObject private var achievementStickerStore = AchievementStickerStore()
    @StateObject private var temperamentStore = TemperamentProfileStore()
    @StateObject private var familyCloudStore = FamilyCloudStore.shared
    @State private var profileStore = BabyProfileStore.shared
    @StateObject private var activityStore = ActivityStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    BBBFont.registerFonts()
                }
                .environmentObject(feedingStore)
                .environmentObject(feedingDraftStore)
                .environmentObject(sleepDraftStore)
                .environmentObject(companionStore)
                .environmentObject(recruitmentStore)
                .environmentObject(achievementStickerStore)
                .environmentObject(temperamentStore)
                .environmentObject(familyCloudStore)
                .environment(profileStore)
                .environmentObject(activityStore)
                .task {
                    familyCloudStore.configure(
                        profileStore: profileStore,
                        feedingStore: feedingStore,
                        activityStore: activityStore,
                        achievementStore: achievementStickerStore,
                        companionStore: companionStore,
                        temperamentStore: temperamentStore
                    )
                    await familyCloudStore.bootstrapIfNeeded()
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        Task { await familyCloudStore.syncNow() }
                    }
                }
                .preferredColorScheme(.light)
        }
    }
}
