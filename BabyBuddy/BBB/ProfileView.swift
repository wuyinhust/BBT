import SwiftUI
import UIKit

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
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var feedingStore: FeedingStore
    @EnvironmentObject private var activityStore: ActivityStore
    @EnvironmentObject private var growthMetricStore: GrowthMetricStore
    @EnvironmentObject private var membershipStore: PlusMembershipStore
    @State private var showFamilySharing = false
    @State private var showPlusMembership = false
    @State private var showLocalBabyInfo = false
    @State private var showDailyVisitors = false
    @State private var showOnboarding = false
    @State private var showDarkModeDemo = false
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
    @State private var shareFile: ExportedCSVFile?
    @State private var exportError: String?
    private let showsDarkModeDemoEntry: Bool

    init(showsDarkModeDemoEntry: Bool = true) {
        self.showsDarkModeDemoEntry = showsDarkModeDemoEntry
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                Button {
                    showLocalBabyInfo = true
                } label: {
                    BabyInfoHeaderView()
                }
                .buttonStyle(ScaleButtonStyle())

                familySection
                preferenceSection
                buddySection
                dataSection
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
            DailyVisitorArchiveView()
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView(prefillFromProfile: true) {
                showOnboarding = false
            }
        }
        #if DEBUG
        .fullScreenCover(isPresented: $showDarkModeDemo) {
            DarkModeDesignDemoView()
        }
        #endif
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
    }

    private var familySection: some View {
        settingsSection("家庭与会员") {
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

            Button {
                showPlusMembership = true
            } label: {
                settingsActionRow(
                    icon: "sparkles",
                    color: DesignToken.primary,
                    title: "BabyBuddy Plus",
                    subtitle: membershipStore.profileSubtitle
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var preferenceSection: some View {
        settingsSection("使用偏好") {
            Button {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                openURL(url)
            } label: {
                settingsActionRow(
                    icon: AppSemanticIcon.language,
                    color: DesignToken.accentBlue,
                    title: "当前语言",
                    subtitle: AppLanguage.current.displayName
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("当前语言".localized)
            .accessibilityValue(AppLanguage.current.displayName)
            .accessibilityHint("在 iOS 设置中更改 BBBUDDY 使用的语言".localized)
            .accessibilityIdentifier("settings.currentLanguage")

            settingsDivider

            Menu {
                Picker("单位", selection: $measurementPreferenceRaw) {
                    ForEach(MeasurementSystemPreference.allCases) { preference in
                        Text(preference.title).tag(preference.rawValue)
                    }
                }
            } label: {
                settingsActionRow(
                    icon: AppSemanticIcon.measurement,
                    color: DesignToken.easyActivity,
                    title: "单位",
                    subtitle: AppMeasurementFormat.preferenceSummary,
                    trailingSystemName: "chevron.up.chevron.down"
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("单位".localized)
            .accessibilityValue(AppMeasurementFormat.preferenceSummary)
            .accessibilityHint("选择跟随地区、公制或英制".localized)
            .accessibilityIdentifier("settings.measurementSystem")

            settingsDivider

            Menu {
                Picker("生长标准", selection: $growthStandardPreferenceRaw) {
                    ForEach(GrowthStandardPreference.allCases) { preference in
                        Text(preference.title).tag(preference.rawValue)
                    }
                }
            } label: {
                settingsActionRow(
                    icon: "chart.xyaxis.line",
                    color: DesignToken.easyActivity,
                    title: "生长标准",
                    subtitle: growthStandardPreferenceSummary,
                    trailingSystemName: "chevron.up.chevron.down"
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("生长标准")
            .accessibilityValue(growthStandardPreferenceSummary)
            .accessibilityHint("选择 WHO 2006 或国家卫健委 7 岁以下儿童生长标准")
            .accessibilityIdentifier("settings.growthStandard")

            settingsDivider

            Menu {
                Picker("外观", selection: $appearanceModeRaw) {
                    ForEach(AppAppearanceMode.allCases) { mode in
                        Text(mode.title).tag(mode.rawValue)
                    }
                }
            } label: {
                settingsActionRow(
                    icon: "circle.lefthalf.filled",
                    color: DesignToken.primary,
                    title: "外观",
                    subtitle: currentAppearanceMode.title,
                    trailingSystemName: "chevron.up.chevron.down"
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("外观")
            .accessibilityValue(currentAppearanceMode.title)
            .accessibilityHint("选择跟随系统、浅色或深色")
            .accessibilityIdentifier("settings.appearance")

            settingsDivider

            Toggle(isOn: $reducedBuddyCardEffects) {
                settingsControlHeader(
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

    private var buddySection: some View {
        settingsSection("Buddy 与来访") {
            Button {
                showDailyVisitors = true
            } label: {
                settingsActionRow(
                    icon: "sunrise.fill",
                    color: DesignToken.reward,
                    title: "每日来访",
                    subtitle: "查看照护节奏与伙伴来访记录"
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
            Button {
                exportCSV()
            } label: {
                settingsActionRow(
                    icon: "square.and.arrow.up.fill",
                    color: DesignToken.accentBlue,
                    title: "导出照护记录",
                    subtitle: exportSubtitle,
                    trailingSystemName: "square.and.arrow.up"
                )
            }
            .buttonStyle(.plain)
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
                Text("BabyBuddy")
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

    private func exportCSV() {
        do {
            shareFile = try BabyDataCSVExporter.export(
                feedingSessions: feedingStore.exportSessions(),
                careRecords: activityStore.exportCareRecords(),
                growthRecords: growthMetricStore.exportRecords()
            )
        } catch {
            exportError = "请稍后重试，或检查设备存储空间。"
        }
    }

    private var profileSummaryCard: some View {
        HStack(spacing: 12) {
            summaryPill(icon: "calendar", title: "成长", value: "持续记录")
            summaryPill(icon: "heart.fill", title: "健康", value: "每日护理")
        }
        .padding(13)
        .softProfileCard(cornerRadius: 20)
    }

    private func summaryPill(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(DesignToken.primary)
                .frame(width: 30, height: 30)
                .background(Circle().fill(DesignToken.primary.opacity(0.13)))
            VStack(alignment: .leading, spacing: 2) {
                Text(title.localized)
                    .font(BBBFont.font(size: 11, weight: .semibold))
                    .foregroundStyle(DesignToken.textSecondary)
                Text(value.localized)
                    .font(BBBFont.font(size: 13, weight: .bold))
                    .foregroundStyle(DesignToken.textPrimary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    private var menuCard: some View {
        VStack(spacing: 0) {
            menu(icon: "heart.text.square.fill", color: DesignToken.primary, title: "健康记录", subtitle: "喂养 · 尿布 · 睡眠")
            line
            menu(icon: "chart.bar.fill", color: DesignToken.accentBlue, title: "统计报告", subtitle: "查看成长趋势")
            line
            Button {
                showDailyVisitors = true
            } label: {
                menu(icon: "sunrise.fill", color: DesignToken.reward, title: "每日来访", subtitle: "照护节奏 · 伙伴来访记录")
            }
            .buttonStyle(.plain)
            line
            Button {
                showPlusMembership = true
            } label: {
                menu(icon: "sparkles", color: DesignToken.primary, title: "BabyBuddy Plus", subtitle: membershipStore.profileSubtitle)
            }
            .buttonStyle(.plain)
            line
            Button {
                if membershipStore.isPlusActive {
                    showFamilySharing = true
                } else {
                    showPlusMembership = true
                }
            } label: {
                menu(icon: "person.2.fill", color: DesignToken.success, title: "家庭共享", subtitle: familySharingSubtitle)
            }
            .buttonStyle(.plain)
            line
            Button {
                showOnboarding = true
            } label: {
                menu(icon: "wand.and.stars", color: DesignToken.primarySoft, title: "气质测试与 Buddy", subtitle: "重新测试 · 自选伙伴")
            }
            .buttonStyle(.plain)
            line
            menu(icon: "info.circle.fill", color: DesignToken.grayNeutral, title: "关于 BabyBuddy", subtitle: "版本与帮助")
        }
        .padding(.vertical, 5)
        .softProfileCard(cornerRadius: 20)
    }

    private var appVersionFooter: some View {
        HStack(spacing: 8) {
            if !AppVariant.isAppStoreReview {
                Text("测试版")
                    .font(BBBFont.font(size: 10, weight: .heavy))
                    .foregroundStyle(DesignToken.onPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(DesignToken.primary.opacity(0.78)))
            }

            Text(AppVariant.versionText)
                .font(BBBFont.font(size: 11, weight: .semibold))
                .foregroundStyle(DesignToken.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 2)
        .accessibilityLabel(AppVariant.profileVersionText)
    }

    private var familySharingSubtitle: String {
        (membershipStore.isPlusActive ? "邀请另一位家长共同记录" : "Plus 权益 · 家庭共同记录").localized
    }

    private var currentAppearanceMode: AppAppearanceMode {
        AppAppearanceMode(rawValue: appearanceModeRaw) ?? .system
    }

    private var selectedGrowthStandard: GrowthReferenceStandard {
        GrowthStandardPreference(rawValue: growthStandardPreferenceRaw)?.resolvedStandard
            ?? GrowthStandardPreference.defaultStandard
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

    private var line: some View {
        Rectangle().fill(DesignToken.line.opacity(0.45)).frame(height: 1).padding(.leading, 64)
    }

    private func menu(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(color.opacity(0.12))
                .frame(width: 38, height: 38)
                .overlay(Image(systemName: icon).font(.system(size: 16, weight: .semibold)).foregroundStyle(color))
            VStack(alignment: .leading, spacing: 2) {
                Text(title.localized)
                    .font(BBBFont.font(size: 15, weight: .bold))
                    .foregroundStyle(DesignToken.textPrimary)
                if !subtitle.isEmpty {
                    Text(subtitle.localized)
                        .font(BBBFont.font(size: 12, weight: .medium))
                        .foregroundStyle(DesignToken.textSecondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(DesignToken.textFaint)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
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
                    AppPageCloseButton { dismiss() }
                        .background(Circle().fill(DesignToken.surfaceRaised.opacity(0.92)))
                        .overlay(Circle().stroke(DesignToken.borderSubtle.opacity(0.82), lineWidth: 1))
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
                    Button("关闭") { dismiss() }
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
        "source_session_id"
    ]

    static func export(
        feedingSessions: [FeedingSession],
        careRecords: [CareRecord],
        growthRecords: [GrowthMetricRecord]
    ) throws -> ExportedCSVFile {
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
            let duration = record.kind == .sleep
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
        let filename = "BabyBuddy-Export-\(filenameDateFormatter.string(from: Date())).csv"
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
            sourceSessionID: session.id.uuidString
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
        sourceSessionID: String
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
            sourceSessionID
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
        return String(format: "%.2f", value)
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
                    Button("关闭") { dismiss() }
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
        case .iCloudUnavailable, .failed: return "exclamationmark.icloud.fill"
        case .syncing, .checkingAccount: return "icloud.and.arrow.up.fill"
        case .ownerShared, .joinedShared: return "person.2.fill"
        case .localOnly: return "iphone"
        }
    }

    private var statusColor: Color {
        switch familyCloudStore.state {
        case .iCloudUnavailable, .failed: return DesignToken.errorRed
        case .syncing, .checkingAccount: return DesignToken.accentBlue
        case .ownerShared, .joinedShared: return DesignToken.success
        case .localOnly: return DesignToken.primary
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

struct DailyVisitorArchiveView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var feedingStore: FeedingStore
    @EnvironmentObject private var activityStore: ActivityStore
    @EnvironmentObject private var companionStore: CompanionStore
    @EnvironmentObject private var recruitmentStore: CompanionRecruitmentStore
    @EnvironmentObject private var temperamentStore: TemperamentProfileStore
    @State private var selectedReport: YesterdayReport?

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    if recruitmentStore.reports.isEmpty {
                        emptyState
                    } else {
                        ForEach(recruitmentStore.reports) { report in
                            reportRow(report)
                        }
                    }
                }
                .padding(20)
            }
            .background(ProfileSoftBackground().ignoresSafeArea())
            .navigationTitle("每日来访")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .sheet(item: $selectedReport) { report in
                YesterdayReportOverlay(report: report) {
                    selectedReport = nil
                }
                .environmentObject(recruitmentStore)
                .presentationBackground(.clear)
            }
            .onAppear {
                _ = DailyVisitorReportFactory.availableReport(
                    feedingStore: feedingStore,
                    activityStore: activityStore,
                    recruitmentStore: recruitmentStore,
                    ownedCompanionIDs: BabyCompanion.unlockedIDs(
                        selectedID: companionStore.selectedID,
                        temperamentAnimalID: temperamentStore.result?.animalID
                    ).union(recruitmentStore.recruitedIDs),
                    excludedVisitorIDs: [companionStore.selectedID]
                )
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sunrise.fill")
                .font(.system(size: 28, weight: .heavy))
                .foregroundStyle(DesignToken.primary)
            Text("还没有每日来访记录")
                .font(BBBFont.font(size: 16, weight: .heavy))
                .foregroundStyle(DesignToken.textPrimary)
            Text("每天 8 点后会根据近期照护记录生成来访卡。")
                .font(BBBFont.font(size: 12, weight: .semibold))
                .foregroundStyle(DesignToken.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .softProfileCard(cornerRadius: 22)
    }

    private func reportRow(_ report: YesterdayReport) -> some View {
        let latestReport = recruitmentStore.report(for: report.reportKey) ?? report
        let companions = latestReport.visitorIDs.map { BabyCompanion.companion(for: $0) }
        let companion = companions.first ?? BabyCompanion.companion(for: latestReport.visitorCompanionID)
        let hasFed = latestReport.feedings.contains { $0.servings > 0 }
        return Button {
            selectedReport = latestReport
        } label: {
            HStack(spacing: 12) {
                ZStack(alignment: .bottomTrailing) {
                    Image(companion.portraitAssetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 44, height: 44)
                        .padding(3)
                        .background(Circle().fill(DesignToken.primary.opacity(0.10)))

                    if companions.count > 1 {
                        Text("+\(companions.count - 1)")
                            .font(BBBFont.font(size: 9, weight: .heavy))
                            .foregroundStyle(DesignToken.onPrimary)
                            .frame(width: 20, height: 20)
                            .background(Circle().fill(DesignToken.primary))
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(report.dateText.localized)
                        .font(BBBFont.font(size: 15, weight: .heavy))
                        .foregroundStyle(DesignToken.textPrimary)
                    Text("\(companions.map(\.localizedName).joined(separator: "、")) 来访 · \(CompanionRecruitmentStore.currencyText(latestReport.earnedBBBucks))")
                        .font(BBBFont.font(size: 12, weight: .semibold))
                        .foregroundStyle(DesignToken.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.86)
                }

                Spacer()

                Text(hasFed ? "已招待" : "未招待")
                    .font(BBBFont.font(size: 10, weight: .heavy))
                    .foregroundStyle(hasFed ? DesignToken.success : DesignToken.primary)
                    .padding(.horizontal, 9)
                    .frame(height: 24)
                    .background(Capsule().fill((hasFed ? DesignToken.success : DesignToken.primary).opacity(0.12)))
            }
            .padding(14)
            .softProfileCard(cornerRadius: 20)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct BabyInfoHeaderView: View {
    @Environment(BabyProfileStore.self) private var profileStore

    var body: some View {
        let profile = profileStore.currentProfile

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
        .padding(16)
        .frame(minHeight: 88)
        .contentShape(Rectangle())
        .softProfileCard(cornerRadius: 24, shadowOpacity: 0.05)
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
