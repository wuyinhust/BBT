import SwiftUI

private enum TemperamentAnimalPalette {
    static let bunny = DesignToken.easyActivity
    static let fawn = DesignToken.warning
    static let duck = DesignToken.reward
    static let samoyed = DesignToken.easySleep
    static let otter = DesignToken.easyYearning
    static let fennec = DesignToken.easyEat
    static let redPanda = DesignToken.activityDiaper
    static let koala = DesignToken.grayNeutral
    static let sloth = DesignToken.success
    static let chipmunk = DesignToken.error
}

struct OnboardingView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme
    @Environment(BabyProfileStore.self) private var profileStore
    @EnvironmentObject private var companionStore: CompanionStore
    @EnvironmentObject private var temperamentStore: TemperamentProfileStore
    @EnvironmentObject private var membershipStore: PlusMembershipStore
    @AppStorage(RecordHomeMode.storageKey) private var recordHomeModeRaw = RecordHomeMode.basic.rawValue

    let onComplete: () -> Void
    private let prefillFromProfile: Bool

    @State private var stage: OnboardingStage
    @State private var questionIndex = 0
    @State private var babyName = ""
    @State private var birthDate = Calendar.current.date(byAdding: .month, value: -2, to: Date()) ?? Date()
    @State private var gender: BabyGender = .boy
    @State private var answers: [TemperamentDimension: Double] = TemperamentQuestion.all.reduce(into: [:]) { answers, question in
        answers[question.dimension] = 3
    }
    @State private var answeredDimensions: Set<TemperamentDimension> = []
    @State private var result: TemperamentAnimal?
    @State private var didHydrateFromProfile = false
    @State private var transitionDirection = 1
    @State private var selectionFeedbackTrigger = 0
    @State private var isBuddyFloating = false
    @State private var showPlusMembership = false

    init(prefillFromProfile: Bool = false, onComplete: @escaping () -> Void) {
        self.prefillFromProfile = prefillFromProfile
        self.onComplete = onComplete
        #if DEBUG
        let launchesModePage = ProcessInfo.processInfo.arguments.contains("-BBUIOnboardingModePage")
        _stage = State(initialValue: launchesModePage ? .activation : (prefillFromProfile ? .profile : .hook))
        #else
        _stage = State(initialValue: prefillFromProfile ? .profile : .hook)
        #endif
    }

    var body: some View {
        ZStack {
            onboardingBackground

            VStack(spacing: 0) {
                topBar

                Group {
                    switch stage {
                    case .hook:
                        hookPage
                    case .profile:
                        profilePage
                    case .quiz:
                        quizPage
                    case .result:
                        resultPage
                    case .value:
                        valuePage
                    case .activation:
                        activationPage
                    case .offer:
                        offerPage
                    }
                }
                .id(pageIdentity)
                .transition(
                    .asymmetric(
                        insertion: .move(edge: transitionDirection > 0 ? .trailing : .leading).combined(with: .opacity),
                        removal: .move(edge: transitionDirection > 0 ? .leading : .trailing).combined(with: .opacity)
                    )
                )
            }
        }
        .sensoryFeedback(.selection, trigger: selectionFeedbackTrigger) { _, _ in
            AppHapticPreference.isEnabled
        }
        .accessibilityIdentifier("onboarding.screen")
        .onAppear {
            hydrateFromProfileIfNeeded()
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                isBuddyFloating = true
            }
        }
        .sheet(isPresented: $showPlusMembership) {
            PlusMembershipView()
        }
    }

    private var pageIdentity: String {
        "\(stage.rawValue)-\(stage == .quiz ? questionIndex : 0)"
    }

    private var canContinueProfile: Bool {
        !babyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var currentQuestion: TemperamentQuestion {
        guard !TemperamentQuestion.all.isEmpty else {
            return TemperamentQuestion(id: "fallback", dimension: .activityLevel, text: "宝宝平时醒着时，通常动作很多、很爱动。")
        }
        let safeIndex = TemperamentQuestion.all.indices.contains(questionIndex) ? questionIndex : 0
        return TemperamentQuestion.all[safeIndex]
    }

    private var matchedAnimal: TemperamentAnimal {
        result ?? TemperamentEngine.match(scores: answers)
    }

    private var matchedCompanion: BabyCompanion {
        BabyCompanion.companion(for: matchedAnimal.id)
    }

    private var progressValue: CGFloat {
        if prefillFromProfile {
            switch stage {
            case .profile: return 0.18
            case .quiz: return 0.18 + 0.62 * CGFloat(questionIndex + 1) / CGFloat(TemperamentQuestion.all.count)
            case .result: return 1
            default: return 0
            }
        }

        switch stage {
        case .hook: return 0.06
        case .profile: return 0.18
        case .quiz: return 0.18 + 0.34 * CGFloat(questionIndex + 1) / CGFloat(TemperamentQuestion.all.count)
        case .result: return 0.62
        case .value: return 0.75
        case .activation: return 0.88
        case .offer: return 1
        }
    }

    private var topBar: some View {
        HStack(spacing: 14) {
            if stage == .hook {
                Color.clear.frame(width: 44, height: 44)
            } else {
                Button(action: handleBack) {
                    Image(systemName: prefillFromProfile && stage == .profile ? "xmark" : "chevron.left")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(DesignToken.textPrimary.opacity(0.82))
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(.ultraThinMaterial))
                        .overlay(Circle().stroke(DesignToken.glassStroke.opacity(0.78), lineWidth: 1))
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(prefillFromProfile && stage == .profile ? "关闭" : "返回")
            }

            GeometryReader { proxy in
                Capsule(style: .continuous)
                    .fill(DesignToken.surfaceRaised.opacity(0.72))
                    .overlay(alignment: .leading) {
                        Capsule(style: .continuous)
                            .fill(DesignToken.primaryGradient)
                            .frame(width: max(12, proxy.size.width * progressValue))
                    }
                    .overlay(Capsule().stroke(DesignToken.glassStroke.opacity(0.7), lineWidth: 0.8))
            }
            .frame(height: 7)

            Text(stage == .quiz ? "\(questionIndex + 1)/\(TemperamentQuestion.all.count)" : "BBBuddy")
                .font(BBBFont.font(size: 12, weight: .bold))
                .foregroundStyle(DesignToken.textSecondary)
                .frame(width: 58, alignment: .trailing)
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var onboardingBackground: some View {
        ZStack(alignment: .top) {
            DesignToken.canvas

            ZStack {
                LinearGradient(
                    colors: onboardingBackgroundColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(DesignToken.primary.opacity(colorScheme == .dark ? 0.07 : 0.25))
                    .frame(width: 300, height: 300)
                    .blur(radius: 70)
                    .offset(x: 140, y: -80)

                Circle()
                    .fill(DesignToken.accentBlue.opacity(colorScheme == .dark ? 0.055 : 0.30))
                    .frame(width: 330, height: 330)
                    .blur(radius: 80)
                    .offset(x: -130, y: 150)

                Circle()
                    .fill(DesignToken.reward.opacity(colorScheme == .dark ? 0.045 : 0.22))
                    .frame(width: 250, height: 250)
                    .blur(radius: 72)
                    .offset(x: 30, y: -190)

                Rectangle().fill(.ultraThinMaterial).opacity(0.14)

                LinearGradient(
                    colors: [DesignToken.canvas.opacity(0), DesignToken.canvas.opacity(0.28), DesignToken.canvas],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .frame(height: 500)
            .clipped()
        }
        .ignoresSafeArea()
    }

    private var onboardingBackgroundColors: [Color] {
        if colorScheme == .dark {
            return [DesignToken.canvas, DesignToken.surface, DesignToken.surfaceSoft.opacity(0.82)]
        }
        return [DesignToken.easyEatSoft, DesignToken.easySleepSoft, DesignToken.activityDiaperSoft]
    }

    private var hookPage: some View {
        pageShell {
            VStack(spacing: 26) {
                VStack(spacing: 12) {
                    Text("少一点猜测，\n多一点看懂")
                        .font(BBBFont.font(size: 36, weight: .heavy))
                        .foregroundStyle(DesignToken.textPrimary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)

                    Text("BBBuddy 把零碎照护变成宝宝的节奏，\n再用一位 Buddy 陪你们一路成长。")
                        .font(BBBFont.font(size: 15, weight: .semibold))
                        .foregroundStyle(DesignToken.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .padding(.top, 18)

                buddyConstellation

                HStack(spacing: 8) {
                    valuePill("快速记录", color: DesignToken.easyEat)
                    valuePill("看见节奏", color: DesignToken.easySleep)
                    valuePill("收藏成长", color: DesignToken.easyYearning)
                }
            }
        } footer: {
            primaryActionButton("认识我的宝宝") {
                go(to: .profile)
            }
        }
    }

    private var buddyConstellation: some View {
        ZStack {
            Circle()
                .fill(DesignToken.surfaceRaised.opacity(0.72))
                .frame(width: 270, height: 270)
                .blur(radius: 2)

            Circle()
                .stroke(DesignToken.glassStroke.opacity(0.82), lineWidth: 1)
                .frame(width: 234, height: 234)

            if BabyCompanion.all.count >= 6 {
                CompanionAnimalFigure(companion: BabyCompanion.all[1], isUnlocked: true, size: 128)
                    .rotationEffect(.degrees(-7))
                    .offset(x: -92, y: 26)
                    .opacity(0.82)

                CompanionAnimalFigure(companion: BabyCompanion.all[2], isUnlocked: true, size: 176)
                    .shadow(color: DesignToken.primary.opacity(0.18), radius: 20, y: 12)
                    .offset(y: isBuddyFloating ? -8 : 3)
                    .zIndex(2)

                CompanionAnimalFigure(companion: BabyCompanion.all[5], isUnlocked: true, size: 126)
                    .rotationEffect(.degrees(7))
                    .offset(x: 94, y: 30)
                    .opacity(0.82)
            }
        }
        .frame(height: 300)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("BBBuddy 动物伙伴")
    }

    private var profilePage: some View {
        pageShell {
            VStack(alignment: .leading, spacing: 24) {
                pageHeader(
                    eyebrow: "先认识一下",
                    title: "怎么称呼宝宝？",
                    subtitle: "出生日期会用来定位月龄内容，其他资料以后都能修改。"
                )

                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        fieldLabel("宝宝名字")
                        TextField("输入小名或名字", text: $babyName)
                            .textInputAutocapitalization(.never)
                            .font(BBBFont.font(size: 18, weight: .semibold))
                            .foregroundStyle(DesignToken.textPrimary)
                            .padding(.horizontal, 16)
                            .frame(height: 56)
                            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(DesignToken.surfaceRaised.opacity(0.88)))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        fieldLabel("出生日期")
                        DatePicker("出生日期", selection: $birthDate, in: ...Date(), displayedComponents: .date)
                            .labelsHidden()
                            .datePickerStyle(.compact)
                            .font(BBBFont.font(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .frame(height: 56)
                            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(DesignToken.surfaceRaised.opacity(0.88)))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        fieldLabel("宝宝")
                        Picker("宝宝", selection: $gender) {
                            ForEach(BabyGender.allCases) { item in
                                Text(genderTitle(item)).tag(item)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                .padding(18)
                .background(onboardingGlassCard(cornerRadius: 28))
            }
        } footer: {
            primaryActionButton("看看宝宝的气质", disabled: !canContinueProfile) {
                saveProfile()
                go(to: .quiz)
            }
        }
    }

    private var quizPage: some View {
        pageShell {
            VStack(alignment: .leading, spacing: 22) {
                pageHeader(
                    eyebrow: "凭第一感觉就好",
                    title: "这句话像 \(displayName) 吗？",
                    subtitle: "没有标准答案，选择宝宝大多数时候的样子。"
                )

                VStack(alignment: .leading, spacing: 22) {
                    Text(currentQuestion.text.localized)
                        .font(BBBFont.font(size: 24, weight: .bold))
                        .foregroundStyle(DesignToken.textPrimary)
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(spacing: 10) {
                        ForEach(1...5, id: \.self) { score in
                            scoreOption(score, for: currentQuestion.dimension)
                        }
                    }
                }
                .padding(20)
                .background(onboardingGlassCard(cornerRadius: 30))
            }
        } footer: {
            primaryActionButton(
                questionIndex == TemperamentQuestion.all.count - 1 ? "找到我的 Buddy" : "下一题",
                disabled: !answeredDimensions.contains(currentQuestion.dimension)
            ) {
                advanceQuiz()
            }
        }
    }

    private var resultPage: some View {
        pageShell {
            VStack(spacing: 20) {
                pageHeader(
                    eyebrow: "匹配完成",
                    title: "\(displayName) 的 Buddy 来了",
                    subtitle: "这是一份当下的气质倾向，不是给宝宝贴上的固定标签。",
                    alignment: .center
                )

                resultCard(companion: matchedCompanion, animal: matchedAnimal)

                VStack(spacing: 12) {
                    HStack(spacing: -8) {
                        ForEach(Array(BabyCompanion.all.dropFirst(10).prefix(5))) { companion in
                            CompanionAnimalFigure(companion: companion, isUnlocked: false, size: 54)
                                .frame(width: 46, height: 54)
                                .background(Circle().fill(DesignToken.surfaceRaised.opacity(0.84)))
                                .clipShape(Circle())
                                .overlay(Circle().stroke(DesignToken.glassStroke.opacity(0.9), lineWidth: 1))
                        }
                    }

                    Text("还有 \(max(BabyCompanion.all.count - 1, 0)) 位 Buddy，\n会在一次次照护与成长里前来相遇。")
                        .font(BBBFont.font(size: 13, weight: .semibold))
                        .foregroundStyle(DesignToken.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
                .padding(.top, 2)
            }
        } footer: {
            VStack(spacing: 8) {
                primaryActionButton(prefillFromProfile ? "保存这位 Buddy" : "领取 \(matchedCompanion.localizedName)") {
                    acceptMatchedBuddy()
                }

                Button("重新测一次") {
                    questionIndex = 0
                    go(to: .quiz, direction: -1)
                }
                .font(BBBFont.font(size: 13, weight: .semibold))
                .foregroundStyle(DesignToken.textSecondary)
                .frame(minHeight: DesignToken.minimumTapSize)
            }
        }
    }

    private var valuePage: some View {
        pageShell {
            VStack(alignment: .leading, spacing: 22) {
                pageHeader(
                    eyebrow: "不是多记一份表格",
                    title: "记录一次，少猜一点",
                    subtitle: "BBBuddy 会把当天的照护整理成看得懂的节奏，也把成长中的第一次留在正确的月龄。"
                )

                VStack(spacing: 14) {
                    trustFeatureCard(
                        title: "EASY 照护节奏",
                        subtitle: "把吃、活动、睡眠串成顺序，帮助你回看宝宝自己的规律。",
                        badge: "灵活，不强迫作息"
                    ) {
                        HStack(spacing: 8) {
                            rhythmToken("E", title: "吃", color: DesignToken.easyEat)
                            rhythmToken("A", title: "玩", color: DesignToken.easyActivity)
                            rhythmToken("S", title: "睡", color: DesignToken.easySleep)
                            rhythmToken("Y", title: "状态", color: DesignToken.easyYearning)
                        }
                    }

                    trustFeatureCard(
                        title: "月龄成长里程碑",
                        subtitle: "沿着月龄保存值得纪念的变化，也知道下一阶段可以观察什么。",
                        badge: "参考 CDC / AAP 观察框架"
                    ) {
                        HStack(spacing: 12) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(DesignToken.primary)
                                .frame(width: 42, height: 42)
                                .background(Circle().fill(DesignToken.primary.opacity(0.13)))

                            VStack(alignment: .leading, spacing: 3) {
                                Text("这个月的新变化")
                                    .font(BBBFont.font(size: 14, weight: .bold))
                                    .foregroundStyle(DesignToken.textPrimary)
                                Text("观察 · 记录 · 与专业人士沟通")
                                    .font(BBBFont.font(size: 11, weight: .semibold))
                                    .foregroundStyle(DesignToken.textSecondary)
                            }
                            Spacer()
                        }
                    }
                }

                Text("里程碑用于日常观察与记录，不替代标准化发育筛查或医疗建议。")
                    .font(BBBFont.font(size: 11, weight: .medium))
                    .foregroundStyle(DesignToken.textSecondary.opacity(0.86))
                    .lineSpacing(3)
                    .padding(.horizontal, 4)
            }
        } footer: {
            primaryActionButton("选择我的记录方式") {
                go(to: .activation)
            }
        }
    }

    private var activationPage: some View {
        pageShell {
            VStack(alignment: .leading, spacing: 22) {
                pageHeader(
                    eyebrow: "马上开始",
                    title: "你想怎样看见今天？",
                    subtitle: "两种模式共用同一份记录，之后可以随时切换。"
                )

                VStack(spacing: 12) {
                    ForEach(activationModeOrder, id: \.self) { mode in
                        homeModeOption(mode)
                    }
                }
            }
        } footer: {
            primaryActionButton(recordHomeModeRaw == RecordHomeMode.easy.rawValue ? "使用 EASY 开始" : "使用基础记录开始") {
                go(to: .offer)
            }
        }
    }

    private var activationModeOrder: [RecordHomeMode] {
        guard dynamicTypeSize.isAccessibilitySize,
              let selectedMode = RecordHomeMode(rawValue: recordHomeModeRaw) else {
            return [.easy, .basic]
        }
        return selectedMode == .easy ? [.easy, .basic] : [.basic, .easy]
    }

    private var offerPage: some View {
        pageShell {
            VStack(spacing: 22) {
                ZStack {
                    Circle()
                        .fill(DesignToken.primary.opacity(0.14))
                        .frame(width: 180, height: 180)
                    CompanionAnimalFigure(companion: matchedCompanion, isUnlocked: true, size: 165)
                        .offset(y: isBuddyFloating ? -6 : 3)
                }
                .frame(height: 190)

                pageHeader(
                    eyebrow: membershipStore.isPlusActive ? "PLUS 已准备好" : "让陪伴多一点灵感",
                    title: membershipStore.isPlusActive ? "一起开始吧" : "需要更多时，再升级",
                    subtitle: membershipStore.isPlusActive
                        ? "\(matchedCompanion.localizedName) 和宝宝的首页都已经准备好了。"
                        : "免费版可以直接开始。Plus 当前提供每日奖励加速与专属场景。",
                    alignment: .center
                )

                if !membershipStore.isPlusActive {
                    VStack(spacing: 0) {
                        offerBenefit("sparkles", "每天多得 3 BB Bucks")
                        offerBenefit("sun.max.fill", "3 款 Plus 专属场景光效")
                    }
                    .padding(.horizontal, 16)
                    .background(onboardingGlassCard(cornerRadius: 26))
                }
            }
        } footer: {
            VStack(spacing: 8) {
                primaryActionButton(membershipStore.isPlusActive ? "进入 BBBuddy" : "查看 Plus 方案") {
                    if membershipStore.isPlusActive {
                        onComplete()
                    } else {
                        showPlusMembership = true
                    }
                }

                if !membershipStore.isPlusActive {
                    Button("先使用免费版") {
                        onComplete()
                    }
                    .font(BBBFont.font(size: 13, weight: .semibold))
                    .foregroundStyle(DesignToken.textSecondary)
                    .frame(minHeight: DesignToken.minimumTapSize)
                }
            }
        }
    }

    private func pageShell<Content: View, Footer: View>(
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) -> some View {
        ScrollView(showsIndicators: false) {
            content()
                .padding(.horizontal, DesignToken.screenHorizontalPadding)
                .padding(.top, 18)
                .padding(.bottom, 28)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            footer()
                .padding(.horizontal, DesignToken.screenHorizontalPadding)
                .padding(.top, 12)
                .padding(.bottom, 10)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                    colors: [DesignToken.canvas.opacity(0), DesignToken.canvas.opacity(0.94), DesignToken.canvas],
                        startPoint: .top,
                        endPoint: .center
                    )
                    .ignoresSafeArea()
                )
        }
    }

    private func pageHeader(
        eyebrow: String,
        title: String,
        subtitle: String,
        alignment: TextAlignment = .leading
    ) -> some View {
        VStack(alignment: alignment == .center ? .center : .leading, spacing: 9) {
            Text(eyebrow.localized.uppercased())
                .font(BBBFont.scaledFont(size: 11, weight: .bold, relativeTo: .caption1, maximumPointSize: 17))
                .tracking(1.2)
                .foregroundStyle(DesignToken.primary)
            Text(title.localized)
                .font(BBBFont.scaledFont(size: 28, weight: .bold, relativeTo: .largeTitle, maximumPointSize: 42))
                .foregroundStyle(DesignToken.textPrimary)
                .multilineTextAlignment(alignment)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
            Text(subtitle.localized)
                .font(BBBFont.scaledFont(size: 14, weight: .semibold, relativeTo: .body, maximumPointSize: 23))
                .foregroundStyle(DesignToken.textSecondary)
                .multilineTextAlignment(alignment)
                .lineSpacing(4)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: alignment == .center ? .center : .leading)
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title.localized)
            .font(BBBFont.font(size: 12, weight: .bold))
            .foregroundStyle(DesignToken.textSecondary)
    }

    private func valuePill(_ title: String, color: Color) -> some View {
        Text(title.localized)
            .font(BBBFont.font(size: 11, weight: .bold))
            .foregroundStyle(DesignToken.textPrimary.opacity(0.82))
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(Capsule().fill(color.opacity(0.12)))
            .overlay(Capsule().stroke(DesignToken.glassStroke.opacity(0.82), lineWidth: 0.8))
    }

    private func scoreOption(_ score: Int, for dimension: TemperamentDimension) -> some View {
        let isSelected = currentScore(for: dimension) == Double(score) && answeredDimensions.contains(dimension)

        return Button {
            answers[dimension] = Double(score)
            answeredDimensions.insert(dimension)
            selectionFeedbackTrigger += 1
        } label: {
            HStack(spacing: 12) {
                Text("\(score)")
                    .font(BBBFont.font(size: 13, weight: .bold))
                    .foregroundStyle(isSelected ? DesignToken.onPrimary : DesignToken.textSecondary)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(isSelected ? DesignToken.primary : DesignToken.surfaceRaised.opacity(0.82)))

                Text(scoreLabel(score).localized)
                    .font(BBBFont.scaledFont(size: 15, weight: isSelected ? .bold : .semibold, relativeTo: .body, maximumPointSize: 24))
                    .foregroundStyle(DesignToken.textPrimary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(DesignToken.primary)
                }
            }
            .padding(.horizontal, 13)
            .frame(minHeight: 48)
            .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 6 : 0)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? DesignToken.primary.opacity(0.12) : DesignToken.surfaceRaised.opacity(0.76))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? DesignToken.primary.opacity(0.52) : DesignToken.glassStroke.opacity(0.62), lineWidth: isSelected ? 1.3 : 0.8)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func scoreLabel(_ score: Int) -> String {
        switch score {
        case 1: return "很不像"
        case 2: return "不太像"
        case 3: return "说不准"
        case 4: return "比较像"
        default: return "很像"
        }
    }

    private func resultCard(companion: BabyCompanion, animal: TemperamentAnimal) -> some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(animal.accent.opacity(0.15))
                    .frame(width: 220, height: 220)
                Circle()
                    .stroke(DesignToken.glassStroke.opacity(0.86), lineWidth: 1.2)
                    .frame(width: 188, height: 188)
                CompanionAnimalFigure(companion: companion, isUnlocked: true, size: 200)
                    .shadow(color: animal.accent.opacity(0.18), radius: 20, y: 10)
                    .offset(y: isBuddyFloating ? -5 : 3)
            }
            .frame(height: 224)

            VStack(spacing: 5) {
                Text("\(companion.catalogNumber) · \(companion.localizedName)")
                    .font(BBBFont.font(size: 22, weight: .heavy))
                    .foregroundStyle(DesignToken.textPrimary)
                Text(animal.slogan.localized)
                    .font(BBBFont.font(size: 14, weight: .bold))
                    .foregroundStyle(animal.accent)
            }

            Text(animal.personality.localized)
                .font(BBBFont.font(size: 14, weight: .semibold))
                .foregroundStyle(DesignToken.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            Text(companion.localizedTemperamentLabel)
                .font(BBBFont.font(size: 11, weight: .bold))
                .foregroundStyle(companion.temperamentStyle.text)
                .padding(.horizontal, 12)
                .frame(height: 28)
                .background(Capsule().fill(companion.temperamentStyle.tint.opacity(0.34)))
        }
        .padding(20)
        .background(onboardingGlassCard(cornerRadius: 32))
    }

    private func trustFeatureCard<Preview: View>(
        title: String,
        subtitle: String,
        badge: String,
        @ViewBuilder preview: () -> Preview
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(title.localized)
                    .font(BBBFont.font(size: 18, weight: .bold))
                    .foregroundStyle(DesignToken.textPrimary)
                Spacer(minLength: 8)
                Text(badge.localized)
                    .font(BBBFont.font(size: 9, weight: .bold))
                    .foregroundStyle(DesignToken.primary)
                    .padding(.horizontal, 8)
                    .frame(height: 23)
                    .background(Capsule().fill(DesignToken.primary.opacity(0.10)))
            }

            Text(subtitle.localized)
                .font(BBBFont.font(size: 13, weight: .semibold))
                .foregroundStyle(DesignToken.textSecondary)
                .lineSpacing(3)

            preview()
        }
        .padding(18)
        .background(onboardingGlassCard(cornerRadius: 26))
    }

    private func rhythmToken(_ letter: String, title: String, color: Color) -> some View {
        VStack(spacing: 5) {
            Text(letter)
                .font(BBBFont.font(size: 14, weight: .heavy))
                .foregroundStyle(DesignToken.onPrimary)
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(color))
            Text(title.localized)
                .font(BBBFont.font(size: 10, weight: .bold))
                .foregroundStyle(DesignToken.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func homeModeOption(_ mode: RecordHomeMode) -> some View {
        let isSelected = recordHomeModeRaw == mode.rawValue

        return Button {
            recordHomeModeRaw = mode.rawValue
            selectionFeedbackTrigger += 1
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label(
                        mode.shortTitle,
                        systemImage: mode == .easy ? AppSemanticIcon.easyMode : AppSemanticIcon.basicMode
                    )
                        .font(BBBFont.scaledFont(size: 13, weight: .heavy, relativeTo: .headline, maximumPointSize: 20))
                        .foregroundStyle(isSelected ? DesignToken.onPrimary : DesignToken.primary)
                        .padding(.horizontal, 11)
                        .frame(minHeight: 28)
                        .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 4 : 0)
                        .background(Capsule().fill(isSelected ? DesignToken.primary : DesignToken.primary.opacity(0.10)))

                    if mode == .easy {
                        Label("推荐", systemImage: AppSemanticIcon.recommended)
                            .font(BBBFont.scaledFont(size: 10, weight: .bold, relativeTo: .caption2, maximumPointSize: 15))
                            .foregroundStyle(DesignToken.easyYearning)
                    }

                    Spacer()

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(isSelected ? DesignToken.primary : DesignToken.textSecondary.opacity(0.34))
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(mode == .easy ? "跟着宝宝的节奏记录" : "按单项快速记录")
                        .font(BBBFont.scaledFont(size: 18, weight: .bold, relativeTo: .title3, maximumPointSize: 28))
                        .foregroundStyle(DesignToken.textPrimary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(mode == .easy ? "吃、玩、睡自动串成今天的照护循环。" : "喂养、尿布、睡眠保持熟悉的时间线。")
                        .font(BBBFont.scaledFont(size: 13, weight: .semibold, relativeTo: .subheadline, maximumPointSize: 21))
                        .foregroundStyle(DesignToken.textSecondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if mode == .easy {
                    HStack(spacing: 6) {
                        ForEach(Array(zip(["E", "A", "S", "Y"], [DesignToken.easyEat, DesignToken.easyActivity, DesignToken.easySleep, DesignToken.easyYearning])), id: \.0) { item in
                            Text(item.0)
                                .font(BBBFont.font(size: 11, weight: .heavy))
                                .foregroundStyle(DesignToken.onPrimary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 30)
                                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(item.1))
                        }
                    }
                }
            }
            .padding(18)
            .background(onboardingGlassCard(cornerRadius: 26))
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(isSelected ? DesignToken.primary.opacity(0.56) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func offerBenefit(_ icon: String, _ title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(DesignToken.primary)
                .frame(width: 34, height: 34)
                .background(Circle().fill(DesignToken.primary.opacity(0.11)))
            Text(title.localized)
                .font(BBBFont.font(size: 14, weight: .bold))
                .foregroundStyle(DesignToken.textPrimary)
            Spacer()
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(DesignToken.easyYearning)
        }
        .frame(height: 54)
    }

    private func primaryActionButton(_ title: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    Text(title.localized)
                        .lineLimit(1)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .bold))
                }

                HStack(spacing: 8) {
                    Text(compactActionTitle(for: title).localized)
                        .lineLimit(1)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .bold))
                }

                Image(systemName: "arrow.right")
                    .font(.system(size: 17, weight: .bold))
                    .accessibilityHidden(true)
            }
            .font(BBBFont.scaledFont(size: 16, weight: .bold, relativeTo: .headline, maximumPointSize: 25))
            .foregroundStyle(DesignToken.onPrimary)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 54)
            .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 6 : 0)
            .background(Capsule(style: .continuous).fill(DesignToken.primaryGradient))
            .shadow(color: DesignToken.primary.opacity(disabled ? 0 : 0.22), radius: 16, y: 8)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(disabled)
        .opacity(disabled ? 0.42 : 1)
        .accessibilityLabel(title.localized)
    }

    private func compactActionTitle(for title: String) -> String {
        switch title {
        case "找到我的 Buddy": return "找 Buddy"
        case "使用基础记录开始": return "使用基础记录"
        case "保存这位 Buddy": return "保存 Buddy"
        case "查看 Plus 方案": return "Plus"
        default: return title
        }
    }

    private func onboardingGlassCard(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(DesignToken.surfaceRaised.opacity(0.82))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(DesignToken.glassStroke.opacity(0.82), lineWidth: 1)
            )
            .shadow(color: DesignToken.shadowColor.opacity(0.07), radius: 18, y: 8)
    }

    private func advanceQuiz() {
        guard answeredDimensions.contains(currentQuestion.dimension) else { return }

        if questionIndex < TemperamentQuestion.all.count - 1 {
            transitionDirection = 1
            withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
                questionIndex += 1
            }
        } else {
            result = TemperamentEngine.match(scores: answers)
            go(to: .result)
        }
    }

    private func acceptMatchedBuddy() {
        let animal = matchedAnimal
        let companion = BabyCompanion.companion(for: animal.id)

        saveProfile()
        temperamentStore.update(
            BabyTemperamentResult(
                animalID: companion.id,
                type: animal.type,
                scores: answers,
                completedAt: Date()
            )
        )
        companionStore.selectedID = companion.id

        if prefillFromProfile {
            onComplete()
        } else {
            go(to: .value)
        }
    }

    private func go(to newStage: OnboardingStage, direction: Int = 1) {
        transitionDirection = direction
        withAnimation(.spring(response: 0.36, dampingFraction: 0.88)) {
            stage = newStage
        }
    }

    private func handleBack() {
        if prefillFromProfile && stage == .profile {
            onComplete()
            return
        }

        if stage == .quiz, questionIndex > 0 {
            transitionDirection = -1
            withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
                questionIndex -= 1
            }
            return
        }

        switch stage {
        case .hook:
            break
        case .profile:
            go(to: .hook, direction: -1)
        case .quiz:
            go(to: .profile, direction: -1)
        case .result:
            questionIndex = TemperamentQuestion.all.count - 1
            go(to: .quiz, direction: -1)
        case .value:
            go(to: .result, direction: -1)
        case .activation:
            go(to: .value, direction: -1)
        case .offer:
            go(to: .activation, direction: -1)
        }
    }

    private var displayName: String {
        let trimmed = babyName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "宝宝" : trimmed
    }

    private func genderTitle(_ gender: BabyGender) -> String {
        switch gender {
        case .boy: return "男宝".localized
        case .girl: return "女宝".localized
        }
    }

    private func currentScore(for dimension: TemperamentDimension) -> Double {
        answers[dimension] ?? 3
    }

    private func hydrateFromProfileIfNeeded() {
        guard prefillFromProfile, !didHydrateFromProfile else { return }

        let profile = profileStore.currentProfile
        babyName = profile.name
        birthDate = min(profile.birthDate, Date())
        gender = profile.gender

        if let savedResult = temperamentStore.result {
            var hydratedAnswers = answers
            savedResult.scores.forEach { dimension, score in
                hydratedAnswers[dimension] = score
            }
            answers = hydratedAnswers
            answeredDimensions = Set(savedResult.scores.keys)
            result = TemperamentEngine.animal(for: savedResult.animalID) ?? TemperamentEngine.match(scores: hydratedAnswers)
        }

        didHydrateFromProfile = true
    }

    private func saveProfile() {
        let trimmedName = babyName.trimmingCharacters(in: .whitespacesAndNewlines)

        if prefillFromProfile {
            let currentProfile = profileStore.currentProfile
            profileStore.create(
                name: trimmedName,
                gender: gender,
                birthDate: birthDate,
                avatarEmoji: currentProfile.avatarEmoji,
                avatarImageData: currentProfile.avatarImageData,
                avatarCompanionID: currentProfile.avatarCompanionID,
                avatarVideoFilename: currentProfile.avatarVideoFilename,
                avatarHistory: currentProfile.avatarHistoryItems,
                avatarMotionEnabled: currentProfile.isAvatarMotionEnabled
            )
        } else {
            profileStore.create(name: trimmedName, gender: gender, birthDate: birthDate)
        }
    }
}

private enum OnboardingStage: Int {
    case hook
    case profile
    case quiz
    case result
    case value
    case activation
    case offer
}

private struct TemperamentQuestion: Identifiable {
    let id: String
    let dimension: TemperamentDimension
    let text: String

    static let all: [TemperamentQuestion] = [
        .init(id: "q01", dimension: .activityLevel, text: "宝宝醒着的时候，通常动作很多、很爱动。"),
        .init(id: "q02", dimension: .regularity, text: "宝宝吃奶、睡觉、便便的时间，大多比较有规律。"),
        .init(id: "q03", dimension: .approach, text: "遇到新玩具、新人或新环境时，宝宝通常愿意靠近或尝试。"),
        .init(id: "q04", dimension: .adaptability, text: "生活节奏有变化时，宝宝通常能比较快适应。"),
        .init(id: "q05", dimension: .intensity, text: "宝宝开心、难过或不舒服时，反应通常很强烈。"),
        .init(id: "q06", dimension: .mood, text: "宝宝平时整体看起来比较轻松、爱笑、好相处。"),
        .init(id: "q07", dimension: .attentionPersistence, text: "宝宝对喜欢的事物，通常能持续关注一会儿。"),
        .init(id: "q08", dimension: .distractibility, text: "周围一点动静，就很容易把宝宝的注意力带走。"),
        .init(id: "q09", dimension: .sensorySensitivity, text: "光线、声音、触感这些小变化，宝宝也很容易察觉并有反应。")
    ]
}

private struct TemperamentAnimal: Identifiable {
    let id: String
    let name: String
    let species: String
    let type: TemperamentType
    let emoji: String
    let accent: Color
    let slogan: String
    let characterLine: String
    let personality: String
    let summary: String
    let profile: [TemperamentDimension: Double]
}

private enum TemperamentEngine {
    static func match(scores: [TemperamentDimension: Double]) -> TemperamentAnimal {
        let type = matchType(scores: scores)
        let candidates = animals.filter { $0.type == type }
        let fallback = animals.first ?? TemperamentAnimal(
            id: "fallback",
            name: "小伙伴",
            species: "陪伴动物",
            type: .intermediate,
            emoji: "🐾",
            accent: DesignToken.primary,
            slogan: "先陪你把今天过完",
            characterLine: "慢慢来就好",
            personality: "温柔、稳定、愿意陪伴",
            summary: "无论今天是什么样，都可以从下一步开始。",
            profile: [:]
        )
        return candidates.min { distance(scores, $0.profile) < distance(scores, $1.profile) }
            ?? fallback
    }

    static func animal(for id: String) -> TemperamentAnimal? {
        animals.first { $0.id == id }
    }

    private static func matchType(scores: [TemperamentDimension: Double]) -> TemperamentType {
        let ranked = typeProfiles
            .map { (type: $0.key, distance: distance(scores, $0.value)) }
            .sorted { $0.distance < $1.distance }

        guard let first = ranked.first else { return .intermediate }
        if ranked.count > 1, ranked[1].distance - first.distance < 0.6 {
            return .intermediate
        }
        return first.type
    }

    private static func distance(_ scores: [TemperamentDimension: Double], _ profile: [TemperamentDimension: Double]) -> Double {
        TemperamentDimension.allCases.reduce(0) { total, dimension in
            let diff = (scores[dimension] ?? 3) - (profile[dimension] ?? 3)
            return total + diff * diff
        }
    }

    private static let typeProfiles: [TemperamentType: [TemperamentDimension: Double]] = [
        .easy: [.activityLevel: 3, .regularity: 5, .approach: 4, .adaptability: 5, .intensity: 2, .mood: 5, .attentionPersistence: 3, .distractibility: 3, .sensorySensitivity: 2],
        .intermediate: [.activityLevel: 3, .regularity: 3, .approach: 3, .adaptability: 3, .intensity: 3, .mood: 3, .attentionPersistence: 3, .distractibility: 3, .sensorySensitivity: 3],
        .slowToWarmUp: [.activityLevel: 2, .regularity: 3, .approach: 2, .adaptability: 2, .intensity: 2, .mood: 3, .attentionPersistence: 4, .distractibility: 2, .sensorySensitivity: 4],
        .highSensitivity: [.activityLevel: 4, .regularity: 1, .approach: 2, .adaptability: 1, .intensity: 5, .mood: 2, .attentionPersistence: 3, .distractibility: 4, .sensorySensitivity: 5]
    ]

    private static let animals: [TemperamentAnimal] = [
        .init(id: "bunny_lulu", name: "洛噗", species: "荷兰垂耳兔宝宝", type: .easy, emoji: "🐰", accent: TemperamentAnimalPalette.bunny, slogan: "软软甜甜的小太阳", characterLine: "稳定亲近、反应柔和，是容易被轻轻引导的小甜心。", personality: "洛噗通常节奏稳定，笑容很多，遇到新变化也愿意慢慢试试看。", summary: "大多数时候都比较轻松好带，也很愿意和熟悉的人互动。", profile: [.activityLevel: 3, .regularity: 5, .approach: 4, .adaptability: 5, .intensity: 2, .mood: 5, .attentionPersistence: 3, .distractibility: 3, .sensorySensitivity: 2]),
        .init(id: "fawn_mimi", name: "西咔", species: "梅花鹿宝宝", type: .easy, emoji: "🦌", accent: TemperamentAnimalPalette.fawn, slogan: "温柔安静的小晨光", characterLine: "安静细腻、喜欢熟悉节奏，需要被温柔守护。", personality: "西咔温和细腻，作息比较有节奏，和熟悉的人在一起时特别放松。", summary: "她带着柔和的小步调，让陪伴变得轻轻的、稳稳的。", profile: [.activityLevel: 2, .regularity: 5, .approach: 3, .adaptability: 5, .intensity: 2, .mood: 5, .attentionPersistence: 3, .distractibility: 2, .sensorySensitivity: 3]),
        .init(id: "cal", name: "柯噜", species: "柯尔鸭宝宝", type: .easy, emoji: "🦆", accent: TemperamentAnimalPalette.duck, slogan: "慢半拍的小圆团", characterLine: "圆滚滚、步伐慢半拍，擅长把普通日常变得可爱。", personality: "柯噜总是带着慢半拍的小节奏，回应温和，也很容易被日常里的小事情逗开心。", summary: "像一只把好心情慢慢带来的小鸭子，让照护节奏变得轻松又可爱。", profile: [.activityLevel: 3, .regularity: 5, .approach: 5, .adaptability: 5, .intensity: 3, .mood: 5, .attentionPersistence: 2, .distractibility: 4, .sensorySensitivity: 2]),
        .init(id: "samoyed_momo", name: "摩耶", species: "萨摩耶宝宝", type: .easy, emoji: "🐶", accent: TemperamentAnimalPalette.samoyed, slogan: "笑眯眯的小棉花糖", characterLine: "亲和稳定、适应力强，像随时给人安心的陪伴。", personality: "摩耶亲和、情绪稳定，进入新场景时往往也比较从容。", summary: "稳定、亲近，也很容易让照护者找到节奏。", profile: [.activityLevel: 3, .regularity: 5, .approach: 5, .adaptability: 5, .intensity: 3, .mood: 5, .attentionPersistence: 3, .distractibility: 3, .sensorySensitivity: 2]),
        .init(id: "otter_tangtang", name: "欧缇", species: "亚洲小爪水獭宝宝", type: .intermediate, emoji: "🦦", accent: TemperamentAnimalPalette.otter, slogan: "今天想撒娇，明天想探险", characterLine: "状态丰富、节奏多变，需要弹性和耐心配合。", personality: "欧缇有时轻松好带，有时又特别有自己的节奏，像在不同状态间轻轻切换。", summary: "不是一种固定模板，而是很有层次的小宝宝。", profile: [.activityLevel: 3, .regularity: 3, .approach: 4, .adaptability: 3, .intensity: 3, .mood: 4, .attentionPersistence: 3, .distractibility: 4, .sensorySensitivity: 3]),
        .init(id: "fenny", name: "芬灵", species: "耳廓狐宝宝", type: .intermediate, emoji: "🦊", accent: TemperamentAnimalPalette.fennec, slogan: "机灵又讲感觉的小观察家", characterLine: "敏锐聪明、先观察再靠近，对环境里的细节特别有感觉。", personality: "芬灵对外界很敏锐，有时热情靠近，有时又想先看看再说。", summary: "他有自己的感受节奏，需要被理解，而不是被催着快一点。", profile: [.activityLevel: 4, .regularity: 3, .approach: 3, .adaptability: 3, .intensity: 3, .mood: 3, .attentionPersistence: 3, .distractibility: 3, .sensorySensitivity: 5]),
        .init(id: "redpanda_youyou", name: "瑞迪", species: "小熊猫宝宝", type: .intermediate, emoji: "🐾", accent: TemperamentAnimalPalette.redPanda, slogan: "有主见的小团子", characterLine: "柔软但有主见，喜欢按自己的方式慢慢进入状态。", personality: "瑞迪既有柔软的一面，也有坚持自己步调的一面，时而乖巧，时而很有态度。", summary: "不是不好带，只是更需要按自己的方式慢慢配合。", profile: [.activityLevel: 3, .regularity: 3, .approach: 3, .adaptability: 2, .intensity: 3, .mood: 3, .attentionPersistence: 5, .distractibility: 2, .sensorySensitivity: 3]),
        .init(id: "koala_anan", name: "阿考", species: "昆士兰考拉宝宝", type: .slowToWarmUp, emoji: "🐨", accent: TemperamentAnimalPalette.koala, slogan: "慢热但很认真的小月亮", characterLine: "慢热谨慎、观察力强，安全感足够后会认真靠近。", personality: "阿考不急着靠近世界，更喜欢先观察，等准备好了才慢慢伸出小手。", summary: "不是慢，而是会先把安全感装满。", profile: [.activityLevel: 2, .regularity: 3, .approach: 1, .adaptability: 2, .intensity: 2, .mood: 3, .attentionPersistence: 5, .distractibility: 2, .sensorySensitivity: 5]),
        .init(id: "sloth_nono", name: "霍菲", species: "霍氏树懒宝宝", type: .slowToWarmUp, emoji: "🌿", accent: TemperamentAnimalPalette.sloth, slogan: "慢一点，也一样很可爱", characterLine: "慢节奏、低刺激偏好，需要更从容的过渡时间。", personality: "霍菲喜欢按照自己的小节奏前进，换环境时会先停一停、看一看。", summary: "给他一点缓冲时间，他会用自己的方式慢慢打开。", profile: [.activityLevel: 1, .regularity: 3, .approach: 1, .adaptability: 2, .intensity: 2, .mood: 3, .attentionPersistence: 3, .distractibility: 2, .sensorySensitivity: 3]),
        .init(id: "chipmunk_huohuo", name: "奇比", species: "西伯利亚花栗鼠宝宝", type: .highSensitivity, emoji: "✨", accent: TemperamentAnimalPalette.chipmunk, slogan: "反应快、感觉多的小火花", characterLine: "感受强烈、反应很快，需要更多安抚和提前预告。", personality: "奇比感受丰富、反应迅速，喜欢立刻表达自己的不舒服，也常常需要更多安抚和理解。", summary: "不是故意难带，只是比别人更敏锐、更强烈地感受这个世界。", profile: [.activityLevel: 4, .regularity: 1, .approach: 2, .adaptability: 1, .intensity: 5, .mood: 2, .attentionPersistence: 3, .distractibility: 4, .sensorySensitivity: 5])
    ]
}
