import PhotosUI
import Photos
import SwiftUI
import UIKit
import AVFoundation
import CoreMotion
import Vision

struct DailyMessageView: View {
    var body: some View {
        Color.clear
            .ignoresSafeArea()
            .navigationBarBackButtonHidden(false)
            .toolbar(.hidden, for: .navigationBar)
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
            return latestReport.visitorIDs
                .prefix(CompanionRecruitmentStore.dailyBuddyFeedLimit)
                .map { BabyCompanion.companion(for: $0) }
        }
        let visitors = recruitmentStore.lockedVisitorCompanions(for: todaysVisitorKey)
        if !visitors.isEmpty {
            return visitors
        }
        return [companionStore.selected]
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
            recruitmentStore: recruitmentStore
        )
    }

    private var recentVisitorReports: [YesterdayReport] {
        var reportsByKey = Dictionary(uniqueKeysWithValues: recruitmentStore.reports.map { ($0.reportKey, $0) })
        if let latestVisitorReport {
            reportsByKey[latestVisitorReport.reportKey] = latestVisitorReport
        }

        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: -7, to: Date()) ?? .distantPast

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
                tint: Color(hex: "#FFF7B8"),
                level: 16,
                badge: "宝",
                isCareLog: true
            )
        }

        return [
            LiveChatMessage(speaker: liveHostCompanion.chineseName, text: "加入了直播间", tint: Color(hex: "#FFFFFF"), level: 34, isJoin: true),
            LiveChatMessage(speaker: liveHostCompanion.chineseName, text: "我今天是随机来访的伙伴，可以用 BB Bucks 慢慢加深友情。", tint: Color(hex: "#FFF7B8"), level: 18, badge: "访"),
            LiveChatMessage(speaker: "尤卡", text: "小木屋灯亮啦，今天的陪伴直播开始。", tint: Color(hex: "#D9F6FF"), level: 23),
            LiveChatMessage(speaker: "芬灵", text: "我在地图右边巡逻，看到好多发光小花。", tint: Color(hex: "#D9F6FF"), level: 10, badge: "管"),
            LiveChatMessage(speaker: "柯噜", text: "如果宝宝刚吃饱，我们就把掌声开小一点。", tint: Color(hex: "#FFFFFF"), level: 3)
        ] + careMessages + [
            LiveChatMessage(speaker: "摩耶", text: "今天也在稳定记录，照护节奏越来越清楚。", tint: Color(hex: "#D9F6FF"), level: 36),
            LiveChatMessage(speaker: "奇比", text: "我给宝宝攒了一颗温柔星星。", tint: Color(hex: "#FFFFFF"), level: 8)
        ]
    }

    private func careText(for session: FeedingSession) -> String {
        let time = session.createdAt.formatted(.dateTime.hour().minute())
        if session.totalBottleAmount > 0 {
            return "\(time) 喝了 \(session.totalBottleAmount)ml，好厉害。"
        }
        if session.totalBreastDuration > 0 {
            return "\(time) 亲喂 \(session.totalBreastDuration) 分钟，节奏很稳。"
        }
        if session.totalSolidAmount > 0 {
            return "\(time) 吃了 \(Int(session.totalSolidAmount))g 辅食，小动物都在鼓掌。"
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
                Text(companion.chineseName)
                    .font(BBBFont.font(size: 16, weight: .heavy))
                    .foregroundStyle(DesignToken.textPrimary)
                    .lineLimit(1)

                Text(companion.temperamentLabel)
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
                                    Color.white.opacity(0.88),
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
        .accessibilityLabel("当前 Buddy，\(companion.chineseName)，\(companion.temperamentLabel)")
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
                    Text(companion.chineseName)
                        .font(BBBFont.font(size: 16, weight: .heavy))
                        .foregroundStyle(DesignToken.textPrimary)
                        .lineLimit(1)

                    Text(companion.temperamentLabel)
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
                    .fill(Color.white.opacity(0.82))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.white.opacity(0.86), lineWidth: 1)
                    )
                    .shadow(color: Color(hex: "#4D4B70").opacity(0.06), radius: 14, y: 7)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("\(report.dateText) 来访，\(companion.chineseName)，\(companion.temperamentLabel)")
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
        Text(title)
            .font(BBBFont.font(size: 9, weight: .heavy))
            .foregroundStyle(isFilled ? .white : text)
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
                    Color(hex: "#F5F1FA"),
                    Color(hex: "#FAF9FC"),
                    Color(hex: "#EEF6FB")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color.white.opacity(0.74),
                    Color.white.opacity(0)
                ],
                center: .top,
                startRadius: 18,
                endRadius: 420
            )
            .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.clear,
                    Color(hex: "#ECEBFF").opacity(0.34)
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
                ZStack(alignment: .topTrailing) {
                    CompanionAnimalFigure(
                        companion: companion,
                        isUnlocked: isUnlocked,
                        size: isUnlocked ? 68 : 72
                    )
                    .frame(width: 80, height: 78, alignment: .center)

                    if isCurrent {
                        Text("当前")
                            .font(BBBFont.font(size: 8, weight: .heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .frame(height: 17)
                            .background(Capsule().fill(DesignToken.primaryGradient))
                            .offset(x: 1, y: 0)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 80)

                VStack(spacing: 2) {
                    Text(isUnlocked ? companion.chineseName : "未解锁")
                        .font(BBBFont.font(size: 12, weight: .heavy))
                        .foregroundStyle(isUnlocked ? DesignToken.textPrimary : DesignToken.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    heartRow(count: affectionHeartCount(for: companion, isUnlocked: isUnlocked), size: 8)
                }
            }
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(isUnlocked ? "\(companion.chineseName), \(companion.species)" : "未获取伙伴")
    }

    private var latestVisitorReport: YesterdayReport? {
        DailyVisitorReportFactory.availableReport(
            feedingStore: feedingStore,
            activityStore: activityStore,
            recruitmentStore: recruitmentStore
        )
    }

    private var recentVisitorReports: [YesterdayReport] {
        var reportsByKey = Dictionary(uniqueKeysWithValues: recruitmentStore.reports.map { ($0.reportKey, $0) })
        if let latestVisitorReport {
            reportsByKey[latestVisitorReport.reportKey] = latestVisitorReport
        }

        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: -7, to: Date()) ?? .distantPast

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

    private func affectionHeartCount(for companion: BabyCompanion, isUnlocked: Bool) -> Int {
        if companionStore.selectedID == companion.id { return 3 }
        let progress = recruitmentStore.friendshipPercent(for: companion.id)
        let count = Int(ceil(progress * 3))
        return isUnlocked ? max(1, count) : count
    }

    private func heartRow(count: Int, size: CGFloat) -> some View {
        HStack(spacing: max(size * 0.18, 1)) {
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: index < count ? "heart.fill" : "heart")
                    .font(.system(size: size, weight: .heavy))
                    .foregroundStyle(index < count ? Color(hex: "#DFA2AE") : Color(hex: "#C9C7D2").opacity(0.62))
            }
        }
    }
}

private struct CompanionScenePage: View {
    @EnvironmentObject private var companionStore: CompanionStore
    @EnvironmentObject private var recruitmentStore: CompanionRecruitmentStore
    @EnvironmentObject private var temperamentStore: TemperamentProfileStore
    @State private var selectedShelfTab: CompanionSceneShelfTab = .all
    @State private var isShelfExpanded = false
    @State private var selectedShelfCompanion: BabyCompanion?
    @State private var isScenePickerPresented = false
    @AppStorage("companion_scene_selection_id") private var selectedSceneID = CompanionSceneOption.cozyRoom.rawValue

    let visitorCompanions: [BabyCompanion]
    let recentVisitorReports: [YesterdayReport]
    let openCompanionPicker: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                sceneLayer(size: proxy.size)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    sceneControls
                        .padding(.horizontal, 22)
                        .padding(.bottom, shelfHeight(for: proxy.size) + 14)
                }

                CompanionSceneShelfPanel(
                    selectedTab: $selectedShelfTab,
                    isExpanded: $isShelfExpanded,
                    companions: companions(for: selectedShelfTab),
                    selectedCompanionID: companionStore.selectedID,
                    unlockedIDs: unlockedCompanionIDs,
                    friendshipPercent: { recruitmentStore.friendshipPercent(for: $0.id) },
                    onOpenDetail: openCompanionDetail(_:)
                )
                .frame(height: shelfHeight(for: proxy.size))
                .transition(.move(edge: .bottom))
            }
            .overlay {
                if let selectedShelfCompanion {
                    CompanionDetailOverlay(
                        companion: selectedShelfCompanion,
                        selectedCompanion: $selectedShelfCompanion,
                        onSetCurrent: {
                            withAnimation(.interactiveSpring(response: 0.30, dampingFraction: 0.86)) {
                                isShelfExpanded = false
                            }
                        }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .zIndex(20)
                }
            }
            .animation(.interactiveSpring(response: 0.34, dampingFraction: 0.86), value: isShelfExpanded)
            .animation(.interactiveSpring(response: 0.28, dampingFraction: 0.88), value: selectedShelfTab)
            .animation(.easeOut(duration: 0.18), value: selectedShelfCompanion?.id)
        }
        .background(Color(hex: "#F4F1FA"))
        .sheet(isPresented: $isScenePickerPresented) {
            CompanionScenePickerSheet(selectedScene: selectedSceneBinding)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    private func sceneLayer(size: CGSize) -> some View {
        ZStack {
            CompanionSceneBackground(scene: selectedScene)
                .frame(width: size.width, height: size.height)
                .clipped()

            CompanionAnimalFigure(
                companion: visitorCompanion,
                isUnlocked: true,
                size: visitorSize(for: size)
            )
            .rotationEffect(.degrees(-8))
            .shadow(color: Color(hex: "#7E5D3F").opacity(0.18), radius: 18, y: 10)
            .position(
                x: size.width * 0.10,
                y: max(230, size.height * 0.47)
            )

            CompanionAnimalFigure(
                companion: companionStore.selected,
                isUnlocked: true,
                size: hostSize(for: size)
            )
            .shadow(color: Color(hex: "#7E5D3F").opacity(0.20), radius: 24, y: 12)
            .position(
                x: size.width * 0.50,
                y: max(270, size.height * 0.49)
            )
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }

    private var sceneControls: some View {
        HStack(alignment: .center) {
            bbBucksPill
            Spacer()
            sceneActionButton(symbol: "photo.on.rectangle.angled", label: "更换场景") {
                isScenePickerPresented = true
            }
            sceneActionButton(symbol: "arrow.triangle.2.circlepath", label: "更换当前 Buddy") {
                selectedShelfTab = .unlocked
                isShelfExpanded = true
            }
        }
    }

    private var bbBucksPill: some View {
        HStack(spacing: 9) {
            Image(systemName: "circle.hexagongrid.fill")
                .font(.system(size: 18, weight: .bold))
            Text("\(recruitmentStore.bbBucks)")
                .font(BBBFont.font(size: 19, weight: .heavy))
                .monospacedDigit()
        }
        .foregroundStyle(DesignToken.primary)
        .padding(.horizontal, 18)
        .frame(height: 48)
        .background(.white.opacity(0.72), in: Capsule(style: .continuous))
        .overlay(Capsule(style: .continuous).stroke(.white.opacity(0.82), lineWidth: 1))
        .shadow(color: DesignToken.primary.opacity(0.16), radius: 18, y: 8)
        .accessibilityLabel("BB Bucks \(recruitmentStore.bbBucks)")
    }

    private func sceneActionButton(symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 54, height: 54)
                .background(Circle().fill(DesignToken.primaryGradient))
                .shadow(color: DesignToken.primary.opacity(0.24), radius: 16, y: 8)
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(label)
    }

    private var selectedScene: CompanionSceneOption {
        CompanionSceneOption(rawValue: selectedSceneID) ?? .cozyRoom
    }

    private var selectedSceneBinding: Binding<CompanionSceneOption> {
        Binding(
            get: { selectedScene },
            set: { selectedSceneID = $0.rawValue }
        )
    }

    private func shelfHeight(for size: CGSize) -> CGFloat {
        if isShelfExpanded {
            return max(size.height - 46, size.height * 0.86)
        }
        return min(max(size.height * 0.45, 365), size.height * 0.54)
    }

    private func hostSize(for size: CGSize) -> CGFloat {
        min(max(size.width * 0.34, 134), 178)
    }

    private func visitorSize(for size: CGSize) -> CGFloat {
        min(max(size.width * 0.28, 108), 148)
    }

    private var visitorCompanion: BabyCompanion {
        recentVisitors.first ?? visitorCompanions.first ?? recruitmentStore.visitorCompanion(for: todayKey)
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

    private func openCompanionDetail(_ companion: BabyCompanion) {
        selectedShelfCompanion = companion
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
    case cozyRoom
    case sunnyNursery
    case moonlitRoom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cozyRoom:
            return "暖阳客厅"
        case .sunnyNursery:
            return "晴空儿童房"
        case .moonlitRoom:
            return "月光小屋"
        }
    }

    var subtitle: String {
        switch self {
        case .cozyRoom:
            return "当前默认场景"
        case .sunnyNursery:
            return "预留第二张场景图"
        case .moonlitRoom:
            return "预留第三张场景图"
        }
    }

    var assetName: String {
        switch self {
        case .cozyRoom:
            return "companion_buddy_scene_01"
        case .sunnyNursery:
            return "companion_buddy_scene_02"
        case .moonlitRoom:
            return "companion_buddy_scene_03"
        }
    }

    var fallbackAssetName: String? {
        switch self {
        case .cozyRoom:
            return "companion_buddy_scene_placeholder"
        case .sunnyNursery:
            return nil
        case .moonlitRoom:
            return "companion_buddy_scene_placeholder"
        }
    }

    var palette: [Color] {
        switch self {
        case .cozyRoom:
            return [Color(hex: "#FFE0BF"), Color(hex: "#FFF1DA"), Color(hex: "#E7E0FF")]
        case .sunnyNursery:
            return [Color(hex: "#DDEEFF"), Color(hex: "#F5F0FF"), Color(hex: "#FFE4D6")]
        case .moonlitRoom:
            return [Color(hex: "#E7F5EA"), Color(hex: "#FFF3D6"), Color(hex: "#F5E8FF")]
        }
    }
}

private struct CompanionScenePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
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

            VStack(spacing: 12) {
                ForEach(CompanionSceneOption.allCases) { scene in
                    CompanionScenePickerRow(
                        scene: scene,
                        isSelected: selectedScene == scene
                    ) {
                        selectedScene = scene
                        dismiss()
                    }
                }
            }
            .padding(.horizontal, 18)

            Spacer(minLength: 0)
        }
        .background(
            LinearGradient(
                colors: [Color(hex: "#FBF9FF"), Color(hex: "#F5F0FA"), Color(hex: "#FFF7EF")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }
}

private struct CompanionScenePickerRow: View {
    let scene: CompanionSceneOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                CompanionScenePreview(scene: scene)
                    .frame(width: 92, height: 68)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(.white.opacity(0.82), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 5) {
                    Text(scene.title)
                        .font(BBBFont.font(size: 17, weight: .heavy))
                        .foregroundStyle(DesignToken.textPrimary)
                    Text(scene.subtitle)
                        .font(BBBFont.font(size: 12, weight: .semibold))
                        .foregroundStyle(DesignToken.textSecondary)
                }

                Spacer(minLength: 0)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(isSelected ? DesignToken.primary : Color(hex: "#C9C3D7"))
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.white.opacity(isSelected ? 0.92 : 0.72))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(isSelected ? DesignToken.primary.opacity(0.34) : .white.opacity(0.80), lineWidth: 1)
            )
            .shadow(color: Color(hex: "#7E5DE8").opacity(isSelected ? 0.14 : 0.07), radius: 16, y: 8)
        }
        .buttonStyle(ScaleButtonStyle())
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
                colors: [.white.opacity(0.28), .white.opacity(0.02), Color(hex: "#FFF2DC").opacity(0.24)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

private struct CompanionSceneBackground: View {
    let scene: CompanionSceneOption

    var body: some View {
        ZStack {
            CompanionSceneImage(scene: scene)

            LinearGradient(
                colors: scene.palette,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(0.20)

            LinearGradient(
                colors: [.white.opacity(0.55), .white.opacity(0.04), Color(hex: "#FFF2DC").opacity(0.38)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

private struct CompanionSceneImage: View {
    let scene: CompanionSceneOption

    var body: some View {
        if let assetName = resolvedAssetName {
            Image(assetName)
                .resizable()
                .scaledToFill()
        } else {
            LinearGradient(
                colors: scene.palette,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var resolvedAssetName: String? {
        if UIImage(named: scene.assetName) != nil {
            return scene.assetName
        }
        if let fallbackAssetName = scene.fallbackAssetName, UIImage(named: fallbackAssetName) != nil {
            return fallbackAssetName
        }
        return nil
    }
}

private struct CompanionSceneShelfPanel: View {
    @Binding var selectedTab: CompanionSceneShelfTab
    @Binding var isExpanded: Bool
    let companions: [BabyCompanion]
    let selectedCompanionID: String
    let unlockedIDs: Set<String>
    let friendshipPercent: (BabyCompanion) -> Double
    let onOpenDetail: (BabyCompanion) -> Void

    private let columns = Array(repeating: GridItem(.flexible(minimum: 0), spacing: 12), count: 3)
    private let dragThreshold: CGFloat = 42

    var body: some View {
        VStack(spacing: 0) {
            shelfChrome

            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(displayCompanions, id: \.id) { companion in
                        CompanionSceneShelfCard(
                            companion: companion,
                            isSelected: companion.id == selectedCompanionID,
                            isUnlocked: unlockedIDs.contains(companion.id),
                            friendshipPercent: friendshipPercent(companion),
                            onTap: {
                                onOpenDetail(companion)
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, isExpanded ? 34 : 126)
            }
            .id(selectedTab.id)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .contentShape(Rectangle())
        .simultaneousGesture(panelExpansionGesture)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28)
                .fill(.ultraThinMaterial)
                .overlay(
                    UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28)
                        .fill(Color(hex: "#F5F2FF").opacity(0.82))
                )
                .overlay(alignment: .top) {
                    UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28)
                        .stroke(.white.opacity(0.72), lineWidth: 1)
                }
                .shadow(color: Color(hex: "#7563B8").opacity(0.14), radius: 22, y: -8)
        )
    }

    private var shelfChrome: some View {
        VStack(spacing: 0) {
            handle
            tabBar
        }
        .contentShape(Rectangle())
        .gesture(shelfDragGesture)
        .accessibilityHint(isExpanded ? "下滑收起伙伴列表" : "上滑展开伙伴列表")
    }

    private var handle: some View {
        Button {
            withAnimation(.interactiveSpring(response: 0.30, dampingFraction: 0.86)) {
                isExpanded.toggle()
            }
        } label: {
            Capsule()
                .fill(Color(hex: "#C8BFF0"))
                .frame(width: 46, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 10)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isExpanded ? "收起伙伴列表" : "展开伙伴列表")
    }

    private var shelfDragGesture: some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .local)
            .onEnded { value in
                let predicted = value.predictedEndTranslation
                let vertical = abs(predicted.height) > abs(predicted.width) ? predicted.height : value.translation.height
                guard abs(vertical) >= dragThreshold, abs(vertical) > abs(value.translation.width) else { return }

                withAnimation(.interactiveSpring(response: 0.30, dampingFraction: 0.86)) {
                    if vertical < 0 {
                        isExpanded = true
                    } else {
                        isExpanded = false
                    }
                }
            }
    }

    private var panelExpansionGesture: some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .local)
            .onEnded { value in
                guard !isExpanded else { return }
                let predicted = value.predictedEndTranslation
                let vertical = abs(predicted.height) > abs(predicted.width) ? predicted.height : value.translation.height
                guard vertical <= -dragThreshold, abs(vertical) > abs(value.translation.width) else { return }

                withAnimation(.interactiveSpring(response: 0.30, dampingFraction: 0.86)) {
                    isExpanded = true
                }
            }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(CompanionSceneShelfTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 8) {
                        Text(tab.title)
                            .font(BBBFont.font(size: 15, weight: selectedTab == tab ? .heavy : .bold))
                            .foregroundStyle(selectedTab == tab ? Color(hex: "#2F2E74") : Color(hex: "#9188C1"))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)

                        Capsule()
                            .fill(selectedTab == tab ? DesignToken.primary : .clear)
                            .frame(width: 42, height: 4)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 2)
    }

    private var displayCompanions: [BabyCompanion] {
        companions.companionSceneUniquedByID()
    }
}

private struct CompanionSceneShelfCard: View {
    let companion: BabyCompanion
    let isSelected: Bool
    let isUnlocked: Bool
    let friendshipPercent: Double
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 7) {
                ZStack(alignment: .topTrailing) {
                    CompanionAnimalFigure(companion: companion, isUnlocked: isUnlocked, size: 92)
                        .frame(maxWidth: .infinity)
                        .frame(height: 94)
                        .padding(.top, 8)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(DesignToken.primary)
                            .background(Circle().fill(.white))
                            .padding(9)
                    } else if !isUnlocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color(hex: "#9D96B7"))
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(Color(hex: "#ECE8F7")))
                            .padding(8)
                    }
                }

                Text(companion.chineseName)
                    .font(BBBFont.font(size: 15, weight: .heavy))
                    .foregroundStyle(Color(hex: "#27285F"))
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Image(systemName: isUnlocked ? "heart.fill" : "heart")
                        .font(.system(size: 10, weight: .bold))
                    Text(statusText)
                        .font(BBBFont.font(size: 12, weight: .bold))
                }
                .foregroundStyle(isUnlocked ? Color(hex: "#6F66A5") : DesignToken.primary)
                .padding(.bottom, 10)
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(0.80, contentMode: .fit)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.white.opacity(isUnlocked ? 0.72 : 0.46))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(isSelected ? DesignToken.primary.opacity(0.72) : .white.opacity(0.78), lineWidth: isSelected ? 2 : 1)
                    )
                    .shadow(color: Color(hex: "#7064A9").opacity(0.10), radius: 14, y: 7)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("\(companion.chineseName)，\(isUnlocked ? "已解锁" : "待解锁")")
        .accessibilityHint("打开伙伴详情")
    }

    private var statusText: String {
        if isUnlocked { return "已解锁" }
        let percent = Int((friendshipPercent * 100).rounded())
        return "好感度 \(percent)%"
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
    @State private var showShop = false
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
                        .black.opacity(0.26),
                        .black.opacity(0.02),
                        .black.opacity(0.46)
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
            .background(Color(hex: "#1AAE68").ignoresSafeArea())
        }
        .sheet(isPresented: $showShop) {
            CompanionShopView(
                hostCompanion: hostCompanion,
                visitorCompanions: visitorCompanions
            )
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
                        Text("\(hostCompanion.chineseName)的小木屋")
                            .font(BBBFont.font(size: metrics.headerTitleSize, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.70)

                        Text(subtitle)
                            .font(BBBFont.font(size: metrics.headerSubtitleSize, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.82))
                            .lineLimit(1)
                            .minimumScaleFactor(0.70)
                    }

                    Button {} label: {
                        Text("关注")
                            .font(BBBFont.font(size: metrics.followFontSize, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: metrics.followButtonWidth, height: metrics.followButtonHeight)
                            .background(Capsule().fill(Color(hex: "#FE3D76")))
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                .padding(.leading, 4)
                .padding(.trailing, 8)
                .frame(height: metrics.headerPillHeight)
                .background(Capsule().fill(.black.opacity(0.30)))

                Spacer(minLength: 5)

                if !metrics.isNarrowWidth {
                    visitorAvatarStack(metrics: metrics)
                }

                Text("\(viewerCount)")
                    .font(BBBFont.font(size: metrics.counterFontSize, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .frame(height: metrics.headerIconButtonSize)
                    .background(Capsule().fill(.black.opacity(0.26)))

                Button {
                    openCompanionPicker()
                } label: {
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: metrics.headerIconSize, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(width: metrics.headerIconButtonSize, height: metrics.headerIconButtonSize)
                        .background(Circle().fill(.black.opacity(0.28)))
                }
                .buttonStyle(ScaleButtonStyle())
            }

            HStack(spacing: 7) {
                Text("小木屋第 1 名")
                    .font(BBBFont.font(size: metrics.secondaryPillFontSize, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 13)
                    .frame(height: metrics.secondaryPillHeight)
                    .background(Capsule().fill(.black.opacity(0.30)))

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
                    .foregroundStyle(.white)
                Image(systemName: "chevron.right")
                    .font(.system(size: metrics.secondaryChevronSize, weight: .heavy))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 13)
            .frame(height: metrics.secondaryPillHeight)
            .background(Capsule().fill(.black.opacity(0.28)))
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
            .background(Circle().fill(.white.opacity(0.22)))
            .clipShape(Circle())
            .overlay(Circle().stroke(.white.opacity(0.68), lineWidth: 1.5))
            .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
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
            levelBadge(34, color: Color(hex: "#735DFF"))
            Text("\(hostCompanion.chineseName) 加入了直播间")
        }
        .font(BBBFont.font(size: metrics.joinFontSize, weight: .bold))
        .foregroundStyle(.white)
        .padding(.leading, 5)
        .padding(.trailing, 12)
        .frame(height: metrics.joinMessageHeight)
        .background(Capsule().fill(Color(hex: "#415FEA").opacity(0.68)))
        .shadow(color: .black.opacity(0.10), radius: 6, y: 3)
    }

    private func liveMessageRow(_ message: LiveChatMessage, metrics: LiveIslandLayoutMetrics) -> some View {
        HStack(alignment: .center, spacing: 6) {
            if let level = message.level {
                levelBadge(level, color: message.isCareLog ? Color(hex: "#FF9B42") : Color(hex: "#6888FF"))
            }

            if let badge = message.badge {
                Text(badge)
                    .font(BBBFont.font(size: metrics.badgeFontSize, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: metrics.badgeSize, height: metrics.badgeSize)
                    .background(Circle().fill(Color(hex: "#D7598B")))
            }

            Text(message.speaker)
                .font(BBBFont.font(size: metrics.messageSpeakerSize, weight: .bold))
                .foregroundStyle(message.tint)
                .lineLimit(1)

            Text(message.isJoin ? "" : "：\(message.text)")
                .font(BBBFont.font(size: metrics.messageBodySize, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .lineSpacing(1)
        }
        .padding(.leading, 5)
        .padding(.trailing, 11)
        .padding(.vertical, metrics.messageVerticalPadding)
        .background(Capsule().fill(.black.opacity(message.isCareLog ? 0.28 : 0.23)))
        .shadow(color: .black.opacity(0.06), radius: 5, y: 2)
    }

    private func levelBadge(_ level: Int, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "diamond.fill")
                .font(.system(size: 7, weight: .heavy))
            Text("\(level)")
                .font(BBBFont.font(size: 9, weight: .heavy))
        }
        .foregroundStyle(.white)
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
                    .foregroundStyle(.white)
                    .textInputAutocapitalization(.never)
                    .submitLabel(.send)
                    .onSubmit(sendChatMessage)
                    .tint(.white)

                Button {
                    sendChatMessage()
                } label: {
                    Image(systemName: chatDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "face.smiling" : "paperplane.fill")
                        .font(.system(size: metrics.composerIconSize, weight: .bold))
                        .foregroundStyle(.white.opacity(0.88))
                        .frame(width: metrics.composerButtonSize, height: metrics.composerButtonSize)
                }
                .buttonStyle(ScaleButtonStyle())
            }
            .padding(.leading, 15)
            .padding(.trailing, 7)
            .frame(height: metrics.composerHeight)
            .background(Capsule().fill(.black.opacity(0.22)))
            .overlay(Capsule().stroke(.white.opacity(0.10), lineWidth: 1))

            Button {
                likeLive()
            } label: {
                liveRoundAction(icon: "heart.fill", colors: [Color(hex: "#FF4A84"), Color(hex: "#7F5BFF")], metrics: metrics)
                    .scaleEffect(liked ? 1.12 : 1)
            }
            .buttonStyle(ScaleButtonStyle())

            Button {
                showShop = true
            } label: {
                liveRoundAction(icon: "cart.fill", colors: [Color(hex: "#26CFA1"), Color(hex: "#5C7CFF")], metrics: metrics)
            }
            .buttonStyle(ScaleButtonStyle())

            Button {
                shareLive()
            } label: {
                Image(systemName: "arrowshape.turn.up.right.fill")
                    .font(.system(size: metrics.bottomIconSize, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: metrics.bottomActionSize, height: metrics.bottomActionSize)
                    .background(Circle().fill(.black.opacity(0.22)))
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    private func liveRoundAction(icon: String, colors: [Color], metrics: LiveIslandLayoutMetrics) -> some View {
        Image(systemName: icon)
            .font(.system(size: metrics.bottomIconSize, weight: .heavy))
            .foregroundStyle(.white)
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
            text: "我正在 BBBuddy 看\(hostCompanion.chineseName)的小木屋陪伴直播"
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
                tint: Color(hex: "#D9F6FF"),
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
                    Color(hex: "#F8F7FB"),
                    Color(hex: "#EEF8F4"),
                    Color(hex: "#F7EEF7")
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
                            .fill(.white.opacity(0.92))
                            .shadow(color: Color(hex: "#4D4B70").opacity(0.08), radius: 12, y: 5)
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
                .background(Circle().fill(.white.opacity(0.90)))
                .shadow(color: Color(hex: "#4D4B70").opacity(0.08), radius: 14, y: 7)

            VStack(alignment: .leading, spacing: 7) {
                Text("\(hostCompanion.chineseName)的小货架")
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
                            .background(Circle().fill(.white.opacity(0.92)))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(.white, lineWidth: 1))
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
                .fill(.white.opacity(0.88))
                .shadow(color: Color(hex: "#4D4B70").opacity(0.06), radius: 18, y: 8)
        )
        .padding(.horizontal, 18)
    }

    private func placeholderSlot(_ index: Int) -> some View {
        VStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.92),
                            Color(hex: "#F0EEF8").opacity(0.92)
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
                .fill(.white.opacity(0.78))
                .shadow(color: Color(hex: "#4D4B70").opacity(0.04), radius: 12, y: 6)
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
            Color(hex: "#101218").ignoresSafeArea()

            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("分享直播")
                            .font(BBBFont.font(size: 21, weight: .heavy))
                            .foregroundStyle(.white)
                        Text("BBBuddy")
                            .font(BBBFont.font(size: 11, weight: .heavy))
                            .foregroundStyle(.white.opacity(0.58))
                    }

                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(.white)
                            .frame(width: 38, height: 38)
                            .background(Circle().fill(.white.opacity(0.14)))
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)

                Image(uiImage: preview.image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: .black.opacity(0.38), radius: 24, y: 14)
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
                            .foregroundStyle(.white)
                            .frame(width: 46, height: 46)
                            .background(Circle().fill(target.color))

                        Text(target.title)
                            .font(BBBFont.font(size: 11, weight: .bold))
                            .foregroundStyle(.white.opacity(0.84))
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
        .background(.black.opacity(0.30))
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
        case .wechat: return Color(hex: "#21C063")
        case .moments: return Color(hex: "#2F8FFF")
        case .rednote: return Color(hex: "#FF3D5A")
        case .more: return Color(hex: "#5F6472")
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
            let title = "\(hostCompanion.chineseName)的小木屋正在直播"
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
        UIColor.white.withAlphaComponent(0.94).setFill()
        path.fill()
        cg.restoreGState()

        UIColor.white.withAlphaComponent(0.86).setStroke()
        path.lineWidth = 4
        path.stroke()
    }

    private static func drawLogo(in rect: CGRect) {
        let markRect = CGRect(x: rect.minX, y: rect.minY + 2, width: 66, height: 66)
        let markPath = UIBezierPath(roundedRect: markRect, cornerRadius: 21)
        UIColor(liveHex: "#20202A").setFill()
        markPath.fill()

        drawText("BB", in: markRect.insetBy(dx: 7, dy: 12), size: 27, weight: .black, color: .white, alignment: .center)
        drawText("BBBuddy", in: CGRect(x: markRect.maxX + 16, y: rect.minY + 8, width: rect.width - 82, height: 34), size: 31, weight: .black, color: UIColor(liveHex: "#20202A"))
        drawText("live companion", in: CGRect(x: markRect.maxX + 17, y: rect.minY + 43, width: rect.width - 82, height: 22), size: 16, weight: .semibold, color: UIColor(liveHex: "#7B788B"))
    }

    private static func drawPhoneFrame(in cg: CGContext, rect: CGRect, snapshot: UIImage?, hostCompanion: BabyCompanion) {
        let framePath = UIBezierPath(roundedRect: rect, cornerRadius: 58)
        cg.saveGState()
        cg.setShadow(offset: CGSize(width: 0, height: 20), blur: 34, color: UIColor.black.withAlphaComponent(0.22).cgColor)
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

        UIColor.white.withAlphaComponent(0.16).setStroke()
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

        drawText("\(hostCompanion.chineseName)的小木屋", in: CGRect(x: rect.minX + 56, y: rect.maxY - 210, width: rect.width - 112, height: 52), size: 34, weight: .black, color: .white, alignment: .center)
        drawText("LIVE", in: CGRect(x: rect.minX + 56, y: rect.maxY - 148, width: rect.width - 112, height: 38), size: 24, weight: .black, color: .white, alignment: .center)
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
                Text(heart.symbol)
                    .font(.system(size: heart.size))
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
    let symbol: String
    let size: CGFloat
    let x: CGFloat
    let startY: CGFloat
    let endY: CGFloat
    let delay: Double
    let duration: Double

    static func makeBurst() -> [FloatingHeart] {
        (0..<12).map { index in
            FloatingHeart(
                symbol: ["💗", "💛", "✨", "🌸"].randomElement() ?? "💗",
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
    var assetLocalIdentifier: String?
    var assetMediaSubtypeRawValue: UInt?
    var livePhotoMovieURL: URL?

    var isLivePhoto: Bool {
        if livePhotoMovieURL != nil { return true }
        guard let assetMediaSubtypeRawValue else { return false }
        return (assetMediaSubtypeRawValue & PHAssetMediaSubtype.photoLive.rawValue) != 0
    }

    static func == (lhs: AchievementStickerMedia, rhs: AchievementStickerMedia) -> Bool {
        lhs.id == rhs.id
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
    }
}

struct BabyAchievementsView: View {
    @EnvironmentObject private var stickerStore: AchievementStickerStore
    @Environment(BabyProfileStore.self) private var profileStore
    @State private var showCreateSticker = false
    @State private var selectedAchievement: CustomAchievement?
    @State private var selectedDay: MilestoneDay?
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
        .sheet(isPresented: $showCreateSticker) {
            CreateCustomAchievementView { achievement in
                selectedAchievement = achievement
            }
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
        .onChange(of: createRequest) { _, requested in
            guard requested else { return }
            showCreateSticker = true
            createRequest = false
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
                    showCreateSticker = true
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
                .foregroundStyle(.white)
            Text("已解锁")
                .font(BBBFont.font(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.82))
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
        let defaultMilestone = AchievementMilestoneCatalog.defaultMilestone(forDayOffset: day.dayOffset, pageIndex: day.pageIndex)
        do {
            let achievement = try stickerStore.add(
                templateID: defaultMilestone?.id,
                name: defaultMilestone?.title ?? "自定义成就",
                description: defaultMilestone?.description ?? "记录宝宝的一个特别时刻",
                note: "",
                completedAt: day.date,
                sourceImage: media.image,
                milestoneID: defaultMilestone?.id,
                milestoneKind: defaultMilestone?.kind ?? .custom,
                achievedDayOffset: day.dayOffset,
                sourceAssetLocalIdentifier: media.assetLocalIdentifier,
                sourceAssetMediaSubtypeRawValue: media.assetMediaSubtypeRawValue,
                livePhotoMovieURL: media.livePhotoMovieURL,
                creationSource: .manual
            )
            selectedAchievement = achievement
        } catch {
            showCreateSticker = true
        }
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
}

private enum AchievementMilestoneCatalog {
    static let importantDays: [MilestoneDefinition] = [
        .init(id: "birth-day", title: "出生日", description: "宝宝来到这个世界的第一天。", kind: .importantDay, targetDayOffset: 0, agePageIndex: nil, symbol: "sparkles"),
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
            return offset / 30 == pageIndex
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
    var pageIndex: Int { dayOffset / 30 }
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
    @State private var showAutoMatchReview = false
    @State private var scanMessage: String?
    @State private var loadedPageUpperBound: Int
    @State private var didScrollToInitialDay = false

    private let verticalStep: CGFloat = 122
    private let pathNodeButtonSize: CGFloat = 126

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
        let currentDay = max(Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: birthDate), to: Calendar.current.startOfDay(for: Date())).day ?? 0, 0)
        let currentPage = currentDay / 30
        self._pageIndex = State(initialValue: currentPage)
        self._loadedPageUpperBound = State(initialValue: max(currentPage + 2, 2))
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollViewReader { reader in
                VStack(spacing: 12) {
                    unitHeader(reader: reader)
                        .id("unit-header")
                        .zIndex(2)

                    learningStatusRow

                    ZStack(alignment: .bottomTrailing) {
                        ScrollView(showsIndicators: false) {
                            scrollOffsetProbe

                            pathCanvas(width: max(proxy.size.width, 320))
                                .padding(.top, 8)
                                .padding(.bottom, 150)
                        }
                        .coordinateSpace(name: "MilestonePathScroll")
                        .onPreferenceChange(MilestoneScrollOffsetPreferenceKey.self) { scrollOffset in
                            updateActivePage(scrollOffset: scrollOffset)
                        }
                        .onAppear {
                            scrollToInitialDayIfNeeded(reader: reader)
                        }

                        quickReturnButton(reader: reader)
                            .padding(.trailing, 18)
                            .padding(.bottom, 132)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
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
        .alert("自动匹配", isPresented: Binding(get: { scanMessage != nil }, set: { if !$0 { scanMessage = nil } })) {
            Button("好", role: .cancel) {}
        } message: {
            Text(scanMessage ?? "")
        }
    }

    private var scrollOffsetProbe: some View {
        Color.clear
            .frame(height: 0)
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: MilestoneScrollOffsetPreferenceKey.self,
                        value: max(-proxy.frame(in: .named("MilestonePathScroll")).minY, 0)
                    )
                }
            )
    }

    private func unitHeader(reader: ScrollViewProxy) -> some View {
        HStack(spacing: 8) {
            pageNavButton(systemName: "chevron.left", isEnabled: pageIndex > 0) {
                scrollToPage(max(pageIndex - 1, 0), reader: reader)
            }

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(headerTitle)
                        .font(BBBFont.font(size: 17, weight: .heavy))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text("\(dateRangeText) · 里程碑")
                        .font(BBBFont.font(size: 11, weight: .heavy))
                        .foregroundStyle(.white.opacity(0.78))
                        .lineLimit(1)
                }
                .padding(.leading, 18)
                .frame(maxWidth: .infinity, alignment: .leading)

                Rectangle()
                    .fill(Color(hex: "#7454D8").opacity(0.34))
                    .frame(width: 1)
                    .padding(.vertical, 12)

                Button {
                    handleScanButtonTap()
                } label: {
                    Group {
                        if isScanning {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        } else {
                            Image(systemName: scanButtonIcon)
                                .font(.system(size: 21, weight: .heavy))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 62, height: 64)
                    .contentShape(Rectangle())
                }
                .disabled(isScanning)
                .accessibilityLabel(scanButtonTitle)
            }
            .frame(height: 72)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#8F6DF4"), Color(hex: "#BDA6F2")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color(hex: "#7454D8").opacity(0.34))
                            .frame(height: 6)
                            .offset(y: 3)
                    }
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            pageNavButton(systemName: "chevron.right", isEnabled: true) {
                scrollToPage(pageIndex + 1, reader: reader)
            }
        }
    }

    private func pageNavButton(systemName: String, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .heavy))
                .foregroundStyle(isEnabled ? DesignToken.primary : DesignToken.textSecondary.opacity(0.35))
                .frame(width: 42, height: 42)
                .background(Circle().fill(Color(hex: "#F0EBFF").opacity(isEnabled ? 1 : 0.52)))
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!isEnabled)
    }

    private var learningStatusRow: some View {
        HStack(spacing: 10) {
            Text("本月 \(pageTotalMilestones) 项")
                .font(BBBFont.font(size: 12, weight: .heavy))
                .foregroundStyle(DesignToken.primary)
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(Capsule().fill(DesignToken.primary.opacity(0.10)))

            Text(progressText)
                .font(BBBFont.font(size: 12, weight: .heavy))
                .foregroundStyle(DesignToken.textSecondary)
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(Capsule().fill(.white.opacity(0.70)))

            Spacer()

            Button {
                onCreateCustomSticker()
            } label: {
                Image(systemName: "camera.fill")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(DesignToken.primary)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color(hex: "#F2EEFF")))
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel("创建自定义贴纸")
        }
    }

    private func pathCanvas(width: CGFloat) -> some View {
        let canvasWidth = max(width, 320)
        let orderedDays = loadedDays
        let points = orderedDays.enumerated().map { index, _ in
            pathPoint(for: index, width: canvasWidth)
        }
        let linePoints = orderedDays.enumerated().map { index, _ in
            pathLinePoint(for: index, width: canvasWidth)
        }
        let achievementsByDay = Dictionary(
            grouping: stickerStore.achievements.sorted { $0.completedAt > $1.completedAt },
            by: { $0.achievedDayOffset ?? Int.min }
        )

        return ZStack(alignment: .topLeading) {
            DottedLearningPathLine(points: linePoints)
                .frame(width: canvasWidth, height: pathHeight)

            ForEach(mascotPlacements(in: canvasWidth), id: \.index) { placement in
                PathCompanionMarker(
                    assetName: placement.assetName,
                    progressText: progressText
                )
                .position(placement.position)
                .allowsHitTesting(false)
            }

            ForEach(Array(orderedDays.enumerated()), id: \.element.id) { index, day in
                let achievement = achievementsByDay[day.dayOffset]?.first
                let point = points[index]

                MilestonePathNode(
                    day: day,
                    isToday: Calendar.current.isDate(day.date, inSameDayAs: Date()),
                    isLocked: !isUnlocked(day),
                    achievement: achievement,
                    milestone: AchievementMilestoneCatalog.importantMilestone(onDayOffset: day.dayOffset),
                    stickerImage: achievement.flatMap { stickerStore.thumbnailImage(for: $0, maxSide: 190) }
                ) {
                    guard isUnlocked(day) else { return }
                    if let achievement {
                        selectedAchievement = achievement
                    } else {
                        selectedDay = day
                    }
                }
                .position(point)
                .id(day.id)
            }
        }
        .frame(width: canvasWidth, height: pathHeight, alignment: .topLeading)
    }

    private var days: [MilestoneDay] {
        days(forPage: pageIndex)
    }

    private var loadedDays: [MilestoneDay] {
        let calendar = Calendar.current
        let birthStart = calendar.startOfDay(for: birthDate)
        return (0..<renderedDayCount).compactMap { dayOffset in
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: birthStart) else { return nil }
            return MilestoneDay(dayOffset: dayOffset, date: date)
        }
    }

    private func days(forPage page: Int) -> [MilestoneDay] {
        let calendar = Calendar.current
        let birthStart = calendar.startOfDay(for: birthDate)
        return (0..<30).compactMap { offset in
            let dayOffset = page * 30 + offset
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: birthStart) else { return nil }
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

    private var scanButtonIcon: String {
        if hasCachedCandidates { return "tray.full.fill" }
        if isScanning { return "sparkles" }
        return scanState == nil ? "wand.and.stars" : "arrow.clockwise"
    }

    private var hasCachedCandidates: Bool {
        !(cachedAutoMatchCandidates[pageIndex]?.isEmpty ?? true)
            || !stickerStore.pendingAutoMatchCandidates(pageIndex: pageIndex).isEmpty
    }

    private var scanFooterText: String {
        guard let scanState else {
            return "本页尚未扫描相册"
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "M月d日 HH:mm"
        return "上次扫描 \(formatter.string(from: scanState.scannedAt))，找到 \(scanState.resultCount) 个候选"
    }

    private var dateRangeText: String {
        guard let first = days.first?.date, let last = days.last?.date else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "M月d日"
        return "\(formatter.string(from: first)) - \(formatter.string(from: last))"
    }

    private var headerTitle: String {
        if pageIndex == currentAgePageIndex {
            return "\(pageIndex)月龄里程碑  \(babyAgeText)"
        }
        return "\(pageIndex)月龄里程碑"
    }

    private var babyAgeText: String {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: birthDate)
        let today = calendar.startOfDay(for: Date())
        let components = calendar.dateComponents([.month, .day], from: start, to: today)
        let months = max(components.month ?? 0, 0)
        let days = max(components.day ?? 0, 0)
        if months == 0 { return "\(days)天" }
        if days == 0 { return "\(months)个月" }
        return "\(months)个月\(days)天"
    }

    private var currentDayOffset: Int {
        let calendar = Calendar.current
        return max(calendar.dateComponents([.day], from: calendar.startOfDay(for: birthDate), to: calendar.startOfDay(for: Date())).day ?? 0, 0)
    }

    private var currentAgePageIndex: Int {
        currentDayOffset / 30
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
        let range = (pageIndex * 30)..<((pageIndex + 1) * 30)
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
        max((loadedPageUpperBound + 1) * 30, 30)
    }

    private var pathHeight: CGFloat {
        CGFloat(max(renderedDayCount - 1, 0)) * verticalStep + 210
    }

    private func pathPoint(for index: Int, width: CGFloat) -> CGPoint {
        let center = width * 0.5
        let laneOffset = min(width * 0.22, 92)
        let x = center + (index.isMultiple(of: 2) ? -laneOffset : laneOffset)
        let y = 88 + CGFloat(index) * verticalStep
        return CGPoint(x: x, y: y)
    }

    private func pathLinePoint(for index: Int, width: CGFloat) -> CGPoint {
        let nodePoint = pathPoint(for: index, width: width)
        let inwardDirection: CGFloat = index.isMultiple(of: 2) ? 1 : -1
        return CGPoint(
            x: nodePoint.x + inwardDirection * (pathNodeButtonSize * 0.47),
            y: nodePoint.y + 8
        )
    }

    private func mascotPlacements(in width: CGFloat) -> [(index: Int, assetName: String, position: CGPoint)] {
        let companionAssets = BabyCompanion.all.map(\.portraitAssetName)
        guard !companionAssets.isEmpty else { return [] }
        let lastDayIndex = max(renderedDayCount - 1, 0)
        let candidateIndexes = stride(from: 0, through: lastDayIndex, by: 18)
            .map { $0 + 6 }
            .filter { $0 <= lastDayIndex }
        return candidateIndexes.enumerated().compactMap { companionIndex, dayIndex in
            let point = pathPoint(for: dayIndex, width: width)
            let x = point.x < width * 0.5 ? width * 0.72 : width * 0.28
            let y = point.y + 8
            return (
                index: dayIndex,
                assetName: companionAssets[companionIndex % companionAssets.count],
                position: CGPoint(x: x, y: y)
            )
        }
    }

    private func isUnlocked(_ day: MilestoneDay) -> Bool {
        day.dayOffset <= currentDayOffset
    }

    private func quickReturnButton(reader: ScrollViewProxy) -> some View {
        Button {
            ensurePageLoaded(currentAgePageIndex + 2)
            withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                pageIndex = currentAgePageIndex
                reader.scrollTo(currentDayOffset, anchor: .center)
            }
        } label: {
            Image(systemName: "arrow.up")
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(DesignToken.primary)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(.white.opacity(0.92))
                        .overlay(
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .stroke(Color(hex: "#E4E0EC"), lineWidth: 1)
                        )
                        .shadow(color: Color(hex: "#4D4B70").opacity(0.10), radius: 12, y: 5)
                )
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("回到当前日期")
    }

    private func scrollToPage(_ targetPage: Int, reader: ScrollViewProxy) {
        let page = max(targetPage, 0)
        ensurePageLoaded(page + 2)
        withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
            pageIndex = page
            reader.scrollTo(page * 30, anchor: .top)
        }
    }

    private func scrollToInitialDayIfNeeded(reader: ScrollViewProxy) {
        guard !didScrollToInitialDay else { return }
        ensurePageLoaded(currentAgePageIndex + 2)
        DispatchQueue.main.async {
            reader.scrollTo(currentDayOffset, anchor: .center)
            didScrollToInitialDay = true
        }
    }

    private func updateActivePage(scrollOffset: CGFloat) {
        guard didScrollToInitialDay else { return }
        let pageHeight = verticalStep * 30
        guard pageHeight > 0 else { return }
        let activePage = max(Int((scrollOffset + 96) / pageHeight), 0)
        guard activePage <= loadedPageUpperBound else { return }

        if activePage != pageIndex {
            pageIndex = activePage
        }

        if activePage >= loadedPageUpperBound - 1 {
            ensurePageLoaded(activePage + 2)
        }
    }

    private func ensurePageLoaded(_ page: Int) {
        let upperBound = max(page, 0)
        if upperBound > loadedPageUpperBound {
            loadedPageUpperBound = upperBound
        }
    }

    @MainActor
    private func handleScanButtonTap() {
        if let cached = cachedAutoMatchCandidates[pageIndex], !cached.isEmpty {
            autoMatchCandidates = cached
            showAutoMatchReview = true
        } else if !stickerStore.pendingAutoMatchCandidates(pageIndex: pageIndex).isEmpty {
            Task { await restorePendingCandidates() }
        } else {
            Task { await scanCurrentPage() }
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
            let candidates = try await scanner.restore(records: records)
            guard !candidates.isEmpty else {
                stickerStore.clearPendingAutoMatchCandidates(pageIndex: pageIndex)
                scanMessage = "上次的候选照片已经不可用，请重新扫描。"
                return
            }
            autoMatchCandidates = candidates
            cachedAutoMatchCandidates[pageIndex] = candidates
            showAutoMatchReview = true
        } catch {
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
            let candidates = try await scanner.scan(
                pageIndex: pageIndex,
                birthDate: birthDate,
                existingAchievements: stickerStore.achievements
            )
            autoMatchCandidates = candidates
            cachedAutoMatchCandidates[pageIndex] = candidates
            stickerStore.updatePendingAutoMatchCandidates(pageIndex: pageIndex, records: candidates.map(\.record))
            stickerStore.updateScanState(pageIndex: pageIndex, resultCount: candidates.count)
            if candidates.isEmpty {
                scanMessage = "这一页没有找到适合生成贴纸的宝宝照片。"
            } else {
                showAutoMatchReview = true
            }
        } catch {
            scanMessage = error.localizedDescription
        }
    }
}

private struct MilestoneScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct DottedLearningPathLine: View {
    let points: [CGPoint]

    var body: some View {
        segmentedCurvePath
            .stroke(
                Color(hex: "#CAC6D1").opacity(0.58),
                style: StrokeStyle(
                    lineWidth: 6,
                    lineCap: .round,
                    lineJoin: .round,
                    dash: [0.1, 14],
                    dashPhase: 0
                )
            )
            .shadow(color: .white.opacity(0.72), radius: 1, y: 1)
            .allowsHitTesting(false)
    }

    private var segmentedCurvePath: Path {
        Path { path in
            guard points.count > 1 else { return }

            for index in 0..<(points.count - 1) {
                let start = points[index]
                let end = points[index + 1]
                let direction: CGFloat = start.x < end.x ? 1 : -1
                let control = CGPoint(
                    x: (start.x + end.x) * 0.5 + direction * 18,
                    y: (start.y + end.y) * 0.5
                )
                path.move(to: start)
                path.addQuadCurve(to: end, control: control)
            }
        }
    }
}

private struct PathCompanionMarker: View {
    let assetName: String
    let progressText: String

    var body: some View {
        VStack(spacing: 2) {
            Image(assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 126, height: 126)
                .shadow(color: Color(hex: "#4D4B70").opacity(0.08), radius: 8, y: 4)

            Text("完成 \(progressText)")
                .font(BBBFont.font(size: 10, weight: .heavy))
                .foregroundStyle(DesignToken.textSecondary.opacity(0.76))
                .padding(.horizontal, 8)
                .frame(height: 20)
                .background(Capsule().fill(.white.opacity(0.78)))
        }
        .frame(width: 156, height: 156)
    }
}

private struct MilestonePathNode: View {
    @GestureState private var isPressed = false

    let day: MilestoneDay
    let isToday: Bool
    let isLocked: Bool
    let achievement: CustomAchievement?
    let milestone: MilestoneDefinition?
    let stickerImage: UIImage?
    let action: () -> Void

    private let buttonSize: CGFloat = 126
    private let baseDepth: CGFloat = 24
    private let cornerRadius: CGFloat = 26
    private let stickerSize: CGFloat = 106

    var body: some View {
        Button {
            action()
        } label: {
            buttonFace
                .frame(width: buttonSize, height: buttonSize + baseDepth)
                .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
        .simultaneousGesture(pressGesture)
        .frame(width: 168, height: 154)
    }

    private var pressGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($isPressed) { _, state, _ in
                state = !isLocked
            }
    }

    private var buttonFace: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(bottomColor)
                .frame(width: buttonSize, height: buttonSize)
                .offset(y: baseDepth * 0.5)

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(topFill)
                .frame(width: buttonSize, height: buttonSize)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(strokeColor, lineWidth: isToday ? 3.4 : 2)
                )
                .overlay(alignment: .topLeading) {
                    Capsule(style: .continuous)
                        .fill(.white.opacity(isLocked ? 0.26 : 0.34))
                        .frame(width: 54, height: 24)
                        .blur(radius: 1)
                        .offset(x: 15, y: 13)
                }
                .offset(y: -baseDepth * 0.5 + (isPressed ? 7 : 0))
                .animation(.spring(response: 0.16, dampingFraction: 0.62), value: isPressed)

            nodeContent
                .offset(y: -baseDepth * 0.5 + (isPressed ? 7 : 0))
                .animation(.spring(response: 0.16, dampingFraction: 0.62), value: isPressed)

            if milestone != nil && achievement == nil && !isLocked {
                Image(systemName: "star.fill")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color(hex: "#FFB75E")))
                    .offset(x: 51, y: -66 + (isPressed ? 7 : 0))
                    .allowsHitTesting(false)
                    .zIndex(4)
            }

            if let labelText {
                Text(labelText)
                    .font(BBBFont.font(size: 10, weight: .heavy))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                    .padding(.horizontal, 8)
                    .frame(maxWidth: buttonSize - 10)
                    .frame(height: 18)
                    .offset(y: buttonSize * 0.5)
                    .allowsHitTesting(false)
                    .zIndex(6)
            }
        }
    }

    private var dayNumber: Int {
        Calendar.current.component(.day, from: day.date)
    }

    @ViewBuilder
    private var nodeContent: some View {
        if let stickerImage {
            AppleStickerImage(image: stickerImage, size: stickerSize)
        } else if isLocked {
            Image(systemName: "lock.fill")
                .font(.system(size: 28, weight: .heavy))
                .foregroundStyle(Color(hex: "#B5B3BF"))
        } else {
            VStack(spacing: 1) {
                Text("\(dayNumber)")
                    .font(BBBFont.font(size: 26, weight: .heavy))
                    .foregroundStyle(.white)
                if milestone != nil {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(.white.opacity(0.88))
                }
            }
        }
    }

    private var labelText: String? {
        if isToday { return "今天" }
        return achievement?.name ?? milestone?.title
    }

    private var topFill: AnyShapeStyle {
        if isLocked {
            return AnyShapeStyle(Color(hex: "#F1F1F4"))
        }
        if achievement != nil {
            return AnyShapeStyle(.white)
        }
        return AnyShapeStyle(
            LinearGradient(
                colors: [Color(hex: "#9A78F5"), Color(hex: "#BDA6F2")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var bottomColor: Color {
        if isLocked { return Color(hex: "#D8D6DE") }
        return Color(hex: "#7655DE")
    }

    private var strokeColor: Color {
        if isToday { return DesignToken.primary.opacity(0.88) }
        if achievement != nil { return Color(hex: "#DCD8E7") }
        if isLocked { return Color(hex: "#E2E0E8") }
        return .white.opacity(0.35)
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
            .shadow(color: .white, radius: 0, x: 2.2, y: 0)
            .shadow(color: .white, radius: 0, x: -2.2, y: 0)
            .shadow(color: .white, radius: 0, x: 0, y: 2.2)
            .shadow(color: .white, radius: 0, x: 0, y: -2.2)
            .shadow(color: .white.opacity(0.96), radius: 1.6, x: 0, y: 0)
            .shadow(color: Color.black.opacity(0.12), radius: 4, y: 2)
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

    private let manager = PHCachingImageManager()
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
                                            .fill(Color(hex: "#E9E5EF"))
                                        if let image = thumbnails[asset.localIdentifier] {
                                            Image(uiImage: image)
                                                .resizable()
                                                .scaledToFill()
                                        }
                                    }
                                    .aspectRatio(1, contentMode: .fit)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
        }
    }

    private var photoPickerTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "M月d日"
        return "\(formatter.string(from: day.date))的照片"
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
        statusText = fetched.isEmpty ? "这一天没有找到照片" : "正在生成缩略图"
        for asset in fetched {
            requestThumbnail(asset)
        }
    }

    private func requestThumbnail(_ asset: PHAsset) {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        manager.requestImage(
            for: asset,
            targetSize: CGSize(width: 240, height: 240),
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            guard let image else { return }
            Task { @MainActor in
                thumbnails[asset.localIdentifier] = image
            }
        }
    }

    private func loadFullImage(_ asset: PHAsset) {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact
        options.isNetworkAccessAllowed = true
        manager.requestImage(
            for: asset,
            targetSize: CGSize(width: 1800, height: 1800),
            contentMode: .aspectFit,
            options: options
        ) { image, _ in
            guard let image else { return }
            Task { @MainActor in
                onSelected(AchievementStickerMedia(
                    image: image,
                    assetLocalIdentifier: asset.localIdentifier,
                    assetMediaSubtypeRawValue: asset.mediaSubtypes.rawValue,
                    livePhotoMovieURL: nil
                ))
                dismiss()
            }
        }
    }
}

private struct MilestoneAutoMatchCandidate: Identifiable, Hashable {
    let id: UUID
    let day: MilestoneDay
    let milestone: MilestoneDefinition?
    let sourceImage: UIImage
    let stickerImage: UIImage
    let assetLocalIdentifier: String
    let assetMediaSubtypeRawValue: UInt
    let confidence: Double
    let scoreBreakdown: AchievementAutoMatchScoreBreakdown

    init(
        id: UUID = UUID(),
        day: MilestoneDay,
        milestone: MilestoneDefinition?,
        sourceImage: UIImage,
        stickerImage: UIImage,
        assetLocalIdentifier: String,
        assetMediaSubtypeRawValue: UInt,
        confidence: Double,
        scoreBreakdown: AchievementAutoMatchScoreBreakdown
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
    }

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
            scoreBreakdown: scoreBreakdown
        )
    }

    static func == (lhs: MilestoneAutoMatchCandidate, rhs: MilestoneAutoMatchCandidate) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

private struct MilestoneAutoMatchReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var stickerStore: AchievementStickerStore
    let pageIndex: Int
    let candidates: [MilestoneAutoMatchCandidate]
    let onSaved: () -> Void

    @State private var selectedIDs: Set<UUID>
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(pageIndex: Int, candidates: [MilestoneAutoMatchCandidate], onSaved: @escaping () -> Void = {}) {
        self.pageIndex = pageIndex
        self.candidates = candidates
        self.onSaved = onSaved
        self._selectedIDs = State(initialValue: Set(candidates.map(\.id)))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                achievementSoftBackground
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("确认后会更新第 \(pageIndex) 页的自动匹配贴纸。手动创建的成就不会被覆盖。")
                            .font(BBBFont.font(size: 13, weight: .semibold))
                            .foregroundStyle(DesignToken.textSecondary)
                            .lineSpacing(3)
                            .padding(.horizontal, 2)

                        ForEach(candidates) { candidate in
                            candidateRow(candidate)
                        }
                    }
                    .padding(18)
                    .padding(.bottom, 96)
                }
            }
            .navigationTitle("自动匹配结果")
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
        }
    }

    private func candidateRow(_ candidate: MilestoneAutoMatchCandidate) -> some View {
        Button {
            if selectedIDs.contains(candidate.id) {
                selectedIDs.remove(candidate.id)
            } else {
                selectedIDs.insert(candidate.id)
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(hex: "#F1EEF8"))
                    Image(uiImage: candidate.stickerImage)
                        .resizable()
                        .scaledToFit()
                        .padding(6)
                }
                .frame(width: 82, height: 82)

                VStack(alignment: .leading, spacing: 6) {
                    Text(candidate.milestone?.title ?? "自定义成就")
                        .font(BBBFont.font(size: 16, weight: .heavy))
                        .foregroundStyle(DesignToken.textPrimary)
                    Text(candidateDateText(candidate.day.date))
                        .font(BBBFont.font(size: 12, weight: .bold))
                        .foregroundStyle(DesignToken.textSecondary)
                    Text("匹配度 \(Int((candidate.confidence * 100).rounded()))%")
                        .font(BBBFont.font(size: 11, weight: .bold))
                        .foregroundStyle(DesignToken.primary)
                    Text(candidate.scoreBreakdown.debugSummary)
                        .font(BBBFont.font(size: 10, weight: .semibold))
                        .foregroundStyle(DesignToken.textSecondary.opacity(0.72))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }

                Spacer()

                Image(systemName: selectedIDs.contains(candidate.id) ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(selectedIDs.contains(candidate.id) ? DesignToken.primary : DesignToken.textSecondary.opacity(0.38))
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.white.opacity(0.82))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(selectedIDs.contains(candidate.id) ? DesignToken.primary.opacity(0.28) : .white.opacity(0.9), lineWidth: 1.2)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func candidateDateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
    }

    private func saveSelected() {
        isSaving = true
        do {
            for candidate in candidates where selectedIDs.contains(candidate.id) {
                _ = try stickerStore.add(
                    templateID: candidate.milestone?.id,
                    name: candidate.milestone?.title ?? "自动匹配成就",
                    description: candidate.milestone?.description ?? "从相册里自动匹配到的宝宝照片。",
                    note: "",
                    completedAt: candidate.day.date,
                    sourceImage: candidate.sourceImage,
                    milestoneID: candidate.milestone?.id,
                    milestoneKind: candidate.milestone?.kind ?? .custom,
                    achievedDayOffset: candidate.day.dayOffset,
                    sourceAssetLocalIdentifier: candidate.assetLocalIdentifier,
                    sourceAssetMediaSubtypeRawValue: candidate.assetMediaSubtypeRawValue,
                    creationSource: .autoMatched,
                    matchConfidence: candidate.confidence,
                    replaceAutoMatchedPeer: true
                )
            }
            isSaving = false
            onSaved()
            dismiss()
        } catch {
            isSaving = false
            errorMessage = error.localizedDescription
        }
    }
}

private struct MilestonePhotoScanner {
    private let manager = PHCachingImageManager()

    func scan(
        pageIndex: Int,
        birthDate: Date,
        existingAchievements: [CustomAchievement]
    ) async throws -> [MilestoneAutoMatchCandidate] {
        let authorized = await Self.requestPhotoAccess()
        guard authorized else {
            throw MilestonePhotoScanError.photoAccessDenied
        }

        let calendar = Calendar.current
        let birthStart = calendar.startOfDay(for: birthDate)
        var candidates: [MilestoneAutoMatchCandidate] = []

        for offset in 0..<30 {
            let dayOffset = pageIndex * 30 + offset
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: birthStart) else { continue }
            let day = MilestoneDay(dayOffset: dayOffset, date: date)
            let assets = Self.assets(on: date)
            guard !assets.isEmpty else { continue }

            var scored: [(asset: PHAsset, image: UIImage, score: Double)] = []
            for asset in assets.prefix(24) {
                guard let image = await requestImage(for: asset) else { continue }
                let breakdown = Self.score(image: image, asset: asset)
                scored.append((asset, image, breakdown.total))
            }

            guard let best = scored.max(by: { $0.score < $1.score }) else { continue }
            let scoreBreakdown = Self.score(image: best.image, asset: best.asset)
            let milestone = AchievementMilestoneCatalog.defaultMilestone(forDayOffset: dayOffset, pageIndex: pageIndex)
            let optimized = best.image.optimizedForStickerInput(maxSide: StickerGenerator.stickerInputMaxSide)
            let previewSource = best.image.optimizedForStickerInput(maxSide: StickerGenerator.stickerPreviewInputMaxSide)
            let sticker = StickerGenerator.generateSticker(from: previewSource, quality: .preview)
            candidates.append(
                MilestoneAutoMatchCandidate(
                    day: day,
                    milestone: milestone,
                    sourceImage: optimized,
                    stickerImage: sticker,
                    assetLocalIdentifier: best.asset.localIdentifier,
                    assetMediaSubtypeRawValue: best.asset.mediaSubtypes.rawValue,
                    confidence: min(max(best.score, 0), 1),
                    scoreBreakdown: scoreBreakdown
                )
            )
        }

        return candidates.sorted { $0.day.dayOffset < $1.day.dayOffset }
    }

    func restore(records: [AchievementAutoMatchCandidateRecord]) async throws -> [MilestoneAutoMatchCandidate] {
        let authorized = await Self.requestPhotoAccess()
        guard authorized else {
            throw MilestonePhotoScanError.photoAccessDenied
        }

        var candidates: [MilestoneAutoMatchCandidate] = []
        for record in records {
            guard let asset = Self.asset(localIdentifier: record.assetLocalIdentifier),
                  let image = await requestImage(for: asset) else {
                continue
            }
            let optimized = image.optimizedForStickerInput(maxSide: StickerGenerator.stickerInputMaxSide)
            let previewSource = image.optimizedForStickerInput(maxSide: StickerGenerator.stickerPreviewInputMaxSide)
            let sticker = StickerGenerator.generateSticker(from: previewSource, quality: .preview)
            let milestone = record.milestoneID.flatMap { AchievementMilestoneCatalog.milestone(id: $0) }
            candidates.append(
                MilestoneAutoMatchCandidate(
                    id: record.id,
                    day: MilestoneDay(dayOffset: record.dayOffset, date: record.date),
                    milestone: milestone,
                    sourceImage: optimized,
                    stickerImage: sticker,
                    assetLocalIdentifier: record.assetLocalIdentifier,
                    assetMediaSubtypeRawValue: asset.mediaSubtypes.rawValue,
                    confidence: record.confidence,
                    scoreBreakdown: record.scoreBreakdown
                )
            )
        }
        return candidates.sorted { $0.day.dayOffset < $1.day.dayOffset }
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

    private func requestImage(for asset: PHAsset) async -> UIImage? {
        await withCheckedContinuation { continuation in
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
        let favoriteScore = asset.isFavorite ? 0.10 : 0.02
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
            facePresenceScore = 0.42
            faceAreaScore = min(Double(faceArea) * 2.2, 0.22)
            faceCenterScore = Double(centerScore) * 0.18
        }

        let aspect = Double(asset.pixelWidth) / Double(max(asset.pixelHeight, 1))
        if aspect > 0.55 && aspect < 1.9 {
            aspectScore = 0.05
        }
        if asset.pixelWidth >= 900 && asset.pixelHeight >= 900 {
            resolutionScore = 0.05
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
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "zh_Hans_CN")
    formatter.dateFormat = Calendar.current.isDate(date, inSameDayAs: Date()) ? "今天 HH:mm" : "yyyy年M月d日 HH:mm"
    return formatter.string(from: date)
}

private var achievementSoftBackground: some View {
    ZStack {
        LinearGradient(
            colors: [
                Color(hex: "#FAF7F3"),
                Color(hex: "#F6F2F7"),
                Color(hex: "#F9F7F2")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        LinearGradient(
            colors: [
                .white.opacity(0.42),
                Color(hex: "#EDE7F7").opacity(0.22),
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
        .foregroundStyle(isEnabled ? DesignToken.primary : Color(hex: "#C9C1CC"))
        .frame(width: 48, height: 48)
        .background(
            Circle()
                .fill(.white.opacity(0.78))
                .shadow(color: Color(hex: "#8F817C").opacity(0.08), radius: 12, y: 5)
        )
}

private func achievementStickerPlaceholder(symbol: String?) -> some View {
    ZStack {
        AchievementDoodleHalo()
            .frame(width: 240, height: 240)
            .opacity(0.48)

        Circle()
            .fill(.white.opacity(0.58))
            .frame(width: 146, height: 146)

        Image(systemName: symbol ?? "sparkles")
            .font(.system(size: 54, weight: .semibold))
            .foregroundStyle(Color(hex: "#C9BDEB").opacity(0.78))

        Image(systemName: "camera.fill")
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(.white)
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
                .stroke(Color.white.opacity(0.78), lineWidth: 12)
                .blur(radius: 0.2)

            Circle()
                .stroke(Color(hex: "#D8D0CA").opacity(0.45), style: StrokeStyle(lineWidth: 9, lineCap: .round, dash: [20, 18]))
                .rotationEffect(.degrees(-12))

            Circle()
                .stroke(Color.white.opacity(0.72), style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [2, 8]))
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

private struct CreateCustomAchievementView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var stickerStore: AchievementStickerStore

    let template: AchievementTemplate?
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
        onCreated: @escaping (CustomAchievement) -> Void = { _ in }
    ) {
        self.template = template
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
                        .foregroundStyle(Color(hex: "#6F605C"))
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
                generateStickerPreview(from: newMedia?.image)
            }
            .onAppear {
                if let template {
                    name = template.title
                    description = template.description
                }
            }
        }
    }

    private func imagePickerCard(height: CGFloat) -> some View {
        Button {
            showCamera = true
        } label: {
            ZStack {
                if let stickerPreview {
                    Image(uiImage: stickerPreview)
                        .resizable()
                        .scaledToFit()
                        .shadow(color: .black.opacity(0.12), radius: 10, y: 5)
                        .padding(.horizontal, 8)
                } else if isGeneratingSticker {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(DesignToken.primary)
                        Text("正在生成贴纸")
                            .font(BBBFont.font(size: 15, weight: .semibold))
                            .foregroundStyle(Color(hex: "#8A7D78"))
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
                    .foregroundStyle(Color(hex: "#6F605C"))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 15)
                    .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color(hex: "#F0EDF7").opacity(0.78)))

                TextField("写一句成就描述", text: $description, axis: .vertical)
                    .textFieldStyle(.plain)
                    .focused($focusedField, equals: .description)
                    .lineLimit(3, reservesSpace: true)
                    .font(BBBFont.font(size: AchievementSheetTypography.bodySize, weight: .medium))
                    .foregroundStyle(Color(hex: "#81736E"))
                    .lineSpacing(4)
                    .padding(18)
                    .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color(hex: "#F0EDF7").opacity(0.78)))
            } else {
                Text(name)
                    .font(BBBFont.font(size: AchievementSheetTypography.titleSize, weight: AchievementSheetTypography.titleWeight))
                    .foregroundStyle(Color(hex: "#6F605C"))
                    .lineLimit(2)
                    .minimumScaleFactor(0.86)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(description)
                    .font(BBBFont.font(size: AchievementSheetTypography.bodySize, weight: .medium))
                    .foregroundStyle(Color(hex: "#8B7B75"))
                    .lineSpacing(5)
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(.white.opacity(0.64))
                            .overlay(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .stroke(Color(hex: "#DFD8D3").opacity(0.8), lineWidth: 1)
                            )
                    )
            }

            achievementNoteEditor
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(.white.opacity(0.84))
                .shadow(color: Color(hex: "#8F817C").opacity(0.08), radius: 20, y: 10)
        )
    }

    private var mediaActionBar: some View {
        Button {
            showCamera = true
        } label: {
            Label(stickerPreview == nil ? "添加照片" : "更换照片", systemImage: "camera.fill")
                .font(BBBFont.font(size: 17, weight: .bold))
                .foregroundStyle(.white)
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
                        .foregroundStyle(Color(hex: "#9A8E8A"))
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: showNoteEditor ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(hex: "#B9AFAB"))
                }
                .padding(.horizontal, 16)
                .frame(height: 48)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color(hex: "#F3F0F7").opacity(0.78)))
            }
            .buttonStyle(.plain)

            if showNoteEditor {
                TextField("写下这一刻的小故事", text: $note, axis: .vertical)
                    .textFieldStyle(.plain)
                    .focused($focusedField, equals: .note)
                    .lineLimit(4, reservesSpace: true)
                    .font(BBBFont.font(size: AchievementSheetTypography.noteSize, weight: .medium))
                    .foregroundStyle(Color(hex: "#81736E"))
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color(hex: "#F3F0F7").opacity(0.78)))
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var completionTimeText: some View {
        Text(achievementDetailTimestampText(Date()))
            .font(BBBFont.font(size: AchievementSheetTypography.metaSize, weight: .semibold))
            .foregroundStyle(Color(hex: "#C1BAB6"))
            .frame(maxWidth: .infinity)
    }

    private func saveAchievement() {
        guard let selectedMedia, stickerPreview != nil else {
            errorMessage = "请先添加一张照片"
            return
        }
        isSaving = true
        do {
            let achievement = try stickerStore.add(
                templateID: template?.id,
                name: name,
                description: description,
                note: note,
                sourceImage: selectedMedia.image,
                sourceAssetLocalIdentifier: selectedMedia.assetLocalIdentifier,
                sourceAssetMediaSubtypeRawValue: selectedMedia.assetMediaSubtypeRawValue,
                livePhotoMovieURL: selectedMedia.livePhotoMovieURL
            )
            isSaving = false
            onCreated(achievement)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
        }
    }

    private func generateStickerPreview(from image: UIImage?) {
        let currentGenerationID = UUID()
        generationID = currentGenerationID
        stickerPreview = nil
        guard let image else {
            isGeneratingSticker = false
            return
        }
        isGeneratingSticker = true
        Task.detached(priority: .userInitiated) {
            let optimizedImage = image.optimizedForStickerInput(maxSide: StickerGenerator.stickerPreviewInputMaxSide)
            let sticker = StickerGenerator.generateSticker(from: optimizedImage, quality: .preview)
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
        return stickerPreview != nil && !isGeneratingSticker && !isSaving && hasCopy
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
    @State private var showDeleteConfirmation = false
    @State private var errorMessage: String?
    @State private var generationID = UUID()

    var body: some View {
        NavigationStack {
            ZStack {
                achievementSoftBackground
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 22) {
                        stickerHero
                        detailCard
                        Text(achievementDetailTimestampText(achievement.completedAt))
                            .font(BBBFont.font(size: AchievementSheetTypography.metaSize, weight: .semibold))
                            .foregroundStyle(Color(hex: "#BFB7B3"))
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 18)
                    .padding(.bottom, 72)
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
                }

                ToolbarItem(placement: .confirmationAction) {
                    Menu {
                        Button {
                            showCamera = true
                        } label: {
                            Label("更换图片", systemImage: "camera.fill")
                        }

                        Button {
                            regenerateStickerFromOriginal()
                        } label: {
                            Label("重新抠图", systemImage: "wand.and.stars")
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
            .sheet(isPresented: $showBindingEditor) {
                MilestoneAchievementBindingEditor(achievement: achievement, note: note)
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
        VStack(spacing: 20) {
            ZStack {
                AchievementDoodleHalo()
                    .frame(width: 260, height: 260)
                    .opacity(0.72)

                if isGeneratingSticker {
                    ProgressView()
                        .tint(DesignToken.primary)
                        .frame(width: 236, height: 236)
                } else if let image = stickerStore.stickerImage(for: achievement) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 236, height: 236)
                        .shadow(color: Color(hex: "#8F817C").opacity(0.14), radius: 14, y: 8)
                }
            }

            Text(achievement.name)
                .font(BBBFont.font(size: 23, weight: .heavy))
                .foregroundStyle(Color(hex: "#786762"))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 26)
    }

    private var detailCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(achievement.description)
                .font(BBBFont.font(size: AchievementSheetTypography.bodySize, weight: .medium))
                .foregroundStyle(Color(hex: "#8A7B76"))
                .lineSpacing(5)
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.white.opacity(0.62))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(Color(hex: "#DDD6D1").opacity(0.82), lineWidth: 1)
                        )
                )

            achievementDetailNoteEditor
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(.white.opacity(0.78))
                .shadow(color: Color(hex: "#8F817C").opacity(0.08), radius: 20, y: 10)
        )
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
                        .foregroundStyle(Color(hex: "#9A8E8A"))
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: showNoteEditor ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(hex: "#B9AFAB"))
                }
                .padding(.horizontal, 16)
                .frame(height: 48)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color(hex: "#F3F0F7").opacity(0.72)))
            }
            .buttonStyle(.plain)

            if showNoteEditor {
                TextField("写下这一刻的小故事", text: $note, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(4, reservesSpace: true)
                    .font(BBBFont.font(size: AchievementSheetTypography.noteSize, weight: .medium))
                    .foregroundStyle(Color(hex: "#81736E"))
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color(hex: "#F3F0F7").opacity(0.78)))
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
            let optimizedImage = media.image.optimizedForStickerInput(maxSide: StickerGenerator.stickerInputMaxSide)
            let sticker = StickerGenerator.generateSticker(from: optimizedImage)
            await MainActor.run {
                guard generationID == currentGenerationID else { return }
                do {
                    _ = try stickerStore.updateImage(
                        for: achievement,
                        sourceImage: media.image,
                        stickerImage: sticker,
                        sourceAssetLocalIdentifier: media.assetLocalIdentifier,
                        sourceAssetMediaSubtypeRawValue: media.assetMediaSubtypeRawValue,
                        livePhotoMovieURL: media.livePhotoMovieURL
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
            let optimizedImage = originalImage.optimizedForStickerInput(maxSide: StickerGenerator.stickerInputMaxSide)
            let sticker = StickerGenerator.generateSticker(from: optimizedImage)
            await MainActor.run {
                guard generationID == currentGenerationID else { return }
                do {
                    _ = try stickerStore.updateImage(
                        for: achievement,
                        sourceImage: optimizedImage,
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
                                .fill(.white.opacity(0.78))
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
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color(hex: "#F3F0F7").opacity(0.86)))

            TextField("写一句成就描述", text: $customDescription, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(4, reservesSpace: true)
                .font(BBBFont.font(size: 14, weight: .medium))
                .foregroundStyle(DesignToken.textSecondary)
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color(hex: "#F3F0F7").opacity(0.86)))
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(.white.opacity(0.78)))
    }

    private func milestonePreview(_ milestone: MilestoneDefinition) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(milestone.title, systemImage: milestone.symbol)
                .font(BBBFont.font(size: 18, weight: .heavy))
                .foregroundStyle(DesignToken.textPrimary)
            Text(milestone.description)
                .font(BBBFont.font(size: 14, weight: .medium))
                .foregroundStyle(DesignToken.textSecondary)
                .lineSpacing(4)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(.white.opacity(0.78)))
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

private struct AchievementCameraView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var media: AchievementStickerMedia?
    @StateObject private var camera = AchievementCameraModel()
    @State private var selectedItem: PhotosPickerItem?
    @State private var previewSize: CGSize = .zero

    private let cropWidthRatio: CGFloat = 0.76
    private let cropHeightRatio: CGFloat = 0.48

    var body: some View {
        ZStack {
            achievementSoftBackground
                .ignoresSafeArea()

            VStack(spacing: 18) {
                cameraPreview
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                cameraControls
                    .padding(.horizontal, 34)
                    .padding(.bottom, 22)
            }
        }
        .task {
            await camera.configure()
        }
        .onDisappear {
            camera.stop()
        }
        .onChange(of: selectedItem) { _, newItem in
            Task {
                if let loadedImage = await loadImage(from: newItem) {
                    media = AchievementStickerMedia(image: loadedImage)
                    dismiss()
                }
            }
        }
    }

    private var cameraPreview: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 58, style: .continuous)
                    .fill(Color.black.opacity(0.08))

                if camera.isConfigured {
                    CameraPreviewView(session: camera.session)
                        .clipShape(RoundedRectangle(cornerRadius: 58, style: .continuous))
                } else {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(DesignToken.primary)
                        Text("正在打开相机")
                            .font(BBBFont.font(size: 15, weight: .semibold))
                            .foregroundStyle(Color(hex: "#8A7D78"))
                    }
                }

                RoundedRectangle(cornerRadius: min(proxy.size.width, proxy.size.height) * 0.16, style: .continuous)
                    .stroke(.white.opacity(0.64), style: StrokeStyle(lineWidth: 6, lineCap: .round, dash: [30, 24]))
                    .frame(width: proxy.size.width * cropWidthRatio, height: proxy.size.height * cropHeightRatio)
                    .allowsHitTesting(false)

                if camera.isLivePhotoCaptureAvailable {
                    livePhotoToggle
                        .padding(18)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }
            }
            .onAppear {
                previewSize = proxy.size
            }
            .onChange(of: proxy.size) { _, newSize in
                previewSize = newSize
            }
        }
        .aspectRatio(0.56, contentMode: .fit)
    }

    private var cameraControls: some View {
        HStack(alignment: .center) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 27, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(width: 74, height: 74)
                    .background(Circle().fill(.white.opacity(0.86)))
            }
            .buttonStyle(ScaleButtonStyle())

            Spacer()

            Button {
                let targetPreviewSize = previewSize
                camera.capture { capturedMedia in
                    media = AchievementStickerMedia(
                        image: croppedStickerSource(from: capturedMedia.image, previewSize: targetPreviewSize),
                        assetLocalIdentifier: nil,
                        assetMediaSubtypeRawValue: capturedMedia.isLivePhoto ? PHAssetMediaSubtype.photoLive.rawValue : nil,
                        livePhotoMovieURL: capturedMedia.livePhotoMovieURL
                    )
                    dismiss()
                }
            } label: {
                Circle()
                    .fill(Color(hex: "#555153"))
                    .frame(width: 74, height: 74)
                    .overlay(
                        Circle()
                            .stroke(Color(hex: "#D8D0CA").opacity(0.72), style: StrokeStyle(lineWidth: 7, lineCap: .round, dash: [12, 8]))
                            .frame(width: 90, height: 90)
                    )
            }
            .buttonStyle(.plain)
            .disabled(!camera.isConfigured)

            Spacer()

            PhotosPicker(selection: $selectedItem, matching: .images) {
                Image(systemName: "photo")
                    .font(.system(size: 27, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(width: 74, height: 74)
                    .background(Circle().fill(.white.opacity(0.86)))
            }
        }
    }

    private func loadImage(from item: PhotosPickerItem?) async -> UIImage? {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self) else {
            return nil
        }
        return UIImage(data: data)
    }

    private var livePhotoToggle: some View {
        Button {
            camera.isLivePhotoEnabled.toggle()
        } label: {
            Text("LIVE")
                .font(BBBFont.font(size: 12, weight: .heavy))
                .foregroundStyle(camera.isLivePhotoEnabled ? .white : .white.opacity(0.62))
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(
                    Capsule()
                        .fill(camera.isLivePhotoEnabled ? Color(hex: "#F0A1C0").opacity(0.92) : Color.black.opacity(0.28))
                )
                .overlay(Capsule().stroke(.white.opacity(0.34), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(camera.isLivePhotoEnabled ? "关闭 Live Photo" : "开启 Live Photo")
    }

    private func croppedStickerSource(from capturedImage: UIImage, previewSize: CGSize) -> UIImage {
        let normalizedImage = capturedImage.normalized()
        guard previewSize.width > 1, previewSize.height > 1 else {
            return normalizedImage
        }

        let cropFrame = CGRect(
            x: previewSize.width * (1 - cropWidthRatio) / 2,
            y: previewSize.height * (1 - cropHeightRatio) / 2,
            width: previewSize.width * cropWidthRatio,
            height: previewSize.height * cropHeightRatio
        )

        return normalizedImage.croppedToPreviewFrame(
            cropFrame,
            previewSize: previewSize,
            videoGravity: .resizeAspectFill
        ) ?? normalizedImage
    }
}

private final class AchievementCameraModel: NSObject, ObservableObject {
    let session = AVCaptureSession()
    @MainActor @Published var isConfigured = false
    @MainActor @Published var isLivePhotoCaptureAvailable = false
    @MainActor @Published var isLivePhotoEnabled = true

    private let sessionQueue = DispatchQueue(label: "babybuddy.achievement.camera.session")
    private let output = AVCapturePhotoOutput()
    private var captureCompletion: ((AchievementCameraCapture) -> Void)?
    private var livePhotoCaptureSupported = false
    private var pendingCaptures: [Int64: PendingPhotoCapture] = [:]

    func configure() async {
        let authorized = await requestAccessIfNeeded()
        guard authorized else { return }

        await withCheckedContinuation { continuation in
            sessionQueue.async {
                self.configureSession()
                continuation.resume()
            }
        }
    }

    func stop() {
        sessionQueue.async {
            guard self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    @MainActor
    func capture(completion: @escaping (AchievementCameraCapture) -> Void) {
        captureCompletion = completion
        let settings = AVCapturePhotoSettings()
        settings.photoQualityPrioritization = output.maxPhotoQualityPrioritization
        if output.maxPhotoDimensions.width > 0, output.maxPhotoDimensions.height > 0 {
            settings.maxPhotoDimensions = output.maxPhotoDimensions
        }
        if livePhotoCaptureSupported,
           output.isLivePhotoCaptureEnabled,
           isLivePhotoEnabled {
            settings.livePhotoMovieFileURL = Self.makeLivePhotoMovieURL()
        }
        pendingCaptures[settings.uniqueID] = PendingPhotoCapture(isLiveRequested: settings.livePhotoMovieFileURL != nil)
        output.capturePhoto(with: settings, delegate: self)
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

    private func configureSession() {
        guard session.inputs.isEmpty, session.outputs.isEmpty else {
            startSessionIfNeeded()
            return
        }

        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input),
            session.canAddOutput(output)
        else {
            return
        }

        session.beginConfiguration()
        session.sessionPreset = .photo
        session.addInput(input)
        session.addOutput(output)
        output.maxPhotoQualityPrioritization = .quality
        if output.isLivePhotoCaptureSupported {
            output.isLivePhotoCaptureEnabled = true
            livePhotoCaptureSupported = true
        } else {
            livePhotoCaptureSupported = false
        }
        if let maxPhotoDimensions = device.activeFormat.supportedMaxPhotoDimensions.max(by: {
            Int64($0.width) * Int64($0.height) < Int64($1.width) * Int64($1.height)
        }) {
            output.maxPhotoDimensions = maxPhotoDimensions
        }
        session.commitConfiguration()
        Task { @MainActor in
            isLivePhotoCaptureAvailable = livePhotoCaptureSupported
            if !livePhotoCaptureSupported {
                isLivePhotoEnabled = false
            }
        }

        startSessionIfNeeded()
    }

    private static func makeLivePhotoMovieURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("achievement-live-\(UUID().uuidString)")
            .appendingPathExtension("mov")
    }

    private struct PendingPhotoCapture {
        var image: UIImage?
        var livePhotoMovieURL: URL?
        var isLiveRequested: Bool
    }

    private func startSessionIfNeeded() {
        guard !session.isRunning else {
            Task { @MainActor in
                isConfigured = true
            }
            return
        }
        session.startRunning()
        Task { @MainActor in
            isConfigured = true
        }
    }
}

extension AchievementCameraModel: @unchecked Sendable {}

private struct AchievementCameraCapture {
    var image: UIImage
    var livePhotoMovieURL: URL?

    var isLivePhoto: Bool {
        livePhotoMovieURL != nil
    }
}

extension AchievementCameraModel: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            return
        }
        let uniqueID = photo.resolvedSettings.uniqueID
        Task { @MainActor [weak self] in
            guard let self else { return }
            var pending = pendingCaptures[uniqueID] ?? PendingPhotoCapture(isLiveRequested: false)
            pending.image = image
            pendingCaptures[uniqueID] = pending
            if !pending.isLiveRequested {
                completeCapture(uniqueID: uniqueID)
            }
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
        guard error == nil else { return }
        let uniqueID = resolvedSettings.uniqueID
        Task { @MainActor [weak self] in
            guard let self else { return }
            var pending = pendingCaptures[uniqueID] ?? PendingPhotoCapture(isLiveRequested: true)
            pending.livePhotoMovieURL = outputFileURL
            pendingCaptures[uniqueID] = pending
            completeCapture(uniqueID: uniqueID)
        }
    }

    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings,
        error: Error?
    ) {
        let uniqueID = resolvedSettings.uniqueID
        Task { @MainActor [weak self] in
            guard let self else { return }
            completeCapture(uniqueID: uniqueID)
        }
    }

    @MainActor
    private func completeCapture(uniqueID: Int64) {
        guard let pending = pendingCaptures[uniqueID],
              let image = pending.image else {
            return
        }
        if pending.isLiveRequested, pending.livePhotoMovieURL == nil {
            return
        }
        pendingCaptures[uniqueID] = nil
        captureCompletion?(AchievementCameraCapture(image: image, livePhotoMovieURL: pending.livePhotoMovieURL))
        captureCompletion = nil
    }
}

private struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.videoPreviewLayer.session = session
    }

    final class PreviewView: UIView {
        override static var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }

        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}

struct GrowthMetricSheet: View {
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
                Text(item.title)
                    .font(BBBFont.font(size: 13 * S, weight: .heavy))
            }
            .foregroundStyle(isSelected ? .white : Color(hex: "#6A55B8").opacity(0.82))
        }
        .frame(width: W - 48 * S)
    }

    private var weightReadout: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color.black.opacity(0.82))
            .frame(width: 205, height: 56)
            .overlay(
                Text(valueText)
                    .font(.system(size: 34, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            )
    }

    private var heightReadout: some View {
        Text("\(valueText)\(selectedKind.unit)")
            .font(BBBFont.font(size: 22, weight: .heavy))
            .foregroundStyle(.white)
            .monospacedDigit()
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(LinearGradient(colors: [selectedKind.accent, DesignToken.primarySoft], startPoint: .leading, endPoint: .trailing))
                    .overlay(Capsule(style: .continuous).stroke(.white.opacity(0.58), lineWidth: 1))
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
                            .fill(abs(scaleValue - value) < 0.05 ? selectedKind.accent : Color.white.opacity(0.58))
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
                    .overlay(Capsule(style: .continuous).fill(Color.white.opacity(0.28)))
                    .overlay(Capsule(style: .continuous).stroke(.white.opacity(0.68), lineWidth: 1))
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
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(0.86)))

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
        .background(Color(hex: "#F8F7FB"))
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
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func dateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter.string(from: date)
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
            RecordTopStat(title: "今日尿布", value: "\(todayDiaperRecords.count)次"),
            RecordTopStat(title: "今日时间", value: timeString(recordedAt)),
            RecordTopStat(title: "距上次", value: lastDiaperDistanceText),
            RecordTopStat(title: "当前时间", value: timeString(recordedAt))
        ]
    }

    private var todayDiaperRecords: [CareRecord] {
        activityStore.todayCareRecords.filter { $0.kind == .diaper }
    }

    private var lastDiaperDistanceText: String {
        guard let latest = todayDiaperRecords.sorted(by: { $0.recordedAt > $1.recordedAt }).first else {
            return "暂无"
        }
        let minutes = max(Int(recordedAt.timeIntervalSince(latest.recordedAt) / 60), 0)
        if minutes < 60 { return "\(minutes)分钟" }
        return "\(minutes / 60)小时\(minutes % 60)分"
    }

    private var diaperStatsButton: some View {
        Button {
            showMore = true
        } label: {
            Label("记录统计", systemImage: "chart.line.uptrend.xyaxis")
                .font(BBBFont.font(size: 13, weight: .heavy))
                .foregroundStyle(Color(hex: "#5D609E"))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(width: 112, height: 58)
                .background(Capsule(style: .continuous).fill(Color.white.opacity(0.50)))
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
        .background(Color(hex: "#F8F7FB"))
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
                    .foregroundStyle(.white)
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
                    .background(Circle().fill(.white.opacity(0.94)))
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(isCompactHeight ? 6 : 8)
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(Capsule(style: .continuous).stroke(.white.opacity(0.7), lineWidth: 1))
                .shadow(color: Color(hex: "#4D4B70").opacity(0.15), radius: 18, y: 8)
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
                .background(Circle().fill(.white.opacity(0.82)))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
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
                                Color.white.opacity(0.54),
                                Color(hex: "#E9F8F0").opacity(0.22),
                                Color.white.opacity(0.36)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: jarWidth * 0.24, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.95), Color(hex: "#BDE8D8").opacity(0.36), .white.opacity(0.68)],
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
                                    colors: [Color(hex: "#EAF8F1").opacity(0.62), Color.white.opacity(0.42)],
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
                            .fill(.white.opacity(0.64))
                            .frame(width: 12, height: jarHeight * 0.62)
                            .blur(radius: 0.2)
                            .padding(.leading, jarWidth * 0.16)
                            .padding(.top, jarHeight * 0.08)
                    }
                    .overlay(alignment: .trailing) {
                        Capsule()
                            .fill(Color(hex: "#82CDB5").opacity(0.13))
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
            .fill(Color(hex: "#67C587").opacity(0.08))
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
                        .fill(isSelected ? type.softFill.opacity(0.88) : Color.white.opacity(0.92))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(isSelected ? type.accent.opacity(0.62) : .white.opacity(0.86), lineWidth: 1.4)
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
                            .stroke(.white.opacity(0.84), lineWidth: 1)
                    )
                    .offset(x: -size * 0.14, y: size * 0.18)
            }
            .overlay(alignment: .bottomLeading) {
                if type == .poop {
                    Capsule()
                        .fill(Color(hex: "#9A6A3E").opacity(0.7))
                        .frame(width: size * 0.28, height: size * 0.1)
                        .rotationEffect(.degrees(-12))
                        .offset(x: size * 0.26, y: -size * 0.2)
                } else {
                    Capsule()
                        .fill(Color.white.opacity(0.72))
                        .frame(width: size * 0.32, height: size * 0.08)
                        .rotationEffect(.degrees(-18))
                        .offset(x: size * 0.24, y: -size * 0.22)
                }
            }
            .shadow(color: Color.black.opacity(0.07), radius: size * 0.08, y: size * 0.04)
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
                    .stroke(Color.white.opacity(0.52), lineWidth: ringWidth)
                    .frame(width: ringSize, height: ringSize)

                Circle()
                    .stroke(Color(hex: "#B8B6EC").opacity(0.22), lineWidth: ringWidth * 0.74)
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
                            Color(hex: "#8F93E8").opacity(0.88),
                            style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: ringSize, height: ringSize)
                        .shadow(color: Color(hex: "#8F93E8").opacity(0.20), radius: 9, y: 4)
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
                        .fill(Color(hex: "#D8A64E").opacity(0.92))
                        .overlay(Circle().stroke(Color.white.opacity(0.80), lineWidth: 1))
                        .frame(width: markerSize, height: markerSize)
                        .offset(pointOffset(fraction: timeFraction(date), radius: ringSize * 0.5))
                        .shadow(color: Color(hex: "#D8A64E").opacity(0.22), radius: 5, y: 2)
                }

                SleepSunMoonMarker(systemIcon: "sun.max.fill", color: Color(hex: "#E2A333"), size: markerSize * 0.62)
                    .offset(pointOffset(fraction: timeFraction(sunriseAt), radius: labelRadius * 1.08))

                SleepSunMoonMarker(systemIcon: "moon.stars.fill", color: Color(hex: "#8F93E8"), size: markerSize * 0.62)
                    .offset(pointOffset(fraction: timeFraction(sunsetAt), radius: labelRadius * 1.08))

                ForEach(0..<96, id: \.self) { index in
                    let isHour = index % 4 == 0
                    let isMajorHour = index % 24 == 0
                    Capsule(style: .continuous)
                        .fill(Color(hex: "#7E7AB6").opacity(isMajorHour ? 0.48 : (isHour ? 0.34 : 0.18)))
                        .frame(width: isMajorHour ? 2.2 : 1.2, height: isMajorHour ? ringWidth * 0.42 : (isHour ? ringWidth * 0.34 : ringWidth * 0.22))
                        .offset(y: -outerTickRadius)
                        .rotationEffect(.degrees(Double(index) / 96 * 360))
                }

                ForEach(0..<96, id: \.self) { index in
                    let isHour = index % 4 == 0
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(isHour ? 0.62 : 0.36))
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
                        .foregroundStyle(Color(hex: "#8F93E8").opacity(0.86))
                    Spacer()
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: side * 0.072, weight: .semibold))
                        .foregroundStyle(Color(hex: "#E2A333").opacity(0.88))
                }
                .frame(height: ringSize * 0.54)
                .allowsHitTesting(false)

                VStack(spacing: 3) {
                    Text(durationText)
                        .font(BBBFont.font(size: side * 0.12, weight: .heavy))
                        .foregroundStyle(Color(hex: "#282A78"))
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
            .overlay(Circle().fill(Color.white.opacity(0.62)))
            .overlay(Circle().stroke(Color.white.opacity(0.88), lineWidth: 1))
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: systemIcon)
                    .font(.system(size: size * 0.43, weight: .heavy))
                    .foregroundStyle(Color(hex: "#5D609E").opacity(0.88))
            )
            .shadow(color: Color(hex: "#7E76C8").opacity(0.18), radius: 9, y: 4)
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
            .background(Circle().fill(Color.white.opacity(0.42)))
            .overlay(Circle().stroke(Color.white.opacity(0.58), lineWidth: 1))
            .shadow(color: color.opacity(0.18), radius: 5, y: 2)
            .allowsHitTesting(false)
    }
}

private struct SleepTimeRingHourLabel: View {
    let hour: Int

    var body: some View {
        Text("\(hour)点")
            .font(BBBFont.font(size: 10, weight: .heavy))
            .foregroundStyle(Color(hex: "#7473B8").opacity(0.78))
            .monospacedDigit()
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.36))
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
                    .stroke(Color.white.opacity(0.46), lineWidth: side * 0.11)
                    .frame(width: ringSize, height: ringSize)

                Circle()
                    .stroke(Color(hex: "#B8B6EC").opacity(0.22), lineWidth: side * 0.074)
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
                .fill(Color(hex: "#8F93E8").opacity(0.42))
                .frame(width: 4, height: 4)
            Text("\(hour)")
                .font(BBBFont.font(size: 9, weight: .bold))
                .foregroundStyle(Color(hex: "#7473B8").opacity(0.76))
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
        max(Int(normalizedManualEndTime.timeIntervalSince(manualStartTime) / 60), 0)
    }

    private var canSaveManualSleep: Bool {
        manualDurationMinutes > 0 && normalizedManualEndTime <= Date()
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
                .foregroundStyle(Color(hex: "#5D609E").opacity(0.92))
                .frame(width: 42 * metrics.S, height: 42 * metrics.S)
                .background(Circle().fill(Color.white.opacity(0.42)))

            VStack(alignment: .leading, spacing: 4 * metrics.S) {
                Text(activeStartTime == nil ? "选取睡眠时间段" : "正在计时")
                    .font(BBBFont.font(size: 12 * metrics.S, weight: .heavy))
                    .foregroundStyle(DesignToken.textSecondary)
                Text(SleepRecordFormatter.durationText(minutes: duration))
                    .font(BBBFont.font(size: 24 * metrics.S, weight: .heavy))
                    .foregroundStyle(Color(hex: "#282A78"))
                    .monospacedDigit()
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4 * metrics.S) {
                Text("开始")
                    .font(BBBFont.font(size: 10 * metrics.S, weight: .bold))
                    .foregroundStyle(DesignToken.textSecondary)
                Text(timeString(start))
                    .font(BBBFont.font(size: 14 * metrics.S, weight: .heavy))
                    .foregroundStyle(Color(hex: "#4D68D8"))
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 16 * metrics.S)
        .padding(.vertical, 12 * metrics.S)
        .frame(width: metrics.W - 54 * metrics.S)
        .background(
            RoundedRectangle(cornerRadius: 22 * metrics.S, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 22 * metrics.S, style: .continuous).fill(Color.white.opacity(0.38)))
                .overlay(RoundedRectangle(cornerRadius: 22 * metrics.S, style: .continuous).stroke(.white.opacity(0.68), lineWidth: 1))
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
                .overlay(RoundedRectangle(cornerRadius: 22 * metrics.S, style: .continuous).fill(Color.white.opacity(0.44)))
                .overlay(RoundedRectangle(cornerRadius: 22 * metrics.S, style: .continuous).stroke(.white.opacity(0.72), lineWidth: 1))
        )
    }

    private func sleepSummaryRow(title: String, value: String, metrics: RecordGlassRecorderMetrics, isEmphasized: Bool = false) -> some View {
        HStack {
            Text(title)
                .font(BBBFont.font(size: 11 * metrics.S, weight: .bold))
                .foregroundStyle(DesignToken.textSecondary)
            Spacer()
            Text(value)
                .font(BBBFont.font(size: (isEmphasized ? 14 : 12) * metrics.S, weight: .heavy))
                .foregroundStyle(isEmphasized ? Color(hex: "#4D68D8") : DesignToken.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
        }
    }

    private var canSaveSleepText: String {
        if activeStartTime != nil { return "底部保存" }
        return canSaveManualSleep ? "可保存" : "醒来时间需要晚于入睡"
    }

    private var canSaveSleepTextColor: Color {
        if activeStartTime != nil || canSaveManualSleep { return Color(hex: "#4D68D8") }
        return Color.red.opacity(0.72)
    }

    private var normalizedManualEndTime: Date {
        if manualEndTime > manualStartTime {
            return manualEndTime
        }
        return manualEndTime.addingTimeInterval(24 * 60 * 60)
    }

    private var sleepHero: some View {
        RecordHeroStage(assetName: "record_sleep_hero", fallbackSystemIcon: "moon.stars.fill", accent: Color(hex: "#6DA5F2")) {
            VStack(spacing: 8) {
                Text(activeStartTime == nil ? SleepRecordFormatter.durationText(minutes: manualDurationMinutes) : SleepRecordFormatter.durationText(minutes: activeElapsedMinutes))
                    .font(BBBFont.font(size: 42, weight: .heavy))
                    .foregroundStyle(Color(hex: "#282A78"))
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
                    .foregroundStyle(Color(hex: "#4D68D8"))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.white.opacity(0.42)))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(.white.opacity(0.76), lineWidth: 1))
        )
        .onChange(of: manualStartTime) { _, newValue in
            if manualEndTime <= newValue {
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
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.white.opacity(0.42)))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(.white.opacity(0.76), lineWidth: 1))
        )
    }

    private func sleepLeadingDock(_ metrics: RecordGlassRecorderMetrics) -> some View {
        Group {
            if activeStartTime == nil {
                RecordGlassDockActionButton(
                    title: "开始睡眠",
                    systemIcon: "play.fill",
                    foreground: Color(hex: "#5D609E"),
                    S: metrics.S
                ) {
                    startSleepTimer()
                }
            } else {
                RecordGlassDockActionButton(
                    title: "取消计时",
                    systemIcon: "xmark",
                    foreground: Color(hex: "#8E4B6A"),
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
                        .foregroundStyle(canSaveManualSleep ? Color(hex: "#4D68D8") : Color.red.opacity(0.74))
                }

            } else {
                EmptyView()
            }
        }
        .padding(16)
        .frame(width: 320)
        .background(Color(hex: "#F8F7FB"))
    }

    private var sleepTopStats: [RecordTopStat] {
        [
            RecordTopStat(title: "距上次", value: lastSleepDistanceText),
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
                color: Color(hex: "#8F93E8"),
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
            segments.append(SleepRingSegment(startAt: record.recordedAt, endAt: end, color: Color(hex: "#8F93E8"), lineWidth: 18, opacity: 0.82))
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
                    color: Color(hex: "#D8A64E"),
                    lineWidth: 10,
                    opacity: 0.78
                )
            )
        }

        if let activeStartTime {
            segments.append(SleepRingSegment(startAt: activeStartTime, endAt: timerTick, color: Color(hex: "#8F93E8"), lineWidth: 20, opacity: 0.92))
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
        guard let latest = todaySleepRecords.sorted(by: { $0.recordedAt > $1.recordedAt }).first else {
            return "暂无"
        }
        let anchor = activeStartTime ?? manualStartTime
        let minutes = max(Int(anchor.timeIntervalSince(latest.recordedAt) / 60), 0)
        if minutes < 60 { return "\(minutes)分钟" }
        return "\(minutes / 60)小时\(minutes % 60)分"
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
        activityStore.recordSleep(startTime: manualStartTime, endTime: normalizedManualEndTime, note: "")
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
        if normalizedManualEndTime <= manualStartTime {
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
                    .foregroundStyle(selection.kind == .wakeUp ? Color(hex: "#E2A333") : Color(hex: "#6B6FD6"))
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.white.opacity(0.76)))

                VStack(alignment: .leading, spacing: 4) {
                    Text(selection.kind.title)
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
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Capsule().fill(Color(hex: "#6B6FD6")))
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(22)
        .background(Color(hex: "#F8F7FB").ignoresSafeArea())
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
                    .fill(Color(hex: "#6DA5F2").opacity(0.12))
                    .frame(width: 128, height: 128)

                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(Color(hex: "#6DA5F2"))
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
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        Capsule()
                            .fill(Color(hex: "#6DA5F2"))
                            .shadow(color: Color(hex: "#6DA5F2").opacity(0.2), radius: 16, y: 8)
                    )
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.white.opacity(0.94)))
    }

    private var activeSleepCard: some View {
        VStack(spacing: 16) {
            Text(SleepRecordFormatter.durationText(minutes: activeElapsedMinutes))
                .font(BBBFont.font(size: 42, weight: .heavy))
                .foregroundStyle(Color(hex: "#4D68D8"))
                .monospacedDigit()

            if let startBinding = activeStartBinding {
                DatePicker("入睡", selection: startBinding, displayedComponents: [.hourAndMinute])
                    .font(BBBFont.font(size: 17, weight: .semibold))
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(hex: "#F4F6FF")))
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
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Capsule().fill(Color(hex: "#6DA5F2")))
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
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.white.opacity(0.94)))
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
                    .foregroundStyle(canSaveManualSleep ? Color(hex: "#4D68D8") : Color.red.opacity(0.8))
            }

            Button {
                guard canSaveManualSleep else { return }
                activityStore.recordSleep(startTime: manualStartTime, endTime: manualEndTime, note: "")
                isPresented = false
            } label: {
                Label("保存补录睡眠", systemImage: "checkmark.circle.fill")
                    .font(BBBFont.font(size: 15, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(canSaveManualSleep ? Color(hex: "#6DA5F2") : Color.gray.opacity(0.36)))
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(!canSaveManualSleep)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.white.opacity(0.94)))
        .onChange(of: manualStartTime) { _, newValue in
            if manualEndTime <= newValue {
                manualEndTime = newValue.addingTimeInterval(30 * 60)
            }
        }
    }

    private var activeStartBinding: Binding<Date>? {
        guard activeStartTime != nil else { return nil }
        return Binding {
            sleepDraftStore.activeSleepStartAt ?? Date()
        } set: { newValue in
            let capped = min(newValue, Date().addingTimeInterval(-60))
            sleepDraftStore.updateStartTime(capped)
            timerTick = Date()
        }
    }

    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
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
                Color(hex: "#FBF9FF"),
                Color(hex: "#F7F3FF"),
                Color(hex: "#FFF7FB")
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
                                .stroke(.white.opacity(0.9), lineWidth: 1)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(BBBFont.font(size: 22, weight: .heavy))
                            .foregroundStyle(DesignToken.textPrimary)
                        Text(subtitle)
                            .font(BBBFont.font(size: 12, weight: .semibold))
                            .foregroundStyle(DesignToken.textSecondary)
                            .lineLimit(2)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.white.opacity(0.94))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(.white.opacity(0.84), lineWidth: 1.2)
                        )
                        .shadow(color: Color(hex: "#7E5DE8").opacity(0.06), radius: 12, y: 5)
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
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(DesignToken.primaryGradient)
                    .shadow(color: Color(hex: "#7E5DE8").opacity(0.16), radius: 14, y: 7)
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
        headerHeight = 40 * S
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

            Text(title)
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
                        Color(hex: "#DDD5FF"),
                        Color(hex: "#EFEAFF"),
                        Color(hex: "#F4F0FF"),
                        Color(hex: "#DFD8FF")
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                RadialGradient(
                    colors: [
                        Color.white.opacity(0.62),
                        Color(hex: "#C9C2FF").opacity(0.42),
                        .clear
                    ],
                    center: UnitPoint(x: 0.18, y: 0.10),
                    startRadius: 10,
                    endRadius: geo.size.width * 0.75
                )

                RadialGradient(
                    colors: [
                        Color.white.opacity(0.70),
                        Color.white.opacity(0.24),
                        .clear
                    ],
                    center: UnitPoint(x: 0.52, y: 0.48),
                    startRadius: 20,
                    endRadius: geo.size.width * 0.58
                )

                Ellipse()
                    .fill(Color.white.opacity(0.50))
                    .frame(width: geo.size.width * 1.45, height: geo.size.height * 0.17)
                    .blur(radius: 44)
                    .offset(y: geo.size.height * 0.18)

                RadialGradient(
                    colors: [
                        Color(hex: "#BFC9FF").opacity(0.40),
                        .clear
                    ],
                    center: UnitPoint(x: 0.12, y: 0.78),
                    startRadius: 10,
                    endRadius: geo.size.width * 0.68
                )

                RadialGradient(
                    colors: [
                        Color(hex: "#D9CBFF").opacity(0.48),
                        .clear
                    ],
                    center: UnitPoint(x: 0.80, y: 0.84),
                    startRadius: 20,
                    endRadius: geo.size.width * 0.70
                )

                VStack {
                    LinearGradient(
                        colors: [
                            Color(hex: "#BEB4EF").opacity(0.16),
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
                    Text(stat.value)
                        .font(BBBFont.font(size: 12 * metrics.S, weight: .semibold))
                        .foregroundStyle(DesignToken.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.62)
                        .allowsTightening(true)
                        .monospacedDigit()

                    Text(stat.title)
                        .font(BBBFont.font(size: 8 * metrics.S, weight: .regular))
                        .foregroundStyle(DesignToken.textSecondary.opacity(0.62))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                .frame(width: columnWidth)
                .clipped()

                if index < 3 {
                    Rectangle()
                        .fill(Color(hex: "#8D8CB8").opacity(0.18))
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
                .foregroundStyle(Color(hex: "#7465A8").opacity(0.88))
                .frame(width: size, height: size)
                .glassEffect(.regular.tint(Color.white.opacity(0.10)).interactive(), in: .circle)
                .overlay(Circle().fill(Color.white.opacity(0.075)))
                .overlay(Circle().stroke(Color.white.opacity(0.36), lineWidth: 1))
                .overlay(alignment: .topLeading) {
                    Circle()
                        .stroke(Color.white.opacity(0.24), lineWidth: 1)
                        .blur(radius: 0.5)
                        .padding(3)
                }
                .shadow(color: Color.white.opacity(0.28), radius: 8, y: -1)
                .shadow(color: Color(hex: "#7465A8").opacity(0.075), radius: 11, y: 5)
        }
        .buttonStyle(.plain)
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
                        .foregroundStyle(Color(hex: "#7465A8").opacity(0.78))
                        .shadow(color: Color.white.opacity(0.46), radius: 5, y: -1)
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
                .fill(Color.white.opacity(0.24))
                .frame(width: W * 0.72, height: 116 * S)
                .blur(radius: 30 * S)

            RadialGradient(
                colors: [
                    Color.white.opacity(0.34),
                    Color(hex: "#CEBDFF").opacity(0.14),
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
                        .foregroundStyle(.white)
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
                                            Color(hex: "#8F6CFF")
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                        .overlay(Capsule(style: .continuous).stroke(Color.white.opacity(0.66), lineWidth: 1))
                        .shadow(color: Color(hex: "#A78BFA").opacity(0.34), radius: 18, y: 7)
                }
                .disabled(!isSaveEnabled)
                .opacity(isSaveEnabled ? 1 : 0.58)
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(8 * S)
        .glassEffect(.regular.tint(Color.white.opacity(0.18)), in: .capsule)
        .overlay(Capsule(style: .continuous).stroke(Color.white.opacity(0.56), lineWidth: 1))
        .shadow(color: Color.white.opacity(0.42), radius: 14, y: -2)
        .shadow(color: Color(hex: "#7E76C8").opacity(0.14), radius: 22, y: 9)
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
                Text(title)
                    .font(BBBFont.font(size: 13 * S, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
            }
                .foregroundStyle(foreground.opacity(0.84))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Capsule(style: .continuous))
                .glassEffect(.regular.tint(Color.white.opacity(0.16)).interactive(), in: .capsule)
                .overlay(Capsule(style: .continuous).fill(Color.white.opacity(0.055)))
                .overlay(Capsule(style: .continuous).stroke(Color.white.opacity(0.30), lineWidth: 1))
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
                                .tint(isSelected ? Color(hex: "#927BE6").opacity(0.82) : Color.white.opacity(0.025))
                                .interactive(),
                            in: .rect(cornerRadius: 19 * S)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 19 * S, style: .continuous)
                                .stroke(Color.white.opacity(isSelected ? 0.78 : 0.14), lineWidth: 1)
                        )
                        .overlay {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 19 * S, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(hex: "#8C72DE").opacity(0.36),
                                                Color(hex: "#C6B9F4").opacity(0.24)
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
                                    .fill(Color.white.opacity(0.34))
                                    .frame(width: 38 * S, height: 11 * S)
                                    .padding(.top, 4 * S)
                            }
                        }
                        .shadow(
                            color: Color(hex: "#7A63C8").opacity(isSelected ? 0.28 : 0.01),
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

            Text(title)
                .font(BBBFont.font(size: 28, weight: .heavy))
                .foregroundStyle(Color(hex: "#282A78"))
                .shadow(color: .white.opacity(0.72), radius: 2, y: 1)
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
                            .foregroundStyle(Color(hex: "#5D609E").opacity(0.78))
                            .frame(height: 20)
                    } else {
                        Text(stat.title)
                            .font(BBBFont.font(size: 13, weight: .bold))
                            .foregroundStyle(Color(hex: "#5D609E").opacity(0.76))
                            .lineLimit(1)
                            .minimumScaleFactor(0.74)
                            .frame(height: 20)
                    }

                    Text(stat.value)
                        .font(BBBFont.font(size: 20, weight: .heavy))
                        .foregroundStyle(Color(hex: "#262B82"))
                        .lineLimit(1)
                        .minimumScaleFactor(0.42)
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity)

                if index < min(stats.count, 4) - 1 {
                    Rectangle()
                        .fill(Color(hex: "#9294C8").opacity(0.32))
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
                .overlay(Circle().fill(Color.white.opacity(0.34)))
                .overlay(Circle().stroke(.white.opacity(0.78), lineWidth: 1.2))
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
                                .fill(item == selected ? DesignToken.primary.opacity(0.66) : Color.white.opacity(0.58))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .stroke(.white.opacity(item == selected ? 0.86 : 0.72), lineWidth: 1.2)
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
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .frame(maxWidth: .infinity)
                    .frame(height: 62)
                    .background(
                        Capsule(style: .continuous)
                            .fill(isSaveEnabled ? DesignToken.primaryGradient : LinearGradient(colors: [.gray.opacity(0.44), .gray.opacity(0.44)], startPoint: .leading, endPoint: .trailing))
                            .overlay(Capsule(style: .continuous).stroke(.white.opacity(0.58), lineWidth: 1.1))
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
                .overlay(Capsule(style: .continuous).fill(Color.white.opacity(0.34)))
                .overlay(Capsule(style: .continuous).stroke(.white.opacity(0.70), lineWidth: 1.1))
                .shadow(color: Color(hex: "#7E5DE8").opacity(0.18), radius: 24, y: 10)
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
                .foregroundStyle(.white.opacity(0.96))
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(Circle().fill(Color.white.opacity(0.22)))
                        .overlay(Circle().stroke(.white.opacity(0.76), lineWidth: 1.1))
                        .shadow(color: Color(hex: "#7E5DE8").opacity(0.12), radius: 16, y: 7)
                )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

private var recordEditorBackground: some View {
    ZStack {
        LinearGradient(
            colors: [
                Color(hex: "#E9E3FF"),
                Color(hex: "#F2E7FF"),
                Color(hex: "#FFE8F3")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        Circle()
            .fill(Color(hex: "#B7C7FF").opacity(0.34))
            .frame(width: 340, height: 340)
            .blur(radius: 86)
            .offset(x: -128, y: 132)

        Circle()
            .fill(Color(hex: "#FFBDE2").opacity(0.28))
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
            Text(title)
                .font(BBBFont.font(size: 24, weight: .bold))
                .foregroundStyle(DesignToken.textPrimary)
            Text(subtitle)
                .font(BBBFont.font(size: 15, weight: .medium))
                .foregroundStyle(DesignToken.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .cardStyle()
        .padding(28)
    }
}
