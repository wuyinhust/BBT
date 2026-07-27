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
    @StateObject private var subjectiveStateStore = SubjectiveStateStore.shared
    @State private var foregroundRefreshTask: Task<Void, Never>?
    @AppStorage(AppAppearanceMode.storageKey) private var appearanceModeRaw = AppAppearanceMode.system.rawValue

    init() {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-BBUIUnitSystem"),
           arguments.indices.contains(index + 1),
           MeasurementSystemPreference(rawValue: arguments[index + 1]) != nil {
            MeasurementSystemPreference.defaults.set(
                arguments[index + 1],
                forKey: MeasurementSystemPreference.storageKey
            )
        }
        #endif
    }

    private var isDarkModeDemoLaunch: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-BBShowDarkModeDemo")
        #else
        return false
        #endif
    }

    private var uiTestScreen: String? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-BBUITestScreen"),
              arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
        #else
        return nil
        #endif
    }

    private var isUITestLaunch: Bool { uiTestScreen != nil }

    @ViewBuilder
    private var rootContent: some View {
        #if DEBUG
        if isDarkModeDemoLaunch {
            DarkModeDesignDemoView()
        } else if uiTestScreen == "settings" {
            NavigationStack { ProfileView(showsDarkModeDemoEntry: false) }
        } else if uiTestScreen == "buddy" {
            CompanionPickerView(
                isPresented: .constant(true),
                showsCloseButton: false,
                dismissesOnSelection: false
            )
        } else if uiTestScreen == "onboarding-mode" {
            OnboardingView(onComplete: {})
        } else if uiTestScreen == "basic-home" {
            NavigationStack { RecordHomeView(homeMode: .constant(.basic)) }
        } else if uiTestScreen == "easy-home" {
            NavigationStack { RecordHomeView(homeMode: .constant(.easy)) }
        } else if uiTestScreen == "growth-weight" {
            NavigationStack { GrowthMetricEntryView(kind: .weight) }
        } else if uiTestScreen == "feeding" {
            QuickRecordDarkModeDemo()
        } else {
            ContentView()
        }
        #else
        ContentView()
        #endif
    }

    private var rootColorScheme: ColorScheme? {
        #if DEBUG
        if isDarkModeDemoLaunch {
            return nil
        }
        #endif
        return (AppAppearanceMode(rawValue: appearanceModeRaw) ?? .system).preferredColorScheme
    }

    var body: some Scene {
        WindowGroup {
            rootContent
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
                .environmentObject(subjectiveStateStore)
                .environment(\.locale, AppLocalization.locale)
                .task {
                    guard !isDarkModeDemoLaunch, !isUITestLaunch else { return }
                    #if LOCAL_DEBUG_UNLOCKS
                    LocalDebugTodayDataSeeder.seedTodayIfNeeded(
                        feedingStore: feedingStore,
                        activityStore: activityStore,
                        easyCycleStore: easyCycleStore
                    )
                    #endif
                    CareRecencyCoordinator.refresh(
                        feedingSessions: feedingStore.allSessions,
                        careRecords: activityStore.careRecords,
                        babyAgeMonths: profileStore.currentProfile.ageMonths
                    )
                    await plusMembershipStore.configure()
                    familyCloudStore.configure(
                        profileStore: profileStore,
                        feedingStore: feedingStore,
                        activityStore: activityStore,
                        growthMetricStore: growthMetricStore,
                        achievementStore: achievementStickerStore,
                        companionStore: companionStore,
                        temperamentStore: temperamentStore,
                        subjectiveStateStore: subjectiveStateStore
                    )
                    await familyCloudStore.bootstrapIfNeeded()
                }
                .onChange(of: scenePhase) { _, phase in
                    foregroundRefreshTask?.cancel()
                    foregroundRefreshTask = nil
                    guard phase == .active, !isDarkModeDemoLaunch, !isUITestLaunch else {
                        return
                    }
                    foregroundRefreshTask = Task { @MainActor in
                        CareRecencyCoordinator.refresh(
                            feedingSessions: feedingStore.allSessions,
                            careRecords: activityStore.careRecords,
                            babyAgeMonths: profileStore.currentProfile.ageMonths
                        )
                        guard !Task.isCancelled else { return }
                        await plusMembershipStore.refreshEntitlements()
                        guard !Task.isCancelled else { return }
                        await familyCloudStore.syncNow()
                    }
                }
                .preferredColorScheme(rootColorScheme)
        }
    }
}
