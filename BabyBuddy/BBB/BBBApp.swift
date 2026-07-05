import SwiftUI
import CloudKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        BBBFont.registerFonts()
        return true
    }

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
    @StateObject private var plusMembershipStore = PlusMembershipStore.shared
    @State private var profileStore = BabyProfileStore.shared
    @StateObject private var activityStore = ActivityStore()
    @StateObject private var growthMetricStore = GrowthMetricStore()
    @StateObject private var easyCycleStore = EasyCycleStore.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(feedingStore)
                .environmentObject(feedingDraftStore)
                .environmentObject(sleepDraftStore)
                .environmentObject(companionStore)
                .environmentObject(recruitmentStore)
                .environmentObject(achievementStickerStore)
                .environmentObject(temperamentStore)
                .environmentObject(familyCloudStore)
                .environmentObject(plusMembershipStore)
                .environment(profileStore)
                .environmentObject(activityStore)
                .environmentObject(growthMetricStore)
                .environmentObject(easyCycleStore)
                .task {
                    #if LOCAL_DEBUG_UNLOCKS
                    LocalDebugTodayDataSeeder.seedTodayIfNeeded(
                        feedingStore: feedingStore,
                        activityStore: activityStore,
                        easyCycleStore: easyCycleStore
                    )
                    #endif
                    await plusMembershipStore.configure()
                    familyCloudStore.configure(
                        profileStore: profileStore,
                        feedingStore: feedingStore,
                        activityStore: activityStore,
                        growthMetricStore: growthMetricStore,
                        achievementStore: achievementStickerStore,
                        companionStore: companionStore,
                        temperamentStore: temperamentStore
                    )
                    await familyCloudStore.bootstrapIfNeeded()
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        Task {
                            await plusMembershipStore.refreshEntitlements()
                            await familyCloudStore.syncNow()
                        }
                    }
                }
                .preferredColorScheme(.light)
        }
    }
}
