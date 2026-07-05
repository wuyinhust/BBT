import SwiftUI
import UIKit

struct ProfileSoftBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: "#FBF9FF"),
                    Color(hex: "#F7F3FF"),
                    Color(hex: "#FFF7FB")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    DesignToken.primary.opacity(0.16),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 24,
                endRadius: 340
            )

            RadialGradient(
                colors: [
                    Color(hex: "#FFD9A8").opacity(0.14),
                    .clear
                ],
                center: .bottomLeading,
                startRadius: 36,
                endRadius: 380
            )
        }
    }
}

private struct SoftProfileCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    let shadowOpacity: Double

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.white.opacity(0.94))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(.white.opacity(0.86), lineWidth: 1.1)
                    )
                    .shadow(color: Color(hex: "#7E5DE8").opacity(shadowOpacity), radius: 14, y: 6)
            )
    }
}

extension View {
    func softProfileCard(cornerRadius: CGFloat, shadowOpacity: Double = 0.06) -> some View {
        modifier(SoftProfileCardModifier(cornerRadius: cornerRadius, shadowOpacity: shadowOpacity))
    }
}

struct ProfileView: View {
    @Binding var showBabyInfo: Bool
    @EnvironmentObject private var feedingStore: FeedingStore
    @EnvironmentObject private var activityStore: ActivityStore
    @EnvironmentObject private var growthMetricStore: GrowthMetricStore
    @EnvironmentObject private var membershipStore: PlusMembershipStore
    @State private var showFamilySharing = false
    @State private var showPlusMembership = false
    @State private var showLocalBabyInfo = false
    @State private var showDailyVisitors = false
    @State private var showOnboarding = false
    @State private var showSettings = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                Button {
                    showLocalBabyInfo = true
                } label: {
                    BabyInfoHeaderView()
                }
                .buttonStyle(ScaleButtonStyle())

                profileSummaryCard
                menuCard
                appVersionFooter
                Spacer(minLength: 72)
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 88)
        }
        .background(ProfileSoftBackground().ignoresSafeArea())
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
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(feedingStore)
                .environmentObject(activityStore)
                .environmentObject(growthMetricStore)
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
                Text(title)
                    .font(BBBFont.font(size: 11, weight: .semibold))
                    .foregroundStyle(DesignToken.textSecondary)
                Text(value)
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
            menu(icon: "chart.bar.fill", color: Color(hex: "#9ABAF2"), title: "统计报告", subtitle: "查看成长趋势")
            line
            Button {
                showDailyVisitors = true
            } label: {
                menu(icon: "sunrise.fill", color: Color(hex: "#F0A35E"), title: "每日来访", subtitle: "照护节奏 · 伙伴来访记录")
            }
            .buttonStyle(.plain)
            line
            Button {
                showPlusMembership = true
            } label: {
                menu(icon: "sparkles", color: Color(hex: "#9F7AEA"), title: "BabyBuddy Plus", subtitle: membershipStore.profileSubtitle)
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
                menu(icon: "person.2.fill", color: Color(hex: "#67C587"), title: "家庭共享", subtitle: familySharingSubtitle)
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
            Button {
                showSettings = true
            } label: {
                menu(icon: "gearshape.fill", color: Color(hex: "#7F8098"), title: "设置", subtitle: "通知 · 数据 · 偏好")
            }
            .buttonStyle(.plain)
            line
            menu(icon: "info.circle.fill", color: Color(hex: "#7F8098"), title: "关于 BabyBuddy", subtitle: "版本与帮助")
        }
        .padding(.vertical, 5)
        .softProfileCard(cornerRadius: 20)
    }

    private var appVersionFooter: some View {
        HStack(spacing: 8) {
            if !AppVariant.isAppStoreReview {
                Text("测试版")
                    .font(BBBFont.font(size: 10, weight: .heavy))
                    .foregroundStyle(.white)
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
        membershipStore.isPlusActive ? "邀请另一位家长共同记录" : "Plus 权益 · 家庭共同记录"
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
                Text(title)
                    .font(BBBFont.font(size: 15, weight: .bold))
                    .foregroundStyle(DesignToken.textPrimary)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(BBBFont.font(size: 12, weight: .medium))
                        .foregroundStyle(DesignToken.textSecondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color(hex: "#E1DFEA"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

private struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var feedingStore: FeedingStore
    @EnvironmentObject private var activityStore: ActivityStore
    @EnvironmentObject private var growthMetricStore: GrowthMetricStore
    @AppStorage("buddy_card_reduced_effects_enabled") private var reducedBuddyCardEffects = false
    @AppStorage(RecordHomeMode.storageKey) private var recordHomeModeRaw = RecordHomeMode.basic.rawValue
    @State private var selectedAppIconName: String?
    @State private var shareFile: ExportedCSVFile?
    @State private var exportError: String?
    @State private var appIconError: String?

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    homeModeCard
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

    private var homeModeCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "rectangle.grid.1x2.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(DesignToken.primary)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(DesignToken.primary.opacity(0.14)))

                VStack(alignment: .leading, spacing: 4) {
                    Text("首页模式")
                        .font(BBBFont.font(size: 16, weight: .heavy))
                        .foregroundStyle(DesignToken.textPrimary)
                    Text(currentHomeMode.subtitle)
                        .font(BBBFont.font(size: 12, weight: .semibold))
                        .foregroundStyle(DesignToken.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Picker("首页模式", selection: $recordHomeModeRaw) {
                ForEach(RecordHomeMode.allCases) { mode in
                    Text(mode.title).tag(mode.rawValue)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(16)
        .softProfileCard(cornerRadius: 22)
    }

    private var currentHomeMode: RecordHomeMode {
        RecordHomeMode(rawValue: recordHomeModeRaw) ?? .basic
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
                            .stroke(isSelected ? DesignToken.primary : Color.white.opacity(0.78), lineWidth: isSelected ? 2 : 1)
                    )
                    .shadow(color: Color(hex: "#4D4B70").opacity(0.10), radius: 8, y: 4)

                Text(option.title)
                    .font(BBBFont.font(size: 11, weight: .heavy))
                    .foregroundStyle(isSelected ? DesignToken.primary : DesignToken.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? DesignToken.primary.opacity(0.12) : Color.white.opacity(0.54))
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
                        .foregroundStyle(Color(hex: "#7F8098"))
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(Color(hex: "#7F8098").opacity(0.13)))

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
                .foregroundStyle(.white)
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
        return "导出全部历史记录：喂养 \(feedingCount) 条、护理 \(careCount) 条、成长 \(growthCount) 条。"
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
        case .primary: return "默认"
        case .alt1: return "占位 1"
        case .alt2: return "占位 2"
        case .alt3: return "占位 3"
        case .alt4: return "占位 4"
        case .alt5: return "占位 5"
        case .alt6: return "占位 6"
        case .alt7: return "占位 7"
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
                    Text(familyCloudStore.state.title)
                        .font(BBBFont.font(size: 15, weight: .bold))
                        .foregroundStyle(DesignToken.textPrimary)
                    Text(familyCloudStore.state.detail)
                        .font(BBBFont.font(size: 12, weight: .medium))
                        .foregroundStyle(DesignToken.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let lastSyncAt = familyCloudStore.lastSyncAt {
                Label("上次同步 \(lastSyncAt.formatted(date: .omitted, time: .shortened))", systemImage: "clock.arrow.circlepath")
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
                .foregroundStyle(.white)
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
            syncRow(icon: "pawprint.fill", text: "当前陪伴动物和未来动物状态")
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
        case .syncing, .checkingAccount: return Color(hex: "#6DA5F2")
        case .ownerShared, .joinedShared: return Color(hex: "#67C587")
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
    @EnvironmentObject private var recruitmentStore: CompanionRecruitmentStore
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
                    recruitmentStore: recruitmentStore
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
                            .foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                            .background(Circle().fill(DesignToken.primary))
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(report.dateText)
                        .font(BBBFont.font(size: 15, weight: .heavy))
                        .foregroundStyle(DesignToken.textPrimary)
                    Text("\(companions.map(\.chineseName).joined(separator: "、")) 来访 · \(CompanionRecruitmentStore.currencyText(latestReport.earnedBBBucks))")
                        .font(BBBFont.font(size: 12, weight: .semibold))
                        .foregroundStyle(DesignToken.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.86)
                }

                Spacer()

                Text(hasFed ? "已喂" : "未喂")
                    .font(BBBFont.font(size: 10, weight: .heavy))
                    .foregroundStyle(hasFed ? Color(hex: "#67C587") : DesignToken.primary)
                    .padding(.horizontal, 9)
                    .frame(height: 24)
                    .background(Capsule().fill((hasFed ? Color(hex: "#67C587") : DesignToken.primary).opacity(0.12)))
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

        VStack(spacing: 12) {
            HStack(spacing: 12) {
                profileAvatar(profile, size: 58, emojiSize: 30)
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(profile.name)
                            .font(BBBFont.font(size: 22, weight: .heavy))
                            .foregroundStyle(DesignToken.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                        Image(systemName: "triangle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(DesignToken.primary)
                    }
                    HStack(spacing: 8) {
                        label(icon: "clock.badge.checkmark", text: profile.ageDisplayText)
                        label(icon: "figure.stand", text: profile.gender.rawValue)
                    }
                }
                Spacer()
            }

            HStack(spacing: 10) {
                infoChip(title: "年龄", value: profile.ageDisplayText)
                infoChip(title: "性别", value: genderTitle(profile.gender))
                Spacer()
            }
        }
        .padding(15)
        .softProfileCard(cornerRadius: 22)
    }

    private func label(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(text)
        }
        .font(BBBFont.font(size: 11, weight: .semibold))
        .foregroundStyle(DesignToken.textSecondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color(hex: "#F6F4FA").opacity(0.82)))
    }

    private func infoChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(BBBFont.font(size: 10, weight: .semibold))
                .foregroundStyle(DesignToken.textSecondary)
            Text(value)
                .font(BBBFont.font(size: 13, weight: .bold))
                .foregroundStyle(DesignToken.textPrimary)
        }
        .frame(minWidth: 78, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(hex: "#F6F4FA").opacity(0.82)))
    }

    private func genderTitle(_ gender: BabyGender) -> String {
        switch gender {
        case .boy: return "男宝"
        case .girl: return "女宝"
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
