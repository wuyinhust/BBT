import PhotosUI
import SwiftUI
import UIKit
import AVFoundation

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
    @EnvironmentObject private var companionStore: CompanionStore
    @EnvironmentObject private var recruitmentStore: CompanionRecruitmentStore
    @EnvironmentObject private var temperamentStore: TemperamentProfileStore
    @Environment(BabyProfileStore.self) private var profileStore
    let openFeedSheet: () -> Void
    let openCompanionPicker: () -> Void
    @Binding var activeYesterdayReport: YesterdayReport?

    init(openFeedSheet: @escaping () -> Void, openCompanionPicker: @escaping () -> Void, activeYesterdayReport: Binding<YesterdayReport?> = .constant(nil)) {
        self.openFeedSheet = openFeedSheet
        self.openCompanionPicker = openCompanionPicker
        _activeYesterdayReport = activeYesterdayReport
    }

    var body: some View {
        BabyLiveIslandView(
            messages: liveMessages,
            subtitle: liveSubtitle,
            hostCompanion: liveHostCompanion,
            visitorCompanions: visitorCompanions,
            showsDismissButton: false
        ) {
            openFeedSheet()
        } openCompanionPicker: {
            openCompanionPicker()
        }
        .overlay {
            if let activeYesterdayReport {
                YesterdayReportOverlay(report: activeYesterdayReport) {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        self.activeYesterdayReport = nil
                    }
                }
                .environmentObject(recruitmentStore)
                .transition(.scale(scale: 0.96).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: activeYesterdayReport?.id)
    }

    private var companionPresences: [CompanionAnimalPresence] {
        BabyCompanion.companionPageAnimals(
            selectedID: companionStore.selectedID,
            temperamentAnimalID: temperamentStore.result?.animalID,
            recruitedIDs: recruitmentStore.recruitedIDs
        )
    }

    private var visitorCompanions: [BabyCompanion] {
        if let activeYesterdayReport {
            return activeYesterdayReport.visitorIDs.map { BabyCompanion.companion(for: $0) }
        }
        if let latestReport = recruitmentStore.latestReport(),
           recruitmentStore.feedableBBBucks(for: latestReport) > 0 {
            return latestReport.visitorIDs.map { BabyCompanion.companion(for: $0) }
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
                        .black.opacity(0.30),
                        .black.opacity(0.02),
                        .black.opacity(0.40)
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
    }

    private func liveHeader(metrics: LiveIslandLayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                HStack(spacing: 7) {
                    liveCompanionAvatar(hostCompanion, size: metrics.hostAvatarSize)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(hostCompanion.chineseName)的小木屋")
                            .font(BBBFont.font(size: metrics.headerTitleSize, weight: .heavy))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.70)

                        Text(subtitle)
                            .font(BBBFont.font(size: metrics.headerSubtitleSize, weight: .bold))
                            .foregroundStyle(.white.opacity(0.86))
                            .lineLimit(1)
                            .minimumScaleFactor(0.70)
                    }

                    Button {} label: {
                        Text("关注")
                            .font(BBBFont.font(size: metrics.followFontSize, weight: .heavy))
                            .foregroundStyle(.white)
                            .frame(width: metrics.followButtonWidth, height: metrics.followButtonHeight)
                            .background(Capsule().fill(Color(hex: "#FE3D76")))
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                .padding(.leading, 4)
                .padding(.trailing, 7)
                .frame(height: metrics.headerPillHeight)
                .background(Capsule().fill(.black.opacity(0.28)))

                Spacer(minLength: 6)

                if !metrics.isNarrowWidth {
                    visitorAvatarStack(metrics: metrics)
                }

                Text("\(viewerCount)")
                    .font(BBBFont.font(size: metrics.counterFontSize, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 11)
                    .frame(height: metrics.headerIconButtonSize)
                    .background(Capsule().fill(.black.opacity(0.22)))

                Button {
                    openCompanionPicker()
                } label: {
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: metrics.headerIconSize, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(width: metrics.headerIconButtonSize, height: metrics.headerIconButtonSize)
                        .background(Circle().fill(.black.opacity(0.24)))
                }
                .buttonStyle(ScaleButtonStyle())
            }

            HStack(spacing: 8) {
                Text("小木屋第 1 名")
                    .font(BBBFont.font(size: metrics.secondaryPillFontSize, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .frame(height: metrics.secondaryPillHeight)
                    .background(Capsule().fill(.black.opacity(0.22)))

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
                    .font(BBBFont.font(size: metrics.secondaryPillFontSize, weight: .heavy))
                    .foregroundStyle(.white)
                Image(systemName: "chevron.right")
                    .font(.system(size: metrics.secondaryChevronSize, weight: .heavy))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 14)
            .frame(height: metrics.secondaryPillHeight)
            .background(Capsule().fill(.black.opacity(0.20)))
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
        VStack(alignment: .leading, spacing: 5) {
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
        .font(BBBFont.font(size: metrics.joinFontSize, weight: .heavy))
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
                .font(BBBFont.font(size: metrics.messageSpeakerSize, weight: .heavy))
                .foregroundStyle(message.tint)
                .lineLimit(1)

            Text(message.isJoin ? "" : "：\(message.text)")
                .font(BBBFont.font(size: metrics.messageBodySize, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .lineSpacing(1)
        }
        .padding(.leading, 6)
        .padding(.trailing, 12)
        .padding(.vertical, metrics.messageVerticalPadding)
        .background(Capsule().fill(.black.opacity(message.isCareLog ? 0.24 : 0.18)))
        .shadow(color: .black.opacity(0.06), radius: 5, y: 2)
    }

    private func levelBadge(_ level: Int, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "diamond.fill")
                .font(.system(size: 7, weight: .heavy))
            Text("\(level)")
                .font(BBBFont.font(size: 10, weight: .heavy))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 6)
        .frame(height: 19)
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
                    .font(BBBFont.font(size: metrics.composerFontSize, weight: .bold))
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
            .background(Capsule().fill(.black.opacity(0.18)))
            .overlay(Capsule().stroke(.white.opacity(0.09), lineWidth: 1))

            Button {
                likeLive()
            } label: {
                liveRoundAction(icon: "heart.fill", colors: [Color(hex: "#FF4A84"), Color(hex: "#7F5BFF")], metrics: metrics)
            }
            .buttonStyle(ScaleButtonStyle())

            Button {
                openRecord()
            } label: {
                liveRoundAction(icon: "gift.fill", colors: [Color(hex: "#FF4DB0"), Color(hex: "#FFB13B")], metrics: metrics)
            }
            .buttonStyle(ScaleButtonStyle())

            Button {
                openRecord()
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
        withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
            liked.toggle()
            heartBurst = FloatingHeart.makeBurst()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.3)) {
                heartBurst = []
            }
        }
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

private struct LiveIslandLayoutMetrics {
    let size: CGSize

    var isCompactHeight: Bool { size.height < 720 }
    var isNarrowWidth: Bool { size.width < 390 }

    var horizontalPadding: CGFloat {
        isNarrowWidth ? 14 : 18
    }

    var topPadding: CGFloat {
        isCompactHeight ? 8 : 12
    }

    var bottomPadding: CGFloat {
        isCompactHeight ? 12 : 16
    }

    var middleSpacing: CGFloat {
        isCompactHeight ? 12 : 22
    }

    var composerSpacing: CGFloat {
        isCompactHeight ? 9 : 12
    }

    var contentSpacing: CGFloat {
        isNarrowWidth ? 8 : 12
    }

    var messageLimit: Int {
        isCompactHeight ? 3 : 3
    }

    var chatMaxWidth: CGFloat {
        max(180, min(size.width - horizontalPadding * 2 - actionColumnWidth - contentSpacing - 6, isNarrowWidth ? 238 : 264))
    }

    var messageVerticalPadding: CGFloat {
        isCompactHeight ? 5 : 6
    }

    var avatarSize: CGFloat {
        isNarrowWidth ? 34 : 38
    }

    var hostAvatarSize: CGFloat {
        avatarSize + 6
    }

    var visitorAvatarSize: CGFloat {
        isNarrowWidth ? 30 : 34
    }

    var visitorAvatarLimit: Int {
        isNarrowWidth ? 2 : 3
    }

    var headerTitleSize: CGFloat {
        isNarrowWidth ? 12 : 13
    }

    var headerSubtitleSize: CGFloat {
        isNarrowWidth ? 9 : 10
    }

    var followFontSize: CGFloat {
        isNarrowWidth ? 12 : 13
    }

    var followButtonWidth: CGFloat {
        isNarrowWidth ? 48 : 52
    }

    var followButtonHeight: CGFloat {
        isNarrowWidth ? 30 : 32
    }

    var headerPillHeight: CGFloat {
        isNarrowWidth ? 48 : 52
    }

    var headerIconButtonSize: CGFloat {
        isNarrowWidth ? 36 : 38
    }

    var headerIconSize: CGFloat {
        isNarrowWidth ? 15 : 16
    }

    var counterFontSize: CGFloat {
        isNarrowWidth ? 14 : 15
    }

    var secondaryPillFontSize: CGFloat {
        isNarrowWidth ? 13 : 14
    }

    var secondaryPillHeight: CGFloat {
        isNarrowWidth ? 32 : 34
    }

    var secondaryChevronSize: CGFloat {
        isNarrowWidth ? 12 : 13
    }

    var joinFontSize: CGFloat {
        isNarrowWidth ? 13 : 14
    }

    var joinMessageHeight: CGFloat {
        isNarrowWidth ? 30 : 32
    }

    var messageSpeakerSize: CGFloat {
        isNarrowWidth ? 13 : 14
    }

    var messageBodySize: CGFloat {
        isNarrowWidth ? 13 : 14
    }

    var badgeFontSize: CGFloat {
        isNarrowWidth ? 9 : 10
    }

    var badgeSize: CGFloat {
        isNarrowWidth ? 19 : 20
    }

    var bottomActionSize: CGFloat {
        isCompactHeight || isNarrowWidth ? 40 : 44
    }

    var bottomIconSize: CGFloat {
        isCompactHeight || isNarrowWidth ? 18 : 20
    }

    var actionButtonSize: CGFloat {
        bottomActionSize
    }

    var actionColumnWidth: CGFloat {
        1
    }

    var composerHeight: CGFloat {
        isCompactHeight ? 40 : 44
    }

    var composerFontSize: CGFloat {
        isNarrowWidth ? 13 : 14
    }

    var composerIconSize: CGFloat {
        isNarrowWidth ? 19 : 20
    }

    var composerButtonSize: CGFloat {
        isCompactHeight || isNarrowWidth ? 32 : 34
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

struct BabyAchievementsView: View {
    @EnvironmentObject private var stickerStore: AchievementStickerStore
    @State private var showCreateSticker = false
    @State private var selectedAchievement: CustomAchievement?
    @State private var selectedTemplate: AchievementTemplate?

    private let sections: [AchievementSection] = [
        .init(
            title: "第一次",
            achievements: [
                .init(id: "first-hug", title: "第一次拥抱", description: "第一次把宝宝稳稳抱进怀里，这一刻值得留下。", symbol: "figure.2.arms.open"),
                .init(id: "first-big-smile", title: "第一次咧嘴笑", description: "宝宝第一次咧开嘴笑，家里的空气都变甜了。", symbol: "face.smiling.fill"),
                .init(id: "first-formula-can", title: "第一次空罐", description: "宝宝第一次吃完一整罐奶粉，成长的进度又亮了一格。", symbol: "takeoutbag.and.cup.and.straw.fill"),
                .init(id: "first-diaper", title: "第一次尿布", description: "完成第一次尿布护理，正式解锁照护日常。", symbol: "drop.fill")
            ]
        ),
        .init(
            title: "成长节点",
            achievements: [
                .init(id: "first-vaccine", title: "不疼不疼啊疼", description: "第一次带宝宝打针，心疼归心疼，也一起勇敢完成了。", symbol: "syringe.fill"),
                .init(id: "first-head-lift", title: "看见更大的世界", description: "宝宝第一次努力抬头，视野从这一刻慢慢变高。", symbol: "eye.fill"),
                .init(id: "one-month", title: "满月啦", description: "宝宝来到身边 30 天，正式收下第一枚月龄纪念。", symbol: "moon.stars.fill")
            ]
        )
    ]

    var body: some View {
        ZStack {
            DesignToken.bg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    achievementHeader

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 16),
                            GridItem(.flexible(), spacing: 16)
                        ],
                        spacing: 22
                    ) {
                        ForEach(allGridItems) { item in
                            switch item {
                            case .achievement(let achievement):
                                achievementCard(achievement)
                            case .customAchievement(let achievement):
                                customStickerCard(achievement)
                            case .createCustom:
                                createCustomCard
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 24)
                .padding(.bottom, 140)
            }
        }
        .sheet(isPresented: $showCreateSticker) {
            CreateCustomAchievementView { achievement in
                selectedAchievement = achievement
            }
                .environmentObject(stickerStore)
        }
        .sheet(item: $selectedTemplate) { template in
            CreateCustomAchievementView(template: template) { achievement in
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

    private var allGridItems: [AchievementGridItem] {
        let presets = allPresetAchievements
        guard let first = presets.first else {
            return [.createCustom] + customAchievements.map { .customAchievement($0) }
        }
        return [.achievement(first), .createCustom]
            + presets.dropFirst().map { .achievement($0) }
            + customAchievements.map { .customAchievement($0) }
    }

    private var createCustomCard: some View {
        Button {
            showCreateSticker = true
        } label: {
            achievementCardShell {
                VStack(spacing: 12) {
                    Image(systemName: "plus")
                        .font(.system(size: 32, weight: .heavy))
                        .foregroundStyle(DesignToken.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 112)

                    VStack(spacing: 4) {
                        Text("自定义成就")
                        .achievementTitleStyle()
                        Text("创建")
                            .achievementMetaStyle()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func customStickerCard(_ achievement: CustomAchievement) -> some View {
        Button {
            selectedAchievement = achievement
        } label: {
            achievementCardShell {
                VStack(spacing: 12) {
                    stickerImage(achievement)
                        .frame(maxWidth: .infinity)
                        .frame(height: 112)

                    VStack(spacing: 4) {
                        Text(achievement.name)
                            .achievementTitleStyle()
                        Text(timestampText(achievement.completedAt))
                            .achievementMetaStyle()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func stickerImage(_ achievement: CustomAchievement) -> some View {
        Group {
            if let image = stickerStore.thumbnailImage(for: achievement) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(DesignToken.primary)
            }
        }
    }

    private func achievementCard(_ achievement: Achievement) -> some View {
        let completedAchievement = stickerStore.achievement(for: achievement.id)
        let isUnlocked = completedAchievement != nil

        return Button {
            if let completedAchievement {
                selectedAchievement = completedAchievement
            } else {
                selectedTemplate = achievement.template
            }
        } label: {
            achievementCardShell {
                VStack(spacing: 12) {
                    if let completedAchievement, let image = stickerStore.thumbnailImage(for: completedAchievement, maxSide: 360) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .frame(height: 112)
                    } else {
                        Image(systemName: achievement.symbol)
                            .font(.system(size: 32, weight: .heavy))
                            .foregroundStyle(DesignToken.textSecondary.opacity(0.58))
                            .frame(maxWidth: .infinity)
                            .frame(height: 112)
                    }

                    VStack(spacing: 4) {
                        Text(achievement.title)
                            .achievementTitleStyle(color: isUnlocked ? DesignToken.textPrimary : DesignToken.textSecondary)
                        Text(completedAchievement.map { timestampText($0.completedAt) } ?? "未获取")
                            .achievementMetaStyle(opacity: isUnlocked ? 1 : 0.72)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func timestampText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = Calendar.current.isDate(date, inSameDayAs: Date()) ? "今天 HH:mm" : "M月d日 HH:mm"
        return formatter.string(from: date)
    }

    private var unlockedCount: Int {
        let completedPresetCount = sections.flatMap(\.achievements).filter { stickerStore.achievement(for: $0.id) != nil }.count
        return completedPresetCount + customAchievements.count
    }

    private var totalCount: Int {
        sections.flatMap(\.achievements).count + customAchievements.count
    }

    private var progressPercent: Int {
        guard totalCount > 0 else { return 0 }
        return Int((Double(unlockedCount) / Double(totalCount) * 100).rounded())
    }

    private var customAchievements: [CustomAchievement] {
        stickerStore.achievements.filter { $0.templateID == nil }
    }

    private var allPresetAchievements: [Achievement] {
        sections.flatMap(\.achievements)
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
            .font(BBBFont.font(size: 14, weight: .heavy))
            .foregroundStyle(color)
            .multilineTextAlignment(alignment)
            .lineLimit(2)
            .minimumScaleFactor(0.82)
    }

    func achievementMetaStyle(
        opacity: Double = 1,
        alignment: TextAlignment = .center
    ) -> some View {
        self
            .font(BBBFont.font(size: 10, weight: .bold))
            .foregroundStyle(DesignToken.textSecondary.opacity(opacity))
            .multilineTextAlignment(alignment)
    }
}

private func achievementCardShell<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    VStack(spacing: 0) {
        content()
    }
    .padding(.horizontal, 12)
    .padding(.top, 18)
    .padding(.bottom, 16)
    .frame(maxWidth: .infinity, alignment: .top)
    .aspectRatio(0.865, contentMode: .fit)
    .background(
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(.white)
            .shadow(color: Color.black.opacity(0.035), radius: 12, y: 5)
    )
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
    @State private var selectedImage: UIImage?
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
                AchievementCameraView(image: $selectedImage)
            }
            .onChange(of: selectedImage) { _, newImage in
                generateStickerPreview(from: newImage)
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
        guard let selectedImage, let stickerPreview else {
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
                sourceImage: selectedImage,
                stickerImage: stickerPreview
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
            let optimizedImage = image.optimizedForStickerInput(maxSide: StickerGenerator.stickerInputMaxSide)
            let sticker = StickerGenerator.generateSticker(from: optimizedImage)
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
    @State private var selectedImage: UIImage?
    @State private var isGeneratingSticker = false
    @State private var showCamera = false
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

                        if achievement.templateID == nil {
                            Button(role: .destructive) {
                                showDeleteConfirmation = true
                            } label: {
                                Label("删除成就", systemImage: "trash")
                            }
                        }
                    } label: {
                        achievementCircleButtonIcon("ellipsis")
                    }
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                AchievementCameraView(image: $selectedImage)
            }
            .alert("无法更新成就", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("好", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .confirmationDialog("删除这个自定义成就？", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("删除", role: .destructive) {
                    deleteAchievement()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("删除后，这张贴纸和备注会从宝宝成就中移除。")
            }
            .onChange(of: selectedImage) { _, newImage in
                updateStickerImage(from: newImage)
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

    private func updateStickerImage(from image: UIImage?) {
        let currentGenerationID = UUID()
        generationID = currentGenerationID
        guard let image else {
            isGeneratingSticker = false
            return
        }
        isGeneratingSticker = true
        Task.detached(priority: .userInitiated) {
            let optimizedImage = image.optimizedForStickerInput(maxSide: StickerGenerator.stickerInputMaxSide)
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

private struct AchievementCameraView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var image: UIImage?
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
                    image = loadedImage
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
                camera.capture { capturedImage in
                    image = croppedStickerSource(from: capturedImage, previewSize: targetPreviewSize)
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

    private let sessionQueue = DispatchQueue(label: "babybuddy.achievement.camera.session")
    private let output = AVCapturePhotoOutput()
    private var captureCompletion: ((UIImage) -> Void)?

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

    func capture(completion: @escaping (UIImage) -> Void) {
        captureCompletion = completion
        let settings = AVCapturePhotoSettings()
        settings.photoQualityPrioritization = output.maxPhotoQualityPrioritization
        if output.maxPhotoDimensions.width > 0, output.maxPhotoDimensions.height > 0 {
            settings.maxPhotoDimensions = output.maxPhotoDimensions
        }
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
        if let maxPhotoDimensions = device.activeFormat.supportedMaxPhotoDimensions.max(by: {
            Int64($0.width) * Int64($0.height) < Int64($1.width) * Int64($1.height)
        }) {
            output.maxPhotoDimensions = maxPhotoDimensions
        }
        session.commitConfiguration()

        startSessionIfNeeded()
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

extension AchievementCameraModel: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            return
        }
        Task { @MainActor in
            captureCompletion?(image)
            captureCompletion = nil
        }
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

struct DiaperSheet: View {
    @EnvironmentObject private var activityStore: ActivityStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var isPresented: Bool

    @State private var selectedType: DiaperRecordType?
    @State private var diaperTokens: [DiaperDropToken] = []
    @State private var jarFrame: CGRect = .zero
    @State private var note = ""
    @State private var recordedAt = Date()

    var body: some View {
        NavigationStack {
            recordSheetContent(
                title: "记录尿布",
                subtitle: "把尿布放进玻璃罐，再保存本次记录",
                icon: "archivebox.fill",
                accent: Color(hex: "#67C587")
            ) {
                VStack(spacing: 14) {
                    DiaperGlassJarView(tokens: diaperTokens)
                        .frame(maxWidth: .infinity)
                        .frame(height: 268)
                        .padding(.top, -2)
                        .background(
                            GeometryReader { proxy in
                                Color.clear.preference(key: DiaperJarFramePreferenceKey.self, value: proxy.frame(in: .global))
                            }
                        )

                    HStack(spacing: 12) {
                        ForEach(DiaperRecordType.allCases) { type in
                            DiaperDropButton(
                                type: type,
                                isSelected: selectedType == type,
                                onTap: {
                                    dropDiaper(type)
                                },
                                onDragEnded: { location in
                                    guard jarFrame.contains(location) else {
                                        return
                                    }
                                    dropDiaper(type)
                                }
                            )
                        }
                    }

                    DatePicker("时间", selection: $recordedAt, displayedComponents: [.hourAndMinute])
                        .font(BBBFont.font(size: 17, weight: .semibold))
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white.opacity(0.94)))

                    notesField

                    Button {
                        guard let selectedType else { return }
                        activityStore.recordDiaper(type: selectedType.rawValue, note: note, recordedAt: recordedAt)
                        isPresented = false
                    } label: {
                        Label("保存尿布记录", systemImage: "checkmark.circle.fill")
                            .font(BBBFont.font(size: 15, weight: .heavy))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                Capsule()
                                    .fill(selectedType == nil ? Color.gray.opacity(0.36) : Color(hex: "#67C587"))
                                    .shadow(color: Color(hex: "#67C587").opacity(selectedType == nil ? 0 : 0.16), radius: 14, y: 7)
                            )
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(selectedType == nil)
                }
            }
            .navigationTitle("记录尿布")
            .navigationBarTitleDisplayMode(.inline)
            .onPreferenceChange(DiaperJarFramePreferenceKey.self) { frame in
                jarFrame = frame
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { isPresented = false }
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private var notesField: some View {
        TextField("备注：比如颜色、量或护理情况", text: $note, axis: .vertical)
            .lineLimit(3, reservesSpace: true)
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white))
    }

    private func dropDiaper(_ type: DiaperRecordType) {
        selectedType = type
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
        if diaperTokens.count > 7 {
            diaperTokens.removeFirst(diaperTokens.count - 7)
        }
        UIImpactFeedbackGenerator(style: reduceMotion ? .light : .soft).impactOccurred(intensity: reduceMotion ? 0.45 : 0.7)
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

    var pileSlot: Int { index % 7 }

    var xOffset: CGFloat {
        let offsets: [CGFloat] = [-56, -22, 24, 58, -40, 6, 44]
        return offsets[pileSlot]
    }

    var yOffset: CGFloat {
        let offsets: [CGFloat] = [72, 64, 68, 58, 38, 34, 30]
        return offsets[pileSlot]
    }

    var rotation: Double {
        let rotations: [Double] = [-18, 11, -7, 17, 5, -13, 9]
        return rotations[pileSlot]
    }

    var scale: CGFloat {
        let scales: [CGFloat] = [0.9, 0.84, 0.88, 0.82, 0.78, 0.8, 0.76]
        return scales[pileSlot]
    }

    func placed() -> DiaperDropToken {
        var copy = self
        copy.isPlaced = true
        return copy
    }
}

private struct DiaperGlassJarView: View {
    let tokens: [DiaperDropToken]

    var body: some View {
        GeometryReader { proxy in
            let jarWidth = min(proxy.size.width * 0.68, 236)
            let jarHeight = min(proxy.size.height, 264)
            let tokenSize = jarWidth * 0.34

            ZStack {
                jarShadow(width: jarWidth, height: jarHeight)

                RoundedRectangle(cornerRadius: jarWidth * 0.24, style: .continuous)
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
                    .overlay(alignment: .top) {
                        Capsule()
                            .fill(.white.opacity(0.74))
                            .overlay(Capsule().stroke(Color(hex: "#BAE7D8").opacity(0.42), lineWidth: 1.4))
                            .frame(width: jarWidth * 0.72, height: 22)
                            .offset(y: -5)
                    }
                    .overlay(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#EAF8F1").opacity(0.62), Color.white.opacity(0.42)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: jarHeight * 0.28)
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
                                        x: token.isPlaced ? token.xOffset : 0,
                                        y: token.isPlaced ? token.yOffset : -jarHeight * 0.52
                                    )
                                    .opacity(token.isPlaced ? 1 : 0.34)
                            }
                        }
                        .frame(width: jarWidth * 0.86, height: jarHeight * 0.86)
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
    }

    private func jarShadow(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: width * 0.24, style: .continuous)
            .fill(Color(hex: "#67C587").opacity(0.08))
            .frame(width: width * 0.92, height: height * 0.16)
            .blur(radius: 14)
            .offset(y: height * 0.48)
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

struct SleepSheet: View {
    @EnvironmentObject private var activityStore: ActivityStore
    @EnvironmentObject private var sleepDraftStore: SleepDraftStore
    @Binding var isPresented: Bool

    @State private var manualStartTime = Date().addingTimeInterval(-30 * 60)
    @State private var manualEndTime = Date()
    @State private var manualNote = ""
    @State private var timerTick = Date()

    private var activeStartTime: Date? {
        sleepDraftStore.activeSleepStartAt
    }

    private var activeElapsedMinutes: Int {
        guard let activeStartTime else { return 0 }
        return max(Int(timerTick.timeIntervalSince(activeStartTime) / 60), 0)
    }

    private var manualDurationMinutes: Int {
        max(Int(manualEndTime.timeIntervalSince(manualStartTime) / 60), 0)
    }

    private var canSaveManualSleep: Bool {
        manualDurationMinutes > 0
    }

    var body: some View {
        NavigationStack {
            recordSheetContent(
                title: "记录睡眠",
                subtitle: activeStartTime == nil ? "开始计时，或补录已经结束的睡眠" : "宝宝还在睡，醒来后保存本次睡眠",
                icon: "moon.zzz.fill",
                accent: Color(hex: "#6DA5F2")
            ) {
                VStack(spacing: 16) {
                    if activeStartTime == nil {
                        idleSleepCard
                        manualSleepCard
                    } else {
                        activeSleepCard
                    }
                }
            }
            .navigationTitle("记录睡眠")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { isPresented = false }
                }
            }
        }
        .presentationDragIndicator(.visible)
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

            activeNotesField

            Button {
                guard let startTime = activeStartTime else { return }
                let endTime = max(Date(), startTime.addingTimeInterval(60))
                activityStore.recordSleep(startTime: startTime, endTime: endTime, note: sleepDraftStore.note)
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

            TextField("备注：比如入睡状态、醒来原因", text: $manualNote, axis: .vertical)
                .lineLimit(3, reservesSpace: true)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(hex: "#F8F9FF")))

            Button {
                guard canSaveManualSleep else { return }
                activityStore.recordSleep(startTime: manualStartTime, endTime: manualEndTime, note: manualNote)
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

    private var activeNotesField: some View {
        TextField(
            "备注：比如入睡状态、醒来原因",
            text: Binding(
                get: { sleepDraftStore.note },
                set: { sleepDraftStore.updateNote($0) }
            ),
            axis: .vertical
        )
        .lineLimit(3, reservesSpace: true)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(hex: "#F8F9FF")))
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
