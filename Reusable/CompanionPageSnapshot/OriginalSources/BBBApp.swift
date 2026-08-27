import SwiftUI
import CloudKit
import UserNotifications

private enum RetiredFeedingReminderCleanup {
    private static let requestIdentifiers = [
        "bb.local.next-feeding",
        "bb.local.next-feeding.snooze",
        "bb.local.test"
    ]
    private static let categoryIdentifier = "bb.local.feeding.category"

    static func run() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: requestIdentifiers)
        center.removeDeliveredNotifications(withIdentifiers: requestIdentifiers)
        UserDefaults.standard.removeObject(forKey: "local_next_feeding_reminder_enabled_v1")
        UserDefaults.standard.removeObject(forKey: "local_next_feeding_reminder_interval_minutes_v1")

        Task {
            let categories = await center.notificationCategories()
            center.setNotificationCategories(Set(categories.filter {
                $0.identifier != categoryIdentifier
            }))
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        BBBFont.registerFonts()
        RetiredFeedingReminderCleanup.run()
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
        guard AppVariant.isFamilySyncEnabled else { return }
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
    @StateObject private var bbBriefStore = BBBriefStore.shared
    @StateObject private var achievementStickerStore = AchievementStickerStore()
    @StateObject private var temperamentStore = TemperamentProfileStore()
    @StateObject private var familyCloudStore = FamilyCloudStore.shared
    @StateObject private var plusMembershipStore = PlusMembershipStore.shared
    @State private var profileStore = BabyProfileStore.shared
    @StateObject private var activityStore = ActivityStore()
    @StateObject private var growthMetricStore = GrowthMetricStore()
    @StateObject private var easyCycleStore = EasyCycleStore.shared
    @StateObject private var subjectiveStateStore = SubjectiveStateStore.shared
    @StateObject private var feedbackCenter = AppFeedbackCenter.shared
    @State private var foregroundRefreshTask: Task<Void, Never>?
    @State private var bedtimeReminderReconcileTask: Task<Void, Never>?
    @AppStorage(AppAppearanceMode.storageKey) private var appearanceModeRaw = AppAppearanceMode.system.rawValue
    #if DEBUG
    @AppStorage(AppLanguage.auditOverrideKey) private var auditLanguageOverrideRaw = ""
    #endif
    @AppStorage(BedtimeReminderSettings.enabledKey) private var bedtimeReminderEnabled = false
    @AppStorage(BedtimeReminderSettings.lookbackDaysKey) private var bedtimeReminderLookbackDays = BedtimeReminderLookback.sevenDays.rawValue

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
        } else if uiTestScreen?.hasPrefix("settings-") == true {
            SettingsUIAuditHarness(screen: uiTestScreen ?? "settings")
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
        } else if uiTestScreen == "plus" {
            PlusMembershipView()
        } else if uiTestScreen == "voice-record" {
            VoiceRecordView()
        } else if uiTestScreen == "celebration" {
            AppFeedbackUITestHarness()
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

    private var rootLocale: Locale {
        #if DEBUG
        _ = auditLanguageOverrideRaw
        #endif
        return AppLocalization.locale
    }

    var body: some Scene {
        WindowGroup {
            rootContent
                .environmentObject(feedingStore)
                .environmentObject(feedingDraftStore)
                .environmentObject(sleepDraftStore)
                .environmentObject(companionStore)
                .environmentObject(recruitmentStore)
                .environmentObject(bbBriefStore)
                .environmentObject(achievementStickerStore)
                .environmentObject(temperamentStore)
                .environmentObject(familyCloudStore)
                .environmentObject(plusMembershipStore)
                .environment(profileStore)
                .environmentObject(activityStore)
                .environmentObject(growthMetricStore)
                .environmentObject(easyCycleStore)
                .environmentObject(subjectiveStateStore)
                .environmentObject(feedbackCenter)
                .environment(\.locale, rootLocale)
                .appFeedbackHost(feedbackCenter)
                .task {
                    feedbackCenter.setSceneActive(scenePhase == .active)
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
                    if AppVariant.isFamilySyncEnabled {
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
                }
                .onChange(of: scenePhase) { _, phase in
                    feedbackCenter.setSceneActive(phase == .active)
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
                        reconcileBedtimeReminder()
                        guard !Task.isCancelled else { return }
                        await plusMembershipStore.refreshEntitlements()
                        guard !Task.isCancelled else { return }
                        if AppVariant.isFamilySyncEnabled {
                            await familyCloudStore.syncNow()
                        }
                    }
                }
                .onReceive(activityStore.$careRecords) { records in
                    reconcileBedtimeReminder(records: records)
                }
                .onChange(of: bedtimeReminderEnabled) { _, _ in
                    reconcileBedtimeReminder()
                }
                .onChange(of: bedtimeReminderLookbackDays) { _, _ in
                    reconcileBedtimeReminder()
                }
                .onReceive(NotificationCenter.default.publisher(for: Notification.Name.NSSystemTimeZoneDidChange)) { _ in
                    reconcileBedtimeReminder()
                }
                .preferredColorScheme(rootColorScheme)
        }
    }

    @MainActor
    private func reconcileBedtimeReminder(records: [CareRecord]? = nil) {
        guard !isDarkModeDemoLaunch, !isUITestLaunch else { return }
        bedtimeReminderReconcileTask?.cancel()
        let recordSnapshot = records ?? activityStore.careRecords
        let settings = BedtimeReminderSettings(
            isEnabled: bedtimeReminderEnabled,
            lookback: BedtimeReminderLookback(rawValue: bedtimeReminderLookbackDays) ?? .sevenDays
        )
        bedtimeReminderReconcileTask = Task {
            guard !Task.isCancelled else { return }
            await BedtimeReminderCoordinator.reconcile(records: recordSnapshot, settings: settings)
        }
    }
}

#if DEBUG
private struct AppFeedbackUITestHarness: View {
    @EnvironmentObject private var feedbackCenter: AppFeedbackCenter
    @State private var underlyingTapCount = 0
    @State private var didSeedCelebrations = false

    private var queuesTwoRewards: Bool {
        ProcessInfo.processInfo.arguments.contains("-BBUITestRewardQueue")
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [DesignToken.canvas, DesignToken.primarySoft, DesignToken.surfaceSoft],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 22) {
                Text("奖励弹窗测试背景")
                    .font(.title.bold())
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(DesignToken.surfaceRaised)
                    .frame(height: 180)
                    .overlay(Text("毛玻璃后方页面轮廓"))
                Text("底层点击次数 \(underlyingTapCount)")
                    .accessibilityIdentifier("feedback.underlying.count")
            }
            .padding(24)
        }
        .contentShape(Rectangle())
        .onTapGesture { underlyingTapCount += 1 }
        .onAppear(perform: seedCelebrationsIfNeeded)
        .appFeedbackHost(feedbackCenter, isEmbedded: true)
    }

    private func seedCelebrationsIfNeeded() {
        guard !didSeedCelebrations else { return }
        didSeedCelebrations = true
        feedbackCenter.presentReward(
            amount: 1,
            title: "UI 测试奖励 1",
            subtitle: "用于验证触摸、Host 和前后台恢复",
            deduplicationKey: "ui-test-reward-1"
        )
        guard queuesTwoRewards else { return }
        feedbackCenter.presentReward(
            amount: 2,
            title: "UI 测试奖励 2",
            subtitle: "用于验证连续奖励退场间隔",
            deduplicationKey: "ui-test-reward-2"
        )
    }
}
#endif
