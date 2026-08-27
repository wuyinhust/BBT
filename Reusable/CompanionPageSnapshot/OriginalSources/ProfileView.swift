import SwiftUI
import UIKit
import UserNotifications
import UniformTypeIdentifiers

struct ProfileSoftBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: backgroundColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    DesignToken.primary.opacity(colorScheme == .dark ? 0.055 : 0.16),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 24,
                endRadius: 340
            )

            RadialGradient(
                colors: [
                    DesignToken.rewardSoft.opacity(colorScheme == .dark ? 0.07 : 0.32),
                    .clear
                ],
                center: .bottomLeading,
                startRadius: 36,
                endRadius: 380
            )
        }
    }

    private var backgroundColors: [Color] {
        if colorScheme == .dark {
            return [
                DesignToken.canvas,
                DesignToken.surface,
                DesignToken.surfaceSoft.opacity(0.90)
            ]
        }

        return [
            DesignToken.canvas,
            DesignToken.surfaceSoft,
            DesignToken.easyActivitySoft.opacity(0.46)
        ]
    }
}

private struct SoftProfileCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    let shadowOpacity: Double

    func body(content: Content) -> some View {
        content
            .appGlassSurface(
                cornerRadius: cornerRadius,
                fillOpacity: 0.90,
                strokeOpacity: 0.78,
                shadowOpacity: shadowOpacity
            )
    }
}

extension View {
    func softProfileCard(cornerRadius: CGFloat, shadowOpacity: Double = 0.06) -> some View {
        modifier(SoftProfileCardModifier(cornerRadius: cornerRadius, shadowOpacity: shadowOpacity))
    }
}

struct ProfileView: View {
    @Environment(BabyProfileStore.self) private var profileStore
    @EnvironmentObject private var membershipStore: PlusMembershipStore
    @State private var showBabyProfile = false
    @State private var showPlus = false
    @State private var showFamilySharing = false
    @State private var showDailyReports = false
    @State private var showTemperamentTest = false
    @State private var appShareRequest: BBBuddyShareRequest?
    @State private var selectedAppIconName: String?
    @State private var appIconError: String?
    @State private var restoreMessage: String?
    @State private var cacheSizeText = "计算中"
    @State private var confirmCacheClear = false

    let showsDarkModeDemoEntry: Bool

    init(showsDarkModeDemoEntry: Bool = true) {
        self.showsDarkModeDemoEntry = showsDarkModeDemoEntry
    }

    var body: some View {
        List {
            babyProfileHeader
            membershipSection
            dataSettingsSection
            generalSettingsSection
            otherSettingsSection
            #if DEBUG
            auditSettingsSection
            #endif
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(ProfileSoftBackground().ignoresSafeArea())
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("设置")
                    .font(BBBFont.scaledFont(size: 17, weight: .bold, relativeTo: .headline, maximumPointSize: 24))
                    .foregroundStyle(DesignToken.textPrimary)
            }
        }
        .accessibilityIdentifier("settings.screen")
        .onAppear {
            selectedAppIconName = UIApplication.shared.alternateIconName
            refreshCacheSize()
        }
        .sheet(isPresented: $showBabyProfile) {
            BabyInfoEditView(isPresented: $showBabyProfile)
        }
        .sheet(isPresented: $showPlus) {
            PlusMembershipView()
        }
        .sheet(isPresented: $showFamilySharing) {
            FamilySharingView()
        }
        .sheet(isPresented: $showDailyReports) {
            BBBriefArchiveView()
        }
        .sheet(isPresented: $showTemperamentTest) {
            OnboardingView(prefillFromProfile: true) { showTemperamentTest = false }
        }
        .sheet(item: $appShareRequest) { request in
            BBBuddySystemShareSheet(activityItems: request.activityItems)
        }
        .alert("更换图标失败", isPresented: Binding(
            get: { appIconError != nil },
            set: { if !$0 { appIconError = nil } }
        )) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(appIconError ?? "")
        }
        .alert("恢复购买", isPresented: Binding(
            get: { restoreMessage != nil },
            set: { if !$0 { restoreMessage = nil } }
        )) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(restoreMessage ?? "")
        }
        .confirmationDialog("清除缓存", isPresented: $confirmCacheClear, titleVisibility: .visible) {
            Button("清除缓存", role: .destructive) { clearCache() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("只清除临时文件，不会删除宝宝资料和照护记录。")
        }
    }

    private var babyProfileHeader: some View {
        let profile = profileStore.currentProfile
        return Button { showBabyProfile = true } label: {
            VStack(spacing: 9) {
                BabyProfileAvatarView(
                    profile: profile,
                    size: 104,
                    emojiSize: 50,
                    lineWidth: 2,
                    motionScale: 0.75
                )
                Text(profile.name)
                    .font(BBBFont.scaledFont(size: 22, weight: .heavy, relativeTo: .title2, maximumPointSize: 32))
                    .foregroundStyle(DesignToken.textPrimary)
                    .lineLimit(1)
                Text(settingsAgeText(for: profile.birthDate))
                    .font(BBBFont.scaledFont(size: 13, weight: .medium, relativeTo: .footnote, maximumPointSize: 20))
                    .foregroundStyle(DesignToken.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 12, trailing: 16))
        .accessibilityLabel(Text("编辑宝宝资料".localized))
    }

    private var membershipSection: some View {
        Section {
            Button { showPlus = true } label: {
                SettingsRowLabel(icon: "crown.fill", tint: DesignToken.primary, title: "会员类型", value: membershipTypeTitle, showsChevron: true)
            }
            .buttonStyle(.plain)

            if AppVariant.isFamilySyncEnabled {
                Button {
                    if membershipStore.isPlusActive { showFamilySharing = true } else { showPlus = true }
                } label: {
                    SettingsRowLabel(
                        icon: "person.2.fill",
                        tint: DesignToken.success,
                        title: "家庭同步",
                        trailingSymbol: membershipStore.isPlusActive ? "chevron.right" : "lock.fill"
                    )
                }
                .buttonStyle(.plain)
            }

            NavigationLink {
                SharePlusCampaignView()
            } label: {
                SettingsRowLabel(icon: "gift.fill", tint: DesignToken.reward, title: "分享领会员")
            }
            .accessibilityIdentifier("settings.sharePlus")

            Button {
                Task {
                    await membershipStore.restorePurchases()
                    restoreMessage = membershipStore.errorMessage ?? "购买记录已检查"
                }
            } label: {
                SettingsRowLabel(
                    icon: "arrow.clockwise",
                    tint: DesignToken.accentBlue,
                    title: "恢复购买",
                    trailingSymbol: isRestoringPurchases ? "hourglass" : "chevron.right"
                )
            }
            .buttonStyle(.plain)
            .disabled(isRestoringPurchases)
        } header: {
            Text("会员")
                .font(BBBFont.scaledFont(size: 12, weight: .bold, relativeTo: .footnote, maximumPointSize: 18))
                .foregroundStyle(DesignToken.primaryGradient)
        }
    }

    private var dataSettingsSection: some View {
        Section {
            Button { showDailyReports = true } label: {
                SettingsRowLabel(icon: "sun.horizon.fill", tint: DesignToken.reward, title: "BBBrief", showsChevron: true)
            }
            .buttonStyle(.plain)

            Button { showTemperamentTest = true } label: {
                SettingsRowLabel(icon: "sparkles", tint: DesignToken.primary, title: "气质测试", showsChevron: true)
            }
            .buttonStyle(.plain)

            NavigationLink {
                DataManagementView()
            } label: {
                SettingsRowLabel(icon: "externaldrive.fill", tint: DesignToken.accentBlue, title: "数据导入导出")
            }
            .accessibilityIdentifier("settings.dataManagement")

            Button { confirmCacheClear = true } label: {
                SettingsRowLabel(icon: "trash.fill", tint: .red, title: "清除缓存", value: cacheSizeText)
            }
            .buttonStyle(.plain)
        } header: {
            SettingsSectionHeader(title: "数据")
        }
    }

    private var generalSettingsSection: some View {
        Section {
            NavigationLink { LanguagePreferenceView() } label: {
                SettingsRowLabel(icon: AppSemanticIcon.language, tint: DesignToken.accentBlue, title: "界面语言", value: AppLanguage.current.displayName)
            }
            .accessibilityIdentifier("settings.currentLanguage")

            NavigationLink { MeasurementPreferenceView() } label: {
                SettingsRowLabel(icon: AppSemanticIcon.measurement, tint: DesignToken.easyActivity, title: "单位偏好")
            }
            .accessibilityIdentifier("settings.measurementSystem")

            NavigationLink { GrowthStandardSettingsView() } label: {
                SettingsRowLabel(icon: "chart.xyaxis.line", tint: DesignToken.success, title: "生长标准")
            }
            .accessibilityIdentifier("settings.growthStandard")

            NavigationLink { AppearancePreferenceView() } label: {
                SettingsRowLabel(icon: "circle.lefthalf.filled", tint: DesignToken.primary, title: "外观设置")
            }
            .accessibilityIdentifier("settings.appearance")

            NavigationLink { MotionFeedbackSettingsView() } label: {
                SettingsRowLabel(icon: "bolt.fill", tint: DesignToken.reward, title: "动效开关")
            }
            .accessibilityIdentifier("settings.motion")

            NavigationLink { AppleReminderSettingsView() } label: {
                SettingsRowLabel(icon: "bell.badge.fill", tint: DesignToken.accentBlue, title: "提醒通知")
            }
            .accessibilityIdentifier("settings.reminders")

            NavigationLink { WidgetGuideView(kind: .homeScreen) } label: {
                SettingsRowLabel(icon: "square.grid.2x2.fill", tint: DesignToken.success, title: "小组件")
            }

            NavigationLink { WidgetGuideView(kind: .lockScreen) } label: {
                SettingsRowLabel(icon: "lock.square.fill", tint: DesignToken.primary, title: "锁屏组件")
            }

            appIconPicker
        } header: {
            SettingsSectionHeader(title: "通用")
        }
    }

    private var otherSettingsSection: some View {
        Section {
            NavigationLink { BBBuddyPrivacyPolicyView() } label: {
                SettingsRowLabel(icon: "hand.raised.fill", tint: DesignToken.success, title: "隐私条款")
            }
            .accessibilityIdentifier("settings.privacyPolicy")

            NavigationLink { BBBuddyTermsOfUseView() } label: {
                SettingsRowLabel(icon: "doc.text.fill", tint: DesignToken.primary, title: "使用条款")
            }
            .accessibilityIdentifier("settings.termsOfUse")

            Button { appShareRequest = BBBuddyShareRequest() } label: {
                SettingsRowLabel(icon: "square.and.arrow.up", tint: DesignToken.accentBlue, title: "分享 APP 给朋友", showsChevron: true)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("settings.shareApp")

            SettingsRowLabel(icon: "info.circle.fill", tint: DesignToken.textSecondary, title: "关于", value: conciseVersionText)
                .accessibilityElement(children: .combine)
        } header: {
            SettingsSectionHeader(title: "其他")
        }
    }

    #if DEBUG
    private var auditSettingsSection: some View {
        Section {
            NavigationLink {
                SettingsUIAuditControlPanel()
            } label: {
                SettingsRowLabel(
                    icon: "checkmark.rectangle.stack.fill",
                    tint: DesignToken.accentBlue,
                    title: "UI Audit"
                )
            }
            .accessibilityIdentifier("settings.uiAudit")
        } header: {
            Text("DEBUG")
        }
    }
    #endif

    private var appIconPicker: some View {
        VStack(alignment: .leading, spacing: 13) {
            Label {
                Text("应用图标")
                    .font(BBBFont.scaledFont(size: 14, weight: .bold, relativeTo: .body, maximumPointSize: 22))
            } icon: {
                SettingsIcon(systemName: "app.badge.fill", tint: DesignToken.primary)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(SettingsAppIconOption.allCases) { option in appIconButton(option) }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(.vertical, 4)
    }

    private func appIconButton(_ option: SettingsAppIconOption) -> some View {
        let isSelected = selectedAppIconName == option.iconName
        let isLocked = !membershipStore.isPlusActive && !option.isFree
        return Button {
            if isLocked { showPlus = true } else { setAppIcon(option) }
        } label: {
            VStack(spacing: 7) {
                ZStack(alignment: .topTrailing) {
                    Image(option.assetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 58, height: 58)
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .stroke(isSelected ? DesignToken.primary : Color.secondary.opacity(0.18), lineWidth: isSelected ? 2.5 : 1)
                        }
                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 23, height: 23)
                            .background(Circle().fill(DesignToken.primary))
                            .offset(x: 6, y: -6)
                    }
                }
                Text(option.title.localized)
                    .font(BBBFont.scaledFont(size: 11, weight: .medium, relativeTo: .caption1, maximumPointSize: 17))
                    .foregroundStyle(isSelected ? DesignToken.primary : DesignToken.textSecondary)
            }
            .frame(width: 72)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(option.title.localized))
        .accessibilityValue(
            Text((isLocked ? "会员专享" : (isSelected ? "当前使用" : "可选择")).localized)
        )
    }

    private var membershipTypeTitle: String {
        switch membershipStore.activePlan {
        case .monthly: return "月度会员"
        case .yearly: return "年度会员"
        case .lifetime: return "永久会员"
        case nil: return membershipStore.isShareRewardActive ? "月度会员" : "免费会员"
        }
    }

    private var isRestoringPurchases: Bool { membershipStore.purchaseState == .refreshing }

    private var conciseVersionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "v\(version)(\(build))"
    }

    private func settingsAgeText(for birthDate: Date) -> String {
        BabyAgeFormatter.displayText(birthDate: birthDate, on: Date())
    }

    private func setAppIcon(_ option: SettingsAppIconOption) {
        guard UIApplication.shared.supportsAlternateIcons else {
            appIconError = "当前设备不支持更换应用图标。"
            return
        }
        guard UIApplication.shared.alternateIconName != option.iconName else { return }
        UIApplication.shared.setAlternateIconName(option.iconName) { error in
            DispatchQueue.main.async {
                if let error { appIconError = error.localizedDescription }
                else { selectedAppIconName = option.iconName }
            }
        }
    }

    private func refreshCacheSize() { cacheSizeText = SettingsCacheManager.formattedSize() }
    private func clearCache() {
        SettingsCacheManager.clear()
        refreshCacheSize()
    }
}

private struct SettingsRowLabel: View {
    let icon: String
    let tint: Color
    let title: String
    var value: String? = nil
    var trailingSymbol: String? = nil
    var showsChevron = false

    var body: some View {
        HStack(spacing: 12) {
            SettingsIcon(systemName: icon, tint: tint)
            Text(title.localized)
                .font(BBBFont.scaledFont(size: 14, weight: .bold, relativeTo: .headline, maximumPointSize: 22))
                .foregroundStyle(DesignToken.textPrimary)
            Spacer(minLength: 8)
            if let value {
                Text(value.localized)
                    .font(BBBFont.scaledFont(size: 11, weight: .medium, relativeTo: .subheadline, maximumPointSize: 18))
                    .foregroundStyle(DesignToken.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            if let trailingSymbol {
                Image(systemName: trailingSymbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DesignToken.textSecondary)
                    .frame(width: 14)
            } else if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DesignToken.textSecondary.opacity(0.7))
            }
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(accessibilityLabel))
    }

    private var accessibilityLabel: String {
        [title.localized, value?.localized]
            .compactMap { $0 }
            .joined(separator: ", ")
    }
}

private struct SettingsSectionHeader: View {
    let title: LocalizedStringKey

    var body: some View {
        Text(title)
            .font(BBBFont.scaledFont(size: 12, weight: .bold, relativeTo: .footnote, maximumPointSize: 18))
            .foregroundStyle(DesignToken.textSecondary)
    }
}

private struct SettingsIcon: View {
    let systemName: String
    let tint: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(tint)
            .frame(width: 29, height: 29)
            .overlay {
                Image(systemName: systemName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }
    }
}

private enum SettingsAppIconOption: String, CaseIterable, Identifiable {
    case primary, alt1, alt2, alt3, alt4, alt5, alt6, alt7

    var id: String { rawValue }
    var isFree: Bool { self == .primary || self == .alt1 }

    var title: String {
        switch self {
        case .primary: return "默认图标"
        case .alt1: return "图标一"
        case .alt2: return "图标二"
        case .alt3: return "图标三"
        case .alt4: return "图标四"
        case .alt5: return "图标五"
        case .alt6: return "图标六"
        case .alt7: return "图标七"
        }
    }

    var iconName: String? {
        switch self {
        case .primary: return nil
        case .alt1: return "AppIconAlt1"
        case .alt2: return "AppIconAlt2"
        case .alt3: return "AppIconAlt3"
        case .alt4: return "AppIconAlt4"
        case .alt5: return "AppIconAlt5"
        case .alt6: return "AppIconAlt6"
        case .alt7: return "AppIconAlt7"
        }
    }

    var assetName: String {
        switch self {
        case .primary: return "SettingsIconPrimary"
        case .alt1: return "SettingsIconAlt1"
        case .alt2: return "SettingsIconAlt2"
        case .alt3: return "SettingsIconAlt3"
        case .alt4: return "SettingsIconAlt4"
        case .alt5: return "SettingsIconAlt5"
        case .alt6: return "SettingsIconAlt6"
        case .alt7: return "SettingsIconAlt7"
        }
    }
}

private enum SettingsCacheManager {
    static func formattedSize() -> String {
        ByteCountFormatter.string(fromByteCount: cacheSize(), countStyle: .file)
    }

    static func clear() {
        URLCache.shared.removeAllCachedResponses()
        guard let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first,
              let contents = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return }
        for url in contents {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private static func cacheSize() -> Int64 {
        guard let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first,
              let enumerator = FileManager.default.enumerator(
                at: directory,
                includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
                options: [.skipsHiddenFiles]
              ) else { return 0 }

        var total: Int64 = 0
        for case let url as URL in enumerator {
            guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                  values.isRegularFile == true else { continue }
            total += Int64(values.fileSize ?? 0)
        }
        return total
    }
}

private struct LegacyProfileView: View {
    @EnvironmentObject private var feedingStore: FeedingStore
    @EnvironmentObject private var activityStore: ActivityStore
    @EnvironmentObject private var growthMetricStore: GrowthMetricStore
    @EnvironmentObject private var membershipStore: PlusMembershipStore
    @State private var showFamilySharing = false
    @State private var showPlusMembership = false
    @State private var showLocalBabyInfo = false
    @State private var activeGrowthMetric: GrowthMetricKind?
    @State private var showDailyVisitors = false
    @State private var showOnboarding = false
    @State private var showDarkModeDemo = false
    @State private var appShareRequest: BBBuddyShareRequest?
    @AppStorage(AppAppearanceMode.storageKey) private var appearanceModeRaw = AppAppearanceMode.system.rawValue
    @AppStorage("buddy_card_reduced_effects_enabled") private var reducedBuddyCardEffects = false
    @AppStorage(
        MeasurementSystemPreference.storageKey,
        store: MeasurementSystemPreference.defaults
    ) private var measurementPreferenceRaw = MeasurementSystemPreference.followRegion.rawValue
    @AppStorage(
        GrowthStandardPreference.storageKey,
        store: GrowthStandardPreference.defaults
    ) private var growthStandardPreferenceRaw = GrowthStandardPreference.automatic.rawValue
    @AppStorage(BedtimeReminderSettings.enabledKey) private var bedtimeReminderEnabled = false
    private let showsDarkModeDemoEntry: Bool

    init(showsDarkModeDemoEntry: Bool = true) {
        self.showsDarkModeDemoEntry = showsDarkModeDemoEntry
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                BabyInfoHeaderView(
                    onOpenProfile: {
                        showLocalBabyInfo = true
                    },
                    onOpenMetric: { kind in
                        activeGrowthMetric = kind
                    }
                )

                preferenceSection
                familySection
                buddySection
                dataSection
                legalAndSharingSection
                #if DEBUG
                if showsDarkModeDemoEntry {
                    developmentSection
                }
                #endif
                aboutCard
                Spacer(minLength: 72)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 88)
        }
        .accessibilityIdentifier("settings.screen")
        .background(ProfileSoftBackground().ignoresSafeArea())
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $activeGrowthMetric) { kind in
            GrowthMetricSheet(kind: kind)
                .toolbar(.hidden, for: .tabBar)
                .presentationBackground(DesignToken.surfaceSoft)
        }
        .sheet(isPresented: $showFamilySharing) {
            FamilySharingView()
        }
        .sheet(isPresented: $showPlusMembership) {
            PlusMembershipView()
        }
        .sheet(isPresented: $showLocalBabyInfo) {
            BabyInfoEditView(isPresented: $showLocalBabyInfo)
        }
        .sheet(isPresented: $showDailyVisitors) {
            BBBriefArchiveView()
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView(prefillFromProfile: true) {
                showOnboarding = false
            }
        }
        .sheet(item: $appShareRequest) { request in
            BBBuddySystemShareSheet(activityItems: request.activityItems)
        }
        #if DEBUG
        .fullScreenCover(isPresented: $showDarkModeDemo) {
            DarkModeDesignDemoView()
        }
        #endif
    }

    private var familySection: some View {
        settingsSection("家庭与会员") {
            if AppVariant.isFamilySyncEnabled {
                Button {
                    if membershipStore.isPlusActive {
                        showFamilySharing = true
                    } else {
                        showPlusMembership = true
                    }
                } label: {
                    settingsActionRow(
                        icon: "person.2.fill",
                        color: DesignToken.success,
                        title: "家庭共享",
                        subtitle: familySharingSubtitle
                    )
                }
                .buttonStyle(.plain)

                settingsDivider
            }

            Button {
                showPlusMembership = true
            } label: {
                settingsActionRow(
                    icon: "sparkles",
                    color: DesignToken.primary,
                    title: "BBBuddy Plus",
                    subtitle: membershipStore.profileSubtitle
                )
            }
            .buttonStyle(.plain)

        }
    }

    private var preferenceSection: some View {
        settingsSection("常用设置") {
            NavigationLink {
                GeneralPreferenceSettingsView()
            } label: {
                settingsActionRow(
                    icon: "slider.horizontal.3",
                    color: DesignToken.accentBlue,
                    title: "语言、单位与生长标准",
                    subtitle: generalPreferenceSummary
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("settings.generalPreferences")

            settingsDivider

            NavigationLink {
                AppearanceSettingsView()
            } label: {
                settingsActionRow(
                    icon: "circle.lefthalf.filled",
                    color: DesignToken.primary,
                    title: "外观与动效",
                    subtitle: appearancePreferenceSummary
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("settings.appearanceAndMotion")

            settingsDivider

            NavigationLink {
                ReminderSettingsView()
            } label: {
                settingsActionRow(
                    icon: "bell.badge.fill",
                    color: DesignToken.accentBlue,
                    title: "提醒设置",
                    subtitle: reminderPreferenceSummary
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("settings.reminders")
        }
    }

    private var buddySection: some View {
        settingsSection("Buddy 与报告") {
            Button {
                showDailyVisitors = true
            } label: {
                settingsActionRow(
                    icon: "sunrise.fill",
                    color: DesignToken.reward,
                    title: "BBBrief",
                    subtitle: "查看照护节奏与每日分析"
                )
            }
            .buttonStyle(.plain)

            settingsDivider

            Button {
                showOnboarding = true
            } label: {
                settingsActionRow(
                    icon: "wand.and.stars",
                    color: DesignToken.primary,
                    title: "气质测试与 Buddy",
                    subtitle: "重新测试或选择陪伴伙伴"
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var dataSection: some View {
        settingsSection("数据") {
            NavigationLink {
                DataManagementView()
            } label: {
                settingsActionRow(
                    icon: "externaldrive.fill",
                    color: DesignToken.accentBlue,
                    title: "数据管理",
                    subtitle: "\(exportSubtitle) · 支持导入与导出"
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("settings.dataManagement")
        }
    }

    private var legalAndSharingSection: some View {
        settingsSection(BBBuddyLegalCopy.legalAndSharingTitle) {
            Button {
                appShareRequest = BBBuddyShareRequest()
            } label: {
                settingsActionRow(
                    icon: "square.and.arrow.up",
                    color: DesignToken.accentBlue,
                    title: BBBuddyLegalCopy.shareAppTitle,
                    subtitle: BBBuddyLegalCopy.shareAppSubtitle,
                    trailingSystemName: "square.and.arrow.up"
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("settings.shareApp")

            settingsDivider

            NavigationLink {
                BBBuddyPrivacyPolicyView()
            } label: {
                settingsActionRow(
                    icon: "hand.raised.fill",
                    color: DesignToken.success,
                    title: BBBuddyLegalCopy.privacyTitle,
                    subtitle: BBBuddyLegalCopy.privacySubtitle
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("settings.privacyPolicy")

            settingsDivider

            NavigationLink {
                BBBuddyTermsOfUseView()
            } label: {
                settingsActionRow(
                    icon: "doc.text.fill",
                    color: DesignToken.primary,
                    title: BBBuddyLegalCopy.termsTitle,
                    subtitle: BBBuddyLegalCopy.termsSubtitle
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("settings.termsOfUse")
        }
    }

    #if DEBUG
    private var developmentSection: some View {
        settingsSection("设计验证") {
            Button {
                showDarkModeDemo = true
            } label: {
                settingsActionRow(
                    icon: "circle.lefthalf.filled",
                    color: DesignToken.primary,
                    title: "深色模式样板",
                    subtitle: "首页 · 快捷记录 · 设置，仅读取不保存"
                )
            }
            .buttonStyle(.plain)
        }
    }
    #endif

    private var aboutCard: some View {
        HStack(spacing: 12) {
            settingsIcon("heart.fill", color: DesignToken.primary)

            VStack(alignment: .leading, spacing: 3) {
                Text("BBBuddy")
                    .font(BBBFont.font(size: 14, weight: .bold))
                    .foregroundStyle(DesignToken.textPrimary)
                Text("宝宝照护与成长记录 · \(AppVariant.versionText)")
                    .font(BBBFont.font(size: 11, weight: .medium))
                    .foregroundStyle(DesignToken.textSecondary)
            }

            Spacer(minLength: 8)

            if !AppVariant.isAppStoreReview {
                Text("测试版")
                    .font(BBBFont.font(size: 9, weight: .bold))
                    .foregroundStyle(DesignToken.primary)
                    .padding(.horizontal, 8)
                    .frame(height: 24)
                    .background(Capsule().fill(DesignToken.primary.opacity(0.10)))
            }
        }
        .padding(14)
        .softProfileCard(cornerRadius: 20, shadowOpacity: 0.035)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(AppVariant.profileVersionText)
    }

    private func settingsSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.localized)
                .font(BBBFont.font(size: 12, weight: .bold))
                .foregroundStyle(DesignToken.textSecondary)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                content()
            }
            .softProfileCard(cornerRadius: 20, shadowOpacity: 0.045)
        }
    }

    private func settingsActionRow(
        icon: String,
        color: Color,
        title: String,
        subtitle: String,
        trailingSystemName: String = "chevron.right"
    ) -> some View {
        HStack(spacing: 12) {
            settingsIcon(icon, color: color)

            VStack(alignment: .leading, spacing: 3) {
                Text(title.localized)
                    .font(BBBFont.scaledFont(size: 14, weight: .bold, relativeTo: .headline, maximumPointSize: 22))
                    .foregroundStyle(DesignToken.textPrimary)
                Text(subtitle.localized)
                    .font(BBBFont.scaledFont(size: 11, weight: .medium, relativeTo: .subheadline, maximumPointSize: 18))
                    .foregroundStyle(DesignToken.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Image(systemName: trailingSystemName)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(DesignToken.textSecondary.opacity(0.55))
                .frame(width: 24, height: 44)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 64)
        .contentShape(Rectangle())
    }

    private func settingsControlHeader(
        icon: String,
        color: Color,
        title: String,
        subtitle: String
    ) -> some View {
        HStack(spacing: 12) {
            settingsIcon(icon, color: color)

            VStack(alignment: .leading, spacing: 3) {
                Text(title.localized)
                    .font(BBBFont.scaledFont(size: 14, weight: .bold, relativeTo: .headline, maximumPointSize: 22))
                    .foregroundStyle(DesignToken.textPrimary)
                Text(subtitle.localized)
                    .font(BBBFont.scaledFont(size: 11, weight: .medium, relativeTo: .subheadline, maximumPointSize: 18))
                    .foregroundStyle(DesignToken.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func settingsIcon(_ systemName: String, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(color.opacity(0.11))
            .frame(width: 36, height: 36)
            .overlay(
                Image(systemName: systemName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(color)
            )
    }

    private var settingsDivider: some View {
        Rectangle()
            .fill(DesignToken.line.opacity(0.40))
            .frame(height: 1)
            .padding(.leading, 62)
    }

    private var exportSubtitle: String {
        let feedingCount = feedingStore.exportSessions().count
        let careCount = activityStore.exportCareRecords().count
        let growthCount = growthMetricStore.exportRecords().count
        return AppLocalization.format("profile.export.summary", feedingCount, careCount, growthCount)
    }

    private var familySharingSubtitle: String {
        (membershipStore.isPlusActive ? "邀请另一位家长共同记录" : "Plus 权益 · 家庭共同记录").localized
    }

    private var generalPreferenceSummary: String {
        let measurement = MeasurementSystemPreference(rawValue: measurementPreferenceRaw) ?? .followRegion
        let measurementSummary = measurement == .followRegion
            ? AppMeasurementFormat.preferenceSummary
            : measurement.title
        return "\(AppLanguage.current.displayName) · \(measurementSummary) · \(growthStandardPreferenceSummary)"
    }

    private var appearancePreferenceSummary: String {
        let mode = AppAppearanceMode(rawValue: appearanceModeRaw) ?? .system
        return reducedBuddyCardEffects ? "\(mode.title) · 已减少动效" : mode.title
    }

    private var reminderPreferenceSummary: String {
        bedtimeReminderEnabled ? "预计入睡提醒已开启" : "预计入睡提醒未开启"
    }

    private var selectedGrowthStandard: GrowthReferenceStandard {
        (GrowthStandardPreference(rawValue: growthStandardPreferenceRaw) ?? .automatic).resolvedStandard
    }

    private var growthStandardPreferenceSummary: String {
        let preference = GrowthStandardPreference(rawValue: growthStandardPreferenceRaw) ?? .automatic
        switch preference {
        case .automatic:
            return "跟随地区 · \(selectedGrowthStandard.shortTitle)"
        case .who2006, .chinaNHC2022:
            return selectedGrowthStandard.title
        }
    }

}

#if DEBUG
struct SettingsUIAuditHarness: View {
    let screen: String

    var body: some View {
        NavigationStack {
            SettingsUIAuditPage(screen: screen)
        }
    }
}

private struct SettingsUIAuditPage: View {
    let screen: String

    @AppStorage(AppLanguage.auditOverrideKey) private var languageRaw = AppLanguage.english.rawValue
    @AppStorage(AppAppearanceMode.storageKey) private var appearanceRaw = AppAppearanceMode.system.rawValue

    private var locale: Locale {
        Locale(identifier: AppLanguage(rawValue: languageRaw)?.rawValue ?? AppLanguage.english.rawValue)
    }

    private var colorScheme: ColorScheme? {
        (AppAppearanceMode(rawValue: appearanceRaw) ?? .system).preferredColorScheme
    }

    var body: some View {
        SettingsUIAuditContent(screen: screen)
            .environment(\.locale, locale)
            .preferredColorScheme(colorScheme)
    }
}

private struct SettingsUIAuditContent: View {
    let screen: String

    @ViewBuilder
    var body: some View {
        switch screen {
            case "settings-baby-profile":
                BabyInfoEditView(isPresented: .constant(true))
            case "settings-family-sharing":
                if AppVariant.isFamilySyncEnabled {
                    FamilySharingView()
                } else {
                    ProfileView(showsDarkModeDemoEntry: false)
                }
            case "settings-daily-reports":
                BBBriefArchiveView()
            case "settings-share-plus":
                SharePlusCampaignView()
            case "settings-data-management":
                DataManagementView()
            case "settings-language":
                LanguagePreferenceView()
            case "settings-measurement":
                MeasurementPreferenceView()
            case "settings-growth-standard":
                GrowthStandardSettingsView()
            case "settings-appearance":
                AppearancePreferenceView()
            case "settings-motion":
                MotionFeedbackSettingsView()
            case "settings-reminders":
                AppleReminderSettingsView()
            case "settings-widget-home":
                WidgetGuideView(kind: .homeScreen)
            case "settings-widget-lock":
                WidgetGuideView(kind: .lockScreen)
            case "settings-privacy":
                BBBuddyPrivacyPolicyView()
            case "settings-terms":
                BBBuddyTermsOfUseView()
            case "audit-home-basic":
                SettingsUIAuditRootSurface {
                    NavigationStack { RecordHomeView(homeMode: .constant(.basic)) }
                }
            case "audit-home-easy":
                SettingsUIAuditRootSurface {
                    NavigationStack { RecordHomeView(homeMode: .constant(.easy)) }
                }
            case "audit-y-picker":
                SettingsUIAuditRootSurface {
                    SubjectiveStatePickerSheet(context: .manual())
                }
            case "audit-y-detail":
                SettingsUIAuditRootSurface {
                    SubjectiveStateDetailView()
                }
            case "audit-buddy-live":
                SettingsUIAuditRootSurface {
                    CompanionLiveView()
                }
            case "audit-buddy-picker":
                SettingsUIAuditRootSurface {
                    CompanionPickerView(
                        isPresented: .constant(true),
                        showsCloseButton: false,
                        dismissesOnSelection: false
                    )
                }
            case "audit-buddy-current-detail":
                SettingsUIAuditRootSurface {
                    SettingsUIAuditBuddyCurrentDetail()
                }
            case "audit-buddy-bucks":
                SettingsUIAuditRootSurface {
                    BBBucksHistoryView()
                }
            case "audit-growth-home":
                SettingsUIAuditRootSurface {
                    NavigationStack { MyPageView() }
                }
            case "audit-growth-height":
                SettingsUIAuditRootSurface {
                    NavigationStack { GrowthMetricEntryView(kind: .height) }
                }
            case "audit-growth-weight":
                SettingsUIAuditRootSurface {
                    NavigationStack { GrowthMetricEntryView(kind: .weight) }
                }
            case "audit-plus":
                SettingsUIAuditRootSurface {
                    PlusMembershipView()
                }
            case "audit-onboarding-hook":
                SettingsUIAuditRootSurface {
                    OnboardingView(onComplete: {})
                }
            default:
                ProfileView(showsDarkModeDemoEntry: false)
        }
    }
}

private struct SettingsUIAuditRootSurface<Content: View>: View {
    @Environment(\.dismiss) private var dismiss
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .overlay(alignment: .topLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(DesignToken.textPrimary)
                        .frame(width: DesignToken.minimumTapSize, height: DesignToken.minimumTapSize)
                        .background(.ultraThinMaterial, in: Circle())
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("uiAudit.back")
                .padding(.top, 44)
                .zIndex(999)
            }
    }
}

private struct SettingsUIAuditBuddyCurrentDetail: View {
    @EnvironmentObject private var companionStore: CompanionStore

    var body: some View {
        let companion = companionStore.selected

        CompanionDetailOverlay(
            companion: companion,
            selectedCompanion: .constant(companion)
        )
        .accessibilityIdentifier("uiAudit.buddy.currentDetail")
    }
}

private struct SettingsUIAuditControlPanel: View {
    @AppStorage(AppLanguage.auditOverrideKey) private var languageRaw = ""
    @AppStorage(AppAppearanceMode.storageKey) private var appearanceRaw = AppAppearanceMode.system.rawValue

    private let pages: [(title: String, screen: String)] = [
        ("Baby Profile", "settings-baby-profile"),
        ("Family Sharing", "settings-family-sharing"),
        ("Daily Reports", "settings-daily-reports"),
        ("Share Plus", "settings-share-plus"),
        ("Data Management", "settings-data-management"),
        ("App Language", "settings-language"),
        ("Unit Preferences", "settings-measurement"),
        ("Growth Standard", "settings-growth-standard"),
        ("Appearance", "settings-appearance"),
        ("Motion", "settings-motion"),
        ("Reminders", "settings-reminders"),
        ("Home Widget", "settings-widget-home"),
        ("Lock Screen Widget", "settings-widget-lock"),
        ("Privacy", "settings-privacy"),
        ("Terms", "settings-terms"),
        ("Basic Home", "audit-home-basic"),
        ("EASY Home", "audit-home-easy"),
        ("Y State Picker", "audit-y-picker"),
        ("Y State Detail", "audit-y-detail"),
        ("Buddy Scene", "audit-buddy-live"),
        ("Buddy Picker", "audit-buddy-picker"),
        ("Buddy Current Detail", "audit-buddy-current-detail"),
        ("BB Bucks", "audit-buddy-bucks"),
        ("Growth Home", "audit-growth-home"),
        ("Height Entry", "audit-growth-height"),
        ("Weight Entry", "audit-growth-weight"),
        ("Plus", "audit-plus"),
        ("Onboarding Hook", "audit-onboarding-hook")
    ]

    var body: some View {
        Form {
            Section("Language") {
                Picker("Language", selection: $languageRaw) {
                    Text("English").tag(AppLanguage.english.rawValue)
                    Text("简体").tag(AppLanguage.simplifiedChinese.rawValue)
                    Text("繁體").tag(AppLanguage.traditionalChinese.rawValue)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("uiAudit.language")
            }

            Section("Appearance") {
                Picker("Appearance", selection: $appearanceRaw) {
                    Text("System").tag(AppAppearanceMode.system.rawValue)
                    Text("Light").tag(AppAppearanceMode.light.rawValue)
                    Text("Dark").tag(AppAppearanceMode.dark.rawValue)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("uiAudit.appearance")
            }

            Section("Pages") {
                ForEach(pages, id: \.screen) { page in
                    NavigationLink {
                        SettingsUIAuditPage(screen: page.screen)
                    } label: {
                        Text(page.title)
                    }
                    .accessibilityIdentifier("uiAudit.screen.\(page.screen)")
                }
            }
        }
        .navigationTitle("UI Audit")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme((AppAppearanceMode(rawValue: appearanceRaw) ?? .system).preferredColorScheme)
        .onAppear {
            if AppLanguage(rawValue: languageRaw) == nil {
                languageRaw = AppLanguage.current.rawValue
            }
        }
    }
}
#endif

private struct LanguagePreferenceView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        Form {
            Section {
                Button {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    openURL(url)
                } label: {
                    SettingsRowLabel(
                        icon: AppSemanticIcon.language,
                        tint: DesignToken.accentBlue,
                        title: "当前语言",
                        value: AppLanguage.current.displayName,
                        showsChevron: true
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .scrollContentBackground(.hidden)
        .background(ProfileSoftBackground().ignoresSafeArea())
        .navigationTitle("界面语言")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct MeasurementPreferenceView: View {
    @AppStorage(
        MeasurementSystemPreference.storageKey,
        store: MeasurementSystemPreference.defaults
    ) private var selectedRaw = MeasurementSystemPreference.followRegion.rawValue

    var body: some View {
        Form {
            Section {
                ForEach(MeasurementSystemPreference.allCases) { option in
                    Button { selectedRaw = option.rawValue } label: {
                        SettingsSelectionRow(title: option.title, isSelected: selectedRaw == option.rawValue)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selectedRaw == option.rawValue ? .isSelected : [])
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(ProfileSoftBackground().ignoresSafeArea())
        .navigationTitle("单位偏好")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct GrowthStandardSettingsView: View {
    @AppStorage(
        GrowthStandardPreference.storageKey,
        store: GrowthStandardPreference.defaults
    ) private var selectedRaw = GrowthStandardPreference.automatic.rawValue

    var body: some View {
        Form {
            Section {
                ForEach(GrowthStandardPreference.allCases) { option in
                    Button { selectedRaw = option.rawValue } label: {
                        SettingsSelectionRow(title: option.title, isSelected: selectedRaw == option.rawValue)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selectedRaw == option.rawValue ? .isSelected : [])
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(ProfileSoftBackground().ignoresSafeArea())
        .navigationTitle("生长标准")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AppearancePreferenceView: View {
    @AppStorage(AppAppearanceMode.storageKey) private var selectedRaw = AppAppearanceMode.system.rawValue

    var body: some View {
        Form {
            Section {
                ForEach(AppAppearanceMode.allCases) { option in
                    Button { selectedRaw = option.rawValue } label: {
                        SettingsSelectionRow(title: option.title, isSelected: selectedRaw == option.rawValue)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selectedRaw == option.rawValue ? .isSelected : [])
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(ProfileSoftBackground().ignoresSafeArea())
        .navigationTitle("外观设置")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct MotionFeedbackSettingsView: View {
    @AppStorage("buddy_card_reduced_effects_enabled") private var reducedMotion = false
    @AppStorage(AppHapticPreference.storageKey) private var hapticsEnabled = true

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $reducedMotion) {
                    Label {
                        Text("减少动效")
                    } icon: {
                        SettingsIcon(systemName: "bolt.slash.fill", tint: DesignToken.reward)
                    }
                }
                .tint(DesignToken.primary)

                Toggle(isOn: $hapticsEnabled) {
                    Label {
                        Text("触觉反馈")
                    } icon: {
                        SettingsIcon(systemName: "hand.tap.fill", tint: DesignToken.accentBlue)
                    }
                }
                .tint(DesignToken.primary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(ProfileSoftBackground().ignoresSafeArea())
        .navigationTitle("动效开关")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AppleReminderSettingsView: View {
    @Environment(\.openURL) private var openURL
    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @State private var showPermissionAlert = false
    @AppStorage(BedtimeReminderSettings.enabledKey) private var reminderEnabled = false
    @AppStorage(BedtimeReminderSettings.lookbackDaysKey) private var lookbackDays = BedtimeReminderLookback.sevenDays.rawValue

    var body: some View {
        Form {
            Section {
                Toggle(isOn: reminderToggleBinding) {
                    Label {
                        Text("入睡提醒")
                    } icon: {
                        SettingsIcon(systemName: "moon.zzz.fill", tint: DesignToken.accentBlue)
                    }
                }
                .tint(DesignToken.primary)

                NavigationLink {
                    ReminderPeriodSettingsView(selectedRaw: $lookbackDays)
                } label: {
                    SettingsRowLabel(
                        icon: "calendar",
                        tint: DesignToken.success,
                        title: "统计周期",
                        value: selectedLookback.title
                    )
                }
                .disabled(!reminderEnabled)

                if authorizationStatus == .denied {
                    Button {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        openURL(url)
                    } label: {
                        SettingsRowLabel(icon: "gear", tint: DesignToken.textSecondary, title: "系统设置", showsChevron: true)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(ProfileSoftBackground().ignoresSafeArea())
        .navigationTitle("提醒通知")
        .navigationBarTitleDisplayMode(.inline)
        .task { authorizationStatus = await BedtimeReminderCoordinator.authorizationStatus() }
        .alert("无法开启提醒", isPresented: $showPermissionAlert) {
            Button("前往设置") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                openURL(url)
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("请先在系统设置中允许通知。")
        }
    }

    private var selectedLookback: BedtimeReminderLookback {
        BedtimeReminderLookback(rawValue: lookbackDays) ?? .sevenDays
    }

    private var reminderToggleBinding: Binding<Bool> {
        Binding {
            reminderEnabled
        } set: { isEnabled in
            guard isEnabled else {
                reminderEnabled = false
                return
            }
            Task {
                let granted = await BedtimeReminderCoordinator.requestAuthorization()
                let status = await BedtimeReminderCoordinator.authorizationStatus()
                await MainActor.run {
                    authorizationStatus = status
                    reminderEnabled = granted || BedtimeReminderCoordinator.canScheduleNotifications(with: status)
                    showPermissionAlert = !reminderEnabled
                }
            }
        }
    }
}

private struct ReminderPeriodSettingsView: View {
    @Binding var selectedRaw: Int

    var body: some View {
        Form {
            Section {
                ForEach(BedtimeReminderLookback.allCases) { option in
                    Button { selectedRaw = option.rawValue } label: {
                        SettingsSelectionRow(title: option.title, isSelected: selectedRaw == option.rawValue)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(ProfileSoftBackground().ignoresSafeArea())
        .navigationTitle("统计周期")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private enum WidgetGuideKind {
    case homeScreen
    case lockScreen

    var title: String { self == .homeScreen ? "小组件" : "锁屏组件" }
    var steps: [String] {
        self == .homeScreen
            ? ["长按主屏", "点击加号", "选择应用", "添加组件"]
            : ["长按锁屏", "点击自定", "选择锁屏", "添加组件"]
    }
}

private struct WidgetGuideView: View {
    let kind: WidgetGuideKind

    var body: some View {
        Form {
            Section {
                ForEach(Array(kind.steps.enumerated()), id: \.offset) { index, step in
                    HStack(spacing: 12) {
                        Text("\(index + 1)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 25, height: 25)
                            .background(Circle().fill(DesignToken.primary))
                        Text(step.localized)
                        Spacer()
                    }
                    .frame(minHeight: 44)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(ProfileSoftBackground().ignoresSafeArea())
        .navigationTitle(kind.title.localized)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SettingsSelectionRow: View {
    let title: String
    let isSelected: Bool

    var body: some View {
        HStack {
            Text(title.localized)
                .foregroundStyle(DesignToken.textPrimary)
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(DesignToken.primary)
            }
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
}

private struct GeneralPreferenceSettingsView: View {
    @Environment(\.openURL) private var openURL
    @AppStorage(
        MeasurementSystemPreference.storageKey,
        store: MeasurementSystemPreference.defaults
    ) private var measurementPreferenceRaw = MeasurementSystemPreference.followRegion.rawValue
    @AppStorage(
        GrowthStandardPreference.storageKey,
        store: GrowthStandardPreference.defaults
    ) private var growthStandardPreferenceRaw = GrowthStandardPreference.automatic.rawValue

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                SettingsInfoCard(
                    icon: "slider.horizontal.3",
                    color: DesignToken.accentBlue,
                    title: "通用偏好",
                    detail: "语言由 iOS 管理；单位只影响显示，生长标准只影响曲线与评估，历史记录不会被改写。"
                )

                SettingsDetailSection(title: "语言") {
                    Button {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        openURL(url)
                    } label: {
                        SettingsDetailActionRow(
                            icon: AppSemanticIcon.language,
                            color: DesignToken.accentBlue,
                            title: "当前语言",
                            subtitle: AppLanguage.current.displayName
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings.currentLanguage")
                }

                SettingsDetailSection(title: "单位") {
                    ForEach(Array(MeasurementSystemPreference.allCases.enumerated()), id: \.element.id) { index, preference in
                        Button {
                            measurementPreferenceRaw = preference.rawValue
                        } label: {
                            SettingsChoiceRow(
                                title: preference.title,
                                subtitle: measurementDescription(preference),
                                isSelected: measurementPreferenceRaw == preference.rawValue
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(measurementPreferenceRaw == preference.rawValue ? .isSelected : [])

                        if index < MeasurementSystemPreference.allCases.count - 1 {
                            SettingsDetailDivider()
                        }
                    }
                }
                .accessibilityIdentifier("settings.measurementSystem")

                SettingsDetailSection(title: "生长标准") {
                    ForEach(Array(GrowthStandardPreference.allCases.enumerated()), id: \.element.id) { index, preference in
                        Button {
                            growthStandardPreferenceRaw = preference.rawValue
                        } label: {
                            SettingsChoiceRow(
                                title: preference.title,
                                subtitle: growthStandardDescription(preference),
                                isSelected: growthStandardPreferenceRaw == preference.rawValue
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(growthStandardPreferenceRaw == preference.rawValue ? .isSelected : [])

                        if index < GrowthStandardPreference.allCases.count - 1 {
                            SettingsDetailDivider()
                        }
                    }
                }
                .accessibilityIdentifier("settings.growthStandard")
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 88)
        }
        .background(ProfileSoftBackground().ignoresSafeArea())
        .navigationTitle("通用偏好")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func measurementDescription(_ preference: MeasurementSystemPreference) -> String {
        switch preference {
        case .followRegion:
            return "根据设备地区自动选择，当前为 \(AppMeasurementFormat.preferenceSummary)"
        case .metric:
            return "厘米、千克、毫升与克"
        case .imperial:
            return "英寸、磅与盎司、液体盎司"
        }
    }

    private func growthStandardDescription(_ preference: GrowthStandardPreference) -> String {
        switch preference {
        case .automatic:
            return "根据当前地区自动选择，当前为 \(GrowthStandardPreference.defaultStandard.shortTitle)"
        case .who2006:
            return "适用于 0–5 岁儿童的 WHO 生长参考"
        case .chinaNHC2022:
            return "适用于 0–7 岁儿童的国家卫健委标准"
        }
    }
}

private struct AppearanceSettingsView: View {
    @AppStorage(AppAppearanceMode.storageKey) private var appearanceModeRaw = AppAppearanceMode.system.rawValue
    @AppStorage("buddy_card_reduced_effects_enabled") private var reducedBuddyCardEffects = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                SettingsInfoCard(
                    icon: "circle.lefthalf.filled",
                    color: DesignToken.primary,
                    title: "外观与动效",
                    detail: "选择界面明暗风格，并单独控制 Buddy 卡片的倾斜与稀有光泽。"
                )

                SettingsDetailSection(title: "外观") {
                    ForEach(Array(AppAppearanceMode.allCases.enumerated()), id: \.element.id) { index, mode in
                        Button {
                            appearanceModeRaw = mode.rawValue
                        } label: {
                            SettingsChoiceRow(
                                title: mode.title,
                                subtitle: appearanceDescription(mode),
                                isSelected: appearanceModeRaw == mode.rawValue
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(appearanceModeRaw == mode.rawValue ? .isSelected : [])

                        if index < AppAppearanceMode.allCases.count - 1 {
                            SettingsDetailDivider()
                        }
                    }
                }
                .accessibilityIdentifier("settings.appearance")

                SettingsDetailSection(title: "动效") {
                    Toggle(isOn: $reducedBuddyCardEffects) {
                        SettingsToggleHeader(
                            icon: "bolt.lefthalf.filled",
                            color: DesignToken.textFaint,
                            title: "减少 Buddy 动效",
                            subtitle: "关闭倾斜与稀有卡光泽，降低动画和耗电。"
                        )
                    }
                    .toggleStyle(.switch)
                    .tint(DesignToken.primary)
                    .padding(14)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 88)
        }
        .background(ProfileSoftBackground().ignoresSafeArea())
        .navigationTitle("外观与动效")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func appearanceDescription(_ mode: AppAppearanceMode) -> String {
        switch mode {
        case .system: return "随 iOS 浅色或深色模式自动切换"
        case .light: return "始终使用浅色界面"
        case .dark: return "始终使用深色界面"
        }
    }
}

private struct ReminderSettingsView: View {
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var activityStore: ActivityStore
    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @State private var showPermissionAlert = false
    @AppStorage(BedtimeReminderSettings.enabledKey) private var reminderEnabled = false
    @AppStorage(BedtimeReminderSettings.lookbackDaysKey) private var lookbackDays = BedtimeReminderLookback.sevenDays.rawValue

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                SettingsInfoCard(
                    icon: "moon.zzz.fill",
                    color: DesignToken.accentBlue,
                    title: "预计入睡提醒",
                    detail: reminderSubtitle
                )

                SettingsDetailSection(title: "提醒") {
                    Toggle(isOn: reminderToggleBinding) {
                        SettingsToggleHeader(
                            icon: "bell.badge.fill",
                            color: DesignToken.accentBlue,
                            title: "预计入睡提醒",
                            subtitle: reminderEnabled ? "已开启" : "预计入睡前 30 分钟提醒"
                        )
                    }
                    .toggleStyle(.switch)
                    .tint(DesignToken.primary)
                    .padding(14)
                    .accessibilityIdentifier("settings.bedtimeReminder.enabled")

                    SettingsDetailDivider(leading: 14)

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("统计周期".localized)
                                .font(BBBFont.font(size: 13, weight: .bold))
                                .foregroundStyle(DesignToken.textPrimary)
                            Spacer()
                            Text(AppLocalization.format("bedtime.reminder.lookback.summary", selectedLookback.rawValue))
                                .font(BBBFont.font(size: 11, weight: .medium))
                                .foregroundStyle(DesignToken.textSecondary)
                        }

                        Picker("统计周期", selection: $lookbackDays) {
                            ForEach(BedtimeReminderLookback.allCases) { lookback in
                                Text(lookback.title).tag(lookback.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("settings.bedtimeReminder.lookback")

                        Text("基于夜间首次入睡记录预测，并在预计时间前 30 分钟提醒；至少需要 3 晚有效记录。".localized)
                            .font(BBBFont.font(size: 11, weight: .medium))
                            .foregroundStyle(DesignToken.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        if authorizationStatus == .denied {
                            Button("前往系统设置") {
                                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                                openURL(url)
                            }
                            .font(BBBFont.font(size: 13, weight: .bold))
                            .foregroundStyle(DesignToken.primary)
                        }
                    }
                    .padding(14)
                    .disabled(!reminderEnabled)
                    .opacity(reminderEnabled ? 1 : 0.58)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 88)
        }
        .background(ProfileSoftBackground().ignoresSafeArea())
        .navigationTitle("提醒设置")
        .navigationBarTitleDisplayMode(.inline)
        .task { await refreshAuthorizationStatus() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            Task { await refreshAuthorizationStatus() }
        }
        .alert("无法开启入睡提醒", isPresented: $showPermissionAlert) {
            Button("前往设置") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                openURL(url)
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("通知权限已关闭，请先到系统设置中允许通知。")
        }
    }

    private var selectedLookback: BedtimeReminderLookback {
        BedtimeReminderLookback(rawValue: lookbackDays) ?? .sevenDays
    }

    private var prediction: BedtimePrediction? {
        BedtimePredictor.prediction(records: activityStore.careRecords, lookbackDays: selectedLookback.rawValue)
    }

    private var reminderSubtitle: String {
        guard reminderEnabled else { return "开启后，会根据最近的夜睡记录自动预测。" }
        switch authorizationStatus {
        case .denied: return "通知权限已关闭，请前往系统设置开启。"
        case .notDetermined: return "等待通知权限。"
        default: break
        }
        guard let prediction else { return "至少需要 3 晚有效夜睡记录。" }
        return AppLocalization.format(
            "bedtime.reminder.status.scheduled",
            AppDateTimeFormat.time(prediction.expectedBedtime),
            AppDateTimeFormat.time(prediction.reminderDate)
        )
    }

    private var reminderToggleBinding: Binding<Bool> {
        Binding {
            reminderEnabled
        } set: { isEnabled in
            guard isEnabled else {
                reminderEnabled = false
                return
            }
            Task {
                let granted = await BedtimeReminderCoordinator.requestAuthorization()
                let status = await BedtimeReminderCoordinator.authorizationStatus()
                await MainActor.run {
                    authorizationStatus = status
                    if granted || BedtimeReminderCoordinator.canScheduleNotifications(with: status) {
                        reminderEnabled = true
                    } else {
                        reminderEnabled = false
                        showPermissionAlert = true
                    }
                }
            }
        }
    }

    @MainActor
    private func refreshAuthorizationStatus() async {
        authorizationStatus = await BedtimeReminderCoordinator.authorizationStatus()
    }
}

private struct DataManagementView: View {
    @EnvironmentObject private var feedingStore: FeedingStore
    @EnvironmentObject private var activityStore: ActivityStore
    @EnvironmentObject private var growthMetricStore: GrowthMetricStore
    @EnvironmentObject private var stickerStore: AchievementStickerStore
    @State private var shareFile: ExportedCSVFile?
    @State private var pendingImport: BabyDataCSVImport?
    @State private var isSelectingImportFile = false
    @State private var showAutoMatchCleanup = false
    @State private var exportError: String?
    @State private var importError: String?
    @State private var importResultMessage: String?

    var body: some View {
        Form {
            Section {
                Button(action: exportCSV) {
                    SettingsRowLabel(icon: "square.and.arrow.up.fill", tint: DesignToken.accentBlue, title: "导出数据", showsChevron: true)
                }
                .buttonStyle(.plain)

                Button { isSelectingImportFile = true } label: {
                    SettingsRowLabel(icon: "square.and.arrow.down.fill", tint: DesignToken.success, title: "导入数据", showsChevron: true)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("settings.importCareRecords")
            } header: {
                Text("数据备份")
            }

            Section {
                Button { showAutoMatchCleanup = true } label: {
                    SettingsRowLabel(icon: "wand.and.stars", tint: DesignToken.primary, title: "成就记录", value: autoMatchCountText, showsChevron: true)
                }
                .buttonStyle(.plain)
            } header: {
                Text("记录维护")
            }
        }
        .scrollContentBackground(.hidden)
        .background(ProfileSoftBackground().ignoresSafeArea())
        .navigationTitle("数据导入导出")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $shareFile) { file in
            SystemShareSheet(activityItems: [file.url])
        }
        .sheet(item: $pendingImport) { payload in
            BabyDataCSVImportPreview(payload: payload) {
                merge(payload)
            }
        }
        .sheet(isPresented: $showAutoMatchCleanup) {
            AutoMatchedAchievementCleanupView()
                .environmentObject(stickerStore)
        }
        .fileImporter(
            isPresented: $isSelectingImportFile,
            allowedContentTypes: [.commaSeparatedText, .plainText],
            allowsMultipleSelection: false,
            onCompletion: handleImportSelection
        )
        .alert("导出失败", isPresented: messageBinding($exportError)) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(exportError ?? "")
        }
        .alert("导入失败", isPresented: messageBinding($importError)) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(importError ?? "")
        }
        .alert("导入完成", isPresented: messageBinding($importResultMessage)) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(importResultMessage ?? "")
        }
    }

    private var exportSubtitle: String {
        AppLocalization.format(
            "profile.export.summary",
            feedingStore.exportSessions().count,
            activityStore.exportCareRecords().count,
            growthMetricStore.exportRecords().count
        )
    }

    private var autoMatchCleanupSubtitle: String {
        let count = stickerStore.autoMatchedAchievements.count
        return count == 0 ? "没有可清理的自动匹配记录" : "共 \(count) 条，仅清理自动匹配记录"
    }

    private var autoMatchCountText: String {
        AppLocalization.format(
            "settings.achievementRecordCount",
            stickerStore.autoMatchedAchievements.count
        )
    }

    private func exportCSV() {
        let feedingSessions = feedingStore.exportSessions()
        let careRecords = activityStore.exportCareRecords()
        let growthRecords = growthMetricStore.exportRecords()
        Task { @MainActor in
            do {
                let file = try await Task.detached(priority: .utility) {
                    try BabyDataCSVExporter.export(
                        feedingSessions: feedingSessions,
                        careRecords: careRecords,
                        growthRecords: growthRecords
                    )
                }.value
                guard !Task.isCancelled else { return }
                shareFile = file
            } catch {
                exportError = "请稍后重试，或检查设备存储空间。"
            }
        }
    }

    private func handleImportSelection(_ result: Result<[URL], Error>) {
        let url: URL
        do {
            guard let selectedURL = try result.get().first else { return }
            url = selectedURL
        } catch {
            importError = error.localizedDescription
            return
        }
        let hasSecurityAccess = url.startAccessingSecurityScopedResource()
        Task { @MainActor in
            do {
                let payload = try await Task.detached(priority: .utility) {
                    defer {
                        if hasSecurityAccess { url.stopAccessingSecurityScopedResource() }
                    }
                    let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
                    guard values.isRegularFile != false,
                          let fileSize = values.fileSize,
                          fileSize >= 0,
                          fileSize <= 10 * 1_024 * 1_024 else {
                        throw BabyDataCSVImportError.fileTooLarge
                    }
                    let data = try Data(contentsOf: url, options: .mappedIfSafe)
                    return try BabyDataCSVImporter.parse(data: data, filename: url.lastPathComponent)
                }.value
                guard !Task.isCancelled else { return }
                pendingImport = payload
            } catch {
                importError = error.localizedDescription
            }
        }
    }

    private func merge(_ payload: BabyDataCSVImport) {
        let existingFeeding = feedingStore.exportSessions()
        let existingCare = activityStore.exportCareRecords()
        let existingGrowth = growthMetricStore.exportRecords()
        let feedingIDs = Set(existingFeeding.map(\.id))
        let careIDs = Set(existingCare.map(\.id))
        let growthIDs = Set(existingGrowth.map(\.id))
        let newFeeding = payload.feedingSessions.filter { !feedingIDs.contains($0.id) }
        let newCare = payload.careRecords.filter { !careIDs.contains($0.id) }
        let newGrowth = payload.growthRecords.filter { !growthIDs.contains($0.id) }

        if !newFeeding.isEmpty { feedingStore.importSessions(existingFeeding + newFeeding) }
        if !newCare.isEmpty { activityStore.importCareRecords(existingCare + newCare) }
        if !newGrowth.isEmpty { growthMetricStore.importRecords(existingGrowth + newGrowth) }

        let added = newFeeding.count + newCare.count + newGrowth.count
        let duplicates = payload.recordCount - added
        importResultMessage = "新增 \(added) 条记录，跳过 \(duplicates) 条本机已有记录。"
        pendingImport = nil
    }

    private func messageBinding(_ message: Binding<String?>) -> Binding<Bool> {
        Binding(
            get: { message.wrappedValue != nil },
            set: { if !$0 { message.wrappedValue = nil } }
        )
    }
}

private struct BabyDataCSVImportPreview: View {
    @Environment(\.dismiss) private var dismiss
    let payload: BabyDataCSVImport
    let onImport: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    SettingsInfoCard(
                        icon: "doc.text.magnifyingglass",
                        color: DesignToken.success,
                        title: payload.filename,
                        detail: payload.recordCount == 0 ? "没有可导入的有效记录" : "已完成解析，请确认后合并到本机。"
                    )

                    SettingsDetailSection(title: "导入预览") {
                        ImportCountRow(title: "喂养记录", count: payload.feedingSessions.count)
                        SettingsDetailDivider()
                        ImportCountRow(title: "护理记录", count: payload.careRecords.count)
                        SettingsDetailDivider()
                        ImportCountRow(title: "成长记录", count: payload.growthRecords.count)
                        if payload.skippedRowCount > 0 {
                            SettingsDetailDivider()
                            ImportCountRow(title: "无法识别的行", count: payload.skippedRowCount, color: DesignToken.reward)
                        }
                    }

                    Text("BBBuddy 会按记录 ID 合并；本机已有记录不会被覆盖。")
                        .font(BBBFont.font(size: 11, weight: .medium))
                        .foregroundStyle(DesignToken.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
            }
            .background(ProfileSoftBackground().ignoresSafeArea())
            .navigationTitle("确认导入")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    onImport()
                    dismiss()
                } label: {
                    Label("合并导入 \(payload.recordCount) 条记录", systemImage: "square.and.arrow.down.fill")
                        .font(BBBFont.font(size: 15, weight: .heavy))
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                }
                .buttonStyle(.borderedProminent)
                .tint(DesignToken.primary)
                .disabled(payload.recordCount == 0)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
            }
        }
    }
}

private struct ImportCountRow: View {
    let title: String
    let count: Int
    var color: Color = DesignToken.primary

    var body: some View {
        HStack {
            Text(title.localized)
                .font(BBBFont.font(size: 14, weight: .bold))
                .foregroundStyle(DesignToken.textPrimary)
            Spacer()
            Text("\(count) 条")
                .font(BBBFont.font(size: 13, weight: .bold))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 52)
    }
}

private struct SettingsDetailSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.localized)
                .font(BBBFont.font(size: 12, weight: .bold))
                .foregroundStyle(DesignToken.textSecondary)
                .padding(.leading, 4)

            VStack(spacing: 0) { content }
                .softProfileCard(cornerRadius: 20, shadowOpacity: 0.045)
        }
    }
}

private struct SettingsInfoCard: View {
    let icon: String
    let color: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            SettingsDetailIcon(systemName: icon, color: color)
            VStack(alignment: .leading, spacing: 5) {
                Text(title.localized)
                    .font(BBBFont.font(size: 16, weight: .heavy))
                    .foregroundStyle(DesignToken.textPrimary)
                Text(detail.localized)
                    .font(BBBFont.font(size: 12, weight: .medium))
                    .foregroundStyle(DesignToken.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .softProfileCard(cornerRadius: 22)
    }
}

private struct SettingsDetailActionRow: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    var trailingSystemName = "chevron.right"

    var body: some View {
        HStack(spacing: 12) {
            SettingsDetailIcon(systemName: icon, color: color)
            VStack(alignment: .leading, spacing: 3) {
                Text(title.localized)
                    .font(BBBFont.scaledFont(size: 14, weight: .bold, relativeTo: .headline, maximumPointSize: 22))
                    .foregroundStyle(DesignToken.textPrimary)
                Text(subtitle.localized)
                    .font(BBBFont.scaledFont(size: 11, weight: .medium, relativeTo: .subheadline, maximumPointSize: 18))
                    .foregroundStyle(DesignToken.textSecondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            Image(systemName: trailingSystemName)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(DesignToken.textSecondary.opacity(0.55))
                .frame(width: 24, height: 44)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 64)
        .contentShape(Rectangle())
    }
}

private struct SettingsChoiceRow: View {
    let title: String
    let subtitle: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(isSelected ? DesignToken.primary : DesignToken.textFaint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title.localized)
                    .font(BBBFont.scaledFont(size: 14, weight: .bold, relativeTo: .headline, maximumPointSize: 22))
                    .foregroundStyle(DesignToken.textPrimary)
                Text(subtitle.localized)
                    .font(BBBFont.scaledFont(size: 11, weight: .medium, relativeTo: .subheadline, maximumPointSize: 18))
                    .foregroundStyle(DesignToken.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 66)
        .contentShape(Rectangle())
    }
}

private struct SettingsToggleHeader: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            SettingsDetailIcon(systemName: icon, color: color)
            VStack(alignment: .leading, spacing: 3) {
                Text(title.localized)
                    .font(BBBFont.font(size: 14, weight: .bold))
                    .foregroundStyle(DesignToken.textPrimary)
                Text(subtitle.localized)
                    .font(BBBFont.font(size: 11, weight: .medium))
                    .foregroundStyle(DesignToken.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct SettingsDetailIcon: View {
    let systemName: String
    let color: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(color.opacity(0.11))
            .frame(width: 36, height: 36)
            .overlay(
                Image(systemName: systemName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(color)
            )
    }
}

private struct SettingsDetailDivider: View {
    var leading: CGFloat = 62

    var body: some View {
        Rectangle()
            .fill(DesignToken.line.opacity(0.40))
            .frame(height: 1)
            .padding(.leading, leading)
    }
}


private struct AutoMatchedAchievementCleanupView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var stickerStore: AchievementStickerStore
    @State private var pendingDeletion: Set<UUID> = []
    @State private var showDeleteConfirmation = false
    @State private var errorMessage: String?

    private var records: [CustomAchievement] {
        stickerStore.autoMatchedAchievements
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("此处只显示自动匹配保存的成就。手动添加、编辑或拍摄的记录不会出现在这里，也不会被清理。")
                        .font(BBBFont.font(size: 12, weight: .medium))
                        .foregroundStyle(DesignToken.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .listRowBackground(Color.clear)
                }

                if records.isEmpty {
                    ContentUnavailableView(
                        "没有自动匹配记录",
                        systemImage: "wand.and.stars",
                        description: Text("之后自动匹配保存的照片会显示在这里。")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    Section("自动匹配记录") {
                        ForEach(records) { achievement in
                            Button {
                                toggle(achievement.id)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: pendingDeletion.contains(achievement.id) ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 21, weight: .semibold))
                                        .foregroundStyle(pendingDeletion.contains(achievement.id) ? DesignToken.primary : DesignToken.textFaint)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(achievement.name)
                                            .font(BBBFont.font(size: 15, weight: .heavy))
                                            .foregroundStyle(DesignToken.textPrimary)
                                            .lineLimit(1)
                                        Text(recordSubtitle(for: achievement))
                                            .font(BBBFont.font(size: 11, weight: .medium))
                                            .foregroundStyle(DesignToken.textSecondary)
                                            .lineLimit(1)
                                    }
                                    Spacer(minLength: 8)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .swipeActions {
                                Button(role: .destructive) {
                                    pendingDeletion = [achievement.id]
                                    showDeleteConfirmation = true
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(ProfileSoftBackground().ignoresSafeArea())
            .navigationTitle("管理自动匹配成就")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    AppPageCloseButton { dismiss() }
                }
                if !records.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button(pendingDeletion.count == records.count ? "取消全选" : "全选") {
                            pendingDeletion = pendingDeletion.count == records.count ? [] : Set(records.map(\.id))
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !records.isEmpty {
                    Button(role: .destructive) {
                        pendingDeletion = pendingDeletion.isEmpty ? Set(records.map(\.id)) : pendingDeletion
                        showDeleteConfirmation = true
                    } label: {
                        Text(pendingDeletion.isEmpty ? "清理全部自动匹配记录" : "删除已选 \(pendingDeletion.count) 条")
                            .font(BBBFont.font(size: 15, weight: .heavy))
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                }
            }
            .alert("删除自动匹配成就？", isPresented: $showDeleteConfirmation) {
                Button("删除", role: .destructive, action: deleteSelected)
                Button("取消", role: .cancel) {}
            } message: {
                Text("将删除 \(pendingDeletion.count) 条自动匹配记录及其本地图片。手动记录不会受影响。")
            }
            .alert("清理失败", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func toggle(_ id: UUID) {
        if pendingDeletion.contains(id) {
            pendingDeletion.remove(id)
        } else {
            pendingDeletion.insert(id)
        }
    }

    private func recordSubtitle(for achievement: CustomAchievement) -> String {
        let date = AppDateTimeFormat.date(achievement.completedAt)
        guard let confidence = achievement.matchConfidence else { return "自动匹配 · \(date)" }
        return "自动匹配 \(Int((confidence * 100).rounded()))% · \(date)"
    }

    private func deleteSelected() {
        do {
            _ = try stickerStore.deleteAutoMatchedAchievements(ids: pendingDeletion)
            pendingDeletion = []
        } catch {
            errorMessage = "请稍后重试，或检查设备存储空间。"
        }
    }
}

#if DEBUG
private enum DarkModeDemoPage: String, CaseIterable, Identifiable {
    case home
    case quickRecord
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "首页"
        case .quickRecord: return "快捷记录"
        case .settings: return "设置"
        }
    }

    static var launchDefault: DarkModeDemoPage {
        guard let value = ProcessInfo.processInfo.launchArgumentValue(after: "-BBDarkModeDemoPage") else {
            return .home
        }
        return DarkModeDemoPage(rawValue: value) ?? .home
    }
}

struct DarkModeDesignDemoView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPage = DarkModeDemoPage.launchDefault
    @State private var appearance = AppAppearanceMode.darkModeDemoLaunchDefault

    private var showsControls: Bool {
        !ProcessInfo.processInfo.arguments.contains("-BBDarkModeDemoHideControls")
    }

    private var demoColorScheme: ColorScheme {
        appearance == .dark ? .dark : .light
    }

    var body: some View {
        demoPage
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DesignToken.canvas.ignoresSafeArea())
            .environment(\.colorScheme, demoColorScheme)
            .preferredColorScheme(demoColorScheme)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if showsControls {
                    demoControls
                }
            }
            .overlay(alignment: .topTrailing) {
                if showsControls {
                    AppPageStandaloneButton(
                        systemName: "xmark",
                        accessibilityLabel: "关闭",
                        action: { dismiss() }
                    )
                        .padding(.top, 8)
                        .padding(.trailing, 12)
                }
            }
    }

    @ViewBuilder
    private var demoPage: some View {
        switch selectedPage {
        case .home:
            RecordHomeView(
                homeMode: .constant(.easy),
                showYearningDetailRequest: .constant(false),
                isReadOnlyDemo: true
            )
            .allowsHitTesting(false)
            .accessibilityHidden(true)

        case .quickRecord:
            QuickRecordDarkModeDemo()

        case .settings:
            NavigationStack {
                ProfileView(showsDarkModeDemoEntry: false)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private var demoControls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Text("深色模式样板")
                    .font(BBBFont.font(size: 13, weight: .bold))
                    .foregroundStyle(DesignToken.textPrimary)
                Spacer()
                Label("只读", systemImage: "lock.fill")
                    .font(BBBFont.font(size: 10, weight: .bold))
                    .foregroundStyle(DesignToken.successText)
                    .padding(.horizontal, 9)
                    .frame(height: 26)
                    .background(Capsule().fill(DesignToken.successSoft))
            }

            Picker("样板页面", selection: $selectedPage) {
                ForEach(DarkModeDemoPage.allCases) { page in
                    Text(page.title).tag(page)
                }
            }
            .pickerStyle(.segmented)

            Picker("样板外观", selection: $appearance) {
                Text("浅色").tag(AppAppearanceMode.light)
                Text("深色").tag(AppAppearanceMode.dark)
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(DesignToken.borderSubtle.opacity(0.72))
                .frame(height: 1)
        }
    }
}

private extension AppAppearanceMode {
    static var darkModeDemoLaunchDefault: AppAppearanceMode {
        let value = ProcessInfo.processInfo.launchArgumentValue(after: "-BBDarkModeDemoScheme")
        return value == AppAppearanceMode.light.rawValue ? .light : .dark
    }
}

private extension ProcessInfo {
    func launchArgumentValue(after flag: String) -> String? {
        guard let index = arguments.firstIndex(of: flag) else { return nil }
        let valueIndex = arguments.index(after: index)
        guard valueIndex < arguments.endIndex else { return nil }
        return arguments[valueIndex]
    }
}
#endif

private struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var feedingStore: FeedingStore
    @EnvironmentObject private var activityStore: ActivityStore
    @EnvironmentObject private var growthMetricStore: GrowthMetricStore
    @AppStorage("buddy_card_reduced_effects_enabled") private var reducedBuddyCardEffects = false
    @State private var selectedAppIconName: String?
    @State private var shareFile: ExportedCSVFile?
    @State private var exportError: String?
    @State private var appIconError: String?

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    appIconCard
                    preferenceCard
                    dataExportCard
                }
                .padding(20)
            }
            .background(ProfileSoftBackground().ignoresSafeArea())
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                selectedAppIconName = UIApplication.shared.alternateIconName
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    AppPageCloseButton { dismiss() }
                }
            }
            .sheet(item: $shareFile) { file in
                SystemShareSheet(activityItems: [file.url])
            }
            .alert("导出失败", isPresented: Binding(
                get: { exportError != nil },
                set: { if !$0 { exportError = nil } }
            )) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text(exportError ?? "")
            }
            .alert("更换图标失败", isPresented: Binding(
                get: { appIconError != nil },
                set: { if !$0 { appIconError = nil } }
            )) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text(appIconError ?? "")
            }
        }
    }

    private var appIconCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "app.badge.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(DesignToken.primary)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(DesignToken.primary.opacity(0.14)))

                VStack(alignment: .leading, spacing: 4) {
                    Text("App 图标")
                        .font(BBBFont.font(size: 16, weight: .heavy))
                        .foregroundStyle(DesignToken.textPrimary)
                    Text("选择主图标或 7 个预留图标位，后续直接替换对应资源。")
                        .font(BBBFont.font(size: 12, weight: .semibold))
                        .foregroundStyle(DesignToken.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            LazyVGrid(columns: appIconColumns, spacing: 12) {
                ForEach(AppIconOption.allCases) { option in
                    appIconButton(option)
                }
            }
        }
        .padding(16)
        .softProfileCard(cornerRadius: 22)
    }

    private var appIconColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 0), spacing: 10), count: 4)
    }

    private func appIconButton(_ option: AppIconOption) -> some View {
        let isSelected = selectedAppIconName == option.iconName
        return Button {
            setAppIcon(option)
        } label: {
            VStack(spacing: 8) {
                Image(option.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(isSelected ? DesignToken.primary : DesignToken.glassStroke.opacity(0.78), lineWidth: isSelected ? 2 : 1)
                    )
                    .shadow(color: DesignToken.shadowColor.opacity(0.10), radius: 8, y: 4)

                Text(option.title.localized)
                    .font(BBBFont.font(size: 11, weight: .heavy))
                    .foregroundStyle(isSelected ? DesignToken.primary : DesignToken.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? DesignToken.primary.opacity(0.12) : DesignToken.surfaceRaised.opacity(0.78))
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!UIApplication.shared.supportsAlternateIcons)
    }

    private func setAppIcon(_ option: AppIconOption) {
        guard UIApplication.shared.supportsAlternateIcons else {
            appIconError = "当前设备不支持更换 App 图标。"
            return
        }

        guard UIApplication.shared.alternateIconName != option.iconName else { return }

        UIApplication.shared.setAlternateIconName(option.iconName) { error in
            DispatchQueue.main.async {
                if let error {
                    appIconError = error.localizedDescription
                } else {
                    selectedAppIconName = option.iconName
                }
            }
        }
    }

    private var preferenceCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle(isOn: $reducedBuddyCardEffects) {
                HStack(spacing: 12) {
                    Image(systemName: "bolt.lefthalf.filled")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(DesignToken.grayNeutral)
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(DesignToken.grayNeutral.opacity(0.13)))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Buddy 卡片低功耗")
                            .font(BBBFont.font(size: 16, weight: .heavy))
                            .foregroundStyle(DesignToken.textPrimary)
                        Text("关闭卡片倾斜与稀有卡光泽，使用静态轻量效果。")
                            .font(BBBFont.font(size: 12, weight: .semibold))
                            .foregroundStyle(DesignToken.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .toggleStyle(.switch)
            .tint(DesignToken.primary)
        }
        .padding(16)
        .softProfileCard(cornerRadius: 22)
    }

    private var dataExportCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "square.and.arrow.up.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(DesignToken.primary)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(DesignToken.primary.opacity(0.14)))

                VStack(alignment: .leading, spacing: 4) {
                    Text("数据导出")
                        .font(BBBFont.font(size: 16, weight: .heavy))
                        .foregroundStyle(DesignToken.textPrimary)
                    Text(exportSubtitle)
                        .font(BBBFont.font(size: 12, weight: .semibold))
                        .foregroundStyle(DesignToken.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button {
                exportCSV()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text("导出为 CSV")
                        .font(BBBFont.font(size: 14, weight: .heavy))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .foregroundStyle(DesignToken.onPrimary)
                .background(Capsule(style: .continuous).fill(DesignToken.primaryGradient))
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(16)
        .softProfileCard(cornerRadius: 22)
    }

    private var exportSubtitle: String {
        let feedingCount = feedingStore.exportSessions().count
        let careCount = activityStore.exportCareRecords().count
        let growthCount = growthMetricStore.exportRecords().count
        return AppLocalization.format("profile.export.summary", feedingCount, careCount, growthCount)
    }

    private func exportCSV() {
        do {
            let file = try BabyDataCSVExporter.export(
                feedingSessions: feedingStore.exportSessions(),
                careRecords: activityStore.exportCareRecords(),
                growthRecords: growthMetricStore.exportRecords()
            )
            shareFile = file
        } catch {
            exportError = "请稍后重试，或检查设备存储空间。"
        }
    }
}

private enum AppIconOption: String, CaseIterable, Identifiable {
    case primary
    case alt1
    case alt2
    case alt3
    case alt4
    case alt5
    case alt6
    case alt7

    var id: String { rawValue }

    var title: String {
        switch self {
        case .primary: return "默认".localized
        case .alt1: return AppLocalization.format("placeholder.number", 1)
        case .alt2: return AppLocalization.format("placeholder.number", 2)
        case .alt3: return AppLocalization.format("placeholder.number", 3)
        case .alt4: return AppLocalization.format("placeholder.number", 4)
        case .alt5: return AppLocalization.format("placeholder.number", 5)
        case .alt6: return AppLocalization.format("placeholder.number", 6)
        case .alt7: return AppLocalization.format("placeholder.number", 7)
        }
    }

    var iconName: String? {
        switch self {
        case .primary: return nil
        case .alt1: return "AppIconAlt1"
        case .alt2: return "AppIconAlt2"
        case .alt3: return "AppIconAlt3"
        case .alt4: return "AppIconAlt4"
        case .alt5: return "AppIconAlt5"
        case .alt6: return "AppIconAlt6"
        case .alt7: return "AppIconAlt7"
        }
    }

    var assetName: String {
        iconName ?? "AppIcon"
    }
}

private struct ExportedCSVFile: Identifiable {
    let id = UUID()
    let url: URL
}

private struct SystemShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        controller.popoverPresentationController?.sourceView = controller.view
        controller.popoverPresentationController?.sourceRect = CGRect(x: 1, y: 1, width: 1, height: 1)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private enum BabyDataCSVExporter {
    private static let columns = [
        "record_id",
        "record_type",
        "recorded_at",
        "item_type",
        "title",
        "amount",
        "unit",
        "duration_minutes",
        "detail",
        "note",
        "mood",
        "source_session_id",
        "start_at",
        "end_at",
        "time_span_source",
        "breast_mode",
        "breast_side",
        "milk_type",
        "solid_food",
        "solid_unit",
        "schema_version"
    ]

    static func export(
        feedingSessions: [FeedingSession],
        careRecords: [CareRecord],
        growthRecords: [GrowthMetricRecord]
    ) throws -> ExportedCSVFile {
        guard feedingSessions.count <= BBBDataSafetyLimits.maxFeedingSessions,
              careRecords.count <= BBBDataSafetyLimits.maxCareRecords,
              growthRecords.count <= BBBDataSafetyLimits.maxGrowthMetricRecords else {
            throw BabyDataCSVExportError.tooLarge
        }
        var rows: [[String]] = [columns]

        for session in feedingSessions.sorted(by: { $0.createdAt < $1.createdAt }) {
            if session.entries.isEmpty {
                rows.append(row(
                    id: session.id,
                    type: "feeding",
                    recordedAt: session.createdAt,
                    itemType: session.displayName,
                    title: session.displayName,
                    amount: "",
                    unit: "",
                    durationMinutes: "",
                    detail: "",
                    note: session.notes,
                    mood: session.babyMood.rawValue,
                    sourceSessionID: session.id.uuidString
                ))
            } else {
                for entry in session.entries {
                    rows.append(feedingRow(session: session, entry: entry))
                }
            }
        }

        for record in careRecords.sorted(by: { $0.recordedAt < $1.recordedAt }) {
            let duration = (record.kind == .sleep || record.kind == .activity)
                ? SleepRecordFormatter.durationMinutes(from: record.detail).map(String.init) ?? ""
                : ""
            rows.append(row(
                id: record.id,
                type: record.kind.rawValue,
                recordedAt: record.recordedAt,
                itemType: record.kind.rawValue,
                title: record.kind == .diaper ? DiaperRecordType.normalizedTitle(record.title) : record.title,
                amount: "",
                unit: "",
                durationMinutes: duration,
                detail: record.detail,
                note: record.note,
                mood: "",
                sourceSessionID: ""
            ))
        }

        for record in growthRecords.sorted(by: { $0.recordedAt < $1.recordedAt }) {
            rows.append(row(
                id: record.id,
                type: "growth",
                recordedAt: record.recordedAt,
                itemType: record.kind.rawValue,
                title: record.kind.title,
                amount: formatNumber(record.value),
                unit: record.unit,
                durationMinutes: "",
                detail: "",
                note: record.note,
                mood: "",
                sourceSessionID: ""
            ))
        }

        let csv = "\u{FEFF}" + rows.map { $0.map(escape).joined(separator: ",") }.joined(separator: "\n")
        guard csv.utf8.count <= 10 * 1_024 * 1_024 else {
            throw BabyDataCSVExportError.tooLarge
        }
        let filename = "BBBuddy-Export-\(filenameDateFormatter.string(from: Date())).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try csv.write(to: url, atomically: true, encoding: .utf8)
        return ExportedCSVFile(url: url)
    }

    private static func feedingRow(session: FeedingSession, entry: FeedingEntry) -> [String] {
        let title = entry.type.displayName(withMilkType: entry.milkType)
        let amount: String
        let unit: String
        let duration: String
        let detail: String

        switch entry.type {
        case .breast:
            amount = ""
            unit = ""
            duration = entry.breastDuration.map(String.init) ?? ""
            detail = [
                entry.breastMode?.displayName,
                entry.breastSide?.displayName
            ].compactMap { $0 }.joined(separator: " ")
        case .bottle:
            amount = entry.bottleAmount.map(String.init) ?? ""
            unit = "ml"
            duration = entry.bottleDuration.map(String.init) ?? ""
            detail = entry.milkType?.displayName ?? ""
        case .solid:
            amount = entry.solidAmount.map(formatNumber) ?? ""
            unit = entry.solidUnit?.displayName ?? ""
            duration = ""
            detail = entry.solidFood?.displayName ?? ""
        }

        return row(
            id: entry.id,
            type: "feeding",
            recordedAt: session.createdAt,
            itemType: entry.type.rawValue,
            title: title,
            amount: amount,
            unit: unit,
            durationMinutes: duration,
            detail: detail,
            note: session.notes,
            mood: session.babyMood.rawValue,
            sourceSessionID: session.id.uuidString,
            startAt: session.startAt.map(csvDateFormatter.string) ?? "",
            endAt: session.endAt.map(csvDateFormatter.string) ?? "",
            timeSpanSource: session.timeSpanSource?.rawValue ?? "",
            breastMode: entry.breastMode?.rawValue ?? "",
            breastSide: entry.breastSide?.rawValue ?? "",
            milkType: entry.milkType?.rawValue ?? "",
            solidFood: entry.solidFood?.rawValue ?? "",
            solidUnit: entry.solidUnit?.rawValue ?? ""
        )
    }

    private static func row(
        id: UUID,
        type: String,
        recordedAt: Date,
        itemType: String,
        title: String,
        amount: String,
        unit: String,
        durationMinutes: String,
        detail: String,
        note: String,
        mood: String,
        sourceSessionID: String,
        startAt: String = "",
        endAt: String = "",
        timeSpanSource: String = "",
        breastMode: String = "",
        breastSide: String = "",
        milkType: String = "",
        solidFood: String = "",
        solidUnit: String = ""
    ) -> [String] {
        [
            id.uuidString,
            type,
            csvDateFormatter.string(from: recordedAt),
            itemType,
            title,
            amount,
            unit,
            durationMinutes,
            detail,
            note,
            mood,
            sourceSessionID,
            startAt,
            endAt,
            timeSpanSource,
            breastMode,
            breastSide,
            milkType,
            solidFood,
            solidUnit,
            "2"
        ]
    }

    private static func escape(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        if escaped.contains(",") || escaped.contains("\"") || escaped.contains("\n") || escaped.contains("\r") {
            return "\"\(escaped)\""
        }
        return escaped
    }

    private static func formatNumber(_ value: Double) -> String {
        guard value.isFinite else { return "" }
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    private static let csvDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    private static let filenameDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()
}

struct BabyDataCSVImport: Identifiable {
    let id = UUID()
    let filename: String
    let feedingSessions: [FeedingSession]
    let careRecords: [CareRecord]
    let growthRecords: [GrowthMetricRecord]
    let skippedRowCount: Int

    var recordCount: Int {
        feedingSessions.count + careRecords.count + growthRecords.count
    }
}

enum BabyDataCSVImportError: LocalizedError, Equatable {
    case fileTooLarge
    case unreadableText
    case malformedCSV
    case unsupportedFormat

    var errorDescription: String? {
        switch self {
        case .fileTooLarge:
            return "文件超过 10 MB，请拆分后再导入。"
        case .unreadableText:
            return "无法读取文件文字，请选择 UTF-8 编码的 BBBuddy CSV。"
        case .malformedCSV:
            return "CSV 引号或换行格式不完整。"
        case .unsupportedFormat:
            return "这不是 BBBuddy 导出的照护记录 CSV。"
        }
    }
}

private enum BabyDataCSVExportError: LocalizedError {
    case tooLarge

    var errorDescription: String? {
        "记录过多，暂时无法生成导出文件。"
    }
}

enum BabyDataCSVImporter {
    private struct FeedingAccumulator {
        var createdAt: Date
        var notes: String
        var mood: BabyMood
        var startAt: Date?
        var endAt: Date?
        var timeSpanSource: FeedingTimeSpanSource?
        var entries: [FeedingEntry]
        var entryIDs: Set<UUID>
    }

    static func parse(data: Data, filename: String) throws -> BabyDataCSVImport {
        guard data.count <= 10 * 1_024 * 1_024 else {
            throw BabyDataCSVImportError.fileTooLarge
        }
        guard var text = String(data: data, encoding: .utf8) else {
            throw BabyDataCSVImportError.unreadableText
        }
        if text.first == "\u{FEFF}" { text.removeFirst() }

        let table = try parseRows(text)
        guard let header = table.first, table.count <= 50_001 else {
            throw BabyDataCSVImportError.unsupportedFormat
        }

        var indices: [String: Int] = [:]
        for (index, name) in header.enumerated() {
            let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if indices[normalized] == nil { indices[normalized] = index }
        }
        let required = ["record_id", "record_type", "recorded_at", "item_type", "title", "amount", "unit", "duration_minutes", "detail", "note", "mood", "source_session_id"]
        guard required.allSatisfy({ indices[$0] != nil }) else {
            throw BabyDataCSVImportError.unsupportedFormat
        }

        func value(_ name: String, in row: [String]) -> String {
            guard let index = indices[name], row.indices.contains(index) else { return "" }
            return row[index].trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var feedingOrder: [UUID] = []
        var feedingByID: [UUID: FeedingAccumulator] = [:]
        var careRecords: [CareRecord] = []
        var growthRecords: [GrowthMetricRecord] = []
        var careIDs: Set<UUID> = []
        var growthIDs: Set<UUID> = []
        var skippedRows = 0

        for row in table.dropFirst() where !row.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            guard let recordID = UUID(uuidString: value("record_id", in: row)),
                  let recordedAt = parseDate(value("recorded_at", in: row)) else {
                skippedRows += 1
                continue
            }

            let recordType = value("record_type", in: row)
            switch recordType {
            case "feeding":
                let sourceID = UUID(uuidString: value("source_session_id", in: row)) ?? recordID
                guard let entry = feedingEntry(
                    id: recordID,
                    itemType: value("item_type", in: row),
                    amount: value("amount", in: row),
                    unit: value("unit", in: row),
                    duration: value("duration_minutes", in: row),
                    detail: value("detail", in: row),
                    breastMode: value("breast_mode", in: row),
                    breastSide: value("breast_side", in: row),
                    milkType: value("milk_type", in: row),
                    solidFood: value("solid_food", in: row),
                    solidUnit: value("solid_unit", in: row)
                ) else {
                    skippedRows += 1
                    continue
                }

                if var accumulator = feedingByID[sourceID] {
                    guard !accumulator.entryIDs.contains(entry.id) else {
                        skippedRows += 1
                        continue
                    }
                    accumulator.entries.append(entry)
                    accumulator.entryIDs.insert(entry.id)
                    feedingByID[sourceID] = accumulator
                } else {
                    feedingOrder.append(sourceID)
                    feedingByID[sourceID] = FeedingAccumulator(
                        createdAt: recordedAt,
                        notes: value("note", in: row),
                        mood: BabyMood(rawValue: value("mood", in: row)) ?? .happy,
                        startAt: parseDate(value("start_at", in: row)),
                        endAt: parseDate(value("end_at", in: row)),
                        timeSpanSource: FeedingTimeSpanSource(rawValue: value("time_span_source", in: row)),
                        entries: [entry],
                        entryIDs: [entry.id]
                    )
                }

            case CareRecordKind.diaper.rawValue, CareRecordKind.activity.rawValue, CareRecordKind.sleep.rawValue:
                guard !careIDs.contains(recordID), let kind = CareRecordKind(rawValue: recordType) else {
                    skippedRows += 1
                    continue
                }
                var detail = value("detail", in: row)
                if detail.isEmpty, let duration = positiveInt(value("duration_minutes", in: row)) {
                    detail = "\(duration) 分钟"
                }
                let record = CareRecord(
                    id: recordID,
                    kind: kind,
                    title: value("title", in: row),
                    detail: detail,
                    note: value("note", in: row),
                    recordedAt: recordedAt
                )
                guard let sanitized = record.sanitized() else {
                    skippedRows += 1
                    continue
                }
                careIDs.insert(recordID)
                careRecords.append(sanitized)

            case "growth":
                guard !growthIDs.contains(recordID),
                      let kind = GrowthMetricKind(rawValue: value("item_type", in: row)),
                      let amount = Double(value("amount", in: row)),
                      amount.isFinite,
                      kind.validRange.contains(amount),
                      recordedAt <= Date() else {
                    skippedRows += 1
                    continue
                }
                growthIDs.insert(recordID)
                growthRecords.append(GrowthMetricRecord(
                    id: recordID,
                    kind: kind,
                    value: amount,
                    note: value("note", in: row),
                    recordedAt: recordedAt
                ))

            default:
                skippedRows += 1
            }
        }

        let feedingSessions = feedingOrder.compactMap { id -> FeedingSession? in
            guard let accumulator = feedingByID[id] else { return nil }
            return FeedingSession(
                id: id,
                entries: accumulator.entries,
                notes: accumulator.notes,
                babyMood: accumulator.mood,
                createdAt: accumulator.createdAt,
                startAt: accumulator.startAt,
                endAt: accumulator.endAt,
                timeSpanSource: accumulator.timeSpanSource
            ).sanitized()
        }

        return BabyDataCSVImport(
            filename: String(filename.replacingOccurrences(of: "\n", with: " ").prefix(120)),
            feedingSessions: feedingSessions.sorted { $0.eventDate > $1.eventDate },
            careRecords: careRecords.sorted { $0.recordedAt > $1.recordedAt },
            growthRecords: growthRecords.sorted { $0.recordedAt > $1.recordedAt },
            skippedRowCount: skippedRows
        )
    }

    private static func feedingEntry(
        id: UUID,
        itemType: String,
        amount: String,
        unit: String,
        duration: String,
        detail: String,
        breastMode: String,
        breastSide: String,
        milkType: String,
        solidFood: String,
        solidUnit: String
    ) -> FeedingEntry? {
        guard let type = FeedingType(rawValue: itemType) else { return nil }
        let entry: FeedingEntry
        switch type {
        case .breast:
            let mode = BreastFeedingMode(rawValue: breastMode)
                ?? BreastFeedingMode.allCases.first(where: { detail.contains($0.displayName) })
                ?? .nursing
            let side = BreastSide(rawValue: breastSide)
                ?? BreastSide.allCases.first(where: { detail.contains($0.displayName) })
                ?? .left
            entry = FeedingEntry(
                id: id,
                type: .breast,
                breastMode: mode,
                breastSide: side,
                breastDuration: positiveInt(duration)
            )
        case .bottle:
            let resolvedMilkType = MilkType(rawValue: milkType)
                ?? MilkType.allCases.first(where: { detail == $0.displayName })
                ?? .formula
            entry = FeedingEntry(
                id: id,
                type: .bottle,
                milkType: resolvedMilkType,
                bottleAmount: positiveInt(amount),
                bottleDuration: positiveInt(duration)
            )
        case .solid:
            let resolvedFood = SolidFood(rawValue: solidFood)
                ?? SolidFood.allCases.first(where: { detail == $0.displayName })
                ?? .other
            let resolvedUnit = SolidUnit(rawValue: solidUnit)
                ?? SolidUnit.allCases.first(where: { unit == $0.displayName })
                ?? resolvedFood.suggestedUnit
            entry = FeedingEntry(
                id: id,
                type: .solid,
                solidFood: resolvedFood,
                solidAmount: Double(amount),
                solidUnit: resolvedUnit
            )
        }
        return entry.sanitized()
    }

    private static func positiveInt(_ value: String) -> Int? {
        guard let number = Int(value), number > 0 else { return nil }
        return number
    }

    private static func parseDate(_ value: String) -> Date? {
        guard !value.isEmpty else { return nil }
        if let date = csvDateFormatter.date(from: value) { return date }
        return ISO8601DateFormatter().date(from: value)
    }

    private static func parseRows(_ text: String) throws -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var index = text.startIndex

        func finishField() {
            row.append(field)
            field = ""
        }

        func finishRow() {
            finishField()
            rows.append(row)
            row = []
        }

        while index < text.endIndex {
            let character = text[index]
            let nextIndex = text.index(after: index)
            if character == "\"" {
                if inQuotes, nextIndex < text.endIndex, text[nextIndex] == "\"" {
                    field.append("\"")
                    index = text.index(after: nextIndex)
                    continue
                }
                inQuotes.toggle()
            } else if character == ",", !inQuotes {
                finishField()
            } else if (character == "\n" || character == "\r"), !inQuotes {
                finishRow()
                if character == "\r", nextIndex < text.endIndex, text[nextIndex] == "\n" {
                    index = text.index(after: nextIndex)
                    continue
                }
            } else {
                field.append(character)
            }
            index = nextIndex
        }

        guard !inQuotes else { throw BabyDataCSVImportError.malformedCSV }
        if !field.isEmpty || !row.isEmpty { finishRow() }
        return rows
    }

    private static let csvDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
}

struct FamilySharingView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var familyCloudStore: FamilyCloudStore
    @State private var shareController: FamilyCloudShareSheet?
    @State private var errorMessage: String?
    @State private var isPreparingInvite = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    statusCard
                    inviteCard
                    dataCard
                }
                .padding(20)
            }
            .background(ProfileSoftBackground().ignoresSafeArea())
            .navigationTitle("家庭共享")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    AppPageCloseButton { dismiss() }
                }
            }
            .task {
                await familyCloudStore.bootstrapIfNeeded()
            }
            .sheet(item: $shareController) { sheet in
                sheet
            }
            .alert("家庭共享暂不可用", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: statusIcon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(statusColor)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(statusColor.opacity(0.14)))

                VStack(alignment: .leading, spacing: 4) {
                    Text(familyCloudStore.state.title.localized)
                        .font(BBBFont.font(size: 15, weight: .bold))
                        .foregroundStyle(DesignToken.textPrimary)
                    Text(familyCloudStore.state.detail.localized)
                        .font(BBBFont.font(size: 12, weight: .medium))
                        .foregroundStyle(DesignToken.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let lastSyncAt = familyCloudStore.lastSyncAt {
                Label("上次同步 \(AppDateTimeFormat.dateTime(lastSyncAt))", systemImage: "clock.arrow.circlepath")
                    .font(BBBFont.font(size: 12, weight: .semibold))
                    .foregroundStyle(DesignToken.textSecondary)
            }

            if familyCloudStore.hasPendingChanges {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text(syncStatusText.localized)
                    Spacer(minLength: 8)
                    Button("重试") {
                        familyCloudStore.retryNow()
                    }
                    .font(BBBFont.font(size: 12, weight: .heavy))
                    .foregroundStyle(DesignToken.primary)
                    .frame(minWidth: 44, minHeight: 44)
                }
                .font(BBBFont.font(size: 12, weight: .semibold))
                .foregroundStyle(DesignToken.textSecondary)
            }
        }
        .padding(15)
        .softProfileCard(cornerRadius: 20)
    }

    private var inviteCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("邀请另一位家长")
                .font(BBBFont.font(size: 16, weight: .heavy))
                .foregroundStyle(DesignToken.textPrimary)

            Text("会打开 Apple 的系统分享面板。对方接受后，就能和你一起查看、添加和编辑这个宝宝的记录。")
                .font(BBBFont.font(size: 12, weight: .medium))
                .foregroundStyle(DesignToken.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                prepareInvite()
            } label: {
                HStack {
                    if isPreparingInvite {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "person.badge.plus.fill")
                    }
                    Text(isPreparingInvite ? "正在准备邀请" : "邀请另一位家长")
                }
                .font(BBBFont.font(size: 15, weight: .bold))
                .foregroundStyle(DesignToken.onPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(Capsule().fill(DesignToken.primaryGradient))
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(isPreparingInvite)
        }
        .padding(15)
        .softProfileCard(cornerRadius: 20)
    }

    private var dataCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("会同步的数据")
                .font(BBBFont.font(size: 15, weight: .bold))
                .foregroundStyle(DesignToken.textPrimary)

            syncRow(icon: "person.crop.circle.fill", text: "宝宝资料")
            syncRow(icon: "fork.knife.circle.fill", text: "喂养记录")
            syncRow(icon: "drop.fill", text: "尿布记录")
            syncRow(icon: "moon.fill", text: "睡眠记录")
            syncRow(icon: "trophy.fill", text: "成长成就和贴纸")
            syncRow(icon: "pawprint.fill", text: "当前 Buddy 与友情进度")
        }
        .padding(15)
        .softProfileCard(cornerRadius: 20)
    }

    private func syncRow(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .font(BBBFont.font(size: 13, weight: .semibold))
            .foregroundStyle(DesignToken.textPrimary)
            .labelStyle(.titleAndIcon)
    }

    private var statusIcon: String {
        switch familyCloudStore.state {
        case .plusRequired: return "sparkles"
        case .iCloudUnavailable, .failed: return "exclamationmark.icloud.fill"
        case .syncing, .checkingAccount: return "icloud.and.arrow.up.fill"
        case .ownerShared, .joinedShared: return "person.2.fill"
        case .localOnly: return "iphone"
        }
    }

    private var statusColor: Color {
        switch familyCloudStore.state {
        case .plusRequired: return DesignToken.primary
        case .iCloudUnavailable, .failed: return DesignToken.errorRed
        case .syncing, .checkingAccount: return DesignToken.accentBlue
        case .ownerShared, .joinedShared: return DesignToken.success
        case .localOnly: return DesignToken.primary
        }
    }

    private var syncStatusText: String {
        switch familyCloudStore.syncPhase {
        case .waitingForNetwork:
            return "当前离线，记录已保存在本机"
        case .syncing, .retryScheduled:
            return "记录已保存在本机，正在同步"
        case .failed:
            return "家庭同步未完成，记录仍保存在本机"
        case .idle, .checking:
            return "有记录等待同步"
        }
    }

    private func prepareInvite() {
        isPreparingInvite = true
        Task {
            do {
                let controller = try await familyCloudStore.makeInviteController()
                shareController = FamilyCloudShareSheet(controller: controller)
            } catch {
                errorMessage = error.localizedDescription
            }
            isPreparingInvite = false
        }
    }
}

extension FamilyCloudShareSheet: Identifiable {
    var id: ObjectIdentifier {
        ObjectIdentifier(controller)
    }
}

struct BabyInfoHeaderView: View {
    @Environment(BabyProfileStore.self) private var profileStore
    @EnvironmentObject private var growthMetricStore: GrowthMetricStore

    let onOpenProfile: () -> Void
    let onOpenMetric: (GrowthMetricKind) -> Void

    init(
        onOpenProfile: @escaping () -> Void = {},
        onOpenMetric: @escaping (GrowthMetricKind) -> Void = { _ in }
    ) {
        self.onOpenProfile = onOpenProfile
        self.onOpenMetric = onOpenMetric
    }

    var body: some View {
        let profile = profileStore.currentProfile

        VStack(alignment: .leading, spacing: 14) {
            Button(action: onOpenProfile) {
                HStack(spacing: 14) {
                    profileAvatar(profile, size: 56, emojiSize: 28)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("宝宝资料")
                            .font(BBBFont.font(size: 10, weight: .bold))
                            .foregroundStyle(DesignToken.primary)

                        Text(profile.name)
                            .font(BBBFont.font(size: 20, weight: .bold))
                            .foregroundStyle(DesignToken.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)

                        Text("\(profile.ageDisplayText) · \(genderTitle(profile.gender))")
                            .font(BBBFont.font(size: 12, weight: .medium))
                            .foregroundStyle(DesignToken.textSecondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 10)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(DesignToken.primary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(DesignToken.primary.opacity(0.10)))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("编辑宝宝资料".localized))

            HStack(spacing: 10) {
                metricCard(.height, value: metricValue(for: .height, profile: profile))
                metricCard(.weight, value: metricValue(for: .weight, profile: profile))
            }
        }
        .padding(16)
        .softProfileCard(cornerRadius: 24, shadowOpacity: 0.05)
    }

    private func metricValue(for kind: GrowthMetricKind, profile: BabyProfileData) -> String {
        if let value = growthMetricStore.latest(kind: kind)?.value {
            return formattedMetric(value, kind: kind)
        }

        let profileValue: Double?
        switch kind {
        case .height:
            profileValue = profile.heightCm
        case .weight:
            profileValue = profile.weightKg
        }

        guard let profileValue, profileValue.isFinite else {
            return "-- \(displayUnit(for: kind))"
        }
        return formattedMetric(profileValue, kind: kind)
    }

    private func formattedMetric(_ value: Double, kind: GrowthMetricKind) -> String {
        switch kind {
        case .height:
            return AppMeasurementFormat.height(value)
        case .weight:
            return AppMeasurementFormat.weight(value)
        }
    }

    private func displayUnit(for kind: GrowthMetricKind) -> String {
        switch kind {
        case .height:
            return AppMeasurementFormat.heightUnit
        case .weight:
            return AppMeasurementFormat.weightPrimaryUnit
        }
    }

    private func metricCard(_ kind: GrowthMetricKind, value: String) -> some View {
        Button {
            onOpenMetric(kind)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: kind.icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(kind.accent)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(kind.accent.opacity(0.13)))

                VStack(alignment: .leading, spacing: 2) {
                    Text(kind.title)
                        .font(BBBFont.font(size: 11, weight: .semibold))
                        .foregroundStyle(DesignToken.textSecondary)
                    Text(value)
                        .font(BBBFont.font(size: 15, weight: .heavy))
                        .foregroundStyle(DesignToken.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(DesignToken.textFaint)
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(kind.accent.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(kind.accent.opacity(0.12), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("\(kind.title) \(value)")
        .accessibilityHint("打开\(kind.title)记录")
    }

    private func genderTitle(_ gender: BabyGender) -> String {
        switch gender {
        case .boy: return "男宝".localized
        case .girl: return "女宝".localized
        }
    }

    @ViewBuilder
    private func profileAvatar(_ profile: BabyProfileData, size: CGFloat, emojiSize: CGFloat) -> some View {
        BabyProfileAvatarView(
            profile: profile,
            size: size,
            emojiSize: emojiSize,
            lineWidth: 2,
            motionScale: 0.75
        )
    }
}
