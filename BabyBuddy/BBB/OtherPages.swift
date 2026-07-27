import PhotosUI
import Photos
import SwiftUI
import UIKit
import AVFoundation
import CoreImage
import CoreVideo
import ImageIO
import MetalKit
import Harbeth
import CoreMotion
import Vision
import os

private let achievementCameraPerformanceLog = OSLog(
    subsystem: Bundle.main.bundleIdentifier ?? "BabyBuddy",
    category: "AchievementCamera"
)

/// The companion live room is a deliberately illustrated scene, so its chrome
/// keeps fixed broadcast pigments instead of inheriting app surface colors.
private enum LiveSceneRenderPalette {
    static let canvas = Color(hex: "#1AAE68") // color-audit: allow-fixed live scene pigment
    static let foreground = Color.white // color-audit: allow-fixed live scene pigment
    static let shadow = Color.black // color-audit: allow-fixed live scene pigment
    static let follow = Color(hex: "#FE3D76") // color-audit: allow-fixed live scene pigment
    static let join = Color(hex: "#415FEA") // color-audit: allow-fixed live scene pigment
    static let level = Color(hex: "#735DFF") // color-audit: allow-fixed live scene pigment
    static let careLevel = Color(hex: "#FF9B42") // color-audit: allow-fixed live scene pigment
    static let chatLevel = Color(hex: "#6888FF") // color-audit: allow-fixed live scene pigment
    static let badge = Color(hex: "#D7598B") // color-audit: allow-fixed live scene pigment
    static let reactionStart = Color(hex: "#FF4A84") // color-audit: allow-fixed live scene pigment
    static let reactionEnd = Color(hex: "#7F5BFF") // color-audit: allow-fixed live scene pigment
}

/// Atmospheric backdrop pigments belong to the companion scene artwork, rather
/// than the reusable application UI palette.
private enum CompanionSceneRenderPalette {
    static func pigment(_ hex: String) -> Color {
        Color(hex: hex) // color-audit: allow-fixed companion scene artwork pigment
    }
}

private enum LiveSharePreviewPalette {
    static let foreground = Color.white // color-audit: allow-fixed share preview foreground
    static let mediaShadow = Color.black // color-audit: allow-fixed share preview media shadow
}

private enum LiveShareImageRenderPalette {
    static let white = UIColor.white // color-audit: allow-fixed exported share bitmap highlight
    static let black = UIColor.black // color-audit: allow-fixed exported share bitmap shadow
}

private enum AchievementMediaRenderPalette {
    static let stickerOutline = Color.white // color-audit: allow-fixed sticker cutout outline
    static let stickerShadow = Color.black // color-audit: allow-fixed sticker cutout shadow
    static let filterPreviewCanvas = Color(hex: "#202020") // color-audit: allow-fixed camera filter preview canvas
    static let watermarkGold = Color(hex: "#FFD66B") // color-audit: allow-fixed camera watermark pigment
    static let watermarkForeground = UIColor.white // color-audit: allow-fixed exported camera watermark foreground
    static let watermarkShadow = UIColor.black // color-audit: allow-fixed exported camera watermark shadow
    static let watermarkGoldUIColor = UIColor(red: 1, green: 0.84, blue: 0.42, alpha: 1) // color-audit: allow-fixed exported camera watermark pigment
}

struct DailyMessageView: View {
    var body: some View {
        Color.clear
            .ignoresSafeArea()
            .navigationBarBackButtonHidden(false)
            .toolbar(.hidden, for: .navigationBar)
    }
}

private struct BBBucksHistoryDay: Identifiable {
    let date: Date
    let transactions: [BBBuckTransaction]

    var id: Date { date }
}

struct BBBucksHistoryView: View {
    @EnvironmentObject private var recruitmentStore: CompanionRecruitmentStore
    @Environment(\.dismiss) private var dismiss

    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    balanceCard
                    earningRuleCard
                    historySection
                }
                .padding(.horizontal, DesignToken.screenHorizontalPadding)
                .padding(.top, 12)
                .padding(.bottom, 32)
                .frame(maxWidth: 560, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(HomeSoftBackground().ignoresSafeArea())
            .navigationTitle("BB Bucks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    AppPageCloseButton { dismiss() }
                }
            }
        }
    }

    private var balanceCard: some View {
        let todayAmount = transactionsReceivedToday.reduce(0) { $0 + $1.amount }

        return HStack(spacing: 14) {
            Image("bbbucks_coin")
                .resizable()
                .scaledToFit()
                .frame(width: 54, height: 54)
                .shadow(color: DesignToken.reward.opacity(0.22), radius: 9, y: 5)

            VStack(alignment: .leading, spacing: 4) {
                Text("当前余额")
                    .font(BBBFont.font(size: 11, weight: .heavy))
                    .foregroundStyle(DesignToken.rewardText.opacity(0.78))
                Text("\(recruitmentStore.bbBucks)")
                    .font(BBBFont.font(size: 30, weight: .heavy))
                    .foregroundStyle(DesignToken.rewardText)
                    .monospacedDigit()
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 4) {
                Text("今天到账")
                    .font(BBBFont.font(size: 10, weight: .heavy))
                    .foregroundStyle(DesignToken.rewardText.opacity(0.72))
                Text(todayAmount > 0 ? "+\(todayAmount)" : "—")
                    .font(BBBFont.font(size: 18, weight: .heavy))
                    .foregroundStyle(DesignToken.rewardText)
                    .monospacedDigit()
                Text(todayAmount > 0 ? "\(transactionsReceivedToday.count) 笔记录" : "暂未获得")
                    .font(BBBFont.font(size: 9, weight: .bold))
                    .foregroundStyle(DesignToken.rewardText.opacity(0.72))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [DesignToken.rewardSoft.opacity(0.94), DesignToken.surfaceRaised.opacity(0.94)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(DesignToken.glassStroke.opacity(0.88), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("当前 BB Bucks 余额 \(recruitmentStore.bbBucks)，今天到账 \(todayAmount)")
    }

    private var earningRuleCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(DesignToken.primary)
                .frame(width: 30, height: 30)
                .background(Circle().fill(DesignToken.primary.opacity(0.12)))

            VStack(alignment: .leading, spacing: 4) {
                Text("完整 EASY，才会获得 BB Bucks")
                    .font(BBBFont.font(size: 13, weight: .heavy))
                    .foregroundStyle(DesignToken.textPrimary)
                Text("每天前 3 轮各 +3；Plus 用户每轮额外 +1。")
                    .font(BBBFont.font(size: 10, weight: .semibold))
                    .foregroundStyle(DesignToken.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(DesignToken.primary.opacity(0.075))
        )
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("获取记录")
                    .font(BBBFont.font(size: 17, weight: .heavy))
                    .foregroundStyle(DesignToken.textPrimary)
                Spacer()
                Text("共 \(recruitmentStore.transactions.count) 笔")
                    .font(BBBFont.font(size: 10, weight: .bold))
                    .foregroundStyle(DesignToken.textSecondary)
            }

            if historyDays.isEmpty {
                emptyHistory
            } else {
                LazyVStack(spacing: 14) {
                    ForEach(historyDays) { day in
                        historyDay(day)
                    }
                }
            }
        }
    }

    private var emptyHistory: some View {
        VStack(spacing: 8) {
            Image("bbbucks_coin")
                .resizable()
                .scaledToFit()
                .frame(width: 34, height: 34)
                .opacity(0.54)
            Text("第一轮完整 EASY 会从这里开始记下。")
                .font(BBBFont.font(size: 11, weight: .semibold))
                .foregroundStyle(DesignToken.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(DesignToken.surfaceRaised.opacity(0.70))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(DesignToken.glassStroke.opacity(0.72), lineWidth: 1)
                )
        )
    }

    private func historyDay(_ day: BBBucksHistoryDay) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(dayTitle(for: day.date))
                .font(BBBFont.font(size: 11, weight: .heavy))
                .foregroundStyle(DesignToken.textSecondary)

            VStack(spacing: 0) {
                ForEach(Array(day.transactions.enumerated()), id: \.element.id) { index, transaction in
                    transactionRow(transaction)
                    if index < day.transactions.count - 1 {
                        Divider()
                            .overlay(DesignToken.borderSubtle.opacity(0.72))
                            .padding(.leading, 50)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(DesignToken.surfaceRaised.opacity(0.84))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(DesignToken.glassStroke.opacity(0.80), lineWidth: 1)
                    )
            )
        }
    }

    private func transactionRow(_ transaction: BBBuckTransaction) -> some View {
        HStack(spacing: 10) {
            Image("bbbucks_coin")
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)
                .padding(6)
                .background(Circle().fill(DesignToken.rewardSoft.opacity(0.72)))

            VStack(alignment: .leading, spacing: 3) {
                Text(transactionTitle(transaction))
                    .font(BBBFont.font(size: 13, weight: .heavy))
                    .foregroundStyle(DesignToken.textPrimary)
                Text(transactionDetail(transaction))
                    .font(BBBFont.font(size: 9.5, weight: .semibold))
                    .foregroundStyle(DesignToken.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                Text("+\(transaction.amount)")
                    .font(BBBFont.font(size: 14, weight: .heavy))
                    .foregroundStyle(DesignToken.rewardText)
                    .monospacedDigit()
                Text(AppDateTimeFormat.time(transaction.createdAt))
                    .font(BBBFont.font(size: 9, weight: .bold))
                    .foregroundStyle(DesignToken.textSecondary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(transactionTitle(transaction))，获得 \(transaction.amount) BB Bucks，\(transactionDetail(transaction))")
    }

    private var transactionsReceivedToday: [BBBuckTransaction] {
        recruitmentStore.transactions.filter { calendar.isDateInToday($0.createdAt) }
    }

    private var historyDays: [BBBucksHistoryDay] {
        let grouped = Dictionary(grouping: recruitmentStore.transactions) {
            calendar.startOfDay(for: $0.createdAt)
        }
        return grouped
            .map { date, transactions in
                BBBucksHistoryDay(date: date, transactions: transactions.sorted { $0.createdAt > $1.createdAt })
            }
            .sorted { $0.date > $1.date }
    }

    private func dayTitle(for date: Date) -> String {
        if calendar.isDateInToday(date) { return "今天" }
        if calendar.isDateInYesterday(date) { return "昨天" }
        return AppDateTimeFormat.date(date)
    }

    private func transactionTitle(_ transaction: BBBuckTransaction) -> String {
        switch transaction.source {
        case .easyCycle: return "完整 EASY 循环"
        case .historicalImport: return "历史照护补发"
        case .migration: return "历史余额迁移"
        }
    }

    private func transactionDetail(_ transaction: BBBuckTransaction) -> String {
        switch transaction.source {
        case .easyCycle:
            if transaction.plusBonus > 0 {
                return "基础 +\(transaction.baseAmount) · Plus +\(transaction.plusBonus)"
            }
            return "完整 EASY 奖励"
        case .historicalImport:
            return "导入照护记录 · 照护日 \(transaction.careDayID)"
        case .migration:
            return "旧版本余额已保留"
        }
    }
}

struct CompanionLiveView: View {
    @EnvironmentObject private var feedingStore: FeedingStore
    @EnvironmentObject private var activityStore: ActivityStore
    @EnvironmentObject private var companionStore: CompanionStore
    @EnvironmentObject private var recruitmentStore: CompanionRecruitmentStore
    @EnvironmentObject private var temperamentStore: TemperamentProfileStore
    @Environment(BabyProfileStore.self) private var profileStore
    let openFeedSheet: () -> Void
    let openCompanionPicker: () -> Void

    init(openFeedSheet: @escaping () -> Void, openCompanionPicker: @escaping () -> Void) {
        self.openFeedSheet = openFeedSheet
        self.openCompanionPicker = openCompanionPicker
    }

    var body: some View {
        CompanionScenePage(
            visitorCompanions: visitorCompanions,
            currentVisitorReport: latestVisitorReport,
            recentVisitorReports: recentVisitorReports,
            openCompanionPicker: openCompanionPicker
        )
    }

    private var companionPresences: [CompanionAnimalPresence] {
        BabyCompanion.companionPageAnimals(
            selectedID: companionStore.selectedID,
            temperamentAnimalID: temperamentStore.result?.animalID,
            recruitedIDs: recruitmentStore.recruitedIDs
        )
    }

    private var visitorCompanions: [BabyCompanion] {
        if let latestReport = latestVisitorReport,
           recruitmentStore.feedableBBBucks(for: latestReport) > 0 {
            let reportVisitors = latestReport.visitorIDs
                .filter { isEligibleCurrentVisitor($0) }
                .prefix(CompanionRecruitmentStore.dailyBuddyFeedLimit)
                .map { BabyCompanion.companion(for: $0) }
            if !reportVisitors.isEmpty {
                return reportVisitors
            }
        }
        return recruitmentStore.lockedVisitorCompanions(
            for: todaysVisitorKey,
            ownedCompanionIDs: ownedCompanionIDs,
            excludedCompanionIDs: [companionStore.selectedID]
        )
    }

    private var liveHostCompanion: BabyCompanion {
        visitorCompanions.first ?? companionStore.selected
    }

    private var liveSubtitle: String {
        let residentCount = companionPresences.filter(\.isResident).count
        let visitorCount = companionPresences.count - residentCount
        return "\(residentCount)只常驻，\(visitorCount)只来访"
    }

    private var todaysVisitorKey: String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private var latestVisitorReport: YesterdayReport? {
        DailyVisitorReportFactory.availableReport(
            feedingStore: feedingStore,
            activityStore: activityStore,
            recruitmentStore: recruitmentStore,
            ownedCompanionIDs: ownedCompanionIDs,
            excludedVisitorIDs: [companionStore.selectedID]
        )
    }

    private var ownedCompanionIDs: Set<String> {
        BabyCompanion.unlockedIDs(
            selectedID: companionStore.selectedID,
            temperamentAnimalID: temperamentStore.result?.animalID
        ).union(recruitmentStore.recruitedIDs)
    }

    private var hasCollectedEveryBuddy: Bool {
        ownedCompanionIDs.count >= BabyCompanion.all.count
    }

    private func isEligibleCurrentVisitor(_ companionID: String) -> Bool {
        companionID != companionStore.selectedID
            && (hasCollectedEveryBuddy || !ownedCompanionIDs.contains(companionID))
    }

    private var recentVisitorReports: [YesterdayReport] {
        var reportsByKey = Dictionary(uniqueKeysWithValues: recruitmentStore.reports.map { ($0.reportKey, $0) })
        if let latestVisitorReport {
            reportsByKey[latestVisitorReport.reportKey] = latestVisitorReport
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let cutoff = calendar.date(byAdding: .day, value: -6, to: today) ?? .distantPast

        return reportsByKey.values
            .filter { $0.date >= cutoff }
            .sorted { $0.date > $1.date }
            .prefix(7)
            .map { $0 }
    }

    private var liveMessages: [LiveChatMessage] {
        let profile = profileStore.currentProfile
        let recentSessions = Array(feedingStore.todaySessions.prefix(4))
        let careMessages = recentSessions.map { session in
            LiveChatMessage(
                speaker: profile.name,
                text: careText(for: session),
                tint: DesignToken.reward,
                level: 16,
                badge: "宝",
                isCareLog: true
            )
        }

        return [
            LiveChatMessage(speaker: liveHostCompanion.localizedName, text: "加入了直播间", tint: DesignToken.onPrimary, level: 34, isJoin: true),
            LiveChatMessage(speaker: liveHostCompanion.localizedName, text: "我今天是随机来访的伙伴，可以用 BB Bucks 慢慢加深友情。", tint: DesignToken.reward, level: 18, badge: "访"),
            LiveChatMessage(speaker: "尤卡", text: "小木屋灯亮啦，今天的陪伴直播开始。", tint: DesignToken.accentBlue, level: 23),
            LiveChatMessage(speaker: "芬灵", text: "我在地图右边巡逻，看到好多发光小花。", tint: DesignToken.accentBlue, level: 10, badge: "管"),
            LiveChatMessage(speaker: "柯噜", text: "如果宝宝刚吃饱，我们就把掌声开小一点。", tint: DesignToken.onPrimary, level: 3)
        ] + careMessages + [
            LiveChatMessage(speaker: "摩耶", text: "今天也在稳定记录，照护节奏越来越清楚。", tint: DesignToken.accentBlue, level: 36),
            LiveChatMessage(speaker: "奇比", text: "我给宝宝攒了一颗温柔星星。", tint: DesignToken.onPrimary, level: 8)
        ]
    }

    private func careText(for session: FeedingSession) -> String {
        let time = AppDateTimeFormat.time(session.createdAt)
        if session.totalBottleAmount > 0 {
            return AppLocalization.format(
                "companion.report.bottle",
                time,
                AppMeasurementFormat.volume(Double(session.totalBottleAmount))
            )
        }
        if session.totalBreastDuration > 0 {
            return "\(time) 亲喂 \(session.totalBreastDuration) 分钟，节奏很稳。"
        }
        if session.totalSolidAmount > 0 {
            return AppLocalization.format(
                "companion.report.solids",
                time,
                AppMeasurementFormat.mass(session.totalSolidAmount)
            )
        }
        return "\(time) 完成了一次喂养记录。"
    }
}

struct CompanionSquareView: View {
    @EnvironmentObject private var feedingStore: FeedingStore
    @EnvironmentObject private var activityStore: ActivityStore
    @EnvironmentObject private var companionStore: CompanionStore
    @EnvironmentObject private var recruitmentStore: CompanionRecruitmentStore
    @EnvironmentObject private var temperamentStore: TemperamentProfileStore
    @State private var selectedCompanion: BabyCompanion?
    @State private var activeVisitorReport: YesterdayReport?

    private let columns = Array(repeating: GridItem(.flexible(minimum: 0), spacing: 12), count: 3)

    var body: some View {
        CompanionScenePage(
            visitorCompanions: recentVisitorReports.compactMap(visitorCompanion(for:)),
            currentVisitorReport: latestVisitorReport,
            recentVisitorReports: recentVisitorReports,
            openCompanionPicker: {}
        )
    }

    private var topBuddyCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                currentBuddyTopCard

                ForEach(recentVisitorReports) { report in
                    if let companion = visitorCompanion(for: report) {
                        visitorBuddyTopCard(companion: companion, report: report)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 2)
        }
        .scrollClipDisabled()
    }

    private var currentBuddyTopCard: some View {
        let companion = companionStore.selected
        let style = companion.temperamentStyle

        return VStack(alignment: .leading, spacing: 8) {
            topCardFigure(companion: companion, isUnlocked: true, size: 104)

            VStack(alignment: .leading, spacing: 4) {
                Text(companion.localizedName)
                    .font(BBBFont.font(size: 16, weight: .heavy))
                    .foregroundStyle(DesignToken.textPrimary)
                    .lineLimit(1)

                Text(companion.localizedTemperamentLabel)
                    .font(BBBFont.font(size: 10, weight: .heavy))
                    .foregroundStyle(style.text)
                    .lineLimit(1)
            }

            topCardChip("当前 Buddy", tint: DesignToken.primary, text: .white, isFilled: true)
        }
        .padding(12)
        .frame(width: 144, height: 210, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    DesignToken.glassFill.opacity(0.88),
                                    DesignToken.primary.opacity(0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(DesignToken.primary.opacity(0.28), lineWidth: 1.1)
                )
                .shadow(color: DesignToken.primary.opacity(0.12), radius: 16, y: 8)
        )
        .accessibilityLabel("当前 Buddy，\(companion.localizedName)，\(companion.localizedTemperamentLabel)")
    }

    private func visitorBuddyTopCard(companion: BabyCompanion, report: YesterdayReport) -> some View {
        let style = companion.temperamentStyle

        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                activeVisitorReport = report
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                topCardFigure(companion: companion, isUnlocked: true, size: 100)

                VStack(alignment: .leading, spacing: 4) {
                    Text(companion.localizedName)
                        .font(BBBFont.font(size: 16, weight: .heavy))
                        .foregroundStyle(DesignToken.textPrimary)
                        .lineLimit(1)

                    Text(companion.localizedTemperamentLabel)
                        .font(BBBFont.font(size: 10, weight: .heavy))
                        .foregroundStyle(style.text)
                        .lineLimit(1)
                }

                topCardChip("\(report.dateText) 来访", tint: style.tint, text: style.text, isFilled: false)
            }
            .padding(12)
            .frame(width: 144, height: 210, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(DesignToken.surfaceRaised.opacity(0.82))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(DesignToken.glassStroke.opacity(0.86), lineWidth: 1)
                    )
                    .shadow(color: DesignToken.shadowColor.opacity(0.14), radius: 14, y: 7)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("\(report.dateText) 来访，\(companion.localizedName)，\(companion.localizedTemperamentLabel)")
    }

    private func topCardFigure(companion: BabyCompanion, isUnlocked: Bool, size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(companion.temperamentStyle.tint.opacity(0.14))
                .frame(width: 102, height: 102)

            CompanionAnimalFigure(
                companion: companion,
                isUnlocked: isUnlocked,
                size: size
            )
            .frame(width: 112, height: 104, alignment: .center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 106)
    }

    private func topCardChip(_ title: String, tint: Color, text: Color, isFilled: Bool) -> some View {
        Text(title.localized)
            .font(BBBFont.font(size: 9, weight: .heavy))
            .foregroundStyle(isFilled ? DesignToken.onPrimary : text)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .padding(.horizontal, 9)
            .frame(height: 24)
            .background(
                Capsule(style: .continuous)
                    .fill(isFilled ? tint.opacity(0.82) : tint.opacity(0.13))
            )
    }

    private var buddyGrid: some View {
        LazyVGrid(columns: columns, alignment: .center, spacing: 18) {
            ForEach(BabyCompanion.all) { companion in
                buddyGridButton(companion)
            }
        }
        .padding(.horizontal, 18)
    }

    private var squareBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    DesignToken.canvas,
                    DesignToken.surfaceSoft,
                    DesignToken.surface
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    DesignToken.glassFill.opacity(0.74),
                    DesignToken.glassFill.opacity(0)
                ],
                center: .top,
                startRadius: 18,
                endRadius: 420
            )
            .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.clear,
                    DesignToken.primarySoft.opacity(0.34)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    private var buddySectionTitle: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("BBBuddy们")
                .font(BBBFont.font(size: 28, weight: .heavy))
                .foregroundStyle(DesignToken.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.top, 4)
    }

    private func buddyGridButton(_ companion: BabyCompanion) -> some View {
        let isUnlocked = isCompanionUnlocked(companion)
        let isCurrent = companionStore.selectedID == companion.id

        return Button {
            selectedCompanion = companion
        } label: {
            VStack(spacing: 6) {
                ZStack(alignment: .top) {
                    CompanionAnimalFigure(
                        companion: companion,
                        isUnlocked: isUnlocked,
                        size: isUnlocked ? 68 : 72
                    )
                    .frame(width: 80, height: 78, alignment: .center)

                    if isCurrent {
                        Text("当前")
                            .font(BBBFont.font(size: 8, weight: .heavy))
                            .foregroundStyle(DesignToken.onPrimary)
                            .padding(.horizontal, 6)
                            .frame(height: 17)
                            .background(Capsule().fill(DesignToken.primaryGradient))
                            .offset(x: 1, y: 0)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 80)

                VStack(spacing: 2) {
                    Text(isUnlocked ? companion.localizedName : "未解锁")
                        .font(BBBFont.font(size: 12, weight: .heavy))
                        .foregroundStyle(isUnlocked ? DesignToken.textPrimary : DesignToken.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    CompanionFriendshipHearts(
                        companion: companion,
                        friendshipValue: recruitmentStore.friendshipValue(for: companion.id),
                        isUnlocked: isUnlocked,
                        size: 8,
                        filledColor: DesignToken.easyActivity,
                        emptyColor: DesignToken.borderSubtle.opacity(0.62)
                    )
                }
            }
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(isUnlocked ? "\(companion.localizedName), \(companion.localizedSpecies)" : "未获取伙伴")
    }

    private var latestVisitorReport: YesterdayReport? {
        DailyVisitorReportFactory.availableReport(
            feedingStore: feedingStore,
            activityStore: activityStore,
            recruitmentStore: recruitmentStore,
            ownedCompanionIDs: ownedCompanionIDs,
            excludedVisitorIDs: [companionStore.selectedID]
        )
    }

    private var ownedCompanionIDs: Set<String> {
        BabyCompanion.unlockedIDs(
            selectedID: companionStore.selectedID,
            temperamentAnimalID: temperamentStore.result?.animalID
        ).union(recruitmentStore.recruitedIDs)
    }

    private var recentVisitorReports: [YesterdayReport] {
        var reportsByKey = Dictionary(uniqueKeysWithValues: recruitmentStore.reports.map { ($0.reportKey, $0) })
        if let latestVisitorReport {
            reportsByKey[latestVisitorReport.reportKey] = latestVisitorReport
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let cutoff = calendar.date(byAdding: .day, value: -6, to: today) ?? .distantPast

        return reportsByKey.values
            .filter { $0.date >= cutoff }
            .sorted { $0.date > $1.date }
            .prefix(7)
            .map { $0 }
    }

    private func visitorCompanion(for report: YesterdayReport) -> BabyCompanion? {
        report.visitorIDs.first.map { BabyCompanion.companion(for: $0) }
    }

    private func isCompanionUnlocked(_ companion: BabyCompanion) -> Bool {
        recruitmentStore.isUnlocked(
            companion,
            selectedID: companionStore.selectedID,
            temperamentAnimalID: temperamentStore.result?.animalID
        )
    }

}

private struct CompanionScenePage: View {
    @EnvironmentObject private var companionStore: CompanionStore
    @EnvironmentObject private var recruitmentStore: CompanionRecruitmentStore
    @EnvironmentObject private var temperamentStore: TemperamentProfileStore
    @EnvironmentObject private var membershipStore: PlusMembershipStore
    @StateObject private var sceneEntitlementStore = SceneEntitlementStore.shared
    @State private var selectedShelfTab: CompanionSceneShelfTab = .all
    @State private var panelMode: CompanionScenePanelMode = .half
    @State private var selectedShelfCompanion: BabyCompanion?
    @State private var activeVisitorReport: YesterdayReport?
    @State private var isScenePickerPresented = false
    @State private var isBBBucksHistoryPresented = false
    @AppStorage("companion_scene_selection_id") private var selectedSceneID = CompanionSceneOption.scene01.rawValue

    let visitorCompanions: [BabyCompanion]
    let currentVisitorReport: YesterdayReport?
    let recentVisitorReports: [YesterdayReport]
    let openCompanionPicker: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                sceneLayer(size: proxy.size)
                    .scaleEffect(sceneLayerScale)
                    .blur(radius: sceneLayerBlur)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    sceneControls
                        .padding(.horizontal, 22)
                        .padding(.bottom, sceneControlsBottomPadding(for: proxy.size))
                }

                if panelMode != .scene {
                    CompanionSceneShelfPanel(
                        selectedTab: $selectedShelfTab,
                        mode: $panelMode,
                        halfItems: halfItems,
                        companions: companions(for: selectedShelfTab),
                        selectedCompanionID: companionStore.selectedID,
                        unlockedIDs: unlockedCompanionIDs,
                        friendshipValue: { recruitmentStore.friendshipValue(for: $0.id) },
                        onOpenDetail: openCompanionDetail(_:),
                        onOpenVisitorReport: openVisitorReport(_:)
                    )
                    .frame(height: shelfHeight(for: proxy.size))
                    .padding(.horizontal, CompanionSceneCardMetrics.panelHorizontalInset)
                    .transition(.move(edge: .bottom))
                }
            }
            .overlay {
                if let selectedShelfCompanion {
                    CompanionDetailOverlay(
                        companion: selectedShelfCompanion,
                        selectedCompanion: $selectedShelfCompanion,
                        onSetCurrent: {
                            withAnimation(.interactiveSpring(response: 0.30, dampingFraction: 0.86)) {
                                panelMode = .scene
                            }
                        }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .zIndex(20)
                }

                if let activeVisitorReport {
                    YesterdayReportOverlay(report: activeVisitorReport) {
                        withAnimation(.easeOut(duration: 0.18)) {
                            self.activeVisitorReport = nil
                        }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .zIndex(21)
                }
            }
            .animation(.interactiveSpring(response: 0.34, dampingFraction: 0.86), value: panelMode)
            .animation(.interactiveSpring(response: 0.28, dampingFraction: 0.88), value: selectedShelfTab)
            .animation(.easeOut(duration: 0.18), value: selectedShelfCompanion?.id)
            .animation(.easeOut(duration: 0.18), value: activeVisitorReport?.reportKey)
        }
        .background {
            CompanionSceneBackground(scene: selectedScene)
                .ignoresSafeArea()
        }
        .ignoresSafeArea()
        .sheet(isPresented: $isScenePickerPresented) {
            CompanionScenePickerSheet(selectedScene: selectedSceneBinding)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isBBBucksHistoryPresented) {
            BBBucksHistoryView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private func sceneLayer(size: CGSize) -> some View {
        ZStack {
            CompanionSceneBackground(scene: selectedScene)
                .frame(width: size.width, height: size.height)
                .clipped()

            if let sceneVisitorCompanion {
                visitorPeekFigure(companion: sceneVisitorCompanion, size: size)
            }
            currentCompanionFigure(size: size)
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }

    private var sceneControls: some View {
        HStack(alignment: .center) {
            bbBucksPill
            Spacer()
            HStack(spacing: 12) {
                sceneActionButton(symbol: "photo.on.rectangle.angled", label: "更换场景") {
                    isScenePickerPresented = true
                }
                sceneActionButton(symbol: panelToggleSymbol, label: panelToggleLabel) {
                    togglePanelMode()
                }
            }
            .opacity(sceneActionButtonsOpacity)
            .scaleEffect(panelMode == .scene ? 1 : 0.92)
            .allowsHitTesting(panelMode == .scene)
        }
        .opacity(sceneControlsOpacity)
        .allowsHitTesting(panelMode != .full)
    }

    private var bbBucksPill: some View {
        Button {
            isBBBucksHistoryPresented = true
        } label: {
            HStack(spacing: 9) {
                Image("bbbucks_coin")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 23, height: 23)
                Text("\(recruitmentStore.bbBucks)")
                    .font(BBBFont.font(size: 17, weight: .heavy))
                    .monospacedDigit()
            }
            .foregroundStyle(DesignToken.rewardText)
            .padding(.horizontal, 15)
            .frame(height: 42)
            .background(DesignToken.rewardSoft.opacity(0.88), in: Capsule(style: .continuous))
            .overlay(Capsule(style: .continuous).stroke(DesignToken.glassStroke.opacity(0.82), lineWidth: 1))
            .shadow(color: DesignToken.reward.opacity(0.16), radius: 18, y: 8)
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("BB Bucks \(recruitmentStore.bbBucks)")
        .accessibilityHint("查看获取记录")
    }

    private func sceneActionButton(symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(DesignToken.onPrimary)
                .frame(width: 46, height: 46)
                .background(Circle().fill(DesignToken.primaryGradient))
                .shadow(color: DesignToken.primary.opacity(0.24), radius: 16, y: 8)
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(label)
    }

    private var selectedScene: CompanionSceneOption {
        let selected = CompanionSceneOption.fromPersistedID(selectedSceneID)
        if selected.isAvailable {
            return selected
        }
        if let firstAvailable = CompanionSceneOption.availableCases.first {
            return firstAvailable
        }
        // Keep the page renderable while the catalog is empty; this is not offered as a selectable scene.
        return selected
    }

    private var selectedSceneBinding: Binding<CompanionSceneOption> {
        Binding(
            get: { selectedScene },
            set: { selectedSceneID = $0.rawValue }
        )
    }

    private func shelfHeight(for size: CGSize) -> CGFloat {
        if panelMode == .full {
            return max(size.height - fullPanelTopReveal(for: size), size.height * 0.84)
        }
        if panelMode == .scene {
            return 0
        }
        return CompanionSceneCardMetrics.halfPanelHeight(for: size.width)
    }

    private func sceneControlsBottomPadding(for size: CGSize) -> CGFloat {
        if panelMode == .scene {
            return min(max(size.height * 0.11, 104), 132)
        }
        if panelMode == .half {
            return shelfHeight(for: size) + 14
        }
        return 0
    }

    private func fullPanelTopReveal(for size: CGSize) -> CGFloat {
        min(max(size.height * 0.10, 86), 118)
    }

    private var sceneLayerScale: CGFloat {
        1
    }

    private var sceneLayerBlur: CGFloat {
        switch panelMode {
        case .scene, .half:
            return 0
        case .full:
            return 0.8
        }
    }

    private var sceneActionButtonsOpacity: Double {
        panelMode == .scene ? 1 : 0
    }

    private var sceneControlsOpacity: Double {
        panelMode == .full ? 0 : 1
    }

    private var panelToggleSymbol: String {
        panelMode == .scene ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left"
    }

    private var panelToggleLabel: String {
        panelMode == .scene ? "打开伙伴列表" : "收起伙伴列表"
    }

    private func togglePanelMode() {
        withAnimation(.interactiveSpring(response: 0.30, dampingFraction: 0.86)) {
            switch panelMode {
            case .scene:
                panelMode = .half
            case .half, .full:
                panelMode = .scene
            }
        }
    }

    private func hostSize(for size: CGSize) -> CGFloat {
        min(max(size.width * 0.34, 134), 178)
    }

    private func visitorSize(for size: CGSize) -> CGFloat {
        min(max(size.width * 0.36, 138), 184)
    }

    private func visitorPeekFigure(companion: BabyCompanion, size: CGSize) -> some View {
        let figureSize = visitorSize(for: size)

        return Button {
            guard let report = currentVisitorReport else { return }
            openVisitorReport(report)
        } label: {
            CompanionSceneBreathingFigure(
                companion: companion,
                isUnlocked: true,
                size: figureSize
            )
            .rotationEffect(.degrees(13))
            .shadow(color: DesignToken.shadowColor.opacity(0.18), radius: 18, y: 10)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(currentVisitorReport == nil)
        .position(
            x: figureSize * 0.10,
            y: max(260, size.height * 0.43)
        )
        .accessibilityLabel("来访伙伴 \(companion.localizedName)")
        .accessibilityHint(currentVisitorReport == nil ? "今日暂无来访卡" : "打开今日来访卡")
    }

    private func currentCompanionFigure(size: CGSize) -> some View {
        Button {
            withAnimation(.interactiveSpring(response: 0.30, dampingFraction: 0.86)) {
                selectedShelfTab = .all
                panelMode = .full
            }
        } label: {
            CompanionSceneBreathingFigure(
                companion: companionStore.selected,
                isUnlocked: true,
                size: hostSize(for: size)
            )
            .shadow(color: DesignToken.shadowColor.opacity(0.20), radius: 24, y: 12)
        }
        .buttonStyle(ScaleButtonStyle())
        .position(
            x: size.width * 0.50,
            y: max(270, size.height * 0.49)
        )
        .accessibilityLabel("当前伙伴 \(companionStore.selected.localizedName)")
        .accessibilityHint("打开全部伙伴")
    }

    private var visitorCompanion: BabyCompanion {
        if let visitorID = currentVisitorReport?.visitorIDs.first {
            return BabyCompanion.companion(for: visitorID)
        }
        return recentVisitors.first
            ?? visitorCompanions.first
            ?? recruitmentStore.visitorCompanion(
                for: todayKey,
                ownedCompanionIDs: unlockedCompanionIDs,
                excludedCompanionIDs: [companionStore.selectedID]
            )
    }

    private var sceneVisitorCompanion: BabyCompanion? {
        if let currentVisitorReport {
            if let reportedVisitor = currentVisitorReport.visitorIDs
                .first(where: isEligibleSceneVisitor(_:))
                .map({ BabyCompanion.companion(for: $0) }) {
                return reportedVisitor
            }

            // A report can become ineligible after its visitor is recruited.
            // Keep the scene populated with the next valid daily candidate.
            return visitorCompanions.first(where: { isEligibleSceneVisitor($0.id) })
                ?? generatedSceneVisitor
        }

        return recentVisitors.first(where: { isEligibleSceneVisitor($0.id) })
            ?? visitorCompanions.first(where: { isEligibleSceneVisitor($0.id) })
            ?? generatedSceneVisitor
    }

    private var generatedSceneVisitor: BabyCompanion? {
        let candidate = recruitmentStore.visitorCompanion(
            for: todayKey,
            ownedCompanionIDs: unlockedCompanionIDs,
            excludedCompanionIDs: [companionStore.selectedID]
        )
        return isEligibleSceneVisitor(candidate.id) ? candidate : nil
    }

    private var recentVisitors: [BabyCompanion] {
        let reportVisitors = recentVisitorReports.flatMap(\.visitorIDs)
        let explicitVisitors = visitorCompanions.map(\.id)
        return (reportVisitors + explicitVisitors)
            .companionSceneUniqued()
            .prefix(12)
            .map { BabyCompanion.companion(for: $0) }
    }

    private var unlockedCompanionIDs: Set<String> {
        Set(BabyCompanion.all.filter(isUnlocked(_:)).map(\.id))
    }

    private var hasCollectedEveryBuddy: Bool {
        unlockedCompanionIDs.count >= BabyCompanion.all.count
    }

    private func isEligibleSceneVisitor(_ companionID: String) -> Bool {
        companionID != companionStore.selectedID
            && (hasCollectedEveryBuddy || !unlockedCompanionIDs.contains(companionID))
    }

    private func companions(for tab: CompanionSceneShelfTab) -> [BabyCompanion] {
        let companions: [BabyCompanion]
        switch tab {
        case .all:
            companions = BabyCompanion.all
        case .recent:
            companions = recentVisitors.isEmpty ? [visitorCompanion] : recentVisitors
        case .unlocked:
            companions = BabyCompanion.all.filter(isUnlocked(_:))
        case .locked:
            companions = BabyCompanion.all.filter { !isUnlocked($0) }
        }
        return companions.companionSceneUniquedByID()
    }

    private var halfItems: [CompanionSceneHalfItem] {
        var items = [
            CompanionSceneHalfItem(
                companion: companionStore.selected,
                role: .current,
                report: nil
            )
        ]

        var orderedReports = recentVisitorReports
        if let currentVisitorReport,
           !orderedReports.contains(where: { $0.reportKey == currentVisitorReport.reportKey }) {
            orderedReports.insert(currentVisitorReport, at: 0)
        }

        for report in orderedReports.sorted(by: { $0.date > $1.date }) {
            for visitorID in report.visitorIDs {
                let role: CompanionSceneHalfItem.Role = report.reportKey == currentVisitorReport?.reportKey
                    ? .todayVisitor
                    : .recentVisitor
                items.append(
                    CompanionSceneHalfItem(
                        companion: BabyCompanion.companion(for: visitorID),
                        role: role,
                        report: report
                    )
                )
            }
        }

        if items.count == 1, visitorCompanion.id != companionStore.selected.id {
            items.append(
                CompanionSceneHalfItem(
                    companion: visitorCompanion,
                    role: .visitor,
                    report: nil
                )
            )
        }

        items.append(
            CompanionSceneHalfItem(
                companion: companionStore.selected,
                role: .more,
                report: nil
            )
        )

        return items
    }

    private func openCompanionDetail(_ companion: BabyCompanion) {
        activeVisitorReport = nil
        selectedShelfCompanion = companion
    }

    private func openVisitorReport(_ report: YesterdayReport) {
        selectedShelfCompanion = nil
        activeVisitorReport = recruitmentStore.report(for: report.reportKey) ?? report
    }

    private func isUnlocked(_ companion: BabyCompanion) -> Bool {
        recruitmentStore.isUnlocked(
            companion,
            selectedID: companionStore.selectedID,
            temperamentAnimalID: temperamentStore.result?.animalID
        )
    }

    private var todayKey: String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

private enum CompanionSceneOption: String, CaseIterable, Identifiable {
    case scene01 = "scene_01"
    case scene02 = "scene_02"
    case scene03 = "scene_03"
    case scene04 = "scene_04"
    case scene05 = "scene_05"
    case scene06 = "scene_06"
    case scene07 = "scene_07"
    case scene08 = "scene_08"
    case scene09 = "scene_09"
    case scene10 = "scene_10"
    case scene11 = "scene_11"
    case scene12 = "scene_12"
    case scene13 = "scene_13"
    case scene14 = "scene_14"
    case scene15 = "scene_15"
    case scene16 = "scene_16"
    case scene17 = "scene_17"
    case scene18 = "scene_18"
    case scene19 = "scene_19"
    case scene20 = "scene_20"
    case scene21 = "scene_21"
    case scene22 = "scene_22"
    case scene23 = "scene_23"
    case scene24 = "scene_24"
    case scene25 = "scene_25"
    case scene26 = "scene_26"
    case scene27 = "scene_27"

    private struct Metadata {
        let assetSlug: String
        let title: String
        let subtitle: String
    }

    private static let metadata: [Metadata] = [
        .init(assetSlug: "01_tea_room_blossom_rug", title: "花间茶室", subtitle: "暖阳里的柔软角落"),
        .init(assetSlug: "02_mint_art_studio", title: "薄荷创作室", subtitle: "轻快明亮的陪伴空间"),
        .init(assetSlug: "03_bamboo_tatami_rug", title: "竹影榻间", subtitle: "安静自然的日常一隅"),
        .init(assetSlug: "04_snowy_glass_room", title: "雪光玻璃屋", subtitle: "清透柔和的冬日房间"),
        .init(assetSlug: "05_sunlit_art_corner", title: "晨光画角", subtitle: "适合一起创作的小空间"),
        .init(assetSlug: "06_peach_sunset_nook", title: "桃色暮光室", subtitle: "温柔的晚霞陪伴"),
        .init(assetSlug: "07_blue_cloud_lounge", title: "蓝云休息室", subtitle: "轻松柔软的云朵角落"),
        .init(assetSlug: "08_lavender_dream_room", title: "薰衣草梦屋", subtitle: "适合晚间安抚的房间"),
        .init(assetSlug: "09_green_reading_room", title: "青苔阅读角", subtitle: "安静读书与陪伴"),
        .init(assetSlug: "10_olive_window_lounge", title: "橄榄窗边", subtitle: "绿意里的慢慢相处"),
        .init(assetSlug: "11_honey_window_lounge", title: "蜂蜜窗边", subtitle: "暖色阳光的小客厅"),
        .init(assetSlug: "12_morning_playroom", title: "晨光游戏房", subtitle: "明亮轻快的游戏时间"),
        .init(assetSlug: "13_lilac_cloud_room", title: "丁香云室", subtitle: "柔和梦幻的陪伴空间"),
        .init(assetSlug: "15_olive_flower_room", title: "橄榄花房", subtitle: "植物与阳光相伴"),
        .init(assetSlug: "16_garden_porch_rug", title: "花园门廊", subtitle: "靠近自然的午后角落"),
        .init(assetSlug: "18_peach_blossom_room", title: "桃花小屋", subtitle: "温暖轻柔的成长空间"),
        .init(assetSlug: "19_blue_window_studio", title: "蓝窗工作室", subtitle: "清爽安静的陪伴时光"),
        .init(assetSlug: "20_stargazer_room", title: "星光观景室", subtitle: "一起看星星的夜晚"),
        .init(assetSlug: "21_lavender_night_room", title: "薰衣草夜屋", subtitle: "安静入睡前的陪伴"),
        .init(assetSlug: "desert_arch_lounge", title: "沙丘拱门", subtitle: "温暖开阔的休息角"),
        .init(assetSlug: "lake_breeze_balcony", title: "湖风阳台", subtitle: "有风经过的明亮空间"),
        .init(assetSlug: "lake_garden_loggia", title: "湖畔花廊", subtitle: "植物与湖光相遇"),
        .init(assetSlug: "lemon_patio", title: "柠檬庭院", subtitle: "清新明亮的户外角落"),
        .init(assetSlug: "mint_round_studio", title: "薄荷圆厅", subtitle: "柔和圆形聚焦空间"),
        .init(assetSlug: "moon_gate_courtyard", title: "月门庭院", subtitle: "安静通透的夜色庭院"),
        .init(assetSlug: "moonlit_pavilion", title: "月光亭", subtitle: "适合慢慢相处的夜晚"),
        .init(assetSlug: "seaside_breeze_balcony", title: "海风露台", subtitle: "有海风的轻盈午后")
    ]

    var id: String { rawValue }

    private var metadataValue: Metadata {
        Self.metadata[Self.allCases.firstIndex(of: self) ?? 0]
    }

    var title: String { metadataValue.title }
    var subtitle: String { metadataValue.subtitle }
    var assetName: String { "companion_buddy_scene_\(metadataValue.assetSlug)" }
    var isAvailable: Bool { UIImage(named: assetName) != nil }
    static var availableCases: [CompanionSceneOption] { allCases.filter(\.isAvailable) }

    static func fromPersistedID(_ rawValue: String) -> CompanionSceneOption {
        if let scene = CompanionSceneOption(rawValue: rawValue) {
            return scene
        }
        switch rawValue {
        case "sunnyNursery", "sunnyNurseryDaylight": return .scene02
        case "moonlitRoom", "moonlitRoomStarlight": return .scene03
        case "fullMonthGift": return .scene04
        case "fiveAchievementGift": return .scene05
        case "hundredDayGift": return .scene06
        case "tenAchievementGift": return .scene07
        case "fifteenAchievementGift": return .scene08
        case "firstBirthdayGift": return .scene09
        default: return .scene01
        }
    }

    var palette: [Color] { [DesignToken.canvas, DesignToken.surfaceSoft, DesignToken.surface] }
    var isPlusVariant: Bool { false }
    var baseScene: CompanionSceneOption { self }
    var entitlementID: String? { nil }
    var unlockConditionText: String? { nil }
}

private struct CompanionScenePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var membershipStore: PlusMembershipStore
    @StateObject private var sceneEntitlementStore = SceneEntitlementStore.shared
    @Binding var selectedScene: CompanionSceneOption

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("更换场景")
                    .font(BBBFont.font(size: 24, weight: .heavy))
                    .foregroundStyle(DesignToken.textPrimary)
                Text("选择陪伴页的房间背景")
                    .font(BBBFont.font(size: 13, weight: .semibold))
                    .foregroundStyle(DesignToken.textSecondary)
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    if CompanionSceneOption.availableCases.isEmpty {
                        Text("暂无可用场景")
                            .font(BBBFont.font(size: 15, weight: .semibold))
                            .foregroundStyle(DesignToken.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                    } else {
                        ForEach(CompanionSceneOption.availableCases) { scene in
                            let isOwned = scene.entitlementID.map(sceneEntitlementStore.isOwned) ?? true
                            let isLocked = (scene.isPlusVariant && !membershipStore.isPlusActive) || !isOwned
                            CompanionScenePickerRow(
                                scene: scene,
                                isSelected: selectedScene == scene,
                                isLocked: isLocked,
                                statusText: sceneStatusText(scene, isOwned: isOwned)
                            ) {
                                guard !isLocked else { return }
                                selectedScene = scene
                                dismiss()
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)
            }

            Spacer(minLength: 0)
        }
        .background(
            LinearGradient(
                colors: [DesignToken.canvas, DesignToken.surfaceSoft, DesignToken.surface],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    private func sceneStatusText(_ scene: CompanionSceneOption, isOwned: Bool) -> String {
        if scene.isPlusVariant {
            return membershipStore.isPlusActive ? "Plus 已可用" : "订阅 Plus 后可用"
        }
        return isOwned ? "已拥有" : (scene.unlockConditionText ?? "尚未解锁")
    }
}

private struct CompanionScenePickerRow: View {
    let scene: CompanionSceneOption
    let isSelected: Bool
    let isLocked: Bool
    let statusText: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                CompanionScenePreview(scene: scene)
                    .frame(width: 92, height: 68)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(DesignToken.glassStroke.opacity(0.82), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(scene.title.localized)
                            .font(BBBFont.font(size: 17, weight: .heavy))
                            .foregroundStyle(DesignToken.textPrimary)
                        if scene.isPlusVariant {
                            Text("Plus")
                                .font(BBBFont.font(size: 8.5, weight: .heavy))
                                .foregroundStyle(DesignToken.onPrimary)
                                .padding(.horizontal, 6)
                                .frame(height: 18)
                                .background(Capsule().fill(DesignToken.primary))
                        }
                    }
                    Text(scene.subtitle.localized)
                        .font(BBBFont.font(size: 12, weight: .semibold))
                        .foregroundStyle(DesignToken.textSecondary)
                    Text(statusText)
                        .font(BBBFont.font(size: 10.5, weight: .heavy))
                        .foregroundStyle(isLocked ? DesignToken.textSecondary.opacity(0.82) : DesignToken.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                Spacer(minLength: 0)

                Image(systemName: isLocked ? "lock.fill" : (isSelected ? "checkmark.circle.fill" : "circle"))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(isSelected ? DesignToken.primary : DesignToken.textFaint)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(DesignToken.surfaceRaised.opacity(isSelected ? 0.92 : 0.72))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(isSelected ? DesignToken.primary.opacity(0.34) : DesignToken.glassStroke.opacity(0.80), lineWidth: 1)
            )
            .shadow(color: DesignToken.shadowColor.opacity(isSelected ? 0.20 : 0.12), radius: 16, y: 8)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(isLocked)
        .opacity(isLocked ? 0.68 : 1)
        .accessibilityLabel(scene.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct CompanionScenePreview: View {
    let scene: CompanionSceneOption

    var body: some View {
        ZStack {
            CompanionSceneImage(scene: scene)

            LinearGradient(
                colors: [DesignToken.glassFill.opacity(0.28), DesignToken.glassFill.opacity(0.02), DesignToken.rewardSoft.opacity(0.24)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

private struct CompanionSceneBackground: View {
    let scene: CompanionSceneOption

    var body: some View {
        CompanionSceneImage(scene: scene)
    }
}

private struct CompanionSceneImage: View {
    let scene: CompanionSceneOption

    var body: some View {
        ZStack {
            if let assetName = resolvedAssetName {
                Image(assetName)
                    .resizable()
                    .scaledToFill()
            } else {
                DesignToken.canvas
            }

            if scene.isPlusVariant {
                LinearGradient(
                    colors: scene.palette.map { $0.opacity(0.24) },
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .blendMode(.softLight)
            }
        }
    }

    private var resolvedAssetName: String? {
        if UIImage(named: scene.assetName) != nil {
            return scene.assetName
        }
        return nil
    }
}

private struct CompanionSceneHalfItem: Identifiable {
    enum Role: String, Equatable {
        case current
        case todayVisitor
        case visitor
        case recentVisitor
        case companion
        case more

        var roleText: String {
            switch self {
            case .current: return "当前伙伴"
            case .todayVisitor: return "今日来访"
            case .visitor: return "来访伙伴"
            case .recentVisitor: return "最近来访"
            case .companion: return "伙伴"
            case .more: return "伙伴图鉴"
            }
        }
    }

    let companion: BabyCompanion
    let role: Role
    let report: YesterdayReport?

    var id: String {
        "\(role.rawValue)-\(companion.id)-\(report?.reportKey ?? "none")"
    }

    var roleText: String {
        if role == .recentVisitor, let report {
            if Calendar.current.isDateInYesterday(report.date) {
                return "昨日来访"
            }
            let components = Calendar.current.dateComponents([.month, .day], from: report.date)
            if let month = components.month, let day = components.day {
                return "\(month)月\(day)日"
            }
        }
        return role.roleText
    }

    var matchedGeometryID: String {
        role == .current ? companion.id : id
    }
}

private enum CompanionSceneCardMetrics {
    static let panelHorizontalInset: CGFloat = 12
    static let horizontalInset: CGFloat = 20
    static let spacing: CGFloat = 12
    static let bottomDockClearance: CGFloat = 94
    static let cardAspectRatio: CGFloat = 0.80
    static let handleHeight: CGFloat = 25
    static let halfCarouselTopPadding: CGFloat = 4

    static func cardWidth(for containerWidth: CGFloat) -> CGFloat {
        let availableWidth = containerWidth - horizontalInset * 2 - spacing * 2
        return max(96, floor(availableWidth / 3))
    }

    static func halfPanelHeight(for viewportWidth: CGFloat) -> CGFloat {
        let panelWidth = viewportWidth - panelHorizontalInset * 2
        let cardHeight = cardWidth(for: panelWidth) / cardAspectRatio
        let contentHeight = handleHeight
            + halfCarouselTopPadding
            + cardHeight
            + bottomDockClearance
        return min(max(contentHeight, 236), 270)
    }
}

private struct CompanionSceneShelfPanel: View {
    @Namespace private var companionCardNamespace
    @Binding var selectedTab: CompanionSceneShelfTab
    @Binding var mode: CompanionScenePanelMode
    let halfItems: [CompanionSceneHalfItem]
    let companions: [BabyCompanion]
    let selectedCompanionID: String
    let unlockedIDs: Set<String>
    let friendshipValue: (BabyCompanion) -> Int
    let onOpenDetail: (BabyCompanion) -> Void
    let onOpenVisitorReport: (YesterdayReport) -> Void

    private let columns = Array(
        repeating: GridItem(.flexible(minimum: 0), spacing: CompanionSceneCardMetrics.spacing),
        count: 3
    )
    private let dragThreshold: CGFloat = 42

    var body: some View {
        VStack(spacing: 0) {
            shelfChrome

            Group {
                if mode == .half {
                    halfCarousel
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .opacity
                        ))
                } else {
                    fullGrid
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .opacity
                        ))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .contentShape(Rectangle())
        .simultaneousGesture(panelDragGesture)
        .animation(.interactiveSpring(response: 0.34, dampingFraction: 0.86), value: mode)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 28,
                topTrailingRadius: 28
            )
                .fill(.ultraThinMaterial)
                .overlay(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 28,
                        topTrailingRadius: 28
                    )
                        .fill(DesignToken.surfaceSoft.opacity(0.82))
                )
                .overlay(alignment: .top) {
                    UnevenRoundedRectangle(
                        topLeadingRadius: 28,
                        topTrailingRadius: 28
                    )
                        .stroke(DesignToken.glassStroke.opacity(0.72), lineWidth: 1)
                }
                .shadow(color: DesignToken.shadowColor.opacity(0.20), radius: 22, y: -8)
        )
    }

    private var shelfChrome: some View {
        VStack(spacing: 0) {
            handle
            if mode == .full {
                tabBar
            }
        }
        .contentShape(Rectangle())
        .gesture(shelfDragGesture)
        .accessibilityHint(mode == .full ? "下滑收起伙伴列表" : "上滑展开伙伴列表")
    }

    private var handle: some View {
        Button {
            withAnimation(.interactiveSpring(response: 0.30, dampingFraction: 0.86)) {
                mode = mode == .full ? .half : .full
            }
        } label: {
            Capsule()
                .fill(DesignToken.primary.opacity(0.46))
                .frame(width: 46, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 10)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mode == .full ? "收起伙伴列表" : "展开伙伴列表")
    }

    private var shelfDragGesture: some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .local)
            .onEnded { value in
                let predicted = value.predictedEndTranslation
                let vertical = abs(predicted.height) > abs(predicted.width) ? predicted.height : value.translation.height
                guard abs(vertical) >= dragThreshold, abs(vertical) > abs(value.translation.width) else { return }

                withAnimation(.interactiveSpring(response: 0.30, dampingFraction: 0.86)) {
                    if vertical < 0 {
                        mode = .full
                    } else {
                        mode = mode == .full ? .half : .scene
                    }
                }
            }
    }

    private var panelDragGesture: some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .local)
            .onEnded { value in
                let predicted = value.predictedEndTranslation
                let vertical = abs(predicted.height) > abs(predicted.width) ? predicted.height : value.translation.height
                guard abs(vertical) >= dragThreshold, abs(vertical) > abs(value.translation.width) else { return }

                withAnimation(.interactiveSpring(response: 0.30, dampingFraction: 0.86)) {
                    if vertical < 0 {
                        mode = .full
                    } else if mode == .half {
                        mode = .scene
                    }
                }
            }
    }

    private var halfCarousel: some View {
        GeometryReader { proxy in
            let cardWidth = CompanionSceneCardMetrics.cardWidth(for: proxy.size.width)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: CompanionSceneCardMetrics.spacing) {
                    ForEach(displayHalfItems) { item in
                        CompanionSceneCarouselCard(
                            companion: item.companion,
                            role: item.role,
                            roleText: item.roleText,
                            isSelected: item.role == .current && item.companion.id == selectedCompanionID,
                            isUnlocked: unlockedIDs.contains(item.companion.id),
                            friendshipValue: friendshipValue(item.companion),
                            onTap: {
                                if item.role == .more {
                                    withAnimation(.interactiveSpring(response: 0.30, dampingFraction: 0.86)) {
                                        selectedTab = .all
                                        mode = .full
                                    }
                                } else if let report = item.report,
                                   item.role == .todayVisitor || item.role == .recentVisitor {
                                    onOpenVisitorReport(report)
                                } else {
                                    onOpenDetail(item.companion)
                                }
                            }
                        )
                        .frame(width: cardWidth)
                        .matchedGeometryEffect(
                            id: item.matchedGeometryID,
                            in: companionCardNamespace
                        )
                    }
            }
            .scrollTargetLayout()
            .padding(.horizontal, CompanionSceneCardMetrics.horizontalInset)
            .padding(.top, CompanionSceneCardMetrics.halfCarouselTopPadding)
            .padding(.bottom, CompanionSceneCardMetrics.bottomDockClearance)
            .frame(maxHeight: .infinity, alignment: .top)
            }
            .scrollTargetBehavior(.viewAligned)
        }
    }

    private var fullGrid: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(displayCompanions, id: \.id) { companion in
                    CompanionSceneShelfCard(
                        companion: companion,
                        isSelected: companion.id == selectedCompanionID,
                        isUnlocked: unlockedIDs.contains(companion.id),
                        friendshipValue: friendshipValue(companion),
                        onTap: {
                            onOpenDetail(companion)
                        }
                    )
                    .matchedGeometryEffect(id: companion.id, in: companionCardNamespace)
                }
            }
            .padding(.horizontal, CompanionSceneCardMetrics.horizontalInset)
            .padding(.top, 12)
            .padding(.bottom, 120)
        }
        .id(selectedTab.id)
    }

    private var tabBar: some View {
        HStack(spacing: 8) {
            ForEach(CompanionSceneShelfTab.allCases) { tab in
                Button {
                    withAnimation(.interactiveSpring(response: 0.26, dampingFraction: 0.88)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 6) {
                        Text(tab.title.localized)
                            .font(BBBFont.font(size: 15, weight: selectedTab == tab ? .heavy : .bold))
                            .foregroundStyle(selectedTab == tab ? DesignToken.textStrong : DesignToken.textMuted)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)

                        Capsule()
                            .fill(selectedTab == tab ? DesignToken.primary : .clear)
                            .frame(width: 30, height: 3)
                    }
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(
                        Capsule(style: .continuous)
                            .fill(selectedTab == tab ? DesignToken.primary.opacity(0.08) : .clear)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    private var displayCompanions: [BabyCompanion] {
        companions.companionSceneUniquedByID()
    }

    private var displayHalfItems: [CompanionSceneHalfItem] {
        halfItems
    }
}

private struct CompanionSceneCarouselCard: View {
    let companion: BabyCompanion
    let role: CompanionSceneHalfItem.Role
    let roleText: String
    let isSelected: Bool
    let isUnlocked: Bool
    let friendshipValue: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                roleIndicator
                    .padding(.horizontal, 10)
                    .padding(.top, 7)

                Group {
                    if role == .more {
                        moreArtwork
                    } else if isVisitorRole {
                        visitorArtwork
                    } else {
                        CompanionSceneCardFigure(
                            companion: companion,
                            isUnlocked: isUnlocked,
                            isSelected: isSelected,
                            size: 78,
                            height: 78
                        )
                    }
                }
                .frame(height: 78)

                footer
                    .padding(.horizontal, 10)

                Spacer(minLength: 7)
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(CompanionSceneCardMetrics.cardAspectRatio, contentMode: .fit)
            .background(cardBackground)
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("\(companion.localizedName)，\(roleText)")
        .accessibilityHint(accessibilityHint)
    }

    private var roleIndicator: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(roleTint)
                .frame(width: 5, height: 5)

            Text(roleText)
                .font(BBBFont.font(size: 9, weight: .heavy))
                .foregroundStyle(roleTint)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Spacer(minLength: 0)
        }
        .frame(height: 16)
    }

    private var visitorArtwork: some View {
        GeometryReader { proxy in
            ZStack {
                CompanionAnimalFigure(
                    companion: companion,
                    isUnlocked: true,
                    size: 92
                )
                .rotationEffect(.degrees(13))
                .position(x: 9, y: proxy.size.height * 0.54)
                .shadow(color: DesignToken.shadowColor.opacity(0.14), radius: 10, y: 6)

                Image("bbbucks_coin")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 54, height: 54)
                    .opacity(0.90)
                    .rotationEffect(.degrees(-10))
                    .position(x: proxy.size.width + 3, y: proxy.size.height * 0.48)
                    .shadow(color: DesignToken.reward.opacity(0.16), radius: 8, y: 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        }
    }

    private var moreArtwork: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(DesignToken.primary.opacity(0.08))
                .frame(width: 58, height: 58)

            Image(systemName: "square.grid.3x3.fill")
                .font(.system(size: 23, weight: .bold))
                .foregroundStyle(DesignToken.primaryGradient)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var footer: some View {
        if role == .more {
            Text("更多伙伴")
                .font(BBBFont.font(size: 13, weight: .heavy))
                .foregroundStyle(DesignToken.textStrong)
                .frame(maxWidth: .infinity, minHeight: 18)
        } else if isVisitorRole {
            HStack(spacing: 4) {
                Text(companion.localizedName)
                    .font(BBBFont.font(size: 12, weight: .heavy))
                    .foregroundStyle(DesignToken.textStrong)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)

                Spacer(minLength: 2)

                CompanionFriendshipHearts(
                    companion: companion,
                    friendshipValue: friendshipValue,
                    isUnlocked: isUnlocked,
                    size: 7,
                    filledColor: DesignToken.primary
                )
            }
            .frame(height: 18)
        } else if isUnlocked {
            Text(companion.localizedName)
                .font(BBBFont.font(size: 14, weight: .heavy))
                .foregroundStyle(DesignToken.textStrong)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .frame(maxWidth: .infinity, minHeight: 18)
        } else {
            CompanionFriendshipHearts(
                companion: companion,
                friendshipValue: friendshipValue,
                isUnlocked: isUnlocked,
                size: 10
            )
                .frame(height: 18)
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(cardFill)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(isSelected ? DesignToken.primary.opacity(0.90) : DesignToken.glassStroke.opacity(0.78), lineWidth: isSelected ? 2.6 : 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(DesignToken.glassStroke.opacity(isSelected ? 0.82 : 0), lineWidth: 1.5)
                    .padding(3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(selectedGlowColor.opacity(isSelected ? 0.12 : 0))
                    .blur(radius: 12)
                    .padding(2)
            )
            .shadow(color: selectedGlowColor.opacity(isSelected ? 0.30 : 0.10), radius: isSelected ? 22 : 14, y: isSelected ? 11 : 7)
    }

    private var selectedGlowColor: Color {
        DesignToken.primary
    }

    private var cardFill: AnyShapeStyle {
        if role == .more {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [DesignToken.surfaceRaised.opacity(0.76), DesignToken.primary.opacity(0.10)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        if isVisitorRole {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [DesignToken.surfaceRaised.opacity(0.80), DesignToken.rewardSoft.opacity(0.78)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        return AnyShapeStyle(DesignToken.surfaceRaised.opacity(isSelected ? 0.92 : (isUnlocked ? 0.74 : 0.48)))
    }

    private var roleTint: Color {
        switch role {
        case .current: return DesignToken.primary
        case .todayVisitor: return DesignToken.reward
        case .visitor: return DesignToken.rewardText
        case .recentVisitor: return DesignToken.primary
        case .companion: return DesignToken.textMuted
        case .more: return DesignToken.primary
        }
    }

    private var isVisitorRole: Bool {
        role == .todayVisitor || role == .visitor || role == .recentVisitor
    }

    private var accessibilityHint: String {
        switch role {
        case .todayVisitor: return "打开今日来访卡"
        case .recentVisitor: return "打开来访记录"
        case .more: return "打开全部伙伴"
        case .current, .visitor, .companion: return "打开伙伴详情"
        }
    }
}

private struct CompanionSceneShelfCard: View {
    let companion: BabyCompanion
    let isSelected: Bool
    let isUnlocked: Bool
    let friendshipValue: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                VStack(spacing: 8) {
                    ZStack {
                        CompanionSceneCardFigure(
                            companion: companion,
                            isUnlocked: isUnlocked,
                            isSelected: isSelected,
                            size: 92,
                            height: 104
                        )
                        .padding(.top, 8)
                    }

                    if isUnlocked {
                        Text(companion.localizedName)
                            .font(BBBFont.font(size: 15, weight: .heavy))
                            .foregroundStyle(DesignToken.textStrong)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                    } else {
                        CompanionFriendshipHearts(
                            companion: companion,
                            friendshipValue: friendshipValue,
                            isUnlocked: isUnlocked,
                            size: 10
                        )
                            .frame(height: 19)
                    }

                    Spacer(minLength: 8)
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(0.80, contentMode: .fit)
                .background(cardBackground)
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("\(companion.localizedName)，\(isUnlocked ? "已解锁" : "待解锁")")
        .accessibilityHint("打开伙伴详情")
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(DesignToken.surfaceRaised.opacity(isSelected ? 0.92 : (isUnlocked ? 0.74 : 0.48)))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(isSelected ? DesignToken.primary.opacity(0.90) : DesignToken.glassStroke.opacity(0.78), lineWidth: isSelected ? 2.6 : 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(DesignToken.glassStroke.opacity(isSelected ? 0.82 : 0), lineWidth: 1.5)
                    .padding(3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(selectedGlowColor.opacity(isSelected ? 0.12 : 0))
                    .blur(radius: 12)
                    .padding(2)
            )
            .shadow(color: selectedGlowColor.opacity(isSelected ? 0.30 : 0.10), radius: isSelected ? 22 : 14, y: isSelected ? 11 : 7)
    }

    private var selectedGlowColor: Color {
        DesignToken.primary
    }
}

private struct CompanionSceneCardFigure: View {
    let companion: BabyCompanion
    let isUnlocked: Bool
    let isSelected: Bool
    let size: CGFloat
    let height: CGFloat

    var body: some View {
        ZStack {
            if !isUnlocked {
                CompanionDashedPortraitOutline(
                    assetName: companion.portraitAssetName,
                    size: size
                )
            }

            CompanionAnimalFigure(companion: companion, isUnlocked: isUnlocked, size: size)
                .opacity(isUnlocked ? 1 : 0.24)
                .saturation(isUnlocked ? 1 : 0.10)
                .scaleEffect(isSelected ? 1.08 : 1)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .shadow(color: DesignToken.primary.opacity(isSelected ? 0.28 : 0), radius: 16, y: 8)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
    }
}

private enum CompanionSceneBreathingMetrics {
    // Match the roughly 3% idle-breath range without introducing a rig or
    // making the flat illustration read as an exaggerated squash-and-stretch.
    static let inhaleScaleX: CGFloat = 0.988
    static let inhaleScaleY: CGFloat = 1.035
    static let inhaleLift: CGFloat = 1.5
    static let halfCycleDuration: TimeInterval = 2.0
}

private struct CompanionSceneBreathingFigure: View {
    let companion: BabyCompanion
    let isUnlocked: Bool
    let size: CGFloat

    @State private var isBreathing = false

    var body: some View {
        CompanionAnimalFigure(
            companion: companion,
            isUnlocked: isUnlocked,
            size: size
        )
        // Anchor at the feet so the Buddy stays grounded while breathing.
        .scaleEffect(
            x: isBreathing ? CompanionSceneBreathingMetrics.inhaleScaleX : 1,
            y: isBreathing ? CompanionSceneBreathingMetrics.inhaleScaleY : 1,
            anchor: .bottom
        )
        .offset(y: isBreathing ? -CompanionSceneBreathingMetrics.inhaleLift : 0)
        .animation(
            .easeInOut(duration: CompanionSceneBreathingMetrics.halfCycleDuration)
                .repeatForever(autoreverses: true),
            value: isBreathing
        )
        .onAppear {
            isBreathing = true
        }
    }
}

private struct CompanionDashedPortraitOutline: View {
    let assetName: String
    let size: CGFloat

    private let outlineRadius: CGFloat = 1.35
    private let sampleCount = 10

    var body: some View {
        ZStack {
            ForEach(0..<sampleCount, id: \.self) { index in
                portraitMask
                    .foregroundStyle(DesignToken.textFaint.opacity(0.34))
                    .offset(offset(for: index))
            }

            portraitMask
                .foregroundStyle(DesignToken.scrim)
                .blendMode(.destinationOut)
        }
        .compositingGroup()
        .mask(CompanionOutlineDashMask())
        .frame(width: size + outlineRadius * 2, height: size + outlineRadius * 2)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var portraitMask: some View {
        Image(assetName)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
    }

    private func offset(for index: Int) -> CGSize {
        let angle = Double(index) / Double(sampleCount) * Double.pi * 2
        return CGSize(
            width: cos(angle) * outlineRadius,
            height: sin(angle) * outlineRadius
        )
    }
}

private struct CompanionOutlineDashMask: View {
    var body: some View {
        Canvas { context, canvasSize in
            var stripes = Path()
            let spacing: CGFloat = 7
            var x = -canvasSize.height

            while x < canvasSize.width {
                stripes.move(to: CGPoint(x: x, y: 0))
                stripes.addLine(to: CGPoint(x: x + canvasSize.height, y: canvasSize.height))
                x += spacing
            }

            context.stroke(
                stripes,
                with: .color(.white),
                style: StrokeStyle(lineWidth: 2.8, lineCap: .round)
            )
        }
    }
}

private enum CompanionSceneShelfTab: String, CaseIterable, Identifiable {
    case all
    case recent
    case unlocked
    case locked

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "全部伙伴"
        case .recent: return "最近访问"
        case .unlocked: return "已解锁"
        case .locked: return "待解锁"
        }
    }
}

private enum CompanionScenePanelMode: Equatable {
    case scene
    case half
    case full
}

private extension Array where Element: Hashable {
    func companionSceneUniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

private extension Array where Element == BabyCompanion {
    func companionSceneUniquedByID() -> [BabyCompanion] {
        var seen = Set<String>()
        return filter { seen.insert($0.id).inserted }
    }
}

struct BabyLiveIslandView: View {
    @Environment(\.dismiss) private var dismiss
    let messages: [LiveChatMessage]
    let subtitle: String
    let hostCompanion: BabyCompanion
    let visitorCompanions: [BabyCompanion]
    var showsDismissButton = true
    let openRecord: () -> Void
    let openCompanionPicker: () -> Void
    @State private var liked = false
    @State private var heartBurst: [FloatingHeart] = []
    @State private var chatDraft = ""
    @State private var sentMessages: [LiveChatMessage] = []
    @State private var sharePreview: LiveSharePreview?

    init(
        messages: [LiveChatMessage],
        subtitle: String = "\(BabyCompanion.all.count)只小动物正在轻轻陪伴",
        hostCompanion: BabyCompanion = BabyCompanion.all[3],
        visitorCompanions: [BabyCompanion] = [],
        showsDismissButton: Bool = true,
        openRecord: @escaping () -> Void,
        openCompanionPicker: @escaping () -> Void = {}
    ) {
        self.messages = messages
        self.subtitle = subtitle
        self.hostCompanion = hostCompanion
        self.visitorCompanions = visitorCompanions
        self.showsDismissButton = showsDismissButton
        self.openRecord = openRecord
        self.openCompanionPicker = openCompanionPicker
    }

    var body: some View {
        GeometryReader { proxy in
            let metrics = LiveIslandLayoutMetrics(size: proxy.size)

            ZStack {
                LiveIslandSceneView()
                    .ignoresSafeArea()

                LinearGradient(
                    colors: [
                        LiveSceneRenderPalette.shadow.opacity(0.26),
                        LiveSceneRenderPalette.shadow.opacity(0.02),
                        LiveSceneRenderPalette.shadow.opacity(0.46)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)

                VStack(spacing: 0) {
                    liveHeader(metrics: metrics)
                        .padding(.horizontal, metrics.horizontalPadding)
                        .padding(.top, metrics.topPadding)

                    Spacer(minLength: metrics.middleSpacing)

                    VStack(spacing: metrics.composerSpacing) {
                        HStack(alignment: .bottom, spacing: metrics.contentSpacing) {
                            chatStack(metrics: metrics)
                                .allowsHitTesting(false)
                            Spacer(minLength: 6)
                            liveActions(metrics: metrics)
                        }

                        liveComposer(metrics: metrics)
                    }
                    .padding(.horizontal, metrics.horizontalPadding)
                    .padding(.bottom, metrics.bottomPadding)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if !heartBurst.isEmpty {
                    FloatingHeartsView(hearts: heartBurst)
                        .transition(.opacity)
                        .allowsHitTesting(false)
                }
            }
            .background(LiveSceneRenderPalette.canvas.ignoresSafeArea())
        }
        .sheet(item: $sharePreview) { preview in
            LiveSharePreviewSheet(preview: preview)
        }
    }

    private func liveHeader(metrics: LiveIslandLayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 7) {
                HStack(spacing: 8) {
                    liveCompanionAvatar(hostCompanion, size: metrics.hostAvatarSize)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(hostCompanion.localizedName)的小木屋")
                            .font(BBBFont.font(size: metrics.headerTitleSize, weight: .bold))
                            .foregroundStyle(LiveSceneRenderPalette.foreground)
                            .lineLimit(1)
                            .minimumScaleFactor(0.70)

                        Text(subtitle.localized)
                            .font(BBBFont.font(size: metrics.headerSubtitleSize, weight: .semibold))
                            .foregroundStyle(LiveSceneRenderPalette.foreground.opacity(0.82))
                            .lineLimit(1)
                            .minimumScaleFactor(0.70)
                    }

                    Button {} label: {
                        Text("关注")
                            .font(BBBFont.font(size: metrics.followFontSize, weight: .bold))
                            .foregroundStyle(LiveSceneRenderPalette.foreground)
                            .frame(width: metrics.followButtonWidth, height: metrics.followButtonHeight)
                            .background(Capsule().fill(LiveSceneRenderPalette.follow))
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                .padding(.leading, 4)
                .padding(.trailing, 8)
                .frame(height: metrics.headerPillHeight)
                .background(Capsule().fill(LiveSceneRenderPalette.shadow.opacity(0.30)))

                Spacer(minLength: 5)

                if !metrics.isNarrowWidth {
                    visitorAvatarStack(metrics: metrics)
                }

                Text("\(viewerCount)")
                    .font(BBBFont.font(size: metrics.counterFontSize, weight: .bold))
                    .foregroundStyle(LiveSceneRenderPalette.foreground)
                    .padding(.horizontal, 12)
                    .frame(height: metrics.headerIconButtonSize)
                    .background(Capsule().fill(LiveSceneRenderPalette.shadow.opacity(0.26)))

                Button {
                    openCompanionPicker()
                } label: {
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: metrics.headerIconSize, weight: .heavy))
                        .foregroundStyle(LiveSceneRenderPalette.foreground)
                        .frame(width: metrics.headerIconButtonSize, height: metrics.headerIconButtonSize)
                        .background(Circle().fill(LiveSceneRenderPalette.shadow.opacity(0.28)))
                }
                .buttonStyle(ScaleButtonStyle())
            }

            HStack(spacing: 7) {
                Text("小木屋第 1 名")
                    .font(BBBFont.font(size: metrics.secondaryPillFontSize, weight: .bold))
                    .foregroundStyle(LiveSceneRenderPalette.foreground)
                    .padding(.horizontal, 13)
                    .frame(height: metrics.secondaryPillHeight)
                    .background(Capsule().fill(LiveSceneRenderPalette.shadow.opacity(0.30)))

                Spacer()

                liveSquareEntry(metrics: metrics)
            }
        }
    }

    private var viewerCount: Int {
        800 + visitorCompanions.count * 7 + messages.count + sentMessages.count
    }

    private func liveSquareEntry(metrics: LiveIslandLayoutMetrics) -> some View {
        Button {
            openCompanionPicker()
        } label: {
            HStack(spacing: 6) {
                Text("伙伴广场")
                    .font(BBBFont.font(size: metrics.secondaryPillFontSize, weight: .bold))
                    .foregroundStyle(LiveSceneRenderPalette.foreground)
                Image(systemName: "chevron.right")
                    .font(.system(size: metrics.secondaryChevronSize, weight: .heavy))
                    .foregroundStyle(LiveSceneRenderPalette.foreground)
            }
            .padding(.horizontal, 13)
            .frame(height: metrics.secondaryPillHeight)
            .background(Capsule().fill(LiveSceneRenderPalette.shadow.opacity(0.28)))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func visitorAvatarStack(metrics: LiveIslandLayoutMetrics) -> some View {
        HStack(spacing: -8) {
            ForEach(Array(visitorCompanions.prefix(metrics.visitorAvatarLimit).enumerated()), id: \.element.id) { _, companion in
                liveCompanionAvatar(companion, size: metrics.visitorAvatarSize)
            }
        }
    }

    private func liveCompanionAvatar(_ companion: BabyCompanion, size: CGFloat) -> some View {
        Image(companion.portraitAssetName)
            .resizable()
            .scaledToFit()
            .padding(size * 0.06)
            .frame(width: size, height: size)
            .background(Circle().fill(LiveSceneRenderPalette.foreground.opacity(0.22)))
            .clipShape(Circle())
            .overlay(Circle().stroke(LiveSceneRenderPalette.foreground.opacity(0.68), lineWidth: 1.5))
            .shadow(color: LiveSceneRenderPalette.shadow.opacity(0.18), radius: 8, y: 4)
    }

    private func chatStack(metrics: LiveIslandLayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            joinMessage(metrics: metrics)

            ForEach((messages + sentMessages).suffix(metrics.messageLimit)) { message in
                liveMessageRow(message, metrics: metrics)
            }
        }
        .frame(maxWidth: metrics.chatMaxWidth, alignment: .leading)
    }

    private func joinMessage(metrics: LiveIslandLayoutMetrics) -> some View {
        HStack(spacing: 6) {
            levelBadge(34, color: LiveSceneRenderPalette.level)
            Text("\(hostCompanion.localizedName) 加入了直播间")
        }
        .font(BBBFont.font(size: metrics.joinFontSize, weight: .bold))
        .foregroundStyle(LiveSceneRenderPalette.foreground)
        .padding(.leading, 5)
        .padding(.trailing, 12)
        .frame(height: metrics.joinMessageHeight)
        .background(Capsule().fill(LiveSceneRenderPalette.join.opacity(0.68)))
        .shadow(color: LiveSceneRenderPalette.shadow.opacity(0.10), radius: 6, y: 3)
    }

    private func liveMessageRow(_ message: LiveChatMessage, metrics: LiveIslandLayoutMetrics) -> some View {
        HStack(alignment: .center, spacing: 6) {
            if let level = message.level {
                levelBadge(level, color: message.isCareLog ? LiveSceneRenderPalette.careLevel : LiveSceneRenderPalette.chatLevel)
            }

            if let badge = message.badge {
                Text(badge)
                    .font(BBBFont.font(size: metrics.badgeFontSize, weight: .heavy))
                    .foregroundStyle(LiveSceneRenderPalette.foreground)
                    .frame(width: metrics.badgeSize, height: metrics.badgeSize)
                    .background(Circle().fill(LiveSceneRenderPalette.badge))
            }

            Text(message.speaker.localized)
                .font(BBBFont.font(size: metrics.messageSpeakerSize, weight: .bold))
                .foregroundStyle(message.tint)
                .lineLimit(1)

            Text(message.isJoin ? "" : "：\(message.text)")
                .font(BBBFont.font(size: metrics.messageBodySize, weight: .semibold))
                .foregroundStyle(LiveSceneRenderPalette.foreground)
                .lineLimit(2)
                .lineSpacing(1)
        }
        .padding(.leading, 5)
        .padding(.trailing, 11)
        .padding(.vertical, metrics.messageVerticalPadding)
        .background(Capsule().fill(LiveSceneRenderPalette.shadow.opacity(message.isCareLog ? 0.28 : 0.23)))
        .shadow(color: LiveSceneRenderPalette.shadow.opacity(0.06), radius: 5, y: 2)
    }

    private func levelBadge(_ level: Int, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "diamond.fill")
                .font(.system(size: 7, weight: .heavy))
            Text("\(level)")
                .font(BBBFont.font(size: 9, weight: .heavy))
        }
        .foregroundStyle(LiveSceneRenderPalette.foreground)
        .padding(.horizontal, 6)
        .frame(height: 18)
        .background(Capsule().fill(color))
    }

    private func liveActions(metrics: LiveIslandLayoutMetrics) -> some View {
        Color.clear
            .frame(width: metrics.actionColumnWidth, height: 1)
    }

    private func liveComposer(metrics: LiveIslandLayoutMetrics) -> some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                TextField("说点什么...", text: $chatDraft)
                    .font(BBBFont.font(size: metrics.composerFontSize, weight: .semibold))
                    .foregroundStyle(LiveSceneRenderPalette.foreground)
                    .textInputAutocapitalization(.never)
                    .submitLabel(.send)
                    .onSubmit(sendChatMessage)
                    .tint(LiveSceneRenderPalette.foreground)

                Button {
                    sendChatMessage()
                } label: {
                    Image(systemName: chatDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "face.smiling" : "paperplane.fill")
                        .font(.system(size: metrics.composerIconSize, weight: .bold))
                        .foregroundStyle(LiveSceneRenderPalette.foreground.opacity(0.88))
                        .frame(width: metrics.composerButtonSize, height: metrics.composerButtonSize)
                }
                .buttonStyle(ScaleButtonStyle())
            }
            .padding(.leading, 15)
            .padding(.trailing, 7)
            .frame(height: metrics.composerHeight)
            .background(Capsule().fill(LiveSceneRenderPalette.shadow.opacity(0.22)))
            .overlay(Capsule().stroke(LiveSceneRenderPalette.foreground.opacity(0.10), lineWidth: 1))

            Button {
                likeLive()
            } label: {
                liveRoundAction(icon: "heart.fill", colors: [LiveSceneRenderPalette.reactionStart, LiveSceneRenderPalette.reactionEnd], metrics: metrics)
                    .scaleEffect(liked ? 1.12 : 1)
            }
            .buttonStyle(ScaleButtonStyle())

            Button {
                shareLive()
            } label: {
                Image(systemName: "arrowshape.turn.up.right.fill")
                    .font(.system(size: metrics.bottomIconSize, weight: .heavy))
                    .foregroundStyle(LiveSceneRenderPalette.foreground)
                    .frame(width: metrics.bottomActionSize, height: metrics.bottomActionSize)
                    .background(Circle().fill(LiveSceneRenderPalette.shadow.opacity(0.22)))
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    private func liveRoundAction(icon: String, colors: [Color], metrics: LiveIslandLayoutMetrics) -> some View {
        Image(systemName: icon)
            .font(.system(size: metrics.bottomIconSize, weight: .heavy))
            .foregroundStyle(LiveSceneRenderPalette.foreground)
            .frame(width: metrics.bottomActionSize, height: metrics.bottomActionSize)
            .background(
                Circle()
                    .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .shadow(color: colors.first?.opacity(0.26) ?? .clear, radius: 10, y: 4)
            )
    }

    private func likeLive() {
        let burst = FloatingHeart.makeBurst()
        let burstIDs = Set(burst.map(\.id))
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
            liked = true
            heartBurst.append(contentsOf: burst)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.72)) {
                liked = false
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.45) {
            withAnimation(.easeOut(duration: 0.3)) {
                heartBurst.removeAll { burstIDs.contains($0.id) }
            }
        }
    }

    @MainActor
    private func shareLive() {
        let image = LiveShareImageFactory.makeShareImage(
            hostCompanion: hostCompanion,
            visitorCompanions: visitorCompanions,
            subtitle: subtitle
        )
        sharePreview = LiveSharePreview(
            image: image,
            text: "我正在 BBBuddy 看\(hostCompanion.localizedName)的小木屋陪伴直播"
        )
    }

    private func sendChatMessage() {
        let text = chatDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            likeLive()
            return
        }

        sentMessages.append(
            LiveChatMessage(
                speaker: "我",
                text: text,
                tint: DesignToken.easySleepSoft,
                level: 8
            )
        )
        chatDraft = ""
    }

}

struct LiveChatMessage: Identifiable {
    let id = UUID()
    let speaker: String
    let text: String
    let tint: Color
    var level: Int?
    var badge: String?
    var isCareLog = false
    var isJoin = false
}

private struct CompanionShopView: View {
    @Environment(\.dismiss) private var dismiss
    let hostCompanion: BabyCompanion
    let visitorCompanions: [BabyCompanion]

    private let columns = [
        GridItem(.flexible(minimum: 0), spacing: 12),
        GridItem(.flexible(minimum: 0), spacing: 12)
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    DesignToken.canvas,
                    DesignToken.surfaceSoft,
                    DesignToken.surface
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    topBar
                    hero

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(0..<8, id: \.self) { index in
                            placeholderSlot(index)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 36)
                }
                .padding(.top, 18)
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("伙伴商城")
                    .font(BBBFont.font(size: 22, weight: .heavy))
                    .foregroundStyle(DesignToken.textPrimary)

                Text("BBBuddy")
                    .font(BBBFont.font(size: 11, weight: .heavy))
                    .foregroundStyle(DesignToken.textSecondary)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(DesignToken.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(DesignToken.surfaceRaised.opacity(0.92))
                            .shadow(color: DesignToken.shadowColor.opacity(0.08), radius: 12, y: 5)
                    )
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, 18)
    }

    private var hero: some View {
        HStack(spacing: 14) {
            Image(hostCompanion.portraitAssetName)
                .resizable()
                .scaledToFit()
                .frame(width: 76, height: 76)
                .padding(8)
                .background(Circle().fill(DesignToken.surfaceRaised.opacity(0.90)))
                .shadow(color: DesignToken.shadowColor.opacity(0.08), radius: 14, y: 7)

            VStack(alignment: .leading, spacing: 7) {
                Text("\(hostCompanion.localizedName)的小货架")
                    .font(BBBFont.font(size: 18, weight: .heavy))
                    .foregroundStyle(DesignToken.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                HStack(spacing: -8) {
                    ForEach(Array(visitorCompanions.prefix(4).enumerated()), id: \.element.id) { _, companion in
                        Image(companion.portraitAssetName)
                            .resizable()
                            .scaledToFit()
                            .padding(3)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(DesignToken.surfaceRaised.opacity(0.92)))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(DesignToken.borderSubtle, lineWidth: 1))
                    }
                }

                Text("占位")
                    .font(BBBFont.font(size: 12, weight: .bold))
                    .foregroundStyle(DesignToken.textSecondary)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(DesignToken.surfaceRaised.opacity(0.88))
                .shadow(color: DesignToken.shadowColor.opacity(0.06), radius: 18, y: 8)
        )
        .padding(.horizontal, 18)
    }

    private func placeholderSlot(_ index: Int) -> some View {
        VStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            DesignToken.surfaceRaised.opacity(0.92),
                            DesignToken.surfaceSoft.opacity(0.92)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(style: StrokeStyle(lineWidth: 1.4, dash: [6, 6]))
                            .foregroundStyle(DesignToken.line.opacity(0.70))
                            .padding(14)

                        Image(systemName: index.isMultiple(of: 2) ? "shippingbox.fill" : "cart.fill")
                            .font(.system(size: 24, weight: .heavy))
                            .foregroundStyle(DesignToken.textSecondary.opacity(0.36))
                    }
                }
                .aspectRatio(1, contentMode: .fit)

            HStack {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(DesignToken.line.opacity(0.55))
                    .frame(width: 48, height: 9)
                Spacer()
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(DesignToken.line.opacity(0.42))
                    .frame(width: 28, height: 9)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(DesignToken.surface.opacity(0.78))
                .shadow(color: DesignToken.shadowColor.opacity(0.04), radius: 12, y: 6)
        )
    }
}

private struct LiveSharePreview: Identifiable {
    let id = UUID()
    let image: UIImage
    let text: String
}

private struct LiveSharePayload: Identifiable {
    let id = UUID()
    let image: UIImage
    let text: String
}

private struct LiveSharePreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let preview: LiveSharePreview
    @State private var sharePayload: LiveSharePayload?

    var body: some View {
        ZStack {
            DesignToken.canvas.ignoresSafeArea()

            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("分享直播")
                            .font(BBBFont.font(size: 21, weight: .heavy))
                            .foregroundStyle(LiveSharePreviewPalette.foreground)
                        Text("BBBuddy")
                            .font(BBBFont.font(size: 11, weight: .heavy))
                            .foregroundStyle(LiveSharePreviewPalette.foreground.opacity(0.58))
                    }

                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(LiveSharePreviewPalette.foreground)
                            .frame(width: 38, height: 38)
                            .background(Circle().fill(LiveSharePreviewPalette.foreground.opacity(0.14)))
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)

                Image(uiImage: preview.image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: LiveSharePreviewPalette.mediaShadow.opacity(0.38), radius: 24, y: 14)
                    .padding(.horizontal, 30)
                    .frame(maxHeight: .infinity)

                shareTargets
            }
        }
        .sheet(item: $sharePayload) { payload in
            LiveSystemShareSheet(activityItems: [payload.image, payload.text])
        }
    }

    private var shareTargets: some View {
        HStack(spacing: 12) {
            ForEach(LiveSocialShareTarget.allCases) { target in
                Button {
                    sharePayload = LiveSharePayload(image: preview.image, text: preview.text)
                } label: {
                    VStack(spacing: 7) {
                        Image(systemName: target.icon)
                            .font(.system(size: 18, weight: .heavy))
                            .foregroundStyle(LiveSharePreviewPalette.foreground)
                            .frame(width: 46, height: 46)
                            .background(Circle().fill(target.color))

                        Text(target.title.localized)
                            .font(BBBFont.font(size: 11, weight: .bold))
                            .foregroundStyle(LiveSharePreviewPalette.foreground.opacity(0.84))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 22)
        .background(DesignToken.scrim.opacity(0.30))
    }
}

private enum LiveSocialShareTarget: CaseIterable, Identifiable {
    case wechat
    case moments
    case rednote
    case more

    var id: Self { self }

    var title: String {
        switch self {
        case .wechat: return "微信"
        case .moments: return "朋友圈"
        case .rednote: return "小红书"
        case .more: return "更多"
        }
    }

    var icon: String {
        switch self {
        case .wechat: return "bubble.left.and.bubble.right.fill"
        case .moments: return "circle.grid.2x2.fill"
        case .rednote: return "camera.aperture"
        case .more: return "square.and.arrow.up.fill"
        }
    }

    var color: Color {
        switch self {
        case .wechat: return DesignToken.success
        case .moments: return DesignToken.easySleep
        case .rednote: return DesignToken.easyActivity
        case .more: return DesignToken.textMuted
        }
    }
}

private struct LiveSystemShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        controller.popoverPresentationController?.sourceView = controller.view
        controller.popoverPresentationController?.sourceRect = CGRect(x: 1, y: 1, width: 1, height: 1)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

@MainActor
private enum LiveShareImageFactory {
    static func makeShareImage(
        hostCompanion: BabyCompanion,
        visitorCompanions: [BabyCompanion],
        subtitle: String
    ) -> UIImage {
        let snapshot = UIWindow.liveCurrentKeyWindow?.liveSnapshotImage()
        let outputSize = CGSize(width: 1080, height: 1680)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        return UIGraphicsImageRenderer(size: outputSize, format: format).image { context in
            let cg = context.cgContext
            drawBackground(in: cg, size: outputSize)
            drawCard(in: cg, size: outputSize)
            drawLogo(in: CGRect(x: 124, y: 102, width: 420, height: 70))

            let count = max(visitorCompanions.count, 1)
            let title = "\(hostCompanion.localizedName)的小木屋正在直播"
            drawText(title, in: CGRect(x: 124, y: 174, width: 832, height: 48), size: 38, weight: .bold, color: UIColor(liveHex: "#20202A"))
            drawText("\(subtitle) · \(count) 位伙伴在线", in: CGRect(x: 124, y: 222, width: 832, height: 34), size: 24, weight: .semibold, color: UIColor(liveHex: "#69677A"))

            let phoneRect = CGRect(x: 190, y: 292, width: 700, height: 1240)
            drawPhoneFrame(in: cg, rect: phoneRect, snapshot: snapshot, hostCompanion: hostCompanion)

            drawText("在 BBBuddy 记录日常，也让小伙伴陪宝宝长大", in: CGRect(x: 124, y: 1562, width: 832, height: 42), size: 26, weight: .semibold, color: UIColor(liveHex: "#58566A"), alignment: .center)
        }
    }

    private static func drawBackground(in cg: CGContext, size: CGSize) {
        let colors = [
            UIColor(liveHex: "#EAF8F1").cgColor,
            UIColor(liveHex: "#F7F2FE").cgColor,
            UIColor(liveHex: "#FDF7EC").cgColor
        ] as CFArray
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.52, 1])!
        cg.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: 0),
            end: CGPoint(x: size.width, y: size.height),
            options: []
        )
    }

    private static func drawCard(in cg: CGContext, size: CGSize) {
        let rect = CGRect(x: 72, y: 64, width: size.width - 144, height: size.height - 128)
        cg.saveGState()
        cg.setShadow(offset: CGSize(width: 0, height: 26), blur: 44, color: UIColor(liveHex: "#4D4B70").withAlphaComponent(0.18).cgColor)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 56)
        LiveShareImageRenderPalette.white.withAlphaComponent(0.94).setFill()
        path.fill()
        cg.restoreGState()

        LiveShareImageRenderPalette.white.withAlphaComponent(0.86).setStroke()
        path.lineWidth = 4
        path.stroke()
    }

    private static func drawLogo(in rect: CGRect) {
        let markRect = CGRect(x: rect.minX, y: rect.minY + 2, width: 66, height: 66)
        let markPath = UIBezierPath(roundedRect: markRect, cornerRadius: 21)
        UIColor(liveHex: "#20202A").setFill()
        markPath.fill()

        drawText("BB", in: markRect.insetBy(dx: 7, dy: 12), size: 27, weight: .black, color: LiveShareImageRenderPalette.white, alignment: .center)
        drawText("BBBuddy", in: CGRect(x: markRect.maxX + 16, y: rect.minY + 8, width: rect.width - 82, height: 34), size: 31, weight: .black, color: UIColor(liveHex: "#20202A"))
        drawText("live companion", in: CGRect(x: markRect.maxX + 17, y: rect.minY + 43, width: rect.width - 82, height: 22), size: 16, weight: .semibold, color: UIColor(liveHex: "#7B788B"))
    }

    private static func drawPhoneFrame(in cg: CGContext, rect: CGRect, snapshot: UIImage?, hostCompanion: BabyCompanion) {
        let framePath = UIBezierPath(roundedRect: rect, cornerRadius: 58)
        cg.saveGState()
        cg.setShadow(offset: CGSize(width: 0, height: 20), blur: 34, color: LiveShareImageRenderPalette.black.withAlphaComponent(0.22).cgColor)
        UIColor(liveHex: "#171820").setFill()
        framePath.fill()
        cg.restoreGState()

        let screenRect = rect.insetBy(dx: 18, dy: 18)
        let screenPath = UIBezierPath(roundedRect: screenRect, cornerRadius: 42)
        cg.saveGState()
        screenPath.addClip()
        UIColor(liveHex: "#0B0E13").setFill()
        UIRectFill(screenRect)

        if let snapshot {
            snapshot.draw(in: aspectFitRect(imageSize: snapshot.size, in: screenRect))
        } else {
            drawFallbackLiveSnapshot(in: screenRect, hostCompanion: hostCompanion)
        }

        cg.restoreGState()

        LiveShareImageRenderPalette.white.withAlphaComponent(0.16).setStroke()
        framePath.lineWidth = 5
        framePath.stroke()
    }

    private static func drawFallbackLiveSnapshot(in rect: CGRect, hostCompanion: BabyCompanion) {
        let colors = [
            UIColor(liveHex: "#6FCF9A").cgColor,
            UIColor(liveHex: "#4C7FEE").cgColor
        ] as CFArray
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
        UIGraphicsGetCurrentContext()?.drawLinearGradient(
            gradient,
            start: CGPoint(x: rect.minX, y: rect.minY),
            end: CGPoint(x: rect.maxX, y: rect.maxY),
            options: []
        )

        if let image = UIImage(named: hostCompanion.portraitAssetName) {
            let imageRect = CGRect(x: rect.midX - 150, y: rect.midY - 170, width: 300, height: 300)
            image.draw(in: imageRect)
        }

        drawText("\(hostCompanion.localizedName)的小木屋", in: CGRect(x: rect.minX + 56, y: rect.maxY - 210, width: rect.width - 112, height: 52), size: 34, weight: .black, color: LiveShareImageRenderPalette.white, alignment: .center)
        drawText("LIVE", in: CGRect(x: rect.minX + 56, y: rect.maxY - 148, width: rect.width - 112, height: 38), size: 24, weight: .black, color: LiveShareImageRenderPalette.white, alignment: .center)
    }

    private static func drawText(
        _ text: String,
        in rect: CGRect,
        size: CGFloat,
        weight: UIFont.Weight,
        color: UIColor,
        alignment: NSTextAlignment = .left
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byTruncatingTail

        (text as NSString).draw(
            in: rect,
            withAttributes: [
                .font: UIFont.systemFont(ofSize: size, weight: weight),
                .foregroundColor: color,
                .paragraphStyle: paragraph
            ]
        )
    }

    private static func aspectFitRect(imageSize: CGSize, in bounds: CGRect) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return bounds }
        let scale = min(bounds.width / imageSize.width, bounds.height / imageSize.height)
        let width = imageSize.width * scale
        let height = imageSize.height * scale
        return CGRect(
            x: bounds.midX - width / 2,
            y: bounds.midY - height / 2,
            width: width,
            height: height
        )
    }
}

private extension UIWindow {
    @MainActor
    static var liveCurrentKeyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
    }

    @MainActor
    func liveSnapshotImage() -> UIImage? {
        guard bounds.width > 1, bounds.height > 1 else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = windowScene?.screen.scale ?? traitCollection.displayScale
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: bounds.size, format: format)
        return renderer.image { _ in
            drawHierarchy(in: bounds, afterScreenUpdates: false)
        }
    }
}

private extension UIColor {
    convenience init(liveHex hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }

        var number: UInt64 = 0
        Scanner(string: value).scanHexInt64(&number)

        let red = CGFloat((number & 0xFF0000) >> 16) / 255
        let green = CGFloat((number & 0x00FF00) >> 8) / 255
        let blue = CGFloat(number & 0x0000FF) / 255
        self.init(red: red, green: green, blue: blue, alpha: 1)
    }
}

private struct LiveIslandLayoutMetrics {
    let size: CGSize

    var isCompactHeight: Bool { size.height < 720 }
    var isNarrowWidth: Bool { size.width < 390 }

    var horizontalPadding: CGFloat {
        isNarrowWidth ? 14 : 16
    }

    var topPadding: CGFloat {
        isCompactHeight ? 8 : 12
    }

    var bottomPadding: CGFloat {
        isCompactHeight ? 10 : 14
    }

    var middleSpacing: CGFloat {
        isCompactHeight ? 12 : 22
    }

    var composerSpacing: CGFloat {
        isCompactHeight ? 7 : 10
    }

    var contentSpacing: CGFloat {
        isNarrowWidth ? 8 : 12
    }

    var messageLimit: Int {
        isCompactHeight ? 4 : 5
    }

    var chatMaxWidth: CGFloat {
        max(184, min(size.width - horizontalPadding * 2 - actionColumnWidth - contentSpacing - 6, isNarrowWidth ? 256 : 286))
    }

    var messageVerticalPadding: CGFloat {
        isCompactHeight ? 4 : 5
    }

    var avatarSize: CGFloat {
        isNarrowWidth ? 32 : 34
    }

    var hostAvatarSize: CGFloat {
        avatarSize + 4
    }

    var visitorAvatarSize: CGFloat {
        isNarrowWidth ? 28 : 31
    }

    var visitorAvatarLimit: Int {
        isNarrowWidth ? 2 : 3
    }

    var headerTitleSize: CGFloat {
        isNarrowWidth ? 12 : 12.5
    }

    var headerSubtitleSize: CGFloat {
        isNarrowWidth ? 8.5 : 9
    }

    var followFontSize: CGFloat {
        isNarrowWidth ? 12 : 12.5
    }

    var followButtonWidth: CGFloat {
        isNarrowWidth ? 48 : 50
    }

    var followButtonHeight: CGFloat {
        isNarrowWidth ? 28 : 29
    }

    var headerPillHeight: CGFloat {
        isNarrowWidth ? 43 : 45
    }

    var headerIconButtonSize: CGFloat {
        isNarrowWidth ? 34 : 36
    }

    var headerIconSize: CGFloat {
        isNarrowWidth ? 14 : 15
    }

    var counterFontSize: CGFloat {
        isNarrowWidth ? 14 : 14.5
    }

    var secondaryPillFontSize: CGFloat {
        isNarrowWidth ? 13 : 14
    }

    var secondaryPillHeight: CGFloat {
        isNarrowWidth ? 30 : 32
    }

    var secondaryChevronSize: CGFloat {
        isNarrowWidth ? 12 : 13
    }

    var joinFontSize: CGFloat {
        isNarrowWidth ? 13 : 14
    }

    var joinMessageHeight: CGFloat {
        isNarrowWidth ? 28 : 30
    }

    var messageSpeakerSize: CGFloat {
        isNarrowWidth ? 13 : 13.5
    }

    var messageBodySize: CGFloat {
        isNarrowWidth ? 13 : 13.5
    }

    var badgeFontSize: CGFloat {
        isNarrowWidth ? 9 : 10
    }

    var badgeSize: CGFloat {
        isNarrowWidth ? 19 : 20
    }

    var bottomActionSize: CGFloat {
        isCompactHeight || isNarrowWidth ? 40 : 42
    }

    var bottomIconSize: CGFloat {
        isCompactHeight || isNarrowWidth ? 18 : 19
    }

    var actionButtonSize: CGFloat {
        bottomActionSize
    }

    var actionColumnWidth: CGFloat {
        1
    }

    var composerHeight: CGFloat {
        isCompactHeight ? 38 : 42
    }

    var composerFontSize: CGFloat {
        isNarrowWidth ? 13 : 13.5
    }

    var composerIconSize: CGFloat {
        isNarrowWidth ? 18 : 19
    }

    var composerButtonSize: CGFloat {
        isCompactHeight || isNarrowWidth ? 30 : 32
    }
}

private struct FloatingHeartsView: View {
    let hearts: [FloatingHeart]
    @State private var isFlying = false

    var body: some View {
        ZStack {
            ForEach(hearts) { heart in
                Image(systemName: heart.systemName)
                    .font(.system(size: heart.size, weight: .semibold))
                    .foregroundStyle(heart.color)
                    .offset(
                        x: heart.x,
                        y: isFlying ? heart.endY : heart.startY
                    )
                    .opacity(isFlying ? 0 : 0.95)
                    .animation(
                        .easeOut(duration: heart.duration).delay(heart.delay),
                        value: isFlying
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .padding(.trailing, 18)
        .padding(.bottom, 126)
        .onAppear {
            isFlying = true
        }
    }
}

private struct FloatingHeart: Identifiable {
    let id = UUID()
    let systemName: String
    let color: Color
    let size: CGFloat
    let x: CGFloat
    let startY: CGFloat
    let endY: CGFloat
    let delay: Double
    let duration: Double

    static func makeBurst() -> [FloatingHeart] {
        (0..<12).map { index in
            let style = [
                ("heart.fill", DesignToken.easyActivity),
                ("sparkles", DesignToken.reward),
                ("star.fill", DesignToken.primary),
                ("heart.circle.fill", DesignToken.primary)
            ].randomElement() ?? ("heart.fill", DesignToken.primary)
            return FloatingHeart(
                systemName: style.0,
                color: style.1,
                size: CGFloat.random(in: 22...34),
                x: CGFloat.random(in: 72...150),
                startY: CGFloat.random(in: -72 ... -112),
                endY: CGFloat.random(in: -250 ... -110),
                delay: Double(index) * 0.035,
                duration: Double.random(in: 0.75...1.18)
            )
        }
    }
}

private struct AchievementStickerMedia: Identifiable, Equatable {
    let id = UUID()
    var image: UIImage
    var originalImage: UIImage? = nil
    var stickerImage: UIImage?
    var prefersStickerPreview: Bool = true
    var capturedAt: Date = Date()
    var filterPresetID: String?
    var watermarkStyleID: String? = AchievementWatermarkStyle.off.rawValue
    var cropState: AchievementCropState = .centered
    var assetLocalIdentifier: String?
    var assetMediaSubtypeRawValue: UInt?
    var livePhotoStillURL: URL?
    var livePhotoMovieURL: URL?
    var pendingLivePhotoResources: AchievementLivePhotoResourceCoordinator?

    var isLivePhoto: Bool {
        if livePhotoMovieURL != nil { return true }
        guard let assetMediaSubtypeRawValue else { return false }
        return (assetMediaSubtypeRawValue & PHAssetMediaSubtype.photoLive.rawValue) != 0
    }

    var mediaKind: AchievementMediaKind {
        prefersStickerPreview ? .sticker : .photo
    }

    var canonicalSourceImage: UIImage {
        originalImage ?? image
    }

    func resolvedLivePhotoResources() async -> AchievementLivePhotoDraftResources? {
        if let livePhotoStillURL, let livePhotoMovieURL {
            return AchievementLivePhotoDraftResources(
                stillURL: livePhotoStillURL,
                movieURL: livePhotoMovieURL
            )
        }
        return await pendingLivePhotoResources?.resources()
    }

    static func == (lhs: AchievementStickerMedia, rhs: AchievementStickerMedia) -> Bool {
        lhs.id == rhs.id
    }
}

private struct AchievementPickedPhoto: @unchecked Sendable {
    let image: UIImage
    let capturedAt: Date
    let assetLocalIdentifier: String?
    let assetMediaSubtypeRawValue: UInt?
    let livePhotoStillURL: URL?
    let livePhotoMovieURL: URL?
}

private struct AchievementLivePhotoDraftResources: Sendable {
    let stillURL: URL
    let movieURL: URL
}

private actor AchievementLivePhotoResourceCoordinator {
    private var stillURL: URL?
    private var movieURL: URL?
    private var isFinished = false
    private var continuations: [UUID: CheckedContinuation<AchievementLivePhotoDraftResources?, Never>] = [:]
    private var cancelledContinuationIDs: Set<UUID> = []

    func setStillURL(_ url: URL) {
        guard !isFinished else {
            try? FileManager.default.removeItem(at: url)
            return
        }
        stillURL = url
        resolveIfPossible()
    }

    func setMovieURL(_ url: URL) {
        guard !isFinished else {
            try? FileManager.default.removeItem(at: url)
            return
        }
        movieURL = url
        resolveIfPossible()
    }

    func finish() {
        isFinished = true
        resolveIfPossible()
    }

    func resources() async -> AchievementLivePhotoDraftResources? {
        if let resources = currentResources {
            return resources
        }
        if isFinished {
            return nil
        }
        let continuationID = UUID()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                if cancelledContinuationIDs.remove(continuationID) != nil || Task.isCancelled {
                    continuation.resume(returning: nil)
                } else if let resources = currentResources {
                    continuation.resume(returning: resources)
                } else if isFinished {
                    continuation.resume(returning: nil)
                } else {
                    continuations[continuationID] = continuation
                }
            }
        } onCancel: {
            Task {
                await self.cancelContinuation(continuationID)
            }
        }
    }

    private func cancelContinuation(_ id: UUID) {
        if let continuation = continuations.removeValue(forKey: id) {
            continuation.resume(returning: nil)
        } else {
            cancelledContinuationIDs.insert(id)
        }
    }

    private var currentResources: AchievementLivePhotoDraftResources? {
        guard let stillURL, let movieURL else { return nil }
        return AchievementLivePhotoDraftResources(stillURL: stillURL, movieURL: movieURL)
    }

    private func resolveIfPossible() {
        guard !continuations.isEmpty else { return }
        if let result = currentResources {
            let waiting = Array(continuations.values)
            continuations.removeAll()
            cancelledContinuationIDs.removeAll()
            waiting.forEach { $0.resume(returning: result) }
            return
        }
        if isFinished {
            let waiting = Array(continuations.values)
            continuations.removeAll()
            cancelledContinuationIDs.removeAll()
            waiting.forEach { $0.resume(returning: nil) }
        }
    }
}

private struct MilestoneLearningPathView: View {
    let birthDate: Date
    @Binding var selectedAchievement: CustomAchievement?
    @Binding var selectedDay: MilestoneDay?
    let onCreateCustomSticker: () -> Void

    var body: some View {
        MilestoneLearningPathContentView(
            birthDate: birthDate,
            selectedAchievement: $selectedAchievement,
            selectedDay: $selectedDay,
            onCreateCustomSticker: onCreateCustomSticker
        )
        .id(Calendar.current.startOfDay(for: birthDate))
    }
}

struct BabyAchievementsView: View {
    @EnvironmentObject private var stickerStore: AchievementStickerStore
    @Environment(BabyProfileStore.self) private var profileStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var sceneEntitlementStore = SceneEntitlementStore.shared
    @State private var showCaptureFlow = false
    @State private var selectedAchievement: CustomAchievement?
    @State private var selectedDay: MilestoneDay?
    @State private var selectedDayMedia: AchievementStickerMedia?
    @State private var achievementCelebrationText: String?
    @Binding private var createRequest: Bool

    let showsHeader: Bool
    let isEmbedded: Bool
    let showsCreateCustomCard: Bool

    init(
        showsHeader: Bool = true,
        isEmbedded: Bool = false,
        createRequest: Binding<Bool> = .constant(false),
        showsCreateCustomCard: Bool = true
    ) {
        self.showsHeader = showsHeader
        self.isEmbedded = isEmbedded
        self._createRequest = createRequest
        self.showsCreateCustomCard = showsCreateCustomCard
    }

    var body: some View {
        Group {
            if isEmbedded {
                achievementContent
            } else {
                ZStack {
                    HomeSoftBackground()

                    ScrollView(showsIndicators: false) {
                        achievementContent
                            .padding(.horizontal, 16)
                            .padding(.top, 24)
                            .padding(.bottom, 140)
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showCaptureFlow) {
            AchievementCaptureFlowView()
                .environmentObject(stickerStore)
        }
        .sheet(item: $selectedAchievement) { achievement in
            AchievementDetailView(achievement: achievement) {
                selectedAchievement = nil
            }
                .environmentObject(stickerStore)
        }
        .sheet(item: $selectedDay) { day in
            MilestoneDayPhotoPicker(
                day: day,
                birthDate: profileStore.currentProfile.birthDate
            ) { media in
                selectedDay = nil
                showCreateStickerForDay(day, media: media)
            }
            .environmentObject(stickerStore)
        }
        .fullScreenCover(item: $selectedDayMedia) { initialMedia in
            AchievementCreationEditorView(
                media: Binding(
                    get: { selectedDayMedia ?? initialMedia },
                    set: { selectedDayMedia = $0 }
                ),
                onCancel: {
                    selectedDayMedia = nil
                },
                onSaved: { achievement in
                    selectedDayMedia = nil
                    selectedAchievement = achievement
                },
                onRetake: {
                    selectedDayMedia = nil
                }
            )
            .environmentObject(stickerStore)
        }
        .onChange(of: createRequest) { _, requested in
            guard requested else { return }
            showCaptureFlow = true
            createRequest = false
        }
        .onChange(of: stickerStore.achievements.count) { oldCount, newCount in
            guard newCount > oldCount, let achievement = stickerStore.achievements.first else { return }
            let sceneAwards = sceneEntitlementStore.consumeLatestAwards()
            achievementCelebrationText = sceneAwards.isEmpty
                ? "\(achievement.name)，被好好留下了。"
                : "\(achievement.name)，被好好留下了 · 已赠送新场景"
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.4))
                achievementCelebrationText = nil
            }
        }
        .overlay(alignment: .top) {
            if let achievementCelebrationText {
                Text(achievementCelebrationText)
                    .font(BBBFont.font(size: 12.5, weight: .heavy))
                    .foregroundStyle(DesignToken.textPrimary)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 40)
                    .background(.ultraThinMaterial, in: Capsule(style: .continuous))
                    .overlay(Capsule().stroke(DesignToken.glassStroke.opacity(0.84), lineWidth: 1))
                    .shadow(color: DesignToken.primary.opacity(0.14), radius: 12, y: 5)
                    .padding(.top, 12)
                    .transition(.opacity.combined(with: reduceMotion ? .identity : .scale(scale: 0.98)))
                    .allowsHitTesting(false)
            }
        }
    }

    private var achievementContent: some View {
        VStack(alignment: .leading, spacing: 22) {
            if showsHeader {
                achievementHeader
            }

            MilestoneLearningPathView(
                birthDate: profileStore.currentProfile.birthDate,
                selectedAchievement: $selectedAchievement,
                selectedDay: $selectedDay,
                onCreateCustomSticker: {
                    showCaptureFlow = true
                }
            )
            .environmentObject(stickerStore)
        }
    }

    private var achievementHeader: some View {
        HStack(alignment: .center) {
            Text("宝宝成就")
                .font(BBBFont.font(size: 22, weight: .heavy))
                .foregroundStyle(DesignToken.textPrimary)
                .frame(height: 44, alignment: .center)

            Spacer()

            progressTag
        }
    }

    private var progressTag: some View {
        HStack(spacing: 4) {
            Text("\(unlockedCount)/\(totalCount)")
                .font(BBBFont.font(size: 14, weight: .heavy))
                .foregroundStyle(DesignToken.onPrimary)
            Text("已解锁")
                .font(BBBFont.font(size: 11, weight: .bold))
                .foregroundStyle(DesignToken.onPrimary.opacity(0.82))
        }
        .frame(height: 34)
        .padding(.horizontal, 12)
        .background(Capsule().fill(DesignToken.primary))
    }

    private var unlockedCount: Int {
        stickerStore.achievements.count
    }

    private var totalCount: Int {
        max(AchievementMilestoneCatalog.all.count, unlockedCount)
    }

    private func showCreateStickerForDay(_ day: MilestoneDay, media: AchievementStickerMedia) {
        // Manual day entries must be reviewed before persistence: photo or sticker,
        // then an optional milestone binding or a custom achievement.
        var editorMedia = media
        editorMedia.prefersStickerPreview = false
        selectedDayMedia = editorMedia
    }
}

private struct MilestoneDefinition: Identifiable, Hashable {
    let id: String
    let title: String
    let description: String
    let kind: AchievementMilestoneKind
    let targetDayOffset: Int?
    let agePageIndex: Int?
    let symbol: String

    var template: AchievementTemplate {
        AchievementTemplate(
            id: id,
            title: title,
            description: description,
            symbol: symbol,
            milestoneKind: kind,
            targetDayOffset: targetDayOffset,
            agePageIndex: agePageIndex
        )
    }

    var category: AchievementMilestoneCategory {
        switch kind {
        case .importantDay: return .importantDay
        case .monthly, .custom: return .growth
        }
    }

    func isAvailable(at dayOffset: Int) -> Bool {
        guard dayOffset >= 1 else { return false }
        if let targetDayOffset {
            return dayOffset >= targetDayOffset
        }
        if let agePageIndex {
            return MilestoneDay.pageIndex(for: dayOffset) >= agePageIndex
        }
        return true
    }

    var availabilityText: String {
        if let targetDayOffset {
            if targetDayOffset == 1 { return "出生当天" }
            return "第 \(targetDayOffset) 天"
        }
        if let agePageIndex {
            return "\(agePageIndex)-\(agePageIndex + 1) 月龄"
        }
        return "随时可完成"
    }
}

private enum AchievementMilestoneCategory: String, CaseIterable, Identifiable {
    case all
    case importantDay
    case growth

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "全部"
        case .importantDay: return "重要日期"
        case .growth: return "成长里程碑"
        }
    }
}

private enum AchievementMilestoneCatalog {
    static let importantDays: [MilestoneDefinition] = [
        .init(id: "birth-day", title: "出生日", description: "宝宝来到这个世界的第一天。", kind: .importantDay, targetDayOffset: 1, agePageIndex: nil, symbol: "sparkles"),
        .init(id: "one-month", title: "满月啦", description: "宝宝来到身边 30 天，正式收下第一枚月龄纪念。", kind: .importantDay, targetDayOffset: 30, agePageIndex: nil, symbol: "moon.stars.fill"),
        .init(id: "hundred-days", title: "百日纪念", description: "宝宝的第 100 天，值得认真留下一张纪念。", kind: .importantDay, targetDayOffset: 100, agePageIndex: nil, symbol: "100.circle.fill"),
        .init(id: "half-year", title: "半岁啦", description: "宝宝半岁了，身体和表情都更有力量。", kind: .importantDay, targetDayOffset: 180, agePageIndex: nil, symbol: "seal.fill"),
        .init(id: "first-birthday", title: "一周岁", description: "宝宝的第一个生日，一整年的成长在这天汇合。", kind: .importantDay, targetDayOffset: 365, agePageIndex: nil, symbol: "birthday.cake.fill")
    ]

    static let monthlyMilestones: [MilestoneDefinition] = [
        .init(id: "zero-bcg", title: "卡介苗接种", description: "按接种安排完成宝宝出生后的重要疫苗记录。", kind: .monthly, targetDayOffset: nil, agePageIndex: 0, symbol: "cross.case.fill"),
        .init(id: "zero-face-focus", title: "注视人脸", description: "开始安静地看向熟悉照护者的脸。", kind: .monthly, targetDayOffset: nil, agePageIndex: 0, symbol: "face.smiling.fill"),
        .init(id: "one-sound-response", title: "回应声音", description: "听到熟悉声音时会安静、转头或出现表情变化。", kind: .monthly, targetDayOffset: nil, agePageIndex: 1, symbol: "ear.fill"),
        .init(id: "one-short-head-lift", title: "短暂抬头", description: "趴着时能短暂抬起头，开始练习颈部力量。", kind: .monthly, targetDayOffset: nil, agePageIndex: 1, symbol: "figure.strengthtraining.traditional"),
        .init(id: "two-three-head-lift", title: "昂首挺胸", description: "趴着时，头和胸部能完全抬起，与床面呈 45 到 90 度，并用前臂支撑身体。", kind: .monthly, targetDayOffset: nil, agePageIndex: 2, symbol: "figure.strengthtraining.traditional"),
        .init(id: "two-three-hands", title: "发现小手", description: "开始长时间盯着自己的手看，或者把两只手凑到胸前玩耍。", kind: .monthly, targetDayOffset: nil, agePageIndex: 2, symbol: "hand.raised.fill"),
        .init(id: "two-three-suck-hand", title: "吃手成章", description: "能精准地把小手或手指放进嘴里吮吸，这是自我安抚的重要进步。", kind: .monthly, targetDayOffset: nil, agePageIndex: 2, symbol: "hand.thumbsup.fill"),
        .init(id: "two-three-baby-talk", title: "婴语交流", description: "当大人对宝宝说话时，会发出咕噜咕噜或啊哦的声音进行对答。", kind: .monthly, targetDayOffset: nil, agePageIndex: 2, symbol: "bubble.left.and.bubble.right.fill"),
        .init(id: "two-three-laugh", title: "咯咯笑声", description: "被逗弄时，能发出清晰清脆的笑声，而不仅仅是面部微笑。", kind: .monthly, targetDayOffset: nil, agePageIndex: 2, symbol: "face.smiling.fill"),
        .init(id: "two-three-emotion", title: "情绪表达", description: "不开心或需求未满足时，哭声开始有明显的辨识度。", kind: .monthly, targetDayOffset: nil, agePageIndex: 2, symbol: "heart.text.square.fill"),
        .init(id: "three-six-hour-sleep", title: "睡够6小时", description: "出现更长的连续睡眠片段，夜间节奏开始更稳定。", kind: .monthly, targetDayOffset: nil, agePageIndex: 3, symbol: "moon.zzz.fill"),
        .init(id: "three-steady-head", title: "稳定抬头", description: "抱起或趴卧时，头颈控制更稳定。", kind: .monthly, targetDayOffset: nil, agePageIndex: 3, symbol: "figure.strengthtraining.traditional"),
        .init(id: "three-laugh-back", title: "逗弄回应", description: "被逗弄时会用笑声、表情或声音回应。", kind: .monthly, targetDayOffset: nil, agePageIndex: 3, symbol: "bubble.left.fill"),
        .init(id: "four-roll-over", title: "学会翻身", description: "开始从仰卧翻到侧卧或俯卧，身体控制明显提升。", kind: .monthly, targetDayOffset: nil, agePageIndex: 4, symbol: "arrow.triangle.2.circlepath"),
        .init(id: "four-reach-grab", title: "伸手抓握", description: "会主动伸手去够近处玩具，并尝试抓住。", kind: .monthly, targetDayOffset: nil, agePageIndex: 4, symbol: "hand.point.up.left.fill"),
        .init(id: "five-name-response", title: "听见名字", description: "听到自己的名字或熟悉呼唤时，会看向声音来源。", kind: .monthly, targetDayOffset: nil, agePageIndex: 5, symbol: "person.wave.2.fill"),
        .init(id: "five-sit-support", title: "扶坐练习", description: "在支撑下能更稳定地坐起一小会儿。", kind: .monthly, targetDayOffset: nil, agePageIndex: 5, symbol: "figure.seated.side")
    ]

    static var all: [MilestoneDefinition] {
        importantDays + monthlyMilestones
    }

    static func importantMilestone(onDayOffset dayOffset: Int) -> MilestoneDefinition? {
        importantDays.first { $0.targetDayOffset == dayOffset }
    }

    static func milestones(forPage pageIndex: Int) -> [MilestoneDefinition] {
        importantDays.filter { milestone in
            guard let offset = milestone.targetDayOffset else { return false }
            return MilestoneDay.pageIndex(for: offset) == pageIndex
        } + monthlyMilestones.filter { $0.agePageIndex == pageIndex }
    }

    static func defaultMilestone(forDayOffset dayOffset: Int, pageIndex: Int) -> MilestoneDefinition? {
        importantMilestone(onDayOffset: dayOffset)
    }

    static func milestone(id: String?) -> MilestoneDefinition? {
        guard let id else { return nil }
        return all.first { $0.id == id }
    }
}

private struct MilestoneDay: Identifiable, Hashable {
    let dayOffset: Int
    let date: Date

    var id: Int { dayOffset }
    var pageIndex: Int { Self.pageIndex(for: dayOffset) }

    // Milestone day numbers are inclusive: the birth date is day 1, never day 0.
    static func dayNumber(birthDate: Date, on date: Date, calendar: Calendar = .current) -> Int {
        let birthStart = calendar.startOfDay(for: birthDate)
        let targetStart = calendar.startOfDay(for: date)
        let elapsedDays = calendar.dateComponents([.day], from: birthStart, to: targetStart).day ?? 0
        return max(elapsedDays + 1, 1)
    }

    static func date(forDayNumber dayOffset: Int, birthDate: Date, calendar: Calendar = .current) -> Date? {
        guard dayOffset >= 1 else { return nil }
        return calendar.date(
            byAdding: .day,
            value: dayOffset - 1,
            to: calendar.startOfDay(for: birthDate)
        )
    }

    static func pageIndex(for dayOffset: Int) -> Int {
        max((dayOffset - 1) / 30, 0)
    }
}

private struct MilestoneDayAchievementGroup: Identifiable {
    let day: MilestoneDay
    let achievementIDs: [UUID]
    let initialAchievementID: UUID?

    var id: Int { day.id }
}

private struct MilestoneUnitTheme {
    let primary: Color
    let secondary: Color
    let depth: Color
    let soft: Color

    static func theme(for pageIndex: Int) -> MilestoneUnitTheme {
        switch pageIndex % 4 {
        case 0:
            return MilestoneUnitTheme(
                primary: DesignToken.easyEat,
                secondary: DesignToken.easyEat,
                depth: DesignToken.easyEatText,
                soft: DesignToken.easyEatSoft
            )
        case 1:
            return MilestoneUnitTheme(
                primary: DesignToken.easyActivity,
                secondary: DesignToken.easyActivity,
                depth: DesignToken.easyActivityText,
                soft: DesignToken.easyActivitySoft
            )
        case 2:
            return MilestoneUnitTheme(
                primary: DesignToken.easySleep,
                secondary: DesignToken.easySleep,
                depth: DesignToken.easySleepText,
                soft: DesignToken.easySleepSoft
            )
        default:
            return MilestoneUnitTheme(
                primary: DesignToken.easyYearning,
                secondary: DesignToken.easyYearning,
                depth: DesignToken.easyYearningText,
                soft: DesignToken.easyYearningSoft
            )
        }
    }
}

private struct MilestoneLearningPathContentView: View {
    @EnvironmentObject private var stickerStore: AchievementStickerStore
    let birthDate: Date
    @Binding var selectedAchievement: CustomAchievement?
    @Binding var selectedDay: MilestoneDay?
    let onCreateCustomSticker: () -> Void

    @State private var pageIndex: Int
    @State private var isScanning = false
    @State private var autoMatchCandidates: [MilestoneAutoMatchCandidate] = []
    @State private var cachedAutoMatchCandidates: [Int: [MilestoneAutoMatchCandidate]] = [:]
    @State private var showAutoMatchIntro = false
    @State private var showAutoMatchProgress = false
    @State private var showAutoMatchReview = false
    @State private var scanProgress = MilestoneScanProgress.idle
    @State private var selectedAchievementGroup: MilestoneDayAchievementGroup?
    @State private var scanMessage: String?
    @State private var loadedPageUpperBound: Int
    @State private var loadedDaysCache: [MilestoneDay]
    @State private var focusedDayOffset: Int
    @State private var didScrollToInitialDay = false
    @State private var pathViewportHeight: CGFloat = 0
    @State private var isCurrentDayVisible = true
    @State private var floatingButtonsTucked = false
    @State private var scanTask: Task<Void, Never>?

    private let verticalStep: CGFloat = 126
    private let pathNodeButtonSize: CGFloat = 140
    private let floatingButtonTrailing: CGFloat = 4
    private let pathTopPadding: CGFloat = 36

    init(
        birthDate: Date,
        selectedAchievement: Binding<CustomAchievement?>,
        selectedDay: Binding<MilestoneDay?>,
        onCreateCustomSticker: @escaping () -> Void
    ) {
        self.birthDate = birthDate
        self._selectedAchievement = selectedAchievement
        self._selectedDay = selectedDay
        self.onCreateCustomSticker = onCreateCustomSticker
        let currentDay = MilestoneDay.dayNumber(birthDate: birthDate, on: Date())
        let currentPage = MilestoneDay.pageIndex(for: currentDay)
        let initialUpperBound = max(currentPage + 2, 2)
        let calendar = Calendar.current
        let initialDays = (1...((initialUpperBound + 1) * 30)).compactMap { dayOffset -> MilestoneDay? in
            guard let date = MilestoneDay.date(forDayNumber: dayOffset, birthDate: birthDate, calendar: calendar) else { return nil }
            return MilestoneDay(dayOffset: dayOffset, date: date)
        }
        self._pageIndex = State(initialValue: currentPage)
        self._loadedPageUpperBound = State(initialValue: initialUpperBound)
        self._loadedDaysCache = State(initialValue: initialDays)
        self._focusedDayOffset = State(initialValue: currentDay)
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollViewReader { reader in
                VStack(spacing: 0) {
                    unitHeader(reader: reader)
                        .id("unit-header")
                        .zIndex(2)

                    ZStack(alignment: .bottomTrailing) {
                        ScrollView(showsIndicators: false) {
                            pathCanvas(width: max(proxy.size.width, 320))
                                .padding(.bottom, 150)
                        }
                        .coordinateSpace(name: "MilestonePathScroll")
                        .onScrollGeometryChange(for: MilestoneScrollMetrics.self) { geometry in
                            MilestoneScrollMetrics(
                                offset: max(geometry.contentOffset.y + geometry.contentInsets.top, 0),
                                viewportHeight: geometry.containerSize.height
                            )
                        } action: { previousMetrics, metrics in
                            updateScrollState(previous: previousMetrics, current: metrics)
                        }
                        .onScrollPhaseChange { _, newPhase in
                            guard newPhase == .idle, floatingButtonsTucked else { return }
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                                floatingButtonsTucked = false
                            }
                        }
                        .onAppear {
                            scrollToInitialDayIfNeeded(reader: reader)
                        }

                        floatingActionButtons(reader: reader)
                            .padding(.trailing, floatingButtonTrailing)
                            .padding(.bottom, 132)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .sheet(isPresented: $showAutoMatchIntro) {
            MilestoneAutoMatchIntroView(
                pageIndex: pageIndex,
                dateRangeText: dateRangeText,
                onStart: beginRequestedScan
            )
        }
        .sheet(isPresented: $showAutoMatchProgress) {
            MilestoneAutoMatchProgressView(
                pageIndex: pageIndex,
                progress: scanProgress,
                onCancel: cancelScan
            )
            .interactiveDismissDisabled(isScanning)
        }
        .sheet(isPresented: $showAutoMatchReview) {
            MilestoneAutoMatchReviewView(
                pageIndex: pageIndex,
                candidates: autoMatchCandidates,
                onSaved: {
                    cachedAutoMatchCandidates[pageIndex] = nil
                    autoMatchCandidates = []
                    stickerStore.clearPendingAutoMatchCandidates(pageIndex: pageIndex)
                }
            )
            .environmentObject(stickerStore)
        }
        .sheet(item: $selectedAchievementGroup) { group in
            MilestoneDayAchievementsView(group: group)
                .environmentObject(stickerStore)
        }
        .alert("自动匹配", isPresented: Binding(get: { scanMessage != nil }, set: { if !$0 { scanMessage = nil } })) {
            Button("好", role: .cancel) {}
        } message: {
            Text(scanMessage ?? "")
        }
        .onDisappear {
            scanTask?.cancel()
            scanTask = nil
        }
    }

    private func unitHeader(reader: ScrollViewProxy) -> some View {
        let theme = currentUnitTheme

        return HStack(spacing: 12) {
            pageNavButton(systemName: "chevron.left", isEnabled: pageIndex > 0) {
                scrollToPage(max(pageIndex - 1, 0), reader: reader)
            }
            .padding(.leading, 12)

            VStack(alignment: .leading, spacing: 4) {
                Text(headerTitle)
                    .font(BBBFont.font(size: 17, weight: .heavy))
                    .foregroundStyle(DesignToken.onPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)

                Text(dateRangeText)
                    .font(BBBFont.font(size: 11, weight: .heavy))
                    .foregroundStyle(DesignToken.onPrimary.opacity(0.78))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                onCreateCustomSticker()
            } label: {
                Image(systemName: "camera.fill")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(DesignToken.onPrimary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(DesignToken.onPrimary.opacity(0.15)))
                    .contentShape(Circle())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel("创建自定义贴纸")

            Button {
                handleScanButtonTap()
            } label: {
                Group {
                    if isScanning {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    } else {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(DesignToken.onPrimary)
                    }
                }
                .frame(width: 36, height: 36)
                .background(Circle().fill(DesignToken.onPrimary.opacity(0.15)))
                .contentShape(Circle())
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(isScanning)
            .accessibilityLabel(scanButtonTitle)

            pageNavButton(systemName: "chevron.right", isEnabled: true) {
                scrollToPage(pageIndex + 1, reader: reader)
            }
            .padding(.trailing, 12)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 72)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [theme.primary, theme.secondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(theme.depth.opacity(0.42))
                        .frame(height: 6)
                        .offset(y: 3)
                }
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.bottom, -1)
        .animation(.easeInOut(duration: 0.28), value: pageIndex)
    }

    private func pageNavButton(systemName: String, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .heavy))
                .foregroundStyle(DesignToken.onPrimary.opacity(isEnabled ? 0.94 : 0.30))
                .frame(width: DesignToken.minimumTapSize, height: DesignToken.minimumTapSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!isEnabled)
    }

    private func pathCanvas(width: CGFloat) -> some View {
        let canvasWidth = max(width, 320)
        let orderedDays = loadedDays
        let achievementsByDay = Dictionary(
            grouping: stickerStore.achievements.sorted { $0.completedAt > $1.completedAt },
            by: { $0.achievedDayOffset ?? Int.min }
        )

        return LazyVStack(spacing: 0) {
            ForEach(Array(orderedDays.enumerated()), id: \.element.id) { index, day in
                let dayAchievements = achievementsByDay[day.dayOffset] ?? []
                let achievement = dayAchievements.first(where: { $0.isDayCover == true }) ?? dayAchievements.first
                let isToday = Calendar.current.isDate(day.date, inSameDayAs: Date())

                MilestonePathRow(
                    index: index,
                    width: canvasWidth,
                    height: verticalStep,
                    nodeOuterSize: pathNodeButtonSize,
                    showsConnector: index < orderedDays.count - 1
                ) {
                    MilestonePathNode(
                        day: day,
                        isToday: isToday,
                        isLocked: !isUnlocked(day),
                        achievement: achievement,
                        achievementCount: dayAchievements.count,
                        milestone: AchievementMilestoneCatalog.importantMilestone(onDayOffset: day.dayOffset),
                        mediaPayload: achievement.map(pathMediaPayload)
                    ) {
                        guard isUnlocked(day) else { return }
                        if !dayAchievements.isEmpty {
                            selectedAchievementGroup = MilestoneDayAchievementGroup(
                                day: day,
                                achievementIDs: dayAchievements.map(\.id),
                                initialAchievementID: achievement?.id
                            )
                        } else {
                            selectedDay = day
                        }
                    }
                }
                .id(dayAnchorID(day.dayOffset))
            }
        }
        .padding(.top, pathTopPadding)
        .frame(width: canvasWidth, alignment: .top)
    }

    private func pathMediaPayload(_ achievement: CustomAchievement) -> MilestonePathMediaPayload {
        MilestonePathMediaPayload(
            achievementID: achievement.id,
            mediaKind: achievement.resolvedMediaKind,
            originalURL: achievement.originalFilename.map { stickerStore.imageURL(for: $0) },
            stickerURL: achievement.stickerFilename.map { stickerStore.imageURL(for: $0) }
        )
    }

    private var days: [MilestoneDay] {
        days(forPage: pageIndex)
    }

    private var loadedDays: [MilestoneDay] {
        loadedDaysCache
    }

    private func days(forPage page: Int) -> [MilestoneDay] {
        let calendar = Calendar.current
        return (0..<30).compactMap { offset in
            let dayOffset = page * 30 + offset + 1
            guard let date = MilestoneDay.date(forDayNumber: dayOffset, birthDate: birthDate, calendar: calendar) else { return nil }
            return MilestoneDay(dayOffset: dayOffset, date: date)
        }
    }

    private var scanState: AchievementScanPageState? {
        stickerStore.scannedPageStates[pageIndex]
    }

    private var scanButtonTitle: String {
        if isScanning { return "扫描中" }
        if hasCachedCandidates { return "查看结果" }
        return scanState == nil ? "自动匹配" : "重新扫描"
    }

    private var hasCachedCandidates: Bool {
        !(cachedAutoMatchCandidates[pageIndex]?.isEmpty ?? true)
            || !stickerStore.pendingAutoMatchCandidates(pageIndex: pageIndex).isEmpty
    }

    private var scanFooterText: String {
        guard let scanState else {
            return "本页尚未扫描相册"
        }
        return "上次扫描 \(AppDateTimeFormat.dateTime(scanState.scannedAt))，找到 \(scanState.resultCount) 个候选"
    }

    private var dateRangeText: String {
        guard let first = days.first?.date, let last = days.last?.date else { return "" }
        return "\(compactMonthDayText(first)) - \(compactMonthDayText(last))"
    }

    private var currentUnitTheme: MilestoneUnitTheme {
        MilestoneUnitTheme.theme(for: pageIndex)
    }

    private var headerTitle: String {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: birthDate)
        let focusedDate = MilestoneDay.date(forDayNumber: focusedDayOffset, birthDate: start, calendar: calendar) ?? start
        return BabyAgeFormatter.displayText(birthDate: start, on: focusedDate, calendar: calendar)
    }

    private var currentDayOffset: Int {
        MilestoneDay.dayNumber(birthDate: birthDate, on: Date())
    }

    private var currentAgePageIndex: Int {
        MilestoneDay.pageIndex(for: currentDayOffset)
    }

    private var pageTotalMilestones: Int {
        max(AchievementMilestoneCatalog.milestones(forPage: pageIndex).count, completedAchievementsOnPage.count)
    }

    private var completedMilestoneCount: Int {
        let pageMilestoneIDs = Set(AchievementMilestoneCatalog.milestones(forPage: pageIndex).map(\.id))
        let completedIDs = Set(completedAchievementsOnPage.compactMap { $0.milestoneID ?? $0.templateID })
        return completedIDs.intersection(pageMilestoneIDs).count
    }

    private var completedAchievementsOnPage: [CustomAchievement] {
        let range = (pageIndex * 30 + 1)...((pageIndex + 1) * 30)
        return stickerStore.achievements.filter { achievement in
            guard let offset = achievement.achievedDayOffset else { return false }
            return range.contains(offset)
        }
    }

    private var progressText: String {
        let total = max(pageTotalMilestones, 1)
        return "\(completedMilestoneCount)/\(total)"
    }

    private var renderedDayCount: Int {
        loadedDaysCache.count
    }

    private func dayAnchorID(_ dayOffset: Int) -> String {
        "milestone-day-\(dayOffset)"
    }

    private func compactMonthDayText(_ date: Date) -> String {
        let components = Calendar.current.dateComponents([.month, .day], from: date)
        return "\(components.month ?? 1)月\(components.day ?? 1)"
    }

    private func isUnlocked(_ day: MilestoneDay) -> Bool {
        day.dayOffset <= currentDayOffset
    }

    private func quickReturnButton(reader: ScrollViewProxy) -> some View {
        Button {
            let returnDistance = abs(focusedDayOffset - currentDayOffset)
            ensurePageLoaded(currentAgePageIndex + 2)
            pageIndex = currentAgePageIndex
            focusedDayOffset = currentDayOffset
            DispatchQueue.main.async {
                scroll(
                    reader,
                    to: currentDayOffset,
                    anchor: .center,
                    animated: returnDistance <= 90
                )
            }
        } label: {
            Image(systemName: "arrow.up")
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(DesignToken.primary)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(DesignToken.surfaceRaised.opacity(0.92))
                        .overlay(
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .stroke(DesignToken.borderSubtle, lineWidth: 1)
                        )
                        .shadow(color: DesignToken.shadowColor.opacity(0.18), radius: 12, y: 5)
                )
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("回到当前日期")
    }

    private func floatingActionButtons(reader: ScrollViewProxy) -> some View {
        Group {
            if !isCurrentDayVisible {
                quickReturnButton(reader: reader)
            }
        }
        .offset(x: floatingButtonsTucked ? 58 : 0)
        .opacity(floatingButtonsTucked ? 0.54 : 1)
        .animation(.spring(response: 0.28, dampingFraction: 0.88), value: floatingButtonsTucked)
        .animation(.spring(response: 0.28, dampingFraction: 0.88), value: isCurrentDayVisible)
    }

    private func scrollToPage(_ targetPage: Int, reader: ScrollViewProxy) {
        let page = max(targetPage, 0)
        ensurePageLoaded(page + 2)
        pageIndex = page
        focusedDayOffset = page * 30 + 1
        DispatchQueue.main.async {
            scroll(
                reader,
                to: page * 30 + 1,
                anchor: .top,
                animated: abs(page - currentAgePageIndex) <= 3
            )
        }
    }

    private func scrollToInitialDayIfNeeded(reader: ScrollViewProxy) {
        guard !didScrollToInitialDay else { return }
        ensurePageLoaded(currentAgePageIndex + 2)
        focusedDayOffset = currentDayOffset
        DispatchQueue.main.async {
            reader.scrollTo(dayAnchorID(currentDayOffset), anchor: .center)
            didScrollToInitialDay = true
        }
    }

    private func scroll(
        _ reader: ScrollViewProxy,
        to dayOffset: Int,
        anchor: UnitPoint,
        animated: Bool
    ) {
        if animated {
            withAnimation(.snappy(duration: 0.32, extraBounce: 0.04)) {
                reader.scrollTo(dayAnchorID(dayOffset), anchor: anchor)
            }
        } else {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                reader.scrollTo(dayAnchorID(dayOffset), anchor: anchor)
            }
        }
    }

    private func updateScrollState(
        previous: MilestoneScrollMetrics,
        current: MilestoneScrollMetrics
    ) {
        if pathViewportHeight != current.viewportHeight {
            pathViewportHeight = current.viewportHeight
        }

        updateCurrentDayVisibility(
            scrollOffset: current.offset,
            viewportHeight: current.viewportHeight
        )
        updateActivePage(
            scrollOffset: current.offset,
            viewportHeight: current.viewportHeight
        )
        updateScrollChrome(previousOffset: previous.offset, scrollOffset: current.offset)
    }

    private func updateActivePage(scrollOffset: CGFloat, viewportHeight: CGFloat) {
        guard didScrollToInitialDay else { return }
        guard viewportHeight > 0, renderedDayCount > 0 else { return }

        let referenceY = scrollOffset + viewportHeight * 0.5
        let firstRowCenter = pathTopPadding + verticalStep * 0.5
        let rawDayIndex = Int(((referenceY - firstRowCenter) / verticalStep).rounded())
        let visibleDayOffset = min(max(rawDayIndex + 1, 1), renderedDayCount)
        let activePage = MilestoneDay.pageIndex(for: visibleDayOffset)
        guard activePage <= loadedPageUpperBound else { return }

        if visibleDayOffset != focusedDayOffset {
            focusedDayOffset = visibleDayOffset
        }

        if activePage != pageIndex {
            pageIndex = activePage
        }

        if activePage >= loadedPageUpperBound - 1 {
            ensurePageLoaded(activePage + 2)
        }
    }

    private func updateScrollChrome(previousOffset: CGFloat, scrollOffset newValue: CGFloat) {
        guard abs(newValue - previousOffset) > 0.8 else { return }
        let isContentMovingUp = newValue > previousOffset
        if floatingButtonsTucked != isContentMovingUp {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                floatingButtonsTucked = isContentMovingUp
            }
        }
    }

    private func updateCurrentDayVisibility(scrollOffset: CGFloat, viewportHeight: CGFloat) {
        guard viewportHeight > 0 else { return }
        let currentY = pathTopPadding + verticalStep * (CGFloat(currentDayOffset - 1) + 0.5)
        let nodeRadius: CGFloat = 88
        let visibleTop = scrollOffset + 12
        let visibleBottom = scrollOffset + viewportHeight - 24
        let visible = (currentY + nodeRadius) > visibleTop && (currentY - nodeRadius) < visibleBottom
        guard visible != isCurrentDayVisible else { return }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
            isCurrentDayVisible = visible
        }
    }

    private func ensurePageLoaded(_ page: Int) {
        let upperBound = max(page, 0)
        if upperBound > loadedPageUpperBound {
            let targetDayCount = (upperBound + 1) * 30
            let currentDayCount = loadedDaysCache.count
            if targetDayCount > currentDayCount {
                let calendar = Calendar.current
                let appendedDays = ((currentDayCount + 1)...targetDayCount).compactMap { dayOffset -> MilestoneDay? in
                    guard let date = MilestoneDay.date(forDayNumber: dayOffset, birthDate: birthDate, calendar: calendar) else { return nil }
                    return MilestoneDay(dayOffset: dayOffset, date: date)
                }
                loadedDaysCache.append(contentsOf: appendedDays)
            }
            loadedPageUpperBound = upperBound
        }
    }

    @MainActor
    private func handleScanButtonTap() {
        if let cached = cachedAutoMatchCandidates[pageIndex], !cached.isEmpty {
            autoMatchCandidates = cached
            showAutoMatchReview = true
        } else if !stickerStore.pendingAutoMatchCandidates(pageIndex: pageIndex).isEmpty {
            scanProgress = .restoring
            showAutoMatchProgress = true
            startScanTask { await restorePendingCandidates() }
        } else {
            showAutoMatchIntro = true
        }
    }

    @MainActor
    private func beginRequestedScan() {
        showAutoMatchIntro = false
        scanProgress = .started
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(280))
            guard !Task.isCancelled else { return }
            showAutoMatchProgress = true
            startScanTask { await scanCurrentPage() }
        }
    }

    @MainActor
    private func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
        showAutoMatchProgress = false
    }

    @MainActor
    private func startScanTask(_ operation: @escaping @MainActor () async -> Void) {
        scanTask?.cancel()
        scanTask = Task { @MainActor in
            await operation()
        }
    }

    @MainActor
    private func restorePendingCandidates() async {
        guard !isScanning else { return }
        isScanning = true
        defer { isScanning = false }

        let records = stickerStore.pendingAutoMatchCandidates(pageIndex: pageIndex)
        let scanner = MilestonePhotoScanner()
        do {
            let existingAchievements = await stickerStore.achievementsResolvingImageFingerprints()
            let candidates = try await scanner.restore(
                records: records,
                existingAchievements: existingAchievements
            )
            guard !candidates.isEmpty else {
                stickerStore.clearPendingAutoMatchCandidates(pageIndex: pageIndex)
                showAutoMatchProgress = false
                scanMessage = "上次的候选照片已经不可用，请重新扫描。"
                return
            }
            autoMatchCandidates = candidates
            cachedAutoMatchCandidates[pageIndex] = candidates
            presentAutoMatchReview()
        } catch is CancellationError {
            return
        } catch {
            showAutoMatchProgress = false
            scanMessage = error.localizedDescription
        }
    }

    @MainActor
    private func scanCurrentPage() async {
        guard !isScanning else { return }
        isScanning = true
        defer { isScanning = false }

        let scanner = MilestonePhotoScanner()
        do {
            let existingAchievements = await stickerStore.achievementsResolvingImageFingerprints()
            let candidates = try await scanner.scan(
                pageIndex: pageIndex,
                birthDate: birthDate,
                existingAchievements: existingAchievements,
                progress: { progress in
                    await MainActor.run {
                        scanProgress = progress
                    }
                }
            )
            autoMatchCandidates = candidates
            cachedAutoMatchCandidates[pageIndex] = candidates
            stickerStore.updatePendingAutoMatchCandidates(pageIndex: pageIndex, records: candidates.map(\.record))
            stickerStore.updateScanState(pageIndex: pageIndex, resultCount: candidates.count)
            if candidates.isEmpty {
                showAutoMatchProgress = false
                scanMessage = "这一页没有找到适合生成贴纸的宝宝照片。"
            } else {
                presentAutoMatchReview()
            }
        } catch is CancellationError {
            return
        } catch {
            showAutoMatchProgress = false
            scanMessage = error.localizedDescription
        }
    }

    @MainActor
    private func presentAutoMatchReview() {
        showAutoMatchProgress = false
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(320))
            guard !Task.isCancelled else { return }
            showAutoMatchReview = true
        }
    }
}

private struct MilestoneScanProgress: Equatable, Sendable {
    let processedDays: Int
    let totalDays: Int
    let matchedCount: Int
    let startedAt: Date
    let isRestoring: Bool

    static let idle = MilestoneScanProgress(
        processedDays: 0,
        totalDays: 30,
        matchedCount: 0,
        startedAt: Date(),
        isRestoring: false
    )

    static var started: MilestoneScanProgress {
        MilestoneScanProgress(
            processedDays: 0,
            totalDays: 30,
            matchedCount: 0,
            startedAt: Date(),
            isRestoring: false
        )
    }

    static var restoring: MilestoneScanProgress {
        MilestoneScanProgress(
            processedDays: 0,
            totalDays: 0,
            matchedCount: 0,
            startedAt: Date(),
            isRestoring: true
        )
    }

    var fraction: Double {
        guard totalDays > 0 else { return 0 }
        return min(max(Double(processedDays) / Double(totalDays), 0), 1)
    }

    var estimatedRemainingText: String {
        guard processedDays > 0, processedDays < totalDays else {
            return processedDays >= totalDays && totalDays > 0 ? "即将完成" : "正在准备本地照片索引"
        }
        let elapsed = Date().timeIntervalSince(startedAt)
        let perDay = elapsed / Double(processedDays)
        let remaining = max(Int((perDay * Double(totalDays - processedDays)).rounded()), 1)
        return "预计还需约 \(remaining) 秒"
    }
}

private struct MilestoneAutoMatchIntroView: View {
    @Environment(\.dismiss) private var dismiss
    let pageIndex: Int
    let dateRangeText: String
    let onStart: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 22) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundStyle(theme.primary)
                    .frame(width: 54, height: 54)
                    .background(Circle().fill(theme.soft))

                VStack(alignment: .leading, spacing: 8) {
                    Text("自动匹配 \(pageIndex) 月龄照片")
                        .font(BBBFont.font(size: 22, weight: .heavy))
                        .foregroundStyle(DesignToken.textPrimary)
                    Text(dateRangeText)
                        .font(BBBFont.font(size: 13, weight: .bold))
                        .foregroundStyle(DesignToken.textSecondary)
                }

                VStack(alignment: .leading, spacing: 14) {
                    introLine(
                        icon: "iphone.and.arrow.forward",
                        title: "仅在这台 iPhone 上处理",
                        detail: "照片不会上传，也不会离开你的设备。"
                    )
                    introLine(
                        icon: "person.crop.rectangle.stack",
                        title: "寻找更像宝宝的照片",
                        detail: "按日期、清晰度、人脸位置和画面质量筛选。"
                    )
                    introLine(
                        icon: "checkmark.circle",
                        title: "保存前由你确认",
                        detail: "低于匹配阈值的照片不会进入结果。"
                    )
                }

                Spacer(minLength: 4)

                HStack(spacing: 12) {
                    Button("取消") { dismiss() }
                        .buttonStyle(MilestoneSheetSecondaryButtonStyle())
                    Button("开始匹配") { onStart() }
                        .buttonStyle(MilestoneSheetPrimaryButtonStyle(color: theme.primary))
                }
            }
            .padding(22)
            .background(HomeSoftBackground().ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var theme: MilestoneUnitTheme {
        MilestoneUnitTheme.theme(for: pageIndex)
    }

    private func introLine(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(theme.primary)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(title.localized)
                    .font(BBBFont.font(size: 14, weight: .heavy))
                    .foregroundStyle(DesignToken.textPrimary)
                Text(detail.localized)
                    .font(BBBFont.font(size: 12, weight: .medium))
                    .foregroundStyle(DesignToken.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct MilestoneAutoMatchProgressView: View {
    let pageIndex: Int
    let progress: MilestoneScanProgress
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 28)

            ZStack {
                Circle()
                    .fill(theme.soft)
                    .frame(width: 90, height: 90)
                Image(systemName: progress.isRestoring ? "photo.stack.fill" : "wand.and.stars")
                    .font(.system(size: 34, weight: .heavy))
                    .foregroundStyle(theme.primary)
                    .symbolEffect(.pulse, options: .repeating, isActive: true)
            }

            VStack(spacing: 8) {
                Text(progress.isRestoring ? "正在重新打开匹配结果" : "扫描中，值得等待一下")
                    .font(BBBFont.font(size: 20, weight: .heavy))
                    .foregroundStyle(DesignToken.textPrimary)

                Text(progress.matchedCount > 0 ? "已匹配 \(progress.matchedCount) 张宝宝照片" : "正在检查 \(pageIndex) 月龄的照片")
                    .font(BBBFont.font(size: 13, weight: .bold))
                    .foregroundStyle(DesignToken.textSecondary)
            }

            if progress.totalDays > 0 {
                VStack(spacing: 9) {
                    ProgressView(value: progress.fraction)
                        .tint(theme.primary)
                    HStack {
                        Text("\(progress.processedDays)/\(progress.totalDays) 天")
                        Spacer()
                        Text(progress.estimatedRemainingText)
                    }
                    .font(BBBFont.font(size: 11, weight: .bold))
                    .foregroundStyle(DesignToken.textSecondary)
                }
                .padding(.horizontal, 28)
            } else {
                ProgressView()
                    .controlSize(.large)
                    .tint(theme.primary)
            }

            Spacer()

            Button("取消匹配", action: onCancel)
                .font(BBBFont.font(size: 14, weight: .heavy))
                .foregroundStyle(DesignToken.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(DesignToken.surfaceRaised.opacity(0.82)))
                .padding(.horizontal, 22)
                .padding(.bottom, 18)
        }
        .background(HomeSoftBackground().ignoresSafeArea())
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
    }

    private var theme: MilestoneUnitTheme {
        MilestoneUnitTheme.theme(for: pageIndex)
    }
}

private struct MilestoneSheetPrimaryButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(BBBFont.font(size: 14, weight: .heavy))
            .foregroundStyle(DesignToken.onPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(color.opacity(configuration.isPressed ? 0.78 : 1)))
    }
}

private struct MilestoneSheetSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(BBBFont.font(size: 14, weight: .heavy))
            .foregroundStyle(DesignToken.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(DesignToken.surfaceRaised.opacity(configuration.isPressed ? 0.64 : 0.86)))
    }
}

private struct MilestoneScrollMetrics: Equatable {
    let offset: CGFloat
    let viewportHeight: CGFloat
}

private struct MilestonePathMediaPayload: Hashable, Sendable {
    let achievementID: UUID
    let mediaKind: AchievementMediaKind
    let originalURL: URL?
    let stickerURL: URL?
}

private struct PreparedMilestonePathMedia: @unchecked Sendable {
    let original: UIImage?
    let sticker: UIImage?
}

private struct MilestonePathRow<Node: View>: View {
    let index: Int
    let width: CGFloat
    let height: CGFloat
    let nodeOuterSize: CGFloat
    let showsConnector: Bool
    @ViewBuilder let node: () -> Node

    var body: some View {
        ZStack(alignment: .topLeading) {
            if showsConnector {
                connector
                    .allowsHitTesting(false)
            }

            node()
                .position(x: nodeX(for: index), y: height * 0.5)
        }
        .frame(width: width, height: height, alignment: .topLeading)
    }

    private var connector: some View {
        Canvas { context, size in
            let startNodeX = nodeX(for: index)
            let endNodeX = nodeX(for: index + 1)
            let startDirection: CGFloat = index.isMultiple(of: 2) ? 1 : -1
            let endDirection: CGFloat = (index + 1).isMultiple(of: 2) ? 1 : -1
            let edgeInset = nodeOuterSize * 0.40
            let start = CGPoint(
                x: startNodeX + startDirection * edgeInset,
                y: height * 0.5 + 34
            )
            let end = CGPoint(
                x: endNodeX + endDirection * edgeInset,
                y: height * 1.5 - 36
            )
            let horizontal = end.x - start.x
            let vertical = end.y - start.y
            var path = Path()
            path.move(to: start)
            path.addCurve(
                to: end,
                control1: CGPoint(
                    x: start.x + horizontal * 0.24,
                    y: start.y + vertical * 0.18
                ),
                control2: CGPoint(
                    x: end.x - horizontal * 0.24,
                    y: end.y - vertical * 0.18
                )
            )
            context.stroke(
                path,
                with: .color(DesignToken.borderSubtle.opacity(0.68)),
                style: StrokeStyle(
                    lineWidth: 2.2,
                    lineCap: .round,
                    lineJoin: .round,
                    dash: [1.6, 9.2]
                )
            )
        }
        .frame(width: width, height: height * 2, alignment: .top)
    }

    private func nodeX(for itemIndex: Int) -> CGFloat {
        let center = width * 0.5
        let laneOffset = min(width * 0.23, 96)
        return center + (itemIndex.isMultiple(of: 2) ? -laneOffset : laneOffset)
    }
}

private struct MilestonePathMediaView: View {
    let payload: MilestonePathMediaPayload
    @State private var prepared: PreparedMilestonePathMedia?

    var body: some View {
        AchievementLayeredMediaView(
            foregroundImage: payload.mediaKind == .photo ? prepared?.original : prepared?.sticker,
            backgroundImage: payload.mediaKind == .sticker ? prepared?.original : nil,
            mediaKind: payload.mediaKind
        )
        .task(id: payload) {
            let currentPayload = payload
            let loaded = await Task.detached(priority: .userInitiated) {
                PreparedMilestonePathMedia(
                    original: currentPayload.originalURL.flatMap {
                        downsampledAchievementImage(at: $0, maxPixelSize: 320)
                    },
                    sticker: currentPayload.stickerURL.flatMap {
                        downsampledAchievementImage(at: $0, maxPixelSize: 320)
                    }
                )
            }.value
            guard !Task.isCancelled else { return }
            prepared = loaded
        }
    }
}

private func downsampledAchievementImage(at url: URL, maxPixelSize: CGFloat) -> UIImage? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    let options: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        kCGImageSourceShouldCacheImmediately: true
    ]
    guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
        return nil
    }
    return UIImage(cgImage: image)
}

private struct AchievementSoftPalette: Sendable {
    let hue: CGFloat
    let saturation: CGFloat
    let lightness: CGFloat

    static let fallback = AchievementSoftPalette(
        hue: 0.69,
        saturation: 0.12,
        lightness: 0.68
    )

    var backgroundColors: [Color] {
        [
            color(saturationScale: 0.88, lightnessOffset: 0.07),
            color(saturationScale: 1, lightnessOffset: 0),
            color(saturationScale: 0.72, lightnessOffset: 0.11)
        ]
    }

    private func color(saturationScale: CGFloat, lightnessOffset: CGFloat) -> Color {
        let rgb = Self.hslToRGB(
            hue: hue,
            saturation: min(max(saturation * saturationScale, 0), 1),
            lightness: min(max(lightness + lightnessOffset, 0), 1)
        )
        return Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
    }

    private static func hslToRGB(
        hue: CGFloat,
        saturation: CGFloat,
        lightness: CGFloat
    ) -> (red: CGFloat, green: CGFloat, blue: CGFloat) {
        guard saturation > 0.001 else {
            return (lightness, lightness, lightness)
        }

        let chroma = (1 - abs(2 * lightness - 1)) * saturation
        let segment = (hue * 6).truncatingRemainder(dividingBy: 6)
        let secondary = chroma * (1 - abs(segment.truncatingRemainder(dividingBy: 2) - 1))
        let base: (CGFloat, CGFloat, CGFloat)

        switch segment {
        case 0..<1: base = (chroma, secondary, 0)
        case 1..<2: base = (secondary, chroma, 0)
        case 2..<3: base = (0, chroma, secondary)
        case 3..<4: base = (0, secondary, chroma)
        case 4..<5: base = (secondary, 0, chroma)
        default: base = (chroma, 0, secondary)
        }

        let match = lightness - chroma / 2
        return (base.0 + match, base.1 + match, base.2 + match)
    }
}

private final class AchievementSoftPaletteBox {
    let value: AchievementSoftPalette

    init(_ value: AchievementSoftPalette) {
        self.value = value
    }
}

private enum AchievementSoftPaletteExtractor {
    private struct Bucket {
        var weight: CGFloat = 0
        var hueX: CGFloat = 0
        var hueY: CGFloat = 0
        var saturation: CGFloat = 0
        var lightness: CGFloat = 0
    }

    private static let cache = NSCache<UIImage, AchievementSoftPaletteBox>()

    static func palette(for image: UIImage) -> AchievementSoftPalette {
        if let cached = cache.object(forKey: image) {
            return cached.value
        }

        let palette = extractPalette(from: image)
        cache.setObject(AchievementSoftPaletteBox(palette), forKey: image)
        return palette
    }

    private static func extractPalette(from image: UIImage) -> AchievementSoftPalette {
        guard let cgImage = image.cgImage else { return .fallback }

        let width = 30
        let height = 30
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
            | CGBitmapInfo.byteOrder32Big.rawValue

        let drewImage = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            ) else { return false }
            context.interpolationQuality = .low
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drewImage else { return .fallback }

        var buckets: [Int: Bucket] = [:]
        for index in stride(from: 0, to: pixels.count, by: 4) {
            let alpha = CGFloat(pixels[index + 3]) / 255
            guard alpha > 0.24 else { continue }

            let red = CGFloat(pixels[index]) / 255
            let green = CGFloat(pixels[index + 1]) / 255
            let blue = CGFloat(pixels[index + 2]) / 255
            let hsl = rgbToHSL(red: red, green: green, blue: blue)

            guard hsl.lightness > 0.08,
                  !(hsl.lightness > 0.92 && hsl.saturation < 0.12) else {
                continue
            }

            let hueBin = min(Int(hsl.hue * 24), 23)
            let saturationBin = min(Int(hsl.saturation * 4), 3)
            let lightnessBin = min(Int(hsl.lightness * 3), 2)
            let key = hueBin * 12 + saturationBin * 3 + lightnessBin

            var pixelWeight = alpha * (0.38 + hsl.saturation * 0.9)
            let isLikelySkinTone = (hsl.hue < 0.12 || hsl.hue > 0.97)
                && hsl.saturation > 0.14
                && hsl.lightness > 0.24
            if isLikelySkinTone {
                pixelWeight *= 0.72
            }

            var bucket = buckets[key, default: Bucket()]
            bucket.weight += pixelWeight
            bucket.hueX += cos(hsl.hue * 2 * .pi) * pixelWeight
            bucket.hueY += sin(hsl.hue * 2 * .pi) * pixelWeight
            bucket.saturation += hsl.saturation * pixelWeight
            bucket.lightness += hsl.lightness * pixelWeight
            buckets[key] = bucket
        }

        guard let dominant = buckets.values.max(by: { $0.weight < $1.weight }),
              dominant.weight > 0 else {
            return .fallback
        }

        var hue = atan2(dominant.hueY, dominant.hueX) / (2 * .pi)
        if hue < 0 { hue += 1 }
        let sourceSaturation = dominant.saturation / dominant.weight
        let sourceLightness = dominant.lightness / dominant.weight
        var saturation = min(max(sourceSaturation * 0.58, 0.12), 0.42)
        var lightness = min(max(0.61 + (sourceLightness - 0.5) * 0.2, 0.52), 0.72)

        if hue < 0.12 || hue > 0.97 {
            saturation = min(saturation, 0.24)
            lightness = max(lightness, 0.64)
        }

        return AchievementSoftPalette(
            hue: hue,
            saturation: saturation,
            lightness: lightness
        )
    }

    private static func rgbToHSL(
        red: CGFloat,
        green: CGFloat,
        blue: CGFloat
    ) -> (hue: CGFloat, saturation: CGFloat, lightness: CGFloat) {
        let maximum = max(red, green, blue)
        let minimum = min(red, green, blue)
        let delta = maximum - minimum
        let lightness = (maximum + minimum) / 2
        guard delta > 0.001 else { return (0, 0, lightness) }

        let saturation = delta / (1 - abs(2 * lightness - 1))
        let hue: CGFloat
        if maximum == red {
            hue = ((green - blue) / delta).truncatingRemainder(dividingBy: 6) / 6
        } else if maximum == green {
            hue = (((blue - red) / delta) + 2) / 6
        } else {
            hue = (((red - green) / delta) + 4) / 6
        }
        return (hue < 0 ? hue + 1 : hue, saturation, lightness)
    }
}

private struct AchievementLayeredMediaView: View {
    let foregroundImage: UIImage?
    let backgroundImage: UIImage?
    let mediaKind: AchievementMediaKind
    var precomputedPalette: AchievementSoftPalette? = nil
    @State private var rebuiltLegacyForeground: UIImage?
    @State private var softPalette = AchievementSoftPalette.fallback

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if mediaKind == .sticker {
                    LinearGradient(
                        colors: displayedPalette.backgroundColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }

                if let displayedForeground {
                    Image(uiImage: displayedForeground)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                }
            }
        }
        .task(id: foregroundImage.map { ObjectIdentifier($0) }) {
            rebuiltLegacyForeground = nil
            guard mediaKind == .sticker,
                  let foregroundImage,
                  !foregroundImage.hasMeaningfulTransparency,
                  let backgroundImage else {
                return
            }
            rebuiltLegacyForeground = await Task.detached(priority: .utility) {
                StickerGenerator.generateCompositeSticker(from: backgroundImage, quality: .preview)
            }.value
        }
        .task(id: paletteSourceImage.map { ObjectIdentifier($0) }) {
            guard precomputedPalette == nil else { return }
            guard mediaKind == .sticker, let paletteSourceImage else {
                softPalette = .fallback
                return
            }
            let palette = await Task.detached(priority: .utility) {
                AchievementSoftPaletteExtractor.palette(for: paletteSourceImage)
            }.value
            guard !Task.isCancelled else { return }
            softPalette = palette
        }
        .transaction { transaction in
            transaction.animation = nil
        }
    }

    private var displayedForeground: UIImage? {
        guard mediaKind == .sticker else { return foregroundImage }
        guard let foregroundImage else { return nil }
        if foregroundImage.hasMeaningfulTransparency {
            return foregroundImage
        }
        return rebuiltLegacyForeground
    }

    private var displayedPalette: AchievementSoftPalette {
        precomputedPalette ?? softPalette
    }

    private var paletteSourceImage: UIImage? {
        backgroundImage ?? foregroundImage
    }
}

private struct MilestonePathNode: View {
    let day: MilestoneDay
    let isToday: Bool
    let isLocked: Bool
    let achievement: CustomAchievement?
    let achievementCount: Int
    let milestone: MilestoneDefinition?
    let mediaPayload: MilestonePathMediaPayload?
    let action: () -> Void

    // Instax SQUARE proportions: 72 x 86 mm paper with a 62 x 62 mm image area.
    private let paperWidth: CGFloat = 146
    private let paperHeight: CGFloat = 174.4
    private let photoSize: CGFloat = 125.7
    private let paperTopInset: CGFloat = 10.1
    private let paperCornerRadius: CGFloat = 4
    private let photoCornerRadius: CGFloat = 1.5
    var body: some View {
        ZStack(alignment: .top) {
            if achievementCount > 1 {
                stackedPaper(offset: CGSize(width: -7, height: -5), rotation: -3.2)
                stackedPaper(offset: CGSize(width: 7, height: -2), rotation: 2.5)
            }

            buttonFace

            if isToday {
                ThemePushpin(size: 28)
                    .offset(y: -25)
                    .transition(.scale.combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .frame(width: paperWidth, height: paperHeight)
        .contentShape(RoundedRectangle(cornerRadius: paperCornerRadius, style: .continuous))
        .onTapGesture {
            guard !isLocked else { return }
            action()
        }
        .accessibilityAddTraits(isLocked ? [] : .isButton)
        .accessibilityAction {
            guard !isLocked else { return }
            action()
        }
        .allowsHitTesting(!isLocked)
        .frame(width: 178, height: 196)
        .animation(.snappy(duration: 0.22), value: isToday)
    }

    private func stackedPaper(offset: CGSize, rotation: Double) -> some View {
        RoundedRectangle(cornerRadius: paperCornerRadius, style: .continuous)
            .fill(DesignToken.surfaceRaised)
            .overlay(
                RoundedRectangle(cornerRadius: paperCornerRadius, style: .continuous)
                    .stroke(DesignToken.borderSubtle, lineWidth: 0.65)
            )
            .frame(width: paperWidth, height: paperHeight)
            .rotationEffect(.degrees(rotation))
            .offset(offset)
            .shadow(color: DesignToken.shadowColor.opacity(0.06), radius: 2, x: 1, y: 2)
            .allowsHitTesting(false)
    }

    private var buttonFace: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                photoArea
                    .frame(width: photoSize, height: photoSize)
                    .clipShape(RoundedRectangle(cornerRadius: photoCornerRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: photoCornerRadius, style: .continuous)
                            .stroke(DesignToken.shadowColor.opacity(isLocked ? 0.025 : 0.055), lineWidth: 0.8)
                    )
                    .shadow(color: DesignToken.shadowColor.opacity(isLocked ? 0.02 : 0.06), radius: 2, y: 1)
                    .padding(.top, paperTopInset)

                Spacer(minLength: 0)

                if let labelText {
                    Text(labelText)
                        .font(BBBFont.font(size: labelFontSize, weight: .heavy))
                        .foregroundStyle(labelColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.54)
                        .padding(.horizontal, 9)
                        .frame(maxWidth: paperWidth - 12)
                        .frame(height: 24)
                        .padding(.bottom, 6)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: paperWidth, height: paperHeight)

            if milestone != nil && achievement == nil && !isLocked {
                Image(systemName: "star.fill")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(DesignToken.onPrimary)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(DesignToken.reward))
                    .offset(x: -6, y: 6)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: paperWidth, height: paperHeight)
        .background(
            RoundedRectangle(cornerRadius: paperCornerRadius, style: .continuous)
                .fill(paperFill)
                .overlay(
                    LinearGradient(
                        colors: [DesignToken.surfaceRaised.opacity(0.24), DesignToken.surfaceSoft.opacity(0.10)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: paperCornerRadius, style: .continuous))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: paperCornerRadius, style: .continuous)
                        .stroke(strokeColor, lineWidth: strokeWidth)
                )
        )
        .shadow(color: DesignToken.shadowColor.opacity(isLocked ? 0.025 : 0.09), radius: 2, x: 0.8, y: 2)
        .shadow(color: DesignToken.shadowColor.opacity(isLocked ? 0.04 : 0.11), radius: 11, y: 7)
    }

    private var photoArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: photoCornerRadius, style: .continuous)
                .fill(photoFill)

            nodeContent
        }
    }

    @ViewBuilder
    private var nodeContent: some View {
        if let mediaPayload {
            MilestonePathMediaView(payload: mediaPayload)
                .frame(width: photoSize, height: photoSize)
                .clipped()
        } else if isLocked {
            Image(systemName: "lock.fill")
                .font(.system(size: 28, weight: .heavy))
                .foregroundStyle(DesignToken.textFaint)
        } else {
            Image(systemName: "camera.fill")
                .font(.system(size: 27, weight: .heavy))
                .foregroundStyle(DesignToken.textFaint)
        }
    }

    private var labelText: String? {
        if let achievement {
            return achievement.name
        }
        if let milestone {
            return milestone.title
        }
        return "\(nodeMonthDayText)（\(day.dayOffset)天）"
    }

    private var labelFontSize: CGFloat {
        milestone == nil ? 9.5 : 11
    }

    private var nodeMonthDayText: String {
        AppDateTimeFormat.date(day.date)
    }

    private var paperFill: Color {
        if isLocked { return DesignToken.surfaceSoft }
        return DesignToken.surfaceRaised
    }

    private var photoFill: AnyShapeStyle {
        if isLocked || mediaPayload == nil {
            return AnyShapeStyle(DesignToken.surfaceSoft)
        }
        return AnyShapeStyle(
            LinearGradient(
                colors: photoGradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var photoGradientColors: [Color] {
        if achievement != nil {
            return [DesignToken.surfaceRaised, DesignToken.surfaceSoft]
        }
        if milestone != nil {
            return [DesignToken.easyActivity, DesignToken.primary]
        }
        return [DesignToken.primary, DesignToken.primary.opacity(0.62)]
    }

    private var labelColor: Color {
        if isLocked { return DesignToken.textFaint }
        if milestone != nil { return DesignToken.easyActivityText }
        return DesignToken.textPrimary
    }

    private var strokeColor: Color {
        if achievement != nil { return DesignToken.borderSubtle }
        if isLocked { return DesignToken.borderSubtle.opacity(0.72) }
        return DesignToken.rewardSoft
    }

    private var strokeWidth: CGFloat {
        return 0.8
    }
}

private struct ThemePushpin: View {
    let size: CGFloat

    var body: some View {
        Text("📌")
            .font(.system(size: size))
            .frame(width: size * 1.2, height: size * 1.2)
            .accessibilityHidden(true)
    }
}

private struct MilestoneDayAchievementsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var stickerStore: AchievementStickerStore

    let group: MilestoneDayAchievementGroup
    @State private var selectedAchievementID: UUID?
    @State private var detailAchievement: CustomAchievement?
    @State private var errorMessage: String?
    @State private var preparedMedia: [UUID: MilestoneDayPreparedMedia] = [:]
    @State private var transitionOffset: CGFloat = 0
    @State private var transitionScale: CGFloat = 1
    @State private var transitionOpacity: CGFloat = 1
    @State private var isTransitioning = false
    @State private var transitionTargetID: UUID?
    @GestureState private var dragTranslation: CGFloat = 0

    init(group: MilestoneDayAchievementGroup) {
        self.group = group
        _selectedAchievementID = State(
            initialValue: group.initialAchievementID ?? group.achievementIDs.first
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                achievementSoftBackground
                    .ignoresSafeArea()

                GeometryReader { proxy in
                    if achievements.isEmpty {
                        ProgressView()
                            .tint(DesignToken.primary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        dayCardViewer(
                            availableWidth: proxy.size.width,
                            availableHeight: proxy.size.height
                        )
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        achievementCircleButtonIcon("chevron.left")
                    }
                    .accessibilityLabel("返回")
                }

                ToolbarItem(placement: .principal) {
                    Text(dayTitle)
                        .font(BBBFont.font(size: 17, weight: .heavy))
                        .foregroundStyle(DesignToken.textPrimary)
                        .contentTransition(.numericText(value: Double(selectedIndex + 1)))
                        .animation(.easeOut(duration: 0.2), value: selectedIndex)
                }
            }
            .sheet(item: $detailAchievement, onDismiss: {
                Task {
                    await prepareAchievementMedia()
                }
            }) { achievement in
                AchievementDetailView(achievement: achievement) {
                    detailAchievement = nil
                }
                .environmentObject(stickerStore)
            }
            .alert("无法设置封面", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("好", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "请重试。")
            }
            .onChange(of: achievementIDs) { _, ids in
                guard !ids.isEmpty else {
                    dismiss()
                    return
                }

                if selectedAchievementID.map({ ids.contains($0) }) != true {
                    selectedAchievementID = coverAchievement?.id ?? ids.first
                }
            }
            .task(id: mediaSignature) {
                await prepareAchievementMedia()
            }
        }
    }

    private var achievements: [CustomAchievement] {
        group.achievementIDs.compactMap { id in
            stickerStore.achievements.first(where: { $0.id == id })
        }
    }

    private var achievementIDs: [UUID] {
        achievements.map(\.id)
    }

    private var coverAchievement: CustomAchievement? {
        stickerStore.coverAchievement(onDayOffset: group.day.dayOffset)
    }

    private var selectedIndex: Int {
        guard let selectedAchievementID,
              let index = achievements.firstIndex(where: { $0.id == selectedAchievementID }) else {
            return 0
        }
        return index
    }

    private var selectedAchievement: CustomAchievement? {
        guard achievements.indices.contains(selectedIndex) else { return nil }
        return achievements[selectedIndex]
    }

    private var mediaSignature: String {
        achievements.map {
            [
                $0.id.uuidString,
                $0.originalFilename ?? "",
                $0.stickerFilename ?? "",
                $0.livePhotoStillFilename ?? "",
                $0.livePhotoMovieFilename ?? ""
            ].joined(separator: ":")
        }
        .joined(separator: "|")
    }

    @ViewBuilder
    private func dayCardViewer(
        availableWidth: CGFloat,
        availableHeight: CGFloat
    ) -> some View {
        if let selectedAchievement {
            let cardWidth = min(max(availableWidth - 68, 268), 312)
            let cardHeight = cardWidth * 86 / 72

            VStack(spacing: 0) {
                Spacer(minLength: 12)

                cardStage(
                    selectedAchievement,
                    cardWidth: cardWidth,
                    cardHeight: cardHeight,
                    availableWidth: availableWidth
                )
                .frame(height: cardHeight + 36)

                Spacer(minLength: 14)

                viewerFooter(for: selectedAchievement)
                    .padding(.bottom, max(22, min(42, availableHeight * 0.045)))
            }
            .padding(.horizontal, 20)
        }
    }

    private func cardStage(
        _ achievement: CustomAchievement,
        cardWidth: CGFloat,
        cardHeight: CGFloat,
        availableWidth: CGFloat
    ) -> some View {
        ZStack {
            ForEach(Array(backgroundCardAchievements.prefix(2).enumerated()).reversed(), id: \.element.id) { depth, item in
                achievementCard(item, width: cardWidth)
                    .scaleEffect(1 - CGFloat(depth + 1) * 0.025)
                    .rotationEffect(.degrees(depth == 0 ? 2.4 : -2.4))
                    .offset(
                        x: depth == 0 ? 7 : -7,
                        y: CGFloat(depth + 1) * -6
                    )
                    .opacity(0.94)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }

            ZStack(alignment: .top) {
                achievementCard(achievement, width: cardWidth)

                if isCover(achievement) {
                    ThemePushpin(size: 30)
                        .offset(y: -22)
                        .accessibilityLabel("当前成长页封面")
                }
            }
            .offset(x: transitionOffset + dragTranslation)
            .rotationEffect(.degrees(Double(transitionOffset + dragTranslation) / Double(max(cardWidth, 1)) * 5.5))
            .scaleEffect(transitionScale - min(abs(dragTranslation) / max(cardWidth, 1), 1) * 0.035)
            .opacity(transitionOpacity)
            .zIndex(3)
            .simultaneousGesture(cardSwipeGesture(cardWidth: cardWidth))

            if achievements.count > 1 {
                cardNavigationButton(systemName: "chevron.left", isEnabled: canTransition(by: -1)) {
                    transitionCard(by: -1, cardWidth: cardWidth)
                }
                .offset(x: -min(availableWidth * 0.43, cardWidth * 0.62))

                cardNavigationButton(systemName: "chevron.right", isEnabled: canTransition(by: 1)) {
                    transitionCard(by: 1, cardWidth: cardWidth)
                }
                .offset(x: min(availableWidth * 0.43, cardWidth * 0.62))
            }
        }
        .frame(maxWidth: .infinity, minHeight: cardHeight + 36)
    }

    private func achievementCard(_ achievement: CustomAchievement, width: CGFloat) -> some View {
        let media = preparedMedia[achievement.id]
        return AchievementInstaxCard(
            image: achievement.resolvedMediaKind == .photo ? media?.original : media?.sticker,
            backgroundImage: achievement.resolvedMediaKind == .sticker ? media?.original : nil,
            mediaKind: achievement.resolvedMediaKind,
            title: achievement.name,
            subtitle: compactDateText(achievement.completedAt),
            width: width,
            livePhotoResources: media?.livePhotoResources,
            precomputedPalette: media?.softPalette
        )
    }

    private var backgroundCardAchievements: [CustomAchievement] {
        guard achievements.count > 1 else { return [] }

        let neighboringIndexes = [
            wrappedIndex(selectedIndex + 1),
            wrappedIndex(selectedIndex - 1)
        ]
        let uniqueIndexes = neighboringIndexes.reduce(into: [Int]()) { indexes, index in
            if !indexes.contains(index) {
                indexes.append(index)
            }
        }
        return uniqueIndexes
            .compactMap { achievements.indices.contains($0) ? achievements[$0] : nil }
            // The entering card must not also remain in the stack. Rendering it
            // twice with different transforms causes the paper and photo to flash.
            .filter { $0.id != transitionTargetID }
    }

    private func cardNavigationButton(
        systemName: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(DesignToken.textSecondary.opacity(isEnabled ? 0.7 : 0))
                .frame(width: 44, height: 64)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isTransitioning)
        .accessibilityLabel(systemName == "chevron.left" ? "上一张" : "下一张")
    }

    private func cardSwipeGesture(cardWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .local)
            .updating($dragTranslation) { value, state, _ in
                guard !isTransitioning else { return }
                state = value.translation.width
            }
            .onEnded { value in
                guard !isTransitioning else { return }
                let projected = value.predictedEndTranslation.width
                let movement = abs(projected) > abs(value.translation.width)
                    ? projected
                    : value.translation.width
                let delta = movement < 0 ? 1 : -1
                let canMove = achievements.count > 1
                let shouldMove = abs(value.translation.width) > 66 || abs(projected) > 118

                guard shouldMove, canMove, canTransition(by: delta) else {
                    transitionOffset = value.translation.width
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
                        transitionOffset = 0
                    }
                    return
                }

                transitionOffset = value.translation.width
                transitionCard(by: delta, cardWidth: cardWidth)
            }
    }

    private func transitionCard(by delta: Int, cardWidth: CGFloat) {
        guard canTransition(by: delta) else { return }
        let targetIndex = wrappedIndex(selectedIndex + delta)
        let targetID = achievements[targetIndex].id
        var setupTransaction = Transaction()
        setupTransaction.disablesAnimations = true
        withTransaction(setupTransaction) {
            transitionTargetID = targetID
        }
        isTransitioning = true
        let exitDirection: CGFloat = delta > 0 ? -1 : 1

        if abs(transitionOffset) < 1 {
            transitionOffset = exitDirection * 8
        }
        withAnimation(.easeIn(duration: 0.14)) {
            transitionOffset = exitDirection * (cardWidth + 110)
            transitionScale = 0.97
            transitionOpacity = 0.58
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 145_000_000)
            var resetTransaction = Transaction()
            resetTransaction.disablesAnimations = true
            withTransaction(resetTransaction) {
                selectedAchievementID = targetID
                transitionOffset = -exitDirection * min(cardWidth * 0.2, 58)
                transitionScale = 0.97
                transitionOpacity = 1
            }

            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                transitionOffset = 0
                transitionScale = 1
                transitionOpacity = 1
            }
            try? await Task.sleep(nanoseconds: 430_000_000)
            var finishTransaction = Transaction()
            finishTransaction.disablesAnimations = true
            withTransaction(finishTransaction) {
                transitionTargetID = nil
                isTransitioning = false
            }
        }
    }

    private func wrappedIndex(_ index: Int) -> Int {
        guard !achievements.isEmpty else { return 0 }
        let count = achievements.count
        return (index % count + count) % count
    }

    private func canTransition(by delta: Int) -> Bool {
        guard achievements.count > 1, !isTransitioning else { return false }
        let targetIndex = wrappedIndex(selectedIndex + delta)
        guard achievements.indices.contains(targetIndex) else { return false }
        return preparedMedia[achievements[targetIndex].id] != nil
    }

    private func viewerFooter(for achievement: CustomAchievement) -> some View {
        VStack(spacing: 16) {
            Text(achievement.description.localized)
                .font(BBBFont.font(size: 14, weight: .medium))
                .foregroundStyle(DesignToken.textSecondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity)

            HStack(spacing: 14) {
                Button {
                    setAsCover(achievement)
                } label: {
                    Image(systemName: isCover(achievement) ? "pin.fill" : "pin")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(isCover(achievement) ? DesignToken.onPrimary : DesignToken.textPrimary)
                        .frame(width: 46, height: 46)
                        .background(
                            isCover(achievement)
                                ? MilestoneUnitTheme.theme(for: group.day.pageIndex).primary
                                : DesignToken.surfaceRaised.opacity(0.84),
                            in: Circle()
                        )
                        .overlay(Circle().stroke(DesignToken.borderSubtle, lineWidth: isCover(achievement) ? 0 : 1))
                }
                .buttonStyle(.plain)
                .disabled(isCover(achievement))
                .accessibilityLabel(isCover(achievement) ? "当前成长页封面" : "设为成长页封面")

                Button {
                    detailAchievement = achievement
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(DesignToken.textPrimary)
                        .frame(width: 46, height: 46)
                        .background(DesignToken.surfaceRaised.opacity(0.84), in: Circle())
                        .overlay(Circle().stroke(DesignToken.borderSubtle, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("编辑这张照片")
            }
        }
    }

    private func prepareAchievementMedia() async {
        let requests = achievements.map { achievement in
            MilestoneDayMediaRequest(
                id: achievement.id,
                originalURL: achievement.originalFilename.map(stickerStore.imageURL(for:)),
                stickerURL: achievement.stickerFilename.map(stickerStore.imageURL(for:)),
                livePhotoResources: achievementLivePhotoResources(for: achievement, store: stickerStore)
            )
        }
        let loaded = await Task.detached(priority: .userInitiated) {
            Dictionary(uniqueKeysWithValues: requests.map { request in
                let original = request.originalURL.flatMap {
                        downsampledAchievementImage(at: $0, maxPixelSize: 1200)
                    }
                let sticker = request.stickerURL.flatMap {
                        downsampledAchievementImage(at: $0, maxPixelSize: 1200)
                    }
                let renderedSticker: UIImage?
                if let sticker, sticker.hasMeaningfulTransparency {
                    renderedSticker = sticker
                } else if let original {
                    renderedSticker = StickerGenerator.generateCompositeSticker(from: original, quality: .preview)
                } else {
                    renderedSticker = nil
                }
                let media = MilestoneDayPreparedMedia(
                    original: original,
                    sticker: renderedSticker,
                    softPalette: original.map(AchievementSoftPaletteExtractor.palette(for:)),
                    livePhotoResources: request.livePhotoResources
                )
                return (request.id, media)
            })
        }.value
        guard !Task.isCancelled else { return }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            preparedMedia = loaded
        }
    }

    private func isCover(_ achievement: CustomAchievement) -> Bool {
        coverAchievement?.id == achievement.id
    }

    private func setAsCover(_ achievement: CustomAchievement) {
        do {
            try stickerStore.setDayCover(achievement)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var dayTitle: String {
        "\(AppDateTimeFormat.date(group.day.date))  \(min(selectedIndex + 1, achievements.count))/\(achievements.count)张"
    }

    private func compactDateText(_ date: Date) -> String {
        AppDateTimeFormat.date(date)
    }
}

private struct MilestoneDayMediaRequest: @unchecked Sendable {
    let id: UUID
    let originalURL: URL?
    let stickerURL: URL?
    let livePhotoResources: AchievementLivePhotoResources?
}

private struct MilestoneDayPreparedMedia: @unchecked Sendable {
    let original: UIImage?
    let sticker: UIImage?
    let softPalette: AchievementSoftPalette?
    let livePhotoResources: AchievementLivePhotoResources?
}

private struct DayGalleryActionButtonStyle: ButtonStyle {
    let isPrimary: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(BBBFont.font(size: 14, weight: .heavy))
            .foregroundStyle(isPrimary ? DesignToken.onPrimary : DesignToken.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        isPrimary
                            ? DesignToken.primary.opacity(configuration.isPressed ? 0.78 : 1)
                            : DesignToken.surfaceRaised.opacity(configuration.isPressed ? 0.62 : 0.88)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isPrimary ? Color.clear : DesignToken.borderSubtle, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.9 : 1)
    }
}

private struct AppleStickerImage: View {
    let image: UIImage
    let size: CGFloat

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .shadow(color: AchievementMediaRenderPalette.stickerOutline, radius: 0, x: 2.2, y: 0)
            .shadow(color: AchievementMediaRenderPalette.stickerOutline, radius: 0, x: -2.2, y: 0)
            .shadow(color: AchievementMediaRenderPalette.stickerOutline, radius: 0, x: 0, y: 2.2)
            .shadow(color: AchievementMediaRenderPalette.stickerOutline, radius: 0, x: 0, y: -2.2)
            .shadow(color: AchievementMediaRenderPalette.stickerOutline.opacity(0.96), radius: 1.6, x: 0, y: 0)
            .shadow(color: AchievementMediaRenderPalette.stickerShadow.opacity(0.12), radius: 4, y: 2)
    }
}

private struct MilestoneDayPhotoPicker: View {
    @Environment(\.dismiss) private var dismiss
    let day: MilestoneDay
    let birthDate: Date
    let onSelected: (AchievementStickerMedia) -> Void

    @State private var assets: [PHAsset] = []
    @State private var thumbnails: [String: UIImage] = [:]
    @State private var statusText = "正在读取当天照片"
    @State private var manager = PHCachingImageManager()
    @State private var thumbnailRequestIDs: [String: PHImageRequestID] = [:]
    @State private var fullImageRequestID: PHImageRequestID?
    @State private var requestGeneration = UUID()

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                achievementSoftBackground
                    .ignoresSafeArea()

                if assets.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 38, weight: .semibold))
                            .foregroundStyle(DesignToken.primary.opacity(0.75))
                        Text(statusText)
                            .font(BBBFont.font(size: 15, weight: .bold))
                            .foregroundStyle(DesignToken.textSecondary)
                    }
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(assets, id: \.localIdentifier) { asset in
                                Button {
                                    loadFullImage(asset)
                                } label: {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(DesignToken.surfaceSoft)
                                        if let image = thumbnails[asset.localIdentifier] {
                                            Image(uiImage: image)
                                                .resizable()
                                                .scaledToFill()
                                        }
                                    }
                                    .aspectRatio(1, contentMode: .fit)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .onAppear {
                                        requestThumbnailIfNeeded(asset)
                                    }
                                }
                                .buttonStyle(ScaleButtonStyle())
                            }
                        }
                        .padding(18)
                    }
                }
            }
            .navigationTitle(photoPickerTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .task {
                await loadAssets()
            }
            .onDisappear {
                cancelImageRequests()
            }
        }
    }

    private var photoPickerTitle: String {
        "\(AppDateTimeFormat.date(day.date))的照片"
    }

    @MainActor
    private func loadAssets() async {
        let authorized = await MilestonePhotoScanner.requestPhotoAccess()
        guard authorized else {
            statusText = "需要允许访问照片后才能选择当天照片"
            return
        }
        let fetched = MilestonePhotoScanner.assets(on: day.date)
        assets = fetched
        statusText = fetched.isEmpty ? "这一天没有找到照片" : ""
    }

    private func requestThumbnailIfNeeded(_ asset: PHAsset) {
        let identifier = asset.localIdentifier
        guard thumbnails[identifier] == nil,
              thumbnailRequestIDs[identifier] == nil else { return }

        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        let generation = requestGeneration
        let requestID = manager.requestImage(
            for: asset,
            targetSize: CGSize(width: 240, height: 240),
            contentMode: .aspectFill,
            options: options
        ) { image, info in
            let isCancelled = (info?[PHImageCancelledKey] as? Bool) == true
            let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) == true
            Task { @MainActor in
                guard requestGeneration == generation else { return }
                if !isDegraded {
                    thumbnailRequestIDs[identifier] = nil
                }
                guard !isCancelled, let image else { return }
                thumbnails[identifier] = image
            }
        }
        thumbnailRequestIDs[identifier] = requestID
    }

    private func loadFullImage(_ asset: PHAsset) {
        if let fullImageRequestID {
            manager.cancelImageRequest(fullImageRequestID)
        }
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact
        options.isNetworkAccessAllowed = true
        let generation = requestGeneration
        fullImageRequestID = manager.requestImage(
            for: asset,
            targetSize: CGSize(width: 1800, height: 1800),
            contentMode: .aspectFit,
            options: options
        ) { image, info in
            let isCancelled = (info?[PHImageCancelledKey] as? Bool) == true
            let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) == true
            guard !isCancelled, !isDegraded, let image else { return }
            Task { @MainActor in
                guard requestGeneration == generation else { return }
                fullImageRequestID = nil
                let squareImage = image.squareCropped(maxSide: StickerGenerator.stickerInputMaxSide)
                onSelected(AchievementStickerMedia(
                    image: squareImage,
                    originalImage: image.normalized(),
                    capturedAt: asset.creationDate ?? day.date,
                    assetLocalIdentifier: asset.localIdentifier,
                    assetMediaSubtypeRawValue: asset.mediaSubtypes.rawValue,
                    livePhotoMovieURL: nil
                ))
                dismiss()
            }
        }
    }

    @MainActor
    private func cancelImageRequests() {
        requestGeneration = UUID()
        thumbnailRequestIDs.values.forEach(manager.cancelImageRequest)
        thumbnailRequestIDs.removeAll()
        if let fullImageRequestID {
            manager.cancelImageRequest(fullImageRequestID)
            self.fullImageRequestID = nil
        }
        manager.stopCachingImagesForAllAssets()
    }
}

private enum MilestoneAutoMatchDuplicateReason: Hashable, Sendable {
    case samePhoto
    case visuallySimilar

    var message: String {
        switch self {
        case .samePhoto:
            return "这张照片已在成长页"
        case .visuallySimilar:
            return "相似照片已在成长页"
        }
    }
}

private struct MilestoneAutoMatchCandidate: Identifiable, Hashable, @unchecked Sendable {
    let id: UUID
    let day: MilestoneDay
    let milestone: MilestoneDefinition?
    let sourceImage: UIImage
    let stickerImage: UIImage
    let assetLocalIdentifier: String
    let assetMediaSubtypeRawValue: UInt
    let confidence: Double
    let scoreBreakdown: AchievementAutoMatchScoreBreakdown
    let sourceImageFingerprint: String?
    let duplicateReason: MilestoneAutoMatchDuplicateReason?
    let duplicateAchievementID: UUID?

    init(
        id: UUID = UUID(),
        day: MilestoneDay,
        milestone: MilestoneDefinition?,
        sourceImage: UIImage,
        stickerImage: UIImage,
        assetLocalIdentifier: String,
        assetMediaSubtypeRawValue: UInt,
        confidence: Double,
        scoreBreakdown: AchievementAutoMatchScoreBreakdown,
        sourceImageFingerprint: String? = nil,
        duplicateReason: MilestoneAutoMatchDuplicateReason? = nil,
        duplicateAchievementID: UUID? = nil
    ) {
        self.id = id
        self.day = day
        self.milestone = milestone
        self.sourceImage = sourceImage
        self.stickerImage = stickerImage
        self.assetLocalIdentifier = assetLocalIdentifier
        self.assetMediaSubtypeRawValue = assetMediaSubtypeRawValue
        self.confidence = confidence
        self.scoreBreakdown = scoreBreakdown
        self.sourceImageFingerprint = sourceImageFingerprint
        self.duplicateReason = duplicateReason
        self.duplicateAchievementID = duplicateAchievementID
    }

    var isAlreadyRecorded: Bool { duplicateReason != nil }

    var record: AchievementAutoMatchCandidateRecord {
        AchievementAutoMatchCandidateRecord(
            id: id,
            pageIndex: day.pageIndex,
            dayOffset: day.dayOffset,
            date: day.date,
            milestoneID: milestone?.id,
            assetLocalIdentifier: assetLocalIdentifier,
            assetMediaSubtypeRawValue: assetMediaSubtypeRawValue,
            confidence: confidence,
            scoreBreakdown: scoreBreakdown,
            sourceImageFingerprint: sourceImageFingerprint
        )
    }

    static func == (lhs: MilestoneAutoMatchCandidate, rhs: MilestoneAutoMatchCandidate) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

private struct MilestoneAutoMatchCandidateDraft: Identifiable, Hashable {
    var id: UUID { candidate.id }
    var candidate: MilestoneAutoMatchCandidate
    var name: String
    var description: String
    var note: String
    var mediaKind: AchievementMediaKind
    var selectedMilestoneID: String?
    var filterPresetID: String?
    var cropState: AchievementCropState
}

private struct MilestoneAutoMatchReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(BabyProfileStore.self) private var profileStore
    @EnvironmentObject private var stickerStore: AchievementStickerStore
    let pageIndex: Int
    let candidates: [MilestoneAutoMatchCandidate]
    let onSaved: () -> Void

    @State private var selectedIDs: Set<UUID>
    @State private var drafts: [UUID: MilestoneAutoMatchCandidateDraft] = [:]
    @State private var editingDraft: MilestoneAutoMatchCandidateDraft?
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(pageIndex: Int, candidates: [MilestoneAutoMatchCandidate], onSaved: @escaping () -> Void = {}) {
        self.pageIndex = pageIndex
        self.candidates = candidates
        self.onSaved = onSaved
        self._selectedIDs = State(initialValue: Set(candidates.filter { !$0.isAlreadyRecorded }.map(\.id)))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                achievementSoftBackground
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 12) {
                        ForEach(sortedCandidates) { candidate in
                            candidateCard(draft(for: candidate))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 96)
                }
            }
            .navigationTitle("\(pageIndex)月龄匹配结果")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "保存中" : "保存") {
                        saveSelected()
                    }
                    .disabled(isSaving || selectedIDs.isEmpty)
                }
            }
            .alert("保存失败", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("好", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .sheet(item: $editingDraft) { draft in
                AutoMatchCandidateEditSheet(draft: draft) { updatedDraft in
                    drafts[updatedDraft.id] = updatedDraft
                    editingDraft = nil
                }
            }
        }
    }

    private func candidateCard(_ draft: MilestoneAutoMatchCandidateDraft) -> some View {
        let candidate = draft.candidate
        let isSelected = selectedIDs.contains(candidate.id)
        let isRecorded = candidate.isAlreadyRecorded

        return HStack(alignment: .center, spacing: 14) {
            Button {
                guard !isRecorded else { return }
                editingDraft = draft
            } label: {
                AchievementInstaxCard(
                    image: draft.mediaKind == .photo ? candidate.sourceImage : candidate.stickerImage,
                    backgroundImage: draft.mediaKind == .sticker ? candidate.sourceImage : nil,
                    mediaKind: draft.mediaKind,
                    title: draft.name,
                    subtitle: "",
                    width: 92
                )
            }
            .buttonStyle(.plain)
            .disabled(isRecorded)

            VStack(alignment: .leading, spacing: 5) {
                Text("\(candidateAgeText(candidate.day.date))的\(profileStore.currentProfile.name)")
                    .font(BBBFont.font(size: 14, weight: .heavy))
                    .foregroundStyle(DesignToken.textPrimary)
                    .lineLimit(2)

                Text(candidate.duplicateReason?.message ?? "宝宝匹配度 \(Int((candidate.confidence * 100).rounded()))%")
                    .font(BBBFont.font(size: 12, weight: .bold))
                    .foregroundStyle(isRecorded ? DesignToken.textSecondary : theme.primary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                guard !isRecorded else { return }
                editingDraft = draft
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(isRecorded ? DesignToken.textSecondary.opacity(0.38) : DesignToken.textPrimary)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(DesignToken.surfaceRaised.opacity(0.88)))
            }
            .buttonStyle(.plain)
            .disabled(isRecorded)
            .accessibilityLabel("编辑照片")

            Button {
                toggleSelection(candidate.id)
            } label: {
                Image(systemName: isRecorded ? "checkmark.circle" : (isSelected ? "checkmark.circle.fill" : "circle"))
                    .font(.system(size: 25, weight: .bold))
                    .foregroundStyle(
                        isRecorded
                            ? DesignToken.textSecondary.opacity(0.30)
                            : (isSelected ? theme.primary : DesignToken.textSecondary.opacity(0.42))
                    )
                    .frame(width: 38, height: 44)
            }
            .buttonStyle(.plain)
            .disabled(isRecorded)
            .accessibilityLabel(isRecorded ? "照片已在成长页" : (isSelected ? "已选择" : "未选择"))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(DesignToken.surfaceRaised.opacity(isRecorded ? 0.48 : 0.74))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(DesignToken.borderSubtle.opacity(0.82), lineWidth: 1)
        )
        .opacity(isRecorded ? 0.78 : 1)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sortedCandidates: [MilestoneAutoMatchCandidate] {
        candidates.sorted {
            if $0.day.dayOffset == $1.day.dayOffset { return $0.confidence > $1.confidence }
            return $0.day.dayOffset > $1.day.dayOffset
        }
    }

    private var theme: MilestoneUnitTheme {
        MilestoneUnitTheme.theme(for: pageIndex)
    }

    private func toggleSelection(_ id: UUID) {
        guard candidates.first(where: { $0.id == id })?.isAlreadyRecorded == false else { return }
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    private func draft(for candidate: MilestoneAutoMatchCandidate) -> MilestoneAutoMatchCandidateDraft {
        if let draft = drafts[candidate.id] {
            return draft
        }
        return MilestoneAutoMatchCandidateDraft(
            candidate: candidate,
            name: candidate.milestone?.title ?? candidateDateText(candidate.day.date),
            description: candidate.milestone?.description ?? "从相册里自动匹配到的宝宝照片。",
            note: "",
            mediaKind: .photo,
            selectedMilestoneID: candidate.milestone?.id,
            filterPresetID: nil,
            cropState: .centered
        )
    }

    private func candidateAgeText(_ date: Date) -> String {
        BabyAgeFormatter.displayText(
            birthDate: profileStore.currentProfile.birthDate,
            on: date
        )
    }

    private func candidateDateText(_ date: Date) -> String {
        AppDateTimeFormat.date(date)
    }

    private func saveSelected() {
        isSaving = true
        do {
            var replacedKeys: Set<String> = []
            var savedCount = 0
            for candidate in candidates where selectedIDs.contains(candidate.id) {
                guard !candidate.isAlreadyRecorded else { continue }
                let draft = draft(for: candidate)
                let editedCandidate = draft.candidate
                let milestone = AchievementMilestoneCatalog.milestone(id: draft.selectedMilestoneID)
                let replacementKey = "\(editedCandidate.day.dayOffset)-\(milestone?.id ?? "custom")"
                let shouldReplacePeer = !replacedKeys.contains(replacementKey)
                do {
                    _ = try stickerStore.add(
                        templateID: milestone?.id,
                        name: draft.name,
                        description: draft.description,
                        note: draft.note,
                        completedAt: editedCandidate.day.date,
                        sourceImage: editedCandidate.sourceImage,
                        stickerImage: draft.mediaKind == .sticker ? editedCandidate.stickerImage : nil,
                        milestoneID: milestone?.id,
                        milestoneKind: milestone?.kind ?? .custom,
                        achievedDayOffset: editedCandidate.day.dayOffset,
                        sourceAssetLocalIdentifier: editedCandidate.assetLocalIdentifier,
                        sourceAssetMediaSubtypeRawValue: editedCandidate.assetMediaSubtypeRawValue,
                        creationSource: .autoMatched,
                        matchConfidence: editedCandidate.confidence,
                        mediaKind: draft.mediaKind,
                        filterPresetID: draft.filterPresetID,
                        cropState: draft.cropState,
                        replaceAutoMatchedPeer: shouldReplacePeer
                    )
                    savedCount += 1
                } catch AchievementStickerError.imageAlreadyRecorded {
                    continue
                }
                replacedKeys.insert(replacementKey)
            }
            isSaving = false
            guard savedCount > 0 else {
                errorMessage = "所选照片都已经在成长页中，无需重复保存。"
                return
            }
            onSaved()
            dismiss()
        } catch {
            isSaving = false
            errorMessage = error.localizedDescription
        }
    }
}

private struct AutoMatchCandidateEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: MilestoneAutoMatchCandidateDraft
    @State private var media: AchievementStickerMedia
    @State private var selectedMilestoneID: String?
    @State private var showMediaEditor = false
    @State private var isRegenerating = false
    let onSave: (MilestoneAutoMatchCandidateDraft) -> Void

    init(draft: MilestoneAutoMatchCandidateDraft, onSave: @escaping (MilestoneAutoMatchCandidateDraft) -> Void) {
        _draft = State(initialValue: draft)
        _media = State(
            initialValue: AchievementStickerMedia(
                image: draft.candidate.sourceImage,
                originalImage: draft.candidate.sourceImage,
                stickerImage: draft.candidate.stickerImage,
                prefersStickerPreview: draft.mediaKind == .sticker,
                capturedAt: draft.candidate.day.date,
                filterPresetID: draft.filterPresetID,
                cropState: draft.cropState,
                assetLocalIdentifier: draft.candidate.assetLocalIdentifier,
                assetMediaSubtypeRawValue: draft.candidate.assetMediaSubtypeRawValue
            )
        )
        _selectedMilestoneID = State(initialValue: draft.selectedMilestoneID)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ZStack {
                achievementSoftBackground
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        ZStack {
                            AchievementInstaxCard(
                                image: previewForeground,
                                backgroundImage: media.mediaKind == .sticker ? media.image : nil,
                                mediaKind: media.mediaKind,
                                title: draft.name,
                                subtitle: "",
                                width: 244
                            )
                            if isRegenerating {
                                ProgressView()
                                    .tint(DesignToken.primary)
                                    .padding(12)
                                    .background(DesignToken.surfaceRaised.opacity(0.88), in: Circle())
                            }
                        }

                        Picker("呈现方式", selection: $media.prefersStickerPreview) {
                            Text("贴纸").tag(true)
                            Text("照片").tag(false)
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: media.prefersStickerPreview) { _, wantsSticker in
                            if wantsSticker, media.stickerImage == nil {
                                regenerateSticker()
                            }
                        }

                        Button {
                            showMediaEditor = true
                        } label: {
                            Label("裁切、缩放与滤镜", systemImage: "slider.horizontal.3")
                                .font(BBBFont.font(size: 14, weight: .heavy))
                                .foregroundStyle(DesignToken.textPrimary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 46)
                                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(DesignToken.surfaceRaised.opacity(0.82)))
                        }
                        .buttonStyle(.plain)

                        VStack(spacing: 12) {
                            Picker("绑定里程碑", selection: $selectedMilestoneID) {
                                Text("自定义成就").tag(Optional<String>.none)
                                ForEach(AchievementMilestoneCatalog.all) { milestone in
                                    Text("\(milestone.availabilityText) · \(milestone.title)")
                                        .tag(Optional(milestone.id))
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
                            .padding(.horizontal, 14)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(DesignToken.surfaceRaised.opacity(0.82)))
                            .onChange(of: selectedMilestoneID) { _, newValue in
                                guard let milestone = AchievementMilestoneCatalog.milestone(id: newValue) else { return }
                                draft.name = milestone.title
                                draft.description = milestone.description
                            }

                            TextField("标题", text: $draft.name)
                                .textFieldStyle(.plain)
                                .font(BBBFont.font(size: 18, weight: .heavy))
                                .foregroundStyle(DesignToken.textPrimary)
                                .padding(16)
                                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(DesignToken.surfaceRaised.opacity(0.78)))

                            TextField("描述", text: $draft.description, axis: .vertical)
                                .textFieldStyle(.plain)
                                .lineLimit(3, reservesSpace: true)
                                .font(BBBFont.font(size: 14, weight: .medium))
                                .foregroundStyle(DesignToken.textSecondary)
                                .padding(16)
                                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(DesignToken.surfaceRaised.opacity(0.78)))

                            TextField("备注", text: $draft.note, axis: .vertical)
                                .textFieldStyle(.plain)
                                .lineLimit(3, reservesSpace: true)
                                .font(BBBFont.font(size: 14, weight: .medium))
                                .foregroundStyle(DesignToken.textSecondary)
                                .padding(16)
                                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(DesignToken.surfaceRaised.opacity(0.78)))
                        }
                    }
                    .padding(18)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("编辑贴纸候选")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveDraft()
                    }
                    .disabled(isRegenerating)
                }
            }
            .fullScreenCover(isPresented: $showMediaEditor) {
                AchievementMediaFilterEditor(media: $media)
            }
            .onChange(of: showMediaEditor) { _, isPresented in
                guard !isPresented, media.prefersStickerPreview else { return }
                regenerateSticker()
            }
        }
    }

    private var previewForeground: UIImage? {
        media.mediaKind == .photo ? media.image : media.stickerImage
    }

    private func regenerateSticker() {
        isRegenerating = true
        let sourceImage = media.image
        Task.detached(priority: .userInitiated) {
            let sticker = StickerGenerator.generateCompositeSticker(from: sourceImage, quality: .preview)
            await MainActor.run {
                media.stickerImage = sticker
                isRegenerating = false
            }
        }
    }

    private func saveDraft() {
        let candidate = draft.candidate
        let milestone = AchievementMilestoneCatalog.milestone(id: selectedMilestoneID)
        let sticker = media.stickerImage ?? candidate.stickerImage
        draft.candidate = MilestoneAutoMatchCandidate(
            id: candidate.id,
            day: candidate.day,
            milestone: milestone,
            sourceImage: media.image,
            stickerImage: sticker,
            assetLocalIdentifier: candidate.assetLocalIdentifier,
            assetMediaSubtypeRawValue: candidate.assetMediaSubtypeRawValue,
            confidence: candidate.confidence,
            scoreBreakdown: candidate.scoreBreakdown,
            sourceImageFingerprint: AchievementImageFingerprint.make(from: media.image),
            duplicateReason: candidate.duplicateReason,
            duplicateAchievementID: candidate.duplicateAchievementID
        )
        draft.mediaKind = media.mediaKind
        draft.selectedMilestoneID = selectedMilestoneID
        draft.filterPresetID = media.filterPresetID
        draft.cropState = media.cropState
        onSave(draft)
    }
}

private struct MilestonePhotoScanner {
    private static let minimumCandidateConfidence = 0.70
    private static let maximumCandidatesPerDay = 3
    private static let nearDuplicateDistance: Float = 9

    private let manager = PHCachingImageManager()

    private struct ScoredPhoto: @unchecked Sendable {
        let asset: PHAsset
        let image: UIImage
        let breakdown: AchievementAutoMatchScoreBreakdown
        let fingerprint: String?
        let duplicateReason: MilestoneAutoMatchDuplicateReason?
        let duplicateAchievementID: UUID?
    }

    func scan(
        pageIndex: Int,
        birthDate: Date,
        existingAchievements: [CustomAchievement],
        progress: @escaping @Sendable (MilestoneScanProgress) async -> Void
    ) async throws -> [MilestoneAutoMatchCandidate] {
        let authorized = await Self.requestPhotoAccess()
        guard authorized else {
            throw MilestonePhotoScanError.photoAccessDenied
        }

        let calendar = Calendar.current
        let birthStart = calendar.startOfDay(for: birthDate)
        let existingByAssetIdentifier = Dictionary(
            existingAchievements.compactMap { achievement -> (String, CustomAchievement)? in
                guard let identifier = achievement.sourceAssetLocalIdentifier, !identifier.isEmpty else { return nil }
                return (identifier, achievement)
            },
            uniquingKeysWith: { current, _ in current }
        )
        let existingFingerprints = existingAchievements.compactMap { achievement in
            achievement.sourceImageFingerprint.map { (achievement.id, $0) }
        }
        var candidates: [MilestoneAutoMatchCandidate] = []
        var seenCandidateAssetIdentifiers: Set<String> = []
        var seenCandidateFingerprints: [String] = []
        let startedAt = Date()

        for offset in 0..<30 {
            try Task.checkCancellation()
            let dayOffset = pageIndex * 30 + offset + 1
            guard let date = MilestoneDay.date(forDayNumber: dayOffset, birthDate: birthStart, calendar: calendar) else { continue }
            let day = MilestoneDay(dayOffset: dayOffset, date: date)
            let assets = Self.assets(on: date)
            guard !assets.isEmpty else {
                await progress(
                    MilestoneScanProgress(
                        processedDays: offset + 1,
                        totalDays: 30,
                        matchedCount: candidates.count,
                        startedAt: startedAt,
                        isRestoring: false
                    )
                )
                continue
            }

            var scored: [ScoredPhoto] = []
            for asset in assets.prefix(24) {
                try Task.checkCancellation()
                guard let image = try await requestImage(for: asset) else { continue }
                try Task.checkCancellation()
                let analysis = await Task.detached(priority: .userInitiated) {
                    (
                        Self.score(image: image, asset: asset),
                        AchievementImageFingerprint.make(from: image)
                    )
                }.value
                guard analysis.0.total >= Self.minimumCandidateConfidence else { continue }

                let exactMatch = existingByAssetIdentifier[asset.localIdentifier]
                let similarMatch = analysis.1.flatMap { fingerprint in
                    existingFingerprints.first(where: {
                        AchievementImageFingerprint.isDuplicate(fingerprint, $0.1)
                    })
                }
                scored.append(
                    ScoredPhoto(
                        asset: asset,
                        image: image,
                        breakdown: analysis.0,
                        fingerprint: analysis.1,
                        duplicateReason: exactMatch != nil ? .samePhoto : (similarMatch != nil ? .visuallySimilar : nil),
                        duplicateAchievementID: exactMatch?.id ?? similarMatch?.0
                    )
                )
            }

            let milestone = AchievementMilestoneCatalog.defaultMilestone(forDayOffset: dayOffset, pageIndex: pageIndex)
            let selectedPhotos = await Task.detached(priority: .userInitiated) {
                Self.distinctCandidates(from: scored)
            }.value

            for photo in selectedPhotos {
                try Task.checkCancellation()
                guard seenCandidateAssetIdentifiers.insert(photo.asset.localIdentifier).inserted else { continue }
                if let fingerprint = photo.fingerprint {
                    guard !seenCandidateFingerprints.contains(where: {
                        AchievementImageFingerprint.isDuplicate(fingerprint, $0)
                    }) else {
                        continue
                    }
                    seenCandidateFingerprints.append(fingerprint)
                }
                let prepared = await Task.detached(priority: .userInitiated) {
                    let optimized = photo.image.squareCropped(maxSide: StickerGenerator.stickerInputMaxSide)
                    let previewSource = photo.image.squareCropped(maxSide: StickerGenerator.stickerPreviewInputMaxSide)
                    let sticker = StickerGenerator.generateCompositeSticker(from: previewSource, quality: .preview)
                    return (optimized, sticker)
                }.value
                candidates.append(
                    MilestoneAutoMatchCandidate(
                        day: day,
                        milestone: milestone,
                        sourceImage: prepared.0,
                        stickerImage: prepared.1,
                        assetLocalIdentifier: photo.asset.localIdentifier,
                        assetMediaSubtypeRawValue: photo.asset.mediaSubtypes.rawValue,
                        confidence: min(max(photo.breakdown.total, 0), 1),
                        scoreBreakdown: photo.breakdown,
                        sourceImageFingerprint: photo.fingerprint,
                        duplicateReason: photo.duplicateReason,
                        duplicateAchievementID: photo.duplicateAchievementID
                    )
                )
            }

            await progress(
                MilestoneScanProgress(
                    processedDays: offset + 1,
                    totalDays: 30,
                    matchedCount: candidates.count,
                    startedAt: startedAt,
                    isRestoring: false
                )
            )
        }

        return candidates.sorted {
            if $0.day.dayOffset == $1.day.dayOffset { return $0.confidence > $1.confidence }
            return $0.day.dayOffset > $1.day.dayOffset
        }
    }

    func restore(
        records: [AchievementAutoMatchCandidateRecord],
        existingAchievements: [CustomAchievement]
    ) async throws -> [MilestoneAutoMatchCandidate] {
        let authorized = await Self.requestPhotoAccess()
        guard authorized else {
            throw MilestonePhotoScanError.photoAccessDenied
        }

        let existingByAssetIdentifier = Dictionary(
            existingAchievements.compactMap { achievement -> (String, CustomAchievement)? in
                guard let identifier = achievement.sourceAssetLocalIdentifier, !identifier.isEmpty else { return nil }
                return (identifier, achievement)
            },
            uniquingKeysWith: { current, _ in current }
        )
        let existingFingerprints = existingAchievements.compactMap { achievement in
            achievement.sourceImageFingerprint.map { (achievement.id, $0) }
        }
        var candidates: [MilestoneAutoMatchCandidate] = []
        var seenAssetIdentifiers: Set<String> = []
        var seenFingerprints: [String] = []
        for record in records {
            try Task.checkCancellation()
            guard seenAssetIdentifiers.insert(record.assetLocalIdentifier).inserted else { continue }
            guard record.confidence >= Self.minimumCandidateConfidence else { continue }
            guard let asset = Self.asset(localIdentifier: record.assetLocalIdentifier),
                  let image = try await requestImage(for: asset) else {
                continue
            }
            try Task.checkCancellation()
            let prepared = await Task.detached(priority: .userInitiated) {
                let optimized = image.squareCropped(maxSide: StickerGenerator.stickerInputMaxSide)
                let previewSource = image.squareCropped(maxSide: StickerGenerator.stickerPreviewInputMaxSide)
                let sticker = StickerGenerator.generateCompositeSticker(from: previewSource, quality: .preview)
                let fingerprint = record.sourceImageFingerprint ?? AchievementImageFingerprint.make(from: image)
                return (optimized, sticker, fingerprint)
            }.value
            if let fingerprint = prepared.2 {
                guard !seenFingerprints.contains(where: {
                    AchievementImageFingerprint.isDuplicate(fingerprint, $0)
                }) else {
                    continue
                }
                seenFingerprints.append(fingerprint)
            }
            let exactMatch = existingByAssetIdentifier[record.assetLocalIdentifier]
            let similarMatch = prepared.2.flatMap { fingerprint in
                existingFingerprints.first(where: {
                    AchievementImageFingerprint.isDuplicate(fingerprint, $0.1)
                })
            }
            let milestone = record.milestoneID.flatMap { AchievementMilestoneCatalog.milestone(id: $0) }
            candidates.append(
                MilestoneAutoMatchCandidate(
                    id: record.id,
                    day: MilestoneDay(dayOffset: record.dayOffset, date: record.date),
                    milestone: milestone,
                    sourceImage: prepared.0,
                    stickerImage: prepared.1,
                    assetLocalIdentifier: record.assetLocalIdentifier,
                    assetMediaSubtypeRawValue: asset.mediaSubtypes.rawValue,
                    confidence: record.confidence,
                    scoreBreakdown: record.scoreBreakdown,
                    sourceImageFingerprint: prepared.2,
                    duplicateReason: exactMatch != nil ? .samePhoto : (similarMatch != nil ? .visuallySimilar : nil),
                    duplicateAchievementID: exactMatch?.id ?? similarMatch?.0
                )
            )
        }
        return candidates.sorted {
            if $0.day.dayOffset == $1.day.dayOffset { return $0.confidence > $1.confidence }
            return $0.day.dayOffset > $1.day.dayOffset
        }
    }

    static func requestPhotoAccess() async -> Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized, .limited:
            return true
        case .notDetermined:
            let newStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            return newStatus == .authorized || newStatus == .limited
        default:
            return false
        }
    }

    static func assets(on date: Date) -> [PHAsset] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }

        let options = PHFetchOptions()
        options.predicate = NSPredicate(
            format: "mediaType == %d AND creationDate >= %@ AND creationDate < %@",
            PHAssetMediaType.image.rawValue,
            start as NSDate,
            end as NSDate
        )
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        let result = PHAsset.fetchAssets(with: .image, options: options)
        var assets: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        return assets
    }

    static func asset(localIdentifier: String) -> PHAsset? {
        PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil).firstObject
    }

    private func requestImage(for asset: PHAsset) async throws -> UIImage? {
        try Task.checkCancellation()
        let image = await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = true
            manager.requestImage(
                for: asset,
                targetSize: CGSize(width: 1200, height: 1200),
                contentMode: .aspectFit,
                options: options
            ) { image, info in
                if let degraded = info?[PHImageResultIsDegradedKey] as? Bool, degraded {
                    return
                }
                continuation.resume(returning: image)
            }
        }
        try Task.checkCancellation()
        return image
    }

    private static func score(image: UIImage, asset: PHAsset) -> AchievementAutoMatchScoreBreakdown {
        guard let cgImage = image.normalized().cgImage else {
            return AchievementAutoMatchScoreBreakdown(
                favorite: asset.isFavorite ? 0.10 : 0.02,
                facePresence: 0,
                faceArea: 0,
                faceCenter: 0,
                aspect: 0,
                resolution: 0,
                total: asset.isFavorite ? 0.10 : 0.02
            )
        }
        let favoriteScore = asset.isFavorite ? 0.08 : 0.02
        var facePresenceScore = 0.0
        var faceAreaScore = 0.0
        var faceCenterScore = 0.0
        var aspectScore = 0.0
        var resolutionScore = 0.0

        let faceRequest = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage)
        if (try? handler.perform([faceRequest])) != nil,
           let faces = faceRequest.results,
           !faces.isEmpty {
            let bestFace = faces.max { lhs, rhs in
                lhs.boundingBox.width * lhs.boundingBox.height < rhs.boundingBox.width * rhs.boundingBox.height
            }
            let faceArea = bestFace.map { $0.boundingBox.width * $0.boundingBox.height } ?? 0
            let centerScore = bestFace.map { face in
                let center = CGPoint(x: face.boundingBox.midX, y: face.boundingBox.midY)
                let distance = hypot(Double(center.x - 0.5), Double(center.y - 0.5))
                return max(0, 1 - distance * 1.45)
            } ?? 0
            facePresenceScore = 0.32
            faceAreaScore = min(Double(faceArea) * 2.8, 0.25)
            faceCenterScore = Double(centerScore) * 0.23
        }

        let aspect = Double(asset.pixelWidth) / Double(max(asset.pixelHeight, 1))
        let squareFit = 1 - min(abs(aspect - 1.0), 1.0)
        if aspect > 0.62 && aspect < 1.62 {
            aspectScore = 0.04 + squareFit * 0.05
        }
        if asset.pixelWidth >= 900 && asset.pixelHeight >= 900 {
            resolutionScore = 0.07
        }
        let total = min(
            favoriteScore + facePresenceScore + faceAreaScore + faceCenterScore + aspectScore + resolutionScore,
            1
        )
        return AchievementAutoMatchScoreBreakdown(
            favorite: favoriteScore,
            facePresence: facePresenceScore,
            faceArea: faceAreaScore,
            faceCenter: faceCenterScore,
            aspect: aspectScore,
            resolution: resolutionScore,
            total: total
        )
    }

    private static func distinctCandidates(from photos: [ScoredPhoto]) -> [ScoredPhoto] {
        let ordered = photos.sorted { $0.breakdown.total > $1.breakdown.total }
        var selected: [ScoredPhoto] = []
        var selectedPrints: [VNFeaturePrintObservation] = []

        for photo in ordered {
            guard selected.count < maximumCandidatesPerDay else { break }
            guard let featurePrint = featurePrint(for: photo.image) else {
                selected.append(photo)
                continue
            }

            let isNearDuplicate = selectedPrints.contains { existing in
                var distance: Float = .greatestFiniteMagnitude
                guard (try? featurePrint.computeDistance(&distance, to: existing)) != nil else {
                    return false
                }
                return distance < nearDuplicateDistance
            }
            guard !isNearDuplicate else { continue }
            selected.append(photo)
            selectedPrints.append(featurePrint)
        }
        return selected
    }

    private static func featurePrint(for image: UIImage) -> VNFeaturePrintObservation? {
        guard let cgImage = image.normalized().cgImage else { return nil }
        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage)
        guard (try? handler.perform([request])) != nil else { return nil }
        return request.results?.first as? VNFeaturePrintObservation
    }
}

private enum MilestonePhotoScanError: LocalizedError {
    case photoAccessDenied

    var errorDescription: String? {
        switch self {
        case .photoAccessDenied:
            return "需要允许访问照片后才能自动匹配宝宝照片。"
        }
    }
}

private func achievementDetailTimestampText(_ date: Date) -> String {
    AppDateTimeFormat.dateTime(date)
}

private var achievementSoftBackground: some View {
    ZStack {
        LinearGradient(
            colors: [
                DesignToken.canvas,
                DesignToken.surfaceSoft,
                DesignToken.surface
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        LinearGradient(
            colors: [
                DesignToken.surfaceRaised.opacity(0.42),
                DesignToken.primarySoft.opacity(0.22),
                .clear
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

private func achievementCircleButtonIcon(_ systemName: String, isEnabled: Bool = true) -> some View {
    Image(systemName: systemName)
        .font(.system(size: 20, weight: .semibold))
        .foregroundStyle(isEnabled ? DesignToken.primary : DesignToken.textFaint)
        .frame(width: 48, height: 48)
        .background(
            Circle()
                .fill(DesignToken.surfaceRaised.opacity(0.78))
                .shadow(color: DesignToken.shadowColor.opacity(0.08), radius: 12, y: 5)
        )
}

private func achievementStickerPlaceholder(symbol: String?) -> some View {
    ZStack {
        AchievementDoodleHalo()
            .frame(width: 240, height: 240)
            .opacity(0.48)

        Circle()
            .fill(DesignToken.surfaceRaised.opacity(0.58))
            .frame(width: 146, height: 146)

        Image(systemName: symbol ?? "sparkles")
            .font(.system(size: 54, weight: .semibold))
            .foregroundStyle(DesignToken.primary.opacity(0.78))

        Image(systemName: "camera.fill")
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(DesignToken.onPrimary)
            .frame(width: 42, height: 42)
            .background(Circle().fill(DesignToken.primary.opacity(0.82)))
            .offset(x: 54, y: 52)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
}

private struct AchievementDoodleHalo: View {
    var body: some View {
        ZStack {
            Circle()
                .stroke(DesignToken.surfaceRaised.opacity(0.78), lineWidth: 12)
                .blur(radius: 0.2)

            Circle()
                .stroke(DesignToken.borderSubtle.opacity(0.45), style: StrokeStyle(lineWidth: 9, lineCap: .round, dash: [20, 18]))
                .rotationEffect(.degrees(-12))

            Circle()
                .stroke(DesignToken.surfaceRaised.opacity(0.72), style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [2, 8]))
                .scaleEffect(0.84)
        }
    }
}

private struct AchievementSection: Identifiable {
    let id = UUID()
    let title: String
    let achievements: [Achievement]
}

private struct Achievement: Identifiable {
    let id: String
    let title: String
    let description: String
    let symbol: String

    var template: AchievementTemplate {
        AchievementTemplate(id: id, title: title, description: description, symbol: symbol)
    }
}

private enum AchievementGridItem: Identifiable {
    case achievement(Achievement)
    case customAchievement(CustomAchievement)
    case createCustom

    var id: String {
        switch self {
        case .achievement(let achievement): return achievement.id
        case .customAchievement(let achievement): return achievement.id.uuidString
        case .createCustom: return "create-custom-achievement"
        }
    }
}

private extension Text {
    func achievementTitleStyle(
        color: Color = DesignToken.textPrimary,
        alignment: TextAlignment = .center
    ) -> some View {
        self
            .font(BBBFont.font(size: 12, weight: .heavy))
            .foregroundStyle(color)
            .multilineTextAlignment(alignment)
            .lineLimit(2)
            .minimumScaleFactor(0.78)
    }

    func achievementMetaStyle(
        opacity: Double = 1,
        alignment: TextAlignment = .center
    ) -> some View {
        self
            .font(BBBFont.font(size: 9, weight: .bold))
            .foregroundStyle(DesignToken.textSecondary.opacity(opacity))
            .multilineTextAlignment(alignment)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
    }
}

private func achievementCardShell<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    VStack(spacing: 0) {
        content()
    }
    .padding(.horizontal, 4)
    .padding(.top, 6)
    .padding(.bottom, 8)
    .frame(maxWidth: .infinity, alignment: .top)
    .aspectRatio(0.84, contentMode: .fit)
}

private enum AchievementDraftField: Hashable {
    case name
    case description
    case note
}

private enum AchievementSheetTypography {
    static let titleSize: CGFloat = 21
    static let titleWeight: BBBFontWeight = .heavy
    static let bodySize: CGFloat = 15
    static let noteSize: CGFloat = 14
    static let metaSize: CGFloat = 13
}

private struct AchievementCaptureFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var stickerStore: AchievementStickerStore
    @Environment(BabyProfileStore.self) private var profileStore
    @State private var media: AchievementStickerMedia?
    @State private var savedAchievement: CustomAchievement?

    var body: some View {
        Group {
            if let savedAchievement,
               let dayOffset = savedAchievement.achievedDayOffset,
               let date = MilestoneDay.date(forDayNumber: dayOffset, birthDate: profileStore.currentProfile.birthDate) {
                MilestoneDayAchievementsView(
                    group: MilestoneDayAchievementGroup(
                        day: MilestoneDay(dayOffset: dayOffset, date: date),
                        achievementIDs: stickerStore.achievements(onDayOffset: dayOffset).map(\.id),
                        initialAchievementID: savedAchievement.id
                    )
                )
                .environmentObject(stickerStore)
            } else if let media {
                AchievementCreationEditorView(
                    media: Binding(
                        get: { self.media ?? media },
                        set: { self.media = $0 }
                    ),
                    onCancel: { self.media = nil },
                    onSaved: { savedAchievement = $0 },
                    onRetake: { self.media = nil }
                )
                .id(media.id)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                AchievementCameraView(media: $media) { capturedMedia in
                    withAnimation(.easeInOut(duration: 0.22)) {
                        media = capturedMedia
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.22), value: media?.id)
    }
}

private struct AchievementInstaxCard: View {
    let image: UIImage?
    var backgroundImage: UIImage? = nil
    let mediaKind: AchievementMediaKind
    let title: String
    let subtitle: String
    let width: CGFloat
    var livePhotoResources: AchievementLivePhotoResources? = nil
    var precomputedPalette: AchievementSoftPalette? = nil

    private var height: CGFloat { width * 86 / 72 }
    private var imageSide: CGFloat { width * 62 / 72 }
    private var paperInset: CGFloat { width * 5 / 72 }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                DesignToken.surfaceSoft

                if let livePhotoResources, let image {
                    AchievementLivePhotoPlayer(resources: livePhotoResources, placeholder: image)
                } else if let image {
                    AchievementLayeredMediaView(
                        foregroundImage: image,
                        backgroundImage: backgroundImage,
                        mediaKind: mediaKind,
                        precomputedPalette: precomputedPalette
                    )
                        .frame(width: imageSide, height: imageSide)
                        .clipped()
                } else {
                    ProgressView()
                        .tint(DesignToken.primary)
                }
            }
            .frame(width: imageSide, height: imageSide)
            .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .stroke(DesignToken.shadowColor.opacity(0.06), lineWidth: 0.8)
            )
            .padding(.top, paperInset)

            Text(title.localized)
                .font(BBBFont.font(size: min(max(width * 0.055, 9), 16), weight: .heavy))
                .foregroundStyle(DesignToken.textStrong)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: width, height: height)
        .background(DesignToken.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(DesignToken.borderSubtle, lineWidth: 0.8)
        )
        .shadow(color: DesignToken.shadowColor.opacity(0.10), radius: 3, x: 1, y: 3)
        .shadow(color: DesignToken.shadowColor.opacity(0.10), radius: 18, y: 10)
        // Keep paper, media and caption in the same render layer while the card moves.
        .compositingGroup()
        .transaction { transaction in
            transaction.animation = nil
        }
    }
}

private struct AchievementLivePhotoResources {
    let stillURL: URL
    let movieURL: URL
}

private struct AchievementLivePhotoPlayer: UIViewRepresentable {
    let resources: AchievementLivePhotoResources
    let placeholder: UIImage

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> PHLivePhotoView {
        let view = PHLivePhotoView()
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        let press = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePress(_:)))
        view.addGestureRecognizer(press)
        context.coordinator.view = view
        context.coordinator.resourceKey = resources.stillURL.path + resources.movieURL.path
        load(into: view)
        return view
    }

    func updateUIView(_ view: PHLivePhotoView, context: Context) {
        let key = resources.stillURL.path + resources.movieURL.path
        guard context.coordinator.resourceKey != key else { return }
        context.coordinator.resourceKey = key
        load(into: view)
    }

    private func load(into view: PHLivePhotoView) {
        PHLivePhoto.request(
            withResourceFileURLs: [resources.stillURL, resources.movieURL],
            placeholderImage: placeholder,
            targetSize: CGSize(width: 900, height: 900),
            contentMode: .aspectFill
        ) { livePhoto, _ in
            Task { @MainActor in view.livePhoto = livePhoto }
        }
    }

    final class Coordinator: NSObject {
        weak var view: PHLivePhotoView?
        var resourceKey = ""

        @objc func handlePress(_ gesture: UILongPressGestureRecognizer) {
            switch gesture.state {
            case .began:
                view?.startPlayback(with: .full)
            case .ended, .cancelled, .failed:
                view?.stopPlayback()
            default:
                break
            }
        }
    }
}

@MainActor
private func achievementLivePhotoResources(
    for achievement: CustomAchievement,
    store: AchievementStickerStore
) -> AchievementLivePhotoResources? {
    guard let urls = store.livePhotoResourceURLs(for: achievement) else { return nil }
    return AchievementLivePhotoResources(stillURL: urls.still, movieURL: urls.movie)
}

private struct AchievementCreationEditorView: View {
    @EnvironmentObject private var stickerStore: AchievementStickerStore
    @Environment(BabyProfileStore.self) private var profileStore

    let onCancel: () -> Void
    let onSaved: (CustomAchievement) -> Void
    let onRetake: () -> Void

    @Binding private var media: AchievementStickerMedia
    @State private var stickerPreview: UIImage?
    @State private var selectedMilestoneID: String?
    @State private var selectedCategory: AchievementMilestoneCategory = .all
    @State private var note = ""
    @State private var isGeneratingSticker = false
    @State private var isSaving = false
    @State private var showImageEditor = false
    @State private var showCustomAchievementEditor = false
    @State private var customAchievementName = ""
    @State private var customAchievementDescription = ""
    @State private var errorMessage: String?
    @State private var generationID = UUID()

    init(
        media: Binding<AchievementStickerMedia>,
        onCancel: @escaping () -> Void,
        onSaved: @escaping (CustomAchievement) -> Void,
        onRetake: @escaping () -> Void
    ) {
        _media = media
        self.onCancel = onCancel
        self.onSaved = onSaved
        self.onRetake = onRetake
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ZStack {
                    achievementSoftBackground
                        .ignoresSafeArea()

                    VStack(spacing: 10) {
                        instaxHero(availableWidth: proxy.size.width)
                        imageActions
                        milestoneSelection
                            .frame(maxHeight: max(210, proxy.size.height * 0.35))
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 76)
                }
            }
            .navigationTitle("编辑成就")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(DesignToken.surface.opacity(0.94), for: .navigationBar)
            .safeAreaInset(edge: .bottom) {
                editorActionBar
            }
            .fullScreenCover(isPresented: $showImageEditor) {
                AchievementMediaFilterEditor(media: $media)
                    .id(media.id)
            }
            .sheet(isPresented: $showCustomAchievementEditor) {
                CustomAchievementDraftSheet(
                    name: $customAchievementName,
                    description: $customAchievementDescription
                ) {
                    selectedMilestoneID = "custom"
                }
            }
            .alert("无法保存成就", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("好", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "请重试。")
            }
            .onAppear {
                generateStickerPreview()
            }
            .onChange(of: media.id) { _, _ in
                generateStickerPreview()
            }
            .onChange(of: media.image) { _, _ in
                generateStickerPreview()
            }
        }
    }

    private func instaxHero(availableWidth: CGFloat) -> some View {
        VStack(spacing: 10) {
            AchievementInstaxCard(
                image: heroImage,
                backgroundImage: media.mediaKind == .sticker ? media.image : nil,
                mediaKind: media.mediaKind,
                title: selectedMilestone?.title ?? unboundPhotoCaption,
                subtitle: photoDateText,
                width: min(max(availableWidth - 92, 286), 320)
            )

        }
        .frame(maxWidth: .infinity)
    }

    private var heroImage: UIImage? {
        if media.mediaKind == .photo {
            return media.image
        }
        return stickerPreview
    }

    private var imageActions: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Text("\(photoAgeText) · \(media.mediaKind == .photo ? "照片" : "贴纸")")
                    .font(BBBFont.font(size: 12, weight: .bold))
                    .foregroundStyle(DesignToken.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    showImageEditor = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(DesignToken.textPrimary)
                        .frame(width: 44, height: 44)
                        .background(DesignToken.surfaceRaised.opacity(0.82), in: Circle())
                        .overlay(Circle().stroke(DesignToken.borderSubtle, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("编辑图片")
            }

            Picker("呈现方式", selection: $media.prefersStickerPreview) {
                Text("照片").tag(false)
                Text("贴纸").tag(true)
            }
            .pickerStyle(.segmented)
            .onChange(of: media.prefersStickerPreview) { _, _ in
                generateStickerPreview()
            }
        }
    }

    private var milestoneSelection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("绑定成就（可选）")
                    .font(BBBFont.font(size: 17, weight: .heavy))
                    .foregroundStyle(DesignToken.textPrimary)
                Spacer()
                TextField("备注", text: $note)
                    .textFieldStyle(.plain)
                    .font(BBBFont.font(size: 12, weight: .medium))
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 140)
            }

            categoryPicker

            ScrollView(showsIndicators: false) {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8)
                    ],
                    spacing: 8
                ) {
                    noAchievementTile
                    customAchievementTile
                    ForEach(filteredMilestones) { milestone in
                        milestoneRow(milestone)
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .padding(.top, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AchievementMilestoneCategory.allCases) { category in
                    Button {
                        selectedCategory = category
                    } label: {
                        Text(category.title.localized)
                            .font(BBBFont.font(size: 13, weight: .heavy))
                            .foregroundStyle(selectedCategory == category ? DesignToken.onPrimary : DesignToken.textSecondary)
                            .padding(.horizontal, 14)
                            .frame(height: 34)
                            .background(
                                Capsule()
                                    .fill(selectedCategory == category ? DesignToken.primary : DesignToken.surfaceRaised.opacity(0.78))
                            )
                            .overlay(
                                Capsule()
                                .stroke(DesignToken.borderSubtle, lineWidth: selectedCategory == category ? 0 : 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func milestoneRow(_ milestone: MilestoneDefinition) -> some View {
        let isSelected = selectedMilestoneID == milestone.id

        return Button {
            selectedMilestoneID = isSelected ? nil : milestone.id
        } label: {
            HStack(alignment: .top, spacing: 7) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(isSelected ? DesignToken.primary : DesignToken.textFaint)
                    .frame(width: 20, height: 20)

                VStack(alignment: .leading, spacing: 3) {
                    Text(milestone.title.localized)
                        .font(BBBFont.font(size: 14, weight: .heavy))
                        .foregroundStyle(DesignToken.textPrimary)
                        .lineLimit(1)

                    Text(milestone.description.localized)
                        .font(BBBFont.font(size: 10, weight: .medium))
                        .foregroundStyle(DesignToken.textSecondary)
                        .lineLimit(1)

                    Text(milestone.availabilityText)
                        .font(BBBFont.font(size: 9, weight: .bold))
                        .foregroundStyle(DesignToken.primary)
                }
            }
            .padding(9)
            .frame(height: 68)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? DesignToken.primary.opacity(0.08) : DesignToken.surfaceRaised.opacity(0.82))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? DesignToken.primary.opacity(0.56) : DesignToken.borderSubtle.opacity(0.72), lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityHint("绑定这个成就")
    }

    private var noAchievementTile: some View {
        let isSelected = selectedMilestoneID == nil
        return Button {
            selectedMilestoneID = nil
        } label: {
            HStack(spacing: 7) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(isSelected ? DesignToken.primary : DesignToken.textFaint)
                VStack(alignment: .leading, spacing: 3) {
                    Text("不绑定成就")
                        .font(BBBFont.font(size: 14, weight: .heavy))
                        .foregroundStyle(DesignToken.textPrimary)
                    Text(unboundPhotoCaption)
                        .font(BBBFont.font(size: 10, weight: .medium))
                        .foregroundStyle(DesignToken.textSecondary)
                        .lineLimit(1)
                }
            }
            .padding(9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 68)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? DesignToken.primary.opacity(0.08) : DesignToken.surfaceRaised.opacity(0.82))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? DesignToken.primary.opacity(0.56) : DesignToken.borderSubtle, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var customAchievementTile: some View {
        Button {
            showCustomAchievementEditor = true
        } label: {
            HStack(spacing: 7) {
                Image(systemName: selectedMilestoneID == "custom" ? "checkmark.circle.fill" : "plus.circle")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(DesignToken.primary)
                VStack(alignment: .leading, spacing: 3) {
                    Text(customAchievementName.isEmpty ? "自定义成就" : customAchievementName)
                        .font(BBBFont.font(size: 14, weight: .heavy))
                        .foregroundStyle(DesignToken.textPrimary)
                        .lineLimit(1)
                    Text(customAchievementDescription.isEmpty ? "填写名称和一句描述" : customAchievementDescription)
                        .font(BBBFont.font(size: 10, weight: .medium))
                        .foregroundStyle(DesignToken.textSecondary)
                        .lineLimit(1)
                }
            }
            .padding(9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 68)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selectedMilestoneID == "custom" ? DesignToken.primary.opacity(0.08) : DesignToken.surfaceRaised.opacity(0.82))
            )
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(DesignToken.borderSubtle, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var noteEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("补充记录")
                .font(BBBFont.font(size: 15, weight: .heavy))
                .foregroundStyle(DesignToken.textPrimary)

            TextField("写下一句想记住的话", text: $note, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(3, reservesSpace: true)
                .font(BBBFont.font(size: 14, weight: .medium))
                .foregroundStyle(DesignToken.textPrimary)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(DesignToken.surfaceRaised.opacity(0.78)))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(DesignToken.borderSubtle, lineWidth: 1))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var editorActionBar: some View {
        HStack(spacing: 12) {
            Button("取消", action: onCancel)
                .font(BBBFont.font(size: 16, weight: .heavy))
                .foregroundStyle(DesignToken.textPrimary)
                .frame(width: 104, height: 54)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(DesignToken.surfaceRaised))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(DesignToken.borderSubtle, lineWidth: 1))

            Button {
                saveAchievement()
            } label: {
                Group {
                    if isSaving {
                        ProgressView().tint(DesignToken.onPrimary)
                    } else {
                        Text("确认保存")
                    }
                }
                .font(BBBFont.font(size: 16, weight: .heavy))
                .foregroundStyle(DesignToken.onPrimary)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(canSave ? DesignToken.primary : DesignToken.textSecondary.opacity(0.34))
                )
            }
            .buttonStyle(.plain)
            .disabled(!canSave)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private var selectedMilestone: MilestoneDefinition? {
        if selectedMilestoneID == "custom",
           !customAchievementName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return MilestoneDefinition(
                id: "custom",
                title: String(customAchievementName.prefix(10)),
                description: String(customAchievementDescription.prefix(32)),
                kind: .custom,
                targetDayOffset: nil,
                agePageIndex: nil,
                symbol: "plus.circle"
            )
        }
        return AchievementMilestoneCatalog.milestone(id: selectedMilestoneID)
    }

    private var exactImportantMilestone: MilestoneDefinition? {
        AchievementMilestoneCatalog.importantMilestone(onDayOffset: photoDayOffset)
    }

    private var filteredMilestones: [MilestoneDefinition] {
        AchievementMilestoneCatalog.all
            .filter { selectedCategory == .all || $0.category == selectedCategory }
            .sorted { relevance(of: $0) < relevance(of: $1) }
    }

    private func relevance(of milestone: MilestoneDefinition) -> Int {
        if milestone.id == exactImportantMilestone?.id { return 0 }
        if milestone.agePageIndex == MilestoneDay.pageIndex(for: photoDayOffset) { return 1 }
        if milestone.isAvailable(at: photoDayOffset) { return 2 }
        return 3 + (milestone.targetDayOffset ?? (milestone.agePageIndex ?? 999) * 30)
    }

    private var photoDayOffset: Int {
        let calendar = Calendar.current
        let birthDate = calendar.startOfDay(for: profileStore.currentProfile.birthDate)
        let photoDate = calendar.startOfDay(for: media.capturedAt)
        return MilestoneDay.dayNumber(birthDate: birthDate, on: photoDate, calendar: calendar)
    }

    private var photoAgeText: String {
        let age = BabyAgeFormatter.displayText(
            birthDate: profileStore.currentProfile.birthDate,
            on: media.capturedAt
        )
        return "宝宝 \(age)"
    }

    private var photoDateText: String {
        AppDateTimeFormat.date(media.capturedAt)
    }

    private var unboundPhotoCaption: String {
        "\(AppDateTimeFormat.date(media.capturedAt)) \(max(photoDayOffset, 1))天"
    }

    private var canSave: Bool {
        (media.mediaKind == .photo || stickerPreview != nil)
            && !isGeneratingSticker
            && !isSaving
    }

    private func generateStickerPreview() {
        let currentGenerationID = UUID()
        generationID = currentGenerationID
        guard media.mediaKind == .sticker else {
            stickerPreview = nil
            isGeneratingSticker = false
            return
        }
        if let stickerImage = media.stickerImage {
            stickerPreview = stickerImage
            isGeneratingSticker = false
            return
        }
        stickerPreview = nil
        isGeneratingSticker = true
        let sourceImage = media.image
        Task.detached(priority: .userInitiated) {
            let sticker = StickerGenerator.generateCompositeSticker(from: sourceImage, quality: .preview)
            await MainActor.run {
                guard generationID == currentGenerationID else { return }
                stickerPreview = sticker
                isGeneratingSticker = false
            }
        }
    }

    private func saveAchievement() {
        let milestone = selectedMilestone
        isSaving = true
        let draft = media
        let currentNote = note
        let dayOffset = max(photoDayOffset, 1)
        Task {
            let livePhotoResources = await draft.resolvedLivePhotoResources()
            let finalSticker: UIImage?
            if draft.mediaKind == .sticker {
                let signpostID = OSSignpostID(log: achievementCameraPerformanceLog)
                os_signpost(.begin, log: achievementCameraPerformanceLog, name: "StickerGeneration", signpostID: signpostID)
                finalSticker = await Task.detached(priority: .userInitiated) {
                    StickerGenerator.generateCompositeSticker(from: draft.image, quality: .full)
                }.value
                os_signpost(.end, log: achievementCameraPerformanceLog, name: "StickerGeneration", signpostID: signpostID)
            } else {
                finalSticker = nil
            }
            do {
                let achievement = try stickerStore.add(
                    templateID: milestone?.kind == .custom ? nil : milestone?.id,
                    name: milestone?.title ?? unboundPhotoCaption,
                    description: milestone?.description ?? "记录宝宝这一天的样子",
                    note: currentNote,
                    completedAt: draft.capturedAt,
                    sourceImage: draft.image,
                    sourceOriginalImage: draft.canonicalSourceImage,
                    stickerImage: finalSticker,
                    milestoneID: milestone?.kind == .custom ? nil : milestone?.id,
                    milestoneKind: milestone?.kind,
                    achievedDayOffset: dayOffset,
                    sourceAssetLocalIdentifier: draft.assetLocalIdentifier,
                    sourceAssetMediaSubtypeRawValue: draft.assetMediaSubtypeRawValue,
                    livePhotoStillURL: livePhotoResources?.stillURL,
                    livePhotoMovieURL: livePhotoResources?.movieURL,
                    creationSource: .manual,
                    mediaKind: draft.mediaKind,
                    filterPresetID: draft.filterPresetID,
                    watermarkStyleID: draft.watermarkStyleID,
                    cropState: draft.cropState
                )
                isSaving = false
                onSaved(achievement)
            } catch {
                isSaving = false
                errorMessage = error.localizedDescription
            }
        }
    }
}

private struct CustomAchievementDraftSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var name: String
    @Binding var description: String
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("成就名称") {
                    TextField("例如：第一次挥手", text: $name)
                    Text("\(name.count)/10")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section("一句话描述") {
                    TextField("补充这个成长时刻", text: $description, axis: .vertical)
                        .lineLimit(2...3)
                    Text("\(description.count)/32")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("自定义成就")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave()
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onChange(of: name) { _, value in
                if value.count > 10 { name = String(value.prefix(10)) }
            }
            .onChange(of: description) { _, value in
                if value.count > 32 { description = String(value.prefix(32)) }
            }
        }
        .presentationDetents([.medium])
    }
}

private struct AchievementSecondaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(BBBFont.font(size: 14, weight: .heavy))
            .foregroundStyle(DesignToken.textPrimary)
            .frame(height: 46)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(DesignToken.surfaceRaised.opacity(configuration.isPressed ? 0.62 : 0.84)))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(DesignToken.borderSubtle, lineWidth: 1))
    }
}

private struct AchievementSquareCropPreview: View {
    let image: UIImage
    @Binding var cropState: AchievementCropState
    let onCommit: () -> Void

    @GestureState private var dragTranslation: CGSize = .zero
    @GestureState private var gestureMagnification: CGFloat = 1

    var body: some View {
        GeometryReader { proxy in
            let viewport = min(proxy.size.width, proxy.size.height)
            let baseSize = aspectFillSize(imageSize: image.size, viewport: viewport)
            let displayScale = min(max(CGFloat(cropState.scale) * gestureMagnification, 1), 4)
            let renderedSize = CGSize(width: baseSize.width * displayScale, height: baseSize.height * displayScale)
            let horizontalTravel = max((renderedSize.width - viewport) / 2, 0)
            let verticalTravel = max((renderedSize.height - viewport) / 2, 0)
            let imageOffset = CGSize(
                width: -CGFloat(cropState.normalizedOffsetX) * horizontalTravel + dragTranslation.width,
                height: -CGFloat(cropState.normalizedOffsetY) * verticalTravel + dragTranslation.height
            )

            ZStack {
                AchievementMediaRenderPalette.stickerShadow

                Image(uiImage: image)
                    .resizable()
                    .frame(width: baseSize.width, height: baseSize.height)
                    .scaleEffect(displayScale)
                    .offset(imageOffset)

                AchievementCameraGridOverlay(style: .thirds)
                    .opacity(0.58)

                Rectangle()
                    .stroke(AchievementMediaRenderPalette.stickerOutline.opacity(0.78), lineWidth: 1)
            }
            .frame(width: viewport, height: viewport)
            .clipped()
            .contentShape(Rectangle())
            .gesture(dragGesture(viewport: viewport, baseSize: baseSize))
            .simultaneousGesture(magnifyGesture)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel("方形照片裁剪")
    }

    private func dragGesture(viewport: CGFloat, baseSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .updating($dragTranslation) { value, state, _ in
                state = value.translation
            }
            .onEnded { value in
                let scale = min(max(CGFloat(cropState.scale), 1), 4)
                let horizontalTravel = max((baseSize.width * scale - viewport) / 2, 0)
                let verticalTravel = max((baseSize.height * scale - viewport) / 2, 0)
                if horizontalTravel > 0 {
                    cropState.normalizedOffsetX = min(max(
                        cropState.normalizedOffsetX - Double(value.translation.width / horizontalTravel),
                        -1
                    ), 1)
                }
                if verticalTravel > 0 {
                    cropState.normalizedOffsetY = min(max(
                        cropState.normalizedOffsetY - Double(value.translation.height / verticalTravel),
                        -1
                    ), 1)
                }
                onCommit()
            }
    }

    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .updating($gestureMagnification) { value, state, _ in
                state = value.magnification
            }
            .onEnded { value in
                cropState.scale = min(max(cropState.scale * Double(value.magnification), 1), 4)
                onCommit()
            }
    }

    private func aspectFillSize(imageSize: CGSize, viewport: CGFloat) -> CGSize {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return CGSize(width: viewport, height: viewport)
        }
        let scale = max(viewport / imageSize.width, viewport / imageSize.height)
        return CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    }
}

private struct AchievementMediaFilterEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(BabyProfileStore.self) private var profileStore
    @Binding var media: AchievementStickerMedia
    @State private var selectedFilter: AchievementCameraFilterPreset
    @State private var previewImage: UIImage
    @State private var cropSourcePreview: UIImage
    @State private var isProcessing = false
    @State private var generationID = UUID()
    @State private var processingTask: Task<Void, Never>?
    @State private var cropState: AchievementCropState
    @State private var showFilterCatalog = false
    let onSaved: ((AchievementStickerMedia) -> Void)?

    init(
        media: Binding<AchievementStickerMedia>,
        onSaved: ((AchievementStickerMedia) -> Void)? = nil
    ) {
        _media = media
        let value = media.wrappedValue
        _selectedFilter = State(initialValue: AchievementCameraFilterPreset(rawValue: value.filterPresetID ?? "") ?? .original)
        _previewImage = State(initialValue: value.image)
        _cropSourcePreview = State(initialValue: value.canonicalSourceImage.rotatedByQuarterTurns(value.cropState.quarterTurns))
        _cropState = State(initialValue: value.cropState)
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AchievementMediaRenderPalette.stickerShadow.ignoresSafeArea()

                VStack(spacing: 20) {
                    Spacer(minLength: 16)

                    ZStack {
                        AchievementSquareCropPreview(
                            image: cropSourcePreview,
                            cropState: $cropState,
                            onCommit: { apply(selectedFilter) }
                        )

                        AchievementWatermarkView(
                            style: editorWatermarkStyle,
                            dateText: cameraEditorDateText,
                            ageText: cameraEditorAgeText
                        )
                        .padding(14)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                        .allowsHitTesting(false)

                        if isProcessing {
                            ProgressView()
                                .tint(AchievementMediaRenderPalette.stickerOutline)
                                .padding(12)
                                .background(AchievementMediaRenderPalette.stickerShadow.opacity(0.42), in: Circle())
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .padding(.horizontal, 16)

                    editorTools
                    Spacer(minLength: 12)
                }
            }
            .navigationTitle("编辑图片")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        var updatedMedia = media
                        updatedMedia.image = previewImage
                        updatedMedia.filterPresetID = selectedFilter.rawValue
                        updatedMedia.cropState = cropState
                        updatedMedia.stickerImage = nil
                        media = updatedMedia
                        onSaved?(updatedMedia)
                        dismiss()
                    }
                    .disabled(isProcessing)
                }
            }
            .onAppear {
                if media.originalImage == nil {
                    media.originalImage = media.image
                }
                resetEditorState()
            }
            .onChange(of: media.id) { _, _ in
                resetEditorState()
            }
            .onDisappear {
                processingTask?.cancel()
            }
            .fullScreenCover(isPresented: $showFilterCatalog) {
                CameraFilterCatalogView(selection: Binding(
                    get: { selectedFilter },
                    set: { apply($0) }
                ))
            }
        }
    }

    private var editorTools: some View {
        HStack(spacing: 24) {
            Label("裁剪", systemImage: "crop")
                .foregroundStyle(AchievementMediaRenderPalette.stickerOutline.opacity(0.72))
            Button {
                cropState.quarterTurns = (cropState.quarterTurns + 1) % 4
                apply(selectedFilter)
            } label: {
                Label("旋转", systemImage: "rotate.right")
            }
            Button {
                cropState = .centered
                apply(selectedFilter)
            } label: {
                Label("重置", systemImage: "arrow.counterclockwise")
            }
            Button {
                showFilterCatalog = true
            } label: {
                Label(selectedFilter.title, systemImage: "camera.filters")
            }
        }
        .font(BBBFont.font(size: 13, weight: .heavy))
        .foregroundStyle(AchievementMediaRenderPalette.stickerOutline)
        .buttonStyle(.borderless)
    }

    private func apply(_ preset: AchievementCameraFilterPreset) {
        selectedFilter = preset
        processingTask?.cancel()
        isProcessing = true
        let currentGenerationID = UUID()
        generationID = currentGenerationID
        let sourceMediaID = media.id
        let sourceImage = media.canonicalSourceImage
        let currentCropState = cropState
        let watermarkStyle = AchievementWatermarkStyle(rawValue: media.watermarkStyleID ?? "") ?? .off
        let dateText = cameraEditorDateText
        let ageText = BabyAgeFormatter.displayText(
            birthDate: profileStore.currentProfile.birthDate,
            on: media.capturedAt
        )
        processingTask = Task {
            try? await Task.sleep(for: .milliseconds(45))
            guard !Task.isCancelled else { return }
            let result = await Task.detached(priority: .userInitiated) {
                let rotatedSource = sourceImage.rotatedByQuarterTurns(currentCropState.quarterTurns)
                    .scaledToFit(maxSide: 1_200)
                let sourcePreview = CameraFilterPipeline.apply(preset, to: rotatedSource)
                let cropped = sourceImage.squareCropped(state: currentCropState, maxSide: StickerGenerator.stickerInputMaxSide)
                let finalImage = CameraFilterPipeline.apply(preset, to: cropped)
                    .addingAchievementWatermark(style: watermarkStyle, dateText: dateText, ageText: ageText)
                return (sourcePreview, finalImage)
            }.value
            guard !Task.isCancelled else { return }
            guard generationID == currentGenerationID,
                  media.id == sourceMediaID else {
                return
            }
            cropSourcePreview = result.0
            previewImage = result.1
            isProcessing = false
        }
    }

    private func resetEditorState() {
        generationID = UUID()
        processingTask?.cancel()
        selectedFilter = AchievementCameraFilterPreset(rawValue: media.filterPresetID ?? "") ?? .original
        cropState = media.cropState
        previewImage = media.image
        cropSourcePreview = media.canonicalSourceImage.rotatedByQuarterTurns(media.cropState.quarterTurns)
        isProcessing = false
        apply(selectedFilter)
    }

    private var editorWatermarkStyle: AchievementWatermarkStyle {
        AchievementWatermarkStyle(rawValue: media.watermarkStyleID ?? "") ?? .off
    }

    private var cameraEditorAgeText: String {
        BabyAgeFormatter.displayText(
            birthDate: profileStore.currentProfile.birthDate,
            on: media.capturedAt
        )
    }

    private var cameraEditorDateText: String {
        AppDateTimeFormat.date(media.capturedAt)
    }
}

private struct AchievementStoredMediaEditorHost: View {
    @State private var media: AchievementStickerMedia
    let onSaved: (AchievementStickerMedia) -> Void

    init(
        media: AchievementStickerMedia,
        onSaved: @escaping (AchievementStickerMedia) -> Void
    ) {
        _media = State(initialValue: media)
        self.onSaved = onSaved
    }

    var body: some View {
        AchievementMediaFilterEditor(media: $media, onSaved: onSaved)
    }
}

private struct CreateCustomAchievementView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var stickerStore: AchievementStickerStore

    let template: AchievementTemplate?
    let initialMedia: AchievementStickerMedia?
    let onCreated: (CustomAchievement) -> Void

    @State private var name = ""
    @State private var description = ""
    @State private var note = ""
    @State private var selectedMedia: AchievementStickerMedia?
    @State private var stickerPreview: UIImage?
    @State private var isGeneratingSticker = false
    @State private var showCamera = false
    @State private var showNoteEditor = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var generationID = UUID()
    @FocusState private var focusedField: AchievementDraftField?

    init(
        template: AchievementTemplate? = nil,
        initialMedia: AchievementStickerMedia? = nil,
        onCreated: @escaping (CustomAchievement) -> Void = { _ in }
    ) {
        self.template = template
        self.initialMedia = initialMedia
        self.onCreated = onCreated
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ZStack {
                    achievementSoftBackground
                        .ignoresSafeArea()

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 22) {
                            imagePickerCard(height: previewHeight(for: proxy.size.height))
                            formCard
                            completionTimeText
                        }
                        .padding(.horizontal, 22)
                        .padding(.top, 20)
                        .padding(.bottom, 120)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                mediaActionBar
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        achievementCircleButtonIcon("chevron.left")
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        saveAchievement()
                    } label: {
                        if isSaving {
                            ProgressView()
                                .tint(DesignToken.primary)
                                .frame(width: 48, height: 48)
                        } else {
                            achievementCircleButtonIcon("checkmark", isEnabled: canSaveAchievement)
                        }
                    }
                    .disabled(!canSaveAchievement)
                }

                ToolbarItem(placement: .principal) {
                    Text(template == nil ? "自定义贴纸" : "完成成就")
                        .font(BBBFont.font(size: 17, weight: .heavy))
                        .foregroundStyle(DesignToken.textStrong)
                }
            }
            .alert("无法创建贴纸", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("好", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .fullScreenCover(isPresented: $showCamera) {
                AchievementCameraView(media: $selectedMedia)
            }
            .onChange(of: selectedMedia) { _, newMedia in
                generateStickerPreview(from: newMedia)
            }
            .onAppear {
                if let template {
                    name = template.title
                    description = template.description
                }
                if selectedMedia == nil, let initialMedia {
                    selectedMedia = initialMedia
                    generateStickerPreview(from: initialMedia)
                }
            }
        }
    }

    private func imagePickerCard(height: CGFloat) -> some View {
        Button {
            showCamera = true
        } label: {
            ZStack {
                if let selectedMedia, !selectedMedia.prefersStickerPreview {
                    Image(uiImage: selectedMedia.image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .padding(.horizontal, 8)

                    if isGeneratingSticker {
                        ProgressView()
                            .tint(DesignToken.primary)
                            .padding(10)
                            .background(.ultraThinMaterial, in: Circle())
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                            .padding(16)
                    }
                } else if let stickerPreview {
                    Image(uiImage: stickerPreview)
                        .resizable()
                        .scaledToFit()
                        .shadow(color: AchievementMediaRenderPalette.stickerShadow.opacity(0.12), radius: 10, y: 5)
                        .padding(.horizontal, 8)
                } else if isGeneratingSticker {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(DesignToken.primary)
                        Text("正在生成贴纸")
                            .font(BBBFont.font(size: 15, weight: .semibold))
                            .foregroundStyle(DesignToken.textMuted)
                    }
                } else {
                    achievementStickerPlaceholder(symbol: template?.symbol)
                }
            }
            .frame(height: height)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private var formCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            if template == nil {
                TextField("成就名称", text: $name)
                    .textFieldStyle(.plain)
                    .focused($focusedField, equals: .name)
                    .font(BBBFont.font(size: AchievementSheetTypography.titleSize, weight: AchievementSheetTypography.titleWeight))
                    .foregroundStyle(DesignToken.textStrong)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 15)
                    .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(DesignToken.surfaceSoft.opacity(0.78)))

                TextField("写一句成就描述", text: $description, axis: .vertical)
                    .textFieldStyle(.plain)
                    .focused($focusedField, equals: .description)
                    .lineLimit(3, reservesSpace: true)
                    .font(BBBFont.font(size: AchievementSheetTypography.bodySize, weight: .medium))
                    .foregroundStyle(DesignToken.textMuted)
                    .lineSpacing(4)
                    .padding(18)
                    .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(DesignToken.surfaceSoft.opacity(0.78)))
            } else {
                Text(name.localized)
                    .font(BBBFont.font(size: AchievementSheetTypography.titleSize, weight: AchievementSheetTypography.titleWeight))
                    .foregroundStyle(DesignToken.textStrong)
                    .lineLimit(2)
                    .minimumScaleFactor(0.86)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(description.localized)
                    .font(BBBFont.font(size: AchievementSheetTypography.bodySize, weight: .medium))
                    .foregroundStyle(DesignToken.textMuted)
                    .lineSpacing(5)
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(DesignToken.surfaceRaised.opacity(0.64))
                            .overlay(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .stroke(DesignToken.borderSubtle.opacity(0.8), lineWidth: 1)
                            )
                    )
            }

            achievementNoteEditor
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(DesignToken.surfaceRaised.opacity(0.84))
                .shadow(color: DesignToken.shadowColor.opacity(0.08), radius: 20, y: 10)
        )
    }

    private var mediaActionBar: some View {
        Button {
            showCamera = true
        } label: {
            Label(selectedMedia == nil ? "添加照片" : "更换照片", systemImage: "camera.fill")
                .font(BBBFont.font(size: 17, weight: .bold))
                .foregroundStyle(DesignToken.onPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(Capsule().fill(DesignToken.primaryGradient))
                .shadow(color: DesignToken.primary.opacity(0.22), radius: 18, y: 9)
        }
        .buttonStyle(ScaleButtonStyle())
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(.ultraThinMaterial.opacity(0.86))
    }

    private var achievementNoteEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                    showNoteEditor.toggle()
                    if showNoteEditor {
                        focusedField = .note
                    }
                }
            } label: {
                HStack {
                    Text(note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "添加备注" : note)
                        .font(BBBFont.font(size: AchievementSheetTypography.noteSize, weight: .medium))
                        .foregroundStyle(DesignToken.textMuted)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: showNoteEditor ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(DesignToken.textFaint)
                }
                .padding(.horizontal, 16)
                .frame(height: 48)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(DesignToken.surfaceSoft.opacity(0.78)))
            }
            .buttonStyle(.plain)

            if showNoteEditor {
                TextField("写下这一刻的小故事", text: $note, axis: .vertical)
                    .textFieldStyle(.plain)
                    .focused($focusedField, equals: .note)
                    .lineLimit(4, reservesSpace: true)
                    .font(BBBFont.font(size: AchievementSheetTypography.noteSize, weight: .medium))
                    .foregroundStyle(DesignToken.textMuted)
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(DesignToken.surfaceSoft.opacity(0.78)))
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var completionTimeText: some View {
        Text(achievementDetailTimestampText(Date()))
            .font(BBBFont.font(size: AchievementSheetTypography.metaSize, weight: .semibold))
            .foregroundStyle(DesignToken.textFaint)
            .frame(maxWidth: .infinity)
    }

    private func saveAchievement() {
        guard let selectedMedia,
              selectedMedia.mediaKind == .photo || stickerPreview != nil else {
            errorMessage = "请先添加一张照片"
            return
        }
        isSaving = true
        Task {
            let livePhotoResources = await selectedMedia.resolvedLivePhotoResources()
            do {
                let achievement = try stickerStore.add(
                    templateID: template?.id,
                    name: name,
                    description: description,
                    note: note,
                    sourceImage: selectedMedia.image,
                    sourceOriginalImage: selectedMedia.canonicalSourceImage,
                    stickerImage: stickerPreview,
                    sourceAssetLocalIdentifier: selectedMedia.assetLocalIdentifier,
                    sourceAssetMediaSubtypeRawValue: selectedMedia.assetMediaSubtypeRawValue,
                    livePhotoStillURL: livePhotoResources?.stillURL,
                    livePhotoMovieURL: livePhotoResources?.movieURL,
                    mediaKind: selectedMedia.mediaKind,
                    filterPresetID: selectedMedia.filterPresetID,
                    watermarkStyleID: selectedMedia.watermarkStyleID,
                    cropState: selectedMedia.cropState
                )
                isSaving = false
                onCreated(achievement)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isSaving = false
            }
        }
    }

    private func generateStickerPreview(from media: AchievementStickerMedia?) {
        let currentGenerationID = UUID()
        generationID = currentGenerationID
        stickerPreview = nil
        guard let media else {
            isGeneratingSticker = false
            return
        }
        guard media.mediaKind == .sticker else {
            stickerPreview = nil
            isGeneratingSticker = false
            return
        }
        if let stickerImage = media.stickerImage {
            stickerPreview = stickerImage
            isGeneratingSticker = false
            return
        }
        isGeneratingSticker = true
        Task.detached(priority: .userInitiated) {
            let squareImage = media.image.squareCropped(maxSide: StickerGenerator.stickerInputMaxSide)
            let sticker = StickerGenerator.generateCompositeSticker(from: squareImage, quality: .full)
            await MainActor.run {
                guard generationID == currentGenerationID else { return }
                stickerPreview = sticker
                isGeneratingSticker = false
            }
        }
    }

    private func previewHeight(for availableHeight: CGFloat) -> CGFloat {
        min(max(availableHeight * 0.30, 220), 310)
    }

    private var canSaveAchievement: Bool {
        let hasCopy = template != nil || !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasMedia = selectedMedia.map { $0.mediaKind == .photo || stickerPreview != nil } ?? false
        return hasMedia && !isGeneratingSticker && !isSaving && hasCopy
    }
}

private struct AchievementDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var stickerStore: AchievementStickerStore
    let achievement: CustomAchievement
    let onDeleted: () -> Void
    @State private var note = ""
    @State private var showNoteEditor = false
    @State private var selectedMedia: AchievementStickerMedia?
    @State private var isGeneratingSticker = false
    @State private var showCamera = false
    @State private var showBindingEditor = false
    @State private var mediaToEdit: AchievementStickerMedia?
    @State private var showDeleteConfirmation = false
    @State private var errorMessage: String?
    @State private var generationID = UUID()

    var body: some View {
        NavigationStack {
            ZStack {
                achievementSoftBackground
                    .ignoresSafeArea()

                VStack(spacing: 18) {
                    stickerHero
                    detailCard
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 22)
                .padding(.top, 18)
                .padding(.bottom, 36)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        achievementCircleButtonIcon("chevron.left")
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Menu {
                        Button {
                            mediaToEdit = editableMedia
                        } label: {
                            Label("编辑图片", systemImage: "crop")
                        }

                        Button {
                            showCamera = true
                        } label: {
                            Label("更换图片", systemImage: "camera.fill")
                        }

                        if currentAchievement.resolvedMediaKind == .sticker {
                            Button {
                                regenerateStickerFromOriginal()
                            } label: {
                                Label("重新抠图", systemImage: "wand.and.stars")
                            }
                        }

                        Button {
                            showBindingEditor = true
                        } label: {
                            Label("编辑绑定", systemImage: "tag.fill")
                        }

                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label("删除成就", systemImage: "trash")
                        }
                    } label: {
                        achievementCircleButtonIcon("ellipsis")
                    }
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                AchievementCameraView(media: $selectedMedia)
            }
            .fullScreenCover(item: $mediaToEdit) { media in
                AchievementStoredMediaEditorHost(media: media) { updatedMedia in
                    updateStickerImage(from: updatedMedia)
                }
            }
            .sheet(isPresented: $showBindingEditor) {
                MilestoneAchievementBindingEditor(achievement: currentAchievement, note: note)
                    .environmentObject(stickerStore)
            }
            .alert("无法更新成就", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("好", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .confirmationDialog("删除这个成就？", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("删除", role: .destructive) {
                    deleteAchievement()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("删除后，这张贴纸和备注会从宝宝成就中移除。")
            }
            .onChange(of: selectedMedia) { _, newMedia in
                updateStickerImage(from: newMedia)
            }
            .onAppear {
                note = achievement.note
            }
            .onDisappear {
                stickerStore.updateNote(for: achievement, note: note)
            }
        }
    }

    private var stickerHero: some View {
        ZStack {
            AchievementInstaxCard(
                image: isGeneratingSticker ? nil : displayedHeroForegroundImage,
                backgroundImage: currentAchievement.resolvedMediaKind == .sticker
                    ? stickerStore.originalImage(for: currentAchievement)
                    : nil,
                mediaKind: currentAchievement.resolvedMediaKind,
                title: currentAchievement.name,
                subtitle: achievementDateText(currentAchievement.completedAt),
                width: 300,
                livePhotoResources: achievementLivePhotoResources(for: currentAchievement, store: stickerStore)
            )

            if isGeneratingSticker {
                ProgressView()
                    .tint(DesignToken.primary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 18)
    }

    private var displayedHeroForegroundImage: UIImage? {
        if currentAchievement.resolvedMediaKind == .photo {
            return stickerStore.originalImage(for: currentAchievement)
        }
        return stickerStore.stickerImage(for: currentAchievement)
    }

    private var currentAchievement: CustomAchievement {
        stickerStore.achievements.first(where: { $0.id == achievement.id }) ?? achievement
    }

    private var editableMedia: AchievementStickerMedia? {
        guard let renderedImage = stickerStore.originalImage(for: currentAchievement) else { return nil }
        let sourceImage = stickerStore.sourceImage(for: currentAchievement) ?? renderedImage
        let livePhotoURLs = stickerStore.livePhotoResourceURLs(for: currentAchievement)
        return AchievementStickerMedia(
            image: renderedImage,
            originalImage: sourceImage,
            stickerImage: stickerStore.stickerImage(for: currentAchievement),
            prefersStickerPreview: currentAchievement.resolvedMediaKind == .sticker,
            capturedAt: currentAchievement.completedAt,
            filterPresetID: currentAchievement.filterPresetID,
            watermarkStyleID: currentAchievement.watermarkStyleID,
            cropState: currentAchievement.cropState ?? .centered,
            assetLocalIdentifier: currentAchievement.sourceAssetLocalIdentifier,
            assetMediaSubtypeRawValue: currentAchievement.sourceAssetMediaSubtypeRawValue,
            livePhotoStillURL: livePhotoURLs?.still,
            livePhotoMovieURL: livePhotoURLs?.movie
        )
    }

    private func achievementDateText(_ date: Date) -> String {
        AppDateTimeFormat.date(date)
    }

    private var detailCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(currentAchievement.description.localized)
                .font(BBBFont.font(size: 14, weight: .medium))
                .foregroundStyle(DesignToken.textMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .frame(maxWidth: .infinity, alignment: .leading)

            achievementDetailNoteEditor
        }
    }

    private var achievementDetailNoteEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                    showNoteEditor.toggle()
                }
            } label: {
                HStack {
                    Text(note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "添加备注" : note)
                        .font(BBBFont.font(size: AchievementSheetTypography.noteSize, weight: .medium))
                        .foregroundStyle(DesignToken.textMuted)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: showNoteEditor ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(DesignToken.textFaint)
                }
                .padding(.horizontal, 16)
                .frame(height: 48)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(DesignToken.surfaceSoft.opacity(0.72)))
            }
            .buttonStyle(.plain)

            if showNoteEditor {
                TextField("写下这一刻的小故事", text: $note, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(4, reservesSpace: true)
                    .font(BBBFont.font(size: AchievementSheetTypography.noteSize, weight: .medium))
                    .foregroundStyle(DesignToken.textMuted)
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(DesignToken.surfaceSoft.opacity(0.78)))
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func updateStickerImage(from media: AchievementStickerMedia?) {
        let currentGenerationID = UUID()
        generationID = currentGenerationID
        guard let media else {
            isGeneratingSticker = false
            return
        }
        isGeneratingSticker = true
        Task.detached(priority: .userInitiated) {
            let sticker = media.mediaKind == .sticker
                ? (media.stickerImage ?? StickerGenerator.generateCompositeSticker(from: media.image))
                : nil
            let livePhotoResources = await media.resolvedLivePhotoResources()
            await MainActor.run {
                guard generationID == currentGenerationID else { return }
                do {
                    _ = try stickerStore.updateImage(
                        for: achievement,
                        sourceImage: media.image,
                        sourceOriginalImage: media.canonicalSourceImage,
                        stickerImage: sticker,
                        sourceAssetLocalIdentifier: media.assetLocalIdentifier,
                        sourceAssetMediaSubtypeRawValue: media.assetMediaSubtypeRawValue,
                        livePhotoStillURL: livePhotoResources?.stillURL,
                        livePhotoMovieURL: livePhotoResources?.movieURL,
                        mediaKind: media.mediaKind,
                        filterPresetID: media.filterPresetID,
                        watermarkStyleID: media.watermarkStyleID,
                        cropState: media.cropState
                    )
                } catch {
                    errorMessage = error.localizedDescription
                }
                isGeneratingSticker = false
            }
        }
    }

    private func regenerateStickerFromOriginal() {
        guard let originalImage = stickerStore.originalImage(for: achievement) else {
            errorMessage = "没有找到原图，请更换一张照片。"
            return
        }
        let currentGenerationID = UUID()
        generationID = currentGenerationID
        isGeneratingSticker = true
        Task.detached(priority: .userInitiated) {
            let squareImage = originalImage.squareCropped(maxSide: StickerGenerator.stickerInputMaxSide)
            let sticker = StickerGenerator.generateCompositeSticker(from: squareImage)
            await MainActor.run {
                guard generationID == currentGenerationID else { return }
                do {
                    _ = try stickerStore.updateImage(
                        for: achievement,
                        sourceImage: squareImage,
                        stickerImage: sticker
                    )
                } catch {
                    errorMessage = error.localizedDescription
                }
                isGeneratingSticker = false
            }
        }
    }

    private func deleteAchievement() {
        do {
            try stickerStore.delete(achievement)
            onDeleted()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct MilestoneAchievementBindingEditor: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var stickerStore: AchievementStickerStore

    let achievement: CustomAchievement
    let note: String

    @State private var selectedMilestoneID: String
    @State private var customName: String
    @State private var customDescription: String

    init(achievement: CustomAchievement, note: String) {
        self.achievement = achievement
        self.note = note
        let initialID = achievement.milestoneID ?? achievement.templateID ?? "custom"
        _selectedMilestoneID = State(initialValue: initialID)
        _customName = State(initialValue: achievement.name)
        _customDescription = State(initialValue: achievement.description)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                achievementSoftBackground
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        Picker("成就类型", selection: $selectedMilestoneID) {
                            Text("自定义成就").tag("custom")
                            ForEach(milestoneOptions) { milestone in
                                Text(optionTitle(milestone)).tag(milestone.id)
                            }
                        }
                        .pickerStyle(.inline)
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(DesignToken.surfaceRaised.opacity(0.78))
                        )

                        if selectedMilestoneID == "custom" {
                            customFields
                        } else if let milestone = AchievementMilestoneCatalog.milestone(id: selectedMilestoneID) {
                            milestonePreview(milestone)
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 60)
                }
            }
            .navigationTitle("编辑成就绑定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                }
            }
        }
    }

    private var milestoneOptions: [MilestoneDefinition] {
        AchievementMilestoneCatalog.all.sorted { lhs, rhs in
            let lhsOrder = lhs.targetDayOffset ?? (lhs.agePageIndex ?? 99_999) * 30
            let rhsOrder = rhs.targetDayOffset ?? (rhs.agePageIndex ?? 99_999) * 30
            return lhsOrder < rhsOrder
        }
    }

    private var customFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("成就名称", text: $customName)
                .textFieldStyle(.plain)
                .font(BBBFont.font(size: 18, weight: .heavy))
                .foregroundStyle(DesignToken.textPrimary)
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(DesignToken.surfaceSoft.opacity(0.86)))

            TextField("写一句成就描述", text: $customDescription, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(4, reservesSpace: true)
                .font(BBBFont.font(size: 14, weight: .medium))
                .foregroundStyle(DesignToken.textSecondary)
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(DesignToken.surfaceSoft.opacity(0.86)))
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(DesignToken.surfaceRaised.opacity(0.78)))
    }

    private func milestonePreview(_ milestone: MilestoneDefinition) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(milestone.title, systemImage: milestone.symbol)
                .font(BBBFont.font(size: 18, weight: .heavy))
                .foregroundStyle(DesignToken.textPrimary)
            Text(milestone.description.localized)
                .font(BBBFont.font(size: 14, weight: .medium))
                .foregroundStyle(DesignToken.textSecondary)
                .lineSpacing(4)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(DesignToken.surfaceRaised.opacity(0.78)))
    }

    private func optionTitle(_ milestone: MilestoneDefinition) -> String {
        if let offset = milestone.targetDayOffset {
            return "\(milestone.title) · 第 \(offset) 天"
        }
        if let page = milestone.agePageIndex {
            return "\(milestone.title) · \(page)-\(page + 1)月龄"
        }
        return milestone.title
    }

    private func save() {
        if selectedMilestoneID == "custom" {
            stickerStore.updateMetadata(
                for: achievement,
                templateID: nil,
                name: customName,
                description: customDescription,
                note: note,
                completedAt: achievement.completedAt,
                milestoneID: nil,
                milestoneKind: .custom,
                achievedDayOffset: achievement.achievedDayOffset,
                creationSource: .manual
            )
        } else if let milestone = AchievementMilestoneCatalog.milestone(id: selectedMilestoneID) {
            stickerStore.updateMetadata(
                for: achievement,
                templateID: milestone.id,
                name: milestone.title,
                description: milestone.description,
                note: note,
                completedAt: achievement.completedAt,
                milestoneID: milestone.id,
                milestoneKind: milestone.kind,
                achievedDayOffset: achievement.achievedDayOffset ?? milestone.targetDayOffset,
                creationSource: .manual
            )
        }
        dismiss()
    }
}

private enum AchievementCameraMode: String, CaseIterable, Identifiable {
    case photo
    case sticker

    var id: String { rawValue }

    var title: String {
        switch self {
        case .photo: return "照片"
        case .sticker: return "贴纸"
        }
    }
}

private enum AchievementCameraFilterPreset: String, CaseIterable, Identifiable {
    case original
    case polaroid
    case fujiNatural
    case fujiClassic
    case ricohPositive
    case warmFilm
    case mono
    case babySoft
    case portraitClean
    case gold200
    case coolChrome
    case dreamy
    case nightFlash

    var id: String { rawValue }

    var title: String {
        switch self {
        case .original: return "原图"
        case .polaroid: return "拍立得"
        case .fujiNatural: return "Fuji Natural"
        case .fujiClassic: return "Fuji Classic"
        case .ricohPositive: return "Ricoh Positive"
        case .warmFilm: return "Warm Film"
        case .mono: return "Mono"
        case .babySoft: return "Baby Soft"
        case .portraitClean: return "Portrait"
        case .gold200: return "Gold 200"
        case .coolChrome: return "Cool Chrome"
        case .dreamy: return "Dreamy"
        case .nightFlash: return "Night Flash"
        }
    }

    var iconAssetName: String? {
        switch self {
        case .original: return nil
        case .polaroid, .babySoft, .dreamy: return "camera_filter_polaroid"
        case .fujiNatural, .portraitClean: return "camera_filter_fuji_natural"
        case .fujiClassic, .nightFlash: return "camera_filter_fuji_classic"
        case .ricohPositive, .coolChrome: return "camera_filter_ricoh_positive"
        case .warmFilm, .gold200: return "camera_filter_warm_film"
        case .mono: return "camera_filter_mono"
        }
    }
}

private struct CameraFilterPresetCarousel: View {
    let selection: AchievementCameraFilterPreset
    let isDisabled: Bool
    let onSelect: (AchievementCameraFilterPreset) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(AchievementCameraFilterPreset.allCases) { preset in
                    filterButton(preset)
                }
            }
            .padding(.horizontal, 14)
        }
        .frame(height: 96)
    }

    private func filterButton(_ preset: AchievementCameraFilterPreset) -> some View {
        let isSelected = selection == preset
        return Button {
            onSelect(preset)
        } label: {
            VStack(spacing: 4) {
                filterIcon(preset)
                    .frame(width: 64, height: 64)
                    .scaleEffect(isSelected ? 1.04 : 1)

                Text(preset.title.localized)
                    .font(BBBFont.font(size: 11, weight: .heavy))
                    .foregroundStyle(isSelected ? AchievementMediaRenderPalette.stickerShadow : AchievementMediaRenderPalette.stickerOutline.opacity(0.88))
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                    .padding(.horizontal, 8)
                    .frame(maxWidth: 86)
                    .frame(height: 25)
                    .background(Capsule().fill(isSelected ? AchievementMediaRenderPalette.stickerOutline : Color.clear))
            }
            .frame(width: 86, height: 94)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.58 : 1)
        .accessibilityLabel("\(preset.title)滤镜")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .animation(.easeOut(duration: 0.16), value: isSelected)
    }

    @ViewBuilder
    private func filterIcon(_ preset: AchievementCameraFilterPreset) -> some View {
        if let assetName = preset.iconAssetName {
            Image(assetName)
                .resizable()
                .scaledToFit()
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AchievementMediaRenderPalette.filterPreviewCanvas)
                Image(systemName: "camera.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(AchievementMediaRenderPalette.stickerOutline.opacity(0.92))
            }
            .padding(5)
        }
    }
}

private enum CameraFilterPipeline {
    private static let preparationLock = NSLock()
    private static var hasPreparedCameraResources = false

    static func prepareForCamera() {
        preparationLock.lock()
        defer { preparationLock.unlock() }
        guard !hasPreparedCameraResources else {
            return
        }
        Shared.shared.advanceSetupDevice()
        Shared.shared.prewarmTexturePool(
            resolutions: [(width: 720, height: 720, pixelFormat: .bgra8Unorm)],
            count: 3
        )
        hasPreparedCameraResources = true
    }

    static func apply(_ preset: AchievementCameraFilterPreset, to image: UIImage) -> UIImage {
        let normalizedImage = image.normalized()
        guard preset != .original else { return normalizedImage }
        let filters = filters(for: preset)
        guard !filters.isEmpty else { return normalizedImage }
        var pipeline = HarbethIO(element: normalizedImage, filters: filters)
        pipeline.enableDoubleBuffer = shouldEnableDoubleBuffer(filterCount: filters.count)
        return pipeline.filtered()
    }

    static func configurePreview(
        _ pipeline: inout HarbethIO<MTLTexture>,
        filterCount: Int
    ) {
        pipeline.bufferPixelFormat = .bgra8Unorm
        // The MTKView consumes this texture through a separate CI command queue.
        // Wait for Harbeth's command buffer to finish so every preset is visible,
        // instead of racing a texture whose GPU writes are only scheduled.
        pipeline.transmitOutputRealTimeCommit = false
        pipeline.enableDoubleBuffer = shouldEnableDoubleBuffer(filterCount: filterCount)
    }

    private static func shouldEnableDoubleBuffer(filterCount: Int) -> Bool {
        filterCount > 3
    }

    static func filters(for preset: AchievementCameraFilterPreset) -> [C7FilterProtocol] {
        switch preset {
        case .original:
            return []
        case .polaroid:
            return [
                C7Warmth(warmth: 0.08),
                C7Contrast(contrast: 1.06),
                C7Saturation(saturation: 0.96),
                C7Granularity(grain: 0.10),
                C7Vignette(start: 0.48, end: 0.90, color: .zero)
            ]
        case .fujiNatural:
            return [
                C7Warmth(warmth: -0.02),
                C7Contrast(contrast: 1.03),
                C7Saturation(saturation: 1.07)
            ]
        case .fujiClassic:
            return [
                C7Warmth(warmth: 0.03),
                C7Contrast(contrast: 1.12),
                C7Saturation(saturation: 0.91),
                C7Granularity(grain: 0.12)
            ]
        case .ricohPositive:
            return [
                C7Contrast(contrast: 1.08),
                C7Saturation(saturation: 1.12),
                C7Warmth(warmth: 0.02)
            ]
        case .warmFilm:
            return [
                C7Warmth(warmth: 0.14),
                C7Contrast(contrast: 1.04),
                C7Saturation(saturation: 0.95),
                C7Granularity(grain: 0.08),
                C7Vignette(start: 0.52, end: 0.94, color: .zero)
            ]
        case .mono:
            return [
                C7Grayed(),
                C7Contrast(contrast: 1.08),
                C7Granularity(grain: 0.06)
            ]
        case .babySoft:
            return [
                C7DetailPreservingBlur(strength: 0.08, detailPreservation: 0.88),
                C7Brightness(brightness: 0.035),
                C7Warmth(warmth: 0.06),
                C7Contrast(contrast: 0.94),
                C7Saturation(saturation: 0.94),
                C7Fade(intensity: 0.025)
            ]
        case .portraitClean:
            return [
                C7Exposure(exposure: 0.08),
                C7Warmth(warmth: 0.035),
                C7Contrast(contrast: 1.02),
                C7Vibrance(vibrance: 0.08),
                C7EdgeAwareSharpen(amount: 0.10, edgeThreshold: 0.55)
            ]
        case .gold200:
            return [
                C7Warmth(warmth: 0.11),
                C7Contrast(contrast: 1.07),
                C7Saturation(saturation: 1.08),
                C7Granularity(grain: 0.08),
                C7Vignette(start: 0.50, end: 0.93, color: .zero)
            ]
        case .coolChrome:
            return [
                C7Temperature(temperature: -0.10, tint: -0.02),
                C7Contrast(contrast: 1.10),
                C7Saturation(saturation: 0.88),
                C7Granularity(grain: 0.055)
            ]
        case .dreamy:
            return [
                C7Brightness(brightness: 0.04),
                C7Warmth(warmth: 0.05),
                C7Contrast(contrast: 0.90),
                C7Saturation(saturation: 0.92),
                C7Fade(intensity: 0.055)
            ]
        case .nightFlash:
            return [
                C7Exposure(exposure: 0.12),
                C7LuminanceAdaptiveContrast(amount: 0.14, adaptivity: 0.72),
                C7Contrast(contrast: 1.16),
                C7Saturation(saturation: 0.94),
                C7Gamma(gamma: 0.95),
                C7Vignette(start: 0.38, end: 0.84, color: .zero)
            ]
        }
    }
}

private enum AchievementCameraAdjustment: String, Identifiable {
    case temperature
    case zoom
    case exposure

    var id: String { rawValue }
}

private enum AchievementCameraGridStyle: String, CaseIterable, Identifiable {
    case off
    case thirds
    case center

    var id: String { rawValue }
}

private struct AchievementCameraGridOverlay: View {
    let style: AchievementCameraGridStyle

    var body: some View {
        GeometryReader { proxy in
            Path { path in
                switch style {
                case .off:
                    break
                case .thirds:
                    for fraction in [CGFloat(1) / 3, CGFloat(2) / 3] {
                        path.move(to: CGPoint(x: proxy.size.width * fraction, y: 0))
                        path.addLine(to: CGPoint(x: proxy.size.width * fraction, y: proxy.size.height))
                        path.move(to: CGPoint(x: 0, y: proxy.size.height * fraction))
                        path.addLine(to: CGPoint(x: proxy.size.width, y: proxy.size.height * fraction))
                    }
                case .center:
                    path.move(to: CGPoint(x: proxy.size.width / 2, y: 0))
                    path.addLine(to: CGPoint(x: proxy.size.width / 2, y: proxy.size.height))
                    path.move(to: CGPoint(x: 0, y: proxy.size.height / 2))
                    path.addLine(to: CGPoint(x: proxy.size.width, y: proxy.size.height / 2))
                }
            }
            .stroke(AchievementMediaRenderPalette.stickerOutline.opacity(0.42), lineWidth: 0.7)
        }
        .allowsHitTesting(false)
    }
}

private struct AchievementWatermarkView: View {
    let style: AchievementWatermarkStyle
    let dateText: String
    let ageText: String

    var body: some View {
        Group {
            switch style {
            case .off:
                EmptyView()
            case .minimal:
                HStack(spacing: 5) {
                    Text(ageText)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                    Circle()
                        .fill(AchievementMediaRenderPalette.stickerOutline.opacity(0.72))
                        .frame(width: 3, height: 3)
                    Text(dateText)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                }
            case .stacked:
                VStack(alignment: .leading, spacing: 1) {
                    Text(ageText).font(.system(size: 15, weight: .bold, design: .rounded))
                    Text(dateText).font(.system(size: 9, weight: .medium, design: .monospaced))
                }
            case .film:
                Text(dateText.replacingOccurrences(of: ".", with: "  "))
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(AchievementMediaRenderPalette.watermarkGold)
            case .ageFocus:
                Text(ageText)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
        }
        .foregroundStyle(AchievementMediaRenderPalette.stickerOutline.opacity(0.94))
        .padding(.horizontal, style == .off ? 0 : 9)
        .padding(.vertical, style == .off ? 0 : 7)
        .background(
            style == .off ? Color.clear : AchievementMediaRenderPalette.stickerShadow.opacity(0.44),
            in: RoundedRectangle(cornerRadius: 6, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(style == .off ? Color.clear : AchievementMediaRenderPalette.stickerOutline.opacity(0.16), lineWidth: 0.7)
        )
        .shadow(color: AchievementMediaRenderPalette.stickerShadow.opacity(0.32), radius: 2, y: 1)
    }
}

private struct CameraFilterCatalogView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: AchievementCameraFilterPreset

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 18), count: 3)

    var body: some View {
        NavigationStack {
            ZStack {
                AchievementMediaRenderPalette.stickerShadow.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: columns, spacing: 24) {
                        ForEach(AchievementCameraFilterPreset.allCases) { preset in
                            Button {
                                selection = preset
                                dismiss()
                            } label: {
                                VStack(spacing: 8) {
                                    filterIcon(preset)
                                        .frame(width: 76, height: 76)
                                    Text(preset.title.localized)
                                        .font(BBBFont.font(size: 12, weight: .heavy))
                                        .foregroundStyle(AchievementMediaRenderPalette.stickerOutline)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.72)
                                    Image(systemName: selection == preset ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selection == preset ? DesignToken.primary : AchievementMediaRenderPalette.stickerOutline.opacity(0.35))
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(24)
                }
            }
            .navigationTitle("选择滤镜")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func filterIcon(_ preset: AchievementCameraFilterPreset) -> some View {
        Image(preset.iconAssetName ?? "camera_filter_polaroid")
            .resizable()
            .scaledToFit()
    }
}

private struct AchievementCameraView: View {
    @Environment(BabyProfileStore.self) private var profileStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @Binding var media: AchievementStickerMedia?
    let onCaptured: ((AchievementStickerMedia) -> Void)?
    @StateObject private var camera = AchievementCameraModel()
    @State private var selectedItem: PhotosPickerItem?
    @State private var mode: AchievementCameraMode = .photo
    @State private var selectedFilter: AchievementCameraFilterPreset = .original
    @State private var isProcessingCapture = false
    @State private var shutterFlashVisible = false
    @State private var activeAdjustment: AchievementCameraAdjustment?
    @State private var showFilterCatalog = false
    @State private var focusPoint: CGPoint?
    @State private var zoomAtGestureStart: CGFloat = 1
    @State private var livePhotoToastMessage: String?
    @State private var livePhotoToastGeneration = UUID()
    @State private var didInitializeCameraDefaults = false
    @State private var isCameraSurfaceVisible = false
    @State private var captureProcessingToken = UUID()
    @AppStorage("achievement_camera_mode_v2") private var storedMode = AchievementCameraMode.photo.rawValue
    @AppStorage("achievement_camera_watermark_v2") private var storedWatermark = AchievementWatermarkStyle.ageFocus.rawValue
    @AppStorage("achievement_camera_grid_v1") private var storedGrid = AchievementCameraGridStyle.off.rawValue

    init(
        media: Binding<AchievementStickerMedia?>,
        onCaptured: ((AchievementStickerMedia) -> Void)? = nil
    ) {
        _media = media
        self.onCaptured = onCaptured
    }

    var body: some View {
        GeometryReader { proxy in
            let previewSide = min(proxy.size.width - 20, max(250, proxy.size.height * 0.49))

            ZStack {
                AchievementMediaRenderPalette.stickerShadow
                    .ignoresSafeArea()

                VStack(spacing: 10) {
                    topControls
                        .padding(.horizontal, 14)

                    Spacer(minLength: 8)
                    cameraPreview
                        .frame(height: previewSide)
                        .padding(.horizontal, 10)

                    controlShelf
                        .padding(.horizontal, 18)

                    Spacer(minLength: 10)

                    captureControls
                        .padding(.horizontal, 24)
                }
                .padding(.top, 6)
                .padding(.bottom, max(proxy.safeAreaInsets.bottom, 10))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                AchievementMediaRenderPalette.stickerOutline
                    .opacity(shutterFlashVisible ? 0.72 : 0)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .statusBarHidden(true)
        .onAppear {
            let shouldResume = didInitializeCameraDefaults && !isCameraSurfaceVisible
            isCameraSurfaceVisible = true
            guard shouldResume else { return }
            camera.previewRenderer.setRenderingEnabled(true)
            Task {
                await camera.configure()
            }
        }
        .task {
            camera.previewRenderer.setRenderingEnabled(true)
            let shouldResetCameraDefaults = !didInitializeCameraDefaults
            if shouldResetCameraDefaults {
                didInitializeCameraDefaults = true
                mode = AchievementCameraMode(rawValue: storedMode) ?? .photo
                selectedFilter = .original
                camera.previewRenderer.update(preset: .original)
            }
            Task.detached(priority: .utility) {
                CameraFilterPipeline.prepareForCamera()
            }
            await camera.configure(resetZoom: shouldResetCameraDefaults)
        }
        .onDisappear {
            isCameraSurfaceVisible = false
            captureProcessingToken = UUID()
            camera.previewRenderer.setRenderingEnabled(false)
            camera.stop()
        }
        .onChange(of: scenePhase) { _, phase in
            guard isCameraSurfaceVisible else { return }
            if phase == .active {
                camera.previewRenderer.setRenderingEnabled(true)
                Task {
                    await camera.configure()
                }
            } else {
                camera.previewRenderer.setRenderingEnabled(false)
                camera.stop()
            }
        }
        .onChange(of: selectedItem) { _, newItem in
            let selectedFilterSnapshot = selectedFilter
            let modeSnapshot = mode
            Task {
                if let pickedPhoto = await loadPhoto(from: newItem) {
                    processAndFinish(
                        image: pickedPhoto.image,
                        filter: selectedFilterSnapshot,
                        mode: modeSnapshot,
                        capturedAt: pickedPhoto.capturedAt,
                        assetLocalIdentifier: pickedPhoto.assetLocalIdentifier,
                        livePhotoStillURL: pickedPhoto.livePhotoStillURL,
                        livePhotoMovieURL: pickedPhoto.livePhotoMovieURL,
                        pendingLivePhotoResources: nil,
                        assetSubtypeRawValue: pickedPhoto.assetMediaSubtypeRawValue
                    )
                }
            }
        }
        .onChange(of: mode) { _, value in storedMode = value.rawValue }
        .onChange(of: selectedFilter) { _, value in
            camera.previewRenderer.update(preset: value)
        }
        .onChange(of: camera.isLivePhotoEnabled) { _, isEnabled in
            showLivePhotoToast(isEnabled ? "实况" : "关闭实况")
        }
        .fullScreenCover(isPresented: $showFilterCatalog) {
            CameraFilterCatalogView(selection: $selectedFilter)
        }
        .alert("拍摄失败", isPresented: Binding(
            get: { camera.captureErrorMessage != nil },
            set: { if !$0 { camera.captureErrorMessage = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            Text(camera.captureErrorMessage ?? "请重试。")
        }
    }

    private var topControls: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                cameraIconButton(systemName: "xmark")
            }
            .accessibilityLabel("关闭相机")

            Spacer()
        }
        .frame(height: 48)
    }

    private var cameraPreview: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                AchievementMediaRenderPalette.stickerShadow

                if let errorMessage = camera.errorMessage {
                    cameraUnavailableView(message: errorMessage)
                } else {
                    FilteredCameraPreviewView(
                        renderer: camera.previewRenderer,
                        preset: selectedFilter,
                        position: camera.activePosition
                    )
                }

                gridOverlay
                livePhotoToggle
                    .padding(12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                if let livePhotoToastMessage {
                    Text(livePhotoToastMessage)
                        .font(BBBFont.font(size: 13, weight: .heavy))
                        .foregroundStyle(AchievementMediaRenderPalette.stickerOutline)
                        .padding(.horizontal, 14)
                        .frame(height: 34)
                        .background(AchievementMediaRenderPalette.stickerShadow.opacity(0.62), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .padding(.top, 14)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        .allowsHitTesting(false)
                }
                watermarkOverlay
                    .padding(14)
                    .padding(.bottom, 42)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                previewToolRow
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                if let focusPoint {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(AchievementMediaRenderPalette.watermarkGold, lineWidth: 1.4)
                        .frame(width: 54, height: 54)
                        .position(focusPoint)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(Rectangle())
            .gesture(focusGesture(size: CGSize(width: side, height: side)))
            .simultaneousGesture(zoomGesture)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var modePicker: some View {
        HStack(spacing: 4) {
            ForEach(AchievementCameraMode.allCases) { mode in
                Button {
                    self.mode = mode
                } label: {
                    Text(mode.title.localized)
                        .font(BBBFont.font(size: 15, weight: .heavy))
                        .foregroundStyle(self.mode == mode ? AchievementMediaRenderPalette.stickerShadow : AchievementMediaRenderPalette.stickerOutline.opacity(0.76))
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: DesignToken.minimumTapSize)
                        .background(
                            Capsule()
                                .fill(self.mode == mode ? AchievementMediaRenderPalette.stickerOutline : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .disabled(isBusy)
            }
        }
        .padding(3)
        .frame(width: 158, height: 40)
        .background(Capsule().fill(AchievementMediaRenderPalette.stickerOutline.opacity(0.14)))
        .overlay(Capsule().stroke(AchievementMediaRenderPalette.stickerOutline.opacity(0.16), lineWidth: 1))
    }

    @ViewBuilder
    private var controlShelf: some View {
        if let activeAdjustment {
            adjustmentControl(activeAdjustment)
                .transition(.opacity)
        } else {
            HStack(spacing: 14) {
                modePicker
                Spacer(minLength: 0)
                Button {
                    camera.toggleFlash()
                } label: {
                    lineControlIcon(camera.flashMode == .off ? "bolt.slash" : "bolt", isActive: camera.flashMode != .off)
                }
                .disabled(!camera.isFlashAvailable || isBusy)

                Button {
                    camera.switchCamera()
                } label: {
                    lineControlIcon("camera.rotate")
                }
                .disabled(isBusy)
            }
            .frame(height: 48)
            .transition(.opacity)
        }
    }

    private func adjustmentControl(_ adjustment: AchievementCameraAdjustment) -> some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.easeOut(duration: 0.16)) { activeAdjustment = nil }
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 40, height: 40)
            }

            switch adjustment {
            case .temperature:
                Image(systemName: "thermometer.medium")
                Slider(
                    value: Binding(
                        get: { Double(camera.colorTemperature) },
                        set: { camera.setColorTemperature(Float($0)) }
                    ),
                    in: 3_000...8_000,
                    step: 100
                )
                Text("\(Int(camera.colorTemperature))K")
                    .frame(width: 58)
            case .zoom:
                ForEach(camera.supportedZoomFactors, id: \.self) { factor in
                    Button(zoomLabel(factor)) { camera.setZoomFactor(factor) }
                        .font(BBBFont.font(size: 13, weight: .heavy))
                        .foregroundStyle(abs(camera.zoomFactor - factor) < 0.05 ? AchievementMediaRenderPalette.stickerShadow : AchievementMediaRenderPalette.stickerOutline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(Capsule().fill(abs(camera.zoomFactor - factor) < 0.05 ? AchievementMediaRenderPalette.stickerOutline : AchievementMediaRenderPalette.stickerOutline.opacity(0.12)))
                }
            case .exposure:
                Image(systemName: "sun.max")
                Slider(
                    value: Binding(
                        get: { Double(camera.exposureBias) },
                        set: { camera.setExposureBias(Float($0)) }
                    ),
                    in: -2...2,
                    step: 0.1
                )
                Text(String(format: "%+.1f", camera.exposureBias))
                    .frame(width: 44)
            }
        }
        .font(BBBFont.font(size: 12, weight: .bold))
        .foregroundStyle(AchievementMediaRenderPalette.stickerOutline)
        .tint(AchievementMediaRenderPalette.stickerOutline)
        .frame(height: 48)
        .padding(.horizontal, 8)
        .background(AchievementMediaRenderPalette.stickerOutline.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
    }

    private var captureControls: some View {
        HStack(alignment: .center) {
            PhotosPicker(selection: $selectedItem, matching: .images) {
                cameraIconButton(systemName: "photo.badge.plus")
            }
            .disabled(isBusy)
            .accessibilityLabel("从相册选择照片")

            Spacer()

            Button {
                capturePhoto()
            } label: {
                ZStack {
                    Circle()
                        .stroke(AchievementMediaRenderPalette.stickerOutline.opacity(0.48), lineWidth: 6)
                        .frame(width: 86, height: 86)

                    Circle()
                        .fill(AchievementMediaRenderPalette.stickerOutline)
                        .frame(width: 68, height: 68)
                        .scaleEffect(camera.isCapturing ? 0.82 : 1)

                    if isBusy {
                        ProgressView()
                            .tint(AchievementMediaRenderPalette.stickerShadow)
                    }
                }
                .frame(width: 92, height: 92)
                .animation(.easeOut(duration: 0.12), value: camera.isCapturing)
            }
            .buttonStyle(.plain)
            .disabled(!camera.isConfigured || isBusy)
            .accessibilityLabel(isBusy ? "正在处理照片" : "拍摄")

            Spacer()

            Button {
                showFilterCatalog = true
            } label: {
                Image(selectedFilter.iconAssetName ?? "camera_filter_polaroid")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 52, height: 52)
                    .frame(width: 60, height: 60)
            }
            .buttonStyle(.plain)
            .disabled(isBusy)
            .accessibilityLabel("当前滤镜：\(selectedFilter.title)")
        }
        .frame(height: 98)
    }

    private func loadPhoto(from item: PhotosPickerItem?) async -> AchievementPickedPhoto? {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self) else {
            return nil
        }
        let imageTask = Task.detached(priority: .userInitiated) {
            Self.downsampledImage(data: data, maxPixelSize: 4_096)
        }
        guard let image = await imageTask.value else { return nil }

        guard let identifier = item.itemIdentifier,
              let asset = PHAsset.fetchAssets(
                withLocalIdentifiers: [identifier],
                options: nil
              ).firstObject else {
            return AchievementPickedPhoto(
                image: image,
                capturedAt: Date(),
                assetLocalIdentifier: nil,
                assetMediaSubtypeRawValue: nil,
                livePhotoStillURL: nil,
                livePhotoMovieURL: nil
            )
        }

        let liveResources = await Self.exportLivePhotoResources(from: asset)
        return AchievementPickedPhoto(
            image: image,
            capturedAt: asset.creationDate ?? Date(),
            assetLocalIdentifier: identifier,
            assetMediaSubtypeRawValue: asset.mediaSubtypes.rawValue,
            livePhotoStillURL: liveResources?.stillURL,
            livePhotoMovieURL: liveResources?.movieURL
        )
    }

    nonisolated private static func downsampledImage(data: Data, maxPixelSize: Int) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    nonisolated private static func exportLivePhotoResources(
        from asset: PHAsset
    ) async -> AchievementLivePhotoDraftResources? {
        guard asset.mediaSubtypes.contains(.photoLive) else { return nil }
        let resources = PHAssetResource.assetResources(for: asset)
        guard let still = resources.first(where: { $0.type == .photo || $0.type == .fullSizePhoto }),
              let movie = resources.first(where: { $0.type == .pairedVideo }) else {
            return nil
        }
        async let stillURL = exportAssetResource(still)
        async let movieURL = exportAssetResource(movie)
        guard let resolvedStillURL = await stillURL,
              let resolvedMovieURL = await movieURL else {
            return nil
        }
        return AchievementLivePhotoDraftResources(
            stillURL: resolvedStillURL,
            movieURL: resolvedMovieURL
        )
    }

    nonisolated private static func exportAssetResource(_ resource: PHAssetResource) async -> URL? {
        let fileExtension = URL(fileURLWithPath: resource.originalFilename).pathExtension
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("achievement-picker-\(UUID().uuidString)")
            .appendingPathExtension(fileExtension.isEmpty ? "dat" : fileExtension)
        return await withCheckedContinuation { continuation in
            PHAssetResourceManager.default().writeData(
                for: resource,
                toFile: url,
                options: nil
            ) { error in
                if error != nil {
                    try? FileManager.default.removeItem(at: url)
                    continuation.resume(returning: nil)
                } else {
                    continuation.resume(returning: url)
                }
            }
        }
    }

    private var livePhotoToggle: some View {
        Button {
            camera.toggleLivePhoto()
        } label: {
            Image(systemName: camera.isLivePhotoEnabled ? "livephoto" : "livephoto.slash")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(camera.isLivePhotoEnabled ? AchievementMediaRenderPalette.watermarkGold : AchievementMediaRenderPalette.stickerOutline.opacity(0.86))
                .frame(width: 42, height: 42)
                .background(AchievementMediaRenderPalette.stickerShadow.opacity(0.48), in: Circle())
                .overlay(Circle().stroke(AchievementMediaRenderPalette.stickerOutline.opacity(0.18), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!camera.isLivePhotoCaptureAvailable || isBusy)
        .opacity(camera.isLivePhotoCaptureAvailable ? 1 : 0.52)
        .accessibilityLabel(camera.isLivePhotoEnabled ? "关闭实况" : "开启实况")
        .accessibilityValue(camera.isLivePhotoEnabled ? "已开启" : "已关闭")
    }

    private func showLivePhotoToast(_ message: String) {
        let generation = UUID()
        livePhotoToastGeneration = generation
        withAnimation(.easeOut(duration: 0.16)) {
            livePhotoToastMessage = message
        }
        Task {
            try? await Task.sleep(for: .seconds(1.1))
            guard livePhotoToastGeneration == generation else { return }
            withAnimation(.easeIn(duration: 0.18)) {
                livePhotoToastMessage = nil
            }
        }
    }

    private var gridStyle: AchievementCameraGridStyle {
        AchievementCameraGridStyle(rawValue: storedGrid) ?? .off
    }

    private var watermarkStyle: AchievementWatermarkStyle {
        AchievementWatermarkStyle(rawValue: storedWatermark) ?? .ageFocus
    }

    private var gridOverlay: some View {
        AchievementCameraGridOverlay(style: gridStyle)
    }

    private var watermarkOverlay: some View {
        AchievementWatermarkView(
            style: watermarkStyle,
            dateText: cameraDateText(Date()),
            ageText: cameraBabyAgeText
        )
    }

    private var previewToolRow: some View {
        HStack(spacing: 8) {
            Menu {
                ForEach(AchievementCameraGridStyle.allCases) { style in
                    Button {
                        storedGrid = style.rawValue
                    } label: {
                        Label(gridTitle(style), systemImage: gridStyle == style ? "checkmark" : "grid")
                    }
                }
            } label: {
                previewToolIcon("grid")
            }

            Menu {
                ForEach(AchievementWatermarkStyle.allCases, id: \.self) { style in
                    Button {
                        storedWatermark = style.rawValue
                    } label: {
                        Label(watermarkTitle(style), systemImage: watermarkStyle == style ? "checkmark" : "calendar")
                    }
                }
            } label: {
                previewToolIcon("calendar.badge.clock")
            }

            Button { openAdjustment(.temperature) } label: { previewToolIcon("thermometer.medium") }
            Button { openAdjustment(.zoom) } label: {
                Text(zoomLabel(camera.zoomFactor))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(AchievementMediaRenderPalette.stickerOutline)
                    .frame(width: 42, height: 34)
                    .background(AchievementMediaRenderPalette.stickerShadow.opacity(0.44), in: Capsule())
            }
            Button { openAdjustment(.exposure) } label: { previewToolIcon("sun.max") }
        }
        .buttonStyle(.plain)
    }

    private var cameraMetadataOverlay: some View {
        VStack(spacing: 3) {
            Text(cameraDateText(Date()))
                .font(BBBFont.font(size: 12, weight: .heavy))
            Text(cameraBabyAgeText)
                .font(BBBFont.font(size: 11, weight: .bold))
        }
        .foregroundStyle(AchievementMediaRenderPalette.stickerOutline.opacity(0.86))
        .padding(.horizontal, 12)
        .frame(height: 44)
        .background(Capsule().fill(AchievementMediaRenderPalette.stickerShadow.opacity(0.42)))
    }

    private var cameraBabyAgeText: String {
        BabyAgeFormatter.displayText(
            birthDate: profileStore.currentProfile.birthDate,
            on: Date()
        )
    }

    private func cameraDateText(_ date: Date) -> String {
        AppDateTimeFormat.date(date)
    }

    private func cameraIconButton(systemName: String, isActive: Bool = false) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(isActive ? AchievementMediaRenderPalette.stickerShadow : AchievementMediaRenderPalette.stickerOutline)
            .frame(width: 46, height: 46)
            .background(Circle().fill(isActive ? AchievementMediaRenderPalette.stickerOutline : AchievementMediaRenderPalette.stickerOutline.opacity(0.14)))
    }

    private var isBusy: Bool {
        camera.isCapturing || camera.isSwitchingCamera || camera.isPreparingLivePhoto || isProcessingCapture
    }

    private func openAdjustment(_ adjustment: AchievementCameraAdjustment) {
        withAnimation(.easeOut(duration: 0.16)) { activeAdjustment = adjustment }
    }

    private func previewToolIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(AchievementMediaRenderPalette.stickerOutline)
            .frame(width: 38, height: 34)
            .background(AchievementMediaRenderPalette.stickerShadow.opacity(0.44), in: Capsule())
    }

    private func lineControlIcon(_ systemName: String, isActive: Bool = false) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 19, weight: .medium))
            .foregroundStyle(isActive ? AchievementMediaRenderPalette.stickerShadow : AchievementMediaRenderPalette.stickerOutline)
            .frame(width: 44, height: 44)
            .background(isActive ? AchievementMediaRenderPalette.stickerOutline : AchievementMediaRenderPalette.stickerOutline.opacity(0.12), in: Circle())
    }

    private func focusGesture(size: CGSize) -> some Gesture {
        SpatialTapGesture()
            .onEnded { value in
                focusPoint = value.location
                camera.focus(at: CGPoint(
                    x: min(max(value.location.y / size.height, 0), 1),
                    y: min(max(1 - value.location.x / size.width, 0), 1)
                ))
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation(.easeOut(duration: 0.18)) { focusPoint = nil }
                }
            }
    }

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                camera.setZoomFactor(zoomAtGestureStart * value.magnification, ramped: false)
            }
            .onEnded { _ in zoomAtGestureStart = camera.zoomFactor }
    }

    private func zoomLabel(_ factor: CGFloat) -> String {
        let displayed = factor * camera.displayZoomMultiplier
        return abs(displayed.rounded() - displayed) < 0.01
            ? "\(Int(displayed.rounded()))x"
            : String(format: "%.1fx", displayed)
    }

    private func gridTitle(_ style: AchievementCameraGridStyle) -> String {
        switch style {
        case .off: return "关闭参考线"
        case .thirds: return "三分线"
        case .center: return "中心十字"
        }
    }

    private func watermarkTitle(_ style: AchievementWatermarkStyle) -> String {
        switch style {
        case .off: return "关闭水印"
        case .minimal: return "月龄与日期"
        case .stacked: return "月龄日期两行"
        case .film: return "仅日期"
        case .ageFocus: return "仅月龄"
        }
    }

    private func capturePhoto() {
        guard camera.isConfigured, !isBusy else { return }
        let selectedFilterSnapshot = selectedFilter
        let modeSnapshot = mode
        withAnimation(.easeOut(duration: 0.08)) {
            shutterFlashVisible = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
            withAnimation(.easeIn(duration: 0.16)) {
                shutterFlashVisible = false
            }
        }

        camera.capture { capturedMedia in
            processAndFinish(
                image: capturedMedia.image,
                filter: selectedFilterSnapshot,
                mode: modeSnapshot,
                capturedAt: Date(),
                assetLocalIdentifier: nil,
                livePhotoStillURL: capturedMedia.livePhotoStillURL,
                livePhotoMovieURL: capturedMedia.livePhotoMovieURL,
                pendingLivePhotoResources: capturedMedia.pendingLivePhotoResources,
                assetSubtypeRawValue: capturedMedia.isLivePhoto ? PHAssetMediaSubtype.photoLive.rawValue : nil
            )
        }
    }

    private func processAndFinish(
        image: UIImage,
        filter: AchievementCameraFilterPreset,
        mode: AchievementCameraMode,
        capturedAt: Date,
        assetLocalIdentifier: String?,
        livePhotoStillURL: URL?,
        livePhotoMovieURL: URL?,
        pendingLivePhotoResources: AchievementLivePhotoResourceCoordinator?,
        assetSubtypeRawValue: UInt?
    ) {
        guard isCameraSurfaceVisible, !isProcessingCapture else { return }
        let processingToken = UUID()
        captureProcessingToken = processingToken
        let prefersStickerPreview = mode == .sticker
        let watermarkStyleSnapshot = watermarkStyle
        let dateTextSnapshot = cameraDateText(Date())
        let ageTextSnapshot = cameraBabyAgeText
        isProcessingCapture = true

        Task.detached(priority: .userInitiated) {
            let processedMedia = Self.makeMedia(
                from: image,
                filter: filter,
                prefersStickerPreview: prefersStickerPreview,
                capturedAt: capturedAt,
                assetLocalIdentifier: assetLocalIdentifier,
                watermarkStyle: watermarkStyleSnapshot,
                dateText: dateTextSnapshot,
                ageText: ageTextSnapshot,
                livePhotoStillURL: livePhotoStillURL,
                livePhotoMovieURL: livePhotoMovieURL,
                pendingLivePhotoResources: pendingLivePhotoResources,
                assetSubtypeRawValue: assetSubtypeRawValue
            )
            await MainActor.run {
                guard captureProcessingToken == processingToken else { return }
                isProcessingCapture = false
                if let onCaptured {
                    onCaptured(processedMedia)
                } else {
                    media = processedMedia
                    dismiss()
                }
            }
        }
    }

    nonisolated private static func makeMedia(
        from image: UIImage,
        filter: AchievementCameraFilterPreset,
        prefersStickerPreview: Bool,
        capturedAt: Date,
        assetLocalIdentifier: String?,
        watermarkStyle: AchievementWatermarkStyle,
        dateText: String,
        ageText: String,
        livePhotoStillURL: URL?,
        livePhotoMovieURL: URL?,
        pendingLivePhotoResources: AchievementLivePhotoResourceCoordinator?,
        assetSubtypeRawValue: UInt?
    ) -> AchievementStickerMedia {
        let signpostID = OSSignpostID(log: achievementCameraPerformanceLog)
        os_signpost(.begin, log: achievementCameraPerformanceLog, name: "FinalFilterRender", signpostID: signpostID)
        defer {
            os_signpost(.end, log: achievementCameraPerformanceLog, name: "FinalFilterRender", signpostID: signpostID)
        }
        let squarePhoto = image.squareCropped(maxSide: StickerGenerator.stickerInputMaxSide)
        let filteredPhoto = CameraFilterPipeline.apply(filter, to: squarePhoto)
        let renderedPhoto = filteredPhoto.addingAchievementWatermark(
            style: watermarkStyle,
            dateText: dateText,
            ageText: ageText
        )
        return AchievementStickerMedia(
            image: renderedPhoto,
            originalImage: image.normalized(),
            stickerImage: nil,
            prefersStickerPreview: prefersStickerPreview,
            capturedAt: capturedAt,
            filterPresetID: filter.rawValue,
            watermarkStyleID: watermarkStyle.rawValue,
            cropState: .centered,
            assetLocalIdentifier: assetLocalIdentifier,
            assetMediaSubtypeRawValue: assetSubtypeRawValue,
            livePhotoStillURL: livePhotoStillURL,
            livePhotoMovieURL: livePhotoMovieURL,
            pendingLivePhotoResources: pendingLivePhotoResources
        )
    }

    @ViewBuilder
    private func cameraUnavailableView(message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "camera.fill")
                .font(.system(size: 28, weight: .semibold))
            Text(message.localized)
                .font(BBBFont.font(size: 14, weight: .semibold))
                .multilineTextAlignment(.center)
            if camera.canOpenSettingsForError {
                Button("前往设置") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
                .font(BBBFont.font(size: 14, weight: .heavy))
                .foregroundStyle(AchievementMediaRenderPalette.stickerShadow)
                .padding(.horizontal, 16)
                .frame(minHeight: DesignToken.minimumTapSize)
                .background(Capsule().fill(AchievementMediaRenderPalette.stickerOutline))
            }
        }
        .foregroundStyle(AchievementMediaRenderPalette.stickerOutline.opacity(0.82))
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private extension UIImage {
    func addingAchievementWatermark(
        style: AchievementWatermarkStyle,
        dateText: String,
        ageText: String
    ) -> UIImage {
        guard style != .off else { return self }
        let source = normalized()
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = source.scale
        let renderer = UIGraphicsImageRenderer(size: source.size, format: format)
        return renderer.image { context in
            source.draw(in: CGRect(origin: .zero, size: source.size))
            let unit = max(source.size.width / 900, 0.7)
            let margin = 28 * unit
            let white = AchievementMediaRenderPalette.watermarkForeground.withAlphaComponent(0.95)
            let yellow = AchievementMediaRenderPalette.watermarkGoldUIColor
            let shadow = NSShadow()
            shadow.shadowColor = AchievementMediaRenderPalette.watermarkShadow.withAlphaComponent(0.58)
            shadow.shadowBlurRadius = 3 * unit
            shadow.shadowOffset = CGSize(width: 0, height: unit)

            func attributes(size: CGFloat, color: UIColor = white, monospaced: Bool = false) -> [NSAttributedString.Key: Any] {
                let font = monospaced
                    ? UIFont.monospacedSystemFont(ofSize: size * unit, weight: .semibold)
                    : UIFont.systemFont(ofSize: size * unit, weight: .semibold)
                return [.font: font, .foregroundColor: color, .shadow: shadow]
            }

            let lines: [(String, [NSAttributedString.Key: Any])]
            switch style {
            case .minimal:
                lines = [("\(ageText)  ·  \(dateText)", attributes(size: 18))]
            case .stacked:
                lines = [
                    (ageText, attributes(size: 27)),
                    (dateText, attributes(size: 15, monospaced: true))
                ]
            case .film:
                lines = [(dateText.replacingOccurrences(of: ".", with: "  "), attributes(size: 17, color: yellow, monospaced: true))]
            case .ageFocus:
                lines = [(ageText, attributes(size: 28))]
            case .off:
                return
            }

            let measured = lines.map { ($0.0 as NSString).size(withAttributes: $0.1) }
            let lineSpacing = 3 * unit
            let totalHeight = measured.reduce(0) { $0 + $1.height } + CGFloat(max(lines.count - 1, 0)) * lineSpacing
            let maxWidth = measured.map(\.width).max() ?? 0
            let originY = source.size.height - margin - totalHeight

            let background = CGRect(
                x: margin - 12 * unit,
                y: originY - 9 * unit,
                width: maxWidth + 24 * unit,
                height: totalHeight + 18 * unit
            )
            context.cgContext.setFillColor(AchievementMediaRenderPalette.watermarkShadow.withAlphaComponent(0.44).cgColor)
            UIBezierPath(roundedRect: background, cornerRadius: 7 * unit).fill()
            context.cgContext.setStrokeColor(AchievementMediaRenderPalette.watermarkForeground.withAlphaComponent(0.16).cgColor)
            context.cgContext.setLineWidth(0.8 * unit)
            UIBezierPath(roundedRect: background, cornerRadius: 7 * unit).stroke()

            var y = originY
            for (index, line) in lines.enumerated() {
                (line.0 as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: line.1)
                y += measured[index].height + lineSpacing
            }
        }
    }
}

private final class AchievementCameraModel: NSObject, ObservableObject {
    let session = AVCaptureSession()
    let previewRenderer = FilteredCameraPreviewRenderer()
    @MainActor @Published var isConfigured = false
    @MainActor @Published var isCapturing = false
    @MainActor @Published var isSwitchingCamera = false
    @MainActor @Published var isLivePhotoCaptureAvailable = false
    @MainActor @Published var isLivePhotoEnabled = false
    @MainActor @Published var isPreparingLivePhoto = false
    @MainActor @Published var isFlashAvailable = false
    @MainActor @Published var flashMode: AVCaptureDevice.FlashMode = .off
    @MainActor @Published var activePosition: AVCaptureDevice.Position = .back
    @MainActor @Published var zoomFactor: CGFloat = 1
    @MainActor @Published var displayZoomMultiplier: CGFloat = 1
    @MainActor @Published var supportedZoomFactors: [CGFloat] = [1]
    @MainActor @Published var exposureBias: Float = 0
    @MainActor @Published var colorTemperature: Float = 5_000
    @MainActor @Published var errorMessage: String?
    @MainActor @Published var canOpenSettingsForError = false
    @MainActor @Published var captureErrorMessage: String?

    private let sessionQueue = DispatchQueue(label: "babybuddy.achievement.camera.session")
    private let previewQueue = DispatchQueue(label: "babybuddy.achievement.camera.preview", qos: .userInteractive)
    private let output = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private var currentInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?
    private var captureCompletion: ((AchievementCameraCapture) -> Void)?
    private var activeCaptureID: Int64?
    private var livePhotoCaptureSupported = false
    private var pendingCaptures: [Int64: PendingPhotoCapture] = [:]
    private var livePhotoResourceCoordinators: [Int64: AchievementLivePhotoResourceCoordinator] = [:]
    private let lifecycleLock = NSLock()
    private var configurationGeneration = 0
    private var isStopped = true

    func configure(resetZoom: Bool = false) async {
        let generation = beginConfigurationGeneration()
        os_signpost(.event, log: achievementCameraPerformanceLog, name: "ConfigureRequested")
        let authorized = await requestAccessIfNeeded()
        guard !Task.isCancelled, isConfigurationCurrent(generation) else { return }
        guard authorized else {
            await MainActor.run {
                guard self.isConfigurationCurrent(generation) else { return }
                errorMessage = "未获得相机权限，请在系统设置中允许访问相机。"
                canOpenSettingsForError = true
            }
            return
        }

        await withCheckedContinuation { continuation in
            sessionQueue.async {
                guard self.isConfigurationCurrent(generation) else {
                    continuation.resume()
                    return
                }
                self.configureSession(generation: generation, resetZoom: resetZoom)
                continuation.resume()
            }
        }
    }

    func stop() {
        invalidateConfigurationGeneration()
        sessionQueue.async {
            self.videoOutput.setSampleBufferDelegate(nil, queue: nil)
            self.discardUndeliveredCaptures()
            if self.session.isRunning {
                self.session.stopRunning()
            }
            Task { @MainActor in
                guard self.configurationIsStopped() else { return }
                self.isConfigured = false
                self.isCapturing = false
                self.isSwitchingCamera = false
                self.isPreparingLivePhoto = false
            }
        }
    }

    private func beginConfigurationGeneration() -> Int {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }
        configurationGeneration &+= 1
        isStopped = false
        return configurationGeneration
    }

    private func invalidateConfigurationGeneration() {
        lifecycleLock.lock()
        configurationGeneration &+= 1
        isStopped = true
        lifecycleLock.unlock()
    }

    private func isConfigurationCurrent(_ generation: Int) -> Bool {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }
        return !isStopped && generation == configurationGeneration
    }

    private func configurationIsStopped() -> Bool {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }
        return isStopped
    }

    private func activeConfigurationGeneration() -> Int? {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }
        return isStopped ? nil : configurationGeneration
    }

    @MainActor
    func capture(completion: @escaping (AchievementCameraCapture) -> Void) {
        guard isConfigured,
              !isCapturing,
              let generation = activeConfigurationGeneration() else {
            return
        }
        os_signpost(.event, log: achievementCameraPerformanceLog, name: "ShutterRequested")
        isCapturing = true
        captureErrorMessage = nil
        let flashModeSnapshot = flashMode
        let wantsLivePhoto = isLivePhotoEnabled
        sessionQueue.async { [weak self] in
            self?.startPhotoCapture(
                generation: generation,
                flashMode: flashModeSnapshot,
                wantsLivePhoto: wantsLivePhoto,
                completion: completion
            )
        }
    }

    private func startPhotoCapture(
        generation: Int,
        flashMode: AVCaptureDevice.FlashMode,
        wantsLivePhoto: Bool,
        completion: @escaping (AchievementCameraCapture) -> Void
    ) {
        guard isConfigurationCurrent(generation), session.isRunning else {
            publishCaptureFailure(generation: generation, message: "相机尚未准备好，请稍后重试。")
            return
        }
        let settings = AVCapturePhotoSettings()
        settings.photoQualityPrioritization = .balanced
        if let previewPixelFormat = settings.availablePreviewPhotoPixelFormatTypes.first {
            settings.previewPhotoFormat = [
                kCVPixelBufferPixelFormatTypeKey as String: previewPixelFormat
            ]
        }
        if output.supportedFlashModes.contains(flashMode) {
            settings.flashMode = flashMode
        }
        if output.maxPhotoDimensions.width > 0, output.maxPhotoDimensions.height > 0 {
            settings.maxPhotoDimensions = output.maxPhotoDimensions
        }
        if livePhotoCaptureSupported,
           output.isLivePhotoCaptureEnabled,
           wantsLivePhoto {
            settings.livePhotoMovieFileURL = Self.makeLivePhotoMovieURL()
        }
        let livePhotoCoordinator = settings.livePhotoMovieFileURL.map { _ in
            AchievementLivePhotoResourceCoordinator()
        }
        pendingCaptures[settings.uniqueID] = PendingPhotoCapture(
            generation: generation,
            requestedLivePhotoMovieURL: settings.livePhotoMovieFileURL,
            isLiveRequested: livePhotoCoordinator != nil,
            livePhotoCoordinator: livePhotoCoordinator
        )
        if let livePhotoCoordinator {
            livePhotoResourceCoordinators[settings.uniqueID] = livePhotoCoordinator
        }
        activeCaptureID = settings.uniqueID
        captureCompletion = completion
        output.capturePhoto(with: settings, delegate: self)
    }

    @MainActor
    func toggleFlash() {
        flashMode = flashMode == .off ? .on : .off
    }

    @MainActor
    func toggleLivePhoto() {
        guard !isPreparingLivePhoto,
              let generation = activeConfigurationGeneration() else {
            return
        }
        if isLivePhotoEnabled {
            isLivePhotoEnabled = false
            return
        }
        isPreparingLivePhoto = true
        Task {
            defer {
                if isConfigurationCurrent(generation) {
                    isPreparingLivePhoto = false
                }
            }
            let authorized: Bool
            switch AVCaptureDevice.authorizationStatus(for: .audio) {
            case .authorized:
                authorized = true
            case .notDetermined:
                authorized = await AVCaptureDevice.requestAccess(for: .audio)
            default:
                authorized = false
            }
            guard authorized else {
                if isConfigurationCurrent(generation) {
                    captureErrorMessage = "需要麦克风权限才能拍摄有声 Live Photo。"
                }
                return
            }
            let installed = await withCheckedContinuation { continuation in
                sessionQueue.async {
                    continuation.resume(returning: self.installAudioInputIfNeeded(generation: generation))
                }
            }
            guard isConfigurationCurrent(generation) else { return }
            isLivePhotoEnabled = installed
        }
    }

    @MainActor
    func switchCamera() {
        guard !isCapturing,
              !isSwitchingCamera,
              let generation = activeConfigurationGeneration() else {
            return
        }
        isSwitchingCamera = true
        let newPosition: AVCaptureDevice.Position = activePosition == .back ? .front : .back
        sessionQueue.async {
            self.replaceCameraInput(position: newPosition, generation: generation)
        }
    }

    @MainActor
    func setZoomFactor(_ factor: CGFloat, ramped: Bool = true) {
        guard let generation = activeConfigurationGeneration() else { return }
        sessionQueue.async {
            guard self.isConfigurationCurrent(generation) else { return }
            guard let device = self.currentInput?.device else { return }
            let clamped = min(max(factor, device.minAvailableVideoZoomFactor), min(device.maxAvailableVideoZoomFactor, 8))
            do {
                try device.lockForConfiguration()
                if ramped {
                    device.ramp(toVideoZoomFactor: clamped, withRate: 8)
                } else {
                    device.videoZoomFactor = clamped
                }
                device.unlockForConfiguration()
                Task { @MainActor in self.zoomFactor = clamped }
            } catch {}
        }
    }

    @MainActor
    func setExposureBias(_ value: Float) {
        exposureBias = value
        guard let generation = activeConfigurationGeneration() else { return }
        sessionQueue.async {
            guard self.isConfigurationCurrent(generation) else { return }
            guard let device = self.currentInput?.device else { return }
            do {
                try device.lockForConfiguration()
                let clamped = min(max(value, device.minExposureTargetBias), device.maxExposureTargetBias)
                device.setExposureTargetBias(clamped, completionHandler: nil)
                device.unlockForConfiguration()
            } catch {}
        }
    }

    @MainActor
    func setColorTemperature(_ value: Float) {
        colorTemperature = value
        guard let generation = activeConfigurationGeneration() else { return }
        sessionQueue.async {
            guard self.isConfigurationCurrent(generation) else { return }
            guard let device = self.currentInput?.device,
                  device.isWhiteBalanceModeSupported(.locked) else { return }
            do {
                try device.lockForConfiguration()
                let values = AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(
                    temperature: value,
                    tint: 0
                )
                var gains = device.deviceWhiteBalanceGains(for: values)
                gains.redGain = min(max(gains.redGain, 1), device.maxWhiteBalanceGain)
                gains.greenGain = min(max(gains.greenGain, 1), device.maxWhiteBalanceGain)
                gains.blueGain = min(max(gains.blueGain, 1), device.maxWhiteBalanceGain)
                device.setWhiteBalanceModeLocked(with: gains)
                device.unlockForConfiguration()
            } catch {}
        }
    }

    @MainActor
    func resetWhiteBalance() {
        colorTemperature = 5_000
        guard let generation = activeConfigurationGeneration() else { return }
        sessionQueue.async {
            guard self.isConfigurationCurrent(generation) else { return }
            guard let device = self.currentInput?.device,
                  device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) else { return }
            do {
                try device.lockForConfiguration()
                device.whiteBalanceMode = .continuousAutoWhiteBalance
                device.unlockForConfiguration()
            } catch {}
        }
    }

    @MainActor
    func focus(at normalizedPoint: CGPoint) {
        guard let generation = activeConfigurationGeneration() else { return }
        sessionQueue.async {
            guard self.isConfigurationCurrent(generation) else { return }
            guard let device = self.currentInput?.device else { return }
            do {
                try device.lockForConfiguration()
                if device.isFocusPointOfInterestSupported, device.isFocusModeSupported(.autoFocus) {
                    device.focusPointOfInterest = normalizedPoint
                    device.focusMode = .autoFocus
                }
                if device.isExposurePointOfInterestSupported, device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposurePointOfInterest = normalizedPoint
                    device.exposureMode = .continuousAutoExposure
                }
                device.isSubjectAreaChangeMonitoringEnabled = true
                device.unlockForConfiguration()
            } catch {}
        }
    }

    private func requestAccessIfNeeded() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
    }

    private func configureSession(generation: Int, resetZoom: Bool) {
        guard isConfigurationCurrent(generation) else { return }
        guard session.inputs.isEmpty, session.outputs.isEmpty else {
            videoOutput.setSampleBufferDelegate(previewRenderer, queue: previewQueue)
            if resetZoom, let device = currentInput?.device {
                Self.resetDefaultZoom(for: device)
                Task { @MainActor in self.updateCameraCapabilities(device) }
            }
            configurePhotoMirroring(position: currentInput?.device.position ?? .back)
            startSessionIfNeeded(generation: generation)
            return
        }

        guard let device = Self.cameraDevice(position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input),
              session.canAddOutput(output),
              session.canAddOutput(videoOutput) else {
            Task { @MainActor in
                errorMessage = "当前设备无法启动相机，仍可从相册选择照片。"
                canOpenSettingsForError = false
            }
            return
        }
        Self.configurePreviewFrameRate(for: device)
        Self.resetDefaultZoom(for: device)

        session.beginConfiguration()
        session.sessionPreset = .photo
        session.addInput(input)
        currentInput = input
        session.addOutput(output)
        session.addOutput(videoOutput)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.automaticallyConfiguresOutputBufferDimensions = false
        videoOutput.deliversPreviewSizedOutputBuffers = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.setSampleBufferDelegate(
            previewRenderer,
            queue: previewQueue
        )
        output.maxPhotoQualityPrioritization = .balanced
        if output.isLivePhotoCaptureSupported {
            output.isLivePhotoCaptureEnabled = true
            livePhotoCaptureSupported = true
        } else {
            livePhotoCaptureSupported = false
        }
        if let preferredDimensions = Self.preferredPhotoDimensions(for: device) {
            output.maxPhotoDimensions = preferredDimensions
        }
        session.commitConfiguration()
        configurePhotoMirroring(position: .back)
        Task { @MainActor in
            guard self.isConfigurationCurrent(generation) else { return }
            errorMessage = nil
            canOpenSettingsForError = false
            isLivePhotoCaptureAvailable = livePhotoCaptureSupported
            isFlashAvailable = device.hasFlash
            activePosition = .back
            updateCameraCapabilities(device)
            if !livePhotoCaptureSupported {
                isLivePhotoEnabled = false
            }
        }

        startSessionIfNeeded(generation: generation)
    }

    private func installAudioInputIfNeeded(generation: Int) -> Bool {
        guard isConfigurationCurrent(generation) else { return false }
        if audioInput != nil { return true }
        guard let device = AVCaptureDevice.default(for: .audio),
              let input = try? AVCaptureDeviceInput(device: device) else {
            return false
        }
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        if session.canAddInput(input) {
            session.addInput(input)
            audioInput = input
        }
        return audioInput != nil && isConfigurationCurrent(generation)
    }

    private func replaceCameraInput(position: AVCaptureDevice.Position, generation: Int) {
        defer {
            Task { @MainActor in
                guard self.isConfigurationCurrent(generation) else { return }
                self.isSwitchingCamera = false
            }
        }
        guard isConfigurationCurrent(generation) else { return }
        guard let device = Self.cameraDevice(position: position),
              let input = try? AVCaptureDeviceInput(device: device) else {
            return
        }
        Self.configurePreviewFrameRate(for: device)
        Self.resetDefaultZoom(for: device)

        let previousInput = currentInput
        var installedPosition = previousInput?.device.position ?? position
        session.beginConfiguration()
        if let previousInput {
            session.removeInput(previousInput)
        }
        if session.canAddInput(input) {
            session.addInput(input)
            currentInput = input
            installedPosition = position
        } else if let previousInput, session.canAddInput(previousInput) {
            session.addInput(previousInput)
            currentInput = previousInput
            installedPosition = previousInput.device.position
        }
        if let preferredDimensions = Self.preferredPhotoDimensions(for: device) {
            output.maxPhotoDimensions = preferredDimensions
        }
        session.commitConfiguration()
        guard isConfigurationCurrent(generation) else { return }
        configurePhotoMirroring(position: installedPosition)

        Task { @MainActor in
            guard self.isConfigurationCurrent(generation) else { return }
            activePosition = installedPosition
            previewRenderer.update(position: installedPosition)
            let installedDevice = currentInput?.device ?? device
            updateCameraCapabilities(installedDevice)
            isFlashAvailable = installedDevice.hasFlash
            if !installedDevice.hasFlash {
                flashMode = .off
            }
        }
    }

    private static func cameraDevice(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        if position == .back {
            for type in [
                AVCaptureDevice.DeviceType.builtInTripleCamera,
                .builtInDualWideCamera,
                .builtInDualCamera,
                .builtInWideAngleCamera
            ] {
                if let device = AVCaptureDevice.default(type, for: .video, position: position) {
                    return device
                }
            }
        }
        return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
    }

    private static func preferredPhotoDimensions(for device: AVCaptureDevice) -> CMVideoDimensions? {
        let supported = device.activeFormat.supportedMaxPhotoDimensions.sorted {
            Int64($0.width) * Int64($0.height) < Int64($1.width) * Int64($1.height)
        }
        return supported.first { min($0.width, $0.height) >= 2_048 } ?? supported.last
    }

    private static func configurePreviewFrameRate(for device: AVCaptureDevice) {
        let targetFPS = 30.0
        guard device.activeFormat.videoSupportedFrameRateRanges.contains(where: {
            $0.minFrameRate <= targetFPS && $0.maxFrameRate >= targetFPS
        }) else { return }
        do {
            try device.lockForConfiguration()
            let duration = CMTime(value: 1, timescale: CMTimeScale(targetFPS))
            device.activeVideoMinFrameDuration = duration
            device.activeVideoMaxFrameDuration = duration
            device.unlockForConfiguration()
        } catch {}
    }

    private static func resetDefaultZoom(for device: AVCaptureDevice) {
        let multiplier = max(device.displayVideoZoomFactorMultiplier, 0.01)
        let oneTimesFactor = min(
            max(1 / multiplier, device.minAvailableVideoZoomFactor),
            device.maxAvailableVideoZoomFactor
        )
        do {
            try device.lockForConfiguration()
            device.cancelVideoZoomRamp()
            device.videoZoomFactor = oneTimesFactor
            device.unlockForConfiguration()
        } catch {}
    }

    private func configurePhotoMirroring(position: AVCaptureDevice.Position) {
        guard let connection = output.connection(with: .video) else { return }
        connection.automaticallyAdjustsVideoMirroring = false
        if connection.isVideoMirroringSupported {
            connection.isVideoMirrored = position == .front
        }
    }

    @MainActor
    private func updateCameraCapabilities(_ device: AVCaptureDevice) {
        let multiplier = device.displayVideoZoomFactorMultiplier
        displayZoomMultiplier = multiplier
        zoomFactor = device.videoZoomFactor
        let oneTimesFactor = min(
            max(1 / max(multiplier, 0.01), device.minAvailableVideoZoomFactor),
            device.maxAvailableVideoZoomFactor
        )
        var factors = [device.minAvailableVideoZoomFactor, oneTimesFactor]
        factors.append(contentsOf: device.virtualDeviceSwitchOverVideoZoomFactors.map { CGFloat(truncating: $0) })
        factors.append(min(device.maxAvailableVideoZoomFactor, 2 / max(multiplier, 0.01)))
        supportedZoomFactors = Array(Set(factors.map { min(max($0, device.minAvailableVideoZoomFactor), min(device.maxAvailableVideoZoomFactor, 8)) }))
            .sorted()
    }

    private static func makeLivePhotoMovieURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("achievement-live-\(UUID().uuidString)")
            .appendingPathExtension("mov")
    }

    private static func makeLivePhotoStillURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("achievement-live-\(UUID().uuidString)")
            .appendingPathExtension("heic")
    }

    private struct PendingPhotoCapture {
        let generation: Int
        let requestedLivePhotoMovieURL: URL?
        var image: UIImage? = nil
        var livePhotoStillURL: URL? = nil
        var livePhotoMovieURL: URL? = nil
        var isLiveRequested: Bool
        var livePhotoCoordinator: AchievementLivePhotoResourceCoordinator? = nil
    }

    private func startSessionIfNeeded(generation: Int) {
        guard isConfigurationCurrent(generation) else { return }
        guard !session.isRunning else {
            Task { @MainActor in
                guard self.isConfigurationCurrent(generation) else { return }
                self.isConfigured = true
            }
            return
        }
        session.startRunning()
        guard isConfigurationCurrent(generation) else {
            session.stopRunning()
            return
        }
        os_signpost(.event, log: achievementCameraPerformanceLog, name: "SessionRunning")
        Task { @MainActor in
            guard self.isConfigurationCurrent(generation) else { return }
            self.isConfigured = true
        }
    }

    private func discardUndeliveredCaptures() {
        let pending = pendingCaptures
        let coordinators = livePhotoResourceCoordinators
        pendingCaptures.removeAll()
        livePhotoResourceCoordinators.removeAll()
        activeCaptureID = nil
        captureCompletion = nil
        for (_, capture) in pending {
            if let url = capture.livePhotoStillURL {
                try? FileManager.default.removeItem(at: url)
            }
            if let url = capture.livePhotoMovieURL ?? capture.requestedLivePhotoMovieURL {
                try? FileManager.default.removeItem(at: url)
            }
        }
        for coordinator in coordinators.values {
            Task { await coordinator.finish() }
        }
    }

    private func publishCaptureFailure(generation: Int, message: String) {
        Task { @MainActor in
            guard self.isConfigurationCurrent(generation) else { return }
            self.isCapturing = false
            self.captureErrorMessage = message
        }
    }

    private func failCapture(uniqueID: Int64, message: String? = nil) {
        guard let pending = pendingCaptures.removeValue(forKey: uniqueID) else { return }
        if let coordinator = livePhotoResourceCoordinators.removeValue(forKey: uniqueID) {
            Task { await coordinator.finish() }
        }
        if let url = pending.livePhotoStillURL {
            try? FileManager.default.removeItem(at: url)
        }
        if let url = pending.livePhotoMovieURL ?? pending.requestedLivePhotoMovieURL {
            try? FileManager.default.removeItem(at: url)
        }
        guard activeCaptureID == uniqueID else { return }
        activeCaptureID = nil
        captureCompletion = nil
        Task { @MainActor in
            guard self.isConfigurationCurrent(pending.generation) else { return }
            self.isCapturing = false
            if let message {
                self.captureErrorMessage = message
            }
        }
    }
}

extension AchievementCameraModel: @unchecked Sendable {}

private final class FilteredCameraPreviewRenderer: NSObject {
    let device: MTLDevice?

    private let stateLock = NSLock()
    private let context: CIContext?
    private let textureCache: CoreVideo.CVMetalTextureCache?
    private let outputColorSpace = CGColorSpaceCreateDeviceRGB()
    private var latestTexture: MTLTexture?
    private var latestSourcePixelBuffer: CVPixelBuffer?
    private var preset: AchievementCameraFilterPreset = .original
    private var filters: [C7FilterProtocol] = []
    private var position: AVCaptureDevice.Position = .back
    private var filterGeneration = 0
    private var isFilteringFrame = false
    private var isRenderingEnabled = true
    private var isDrawRequestPending = false
    private weak var previewView: MTKView?
    private var hasReportedFirstFrame = false

    override init() {
        let device = MTLCreateSystemDefaultDevice()
        self.device = device
        if let device {
            var cache: CoreVideo.CVMetalTextureCache?
            CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &cache)
            textureCache = cache
            context = CIContext(
                mtlDevice: device,
                options: [.cacheIntermediates: false, .useSoftwareRenderer: false]
            )
        } else {
            textureCache = nil
            context = nil
        }
        super.init()
    }

    func update(preset: AchievementCameraFilterPreset? = nil, position: AVCaptureDevice.Position? = nil) {
        stateLock.lock()
        if let preset, preset != self.preset {
            self.preset = preset
            filters = CameraFilterPipeline.filters(for: preset)
            filterGeneration += 1
            isFilteringFrame = false
        }
        if let position, position != self.position {
            self.position = position
            latestTexture = nil
            latestSourcePixelBuffer = nil
            filterGeneration += 1
            isFilteringFrame = false
        }
        stateLock.unlock()
    }

    func reset() {
        stateLock.lock()
        latestTexture = nil
        latestSourcePixelBuffer = nil
        filterGeneration += 1
        isFilteringFrame = false
        stateLock.unlock()
    }

    func setRenderingEnabled(_ isEnabled: Bool) {
        stateLock.lock()
        guard isRenderingEnabled != isEnabled else {
            stateLock.unlock()
            return
        }
        isRenderingEnabled = isEnabled
        latestTexture = nil
        latestSourcePixelBuffer = nil
        filterGeneration += 1
        if !isEnabled {
            isFilteringFrame = false
        }
        stateLock.unlock()
    }

    func attach(view: MTKView?) {
        stateLock.lock()
        previewView = view
        stateLock.unlock()
    }

    private func requestDraw() {
        stateLock.lock()
        guard isRenderingEnabled, !isDrawRequestPending else {
            stateLock.unlock()
            return
        }
        isDrawRequestPending = true
        stateLock.unlock()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.stateLock.lock()
            self.isDrawRequestPending = false
            let view = self.isRenderingEnabled ? self.previewView : nil
            self.stateLock.unlock()
            view?.setNeedsDisplay()
        }
    }

    private func frameState() -> (
        texture: MTLTexture,
        position: AVCaptureDevice.Position,
        sourcePixelBuffer: CVPixelBuffer?
    )? {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard isRenderingEnabled, let latestTexture else { return nil }
        return (latestTexture, position, latestSourcePixelBuffer)
    }

    private func renderingIsEnabled() -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return isRenderingEnabled
    }

    private func render(
        _ state: (
            texture: MTLTexture,
            position: AVCaptureDevice.Position,
            sourcePixelBuffer: CVPixelBuffer?
        ),
        in view: MTKView
    ) {
        guard renderingIsEnabled(),
              let context,
              view.drawableSize.width > 0,
              view.drawableSize.height > 0,
              let drawable = view.currentDrawable else {
            return
        }
        _ = state.sourcePixelBuffer

        let orientation: Int32 = state.position == .front ? 5 : 6
        guard let textureImage = CIImage(
            mtlTexture: state.texture,
            options: [.colorSpace: outputColorSpace]
        ) else {
            return
        }
        let previewImage = textureImage
            .oriented(.downMirrored)
            .oriented(forExifOrientation: orientation)
        let destination = CGRect(
            x: 0,
            y: 0,
            width: drawable.texture.width,
            height: drawable.texture.height
        )
        let extent = previewImage.extent
        guard extent.width > 0, extent.height > 0 else { return }

        let scale = max(destination.width / extent.width, destination.height / extent.height)
        let normalized = previewImage.transformed(
            by: CGAffineTransform(translationX: -extent.minX, y: -extent.minY)
        )
        let scaled = normalized.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let centered = scaled.transformed(
            by: CGAffineTransform(
                translationX: (destination.width - scaled.extent.width) / 2,
                y: (destination.height - scaled.extent.height) / 2
            )
        )

        context.render(
            centered.cropped(to: destination),
            to: drawable.texture,
            commandBuffer: nil,
            bounds: destination,
            colorSpace: outputColorSpace
        )
        drawable.present()
    }
}

extension FilteredCameraPreviewRenderer: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        stateLock.lock()
        guard isRenderingEnabled else {
            stateLock.unlock()
            return
        }
        if !hasReportedFirstFrame {
            hasReportedFirstFrame = true
            stateLock.unlock()
            os_signpost(.event, log: achievementCameraPerformanceLog, name: "FirstPreviewFrame")
        } else {
            stateLock.unlock()
        }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let inputTexture = pixelBuffer.c7.toMTLTexture() else {
            return
        }

        stateLock.lock()
        let selectedPreset = preset
        let selectedFilters = filters
        let generation = filterGeneration
        if selectedPreset == .original || selectedFilters.isEmpty {
            latestTexture = inputTexture
            latestSourcePixelBuffer = pixelBuffer
            stateLock.unlock()
            requestDraw()
            return
        }
        guard !isFilteringFrame else {
            stateLock.unlock()
            return
        }
        isFilteringFrame = true
        stateLock.unlock()

        var pipeline = HarbethIO(element: inputTexture, filters: selectedFilters)
        CameraFilterPipeline.configurePreview(&pipeline, filterCount: selectedFilters.count)
        pipeline.transmitOutput(complete: { [weak self] (result: Result<MTLTexture, HarbethError>) in
            guard let self else { return }
            let filteredTexture: MTLTexture
            let sourcePixelBuffer: CVPixelBuffer?
            switch result {
            case .success(let texture):
                filteredTexture = texture
                sourcePixelBuffer = nil
            case .failure:
                filteredTexture = inputTexture
                sourcePixelBuffer = pixelBuffer
            }
            self.stateLock.lock()
            if generation == self.filterGeneration {
                self.latestTexture = filteredTexture
                self.latestSourcePixelBuffer = sourcePixelBuffer
                self.isFilteringFrame = false
            }
            self.stateLock.unlock()
            self.requestDraw()
        })
    }
}

extension FilteredCameraPreviewRenderer: MTKViewDelegate {
    nonisolated func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    nonisolated func draw(in view: MTKView) {
        autoreleasepool {
            guard let state = frameState() else { return }
            render(state, in: view)
        }
    }
}

extension FilteredCameraPreviewRenderer: @unchecked Sendable {}

private struct FilteredCameraPreviewView: UIViewRepresentable {
    let renderer: FilteredCameraPreviewRenderer
    let preset: AchievementCameraFilterPreset
    let position: AVCaptureDevice.Position

    func makeCoordinator() -> FilteredCameraPreviewRenderer {
        renderer
    }

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: renderer.device)
        view.backgroundColor = .black
        view.clearColor = MTLClearColorMake(0, 0, 0, 1)
        view.colorPixelFormat = .bgra8Unorm
        view.framebufferOnly = false
        view.enableSetNeedsDisplay = true
        view.isPaused = true
        view.delegate = context.coordinator
        renderer.attach(view: view)
        renderer.update(preset: preset, position: position)
        return view
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        renderer.update(preset: preset, position: position)
    }

    static func dismantleUIView(_ uiView: MTKView, coordinator: FilteredCameraPreviewRenderer) {
        uiView.isPaused = true
        uiView.delegate = nil
        coordinator.attach(view: nil)
        coordinator.reset()
    }
}

private struct AchievementCameraCapture {
    var image: UIImage
    var livePhotoStillURL: URL?
    var livePhotoMovieURL: URL?
    var pendingLivePhotoResources: AchievementLivePhotoResourceCoordinator?

    var isLivePhoto: Bool {
        livePhotoMovieURL != nil || pendingLivePhotoResources != nil
    }
}

extension AchievementCameraModel: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        os_signpost(.event, log: achievementCameraPerformanceLog, name: "PhotoProcessedCallback")
        let uniqueID = photo.resolvedSettings.uniqueID
        let result: (Data, UIImage)? = autoreleasepool {
            guard error == nil,
                  let data = photo.fileDataRepresentation(),
                  let image = UIImage(data: data) else {
                return nil
            }
            return (data, image)
        }
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard let result else {
                self.failCapture(uniqueID: uniqueID, message: "照片拍摄失败，请重试。")
                return
            }
            self.handleProcessedPhoto(uniqueID: uniqueID, data: result.0, image: result.1)
        }
    }

    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingLivePhotoToMovieFileAt outputFileURL: URL,
        duration: CMTime,
        photoDisplayTime: CMTime,
        resolvedSettings: AVCaptureResolvedPhotoSettings,
        error: Error?
    ) {
        let uniqueID = resolvedSettings.uniqueID
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.handleLivePhotoMovie(
                uniqueID: uniqueID,
                outputFileURL: outputFileURL,
                error: error
            )
        }
    }

    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings,
        error: Error?
    ) {
        let uniqueID = resolvedSettings.uniqueID
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.handleFinishedCapture(uniqueID: uniqueID, error: error)
        }
    }

    private func handleProcessedPhoto(uniqueID: Int64, data: Data, image: UIImage) {
        guard var pending = pendingCaptures[uniqueID] else { return }
        pending.image = image
        pendingCaptures[uniqueID] = pending

        if pending.isLiveRequested, let coordinator = pending.livePhotoCoordinator {
            let stillURL = Self.makeLivePhotoStillURL()
            Task.detached(priority: .utility) {
                do {
                    try data.write(to: stillURL, options: [.atomic])
                    await coordinator.setStillURL(stillURL)
                } catch {
                    try? FileManager.default.removeItem(at: stillURL)
                }
            }
        }

        // Enter the editor as soon as the still image is available. The paired
        // Live Photo resources continue finishing through the coordinator.
        completeCapture(uniqueID: uniqueID)
    }

    private func handleLivePhotoMovie(
        uniqueID: Int64,
        outputFileURL: URL,
        error: Error?
    ) {
        guard error == nil,
              let coordinator = livePhotoResourceCoordinators[uniqueID] else {
            try? FileManager.default.removeItem(at: outputFileURL)
            return
        }
        Task { await coordinator.setMovieURL(outputFileURL) }
        os_signpost(.event, log: achievementCameraPerformanceLog, name: "LiveMovieReady")
    }

    private func handleFinishedCapture(uniqueID: Int64, error: Error?) {
        if let pending = pendingCaptures[uniqueID], pending.image == nil {
            if error != nil {
                failCapture(uniqueID: uniqueID, message: "照片拍摄失败，请重试。")
            } else {
                let generation = pending.generation
                sessionQueue.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                    guard let self,
                          let delayedPending = self.pendingCaptures[uniqueID],
                          delayedPending.image == nil,
                          delayedPending.generation == generation else {
                        return
                    }
                    self.failCapture(uniqueID: uniqueID, message: "照片处理超时，请重试。")
                }
            }
        } else {
            completeCapture(uniqueID: uniqueID)
        }

        guard let coordinator = livePhotoResourceCoordinators[uniqueID] else { return }
        if error != nil {
            livePhotoResourceCoordinators[uniqueID] = nil
            Task { await coordinator.finish() }
            return
        }
        // AVFoundation can deliver the movie callback just after the capture
        // callback. Keep the coordinator available briefly for that ordering.
        sessionQueue.asyncAfter(deadline: .now() + 4) { [weak self] in
            guard let self,
                  let pendingCoordinator = self.livePhotoResourceCoordinators.removeValue(forKey: uniqueID) else {
                return
            }
            Task { await pendingCoordinator.finish() }
        }
    }

    private func completeCapture(uniqueID: Int64) {
        guard let pending = pendingCaptures[uniqueID],
              let image = pending.image else {
            return
        }
        pendingCaptures[uniqueID] = nil
        guard activeCaptureID == uniqueID else { return }
        activeCaptureID = nil
        let completion = captureCompletion
        captureCompletion = nil
        guard isConfigurationCurrent(pending.generation) else { return }
        let capture = AchievementCameraCapture(
            image: image,
            livePhotoStillURL: pending.livePhotoStillURL,
            livePhotoMovieURL: pending.livePhotoMovieURL,
            pendingLivePhotoResources: pending.livePhotoCoordinator
        )
        Task { @MainActor [weak self] in
            guard let self,
                  self.isConfigurationCurrent(pending.generation) else {
                return
            }
            self.isCapturing = false
            completion?(capture)
        }
    }
}

private struct LegacyGrowthMetricSheet: View {
    @EnvironmentObject private var growthMetricStore: GrowthMetricStore
    @Binding var isPresented: Bool

    @State private var selectedKind: GrowthMetricKind
    @State private var value: Double
    @State private var note = ""
    @State private var recordedAt = Date()
    @State private var showMore = false
    @State private var scaleDragStartValue: Double?

    init(kind: GrowthMetricKind, isPresented: Binding<Bool>) {
        _isPresented = isPresented
        _selectedKind = State(initialValue: kind)
        _value = State(initialValue: kind == .weight ? 7.6 : 68)
    }

    var body: some View {
        RecordGlassRecorderShell(
            title: "记录\(selectedKind.title)",
            stats: topStats,
            showMore: $showMore,
            moreHeight: 360,
            saveTitle: "保存",
            isSaveEnabled: canSave,
            onClose: { isPresented = false },
            onSave: save
        ) { metrics in
            metricGlassStage(metrics)
        } primaryControls: { metrics in
            metricScalePicker(metrics)
        } modeControls: { metrics in
            metricKindSelector(W: metrics.W, S: metrics.S)
        } leadingDock: { metrics in
            curveDockButton(S: metrics.S)
                .frame(width: metrics.W * 0.43, height: 56 * metrics.S)
        } moreContent: {
            morePanel
        }
        .presentationDragIndicator(.visible)
        .onAppear {
            loadValueForSelectedKind()
        }
        .onChange(of: selectedKind) { _, _ in
            loadValueForSelectedKind()
        }
    }

    private var metricHero: some View {
        RecordHeroStage(assetName: selectedKind.heroAssetName, fallbackSystemIcon: selectedKind.icon, accent: selectedKind.accent) {
            if selectedKind == .weight {
                weightReadout
                    .offset(y: 54)
            } else {
                heightReadout
                    .offset(y: 12)
            }
        }
    }

    private func metricGlassStage(_ metrics: RecordGlassRecorderMetrics) -> some View {
        let S = metrics.S
        let stageHeight = min(metrics.stageHeight, selectedKind == .weight ? 360 * S : 330 * S)
        return ZStack {
            metricHero
                .frame(width: metrics.W - 48 * S, height: stageHeight)
                .scaleEffect(selectedKind == .weight ? 0.88 : 0.80)

            RecordGlassStageSideButton(systemIcon: "chart.line.uptrend.xyaxis", S: S) {
                showMore = true
            }
            .position(x: 44 * S, y: stageHeight * 0.5 + 18 * S)
            .zIndex(20)

            RecordGlassStageSideButton(systemIcon: "clock", S: S) {
                recordedAt = Date()
            }
            .position(x: metrics.W - 44 * S, y: stageHeight * 0.5 + 18 * S)
            .zIndex(20)
        }
        .frame(width: metrics.W, height: stageHeight)
    }

    private func metricScalePicker(_ metrics: RecordGlassRecorderMetrics) -> some View {
        let S = metrics.S
        return metricScale
            .frame(width: metrics.W - 80 * S, height: 72 * S)
    }

    private func metricKindSelector(W: CGFloat, S: CGFloat) -> some View {
        RecordModeSelector(items: GrowthMetricKind.allCases, selected: selectedKind) { item in
            withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                selectedKind = item
            }
        } content: { item, isSelected in
            VStack(spacing: 5 * S) {
                Image(systemName: item.icon)
                    .font(.system(size: 17 * S, weight: .heavy))
                Text(item.title.localized)
                    .font(BBBFont.font(size: 13 * S, weight: .heavy))
            }
            .foregroundStyle(isSelected ? DesignToken.onPrimary : DesignToken.primary.opacity(0.82))
        }
        .frame(width: W - 48 * S)
    }

    private var weightReadout: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(DesignToken.shadowColor.opacity(0.82))
            .frame(width: 205, height: 56)
            .overlay(
                Text(valueText)
                    .font(.system(size: 34, weight: .medium, design: .rounded))
                    .foregroundStyle(DesignToken.onPrimary)
                    .monospacedDigit()
            )
    }

    private var heightReadout: some View {
        Text("\(valueText)\(selectedKind.unit)")
            .font(BBBFont.font(size: 22, weight: .heavy))
            .foregroundStyle(DesignToken.onPrimary)
            .monospacedDigit()
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(LinearGradient(colors: [selectedKind.accent, DesignToken.primarySoft], startPoint: .leading, endPoint: .trailing))
                    .overlay(Capsule(style: .continuous).stroke(DesignToken.glassStroke.opacity(0.58), lineWidth: 1))
            )
            .offset(y: 86)
    }

    private var metricScale: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)
            HStack(spacing: 8) {
                ForEach(scaleValues, id: \.self) { scaleValue in
                    VStack(spacing: 5) {
                        Capsule()
                            .fill(abs(scaleValue - value) < 0.05 ? selectedKind.accent : DesignToken.surfaceRaised.opacity(0.58))
                            .frame(width: abs(scaleValue - value) < 0.05 ? 6 : 2, height: abs(scaleValue - value) < 0.05 ? 34 : 18)
                        Text(scaleLabel(scaleValue))
                            .font(BBBFont.font(size: 11, weight: .bold))
                            .foregroundStyle(DesignToken.textSecondary)
                            .monospacedDigit()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(Capsule(style: .continuous).fill(DesignToken.glassFill.opacity(0.28)))
                    .overlay(Capsule(style: .continuous).stroke(DesignToken.glassStroke.opacity(0.68), lineWidth: 1))
            )
            .contentShape(Capsule(style: .continuous))
            .gesture(scaleDragGesture(width: width))
        }
    }

    private func curveDockButton(S: CGFloat) -> some View {
        RecordGlassDockActionButton(
            title: selectedKind == .weight ? "体重曲线" : "身高曲线",
            systemIcon: "chart.line.uptrend.xyaxis",
            S: S
        ) {
            showMore = true
        }
    }

    private var morePanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("更多信息")
                .font(BBBFont.font(size: 16, weight: .heavy))
                .foregroundStyle(DesignToken.textPrimary)

            DatePicker("记录时间", selection: $recordedAt, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                .font(BBBFont.font(size: 14, weight: .bold))

            TextField("备注", text: $note, axis: .vertical)
                .lineLimit(3, reservesSpace: true)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(DesignToken.surfaceRaised.opacity(0.86)))

            if !recentRecords.isEmpty {
                Divider()
                ForEach(recentRecords.prefix(3)) { record in
                    HStack {
                        Text(dateText(record.recordedAt))
                            .font(BBBFont.font(size: 12, weight: .bold))
                            .foregroundStyle(DesignToken.textSecondary)
                        Spacer()
                        Text("\(format(record.value))\(record.unit)")
                            .font(BBBFont.font(size: 13, weight: .heavy))
                            .foregroundStyle(DesignToken.textPrimary)
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 320)
        .background(DesignToken.canvas)
    }

    private var topStats: [RecordTopStat] {
        [
            RecordTopStat(title: "当前\(selectedKind.title)", value: latestText),
            RecordTopStat(title: "近30天", value: thirtyDayText),
            RecordTopStat(title: "距上次", value: lastDistanceText),
            RecordTopStat(title: "当前时间", value: timeText(recordedAt))
        ]
    }

    private var canSave: Bool {
        value > 0 && recordedAt <= Date()
    }

    private var recentRecords: [GrowthMetricRecord] {
        growthMetricStore.records(kind: selectedKind)
    }

    private var lastDistanceText: String {
        guard let latest = growthMetricStore.latest(kind: selectedKind) else { return "首次" }
        let minutes = max(Int(recordedAt.timeIntervalSince(latest.recordedAt) / 60), 0)
        if minutes < 60 { return "\(minutes)分钟" }
        if minutes < 60 * 24 { return "\(minutes / 60)小时" }
        return "\(minutes / (60 * 24))天"
    }

    private var latestText: String {
        guard let latest = growthMetricStore.latest(kind: selectedKind) else { return "\(valueText)\(selectedKind.unit)" }
        return "\(format(latest.value))\(selectedKind.unit)"
    }

    private var thirtyDayText: String {
        guard let change = growthMetricStore.changeInLast30Days(kind: selectedKind) else { return "暂无" }
        let sign = change >= 0 ? "+" : ""
        return "\(sign)\(format(change))\(selectedKind.unit)"
    }

    private var valueText: String {
        format(value)
    }

    private var scaleValues: [Double] {
        let base = (value * 10).rounded() / 10
        return (-2...2).map { clamp(((base + Double($0) * scaleStep) * 10).rounded() / 10) }
    }

    private var scaleStep: Double {
        selectedKind == .weight ? 0.5 : 2.0
    }

    private var valueRange: ClosedRange<Double> {
        selectedKind == .weight ? 0.5...40.0 : 20.0...130.0
    }

    private func save() {
        guard canSave else { return }
        growthMetricStore.saveRecord(kind: selectedKind, value: value, note: note, recordedAt: recordedAt)
        isPresented = false
    }

    private func loadValueForSelectedKind() {
        value = growthMetricStore.latest(kind: selectedKind)?.value ?? (selectedKind == .weight ? 7.6 : 68.0)
        note = ""
        scaleDragStartValue = nil
    }

    private func scaleDragGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gesture in
                if scaleDragStartValue == nil {
                    scaleDragStartValue = value
                }
                let start = scaleDragStartValue ?? value
                let deltaSteps = Double(gesture.translation.width / max(width / 4, 1))
                value = clamp(((start + deltaSteps * scaleStep) * 10).rounded() / 10)
            }
            .onEnded { _ in
                scaleDragStartValue = nil
            }
    }

    private func clamp(_ value: Double) -> Double {
        min(max(value, valueRange.lowerBound), valueRange.upperBound)
    }

    private func format(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private func scaleLabel(_ value: Double) -> String {
        format(value)
    }

    private func timeText(_ date: Date) -> String {
        AppDateTimeFormat.time(date)
    }

    private func dateText(_ date: Date) -> String {
        AppDateTimeFormat.dateTime(date)
    }
}

struct DiaperSheet: View {
    @EnvironmentObject private var activityStore: ActivityStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var isPresented: Bool

    @State private var selectedType: DiaperRecordType? = .pee
    @State private var diaperTokens: [DiaperDropToken] = []
    @State private var jarFrame: CGRect = .zero
    @State private var note = ""
    @State private var recordedAt = Date()
    @State private var showMore = false
    @State private var layoutHeight: CGFloat = 800
    private var isCompactHeight: Bool { layoutHeight < 760 }

    var body: some View {
        RecordGlassRecorderShell(
            title: "记录尿布",
            stats: diaperTopStats,
            showMore: $showMore,
            moreHeight: 280,
            saveTitle: "保存",
            isSaveEnabled: canSaveDiaper,
            onClose: { isPresented = false },
            onSave: saveDiaper
        ) { metrics in
            diaperHero(metrics)
                .frame(width: metrics.W - 40 * metrics.S, height: min(metrics.stageHeight, 330 * metrics.S))
                .scaleEffect(0.82)
        } primaryControls: { _ in
            EmptyView()
        } modeControls: { metrics in
            VStack(spacing: isCompactHeight ? 12 : 16) {
                Text(diaperJarSummary)
                    .font(BBBFont.font(size: 13, weight: .bold))
                    .foregroundStyle(DesignToken.textSecondary)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    ForEach(DiaperRecordType.allCases) { type in
                        DiaperDropButton(
                            type: type,
                            isSelected: selectedType == type,
                            onTap: {
                                dropDiaper(type)
                            },
                            onDragEnded: { location in
                                guard jarFrame.contains(location) else { return }
                                dropDiaper(type)
                            }
                        )
                    }
                }
            }
            .frame(width: metrics.W - 40 * metrics.S)
            .scaleEffect(0.86)
        } leadingDock: { metrics in
            diaperStatsDockButton(S: metrics.S)
                .frame(width: metrics.W * 0.43, height: 56 * metrics.S)
        } moreContent: {
            diaperMorePanel
        }
        .onPreferenceChange(DiaperJarFramePreferenceKey.self) { frame in
            jarFrame = frame
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.height
        } action: { height in
            layoutHeight = height
        }
        .onAppear {
            seedTodayDiapers()
        }
    }

    private func diaperHero(_ metrics: RecordGlassRecorderMetrics) -> some View {
        let S = metrics.S
        return ZStack {
            if DiaperBucketStageView.hasLayerAssets {
                DiaperBucketStageView(tokens: diaperTokens)
                    .frame(maxWidth: .infinity)
                    .frame(height: isCompactHeight ? 318 : 386)
                    .background(
                        GeometryReader { proxy in
                            Color.clear.preference(key: DiaperJarFramePreferenceKey.self, value: proxy.frame(in: .global))
                        }
                    )
                    .allowsHitTesting(false)
            } else if UIImage(named: "record_diaper_hero") != nil {
                Image("record_diaper_hero")
                    .resizable()
                    .scaledToFit()
                    .frame(height: isCompactHeight ? 318 : 386)
                    .opacity(0.86)

                DiaperGlassJarView(tokens: diaperTokens)
                    .frame(maxWidth: .infinity)
                    .frame(height: isCompactHeight ? 318 : 386)
                    .background(
                        GeometryReader { proxy in
                            Color.clear.preference(key: DiaperJarFramePreferenceKey.self, value: proxy.frame(in: .global))
                        }
                    )
                    .allowsHitTesting(false)
            } else {
                DiaperGlassJarView(tokens: diaperTokens)
                    .frame(maxWidth: .infinity)
                    .frame(height: isCompactHeight ? 318 : 386)
                    .background(
                        GeometryReader { proxy in
                            Color.clear.preference(key: DiaperJarFramePreferenceKey.self, value: proxy.frame(in: .global))
                        }
                    )
            }

            HStack {
                RecordGlassStageSideButton(systemIcon: "arrow.triangle.2.circlepath", S: S) {
                    selectedType = nil
                }
                Spacer()
                RecordGlassStageSideButton(systemIcon: "clock", S: S) {
                    recordedAt = Date()
                }
            }
            .padding(.horizontal, 28)
            .frame(maxHeight: .infinity, alignment: .center)
        }
        .frame(height: isCompactHeight ? 318 : 386)
    }

    private var diaperJarSummary: String {
        let peeCount = diaperTokens.filter { $0.type == .pee }.count
        let poopCount = diaperTokens.filter { $0.type == .poop }.count
        return "\(peeCount)个尿了，\(poopCount)个拉了 · 现在 \(timeString(recordedAt))"
    }

    private var diaperTopStats: [RecordTopStat] {
        [
            RecordTopStat(title: "今日尿尿", value: "\(todayPeeCount)次"),
            RecordTopStat(title: "今日粑粑", value: "\(todayPoopCount)次"),
            RecordTopStat(title: "上次尿尿", value: lastPeeDistanceText),
            RecordTopStat(title: "上次粑粑", value: lastPoopDistanceText)
        ]
    }

    private var todayDiaperRecords: [CareRecord] {
        activityStore.todayCareRecords.filter { $0.kind == .diaper }
    }

    private var todayPeeCount: Int {
        todayDiaperRecords.filter { record in
            record.title == "混合" || DiaperRecordType.type(for: record.title) == .pee
        }.count
    }

    private var todayPoopCount: Int {
        todayDiaperRecords.filter { record in
            record.title == "混合" || DiaperRecordType.type(for: record.title) == .poop
        }.count
    }

    private var diaperRecencySnapshot: CareRecencySnapshot {
        CareRecencyCalculator.snapshot(
            feedingSessions: [],
            careRecords: activityStore.careRecords,
            referenceDate: recordedAt
        )
    }

    private var lastPeeDistanceText: String {
        CareRecencyTimeFormatter.distanceText(
            since: diaperRecencySnapshot.pee.completedAt,
            relativeTo: recordedAt
        )
    }

    private var lastPoopDistanceText: String {
        CareRecencyTimeFormatter.distanceText(
            since: diaperRecencySnapshot.poop.completedAt,
            relativeTo: recordedAt
        )
    }

    private var diaperStatsButton: some View {
        Button {
            showMore = true
        } label: {
            Label("记录统计", systemImage: "chart.line.uptrend.xyaxis")
                .font(BBBFont.font(size: 13, weight: .heavy))
                .foregroundStyle(DesignToken.activityDiaperText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(width: 112, height: 58)
                .background(Capsule(style: .continuous).fill(DesignToken.surfaceRaised.opacity(0.50)))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func diaperStatsDockButton(S: CGFloat) -> some View {
        RecordGlassDockActionButton(
            title: "记录统计",
            systemIcon: "chart.line.uptrend.xyaxis",
            S: S
        ) {
            showMore = true
        }
    }

    private var diaperMorePanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("更多信息")
                .font(BBBFont.font(size: 16, weight: .heavy))
                .foregroundStyle(DesignToken.textPrimary)

            DatePicker("记录时间", selection: $recordedAt, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                .font(BBBFont.font(size: 14, weight: .bold))

        }
        .padding(16)
        .frame(width: 320)
        .background(DesignToken.canvas)
    }

    private func saveDiaper() {
        guard let selectedType, canSaveDiaper else { return }
        activityStore.recordDiaper(type: selectedType.rawValue, note: "", recordedAt: recordedAt)
        isPresented = false
    }

    private var diaperBottomDock: some View {
        HStack(spacing: 12) {
            Button {
                guard let selectedType, canSaveDiaper else { return }
                activityStore.recordDiaper(type: selectedType.rawValue, note: "", recordedAt: recordedAt)
                isPresented = false
            } label: {
                Label("保存尿布记录", systemImage: "checkmark.circle.fill")
                    .font(BBBFont.font(size: 16, weight: .heavy))
                    .foregroundStyle(DesignToken.onPrimary)
                    .frame(maxWidth: .infinity)
                            .frame(height: isCompactHeight ? 48 : 54)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(canSaveDiaper ? DesignToken.primaryGradient : LinearGradient(colors: [.gray.opacity(0.58), .gray.opacity(0.58)], startPoint: .leading, endPoint: .trailing))
                            )
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(!canSaveDiaper)

            Button {
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(DesignToken.textSecondary)
                    .frame(width: isCompactHeight ? 48 : 54, height: isCompactHeight ? 48 : 54)
                    .background(Circle().fill(DesignToken.surfaceRaised.opacity(0.94)))
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(isCompactHeight ? 6 : 8)
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(Capsule(style: .continuous).stroke(DesignToken.glassStroke.opacity(0.7), lineWidth: 1))
                .shadow(color: DesignToken.shadowColor.opacity(0.15), radius: 18, y: 8)
        )
        .padding(.horizontal, isCompactHeight ? 14 : 16)
        .padding(.bottom, isCompactHeight ? 8 : 12)
    }

    private func sideCircleButton(icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .heavy))
                .foregroundStyle(color.opacity(0.9))
                .frame(width: 56, height: 56)
                .background(Circle().fill(DesignToken.surfaceRaised.opacity(0.82)))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func timeString(_ date: Date) -> String {
        AppDateTimeFormat.time(date)
    }

    private var canSaveDiaper: Bool {
        selectedType != nil && recordedAt <= Date()
    }

    private func dropDiaper(_ type: DiaperRecordType) {
        selectedType = type
        if let last = diaperTokens.indices.last, !diaperTokens[last].isSeeded, !diaperTokens[last].isPlaced {
            diaperTokens[last] = DiaperDropToken(type: type, index: diaperTokens[last].index, isPlaced: diaperTokens[last].isPlaced)
            return
        }

        let token = DiaperDropToken(type: type, index: diaperTokens.count)
        if reduceMotion {
            diaperTokens.append(token.placed())
        } else {
            diaperTokens.append(token)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) {
                guard let tokenIndex = diaperTokens.firstIndex(where: { $0.id == token.id }) else { return }
                withAnimation(.interpolatingSpring(stiffness: 230, damping: 18)) {
                    diaperTokens[tokenIndex] = diaperTokens[tokenIndex].placed()
                }
            }
        }
        if diaperTokens.count > 16 {
            diaperTokens.removeFirst(diaperTokens.count - 16)
        }
        UIImpactFeedbackGenerator(style: reduceMotion ? .light : .soft).impactOccurred(intensity: reduceMotion ? 0.45 : 0.7)
    }

    private func seedTodayDiapers() {
        guard diaperTokens.isEmpty else { return }
        let records = activityStore.todayCareRecords.filter { $0.kind == .diaper }
        let seededTokens = records.prefix(12).enumerated().map { index, record in
            DiaperDropToken(type: DiaperRecordType.type(for: record.title), index: index, isSeeded: true)
        }
        diaperTokens = seededTokens
        guard !reduceMotion else {
            diaperTokens = seededTokens.map { $0.placed() }
            return
        }
        for token in seededTokens {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(token.index) * 0.045) {
                guard let tokenIndex = diaperTokens.firstIndex(where: { $0.id == token.id }) else { return }
                withAnimation(.interpolatingSpring(stiffness: 220, damping: 20)) {
                    diaperTokens[tokenIndex] = diaperTokens[tokenIndex].placed()
                }
            }
        }
    }
}

private struct DiaperJarFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

private struct DiaperDropToken: Identifiable, Equatable {
    let id = UUID()
    let type: DiaperRecordType
    let index: Int
    var isPlaced = false
    var isSeeded = false

    private static let slotCount = 7
    private static let xOffsets: [CGFloat] = [-56, -22, 24, 58, -40, 6, 44]
    private static let yOffsets: [CGFloat] = [72, 64, 68, 58, 38, 34, 30]
    private static let rotations: [Double] = [-18, 11, -7, 17, 5, -13, 9]
    private static let scales: [CGFloat] = [0.9, 0.84, 0.88, 0.82, 0.78, 0.8, 0.76]
    private static let motionFactors: [CGFloat] = [1.0, 0.82, 0.92, 0.76, 0.68, 0.72, 0.58]

    private var pileSlot: Int {
        let slot = index % Self.slotCount
        assert(slot >= 0 && slot < Self.xOffsets.count, "DiaperDropToken pileSlot out of bounds")
        return slot
    }

    var xOffset: CGFloat { Self.xOffsets[pileSlot] }
    var yOffset: CGFloat { Self.yOffsets[pileSlot] }
    var rotation: Double { Self.rotations[pileSlot] }
    var scale: CGFloat { Self.scales[pileSlot] }
    var motionFactor: CGFloat { Self.motionFactors[pileSlot] }

    func placed() -> DiaperDropToken {
        var copy = self
        copy.isPlaced = true
        return copy
    }
}

private struct DiaperBucketStageView: View {
    let tokens: [DiaperDropToken]
    @StateObject private var motion = DiaperJarMotionModel()

    private static let layerNames = [
        "diaper_bucket_back",
        "diaper_bucket_inner_mask",
        "diaper_bucket_front_glass",
        "diaper_bucket_front_rim"
    ]

    static var hasLayerAssets: Bool {
        layerNames.allSatisfy { UIImage(named: $0) != nil }
    }

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let tokenSize = side * 0.18

            ZStack {
                bucketLayer("diaper_bucket_back", side: side)

                bucketInterior(side: side, tokenSize: tokenSize)
                    .mask {
                        bucketLayer("diaper_bucket_inner_mask", side: side)
                    }

                activeOutsideTokens(side: side, tokenSize: tokenSize)

                bucketLayer("diaper_bucket_front_glass", side: side)
                    .allowsHitTesting(false)

                bucketLayer("diaper_bucket_front_rim", side: side)
                    .allowsHitTesting(false)
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityHidden(true)
        }
        .onAppear { motion.start() }
        .onDisappear { motion.stop() }
    }

    private func bucketLayer(_ name: String, side: CGFloat) -> some View {
        Image(name)
            .resizable()
            .scaledToFit()
            .frame(width: side, height: side)
    }

    private func bucketInterior(side: CGFloat, tokenSize: CGFloat) -> some View {
        ZStack {
            ForEach(tokens) { token in
                DiaperTokenView(type: token.type, size: tokenSize)
                    .scaleEffect(token.isPlaced ? token.scale : 0.58)
                    .rotationEffect(.degrees(token.isPlaced ? token.rotation : token.rotation * 0.2))
                    .position(position(for: token, side: side, isOutside: false))
                    .opacity(token.isPlaced ? 1 : 0)
            }
        }
        .frame(width: side, height: side)
    }

    private func activeOutsideTokens(side: CGFloat, tokenSize: CGFloat) -> some View {
        ZStack {
            ForEach(tokens) { token in
                DiaperTokenView(type: token.type, size: tokenSize)
                    .scaleEffect(token.isPlaced ? token.scale : 0.58)
                    .rotationEffect(.degrees(token.isPlaced ? token.rotation : token.rotation * 0.2))
                    .position(position(for: token, side: side, isOutside: true))
                    .opacity(token.isPlaced ? 0 : 1)
            }
        }
        .frame(width: side, height: side)
    }

    private func position(for token: DiaperDropToken, side: CGFloat, isOutside: Bool) -> CGPoint {
        guard token.isPlaced || !isOutside else {
            return CGPoint(x: side * 0.52, y: -side * 0.12)
        }

        let scale = side / 386
        return CGPoint(
            x: side * 0.5 + (token.xOffset + motion.offset.width * token.motionFactor) * scale,
            y: side * 0.5 + (token.yOffset + motion.offset.height * token.motionFactor) * scale
        )
    }
}

private struct DiaperGlassJarView: View {
    let tokens: [DiaperDropToken]
    @StateObject private var motion = DiaperJarMotionModel()

    var body: some View {
        GeometryReader { proxy in
            let jarWidth = min(proxy.size.width * 0.74, 304)
            let jarHeight = min(proxy.size.height, 386)
            let tokenSize = jarWidth * 0.24

            ZStack {
                jarShadow(width: jarWidth, height: jarHeight)

                RoundedRectangle(cornerRadius: jarWidth * 0.22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                DesignToken.glassFill.opacity(0.54),
                                DesignToken.easyYearningSoft.opacity(0.22),
                                DesignToken.glassFill.opacity(0.36)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: jarWidth * 0.24, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [DesignToken.glassStroke.opacity(0.95), DesignToken.easyYearningSoft.opacity(0.36), DesignToken.glassStroke.opacity(0.68)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                    .overlay(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [DesignToken.easyYearningSoft.opacity(0.62), DesignToken.glassFill.opacity(0.42)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: jarHeight * 0.30)
                            .padding(.horizontal, 17)
                            .padding(.bottom, 16)
                    }
                    .overlay {
                        ZStack {
                            ForEach(tokens) { token in
                                DiaperTokenView(type: token.type, size: tokenSize)
                                    .scaleEffect(token.isPlaced ? token.scale : 0.56)
                                    .rotationEffect(.degrees(token.isPlaced ? token.rotation : token.rotation * 0.2))
                                    .offset(
                                        x: token.isPlaced ? token.xOffset + motion.offset.width * token.motionFactor : 0,
                                        y: token.isPlaced ? token.yOffset + motion.offset.height * token.motionFactor : -jarHeight * 0.52
                                    )
                                    .opacity(token.isPlaced ? 1 : 0.34)
                            }
                        }
                        .frame(width: jarWidth * 0.88, height: jarHeight * 0.86)
                        .clipped()
                    }
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(DesignToken.glassFill.opacity(0.64))
                            .frame(width: 12, height: jarHeight * 0.62)
                            .blur(radius: 0.2)
                            .padding(.leading, jarWidth * 0.16)
                            .padding(.top, jarHeight * 0.08)
                    }
                    .overlay(alignment: .trailing) {
                        Capsule()
                            .fill(DesignToken.easyYearning.opacity(0.13))
                            .frame(width: 9, height: jarHeight * 0.56)
                            .padding(.trailing, jarWidth * 0.14)
                            .padding(.bottom, jarHeight * 0.12)
                    }
                    .frame(width: jarWidth, height: jarHeight)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityHidden(true)
        }
        .onAppear { motion.start() }
        .onDisappear { motion.stop() }
    }

    private func jarShadow(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: width * 0.24, style: .continuous)
            .fill(DesignToken.easyYearning.opacity(0.08))
            .frame(width: width * 0.92, height: height * 0.16)
            .blur(radius: 14)
            .offset(y: height * 0.48)
    }
}

private struct DiaperDropTokenLayer: View {
    let tokens: [DiaperDropToken]
    @StateObject private var motion = DiaperJarMotionModel()

    var body: some View {
        GeometryReader { proxy in
            let jarWidth = min(proxy.size.width * 0.74, 304)
            let jarHeight = min(proxy.size.height, 386)
            let tokenSize = jarWidth * 0.24

            ZStack {
                ForEach(tokens) { token in
                    DiaperTokenView(type: token.type, size: tokenSize)
                        .scaleEffect(token.isPlaced ? token.scale : 0.56)
                        .rotationEffect(.degrees(token.isPlaced ? token.rotation : token.rotation * 0.2))
                        .offset(
                            x: token.isPlaced ? token.xOffset + motion.offset.width * token.motionFactor : 0,
                            y: token.isPlaced ? token.yOffset + motion.offset.height * token.motionFactor : -jarHeight * 0.52
                        )
                        .opacity(token.isPlaced ? 1 : 0.34)
                }
            }
            .frame(width: jarWidth * 0.88, height: jarHeight * 0.86)
            .clipped()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityHidden(true)
        }
    }
}

@MainActor
private final class DiaperJarMotionModel: ObservableObject {
    @Published var offset: CGSize = .zero
    private let manager = CMMotionManager()

    func start() {
        guard manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 30.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let motion else { return }
            let roll = max(min(motion.attitude.roll, 0.45), -0.45)
            let pitch = max(min(motion.attitude.pitch, 0.45), -0.45)
            withAnimation(.spring(response: 0.22, dampingFraction: 0.82)) {
                self?.offset = CGSize(width: roll * 22, height: -pitch * 12)
            }
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
    }
}

private struct DiaperDropButton: View {
    let type: DiaperRecordType
    let isSelected: Bool
    let onTap: () -> Void
    let onDragEnded: (CGPoint) -> Void

    @State private var dragOffset: CGSize = .zero

    var body: some View {
        GeometryReader { _ in
            Button(action: onTap) {
                VStack(spacing: 8) {
                    DiaperTokenView(type: type, size: 74)
                        .offset(dragOffset)
                        .gesture(
                            DragGesture(coordinateSpace: .global)
                                .onChanged { value in
                                    dragOffset = value.translation
                                }
                                .onEnded { value in
                                    onDragEnded(value.location)
                                    withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                                        dragOffset = .zero
                                    }
                                }
                        )

                    Text(type.rawValue)
                        .font(BBBFont.font(size: 15, weight: .heavy))
                        .foregroundStyle(DesignToken.textPrimary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(isSelected ? type.softFill.opacity(0.88) : DesignToken.surfaceRaised.opacity(0.92))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(isSelected ? type.accent.opacity(0.62) : DesignToken.borderSubtle.opacity(0.86), lineWidth: 1.4)
                        )
                )
                .shadow(color: type.accent.opacity(isSelected ? 0.16 : 0.07), radius: isSelected ? 14 : 9, y: 6)
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .frame(height: 128)
    }
}

private struct DiaperTokenView: View {
    let type: DiaperRecordType
    let size: CGFloat

    var body: some View {
        Image("rhythm_diaper_icon")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .overlay(
                type.softFill
                    .blendMode(.multiply)
                    .opacity(type == .pee ? 0.32 : 0.42)
                    .mask(
                        Image("rhythm_diaper_icon")
                            .resizable()
                            .scaledToFit()
                    )
            )
            .overlay(alignment: .topTrailing) {
                Circle()
                    .fill(type.accent.opacity(type == .pee ? 0.74 : 0.86))
                    .frame(width: size * 0.18, height: size * 0.18)
                    .overlay(
                        Circle()
                            .stroke(DesignToken.glassStroke.opacity(0.84), lineWidth: 1)
                    )
                    .offset(x: -size * 0.14, y: size * 0.18)
            }
            .overlay(alignment: .bottomLeading) {
                if type == .poop {
                    Capsule()
                        .fill(DesignToken.activityDiaperText.opacity(0.7))
                        .frame(width: size * 0.28, height: size * 0.1)
                        .rotationEffect(.degrees(-12))
                        .offset(x: size * 0.26, y: -size * 0.2)
                } else {
                    Capsule()
                        .fill(DesignToken.glassFill.opacity(0.72))
                        .frame(width: size * 0.32, height: size * 0.08)
                        .rotationEffect(.degrees(-18))
                        .offset(x: size * 0.24, y: -size * 0.22)
                }
            }
            .shadow(color: DesignToken.shadowColor.opacity(0.07), radius: size * 0.08, y: size * 0.04)
            .accessibilityLabel(type.rawValue)
    }
}

private struct SleepTimeSelection: Identifiable {
    enum Kind {
        case wakeUp
        case bedtime

        var title: String {
            switch self {
            case .wakeUp: return "Wake up"
            case .bedtime: return "Bedtime"
            }
        }

        func estimateText(_ time: String) -> String {
            switch self {
            case .wakeUp: return "宝宝可能是 \(time) 醒来的"
            case .bedtime: return "宝宝可能是 \(time) 入睡的"
            }
        }
    }

    let id = UUID()
    let kind: Kind
}

private struct SleepRingSegment: Identifiable {
    let id = UUID()
    let startAt: Date
    let endAt: Date
    let color: Color
    let lineWidth: CGFloat
    let opacity: Double
}

private struct SleepTimeRing: View {
    let startAt: Date
    let endAt: Date
    let durationText: String
    let recordedSleepSegments: [SleepRingSegment]
    let feedingSegments: [SleepRingSegment]
    let diaperTimes: [Date]
    let sunriseAt: Date
    let sunsetAt: Date
    let allowsDrag: Bool
    let onDragBedtime: (Date) -> Void
    let onDragWakeUp: (Date) -> Void

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let ringWidth = side * 0.105
            let ringSize = side - ringWidth * 1.3
            let markerSize = ringWidth
            let outerTickRadius = ringSize * 0.5
            let innerTickRadius = ringSize * 0.5 - ringWidth * 0.84
            let labelRadius = ringSize * 0.5 - ringWidth * 1.75
            let sleepFractions = ringFractions(start: startAt, end: endAt)

            ZStack {
                Circle()
                    .stroke(DesignToken.glassStroke.opacity(0.52), lineWidth: ringWidth)
                    .frame(width: ringSize, height: ringSize)

                Circle()
                    .stroke(DesignToken.easySleepSoft.opacity(0.72), lineWidth: ringWidth * 0.74)
                    .frame(width: ringSize, height: ringSize)

                ForEach(recordedSleepSegments) { segment in
                    ForEach(ringFractions(start: segment.startAt, end: segment.endAt), id: \.id) { span in
                        Circle()
                            .trim(from: span.start, to: span.end)
                            .stroke(
                                segment.color.opacity(segment.opacity),
                                style: StrokeStyle(lineWidth: ringWidth * 0.62, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .frame(width: ringSize, height: ringSize)
                    }
                }

                ForEach(sleepFractions.indices, id: \.self) { index in
                    let span = sleepFractions[index]
                    Circle()
                        .trim(from: span.start, to: span.end)
                        .stroke(
                            DesignToken.easySleep.opacity(0.88),
                            style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: ringSize, height: ringSize)
                        .shadow(color: DesignToken.easySleep.opacity(0.20), radius: 9, y: 4)
                        .animation(.spring(response: 0.26, dampingFraction: 0.82), value: startAt)
                        .animation(.spring(response: 0.26, dampingFraction: 0.82), value: endAt)
                }

                ForEach(feedingSegments) { segment in
                    ForEach(ringFractions(start: segment.startAt, end: segment.endAt), id: \.id) { span in
                        Circle()
                            .trim(from: span.start, to: span.end)
                            .stroke(
                                segment.color.opacity(segment.opacity),
                                style: StrokeStyle(lineWidth: ringWidth * 0.46, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .frame(width: ringSize - ringWidth * 1.05, height: ringSize - ringWidth * 1.05)
                    }
                }

                ForEach(diaperTimes, id: \.self) { date in
                    Circle()
                        .fill(DesignToken.activityDiaper.opacity(0.92))
                        .overlay(Circle().stroke(DesignToken.glassStroke.opacity(0.80), lineWidth: 1))
                        .frame(width: markerSize, height: markerSize)
                        .offset(pointOffset(fraction: timeFraction(date), radius: ringSize * 0.5))
                        .shadow(color: DesignToken.activityDiaper.opacity(0.22), radius: 5, y: 2)
                }

                SleepSunMoonMarker(systemIcon: "sun.max.fill", color: DesignToken.reward, size: markerSize * 0.62)
                    .offset(pointOffset(fraction: timeFraction(sunriseAt), radius: labelRadius * 1.08))

                SleepSunMoonMarker(systemIcon: "moon.stars.fill", color: DesignToken.easySleep, size: markerSize * 0.62)
                    .offset(pointOffset(fraction: timeFraction(sunsetAt), radius: labelRadius * 1.08))

                ForEach(0..<96, id: \.self) { index in
                    let isHour = index % 4 == 0
                    let isMajorHour = index % 24 == 0
                    Capsule(style: .continuous)
                        .fill(DesignToken.easySleepText.opacity(isMajorHour ? 0.48 : (isHour ? 0.34 : 0.18)))
                        .frame(width: isMajorHour ? 2.2 : 1.2, height: isMajorHour ? ringWidth * 0.42 : (isHour ? ringWidth * 0.34 : ringWidth * 0.22))
                        .offset(y: -outerTickRadius)
                        .rotationEffect(.degrees(Double(index) / 96 * 360))
                }

                ForEach(0..<96, id: \.self) { index in
                    let isHour = index % 4 == 0
                    Capsule(style: .continuous)
                        .fill(DesignToken.glassFill.opacity(isHour ? 0.62 : 0.36))
                        .frame(width: isHour ? 1.5 : 1, height: isHour ? ringWidth * 0.34 : ringWidth * 0.20)
                        .offset(y: -innerTickRadius)
                        .rotationEffect(.degrees(Double(index) / 96 * 360))
                }

                ForEach([0, 6, 12, 18], id: \.self) { hour in
                    SleepTimeRingHourLabel(hour: hour)
                        .offset(pointOffset(fraction: CGFloat(hour) / 24.0, radius: labelRadius))
                }

                VStack(spacing: 8) {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: side * 0.075, weight: .semibold))
                        .foregroundStyle(DesignToken.easySleep.opacity(0.86))
                    Spacer()
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: side * 0.072, weight: .semibold))
                        .foregroundStyle(DesignToken.reward.opacity(0.88))
                }
                .frame(height: ringSize * 0.54)
                .allowsHitTesting(false)

                VStack(spacing: 3) {
                    Text(durationText)
                        .font(BBBFont.font(size: side * 0.12, weight: .heavy))
                        .foregroundStyle(DesignToken.textStrong)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.62)
                    Text(SleepRecordFormatter.sleepTitle(start: startAt, end: endAt))
                        .font(BBBFont.font(size: side * 0.04, weight: .bold))
                        .foregroundStyle(DesignToken.textSecondary.opacity(0.78))
                }
                .frame(width: ringSize * 0.56)
                .allowsHitTesting(false)

                SleepTimeRingNode(systemIcon: "bed.double.fill", size: markerSize)
                    .offset(pointOffset(fraction: timeFraction(startAt), radius: ringSize * 0.5))
                    .gesture(nodeDragGesture(size: geo.size, reference: startAt, action: onDragBedtime))
                    .allowsHitTesting(allowsDrag)

                SleepTimeRingNode(systemIcon: "alarm.fill", size: markerSize)
                    .offset(pointOffset(fraction: timeFraction(endAt), radius: ringSize * 0.5))
                    .gesture(nodeDragGesture(size: geo.size, reference: startAt, action: onDragWakeUp))
                    .allowsHitTesting(allowsDrag)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .coordinateSpace(name: "SleepRingSpace")
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("睡眠时间环")
    }

    private func timeFraction(_ date: Date) -> CGFloat {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute, .second], from: date)
        let hours = components.hour ?? 0
        let minutes = components.minute ?? 0
        let secondsComponent = components.second ?? 0
        let seconds = Double(hours * 3600 + minutes * 60 + secondsComponent)
        return CGFloat(seconds / (24 * 60 * 60))
    }

    private func ringFractions(start: Date, end: Date) -> [RingFractionSpan] {
        let startFraction = timeFraction(start)
        let endFraction = timeFraction(end)
        guard end != start else { return [] }
        if end > start, Calendar.current.isDate(start, inSameDayAs: end), endFraction > startFraction {
            return [RingFractionSpan(start: startFraction, end: endFraction)]
        }
        if endFraction > startFraction {
            return [RingFractionSpan(start: startFraction, end: endFraction)]
        }
        return [
            RingFractionSpan(start: startFraction, end: 1),
            RingFractionSpan(start: 0, end: endFraction)
        ].filter { $0.end > $0.start }
    }

    private func pointOffset(fraction: CGFloat, radius: CGFloat) -> CGSize {
        let angle = Double(fraction) * 2 * Double.pi - Double.pi / 2
        return CGSize(width: cos(angle) * radius, height: sin(angle) * radius)
    }

    private func nodeDragGesture(size: CGSize, reference: Date, action: @escaping (Date) -> Void) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("SleepRingSpace"))
            .onChanged { value in
                let center = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
                let dx = value.location.x - center.x
                let dy = value.location.y - center.y
                let radians = atan2(dy, dx) + Double.pi / 2
                let normalized = (radians < 0 ? radians + 2 * Double.pi : radians) / (2 * Double.pi)
                action(dateForFraction(CGFloat(normalized), reference: reference))
            }
    }

    private func dateForFraction(_ fraction: CGFloat, reference: Date) -> Date {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: reference)
        let seconds = TimeInterval(Double(fraction) * 24 * 60 * 60)
        let snapped = (seconds / (5 * 60)).rounded() * (5 * 60)
        return dayStart.addingTimeInterval(snapped)
    }
}

private struct RingFractionSpan: Identifiable {
    let id = UUID()
    let start: CGFloat
    let end: CGFloat
}

private struct SleepTimeRingNode: View {
    let systemIcon: String
    let size: CGFloat

    var body: some View {
        Circle()
            .fill(.ultraThinMaterial)
            .overlay(Circle().fill(DesignToken.glassFill.opacity(0.62)))
            .overlay(Circle().stroke(DesignToken.glassStroke.opacity(0.88), lineWidth: 1))
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: systemIcon)
                    .font(.system(size: size * 0.43, weight: .heavy))
                    .foregroundStyle(DesignToken.easySleepText.opacity(0.88))
            )
            .shadow(color: DesignToken.easySleep.opacity(0.18), radius: 9, y: 4)
    }
}

private struct SleepSunMoonMarker: View {
    let systemIcon: String
    let color: Color
    let size: CGFloat

    var body: some View {
        Image(systemName: systemIcon)
            .font(.system(size: size * 0.72, weight: .heavy))
            .foregroundStyle(color.opacity(0.9))
            .frame(width: size, height: size)
            .background(Circle().fill(DesignToken.glassFill.opacity(0.42)))
            .overlay(Circle().stroke(DesignToken.glassStroke.opacity(0.58), lineWidth: 1))
            .shadow(color: color.opacity(0.18), radius: 5, y: 2)
            .allowsHitTesting(false)
    }
}

private struct SleepTimeRingHourLabel: View {
    let hour: Int

    var body: some View {
        Text("\(hour)点")
            .font(BBBFont.font(size: 10, weight: .heavy))
            .foregroundStyle(DesignToken.easySleepText.opacity(0.78))
            .monospacedDigit()
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                Capsule(style: .continuous)
                    .fill(DesignToken.glassFill.opacity(0.36))
            )
    }
}

private struct SleepRhythmRing: View {
    let date: Date
    let segments: [SleepRingSegment]
    let activeStartTime: Date?
    let timerTick: Date

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let lineInset = side * 0.12
            let ringSize = side - lineInset

            ZStack {
                Circle()
                    .stroke(DesignToken.glassStroke.opacity(0.46), lineWidth: side * 0.11)
                    .frame(width: ringSize, height: ringSize)

                Circle()
                    .stroke(DesignToken.easySleepSoft.opacity(0.72), lineWidth: side * 0.074)
                    .frame(width: ringSize, height: ringSize)

                ForEach(segments) { segment in
                    if let fractions = clippedFractions(for: segment), fractions.end > fractions.start {
                        Circle()
                            .trim(from: fractions.start, to: fractions.end)
                            .stroke(
                                segment.color.opacity(segment.opacity),
                                style: StrokeStyle(lineWidth: segment.lineWidth, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .frame(width: ringSize, height: ringSize)
                            .shadow(color: segment.color.opacity(segment.opacity * 0.18), radius: 7, y: 3)
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("睡眠时间环")
    }

    private func clippedFractions(for segment: SleepRingSegment) -> (start: CGFloat, end: CGFloat)? {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return nil }
        let start = max(segment.startAt, dayStart)
        let end = min(segment.endAt, dayEnd)
        guard end > start else { return nil }
        let daySeconds = dayEnd.timeIntervalSince(dayStart)
        guard daySeconds > 0 else { return nil }
        return (
            CGFloat(start.timeIntervalSince(dayStart) / daySeconds),
            CGFloat(end.timeIntervalSince(dayStart) / daySeconds)
        )
    }
}

private struct SleepRingTick: View {
    let hour: Int
    let side: CGFloat

    var body: some View {
        let angle = Double(hour) / 24 * 360 - 90
        let radius = side * 0.45
        let radians = angle * Double.pi / 180
        let x = cos(radians) * radius
        let y = sin(radians) * radius

        VStack(spacing: 3) {
            Circle()
                .fill(DesignToken.easySleep.opacity(0.42))
                .frame(width: 4, height: 4)
            Text("\(hour)")
                .font(BBBFont.font(size: 9, weight: .bold))
                .foregroundStyle(DesignToken.easySleepText.opacity(0.76))
                .monospacedDigit()
        }
        .offset(x: x, y: y)
    }
}

struct SleepSheet: View {
    @EnvironmentObject private var activityStore: ActivityStore
    @EnvironmentObject private var feedingStore: FeedingStore
    @EnvironmentObject private var sleepDraftStore: SleepDraftStore
    @Environment(BabyProfileStore.self) private var profileStore
    @Binding var isPresented: Bool

    @State private var manualStartTime = Date().addingTimeInterval(-30 * 60)
    @State private var manualEndTime = Date()
    @State private var manualNote = ""
    @State private var timerTick = Date()
    @State private var showMore = false
    @State private var pendingTimeSelection: SleepTimeSelection?
    @State private var proposedSleepTime = Date()

    private var activeStartTime: Date? {
        sleepDraftStore.activeSleepStartAt
    }

    private var activeElapsedMinutes: Int {
        guard let activeStartTime else { return 0 }
        return max(Int(timerTick.timeIntervalSince(activeStartTime) / 60), 0)
    }

    private var manualDurationMinutes: Int {
        guard let window = normalizedManualSleepWindow else { return 0 }
        return max(Int(window.end.timeIntervalSince(window.start) / 60), 0)
    }

    private var canSaveManualSleep: Bool {
        guard let window = normalizedManualSleepWindow else { return false }
        return window.end > window.start && window.end <= Date()
    }

    var body: some View {
        RecordGlassRecorderShell(
            title: "记录睡眠",
            stats: sleepTopStats,
            showMore: $showMore,
            moreHeight: 430,
            saveTitle: activeStartTime == nil ? "保存记录" : "停止并保存",
            isSaveEnabled: activeStartTime != nil || canSaveManualSleep,
            onClose: { isPresented = false },
            onSave: savePrimarySleep
        ) { metrics in
            sleepRingStage(metrics)
        } primaryControls: { metrics in
            sleepTimerCard(metrics)
        } modeControls: { _ in
            EmptyView()
        } leadingDock: { metrics in
            sleepLeadingDock(metrics)
                .frame(width: metrics.W * 0.43, height: 56 * metrics.S)
        } moreContent: {
            sleepMorePanel
        }
        .onAppear {
            timerTick = Date()
            if manualEndTime <= manualStartTime {
                manualEndTime = manualStartTime.addingTimeInterval(30 * 60)
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { date in
            timerTick = date
            sleepDraftStore.updateCurrentTime(date)
        }
    }

    private func sleepRingStage(_ metrics: RecordGlassRecorderMetrics) -> some View {
        let ringSize = min(metrics.W * 0.78, metrics.stageHeight * 0.96)
        let start = activeStartTime ?? manualStartTime
        let end = activeStartTime == nil ? normalizedManualEndTime : timerTick
        let duration = activeStartTime == nil ? manualDurationMinutes : activeElapsedMinutes
        return ZStack {
            SleepTimeRing(
                startAt: start,
                endAt: end,
                durationText: SleepRecordFormatter.durationText(minutes: duration),
                recordedSleepSegments: recordedSleepRingSegments,
                feedingSegments: sleepFeedingRingSegments,
                diaperTimes: sleepDiaperRingTimes,
                sunriseAt: approximateSunriseTime(on: Date()),
                sunsetAt: approximateSunsetTime(on: Date()),
                allowsDrag: activeStartTime == nil,
                onDragBedtime: setManualSleepStartFromRing,
                onDragWakeUp: setManualSleepEndFromRing
            )
            .frame(width: ringSize, height: ringSize)
        }
        .frame(width: metrics.W, height: metrics.stageHeight)
    }

    private func sleepTimerCard(_ metrics: RecordGlassRecorderMetrics) -> some View {
        let start = activeStartTime ?? manualStartTime
        let duration = activeStartTime == nil ? manualDurationMinutes : activeElapsedMinutes

        return HStack(spacing: 14 * metrics.S) {
            Image(systemName: activeStartTime == nil ? "timer" : "stopwatch.fill")
                .font(.system(size: 22 * metrics.S, weight: .heavy))
                .foregroundStyle(DesignToken.easySleepText.opacity(0.92))
                .frame(width: 42 * metrics.S, height: 42 * metrics.S)
                .background(Circle().fill(DesignToken.glassFill.opacity(0.42)))

            VStack(alignment: .leading, spacing: 4 * metrics.S) {
                Text(activeStartTime == nil ? "选取睡眠时间段" : "正在计时")
                    .font(BBBFont.font(size: 12 * metrics.S, weight: .heavy))
                    .foregroundStyle(DesignToken.textSecondary)
                Text(SleepRecordFormatter.durationText(minutes: duration))
                    .font(BBBFont.font(size: 24 * metrics.S, weight: .heavy))
                    .foregroundStyle(DesignToken.textStrong)
                    .monospacedDigit()
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4 * metrics.S) {
                Text("开始")
                    .font(BBBFont.font(size: 10 * metrics.S, weight: .bold))
                    .foregroundStyle(DesignToken.textSecondary)
                Text(timeString(start))
                    .font(BBBFont.font(size: 14 * metrics.S, weight: .heavy))
                    .foregroundStyle(DesignToken.easySleep)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 16 * metrics.S)
        .padding(.vertical, 12 * metrics.S)
        .frame(width: metrics.W - 54 * metrics.S)
        .background(
            RoundedRectangle(cornerRadius: 22 * metrics.S, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 22 * metrics.S, style: .continuous).fill(DesignToken.glassFill.opacity(0.38)))
                .overlay(RoundedRectangle(cornerRadius: 22 * metrics.S, style: .continuous).stroke(DesignToken.glassStroke.opacity(0.68), lineWidth: 1))
        )
    }

    private func sleepSummaryCard(_ metrics: RecordGlassRecorderMetrics) -> some View {
        let start = activeStartTime ?? manualStartTime
        let end = activeStartTime == nil ? normalizedManualEndTime : timerTick
        let duration = activeStartTime == nil ? manualDurationMinutes : activeElapsedMinutes

        return VStack(alignment: .leading, spacing: 10 * metrics.S) {
            HStack {
                Text(activeStartTime == nil ? "睡眠摘要" : "正在记录")
                    .font(BBBFont.font(size: 13 * metrics.S, weight: .heavy))
                    .foregroundStyle(DesignToken.textPrimary)
                Spacer()
                Text(canSaveSleepText)
                    .font(BBBFont.font(size: 10 * metrics.S, weight: .bold))
                    .foregroundStyle(canSaveSleepTextColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            sleepSummaryRow(title: "入睡", value: timeString(start), metrics: metrics)
            sleepSummaryRow(title: activeStartTime == nil ? "醒来" : "当前", value: timeString(end), metrics: metrics)
            sleepSummaryRow(
                title: activeStartTime == nil ? "睡眠时长" : "已睡时长",
                value: SleepRecordFormatter.durationText(minutes: duration),
                metrics: metrics,
                isEmphasized: true
            )
        }
        .padding(.horizontal, 16 * metrics.S)
        .padding(.vertical, 13 * metrics.S)
        .frame(width: metrics.W - 54 * metrics.S)
        .background(
            RoundedRectangle(cornerRadius: 22 * metrics.S, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 22 * metrics.S, style: .continuous).fill(DesignToken.glassFill.opacity(0.44)))
                .overlay(RoundedRectangle(cornerRadius: 22 * metrics.S, style: .continuous).stroke(DesignToken.glassStroke.opacity(0.72), lineWidth: 1))
        )
    }

    private func sleepSummaryRow(title: String, value: String, metrics: RecordGlassRecorderMetrics, isEmphasized: Bool = false) -> some View {
        HStack {
            Text(title.localized)
                .font(BBBFont.font(size: 11 * metrics.S, weight: .bold))
                .foregroundStyle(DesignToken.textSecondary)
            Spacer()
            Text(value.localized)
                .font(BBBFont.font(size: (isEmphasized ? 14 : 12) * metrics.S, weight: .heavy))
                .foregroundStyle(isEmphasized ? DesignToken.easySleep : DesignToken.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
        }
    }

    private var canSaveSleepText: String {
        if activeStartTime != nil { return "底部保存" }
        return canSaveManualSleep ? "可保存" : "醒来时间需要晚于入睡"
    }

    private var canSaveSleepTextColor: Color {
        if activeStartTime != nil || canSaveManualSleep { return DesignToken.easySleep }
        return DesignToken.error.opacity(0.72)
    }

    private var normalizedManualSleepWindow: (start: Date, end: Date)? {
        SleepRecordFormatter.normalizedWindow(
            startTime: manualStartTime,
            endTime: manualEndTime,
            anchorDate: manualStartTime
        )
    }

    private var normalizedManualEndTime: Date {
        normalizedManualSleepWindow?.end ?? manualEndTime
    }

    private var sleepHero: some View {
        RecordHeroStage(assetName: "record_sleep_hero", fallbackSystemIcon: "moon.stars.fill", accent: DesignToken.easySleep) {
            VStack(spacing: 8) {
                Text(activeStartTime == nil ? SleepRecordFormatter.durationText(minutes: manualDurationMinutes) : SleepRecordFormatter.durationText(minutes: activeElapsedMinutes))
                    .font(BBBFont.font(size: 42, weight: .heavy))
                    .foregroundStyle(DesignToken.textStrong)
                    .monospacedDigit()
                Text(activeStartTime == nil ? "补录睡眠" : "睡眠进行中")
                    .font(BBBFont.font(size: 14, weight: .heavy))
                    .foregroundStyle(DesignToken.textSecondary)
            }
            .offset(y: 126)
        }
    }

    private var sleepControls: some View {
        VStack(spacing: 14) {
            if activeStartTime == nil {
                manualSleepControls
            } else {
                activeSleepControls
            }
        }
    }

    private var manualSleepControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            DatePicker("入睡", selection: $manualStartTime, displayedComponents: [.hourAndMinute])
                .font(BBBFont.font(size: 15, weight: .bold))

            DatePicker("醒来", selection: $manualEndTime, displayedComponents: [.hourAndMinute])
                .font(BBBFont.font(size: 15, weight: .bold))

            HStack {
                Text("睡眠时长")
                    .font(BBBFont.font(size: 13, weight: .bold))
                    .foregroundStyle(DesignToken.textSecondary)
                Spacer()
                Text(SleepRecordFormatter.durationText(minutes: manualDurationMinutes))
                    .font(BBBFont.font(size: 16, weight: .heavy))
                    .foregroundStyle(DesignToken.easySleep)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(DesignToken.glassFill.opacity(0.42)))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(DesignToken.glassStroke.opacity(0.76), lineWidth: 1))
        )
        .onChange(of: manualStartTime) { _, newValue in
            if normalizedManualSleepWindow == nil {
                manualEndTime = newValue.addingTimeInterval(30 * 60)
            }
        }
    }

    private var activeSleepControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let startBinding = activeStartBinding {
                DatePicker("入睡", selection: startBinding, displayedComponents: [.hourAndMinute])
                    .font(BBBFont.font(size: 15, weight: .bold))
            }

            Button(role: .destructive) {
                sleepDraftStore.resetDraft()
            } label: {
                Text("取消计时")
                    .font(BBBFont.font(size: 14, weight: .heavy))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(DesignToken.glassFill.opacity(0.42)))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(DesignToken.glassStroke.opacity(0.76), lineWidth: 1))
        )
    }

    private func sleepLeadingDock(_ metrics: RecordGlassRecorderMetrics) -> some View {
        Group {
            if activeStartTime == nil {
                RecordGlassDockActionButton(
                    title: "开始睡眠",
                    systemIcon: "play.fill",
                    foreground: DesignToken.easySleepText,
                    S: metrics.S
                ) {
                    startSleepTimer()
                }
            } else {
                RecordGlassDockActionButton(
                    title: "取消计时",
                    systemIcon: "xmark",
                    foreground: DesignToken.easyActivityText,
                    S: metrics.S
                ) {
                    sleepDraftStore.resetDraft()
                }
            }
        }
    }

    private var sleepMorePanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("手动填写")
                .font(BBBFont.font(size: 16, weight: .heavy))
                .foregroundStyle(DesignToken.textPrimary)

            if activeStartTime == nil {
                DatePicker("入睡", selection: $manualStartTime, displayedComponents: [.date, .hourAndMinute])
                    .font(BBBFont.font(size: 14, weight: .bold))

                DatePicker("醒来", selection: $manualEndTime, displayedComponents: [.date, .hourAndMinute])
                    .font(BBBFont.font(size: 14, weight: .bold))

                HStack {
                    Text("睡眠时长")
                        .font(BBBFont.font(size: 13, weight: .bold))
                        .foregroundStyle(DesignToken.textSecondary)
                    Spacer()
                    Text(SleepRecordFormatter.durationText(minutes: manualDurationMinutes))
                        .font(BBBFont.font(size: 15, weight: .heavy))
                        .foregroundStyle(canSaveManualSleep ? DesignToken.easySleep : DesignToken.error.opacity(0.74))
                }

            } else {
                EmptyView()
            }
        }
        .padding(16)
        .frame(width: 320)
        .background(DesignToken.canvas)
    }

    private var sleepTopStats: [RecordTopStat] {
        [
            RecordTopStat(title: "上次醒来", value: lastSleepDistanceText),
            RecordTopStat(title: "今日睡眠", value: "\(todaySleepCount)次"),
            RecordTopStat(title: "今日时长", value: "\(todaySleepMinutes)min"),
            RecordTopStat(title: "时间", value: activeStartTime.map(timeString) ?? timeString(manualStartTime), systemIcon: "clock")
        ]
    }

    private var todaySleepRecords: [CareRecord] {
        activityStore.careRecordsForSleepSummary(on: Date()).filter { $0.kind == .sleep }
    }

    private var recordedSleepRingSegments: [SleepRingSegment] {
        activityStore.careRecordsForSleepSummary(on: Date()).compactMap { record in
            guard record.kind == .sleep,
                  let duration = SleepRecordFormatter.durationMinutes(from: record.detail) else {
                return nil
            }
            let end = SleepRecordFormatter.endTime(start: record.recordedAt, durationMinutes: duration)
            return SleepRingSegment(
                startAt: record.recordedAt,
                endAt: end,
                color: DesignToken.easySleep,
                lineWidth: 18,
                opacity: 0.52
            )
        }
    }

    private var sleepRingSegments: [SleepRingSegment] {
        let date = Date()
        let ageMonths = profileStore.currentProfile.ageMonths
        var segments: [SleepRingSegment] = []

        for record in activityStore.careRecordsForSleepSummary(on: date) where record.kind == .sleep {
            guard let duration = SleepRecordFormatter.durationMinutes(from: record.detail) else { continue }
            let end = SleepRecordFormatter.endTime(start: record.recordedAt, durationMinutes: duration)
            segments.append(SleepRingSegment(startAt: record.recordedAt, endAt: end, color: DesignToken.easySleep, lineWidth: 18, opacity: 0.82))
        }

        for session in feedingStore.sessions(on: date) {
            let span = session.resolvedTimeSpan(ageMonths: ageMonths)
            let end = span.isPoint ? span.endAt.addingTimeInterval(6 * 60) : span.endAt
            segments.append(
                SleepRingSegment(
                    startAt: span.startAt,
                    endAt: end,
                    color: sleepRingFeedingColor(for: session.type),
                    lineWidth: 12,
                    opacity: span.isEstimated ? 0.36 : 0.76
                )
            )
        }

        for record in activityStore.careRecords(on: date) where record.kind == .diaper {
            segments.append(
                SleepRingSegment(
                    startAt: record.recordedAt.addingTimeInterval(-2 * 60),
                    endAt: record.recordedAt.addingTimeInterval(5 * 60),
                    color: DesignToken.activityDiaper,
                    lineWidth: 10,
                    opacity: 0.78
                )
            )
        }

        if let activeStartTime {
            segments.append(SleepRingSegment(startAt: activeStartTime, endAt: timerTick, color: DesignToken.easySleep, lineWidth: 20, opacity: 0.92))
        }

        return segments
    }

    private var sleepFeedingRingSegments: [SleepRingSegment] {
        let date = Date()
        let ageMonths = profileStore.currentProfile.ageMonths
        return feedingStore.sessions(on: date).map { session in
            let span = session.resolvedTimeSpan(ageMonths: ageMonths)
            let end = span.isPoint ? span.endAt.addingTimeInterval(8 * 60) : span.endAt
            return SleepRingSegment(
                startAt: span.startAt,
                endAt: end,
                color: sleepRingFeedingColor(for: session.type),
                lineWidth: 12,
                opacity: span.isEstimated ? 0.34 : 0.78
            )
        }
    }

    private var sleepDiaperRingTimes: [Date] {
        activityStore.careRecords(on: Date())
            .filter { $0.kind == .diaper }
            .map(\.recordedAt)
    }

    private var todaySleepCount: Int {
        todaySleepRecords.count
    }

    private var todaySleepMinutes: Int {
        todaySleepRecords.reduce(0) { total, record in
            total + (SleepRecordFormatter.durationMinutes(from: record.detail) ?? 0)
        }
    }

    private var lastSleepDistanceText: String {
        let anchor = activeStartTime ?? manualStartTime
        let snapshot = CareRecencyCalculator.snapshot(
            feedingSessions: [],
            careRecords: activityStore.careRecords,
            referenceDate: anchor
        )
        return CareRecencyTimeFormatter.distanceText(
            since: snapshot.sleep.completedAt,
            relativeTo: anchor
        )
    }

    private func savePrimarySleep() {
        if let startTime = activeStartTime {
            let endTime = max(Date(), startTime.addingTimeInterval(60))
            activityStore.recordSleep(startTime: startTime, endTime: endTime, note: "")
            sleepDraftStore.resetDraft()
            isPresented = false
            return
        }

        guard canSaveManualSleep else { return }
        guard let window = normalizedManualSleepWindow else { return }
        activityStore.recordSleep(startTime: window.start, endTime: window.end, note: "")
        isPresented = false
    }

    private func startSleepTimer() {
        let now = Date()
        sleepDraftStore.start(at: now)
        timerTick = now
    }

    private func setManualSleepStartFromRing(_ date: Date) {
        guard activeStartTime == nil else { return }
        var proposed = date
        let currentEnd = normalizedManualEndTime
        if proposed >= currentEnd {
            proposed = proposed.addingTimeInterval(-24 * 60 * 60)
        }
        manualStartTime = min(proposed, Date().addingTimeInterval(-60))
        if normalizedManualSleepWindow == nil {
            manualEndTime = manualStartTime.addingTimeInterval(30 * 60)
        }
    }

    private func setManualSleepEndFromRing(_ date: Date) {
        guard activeStartTime == nil else { return }
        var proposed = date
        if proposed <= manualStartTime {
            proposed = proposed.addingTimeInterval(24 * 60 * 60)
        }
        manualEndTime = min(proposed, Date())
        if manualEndTime <= manualStartTime {
            manualEndTime = manualStartTime.addingTimeInterval(30 * 60)
        }
    }

    private func sleepRingFeedingColor(for type: FeedingType) -> Color {
        switch type {
        case .bottle: return DesignToken.feedingBottle
        case .breast: return DesignToken.feedingBreast
        case .solid: return DesignToken.feedingSolid
        }
    }

    private func openTimeSelection(_ kind: SleepTimeSelection.Kind) {
        proposedSleepTime = kind == .wakeUp ? estimatedWakeUpTime() : estimatedBedtime()
        pendingTimeSelection = SleepTimeSelection(kind: kind)
    }

    private func sleepTimeConfirmationSheet(_ selection: SleepTimeSelection) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Image(systemName: selection.kind == .wakeUp ? "sun.max.fill" : "moon.stars.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(selection.kind == .wakeUp ? DesignToken.reward : DesignToken.easySleep)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(DesignToken.surfaceRaised.opacity(0.76)))

                VStack(alignment: .leading, spacing: 4) {
                    Text(selection.kind.title.localized)
                        .font(BBBFont.font(size: 20, weight: .heavy))
                        .foregroundStyle(DesignToken.textPrimary)
                    Text(selection.kind.estimateText(timeString(proposedSleepTime)))
                        .font(BBBFont.font(size: 13, weight: .bold))
                        .foregroundStyle(DesignToken.textSecondary)
                }
            }

            DatePicker("精确时间", selection: $proposedSleepTime, displayedComponents: [.hourAndMinute])
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .frame(height: 138)
                .clipped()

            Button {
                confirmTimeSelection(selection.kind)
            } label: {
                Text("确认")
                    .font(BBBFont.font(size: 17, weight: .heavy))
                    .foregroundStyle(DesignToken.onPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Capsule().fill(DesignToken.easySleep))
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(22)
        .background(DesignToken.canvas.ignoresSafeArea())
    }

    private func confirmTimeSelection(_ kind: SleepTimeSelection.Kind) {
        switch kind {
        case .wakeUp:
            manualEndTime = proposedSleepTime
            if manualStartTime >= manualEndTime {
                manualStartTime = manualEndTime.addingTimeInterval(-30 * 60)
            }
        case .bedtime:
            manualStartTime = proposedSleepTime
            if manualEndTime <= manualStartTime {
                manualEndTime = manualStartTime.addingTimeInterval(30 * 60)
            }
        }
        pendingTimeSelection = nil
    }

    private func estimatedWakeUpTime() -> Date {
        let sunrise = approximateSunriseTime(on: Date())
        let ageMonths = profileStore.currentProfile.ageMonths
        let sessions = feedingStore.sessions(on: Date())
        let endTimes = sessions.map { session in
            session.resolvedTimeSpan(ageMonths: ageMonths).endAt
        }
        let nearbyEndTimes = endTimes.filter { endTime in
            abs(endTime.timeIntervalSince(sunrise)) <= 2 * 60 * 60
        }
        let candidates = nearbyEndTimes.sorted { left, right in
            abs(left.timeIntervalSince(sunrise)) < abs(right.timeIntervalSince(sunrise))
        }

        if let afterSunrise = candidates.filter({ $0 >= sunrise }).min(by: { $0.timeIntervalSince(sunrise) < $1.timeIntervalSince(sunrise) }) {
            return afterSunrise
        }

        return candidates.first ?? sunrise
    }

    private func estimatedBedtime() -> Date {
        let calendar = Calendar.current
        let now = Date()
        let targetDate = (calendar.component(.hour, from: now) < 12)
            ? (calendar.date(byAdding: .day, value: -1, to: now) ?? now)
            : now
        let dayStart = calendar.startOfDay(for: targetDate)
        let eveningStart = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: dayStart) ?? dayStart
        let eveningEnd = calendar.date(bySettingHour: 23, minute: 30, second: 0, of: dayStart) ?? dayStart.addingTimeInterval(23.5 * 60 * 60)
        let fallback = calendar.date(bySettingHour: 20, minute: 30, second: 0, of: dayStart) ?? dayStart.addingTimeInterval(20.5 * 60 * 60)
        let ageMonths = profileStore.currentProfile.ageMonths

        let lastFeeding = feedingStore.sessions(on: targetDate)
            .map { $0.resolvedTimeSpan(ageMonths: ageMonths).endAt }
            .filter { $0 >= eveningStart && $0 <= eveningEnd }
            .max()

        guard let lastFeeding else { return fallback }
        let proposed = lastFeeding.addingTimeInterval(45 * 60)
        return min(max(proposed, eveningStart), eveningEnd)
    }

    private func approximateSunriseTime(on date: Date) -> Date {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 172
        let season = cos(2 * Double.pi * Double(dayOfYear - 172) / 365)
        let offsetHours = Double(TimeZone.current.secondsFromGMT(for: date)) / 3600
        let timezoneFineTune = (offsetHours.rounded() - offsetHours) * 12
        let minutes = Int((6 * 60 + 30) - 45 * season + timezoneFineTune)
        return calendar.date(byAdding: .minute, value: minutes, to: dayStart)
            ?? calendar.date(bySettingHour: 6, minute: 30, second: 0, of: dayStart)
            ?? date
    }

    private func approximateSunsetTime(on date: Date) -> Date {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 172
        let season = cos(2 * Double.pi * Double(dayOfYear - 172) / 365)
        let offsetHours = Double(TimeZone.current.secondsFromGMT(for: date)) / 3600
        let timezoneFineTune = (offsetHours.rounded() - offsetHours) * 12
        let minutes = Int((18 * 60 + 20) + 55 * season + timezoneFineTune)
        return calendar.date(byAdding: .minute, value: minutes, to: dayStart)
            ?? calendar.date(bySettingHour: 18, minute: 20, second: 0, of: dayStart)
            ?? date
    }

    private var idleSleepCard: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(DesignToken.easySleep.opacity(0.12))
                    .frame(width: 128, height: 128)

                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(DesignToken.easySleep)
            }

            Text("准备入睡")
                .font(BBBFont.font(size: 22, weight: .heavy))
                .foregroundStyle(DesignToken.textPrimary)

            Button {
                let now = Date()
                sleepDraftStore.start(at: now)
                timerTick = now
            } label: {
                Label("开始睡眠", systemImage: "play.fill")
                    .font(BBBFont.font(size: 17, weight: .heavy))
                    .foregroundStyle(DesignToken.onPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        Capsule()
                            .fill(DesignToken.easySleep)
                            .shadow(color: DesignToken.easySleep.opacity(0.2), radius: 16, y: 8)
                    )
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(DesignToken.surfaceRaised.opacity(0.94)))
    }

    private var activeSleepCard: some View {
        VStack(spacing: 16) {
            Text(SleepRecordFormatter.durationText(minutes: activeElapsedMinutes))
                .font(BBBFont.font(size: 42, weight: .heavy))
                .foregroundStyle(DesignToken.easySleep)
                .monospacedDigit()

            if let startBinding = activeStartBinding {
                DatePicker("入睡", selection: startBinding, displayedComponents: [.hourAndMinute])
                    .font(BBBFont.font(size: 17, weight: .semibold))
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(DesignToken.easySleepSoft))
            }

            Button {
                guard let startTime = activeStartTime else { return }
                let endTime = max(Date(), startTime.addingTimeInterval(60))
                activityStore.recordSleep(startTime: startTime, endTime: endTime, note: "")
                sleepDraftStore.resetDraft()
                isPresented = false
            } label: {
                Label("醒了，保存", systemImage: "checkmark.circle.fill")
                    .font(BBBFont.font(size: 17, weight: .heavy))
                    .foregroundStyle(DesignToken.onPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Capsule().fill(DesignToken.easySleep))
            }
            .buttonStyle(ScaleButtonStyle())

            Button(role: .destructive) {
                sleepDraftStore.resetDraft()
            } label: {
                Text("取消计时")
                    .font(BBBFont.font(size: 15, weight: .heavy))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(DesignToken.surfaceRaised.opacity(0.94)))
    }

    private var manualSleepCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("补录睡眠")
                .font(BBBFont.font(size: 18, weight: .heavy))
                .foregroundStyle(DesignToken.textPrimary)

            DatePicker("入睡", selection: $manualStartTime, displayedComponents: [.hourAndMinute])
                .font(BBBFont.font(size: 17, weight: .semibold))

            DatePicker("醒来", selection: $manualEndTime, displayedComponents: [.hourAndMinute])
                .font(BBBFont.font(size: 17, weight: .semibold))

            HStack {
                Label("睡眠时长", systemImage: "timer")
                    .font(BBBFont.font(size: 15, weight: .bold))
                Spacer()
                Text(SleepRecordFormatter.durationText(minutes: manualDurationMinutes))
                    .font(BBBFont.font(size: 17, weight: .heavy))
                    .foregroundStyle(canSaveManualSleep ? DesignToken.easySleep : DesignToken.error.opacity(0.8))
            }

            Button {
                guard canSaveManualSleep else { return }
                guard let window = normalizedManualSleepWindow else { return }
                activityStore.recordSleep(startTime: window.start, endTime: window.end, note: "")
                isPresented = false
            } label: {
                Label("保存补录睡眠", systemImage: "checkmark.circle.fill")
                    .font(BBBFont.font(size: 15, weight: .heavy))
                    .foregroundStyle(DesignToken.onPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(canSaveManualSleep ? DesignToken.easySleep : DesignToken.textFaint.opacity(0.36)))
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(!canSaveManualSleep)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(DesignToken.surfaceRaised.opacity(0.94)))
        .onChange(of: manualStartTime) { _, newValue in
            if normalizedManualSleepWindow == nil {
                manualEndTime = newValue.addingTimeInterval(30 * 60)
            }
        }
    }

    private var activeStartBinding: Binding<Date>? {
        guard activeStartTime != nil else { return nil }
        return Binding {
            sleepDraftStore.activeSleepStartAt ?? Date()
        } set: { newValue in
            let capped = SleepRecordFormatter.normalizedStart(
                startTime: newValue,
                endTime: Date(),
                anchorDate: Date()
            ) ?? min(newValue, Date().addingTimeInterval(-60))
            sleepDraftStore.updateStartTime(capped)
            timerTick = Date()
        }
    }

    private func timeString(_ date: Date) -> String {
        AppDateTimeFormat.time(date)
    }
}

func recordSheetContent<Content: View>(
    title: String,
    subtitle: String,
    icon: String,
    accent: Color,
    @ViewBuilder content: () -> Content
) -> some View {
    ZStack {
        LinearGradient(
            colors: [
                DesignToken.canvas,
                DesignToken.surfaceSoft,
                DesignToken.surface
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(accent)
                        .frame(width: 42, height: 42)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(accent.opacity(0.12))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(DesignToken.borderSubtle.opacity(0.9), lineWidth: 1)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title.localized)
                            .font(BBBFont.font(size: 22, weight: .heavy))
                            .foregroundStyle(DesignToken.textPrimary)
                        Text(subtitle.localized)
                            .font(BBBFont.font(size: 12, weight: .semibold))
                            .foregroundStyle(DesignToken.textSecondary)
                            .lineLimit(2)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(DesignToken.surfaceRaised.opacity(0.94))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(DesignToken.borderSubtle.opacity(0.84), lineWidth: 1.2)
                        )
                        .shadow(color: DesignToken.shadowColor.opacity(0.06), radius: 12, y: 5)
                )

                content()
            }
            .padding(18)
        }
    }
}

func saveButton(title: String, color: Color, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Label(title, systemImage: "checkmark.circle.fill")
            .font(BBBFont.font(size: 15, weight: .heavy))
            .foregroundStyle(DesignToken.onPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(DesignToken.primaryGradient)
                    .shadow(color: DesignToken.primary.opacity(0.16), radius: 14, y: 7)
            )
    }
    .buttonStyle(ScaleButtonStyle())
}

struct RecordTopStat: Identifiable {
    let id = UUID()
    var title: String
    var value: String
    var systemIcon: String? = nil
}

struct RecordGlassRecorderMetrics {
    let W: CGFloat
    let H: CGFloat
    let S: CGFloat
    let horizontalPadding: CGFloat
    let headerHeight: CGFloat
    let statsHeight: CGFloat
    let modeHeight: CGFloat
    let dockHeight: CGFloat
    let headerY: CGFloat
    let statsY: CGFloat
    let stageY: CGFloat
    let primaryY: CGFloat
    let modeY: CGFloat
    let dockY: CGFloat
    let stageHeight: CGFloat

    init(size: CGSize, safeAreaInsets: EdgeInsets = EdgeInsets()) {
        W = size.width
        H = size.height
        S = size.width / 393.0
        horizontalPadding = 24 * S
        headerHeight = max(44, 44 * S)
        statsHeight = 54 * S
        modeHeight = 96 * S
        dockHeight = 72 * S
        let islandSafeHeaderY = safeAreaInsets.top + 24 * S
        headerY = max(62 * S, islandSafeHeaderY)
        statsY = headerY + 64 * S
        dockY = size.height - max(70 * S, safeAreaInsets.bottom + 50 * S)
        modeY = dockY - 90 * S
        let stageTop = statsY + statsHeight * 0.5 + 18 * S
        let stageBottom = modeY - modeHeight * 0.5 - 24 * S
        stageHeight = max(180 * S, stageBottom - stageTop)
        stageY = (stageTop + stageBottom) * 0.5 - 10 * S
        primaryY = min(stageBottom - 20 * S, stageY + stageHeight * 0.38)
    }
}

struct RecordGlassRecorderShell<Stage: View, PrimaryControls: View, ModeControls: View, LeadingDock: View, MoreContent: View>: View {
    let title: String
    let stats: [RecordTopStat]
    @Binding var showMore: Bool
    var moreHeight: CGFloat = 280
    let saveTitle: String
    let isSaveEnabled: Bool
    let onClose: () -> Void
    let onSave: () -> Void
    @ViewBuilder var stage: (RecordGlassRecorderMetrics) -> Stage
    @ViewBuilder var primaryControls: (RecordGlassRecorderMetrics) -> PrimaryControls
    @ViewBuilder var modeControls: (RecordGlassRecorderMetrics) -> ModeControls
    @ViewBuilder var leadingDock: (RecordGlassRecorderMetrics) -> LeadingDock
    @ViewBuilder var moreContent: () -> MoreContent

    var body: some View {
        GeometryReader { geometry in
            let metrics = RecordGlassRecorderMetrics(
                size: geometry.size,
                safeAreaInsets: geometry.safeAreaInsets
            )

            ZStack {
                RecordGlassBackground()

                topDataSection(metrics)

                coreSection(metrics)

                footerSection(metrics)
            }
            .frame(width: metrics.W, height: metrics.H)
            .ignoresSafeArea()
        }
        .background(RecordGlassBackground().ignoresSafeArea())
        .ignoresSafeArea()
        .statusBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $showMore) {
            moreContent()
                .presentationDetents([.height(moreHeight)])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
                .presentationCornerRadius(34)
        }
    }

    private func topDataSection(_ metrics: RecordGlassRecorderMetrics) -> some View {
        ZStack {
            RecordGlassCircleButton(systemIcon: "chevron.left", size: metrics.headerHeight, iconSize: 16 * metrics.S, action: onClose)
                .position(x: metrics.horizontalPadding + metrics.headerHeight * 0.5, y: metrics.headerY)

            Text(title.localized)
                .font(BBBFont.font(size: 18 * metrics.S, weight: .bold))
                .foregroundStyle(DesignToken.textPrimary)
                .lineLimit(1)
                .position(x: metrics.W * 0.5, y: metrics.headerY)

            RecordGlassCircleButton(systemIcon: "ellipsis", size: metrics.headerHeight, iconSize: 16 * metrics.S) {
                showMore = true
            }
            .position(x: metrics.W - metrics.horizontalPadding - metrics.headerHeight * 0.5, y: metrics.headerY)

            RecordGlassStatsBar(stats: stats, metrics: metrics)
                .frame(height: metrics.statsHeight)
                .position(x: metrics.W * 0.5, y: metrics.statsY)
        }
        .frame(width: metrics.W, height: metrics.H)
    }

    private func coreSection(_ metrics: RecordGlassRecorderMetrics) -> some View {
        ZStack {
            RecordGlassStageGlow(W: metrics.W, S: metrics.S)
                .position(x: metrics.W * 0.5, y: metrics.stageY + metrics.stageHeight * 0.12)
                .allowsHitTesting(false)

            stage(metrics)
                .position(x: metrics.W * 0.5, y: metrics.stageY)

            primaryControls(metrics)
                .position(x: metrics.W * 0.5, y: metrics.primaryY)
        }
        .frame(width: metrics.W, height: metrics.H)
    }

    private func footerSection(_ metrics: RecordGlassRecorderMetrics) -> some View {
        ZStack {
            modeControls(metrics)
                .frame(height: metrics.modeHeight)
                .position(x: metrics.W * 0.5, y: metrics.modeY)

            RecordGlassBottomDock(
                saveTitle: saveTitle,
                isSaveEnabled: isSaveEnabled,
                S: metrics.S,
                onSave: onSave
            ) {
                leadingDock(metrics)
            }
            .frame(width: metrics.W - 48 * metrics.S, height: metrics.dockHeight)
            .position(x: metrics.W * 0.5, y: metrics.dockY)
        }
        .frame(width: metrics.W, height: metrics.H)
    }
}

struct RecordGlassBackground: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    colors: [
                        DesignToken.canvas,
                        DesignToken.surfaceSoft,
                        DesignToken.surface,
                        DesignToken.surfaceSoft
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                RadialGradient(
                    colors: [
                        DesignToken.glassFill.opacity(0.62),
                        DesignToken.primarySoft.opacity(0.42),
                        .clear
                    ],
                    center: UnitPoint(x: 0.18, y: 0.10),
                    startRadius: 10,
                    endRadius: geo.size.width * 0.75
                )

                RadialGradient(
                    colors: [
                        DesignToken.glassFill.opacity(0.70),
                        DesignToken.glassFill.opacity(0.24),
                        .clear
                    ],
                    center: UnitPoint(x: 0.52, y: 0.48),
                    startRadius: 20,
                    endRadius: geo.size.width * 0.58
                )

                Ellipse()
                    .fill(DesignToken.glassFill.opacity(0.50))
                    .frame(width: geo.size.width * 1.45, height: geo.size.height * 0.17)
                    .blur(radius: 44)
                    .offset(y: geo.size.height * 0.18)

                RadialGradient(
                    colors: [
                        DesignToken.easySleepSoft.opacity(0.40),
                        .clear
                    ],
                    center: UnitPoint(x: 0.12, y: 0.78),
                    startRadius: 10,
                    endRadius: geo.size.width * 0.68
                )

                RadialGradient(
                    colors: [
                        DesignToken.primarySoft.opacity(0.48),
                        .clear
                    ],
                    center: UnitPoint(x: 0.80, y: 0.84),
                    startRadius: 20,
                    endRadius: geo.size.width * 0.70
                )

                VStack {
                    LinearGradient(
                        colors: [
                            DesignToken.primary.opacity(0.16),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: geo.size.height * 0.28)
                    Spacer()
                }

                RecordGlassNoiseOverlay(opacity: 0.036)
                    .blendMode(.softLight)
            }
            .ignoresSafeArea()
        }
    }
}

private struct RecordGlassNoiseOverlay: View {
    let opacity: Double

    private static let image: UIImage = {
        let size = 120
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { context in
            let cgContext = context.cgContext
            for x in 0..<size {
                for y in 0..<size {
                    let white = CGFloat.random(in: 0.74...1.0)
                    let alpha = CGFloat.random(in: 0.025...0.09)
                    cgContext.setFillColor(UIColor(white: white, alpha: alpha).cgColor)
                    cgContext.fill(CGRect(x: x, y: y, width: 1, height: 1))
                }
            }
        }
    }()

    var body: some View {
        Image(uiImage: Self.image)
            .resizable(resizingMode: .tile)
            .opacity(opacity)
            .ignoresSafeArea()
    }
}

struct RecordGlassStatsBar: View {
    let stats: [RecordTopStat]
    let metrics: RecordGlassRecorderMetrics

    var body: some View {
        let totalWidth = metrics.W - 48 * metrics.S
        let dividerWidth = 1 * metrics.S
        let columnWidth = (totalWidth - 3 * dividerWidth) / 4

        HStack(spacing: 0) {
            ForEach(Array(stats.prefix(4).enumerated()), id: \.offset) { index, stat in
                VStack(spacing: 6 * metrics.S) {
                    Text(stat.value.localized)
                        .font(BBBFont.font(size: 12 * metrics.S, weight: .semibold))
                        .foregroundStyle(DesignToken.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.62)
                        .allowsTightening(true)
                        .monospacedDigit()

                    Text(stat.title.localized)
                        .font(BBBFont.font(size: 8 * metrics.S, weight: .regular))
                        .foregroundStyle(DesignToken.textSecondary.opacity(0.62))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                .frame(width: columnWidth)
                .clipped()

                if index < 3 {
                    Rectangle()
                        .fill(DesignToken.borderSubtle.opacity(0.72))
                        .frame(width: dividerWidth, height: 32 * metrics.S)
                }
            }
        }
        .frame(width: totalWidth, height: 54 * metrics.S)
    }
}

struct RecordGlassCircleButton: View {
    let systemIcon: String
    let size: CGFloat
    let iconSize: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemIcon)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(DesignToken.textMuted.opacity(0.88))
                .frame(width: size, height: size)
                .glassEffect(.regular.tint(DesignToken.glassFill.opacity(0.10)).interactive(), in: .circle)
                .overlay(Circle().fill(DesignToken.glassFill.opacity(0.075)))
                .overlay(Circle().stroke(DesignToken.glassStroke.opacity(0.36), lineWidth: 1))
                .overlay(alignment: .topLeading) {
                    Circle()
                        .stroke(DesignToken.glassStroke.opacity(0.24), lineWidth: 1)
                        .blur(radius: 0.5)
                        .padding(3)
                }
                .shadow(color: DesignToken.glassStroke.opacity(0.28), radius: 8, y: -1)
                .shadow(color: DesignToken.shadowColor.opacity(0.075), radius: 11, y: 5)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isButton)
    }
}

struct RecordGlassStageSideButton: View {
    let systemIcon: String
    let S: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Color.clear
                .frame(width: 56 * S, height: 56 * S)
                .overlay {
                    Image(systemName: systemIcon)
                        .font(.system(size: 16 * S, weight: .medium))
                        .foregroundStyle(DesignToken.textMuted.opacity(0.78))
                        .shadow(color: DesignToken.glassStroke.opacity(0.46), radius: 5, y: -1)
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

struct RecordGlassStageGlow: View {
    let W: CGFloat
    let S: CGFloat

    var body: some View {
        ZStack {
            Ellipse()
                .fill(DesignToken.glassFill.opacity(0.24))
                .frame(width: W * 0.72, height: 116 * S)
                .blur(radius: 30 * S)

            RadialGradient(
                colors: [
                    DesignToken.glassFill.opacity(0.34),
                    DesignToken.primarySoft.opacity(0.14),
                    .clear
                ],
                center: .center,
                startRadius: 12 * S,
                endRadius: 150 * S
            )
            .frame(width: W * 0.76, height: 210 * S)
        }
        .allowsHitTesting(false)
    }
}

struct RecordGlassBottomDock<Leading: View>: View {
    let saveTitle: String
    let isSaveEnabled: Bool
    let S: CGFloat
    let onSave: () -> Void
    @ViewBuilder var leading: () -> Leading

    var body: some View {
        GlassEffectContainer(spacing: 7 * S) {
            HStack(spacing: 7 * S) {
                leading()

                Button(action: onSave) {
                    Text(saveTitle)
                        .font(BBBFont.font(size: 18 * S, weight: .bold))
                        .foregroundStyle(DesignToken.onPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56 * S)
                        .glassEffect(
                            .regular
                                .tint(DesignToken.primary.opacity(0.84))
                                .interactive(),
                            in: .capsule
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            DesignToken.primary,
                                            DesignToken.primary.opacity(0.82)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                        .overlay(Capsule(style: .continuous).stroke(DesignToken.glassStroke.opacity(0.66), lineWidth: 1))
                        .shadow(color: DesignToken.primary.opacity(0.26), radius: 18, y: 7)
                }
                .disabled(!isSaveEnabled)
                .opacity(isSaveEnabled ? 1 : 0.58)
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(8 * S)
        .glassEffect(.regular.tint(DesignToken.glassFill.opacity(0.18)), in: .capsule)
        .overlay(Capsule(style: .continuous).stroke(DesignToken.glassStroke.opacity(0.56), lineWidth: 1))
        .shadow(color: DesignToken.glassStroke.opacity(0.42), radius: 14, y: -2)
        .shadow(color: DesignToken.shadowColor.opacity(0.14), radius: 22, y: 9)
    }
}

struct RecordGlassDockActionButton: View {
    let title: String
    let systemIcon: String
    var foreground: Color = DesignToken.textSecondary
    var S: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8 * S) {
                Image(systemName: systemIcon)
                    .font(.system(size: 14 * S, weight: .bold))
                Text(title.localized)
                    .font(BBBFont.font(size: 13 * S, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
            }
                .foregroundStyle(foreground.opacity(0.84))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Capsule(style: .continuous))
                .glassEffect(.regular.tint(DesignToken.glassFill.opacity(0.16)).interactive(), in: .capsule)
                .overlay(Capsule(style: .continuous).fill(DesignToken.glassFill.opacity(0.055)))
                .overlay(Capsule(style: .continuous).stroke(DesignToken.glassStroke.opacity(0.30), lineWidth: 1))
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct RecordGlassModeSelector<Item: Identifiable & Equatable, Content: View>: View {
    let items: [Item]
    let selected: Item
    let S: CGFloat
    let action: (Item) -> Void
    @ViewBuilder var content: (Item, Bool) -> Content

    var body: some View {
        HStack(spacing: 16 * S) {
            ForEach(items) { item in
                let isSelected = item == selected
                Button {
                    action(item)
                } label: {
                    content(item, isSelected)
                        .frame(width: 56 * S, height: 56 * S)
                        .scaleEffect(isSelected ? 1.055 : 1.0)
                        .offset(y: isSelected ? -2 * S : 0)
                        .glassEffect(
                            .regular
                                .tint(isSelected ? DesignToken.primary.opacity(0.82) : DesignToken.glassFill.opacity(0.025))
                                .interactive(),
                            in: .rect(cornerRadius: 19 * S)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 19 * S, style: .continuous)
                                .stroke(DesignToken.glassStroke.opacity(isSelected ? 0.78 : 0.14), lineWidth: 1)
                        )
                        .overlay {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 19 * S, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                DesignToken.primary.opacity(0.36),
                                                DesignToken.primarySoft.opacity(0.24)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                        }
                        .overlay(alignment: .top) {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 12 * S, style: .continuous)
                                    .fill(DesignToken.glassFill.opacity(0.34))
                                    .frame(width: 38 * S, height: 11 * S)
                                    .padding(.top, 4 * S)
                            }
                        }
                        .shadow(
                            color: DesignToken.primary.opacity(isSelected ? 0.28 : 0.01),
                            radius: isSelected ? 18 : 6,
                            y: isSelected ? 8 : 3
                        )
                        .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isSelected)
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
    }
}

struct RecordEditorShell<Hero: View, Controls: View, LeadingDock: View, MoreContent: View>: View {
    let title: String
    let stats: [RecordTopStat]
    @Binding var showMore: Bool
    let saveTitle: String
    let isSaveEnabled: Bool
    let onClose: () -> Void
    let onSave: () -> Void
    @ViewBuilder var hero: () -> Hero
    @ViewBuilder var controls: () -> Controls
    @ViewBuilder var leadingDock: () -> LeadingDock
    @ViewBuilder var moreContent: () -> MoreContent

    var body: some View {
        GeometryReader { proxy in
            let isCompactHeight = proxy.size.height < 760

            ZStack(alignment: .bottom) {
                recordEditorBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    VStack(spacing: isCompactHeight ? 12 : 18) {
                        recordHeader
                            .padding(.top, isCompactHeight ? 10 : 16)
                        RecordTopStatsBar(stats: stats)
                    }
                    .padding(.horizontal, 28)

                    Spacer(minLength: isCompactHeight ? 4 : 8)

                    hero()
                        .frame(maxWidth: .infinity)

                    controls()
                        .padding(.horizontal, 20)
                        .padding(.top, isCompactHeight ? 4 : 8)

                    Spacer(minLength: isCompactHeight ? 98 : 118)
                }

                RecordBottomDock(
                    saveTitle: saveTitle,
                    isSaveEnabled: isSaveEnabled,
                    onSave: onSave,
                    showMore: $showMore,
                    leading: leadingDock
                )
                .padding(.horizontal, 16)
                .padding(.bottom, max(proxy.safeAreaInsets.bottom, 10))
            }
        }
        .statusBarHidden(true)
        .popover(isPresented: $showMore, attachmentAnchor: .point(.bottomTrailing), arrowEdge: .bottom) {
            moreContent()
                .presentationCompactAdaptation(.popover)
        }
    }

    private var recordHeader: some View {
        ZStack {
            HStack {
                RecordGlassButton(systemIcon: "chevron.left", size: 48, iconSize: 22, action: onClose)
                Spacer()
                RecordGlassButton(systemIcon: "ellipsis", size: 48, iconSize: 20) {
                    showMore = true
                }
            }

            Text(title.localized)
                .font(BBBFont.font(size: 28, weight: .heavy))
                .foregroundStyle(DesignToken.textStrong)
                .shadow(color: DesignToken.glassStroke.opacity(0.72), radius: 2, y: 1)
        }
        .frame(height: 52)
    }
}

struct RecordTopStatsBar: View {
    let stats: [RecordTopStat]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(stats.prefix(4).enumerated()), id: \.element.id) { index, stat in
                VStack(spacing: 5) {
                    if let systemIcon = stat.systemIcon {
                        Image(systemName: systemIcon)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(DesignToken.textMuted.opacity(0.78))
                            .frame(height: 20)
                    } else {
                        Text(stat.title.localized)
                            .font(BBBFont.font(size: 13, weight: .bold))
                            .foregroundStyle(DesignToken.textMuted.opacity(0.76))
                            .lineLimit(1)
                            .minimumScaleFactor(0.74)
                            .frame(height: 20)
                    }

                    Text(stat.value.localized)
                        .font(BBBFont.font(size: 20, weight: .heavy))
                        .foregroundStyle(DesignToken.textStrong)
                        .lineLimit(1)
                        .minimumScaleFactor(0.42)
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity)

                if index < min(stats.count, 4) - 1 {
                    Rectangle()
                        .fill(DesignToken.borderSubtle.opacity(0.72))
                        .frame(width: 1, height: 40)
                        .padding(.horizontal, 7)
                }
            }
        }
        .frame(height: 56)
    }
}

struct RecordHeroStage<Content: View>: View {
    let assetName: String?
    let fallbackSystemIcon: String
    let accent: Color
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            Ellipse()
                .fill(accent.opacity(0.14))
                .frame(width: 260, height: 54)
                .blur(radius: 16)
                .offset(y: 132)

            if let assetName, UIImage(named: assetName) != nil {
                Image(assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 360, maxHeight: 390)
            } else {
                fallbackHero
            }

            content()
        }
        .frame(maxWidth: .infinity)
        .containerRelativeFrame(.vertical) { length, _ in
            length < 760 ? 310 : 390
        }
    }

    private var fallbackHero: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .overlay(Circle().fill(DesignToken.glassFill.opacity(0.34)))
                .overlay(Circle().stroke(DesignToken.glassStroke.opacity(0.78), lineWidth: 1.2))
                .frame(width: 230, height: 230)
                .shadow(color: accent.opacity(0.18), radius: 24, y: 14)

            Image(systemName: fallbackSystemIcon)
                .font(.system(size: 82, weight: .light))
                .foregroundStyle(accent.opacity(0.78))
        }
    }
}

struct RecordModeSelector<Item: Identifiable & Equatable, ItemContent: View>: View {
    let items: [Item]
    let selected: Item
    let action: (Item) -> Void
    @ViewBuilder var content: (Item, Bool) -> ItemContent

    var body: some View {
        HStack(spacing: 10) {
            ForEach(items) { item in
                Button {
                    action(item)
                } label: {
                    content(item, item == selected)
                        .frame(maxWidth: .infinity)
                        .frame(height: 74)
                        .background(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(item == selected ? DesignToken.primary.opacity(0.66) : DesignToken.glassFill.opacity(0.58))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .stroke(DesignToken.glassStroke.opacity(item == selected ? 0.86 : 0.72), lineWidth: 1.2)
                                )
                                .shadow(color: DesignToken.primary.opacity(item == selected ? 0.18 : 0.05), radius: item == selected ? 16 : 8, y: 6)
                        )
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
    }
}

struct RecordBottomDock<Leading: View>: View {
    let saveTitle: String
    let isSaveEnabled: Bool
    let onSave: () -> Void
    @Binding var showMore: Bool
    @ViewBuilder var leading: () -> Leading

    var body: some View {
        HStack(spacing: 12) {
            leading()

            Button(action: onSave) {
                Label(saveTitle, systemImage: "checkmark.circle.fill")
                    .font(BBBFont.font(size: 23, weight: .heavy))
                    .foregroundStyle(DesignToken.onPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .frame(maxWidth: .infinity)
                    .frame(height: 62)
                    .background(
                        Capsule(style: .continuous)
                            .fill(isSaveEnabled ? DesignToken.primaryGradient : LinearGradient(colors: [.gray.opacity(0.44), .gray.opacity(0.44)], startPoint: .leading, endPoint: .trailing))
                            .overlay(Capsule(style: .continuous).stroke(DesignToken.glassStroke.opacity(0.58), lineWidth: 1.1))
                    )
            }
            .disabled(!isSaveEnabled)
            .buttonStyle(ScaleButtonStyle())

            RecordGlassButton(systemIcon: "ellipsis", size: 62, iconSize: 24) {
                showMore = true
            }
        }
        .padding(8)
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(Capsule(style: .continuous).fill(DesignToken.glassFill.opacity(0.34)))
                .overlay(Capsule(style: .continuous).stroke(DesignToken.glassStroke.opacity(0.70), lineWidth: 1.1))
                .shadow(color: DesignToken.shadowColor.opacity(0.18), radius: 24, y: 10)
        )
    }
}

struct RecordGlassButton: View {
    let systemIcon: String
    var size: CGFloat = 54
    var iconSize: CGFloat = 20
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemIcon)
                .font(.system(size: iconSize, weight: .heavy))
                .foregroundStyle(DesignToken.onPrimary.opacity(0.96))
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(Circle().fill(DesignToken.glassFill.opacity(0.22)))
                        .overlay(Circle().stroke(DesignToken.glassStroke.opacity(0.76), lineWidth: 1.1))
                        .shadow(color: DesignToken.shadowColor.opacity(0.12), radius: 16, y: 7)
                )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

private var recordEditorBackground: some View {
    ZStack {
        LinearGradient(
            colors: [
                DesignToken.canvas,
                DesignToken.surfaceSoft,
                DesignToken.surface
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        Circle()
            .fill(DesignToken.easySleepSoft.opacity(0.34))
            .frame(width: 340, height: 340)
            .blur(radius: 86)
            .offset(x: -128, y: 132)

        Circle()
            .fill(DesignToken.easyActivitySoft.opacity(0.28))
            .frame(width: 330, height: 330)
            .blur(radius: 88)
            .offset(x: 132, y: 270)

        Rectangle()
            .fill(.ultraThinMaterial)
            .opacity(0.10)
    }
}

private func simplePage(icon: String, title: String, subtitle: String) -> some View {
    ZStack {
        DesignToken.bg.ignoresSafeArea()
        VStack(spacing: 18) {
            Image(systemName: icon)
                .font(.system(size: 46, weight: .semibold))
                .foregroundStyle(DesignToken.primary)
            Text(title.localized)
                .font(BBBFont.font(size: 24, weight: .bold))
                .foregroundStyle(DesignToken.textPrimary)
            Text(subtitle.localized)
                .font(BBBFont.font(size: 15, weight: .medium))
                .foregroundStyle(DesignToken.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .cardStyle()
        .padding(28)
    }
}
