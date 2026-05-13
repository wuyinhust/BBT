import PhotosUI
import SwiftUI
import UIKit

struct DailyMessageView: View {
    @EnvironmentObject private var feedingStore: FeedingStore
    @Environment(BabyProfileStore.self) private var profileStore
    @State private var showRecord = false

    var body: some View {
        BabyLiveIslandView(messages: liveMessages) {
            showRecord = true
        }
            .navigationBarBackButtonHidden(false)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showRecord) {
                RecordView(showFeedSheet: .constant(false))
            }
    }

    private var liveMessages: [LiveChatMessage] {
        let profile = profileStore.currentProfile
        let recentSessions = Array(feedingStore.todaySessions.prefix(4))
        let careMessages = recentSessions.map { session in
            LiveChatMessage(
                speaker: profile.name,
                text: careText(for: session),
                tint: Color(hex: "#FFE7A8"),
                isCareLog: true
            )
        }

        return [
            LiveChatMessage(speaker: "粉咕", text: "小木屋灯亮啦，今天的陪伴直播开始。", tint: Color(hex: "#FFD1DC")),
            LiveChatMessage(speaker: "芬灵", text: "我在地图右边巡逻，看到好多发光小花。", tint: Color(hex: "#FFC692")),
            LiveChatMessage(speaker: "柯噜", text: "如果宝宝刚吃饱，我们就把掌声开小一点。", tint: Color(hex: "#FFF19A"))
        ] + careMessages + [
            LiveChatMessage(speaker: "云朵", text: "今天也在稳定记录，照护节奏越来越清楚。", tint: Color(hex: "#D7E8FF")),
            LiveChatMessage(speaker: "啾啾", text: "我给宝宝攒了一颗温柔星星。", tint: Color(hex: "#FFF1A8"))
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
    let openRecord: () -> Void
    @State private var liked = false
    @State private var heartBurst: [FloatingHeart] = []

    var body: some View {
        ZStack {
            LiveIslandSceneView()

            LinearGradient(
                colors: [
                    .black.opacity(0.34),
                    .clear,
                    .black.opacity(0.42)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                liveHeader
                    .padding(.horizontal, 16)
                    .padding(.top, 10)

                Spacer()

                VStack(spacing: 12) {
                    HStack(alignment: .bottom, spacing: 12) {
                        chatStack
                            .allowsHitTesting(false)
                        Spacer(minLength: 10)
                        liveActions
                    }

                    liveComposer
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 18)
            }

            if !heartBurst.isEmpty {
                FloatingHeartsView(hearts: heartBurst)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
        .background(Color(hex: "#1AAE68"))
        .ignoresSafeArea()
    }

    private var liveHeader: some View {
        HStack(spacing: 10) {
            Button {
                dismiss()
            } label: {
                Circle()
                    .fill(.black.opacity(0.3))
                    .frame(width: 38, height: 38)
                    .overlay(
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundStyle(.white)
                    )
            }
            .buttonStyle(ScaleButtonStyle())

            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [Color(hex: "#FFE082"), Color(hex: "#FFA7C8")], startPoint: .topLeading, endPoint: .bottomTrailing))
                    Text("🏡")
                        .font(.system(size: 24))
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("BabyBuddy 小木屋")
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                        Text("LIVE")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color(hex: "#FF3B63")))
                    }
                    .foregroundStyle(.white)

                    Text("10只小动物正在陪伴宝宝")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.78))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Capsule().fill(.black.opacity(0.32)))

            Spacer()

            HStack(spacing: 5) {
                Image(systemName: "eye.fill")
                Text("2.4k")
            }
            .font(.system(size: 13, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(Capsule().fill(.black.opacity(0.28)))
        }
    }

    private var chatStack: some View {
        VStack(alignment: .leading, spacing: 8) {
            livePrompt

            ForEach(messages.suffix(7)) { message in
                liveMessageRow(message)
            }
        }
        .frame(maxWidth: 292, alignment: .leading)
    }

    private var livePrompt: some View {
        HStack(spacing: 8) {
            Image(systemName: "hand.draw.fill")
            Text("拖动屏幕看看小动物在做什么")
        }
        .font(.system(size: 12, weight: .bold, design: .rounded))
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Capsule().fill(.white.opacity(0.18)))
    }

    private func liveMessageRow(_ message: LiveChatMessage) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Text(message.speaker)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(message.tint)

            Text(message.text)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(message.isCareLog ? Color(hex: "#47351D").opacity(0.62) : .black.opacity(0.34))
        )
        .overlay(alignment: .leading) {
            if message.isCareLog {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color(hex: "#FFE08A").opacity(0.42), lineWidth: 1)
            }
        }
    }

    private var liveActions: some View {
        VStack(spacing: 14) {
            liveActionButton(icon: "pawprint.fill", title: "动物")
            liveActionButton(icon: "gift.fill", title: "贴纸")
            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                    liked.toggle()
                    heartBurst = FloatingHeart.makeBurst()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        heartBurst = []
                    }
                }
            } label: {
                VStack(spacing: 5) {
                    Circle()
                        .fill(liked ? Color(hex: "#FF477E") : .white.opacity(0.92))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: "heart.fill")
                                .font(.system(size: 23, weight: .heavy))
                                .foregroundStyle(liked ? .white : Color(hex: "#FF477E"))
                        )
                    Text("喜欢")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    private var liveComposer: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "message.fill")
                    .foregroundStyle(.white.opacity(0.7))
                Text("和小动物说点什么...")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
                Spacer()
            }
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(Capsule().fill(.black.opacity(0.32)))

            Button {
                openRecord()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                    Text("记录")
                }
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(Color(hex: "#3D2849"))
                .padding(.horizontal, 16)
                .frame(height: 44)
                .background(Capsule().fill(Color(hex: "#FFE08A")))
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    private func liveActionButton(icon: String, title: String) -> some View {
        VStack(spacing: 5) {
            Circle()
                .fill(.white.opacity(0.92))
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundStyle(Color(hex: "#6F55E8"))
                )
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
    }
}

struct LiveChatMessage: Identifiable {
    let id = UUID()
    let speaker: String
    let text: String
    let tint: Color
    var isCareLog = false
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
            title: "新人成就",
            achievements: [
                .init(id: "first-empty-bottle", title: "第一次空罐", description: "宝宝第一次喝完一整瓶奶，值得收集成贴纸。", symbol: "babybottle.fill"),
                .init(id: "first-diaper", title: "第一次尿布", description: "记录第一次尿布护理，保存这一刻。", symbol: "drop.fill"),
                .init(id: "first-sleep", title: "第一次睡眠", description: "记录第一次睡眠成就。", symbol: "moon.fill"),
                .init(id: "first-companion", title: "第一次陪伴", description: "和 Buddy 建立第一次陪伴记忆。", symbol: "heart.fill")
            ]
        ),
        .init(
            title: "照护成就",
            achievements: [
                .init(id: "three-day-streak", title: "连续记录 3 天", description: "连续三天记录宝宝照护。", symbol: "calendar.badge.checkmark"),
                .init(id: "ten-feedings", title: "完成 10 次喂养", description: "累计完成十次喂养记录。", symbol: "10.circle.fill"),
                .init(id: "growth-moment", title: "记录一次成长", description: "保存一个宝宝成长瞬间。", symbol: "sparkles"),
                .init(id: "steady-rhythm", title: "稳定作息", description: "开始形成稳定的宝宝照护节奏。", symbol: "clock.badge.checkmark.fill")
            ]
        ),
        .init(
            title: "陪伴成就",
            achievements: [
                .init(id: "first-chat", title: "和 Buddy 聊天", description: "第一次和 Buddy 聊天。", symbol: "message.fill"),
                .init(id: "switch-buddy", title: "切换陪伴伙伴", description: "选择一个新的陪伴伙伴。", symbol: "pawprint.fill"),
                .init(id: "first-interaction", title: "完成一次互动", description: "和 Buddy 完成一次互动。", symbol: "hand.tap.fill"),
                .init(id: "gentle-moment", title: "收集温柔时刻", description: "把一个温柔瞬间收进宝宝贴纸册。", symbol: "star.fill")
            ]
        )
    ]

    var body: some View {
        ZStack {
            DesignToken.bg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    achievementHeader

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 18),
                            GridItem(.flexible(), spacing: 18)
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
                .padding(.horizontal, 20)
                .padding(.top, 18)
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
            AchievementDetailView(achievement: achievement)
                .environmentObject(stickerStore)
        }
    }

    private var achievementHeader: some View {
        HStack(alignment: .center) {
            Text("宝宝成就")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(DesignToken.textPrimary)
                .frame(height: 44, alignment: .center)

            Spacer()

            progressTag
        }
    }

    private var progressTag: some View {
        HStack(spacing: 4) {
            Text("\(unlockedCount)/\(totalCount)")
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Text("已解锁")
                .font(.system(size: 11, weight: .bold, design: .rounded))
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
                        .font(.system(size: 40, weight: .heavy))
                        .foregroundStyle(DesignToken.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 136)

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
                        .frame(height: 136)

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
                            .frame(height: 136)
                    } else {
                        Image(systemName: achievement.symbol)
                            .font(.system(size: 40, weight: .heavy))
                            .foregroundStyle(DesignToken.textSecondary.opacity(0.58))
                            .frame(maxWidth: .infinity)
                            .frame(height: 136)
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
        formatter.dateFormat = "M/d HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
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
            .font(.system(size: 15, weight: .heavy, design: .rounded))
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
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(DesignToken.textSecondary.opacity(opacity))
            .multilineTextAlignment(alignment)
    }
}

private func achievementCardShell<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    VStack(spacing: 0) {
        content()
    }
    .padding(.horizontal, 16)
    .padding(.top, 16)
    .padding(.bottom, 12)
    .frame(maxWidth: .infinity, minHeight: 214, alignment: .top)
    .background(
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(.white)
            .shadow(color: Color.black.opacity(0.04), radius: 14, y: 6)
    )
}

private struct CreateCustomAchievementView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var stickerStore: AchievementStickerStore

    let template: AchievementTemplate?
    let onCreated: (CustomAchievement) -> Void

    @State private var name = ""
    @State private var description = ""
    @State private var note = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var stickerPreview: UIImage?
    @State private var isGeneratingSticker = false
    @State private var showCamera = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var generationID = UUID()

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
                    DesignToken.bg.ignoresSafeArea()

                    VStack(spacing: 0) {
                        VStack(spacing: 18) {
                            imagePickerCard(height: previewHeight(for: proxy.size.height))
                            formCard
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)

                        Spacer(minLength: 0)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                mediaActionBar
            }
            .navigationTitle(template == nil ? "自定义贴纸" : "完成成就")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(DesignToken.primary.opacity(0.72))
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(.white.opacity(0.92)))
                    }
                }

                if stickerPreview != nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            saveAchievement()
                        } label: {
                            if isSaving {
                                ProgressView()
                                    .tint(DesignToken.primary)
                                    .frame(width: 44, height: 44)
                            } else {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 19, weight: .bold))
                                    .foregroundStyle(canSaveAchievement ? DesignToken.primary : DesignToken.textSecondary.opacity(0.45))
                                    .frame(width: 44, height: 44)
                            }
                        }
                        .disabled(!canSaveAchievement)
                    }
                }
            }
            .alert("无法创建贴纸", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("好", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .sheet(isPresented: $showCamera) {
                CameraPicker(image: $selectedImage)
                    .ignoresSafeArea()
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
                        .font(.headline.weight(.bold))
                        .foregroundStyle(DesignToken.textPrimary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(DesignToken.primary)
                    Text("拍照或从相册选择一张照片")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(DesignToken.textPrimary)
                    Text("生成一枚宝宝成就贴纸")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DesignToken.textSecondary)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
    }

    private var formCard: some View {
        VStack(spacing: 12) {
            TextField("成就名称，例如：第一次空罐", text: $name)
                .textFieldStyle(.plain)
                .font(.headline.weight(.bold))
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(DesignToken.iconSoftBG))

            TextField("成就描述", text: $description, axis: .vertical)
                .lineLimit(2, reservesSpace: true)
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(DesignToken.iconSoftBG))

            TextField("备注，可选", text: $note, axis: .vertical)
                .lineLimit(2, reservesSpace: true)
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(DesignToken.iconSoftBG))
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(.white))
    }

    private var mediaActionBar: some View {
        HStack(spacing: 12) {
            Button {
                showCamera = true
            } label: {
                Label("拍照", systemImage: "camera.fill")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(DesignToken.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Capsule().fill(DesignToken.iconSoftBG))
            }
            .buttonStyle(ScaleButtonStyle())

            PhotosPicker(selection: $selectedItem, matching: .images) {
                Label("相册", systemImage: "photo.on.rectangle.angled")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Capsule().fill(DesignToken.primaryGradient))
            }
            .onChange(of: selectedItem) { _, newItem in
                Task {
                    selectedImage = await loadImage(from: newItem)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(DesignToken.bg.opacity(0.96))
    }

    private func saveAchievement() {
        guard let selectedImage, let stickerPreview else {
            errorMessage = "请先选择一张照片"
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

    private func loadImage(from item: PhotosPickerItem?) async -> UIImage? {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self) else {
            return nil
        }
        return UIImage(data: data)
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
            let optimizedImage = image.optimizedForStickerInput()
            let sticker = StickerGenerator.generateSticker(from: optimizedImage)
            await MainActor.run {
                guard generationID == currentGenerationID else { return }
                stickerPreview = sticker
                isGeneratingSticker = false
            }
        }
    }

    private func previewHeight(for availableHeight: CGFloat) -> CGFloat {
        min(max(availableHeight * 0.28, 200), 280)
    }

    private var canSaveAchievement: Bool {
        stickerPreview != nil && !isGeneratingSticker && !isSaving
    }
}

private struct AchievementDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var stickerStore: AchievementStickerStore
    let achievement: CustomAchievement
    @State private var note = ""

    var body: some View {
        NavigationStack {
            ZStack {
                DesignToken.bg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        stickerHero
                        detailCard
                    }
                    .padding(20)
                }
            }
            .navigationTitle("成就详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
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
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(DesignToken.primaryGradient)
                    .frame(width: 220, height: 220)
                    .opacity(0.22)
                if let image = stickerStore.stickerImage(for: achievement) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 210, height: 210)
                }
            }

            Text(achievement.name)
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(DesignToken.textPrimary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .background(RoundedRectangle(cornerRadius: 30, style: .continuous).fill(.white.opacity(0.92)))
    }

    private var detailCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            detailRow(title: "完成时间", value: achievement.completedAt.formatted(date: .abbreviated, time: .shortened), icon: "calendar.badge.checkmark")
            detailRow(title: "描述", value: achievement.description, icon: "text.quote")

            VStack(alignment: .leading, spacing: 8) {
                Label("备注", systemImage: "square.and.pencil")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(DesignToken.textPrimary)
                TextField("写下这一刻的故事", text: $note, axis: .vertical)
                    .lineLimit(4, reservesSpace: true)
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(DesignToken.iconSoftBG))
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(.white))
    }

    private func detailRow(title: String, value: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(DesignToken.primary)
                .frame(width: 34, height: 34)
                .background(Circle().fill(DesignToken.iconSoftBG))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(DesignToken.textSecondary)
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DesignToken.textPrimary)
            }
            Spacer()
        }
    }
}

private struct CameraPicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    @Binding var image: UIImage?

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraPicker

        init(parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.image = info[.originalImage] as? UIImage
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

struct DiaperSheet: View {
    @EnvironmentObject private var activityStore: ActivityStore
    @Binding var isPresented: Bool

    @State private var selectedType = "湿尿布"
    @State private var note = ""
    @State private var recordedAt = Date()

    private let types = ["湿尿布", "便便", "混合"]

    var body: some View {
        NavigationStack {
            recordSheetContent(
                title: "记录尿布",
                subtitle: "选择尿布状态，保存后会加入今日记录",
                icon: "drop.fill",
                accent: Color(hex: "#67C587")
            ) {
                VStack(spacing: 16) {
                    Picker("尿布状态", selection: $selectedType) {
                        ForEach(types, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)

                    DatePicker("时间", selection: $recordedAt, displayedComponents: [.hourAndMinute])
                        .font(.headline.weight(.semibold))

                    notesField

                    saveButton(title: "保存尿布记录", color: Color(hex: "#67C587")) {
                        activityStore.recordDiaper(type: selectedType, note: note, recordedAt: recordedAt)
                        isPresented = false
                    }
                }
            }
            .navigationTitle("记录尿布")
            .navigationBarTitleDisplayMode(.inline)
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
}

struct SleepSheet: View {
    @EnvironmentObject private var activityStore: ActivityStore
    @Binding var isPresented: Bool

    @State private var startTime = Date()
    @State private var duration = 30.0
    @State private var note = ""

    var body: some View {
        NavigationStack {
            recordSheetContent(
                title: "记录睡眠",
                subtitle: "记录宝宝本次睡眠时长和时间",
                icon: "moon.fill",
                accent: Color(hex: "#6DA5F2")
            ) {
                VStack(spacing: 16) {
                    DatePicker("开始时间", selection: $startTime, displayedComponents: [.hourAndMinute])
                        .font(.headline.weight(.semibold))

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("睡眠时长", systemImage: "timer")
                                .font(.headline.weight(.bold))
                            Spacer()
                            Text("\(Int(duration)) 分钟")
                                .font(.headline.weight(.heavy))
                        }
                        .foregroundStyle(DesignToken.textPrimary)

                        Slider(value: $duration, in: 5...240, step: 5)
                            .tint(Color(hex: "#6DA5F2"))
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white))

                    notesField

                    saveButton(title: "保存睡眠记录", color: Color(hex: "#6DA5F2")) {
                        activityStore.recordSleep(durationMinutes: Int(duration), note: note, startTime: startTime)
                        isPresented = false
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
    }

    private var notesField: some View {
        TextField("备注：比如入睡状态、醒来原因", text: $note, axis: .vertical)
            .lineLimit(3, reservesSpace: true)
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white))
    }
}

private func recordSheetContent<Content: View>(
    title: String,
    subtitle: String,
    icon: String,
    accent: Color,
    @ViewBuilder content: () -> Content
) -> some View {
    ZStack {
        Color(hex: "#F8F7FB").ignoresSafeArea()
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 14) {
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .background(Circle().fill(accent))

                    VStack(alignment: .leading, spacing: 5) {
                        Text(title)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(DesignToken.textPrimary)
                        Text(subtitle)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(DesignToken.textSecondary)
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(.white))

                content()
            }
            .padding(18)
        }
    }
}

private func saveButton(title: String, color: Color, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Label(title, systemImage: "checkmark.circle.fill")
            .font(.headline.weight(.bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Capsule().fill(color))
    }
    .buttonStyle(ScaleButtonStyle())
}

private func simplePage(icon: String, title: String, subtitle: String) -> some View {
    ZStack {
        DesignToken.bg.ignoresSafeArea()
        VStack(spacing: 18) {
            Image(systemName: icon)
                .font(.system(size: 72, weight: .semibold))
                .foregroundStyle(DesignToken.primary)
            Text(title)
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(DesignToken.textPrimary)
            Text(subtitle)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(DesignToken.textSecondary)
        }
        .padding(40)
        .cardStyle()
        .padding(36)
    }
}
