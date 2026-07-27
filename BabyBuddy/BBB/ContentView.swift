import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var feedingDraftStore: FeedingDraftStore
    @EnvironmentObject private var sleepDraftStore: SleepDraftStore
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("has_completed_onboarding") private var hasCompletedOnboarding = false
    @AppStorage(RecordHomeMode.storageKey) private var recordHomeModeRaw = RecordHomeMode.basic.rawValue

    @State private var selectedTab: RootTab = .record
    @State private var showCompanionPicker = false
    @State private var activeRecordSheet: RecordSheet?
    @State private var activeQuickRecordKind: QuickRecordKind?
    @State private var activeQuickRecordCycleID: UUID?
    @State private var activeQuickRecordDate: Date?
    @State private var showQuickAddMenu = false
    @State private var showYearningDetailFromQuickAdd = false
    @State private var subjectiveStatePrompt: SubjectiveStatePromptContext?
    @State private var recordStackResetID = UUID()
    @State private var companionStackResetID = UUID()
    @State private var growthStackResetID = UUID()
    @State private var bottomDockLayoutEpoch = UUID()

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                mainApp
            } else {
                OnboardingView {
                    hasCompletedOnboarding = true
                }
            }
        }
    }

    private var mainApp: some View {
        tabViewContent
    }

    private var recordHomeMode: RecordHomeMode {
        RecordHomeMode(rawValue: recordHomeModeRaw) ?? .basic
    }

    private var recordHomeModeBinding: Binding<RecordHomeMode> {
        Binding {
            recordHomeMode
        } set: { newMode in
            recordHomeModeRaw = newMode.rawValue
        }
    }

    private var tabViewContent: some View {
        tabViewShell
            .onChange(of: selectedTab) { _, _ in
                dismissQuickAddMenu()
            }
            .onChange(of: activeRecordSheet) { _, _ in
                dismissQuickAddMenu()
            }
            .onChange(of: activeQuickRecordKind) { _, _ in
                dismissQuickAddMenu()
            }
            .onChange(of: showCompanionPicker) { _, isPresented in
                if isPresented {
                    dismissQuickAddMenu()
                }
            }
            .onChange(of: showYearningDetailFromQuickAdd) { _, isPresented in
                if isPresented {
                    dismissQuickAddMenu()
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                // A tab shell can briefly receive stale local safe-area geometry after
                // returning from the app switcher. Recreate only this stateless overlay
                // on the next main-loop turn, once the window has final bounds again.
                guard newPhase == .active else { return }
                DispatchQueue.main.async {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        bottomDockLayoutEpoch = UUID()
                    }
                }
            }
            .onChange(of: feedingDraftStore.activeTimingStateID) { _, _ in
                CareRecencyCoordinator.refreshFromSharedStorage(
                    babyAgeMonths: BabyProfileStore.shared.currentProfile.ageMonths
                )
            }
            .onChange(of: sleepDraftStore.activeTimingStateID) { _, _ in
                CareRecencyCoordinator.refreshFromSharedStorage(
                    babyAgeMonths: BabyProfileStore.shared.currentProfile.ageMonths
                )
            }
            .sheet(isPresented: $showCompanionPicker) {
                CompanionPickerView(isPresented: $showCompanionPicker)
            }
            .fullScreenCover(item: $activeRecordSheet) { sheet in
                recordSheetContent(for: sheet)
            }
            .sheet(item: $subjectiveStatePrompt) { context in
                SubjectiveStatePickerSheet(context: context)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
    }

    private var tabViewShell: some View {
        rootTabs
            .toolbar(.hidden, for: .tabBar)
            .background(SystemTabBarHiddenController())
            .tint(DesignToken.primary)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                bottomDockOverlay
                    .id(bottomDockLayoutEpoch)
            }
            .overlay {
                if let activeQuickRecordKind {
                    QuickRecordCardOverlay(
                        initialKind: activeQuickRecordKind,
                        targetCycleID: activeQuickRecordCycleID,
                        recordDate: activeQuickRecordDate,
                        onDismiss: {
                            closeQuickRecordCard()
                        },
                        onCompletedRecord: { context in
                            subjectiveStatePrompt = context
                        }
                    )
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .zIndex(20)
                }
            }
            .animation(.interactiveSpring(response: 0.28, dampingFraction: 0.86), value: activeQuickRecordKind)
    }

    private var rootTabs: some View {
        TabView(selection: $selectedTab) {
            Tab(value: RootTab.record) {
                NavigationStack {
                    RecordHomeView(
                        homeMode: recordHomeModeBinding,
                        showYearningDetailRequest: $showYearningDetailFromQuickAdd,
                        openFeedSheet: { recordDate in
                            openEatQuickRecordCard(recordDate: recordDate)
                        },
                        openActivitySheet: { recordDate in
                            openActivityQuickRecordCard(recordDate: recordDate)
                        },
                        openSleepSheet: { recordDate in
                            openSleepQuickRecordCard(recordDate: recordDate)
                        },
                        openSleepSheetForCycle: { cycleID, recordDate in
                            openQuickRecordCard(.sleep, targetCycleID: cycleID, recordDate: recordDate)
                        },
                        openFeedingTiming: {
                            resumeActiveFeedingTiming()
                        },
                        dismissQuickAddMenu: {
                            dismissQuickAddMenu()
                        },
                        onSubjectiveStatePrompt: { context in
                            subjectiveStatePrompt = context
                        }
                    )
                }
                .id(recordStackResetID)
            } label: {
                rootTabLabel(.record)
            }

            Tab(value: RootTab.companion) {
                NavigationStack {
                    if AppVariant.isAppStoreReview {
                        CompanionSquareView()
                    } else {
                        CompanionLiveView(openFeedSheet: {
                            openEatQuickRecordCard()
                        }, openCompanionPicker: {
                            showCompanionPicker = true
                        })
                    }
                }
                .id(companionStackResetID)
            } label: {
                rootTabLabel(.companion)
            }

            Tab(value: RootTab.growth) {
                NavigationStack {
                    MyPageView(openMetricSheet: { kind in
                        openRecordSheet(kind == .height ? .height : .weight)
                    })
                }
                .id(growthStackResetID)
            } label: {
                rootTabLabel(.growth)
            }
        }
    }

    @ViewBuilder
    private var bottomDockOverlay: some View {
        if shouldShowBottomDock {
            ZStack(alignment: .bottom) {
                BottomDockVisualProtection()
                    .allowsHitTesting(false)

                BottomNavigationDock(
                    selectedTab: $selectedTab,
                    isQuickAddExpanded: $showQuickAddMenu,
                    onTabSelected: handleTabSelection,
                    onEat: { openEatQuickRecordCard() },
                    onPoop: { openActivityQuickRecordCard() },
                    onYearning: {
                        dismissQuickAddMenu()
                        selectedTab = .record
                        subjectiveStatePrompt = .manual()
                    },
                    onSleep: { openSleepQuickRecordCard() }
                )
            }
            .frame(maxWidth: .infinity, alignment: .bottom)
        }
    }

    @ViewBuilder
    private func recordSheetContent(for sheet: RecordSheet) -> some View {
        switch sheet {
        case .diaper:
            DiaperSheet(isPresented: recordSheetBinding(for: .diaper))
                .ignoresSafeArea()
                .toolbar(.hidden, for: .tabBar)
                .presentationBackground(DesignToken.surfaceSoft)
        case .sleep:
            SleepSheet(isPresented: recordSheetBinding(for: .sleep))
                .ignoresSafeArea()
                .toolbar(.hidden, for: .tabBar)
                .presentationBackground(DesignToken.surfaceSoft)
        case .weight:
            GrowthMetricSheet(kind: .weight)
                .toolbar(.hidden, for: .tabBar)
                .presentationBackground(DesignToken.surfaceSoft)
        case .height:
            GrowthMetricSheet(kind: .height)
                .toolbar(.hidden, for: .tabBar)
                .presentationBackground(DesignToken.surfaceSoft)
        }
    }

    private func handleTabSelection(_ tab: RootTab) {
        dismissQuickAddMenu()

        if selectedTab == tab {
            resetNavigationStack(for: tab)
            return
        }

        withAnimation(.interactiveSpring(response: 0.26, dampingFraction: 0.86)) {
            selectedTab = tab
        }
    }

    private func resetNavigationStack(for tab: RootTab) {
        withAnimation(.interactiveSpring(response: 0.26, dampingFraction: 0.86)) {
            switch tab {
            case .record:
                recordStackResetID = UUID()
                showYearningDetailFromQuickAdd = false
            case .companion:
                companionStackResetID = UUID()
                showCompanionPicker = false
            case .growth:
                growthStackResetID = UUID()
            }
        }
    }

    private func openRecordSheet(_ sheet: RecordSheet) {
        dismissQuickAddMenu()
        activeRecordSheet = sheet
    }

    private func resumeActiveFeedingTiming() {
        let kind: QuickRecordKind
        switch feedingDraftStore.type {
        case .breast:
            kind = .nursing
        case .bottle:
            kind = feedingDraftStore.milkType == .expressed ? .expressedBottle : .formulaBottle
        case .solid:
            kind = .solids
        }
        openQuickRecordCard(kind)
    }

    private func openEatQuickRecordCard(recordDate: Date? = nil) {
        openQuickRecordCard(.formulaBottle, recordDate: recordDate)
    }

    private func openActivityQuickRecordCard(recordDate: Date? = nil) {
        openQuickRecordCard(.diaper, recordDate: recordDate)
    }

    private func openSleepQuickRecordCard(recordDate: Date? = nil) {
        openQuickRecordCard(.sleep, recordDate: recordDate)
    }

    private func openQuickRecordCard(_ kind: QuickRecordKind, targetCycleID: UUID? = nil, recordDate: Date? = nil) {
        dismissQuickAddMenu()
        activeQuickRecordCycleID = targetCycleID
        activeQuickRecordDate = recordDate
        activeQuickRecordKind = kind
    }

    private func closeQuickRecordCard() {
        activeQuickRecordKind = nil
        activeQuickRecordCycleID = nil
        activeQuickRecordDate = nil
    }

    private func dismissQuickAddMenu() {
        guard showQuickAddMenu else { return }
        withAnimation(.interactiveSpring(response: 0.24, dampingFraction: 0.88)) {
            showQuickAddMenu = false
        }
    }

    private func rootTabLabel(_ tab: RootTab) -> some View {
        rootTabIcon(tab)
            .accessibilityLabel(tab.title)
    }

    private func rootTabIcon(_ tab: RootTab) -> some View {
        Image(systemName: rootTabSymbol(for: tab))
            .font(.system(size: 18, weight: .semibold))
    }

    private func rootTabSymbol(for tab: RootTab) -> String {
        let isSelected = selectedTab == tab

        switch tab {
        case .record:
            return isSelected ? "magazine.fill" : "magazine"
        case .companion:
            return isSelected ? "teddybear.fill" : "teddybear"
        case .growth:
            return isSelected ? "crown.fill" : "crown"
        }
    }

    private var shouldShowBottomDock: Bool {
        activeRecordSheet == nil
    }

    private func recordSheetBinding(for sheet: RecordSheet) -> Binding<Bool> {
        Binding {
            activeRecordSheet == sheet
        } set: { isPresented in
            if !isPresented, activeRecordSheet == sheet {
                activeRecordSheet = nil
            }
        }
    }
}

private struct BottomDockVisualProtection: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Rectangle()
            .fill(bottomFade)
            .frame(height: 148)
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
    }

    private var bottomFade: LinearGradient {
        let fadeColor = colorScheme == .dark ? DesignToken.scrim : DesignToken.surface
        let middleOpacity = colorScheme == .dark ? 0.42 : 0.28
        let bottomOpacity = colorScheme == .dark ? 0.84 : 0.56

        return LinearGradient(
            stops: [
                .init(color: fadeColor.opacity(0), location: 0),
                .init(color: fadeColor.opacity(middleOpacity), location: 0.54),
                .init(color: fadeColor.opacity(bottomOpacity), location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

private struct BottomNavigationDock: View {
    @Binding var selectedTab: RootTab
    @Binding var isQuickAddExpanded: Bool
    let onTabSelected: (RootTab) -> Void
    let onEat: () -> Void
    let onPoop: () -> Void
    let onYearning: () -> Void
    let onSleep: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            tabCluster

            Spacer(minLength: 12)

            FloatingRecordAddButton(
                isExpanded: $isQuickAddExpanded,
                onEat: onEat,
                onPoop: onPoop,
                onYearning: onYearning,
                onSleep: onSleep
            )
            .frame(width: 56, height: 56)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    private var tabCluster: some View {
        HStack(spacing: 16) {
            ForEach(RootTab.allCases, id: \.self) { tab in
                tabButton(tab)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
        .dockGlass(shape: Capsule(style: .continuous))
    }

    private func tabButton(_ tab: RootTab) -> some View {
        let isSelected = selectedTab == tab

        return Button {
            onTabSelected(tab)
        } label: {
            tabIcon(for: tab, isSelected: isSelected)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    @ViewBuilder
    private func tabIcon(for tab: RootTab, isSelected: Bool) -> some View {
        if tab == .record {
            SimpleHomeGlyph(isFilled: isSelected)
                .foregroundStyle(isSelected ? DesignToken.textPrimary : DesignToken.textPrimary.opacity(0.82))
                .frame(width: 19, height: 19)
        } else {
            Image(systemName: symbol(for: tab, isSelected: isSelected))
                .font(.system(size: 19, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(isSelected ? DesignToken.textPrimary : DesignToken.textPrimary.opacity(0.82))
        }
    }

    private func symbol(for tab: RootTab, isSelected: Bool) -> String {
        switch tab {
        case .record:
            return isSelected ? "house.fill" : "house"
        case .companion:
            return isSelected ? "heart.fill" : "heart"
        case .growth:
            return isSelected ? "trophy.fill" : "trophy"
        }
    }
}

private struct FloatingRecordAddButton: View {
    @Binding var isExpanded: Bool
    let onEat: () -> Void
    let onPoop: () -> Void
    let onYearning: () -> Void
    let onSleep: () -> Void

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            quickActionMenu

            Button {
                withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.82)) {
                    isExpanded.toggle()
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(DesignToken.onPrimary)
                    .frame(width: 56, height: 56)
                    .contentShape(Circle())
                    .rotationEffect(.degrees(isExpanded ? 45 : 0))
            }
            .buttonStyle(.plain)
            .background(mainButtonSurface)
            .overlay(Circle().stroke(DesignToken.glassStroke.opacity(0.7), lineWidth: 1))
            .shadow(color: DesignToken.primary.opacity(0.18), radius: 16, y: 8)
            .accessibilityLabel(isExpanded ? "收起记录菜单" : "打开记录菜单")
        }
        .animation(.interactiveSpring(response: 0.28, dampingFraction: 0.82), value: isExpanded)
    }

    private var quickActionMenu: some View {
        ZStack(alignment: .bottomTrailing) {
            quickActionButton(
                letter: "E",
                accessibilityLabel: "记录喂养",
                tint: DesignToken.easyEat,
                angle: 0,
                index: 0,
                action: onEat
            )

            quickActionButton(
                letter: "A",
                accessibilityLabel: "记录活动",
                tint: DesignToken.easyActivity,
                angle: 30,
                index: 1,
                action: onPoop
            )

            quickActionButton(
                letter: "S",
                accessibilityLabel: "记录睡眠",
                tint: DesignToken.easySleep,
                angle: 60,
                index: 2,
                action: onSleep
            )

            quickActionButton(
                letter: "Y",
                accessibilityLabel: subjectiveStateQuickActionAccessibilityLabel,
                tint: DesignToken.easyYearning,
                angle: 90,
                index: 3,
                action: onYearning
            )
        }
    }

    private var subjectiveStateQuickActionAccessibilityLabel: String {
        switch AppLocalization.language {
        case .simplifiedChinese: return "记录 Y 状态"
        case .traditionalChinese: return "記錄 Y 狀態"
        case .english: return "Record Y state"
        }
    }

    private func quickActionButton(
        letter: String,
        accessibilityLabel: String,
        tint: Color,
        angle: Double,
        index: Int,
        action: @escaping () -> Void
    ) -> some View {
        let delay = isExpanded ? Double(index) * 0.035 : 0

        return Button {
            withAnimation(.interactiveSpring(response: 0.24, dampingFraction: 0.88)) {
                isExpanded = false
            }
            action()
            } label: {
                Text(letter)
                    .font(BBBFont.font(size: 16, weight: .heavy))
                    .foregroundStyle(DesignToken.onPrimary.opacity(0.94))
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(tint))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .background(
                Circle().fill(tint.opacity(0.14))
            )
            .overlay(
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                DesignToken.onPrimary.opacity(0.88),
                                tint.opacity(0.42)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                    lineWidth: 0.9
                )
            )
        .shadow(color: tint.opacity(0.14), radius: 8, y: 4)
        .shadow(color: DesignToken.shadowColor.opacity(0.14), radius: 2, y: 1)
        .modifier(
            FloatingArcBurstModifier(
                isExpanded: isExpanded,
                angle: angle,
                radius: 82,
                arcSweep: 18 + Double(index) * 4,
                spinDegrees: index.isMultiple(of: 2) ? 18 : -18
            )
        )
        .zIndex(Double(index))
        .allowsHitTesting(isExpanded)
        .accessibilityHidden(!isExpanded)
        .accessibilityLabel(accessibilityLabel)
        .animation(
            .interpolatingSpring(stiffness: 330, damping: 18, initialVelocity: 0.8)
                .delay(delay),
            value: isExpanded
        )
    }

    private var mainButtonSurface: some View {
        Circle()
            .fill(Self.babyAgeGradient)
            .overlay(
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                DesignToken.onPrimary.opacity(0.24),
                                DesignToken.onPrimary.opacity(0.04),
                                DesignToken.primary.opacity(0.16)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
    }

    private static let babyAgeGradient = LinearGradient(
        colors: [
            DesignToken.primary,
            DesignToken.primarySoft,
            DesignToken.accentBlue
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

}

private struct SimpleHomeGlyph: View {
    let isFilled: Bool

    var body: some View {
        let shape = SimpleHomeShape()

        if isFilled {
            shape
                .fill(.foreground)
        } else {
            shape
                .stroke(.foreground, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
        }
    }
}

private struct SimpleHomeShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height

        var path = Path()
        path.move(to: CGPoint(x: 0.50 * w, y: 0.08 * h))

        path.addQuadCurve(
            to: CGPoint(x: 0.89 * w, y: 0.38 * h),
            control: CGPoint(x: 0.73 * w, y: 0.12 * h)
        )
        path.addQuadCurve(
            to: CGPoint(x: 0.94 * w, y: 0.51 * h),
            control: CGPoint(x: 0.94 * w, y: 0.43 * h)
        )
        path.addLine(to: CGPoint(x: 0.94 * w, y: 0.82 * h))
        path.addQuadCurve(
            to: CGPoint(x: 0.82 * w, y: 0.94 * h),
            control: CGPoint(x: 0.94 * w, y: 0.90 * h)
        )
        path.addLine(to: CGPoint(x: 0.18 * w, y: 0.94 * h))
        path.addQuadCurve(
            to: CGPoint(x: 0.06 * w, y: 0.82 * h),
            control: CGPoint(x: 0.06 * w, y: 0.90 * h)
        )
        path.addLine(to: CGPoint(x: 0.06 * w, y: 0.51 * h))
        path.addQuadCurve(
            to: CGPoint(x: 0.11 * w, y: 0.38 * h),
            control: CGPoint(x: 0.06 * w, y: 0.43 * h)
        )
        path.addQuadCurve(
            to: CGPoint(x: 0.50 * w, y: 0.08 * h),
            control: CGPoint(x: 0.27 * w, y: 0.12 * h)
        )
        path.closeSubpath()

        return path
    }
}

private struct FloatingArcBurstModifier: AnimatableModifier {
    var progress: Double
    let angle: Double
    let radius: CGFloat
    let arcSweep: Double
    let spinDegrees: Double

    init(isExpanded: Bool, angle: Double, radius: CGFloat, arcSweep: Double, spinDegrees: Double) {
        self.progress = isExpanded ? 1 : 0
        self.angle = angle
        self.radius = radius
        self.arcSweep = arcSweep
        self.spinDegrees = spinDegrees
    }

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let visibleProgress = min(max(progress, 0), 1)
        let travelProgress = max(progress, 0)
        let currentAngle = angle + arcSweep * (1 - progress)
        let radians = currentAngle * .pi / 180
        let currentRadius = radius * travelProgress
        let spin = spinDegrees * sin(progress * .pi)
        let scale = max(0.18, 0.18 + 0.86 * min(max(progress, 0), 1.12))

        content
            .scaleEffect(scale)
            .opacity(visibleProgress)
            .rotationEffect(.degrees(spin))
            .offset(
                x: -cos(radians) * currentRadius,
                y: -sin(radians) * currentRadius
            )
    }
}

private enum QuickRecordKind: String, CaseIterable, Identifiable {
    case formulaBottle
    case expressedBottle
    case nursing
    case solids
    case diaper
    case activity
    case bath
    case tummyTime
    case massage
    case story
    case outdoor
    case play
    case toothbrushing
    case sleep

    var id: String { rawValue }

    static var allCases: [QuickRecordKind] {
        [.formulaBottle, .expressedBottle, .nursing, .solids, .diaper, .activity, .sleep]
    }

    var title: String {
        switch self {
        case .formulaBottle: return "奶粉瓶喂"
        case .expressedBottle: return "母乳瓶喂"
        case .nursing: return "母乳亲喂"
        case .solids: return "宝宝辅食"
        case .diaper: return "尿布"
        case .activity: return "活动"
        case .bath: return "洗澡"
        case .tummyTime: return "趴卧"
        case .massage: return "抚触"
        case .story: return "故事"
        case .outdoor: return "户外"
        case .play: return "玩耍"
        case .toothbrushing: return "刷牙"
        case .sleep: return "睡眠"
        }
    }

    var shortTitle: String {
        switch self {
        case .formulaBottle: return "奶粉瓶喂"
        case .expressedBottle: return "母乳瓶喂"
        case .nursing: return "亲喂"
        case .solids: return "辅食"
        case .diaper: return "尿布"
        case .activity: return "活动"
        case .bath: return "洗澡"
        case .tummyTime: return "趴卧"
        case .massage: return "抚触"
        case .story: return "故事"
        case .outdoor: return "户外"
        case .play: return "玩耍"
        case .toothbrushing: return "刷牙"
        case .sleep: return "睡眠"
        }
    }

    var phaseLetter: String {
        switch self {
        case .formulaBottle, .expressedBottle, .nursing, .solids: return "E"
        case .diaper, .activity, .bath, .tummyTime, .massage, .story, .outdoor, .play, .toothbrushing: return "A"
        case .sleep: return "S"
        }
    }

    var color: Color {
        switch self {
        case .formulaBottle, .expressedBottle, .nursing, .solids: return DesignToken.easyEat
        case .diaper, .activity, .bath, .tummyTime, .massage, .story, .outdoor, .play, .toothbrushing: return DesignToken.easyActivity
        case .sleep: return DesignToken.easySleep
        }
    }

    var softColor: Color {
        switch self {
        case .formulaBottle, .expressedBottle, .nursing, .solids: return DesignToken.easyEatSoft
        case .diaper, .activity, .bath, .tummyTime, .massage, .story, .outdoor, .play, .toothbrushing: return DesignToken.easyActivitySoft
        case .sleep: return DesignToken.easySleepSoft
        }
    }

    var symbolName: String {
        switch self {
        case .formulaBottle, .expressedBottle: return "baby.bottle.fill"
        case .nursing: return "heart.fill"
        case .solids: return "fork.knife"
        case .diaper: return "drop.fill"
        case .activity: return "sparkles"
        case .bath: return "bathtub.fill"
        case .tummyTime: return "figure.strengthtraining.traditional"
        case .massage: return "hands.sparkles.fill"
        case .story: return "book.fill"
        case .outdoor: return "sun.max.fill"
        case .play: return "sparkles"
        case .toothbrushing: return "mouth.fill"
        case .sleep: return "moon.zzz.fill"
        }
    }

    var usesBottleHero: Bool {
        switch self {
        case .formulaBottle, .expressedBottle:
            return true
        default:
            return false
        }
    }

    var unit: String {
        switch self {
        case .formulaBottle, .expressedBottle: return "ml"
        case .nursing, .activity, .bath, .tummyTime, .massage, .story, .outdoor, .play, .toothbrushing, .sleep: return "min"
        case .solids: return "g"
        case .diaper: return "次"
        }
    }

    var defaultValue: Int {
        switch self {
        case .formulaBottle, .expressedBottle: return 120
        case .nursing: return 10
        case .solids: return 30
        case .diaper: return 1
        case .activity: return 10
        case .bath: return 15
        case .tummyTime: return 5
        case .massage, .story, .play: return 10
        case .outdoor: return 20
        case .toothbrushing: return 2
        case .sleep: return 30
        }
    }

    var step: Int {
        switch self {
        case .formulaBottle, .expressedBottle: return 10
        case .nursing, .activity, .bath, .tummyTime, .massage, .story, .outdoor, .play, .sleep: return 5
        case .solids: return 5
        case .diaper, .toothbrushing: return 1
        }
    }

    var valueRange: ClosedRange<Int> {
        switch self {
        case .formulaBottle, .expressedBottle: return 10...240
        case .nursing: return 1...60
        case .solids: return 5...300
        case .diaper: return 1...6
        case .activity: return 1...120
        case .bath, .tummyTime, .massage, .story, .outdoor, .play: return 1...120
        case .toothbrushing: return 1...10
        case .sleep: return 1...720
        }
    }

    var placeholderText: String {
        switch self {
        case .formulaBottle, .expressedBottle:
            return "拖动刻度或使用加减按钮调整奶量"
        case .nursing:
            return "记录左右侧时长，也可以直接输入总时长"
        case .solids:
            return "选择食物种类并记录本次进食量"
        case .diaper:
            return "选择类型和状态，记录本次护理"
        case .activity:
            return "多选活动，按类型合并记录"
        case .sleep:
            return "选择开始与结束时间，保存实际睡眠"
        default:
            return "选择时长，并可添加一条简短备注"
        }
    }
}

private struct LoopingQuickRecordKind: Identifiable {
    let loop: Int
    let kind: QuickRecordKind

    var id: String {
        "\(loop)-\(kind.rawValue)"
    }
}

private enum QuickSleepMode: String, CaseIterable, Identifiable {
    case justWoke
    case justAsleep
    case smartFill
    case manual

    var id: String { rawValue }

    var title: String {
        switch self {
        case .justWoke: return "刚清醒"
        case .justAsleep: return "刚入睡"
        case .smartFill: return "补本轮"
        case .manual: return "手动"
        }
    }
}

private struct QuickSleepSuggestion {
    let startAt: Date
    let endAt: Date
    let reason: String
}

private enum QuickDiaperMode: String, CaseIterable, Identifiable {
    case pee
    case poop

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pee: return "尿了"
        case .poop: return "拉了"
        }
    }

    var subtitle: String {
        switch self {
        case .pee: return "选择尿量"
        case .poop: return "选择性状"
        }
    }

    var recordType: DiaperRecordType {
        switch self {
        case .pee: return .pee
        case .poop: return .poop
        }
    }

    var accent: Color { recordType.accent }
    var softFill: Color { recordType.softFill }

    var symbolName: String {
        switch self {
        case .pee: return "drop.fill"
        case .poop: return "circle.grid.2x2.fill"
        }
    }
}

private enum QuickUrineAmount: String, CaseIterable, Identifiable {
    case low
    case medium
    case high

    var id: String { rawValue }

    var title: String {
        switch self {
        case .low: return "少"
        case .medium: return "中"
        case .high: return "多"
        }
    }

    var dropCount: Int {
        switch self {
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        }
    }

    var detail: String {
        switch self {
        case .low:
            return "尿了一点💧"
        case .medium:
            return "尿了不少💧💧"
        case .high:
            return "尿了很多💧💧💧"
        }
    }
}

private enum QuickPoopTexture: String, CaseIterable, Identifiable {
    case hard
    case formed
    case paste
    case watery
    case mucus

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hard: return "硬"
        case .formed: return "条"
        case .paste: return "糊"
        case .watery: return "稀"
        case .mucus: return "黏"
        }
    }

    var shortText: String {
        switch self {
        case .hard: return "硬结便"
        case .formed: return "成型便"
        case .paste: return "糊状便"
        case .watery: return "稀水便"
        case .mucus: return "黏液便"
        }
    }

    var guidance: String {
        switch self {
        case .hard:
            return "硬结便，注意便秘或脱水"
        case .formed:
            return "成型便，软硬适中"
        case .paste:
            return "糊状便，小月龄常见的黄金状态"
        case .watery:
            return "稀水便，观察精神和发热"
        case .mucus:
            return "黏液便，持续大量需注意"
        }
    }

    var detail: String {
        shortText
    }
}

private enum QuickActivityCategory: String, CaseIterable, Identifiable {
    case development
    case family
    case care

    var id: String { rawValue }

    var title: String {
        switch self {
        case .development: return "发育与训练"
        case .family: return "亲子与娱乐"
        case .care: return "日常护理"
        }
    }

    var shortTitle: String {
        switch self {
        case .development: return "发育"
        case .family: return "亲子"
        case .care: return "护理"
        }
    }

    var symbolName: String {
        switch self {
        case .development: return "lightbulb.fill"
        case .family: return "book.closed.fill"
        case .care: return "sparkles"
        }
    }

    var items: [QuickActivityItem] {
        switch self {
        case .development:
            return ["趴卧", "翻身训练", "黑白卡", "追物训练", "抓握", "健身架", "悬挂玩具"]
                .map { QuickActivityItem(category: self, title: $0) }
        case .family:
            return ["对视聊天", "照镜子", "绘本", "布书", "音乐律动", "听儿歌", "户外活动", "室内活动"]
                .map { QuickActivityItem(category: self, title: $0) }
        case .care:
            return ["抚触", "排气操", "排嗝", "飞机抱", "洗澡", "剪指甲"]
                .map { QuickActivityItem(category: self, title: $0) }
        }
    }
}

private struct QuickActivityItem: Hashable, Identifiable {
    let category: QuickActivityCategory
    let title: String

    var id: String {
        "\(category.rawValue)-\(title)"
    }
}

enum QuickRecordEditTarget: Identifiable {
    case feeding(FeedingSession)
    case care(CareRecord)

    var id: String {
        switch self {
        case .feeding(let session):
            return "feeding-\(session.id.uuidString)"
        case .care(let record):
            return "care-\(record.id.uuidString)"
        }
    }
}

private struct QuickRecordInitialState {
    let kind: QuickRecordKind
    let value: Int
    let recordedAt: Date
    var sleepMode: QuickSleepMode = .justWoke
    var sleepStartAt: Date = Date().addingTimeInterval(-30 * 60)
    var sleepEndAt: Date = Date()
    var diaperMode: QuickDiaperMode = .pee
    var urineAmount: QuickUrineAmount = .medium
    var poopTexture: QuickPoopTexture = .paste
    var selectedActivityItems: Set<QuickActivityItem> = []
    var selectedSolidFoods: Set<SolidFood> = [.rice]
    var nursingLeftSeconds = 0
    var nursingRightSeconds = 0
}

struct QuickRecordCardOverlay: View {
    @EnvironmentObject private var feedingStore: FeedingStore
    @EnvironmentObject private var feedingDraftStore: FeedingDraftStore
    @EnvironmentObject private var activityStore: ActivityStore
    @EnvironmentObject private var sleepDraftStore: SleepDraftStore
    @EnvironmentObject private var easyCycleStore: EasyCycleStore

    private let targetCycleID: UUID?
    private let recordDate: Date?
    private let editTarget: QuickRecordEditTarget?
    private let onDismiss: () -> Void
    private let onCompletedRecord: (SubjectiveStatePromptContext) -> Void

    @State private var selectedKind: QuickRecordKind
    @State private var value: Int
    @State private var recordedAt = Date()
    @State private var sleepMode: QuickSleepMode = .justWoke
    @State private var sleepStartAt = Date().addingTimeInterval(-30 * 60)
    @State private var sleepEndAt = Date()
    @State private var didConfigureSleep = false
    @State private var diaperMode: QuickDiaperMode = .pee
    @State private var urineAmount: QuickUrineAmount = .medium
    @State private var poopTexture: QuickPoopTexture = .paste
    @State private var didConfigureDiaper = false
    @State private var selectedActivityItems: Set<QuickActivityItem> = []
    @State private var selectedSolidFoods: Set<SolidFood> = [.rice]
    @State private var activeNursingSide: BreastSide?
    @State private var nursingLeftSeconds = 0
    @State private var nursingRightSeconds = 0
    @State private var showRecordTimePicker = false
    @State private var recordTimeHour = 0
    @State private var recordTimeMinute = 0

    private static let kindSwitcherLoopCount = 5
    private static let kindSwitcherCenterLoop = 2

    fileprivate init(
        initialKind: QuickRecordKind,
        targetCycleID: UUID? = nil,
        recordDate: Date? = nil,
        onDismiss: @escaping () -> Void,
        onCompletedRecord: @escaping (SubjectiveStatePromptContext) -> Void = { _ in }
    ) {
        let initialState = QuickRecordInitialState(
            kind: initialKind,
            value: initialKind.defaultValue,
            recordedAt: Self.defaultRecordedAt(for: recordDate)
        )
        self.init(
            initialState: initialState,
            targetCycleID: targetCycleID,
            recordDate: recordDate,
            editTarget: nil,
            onDismiss: onDismiss,
            onCompletedRecord: onCompletedRecord
        )
    }

    init(
        editTarget: QuickRecordEditTarget,
        onDismiss: @escaping () -> Void,
        onCompletedRecord: @escaping (SubjectiveStatePromptContext) -> Void = { _ in }
    ) {
        let initialState = Self.initialState(for: editTarget)
        self.init(
            initialState: initialState,
            targetCycleID: nil,
            recordDate: initialState.recordedAt,
            editTarget: editTarget,
            onDismiss: onDismiss,
            onCompletedRecord: onCompletedRecord
        )
    }

    private init(
        initialState: QuickRecordInitialState,
        targetCycleID: UUID?,
        recordDate: Date?,
        editTarget: QuickRecordEditTarget?,
        onDismiss: @escaping () -> Void,
        onCompletedRecord: @escaping (SubjectiveStatePromptContext) -> Void
    ) {
        self.targetCycleID = targetCycleID
        self.recordDate = recordDate
        self.editTarget = editTarget
        self.onDismiss = onDismiss
        self.onCompletedRecord = onCompletedRecord
        _selectedKind = State(initialValue: initialState.kind)
        _value = State(initialValue: initialState.value)
        _recordedAt = State(initialValue: initialState.recordedAt)
        _sleepMode = State(initialValue: initialState.sleepMode)
        _sleepStartAt = State(initialValue: initialState.sleepStartAt)
        _sleepEndAt = State(initialValue: initialState.sleepEndAt)
        _didConfigureSleep = State(initialValue: editTarget != nil)
        _diaperMode = State(initialValue: initialState.diaperMode)
        _urineAmount = State(initialValue: initialState.urineAmount)
        _poopTexture = State(initialValue: initialState.poopTexture)
        _didConfigureDiaper = State(initialValue: editTarget != nil)
        _selectedActivityItems = State(initialValue: initialState.selectedActivityItems)
        _selectedSolidFoods = State(initialValue: initialState.selectedSolidFoods)
        _nursingLeftSeconds = State(initialValue: initialState.nursingLeftSeconds)
        _nursingRightSeconds = State(initialValue: initialState.nursingRightSeconds)
    }

    var body: some View {
        ZStack {
            DesignToken.scrim
                .opacity(0.46)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            VStack(spacing: 12) {
                quickCard
                if editTarget == nil {
                    kindSwitcher
                        .padding(.horizontal, 2)
                }
            }
            .padding(.horizontal, DesignToken.screenHorizontalPadding)
            .frame(maxWidth: 430)
        }
        .onChange(of: selectedKind) { _, newValue in
            guard editTarget == nil else { return }
            value = newValue.defaultValue
            activeNursingSide = nil
            if newValue != .nursing {
                feedingDraftStore.pauseBreastTimer()
            }
            if newValue == .sleep {
                configureSleepDefaults(force: true)
            }
            if newValue == .diaper {
                configureDiaperDefaults(force: true)
            }
        }
        .onAppear {
            syncRecordTimePickerState()
            configureSleepDefaults(force: false)
            configureDiaperDefaults(force: false)
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            guard selectedKind == .nursing else { return }
            value = max(nursingTotalSeconds / 60, 0)
        }
    }

    private static func defaultRecordedAt(for recordDate: Date?) -> Date {
        guard let recordDate else { return Date() }
        let calendar = Calendar.current
        let now = Date()
        if calendar.isDate(recordDate, inSameDayAs: now) {
            return now
        }
        var dayComponents = calendar.dateComponents([.year, .month, .day], from: recordDate)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: now)
        dayComponents.hour = timeComponents.hour
        dayComponents.minute = timeComponents.minute
        dayComponents.second = 0
        return min(calendar.date(from: dayComponents) ?? now, now)
    }

    private static func initialState(for target: QuickRecordEditTarget) -> QuickRecordInitialState {
        switch target {
        case .feeding(let session):
            return feedingInitialState(for: session)
        case .care(let record):
            return careInitialState(for: record)
        }
    }

    private static func feedingInitialState(for session: FeedingSession) -> QuickRecordInitialState {
        let recordedAt = session.startAt ?? session.createdAt

        switch session.type {
        case .bottle:
            let milkType = session.bottleMilkType ?? .formula
            let kind: QuickRecordKind = milkType == .expressed ? .expressedBottle : .formulaBottle
            let amount = session.entries
                .filter { $0.type == .bottle && ($0.milkType ?? .formula) == milkType }
                .compactMap(\.bottleAmount)
                .reduce(0, +)
            return QuickRecordInitialState(
                kind: kind,
                value: clamped(amount, for: kind),
                recordedAt: recordedAt
            )

        case .breast:
            let leftMinutes = session.entries
                .filter { $0.type == .breast && ($0.breastSide ?? .left) == .left }
                .compactMap(\.breastDuration)
                .reduce(0, +)
            let rightMinutes = session.entries
                .filter { $0.type == .breast && $0.breastSide == .right }
                .compactMap(\.breastDuration)
                .reduce(0, +)
            let totalMinutes = leftMinutes + rightMinutes
            var state = QuickRecordInitialState(
                kind: .nursing,
                value: clamped(totalMinutes, for: .nursing),
                recordedAt: recordedAt
            )
            state.nursingLeftSeconds = leftMinutes * 60
            state.nursingRightSeconds = rightMinutes * 60
            return state

        case .solid:
            let foods = Set(session.entries.compactMap(\.solidFood))
            let totalAmount = session.entries
                .filter { $0.type == .solid }
                .compactMap(\.solidAmount)
                .reduce(0, +)
            var state = QuickRecordInitialState(
                kind: .solids,
                value: clamped(Int(totalAmount.rounded()), for: .solids),
                recordedAt: recordedAt
            )
            state.selectedSolidFoods = foods.isEmpty ? [.rice] : foods
            return state
        }
    }

    private static func careInitialState(for record: CareRecord) -> QuickRecordInitialState {
        switch record.kind {
        case .diaper:
            let type = DiaperRecordType.type(for: record.title)
            let detail = DiaperRecordType.displayDetail(title: record.title, detail: record.detail)
            var state = QuickRecordInitialState(kind: .diaper, value: 1, recordedAt: record.recordedAt)
            state.diaperMode = type == .pee ? .pee : .poop
            state.urineAmount = urineAmount(from: detail)
            state.poopTexture = poopTexture(from: detail)
            return state

        case .activity:
            var state = QuickRecordInitialState(
                kind: .activity,
                value: QuickRecordKind.activity.defaultValue,
                recordedAt: record.recordedAt
            )
            state.selectedActivityItems = activityItems(from: record.title)
            return state

        case .sleep:
            let duration = SleepRecordFormatter.durationMinutes(from: record.detail) ?? QuickRecordKind.sleep.defaultValue
            let end = SleepRecordFormatter.endTime(start: record.recordedAt, durationMinutes: duration)
            var state = QuickRecordInitialState(
                kind: .sleep,
                value: clamped(duration, for: .sleep),
                recordedAt: record.recordedAt
            )
            state.sleepMode = .manual
            state.sleepStartAt = record.recordedAt
            state.sleepEndAt = end
            return state
        }
    }

    private static func clamped(_ value: Int, for kind: QuickRecordKind) -> Int {
        min(max(value, kind.valueRange.lowerBound), kind.valueRange.upperBound)
    }

    private static func urineAmount(from detail: String) -> QuickUrineAmount {
        let normalized = detail
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "：", with: ":")
        if normalized.contains("尿了很多") || normalized.contains("尿量:多") || normalized.contains("尿量多") || normalized.contains("很多") {
            return .high
        }
        if normalized.contains("尿了不少") || normalized.contains("尿量:中") || normalized.contains("尿量中") || normalized.contains("不少") {
            return .medium
        }
        if normalized.contains("尿了一点") || normalized.contains("尿量:少") || normalized.contains("尿量少") || normalized.contains("一点") || normalized.contains("少") {
            return .low
        }
        if normalized.contains("多") { return .high }
        return .medium
    }

    private static func poopTexture(from detail: String) -> QuickPoopTexture {
        if detail.contains("成型") || detail.contains("条") { return .formed }
        if detail.contains("稀水") || detail.contains("稀") { return .watery }
        if detail.contains("黏液") || detail.contains("黏") { return .mucus }
        if detail.contains("硬结") || detail.contains("硬") { return .hard }
        return .paste
    }

    private static func activityItems(from title: String) -> Set<QuickActivityItem> {
        let availableItems = QuickActivityCategory.allCases.flatMap(\.items)
        var payload = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let usesCombinedRecordTitle = payload.hasPrefix("宝宝完成了")
        if usesCombinedRecordTitle {
            payload.removeFirst("宝宝完成了".count)
        }
        if usesCombinedRecordTitle, payload.hasSuffix("活动") {
            payload.removeLast("活动".count)
        }

        let names = payload
            .split(separator: "、")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return Set(names.map { name in
            availableItems.first(where: { $0.title == name })
                ?? QuickActivityItem(category: .care, title: name)
        })
    }

    private var quickCard: some View {
        VStack(spacing: 0) {
            header
            if showRecordTimePicker {
                recordTimeEditor
                    .padding(.top, 12)
                    .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
            }

            VStack(spacing: 12) {
                hero
                if selectedKind == .sleep, editTarget == nil {
                    sleepModeSwitcher
                } else if selectedKind == .diaper {
                    diaperControls
                } else if selectedKind == .activity || selectedKind == .solids {
                    EmptyView()
                } else if selectedKind == .nursing {
                    nursingTimerControls
                } else {
                    controlBar
                }
            }
            .padding(.top, 12)
            .frame(maxHeight: .infinity, alignment: .top)

            saveButton
        }
        .padding(16)
        .frame(height: quickCardHeight, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [DesignToken.surfaceRaised, DesignToken.surfaceSoft],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(DesignToken.glassStroke.opacity(0.82), lineWidth: 1)
                )
                .shadow(color: DesignToken.shadowColor.opacity(0.22), radius: 28, y: 16)
        )
    }

    private var quickCardHeight: CGFloat {
        showRecordTimePicker ? 670 : 500
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack(spacing: 9) {
                quickPhaseIcon(kind: selectedKind)

                VStack(alignment: .leading, spacing: 3) {
                    Text(
                        editTarget == nil
                            ? selectedKind.title.localized
                            : AppLocalization.format("修改%@", selectedKind.title.localized)
                    )
                        .font(BBBFont.font(size: 17, weight: .bold))
                        .foregroundStyle(DesignToken.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
                .frame(height: 34, alignment: .center)

                Spacer(minLength: 6)

                quickRecordTimePicker
            }
        }
    }

    private func quickPhaseIcon(kind: QuickRecordKind) -> some View {
        ZStack {
            Circle()
                .fill(kind.softColor.opacity(0.46))
                .frame(width: 34, height: 34)
                .overlay(Circle().stroke(kind.color.opacity(0.88), lineWidth: 1.5))
                .shadow(color: kind.color.opacity(0.12), radius: 6, y: 3)

            Text(kind.phaseLetter)
                .font(BBBFont.font(size: 15, weight: .heavy))
                .foregroundStyle(kind.color)
        }
        .frame(width: 34, height: 34)
    }

    private var quickRecordTimePicker: some View {
        Button {
            syncRecordTimePickerState()
            withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                showRecordTimePicker.toggle()
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.system(size: 12, weight: .bold))
                Text(AppDateTimeFormat.time(recordedAt))
                    .font(BBBFont.font(size: 12, weight: .heavy))
                    .monospacedDigit()
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .black))
            }
            .foregroundStyle(selectedKind.color)
            .padding(.horizontal, 9)
            .frame(height: 34)
            .frame(width: 136)
            .background(Capsule().fill(DesignToken.glassFill.opacity(0.76)))
            .overlay(Capsule().stroke(selectedKind.color.opacity(0.22), lineWidth: 1))
        }
        .buttonStyle(ScaleButtonStyle())
        .frame(minHeight: DesignToken.minimumTapSize)
        .accessibilityLabel("记录时间")
        .accessibilityValue(AppDateTimeFormat.dateTime(recordedAt))
    }

    private var recordTimeEditor: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Picker("小时", selection: $recordTimeHour) {
                    ForEach(availableRecordHours, id: \.self) { hour in
                        Text(String(format: "%02d", hour))
                            .tag(hour)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                .clipped()

                Text(":")
                    .font(BBBFont.font(size: 20, weight: .heavy))
                    .foregroundStyle(selectedKind.color.opacity(0.72))

                Picker("分钟", selection: $recordTimeMinute) {
                    ForEach(availableRecordMinutes, id: \.self) { minute in
                        Text(String(format: "%02d", minute))
                            .tag(minute)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                .clipped()
            }
            .frame(height: 96)
            .onChange(of: recordTimeHour) { _, _ in
                applyRecordTimePickerState()
            }
            .onChange(of: recordTimeMinute) { _, _ in
                applyRecordTimePickerState()
            }

            HStack {
                Text(recordTimeEditorText)
                    .font(BBBFont.font(size: 12, weight: .heavy))
                    .foregroundStyle(DesignToken.textSecondary)
                    .monospacedDigit()
                Spacer()
                Button("完成") {
                    applyRecordTimePickerState()
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.86)) {
                        showRecordTimePicker = false
                    }
                }
                .font(BBBFont.font(size: 12, weight: .heavy))
                .foregroundStyle(DesignToken.onPrimary)
                .padding(.horizontal, 12)
                .frame(minWidth: 64, minHeight: DesignToken.minimumTapSize)
                .background(Capsule().fill(selectedKind.color))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(selectedKind.softColor.opacity(0.58))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(selectedKind.color.opacity(0.16), lineWidth: 1)
        )
    }

    private var recordTimeEditorText: String {
        AppDateTimeFormat.dateTime(recordedAt)
    }

    private func syncRecordTimePickerState() {
        let components = Calendar.current.dateComponents([.hour, .minute], from: recordedAt)
        recordTimeHour = min(max(components.hour ?? 0, 0), maxAvailableRecordHour)
        recordTimeMinute = min(max(components.minute ?? 0, 0), maxAvailableRecordMinute(for: recordTimeHour))
    }

    private func applyRecordTimePickerState() {
        normalizeRecordTimePickerState()
        var components = Calendar.current.dateComponents([.year, .month, .day], from: recordedAt)
        components.hour = recordTimeHour
        components.minute = recordTimeMinute
        components.second = 0
        guard let candidate = Calendar.current.date(from: components) else { return }
        let updatedRecordedAt = min(candidate, Date())
        if editTarget != nil, selectedKind == .sleep {
            let duration = max(sleepEndAt.timeIntervalSince(sleepStartAt), 60)
            sleepStartAt = updatedRecordedAt
            sleepEndAt = min(updatedRecordedAt.addingTimeInterval(duration), Date())
        }
        recordedAt = updatedRecordedAt
    }

    private var availableRecordHours: [Int] {
        Array(0...maxAvailableRecordHour)
    }

    private var availableRecordMinutes: [Int] {
        Array(0...maxAvailableRecordMinute(for: recordTimeHour))
    }

    private var isRecordingToday: Bool {
        Calendar.current.isDateInToday(recordedAt)
    }

    private var maxAvailableRecordHour: Int {
        guard isRecordingToday else { return 23 }
        return Calendar.current.component(.hour, from: Date())
    }

    private func maxAvailableRecordMinute(for hour: Int) -> Int {
        guard isRecordingToday, hour >= maxAvailableRecordHour else { return 59 }
        return Calendar.current.component(.minute, from: Date())
    }

    private func normalizeRecordTimePickerState() {
        let maxHour = maxAvailableRecordHour
        if recordTimeHour > maxHour {
            recordTimeHour = maxHour
        }
        let maxMinute = maxAvailableRecordMinute(for: recordTimeHour)
        if recordTimeMinute > maxMinute {
            recordTimeMinute = maxMinute
        }
    }

    private var recordedAtDayText: String {
        AppDateTimeFormat.date(recordedAt)
    }

    private var hero: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            DesignToken.surfaceRaised,
                            selectedKind.softColor.opacity(0.30),
                            DesignToken.surfaceSoft
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(selectedKind.color.opacity(0.10), lineWidth: 1)
                )

            if selectedKind == .sleep {
                sleepSegmentHero
            } else if selectedKind == .diaper {
                diaperHero
            } else if selectedKind == .activity {
                activityHero
            } else if selectedKind == .solids {
                solidsHero
            } else if selectedKind == .nursing {
                nursingHero
            } else if selectedKind.usesBottleHero {
                InteractiveBottleView(
                    amount: bottleAmountBinding,
                    range: Double(selectedKind.valueRange.lowerBound)...Double(selectedKind.valueRange.upperBound),
                    step: quickBottleStep,
                    tint: selectedKind.color
                )
                .frame(width: 210, height: 250)
                .padding(.top, 2)
                .padding(.bottom, 4)
            } else {
                VStack(spacing: 13) {
                    ZStack {
                        Circle()
                            .fill(DesignToken.glassFill.opacity(0.68))
                            .frame(width: 118, height: 118)
                            .shadow(color: selectedKind.color.opacity(0.12), radius: 16, y: 9)

                        Image(systemName: selectedKind.symbolName)
                            .font(.system(size: 46, weight: .bold))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(selectedKind.color)
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text(displayedQuickValue)
                            .font(BBBFont.font(size: 38, weight: .heavy))
                            .foregroundStyle(selectedKind.color)
                        Text(displayedQuickUnit)
                            .font(BBBFont.font(size: 19, weight: .heavy))
                            .foregroundStyle(DesignToken.textSecondary)
                    }

                    Text(selectedKind.placeholderText.localized)
                        .font(BBBFont.font(size: 12, weight: .semibold))
                        .foregroundStyle(DesignToken.textSecondary.opacity(0.72))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                .padding(.vertical, 26)
                .padding(.horizontal, 16)
            }
        }
        .id(selectedKind)
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: selectedKind)
        .frame(height: heroHeight)
    }

    private var heroHeight: CGFloat {
        switch selectedKind {
        case .activity, .solids:
            return 310
        case .diaper:
            return 224
        default:
            return 270
        }
    }

    private var nursingHero: some View {
        ZStack {
            QuickBreastMinuteArcScale(
                side: .left,
                seconds: nursingLeftSeconds,
                accent: DesignToken.feedingBreast
            ) { minutes in
                setNursingMinutes(.left, minutes: minutes)
            }
            .frame(width: 84, height: 226)
            .position(x: 95, y: 135)

            QuickBreastMinuteArcScale(
                side: .right,
                seconds: nursingRightSeconds,
                accent: DesignToken.feedingBottle
            ) { minutes in
                setNursingMinutes(.right, minutes: minutes)
            }
            .frame(width: 84, height: 226)
            .position(x: 275, y: 135)

            Image("record_nursing_hero")
                .resizable()
                .scaledToFit()
                .opacity(0.70)
                .frame(width: 178, height: 220)
                .position(x: 185, y: 135)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 270)
    }

    private var solidsHero: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "checklist")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(selectedKind.color)
                    Text(solidsSelectionSummary)
                        .font(BBBFont.font(size: 13, weight: .heavy))
                        .foregroundStyle(DesignToken.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    Spacer(minLength: 0)
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 9), count: 3), spacing: 9) {
                    ForEach(SolidFood.allCases) { food in
                        solidFoodChip(food)
                    }
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 28)
            .padding(.horizontal, 14)
        }
        .scrollIndicators(.visible)
    }

    private func solidFoodChip(_ food: SolidFood) -> some View {
        let isSelected = selectedSolidFoods.contains(food)
        return Button {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.86)) {
                if isSelected, selectedSolidFoods.count > 1 {
                    selectedSolidFoods.remove(food)
                } else {
                    selectedSolidFoods.insert(food)
                }
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            VStack(spacing: 6) {
                Text(food.shortLabel.localized)
                    .font(BBBFont.font(size: 13, weight: .bold))
                    .foregroundStyle(selectedKind.color)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(selectedKind.softColor.opacity(0.86)))
                Text(food.localizedDisplayName.localized)
                    .font(BBBFont.font(size: 12, weight: .heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
            }
            .foregroundStyle(isSelected ? DesignToken.textPrimary : DesignToken.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: 62)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? selectedKind.softColor.opacity(0.86) : DesignToken.glassFill.opacity(0.60))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? selectedKind.color.opacity(0.44) : DesignToken.glassStroke.opacity(0.46), lineWidth: 1.1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var solidsSelectionSummary: String {
        let names = selectedSolidFoods
            .sorted { $0.displayName < $1.displayName }
            .map(\.localizedDisplayName)

        return AppLocalization.list(names)
    }

    private var sleepSegmentHero: some View {
        VStack(spacing: 18) {
            HStack(alignment: .top, spacing: 10) {
                sleepEndpointColumn(
                    title: "入睡",
                    timeText: sleepClockText(sleepStartAt),
                    binding: sleepMode == .justAsleep && sleepDraftStore.isRecording ? nil : sleepStartTimeBinding
                )

                VStack(spacing: 10) {
                    Rectangle()
                        .fill(selectedKind.color.opacity(0.20))
                        .frame(height: 1)
                        .overlay(
                            Image(systemName: "moon.zzz.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(selectedKind.color)
                                .padding(.horizontal, 8)
                                .background(Capsule().fill(DesignToken.surfaceRaised))
                        )
                        .padding(.top, 29)

                    Text(sleepCenterText)
                        .font(BBBFont.font(size: 12, weight: .heavy))
                        .foregroundStyle(selectedKind.color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                .frame(maxWidth: .infinity)

                sleepEndpointColumn(
                    title: "清醒",
                    timeText: sleepMode == .justAsleep
                        ? (sleepDraftStore.isRecording ? sleepClockText(Date()) : "--:--")
                        : sleepClockText(sleepEndAt),
                    binding: sleepMode == .justAsleep ? nil : sleepEndTimeBinding
                )
            }

            sleepModeBody
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 20)
    }

    private func sleepEndpointColumn(title: String, timeText: String, binding: Binding<Date>?) -> some View {
        VStack(spacing: 8) {
            Text(title.localized)
                .font(BBBFont.font(size: 24, weight: .heavy))
                .foregroundStyle(DesignToken.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            if let binding {
                DatePicker("", selection: binding, displayedComponents: [.hourAndMinute])
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .tint(selectedKind.color)
                    .frame(width: 100, height: 38)
                    .padding(.horizontal, 4)
                    .background(Capsule().fill(DesignToken.glassFill.opacity(0.78)))
                    .overlay(Capsule().stroke(selectedKind.color.opacity(0.24), lineWidth: 1))
                    .accessibilityLabel(AppLocalization.format("%@时间", title.localized))
            } else {
                Text(timeText)
                    .font(BBBFont.font(size: 15, weight: .heavy))
                    .foregroundStyle(DesignToken.textSecondary)
                    .monospacedDigit()
                    .frame(width: 100, height: 38)
                    .background(Capsule().fill(DesignToken.glassFill.opacity(0.82)))
            }
        }
        .frame(width: 104, alignment: .center)
    }

    @ViewBuilder
    private var sleepModeBody: some View {
        switch sleepMode {
        case .justAsleep:
            VStack(spacing: 8) {
                Text(
                    sleepDraftStore.isRecording
                        ? "宝宝正在睡，醒来后点保存。".localized
                        : "记录从现在入睡开始，醒来后再保存。".localized
                )
                    .font(BBBFont.font(size: 12, weight: .semibold))
                    .foregroundStyle(DesignToken.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        case .justWoke:
            sleepDurationChips
        case .smartFill:
            VStack(spacing: 8) {
                Text(smartSleepSuggestion?.reason ?? "根据本轮记录推测一段睡眠。".localized)
                    .font(BBBFont.font(size: 12, weight: .semibold))
                    .foregroundStyle(DesignToken.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                sleepDurationChips
            }
        case .manual:
            Text("直接点上方时间胶囊调整。".localized)
                .font(BBBFont.font(size: 12, weight: .semibold))
                .foregroundStyle(DesignToken.textSecondary)
        }
    }

    private var sleepDurationChips: some View {
        HStack(spacing: 8) {
            ForEach([30, 45, 60, 90], id: \.self) { minutes in
                Button {
                    applySleepDuration(minutes)
                } label: {
                    Text(sleepQuickDurationText(minutes))
                        .font(BBBFont.font(size: 11, weight: .heavy))
                        .foregroundStyle(value == minutes ? .white : selectedKind.color)
                        .padding(.horizontal, 10)
                        .frame(height: 30)
                        .background(Capsule().fill(value == minutes ? selectedKind.color : selectedKind.softColor.opacity(0.70)))
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
    }

    private var sleepModeSwitcher: some View {
        HStack(spacing: 8) {
            ForEach(QuickSleepMode.allCases) { mode in
                Button {
                    applySleepMode(mode)
                } label: {
                    Text(mode.title.localized)
                        .font(BBBFont.font(size: 11, weight: .heavy))
                        .foregroundStyle(sleepMode == mode ? .white : selectedKind.color)
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background(Capsule().fill(sleepMode == mode ? selectedKind.color : selectedKind.softColor.opacity(0.60)))
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(mode == .smartFill && smartSleepSuggestion == nil)
                .opacity(mode == .smartFill && smartSleepSuggestion == nil ? 0.42 : 1)
            }
        }
    }

    private var sleepCenterText: String {
        if sleepMode == .justAsleep, sleepDraftStore.isRecording {
            return AppLocalization.format(
                "睡眠中 %@",
                SleepRecordFormatter.durationText(minutes: max(sleepDraftStore.elapsedSeconds / 60, 0))
            )
        }
        if sleepMode == .justAsleep {
            return "准备计时".localized
        }
        return "\(SleepRecordFormatter.durationText(minutes: sleepDurationMinutes))"
    }

    private var sleepDurationMinutes: Int {
        guard let window = normalizedSleepWindow() else { return 0 }
        return max(Int(window.end.timeIntervalSince(window.start) / 60), 0)
    }

    private var sleepStartTimeBinding: Binding<Date> {
        Binding(
            get: { sleepStartAt },
            set: { candidate in
                applyNormalizedSleepWindow(startTime: candidate, endTime: sleepEndAt)
            }
        )
    }

    private var sleepEndTimeBinding: Binding<Date> {
        Binding(
            get: { sleepEndAt },
            set: { candidate in
                applyNormalizedSleepWindow(startTime: sleepStartAt, endTime: candidate)
            }
        )
    }

    private var diaperHero: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                ForEach(QuickDiaperMode.allCases) { mode in
                    diaperModeButton(mode)
                }
            }

            ZStack {
                Circle()
                    .fill(diaperAccent.opacity(0.16))
                    .frame(width: 82, height: 82)
                    .overlay(Circle().stroke(diaperAccent.opacity(0.20), lineWidth: 1))

                Image(systemName: diaperMode.symbolName)
                    .font(.system(size: 30, weight: .black))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(diaperAccent)
            }

            VStack(spacing: 4) {
                Text(diaperSummaryTitle)
                    .font(BBBFont.font(size: 28, weight: .heavy))
                    .foregroundStyle(DesignToken.textPrimary)
                    .lineLimit(1)

                Text(diaperSummaryDetail)
                    .font(BBBFont.font(size: 12, weight: .semibold))
                    .foregroundStyle(DesignToken.textSecondary.opacity(0.76))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(16)
    }

    private func diaperModeButton(_ mode: QuickDiaperMode) -> some View {
        Button {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                diaperMode = mode
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: mode.symbolName)
                    .font(.system(size: 14, weight: .black))
                VStack(alignment: .leading, spacing: 1) {
                    Text(mode.title.localized)
                        .font(BBBFont.font(size: 15, weight: .heavy))
                    Text(mode.subtitle.localized)
                        .font(BBBFont.font(size: 10, weight: .bold))
                        .opacity(0.74)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(diaperMode == mode ? .white : mode.accent)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(diaperMode == mode ? mode.accent : mode.softFill.opacity(0.66))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(diaperMode == mode ? DesignToken.onPrimary.opacity(0.32) : mode.accent.opacity(0.16), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    @ViewBuilder
    private var diaperControls: some View {
        if diaperMode == .pee {
            urineAmountSelector
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        } else {
            poopTextureSelector
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        }
    }

    private var urineAmountSelector: some View {
        HStack(spacing: 8) {
            ForEach(QuickUrineAmount.allCases) { amount in
                urineAmountButton(amount)
            }
        }
    }

    private func urineAmountButton(_ amount: QuickUrineAmount) -> some View {
        Button {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.86)) {
                urineAmount = amount
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            VStack(spacing: 5) {
                HStack(spacing: 2) {
                    ForEach(0..<amount.dropCount, id: \.self) { _ in
                        Image(systemName: "drop.fill")
                            .font(.system(size: 10, weight: .black))
                    }
                }
                Text(amount.title.localized)
                    .font(BBBFont.font(size: 17, weight: .heavy))
            }
            .foregroundStyle(urineAmount == amount ? .white : DiaperRecordType.pee.accent)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(urineAmount == amount ? DiaperRecordType.pee.accent : DiaperRecordType.pee.softFill.opacity(0.58))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(urineAmount == amount ? DesignToken.onPrimary.opacity(0.34) : DiaperRecordType.pee.accent.opacity(0.16), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var poopTextureSelector: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
            spacing: 8
        ) {
            ForEach(orderedPoopTextures) { texture in
                poopTextureButton(texture)
            }
        }
    }

    private func poopTextureButton(_ texture: QuickPoopTexture) -> some View {
        Button {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.86)) {
                poopTexture = texture
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            VStack(spacing: 2) {
                Text(texture.title.localized)
                    .font(BBBFont.font(size: 18, weight: .heavy))
                Text(texture.shortText.localized)
                    .font(BBBFont.font(size: 9, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .foregroundStyle(poopTexture == texture ? .white : DiaperRecordType.poop.accent)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(poopTexture == texture ? DiaperRecordType.poop.accent : DiaperRecordType.poop.softFill.opacity(0.54))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(poopTexture == texture ? DesignToken.onPrimary.opacity(0.34) : DiaperRecordType.poop.accent.opacity(0.16), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var diaperAccent: Color {
        diaperMode.accent
    }

    private var diaperSummaryTitle: String {
        switch diaperMode {
        case .pee:
            return AppLocalization.format("尿量%@", urineAmount.title.localized)
        case .poop:
            return AppLocalization.format("%@便", poopTexture.title.localized)
        }
    }

    private var diaperSummaryDetail: String {
        switch diaperMode {
        case .pee:
            return AppLocalization.format("%d级尿量，保存为一次尿布记录", urineAmount.dropCount)
        case .poop:
            return poopTexture.guidance.localized
        }
    }

    private var activityHero: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "checklist")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(selectedKind.color)
                    Text(activitySelectionSummary)
                        .font(BBBFont.font(size: 13, weight: .heavy))
                        .foregroundStyle(DesignToken.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    Spacer(minLength: 0)
                }

                if !customActivityItems.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("原记录")
                            .font(BBBFont.font(size: 13, weight: .heavy))
                            .foregroundStyle(DesignToken.textPrimary)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 74), spacing: 7)], alignment: .leading, spacing: 7) {
                            ForEach(customActivityItems) { item in
                                activityChip(item)
                            }
                        }
                    }
                }

                ForEach(QuickActivityCategory.allCases) { category in
                    activityCategorySection(category)
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 28)
            .padding(.horizontal, 14)
        }
        .scrollIndicators(.visible)
    }

    private func activityCategorySection(_ category: QuickActivityCategory) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: category.symbolName)
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(selectedKind.color)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(selectedKind.softColor.opacity(0.72)))
                Text(category.title.localized)
                    .font(BBBFont.font(size: 13, weight: .heavy))
                    .foregroundStyle(DesignToken.textPrimary)
                Spacer(minLength: 0)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 74), spacing: 7)], alignment: .leading, spacing: 7) {
                ForEach(category.items) { item in
                    activityChip(item)
                }
            }
        }
    }

    private func activityChip(_ item: QuickActivityItem) -> some View {
        let isSelected = selectedActivityItems.contains(item)

        return Button {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.86)) {
                if isSelected {
                    selectedActivityItems.remove(item)
                } else {
                    selectedActivityItems.insert(item)
                }
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            Text(item.title.localized)
                .font(BBBFont.font(size: 12, weight: .heavy))
                .foregroundStyle(isSelected ? .white : selectedKind.color)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .padding(.horizontal, 11)
                .frame(height: 36)
                .frame(maxWidth: .infinity)
                .background(Capsule().fill(isSelected ? selectedKind.color : selectedKind.softColor.opacity(0.62)))
                .overlay(Capsule().stroke(isSelected ? DesignToken.onPrimary.opacity(0.34) : selectedKind.color.opacity(0.16), lineWidth: 1))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var activitySelectionSummary: String {
        guard !selectedActivityItems.isEmpty else { return "选择今天刚做过的活动".localized }
        let categories = Set(selectedActivityItems.map(\.category)).count
        return AppLocalization.format(
            "已选 %d 项，将合并为 %d 条记录",
            selectedActivityItems.count,
            categories
        )
    }

    private var customActivityItems: [QuickActivityItem] {
        let availableIDs = Set(QuickActivityCategory.allCases.flatMap(\.items).map(\.id))
        return selectedActivityItems
            .filter { !availableIDs.contains($0.id) }
            .sorted { $0.title < $1.title }
    }

    private var controlBar: some View {
        HStack(spacing: 12) {
            stepButton(systemName: "minus") {
                adjustValue(-selectedKind.step)
            }
            .disabled(value <= selectedKind.valueRange.lowerBound)

            HStack(spacing: 8) {
                Spacer(minLength: 0)

                Text(displayedQuickValue)
                    .font(BBBFont.font(size: 38, weight: .heavy))
                    .foregroundStyle(DesignToken.textPrimary)
                    .monospacedDigit()
                Text(displayedQuickUnit)
                    .font(BBBFont.font(size: 19, weight: .heavy))
                    .foregroundStyle(DesignToken.textSecondary)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .frame(height: 58)
            .frame(maxWidth: .infinity)
            .background(Capsule().fill(DesignToken.surfaceSoft.opacity(0.88)))
            .overlay(Capsule().stroke(DesignToken.glassStroke.opacity(0.86), lineWidth: 1))

            stepButton(systemName: "plus") {
                adjustValue(selectedKind.step)
            }
            .disabled(value >= selectedKind.valueRange.upperBound)
        }
    }

    private var nursingTimerControls: some View {
        HStack(spacing: 10) {
            nursingTimerButton(side: .left)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(nursingTotalSeconds / 60)")
                    .font(BBBFont.font(size: 31, weight: .heavy))
                    .foregroundStyle(DesignToken.textPrimary)
                    .monospacedDigit()
                Text("min")
                    .font(BBBFont.font(size: 15, weight: .heavy))
                    .foregroundStyle(DesignToken.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(Capsule().fill(DesignToken.surfaceSoft.opacity(0.88)))
            .overlay(Capsule().stroke(DesignToken.glassStroke.opacity(0.86), lineWidth: 1))

            nursingTimerButton(side: .right)
        }
    }

    private func nursingTimerButton(side: BreastSide) -> some View {
        let isActive = currentActiveNursingSide == side
        let seconds = nursingSeconds(for: side)

        return Button {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.86)) {
                if editTarget == nil {
                    if feedingDraftStore.breastTimingStartedAt == nil {
                        feedingDraftStore.setBreastTiming(
                            leftSeconds: nursingLeftSeconds,
                            rightSeconds: nursingRightSeconds,
                            startedAt: Date()
                        )
                    }
                    feedingDraftStore.toggleBreastTimer(side)
                } else {
                    activeNursingSide = isActive ? nil : side
                }
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            VStack(spacing: 3) {
                HStack(spacing: 4) {
                    Text(side == .left ? "左" : "右")
                        .font(BBBFont.font(size: 10, weight: .heavy))
                    Image(systemName: isActive ? "pause.fill" : "play.fill")
                        .font(.system(size: 9, weight: .black))
                }
                Text(durationText(seconds))
                    .font(BBBFont.font(size: 10, weight: .heavy))
                    .monospacedDigit()
            }
            .foregroundStyle(isActive ? DesignToken.onPrimary : selectedKind.color)
            .frame(width: 84, height: 58)
            .background(
                Capsule(style: .continuous)
                    .fill(isActive ? selectedKind.color : DesignToken.glassFill.opacity(0.86))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(isActive ? DesignToken.onPrimary.opacity(0.34) : selectedKind.color.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: selectedKind.color.opacity(isActive ? 0.18 : 0.08), radius: 10, y: 5)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var nursingTotalSeconds: Int {
        nursingSeconds(for: .left) + nursingSeconds(for: .right)
    }

    private var currentActiveNursingSide: BreastSide? {
        editTarget == nil && feedingDraftStore.breastTimingStartedAt != nil
            ? feedingDraftStore.activeBreastSide
            : activeNursingSide
    }

    private func nursingSeconds(for side: BreastSide) -> Int {
        if editTarget == nil, feedingDraftStore.breastTimingStartedAt != nil {
            return feedingDraftStore.breastSeconds(for: side)
        }
        return side == .left ? nursingLeftSeconds : nursingRightSeconds
    }

    private func setNursingMinutes(_ side: BreastSide, minutes: Int) {
        let seconds = max(minutes, 0) * 60
        if editTarget == nil, feedingDraftStore.breastTimingStartedAt != nil {
            let left = side == .left ? seconds : nursingSeconds(for: .left)
            let right = side == .right ? seconds : nursingSeconds(for: .right)
            feedingDraftStore.setBreastTiming(
                leftSeconds: left,
                rightSeconds: right,
                startedAt: feedingDraftStore.breastTimingStartedAt
            )
        } else {
            activeNursingSide = nil
            if side == .left {
                nursingLeftSeconds = seconds
            } else {
                nursingRightSeconds = seconds
            }
        }
        value = max(nursingTotalSeconds / 60, 0)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func durationText(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainder = seconds % 60
        return String(format: "%02d:%02d", minutes, remainder)
    }

    private var saveButton: some View {
        let actionColor = primaryActionColor

        return Button {
            save()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22, weight: .bold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(
                        canSave ? actionColor : actionColor.opacity(0.72),
                        canSave ? DesignToken.onPrimary : actionColor.opacity(0.12)
                    )
                Text(saveButtonTitle)
                    .font(BBBFont.font(size: 19, weight: .heavy))
                    .foregroundStyle(canSave ? DesignToken.onPrimary : actionColor.opacity(0.78))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(
                Capsule()
                    .fill(
                        canSave
                            ? AnyShapeStyle(
                                LinearGradient(
                                    colors: [actionColor.opacity(0.82), actionColor],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            : AnyShapeStyle(actionColor.opacity(0.12))
                    )
            )
            .overlay(
                Capsule()
                    .stroke(canSave ? DesignToken.onPrimary.opacity(0.36) : actionColor.opacity(0.16), lineWidth: 1)
            )
            .shadow(color: actionColor.opacity(canSave ? 0.20 : 0), radius: 14, y: 8)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!canSave)
    }

    private var primaryActionColor: Color {
        selectedKind == .diaper ? diaperAccent : selectedKind.color
    }

    private func stepButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(selectedKind.color)
                .frame(width: 56, height: 56)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(DesignToken.glassFill.opacity(0.86)))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(DesignToken.glassStroke.opacity(0.86), lineWidth: 1))
                .shadow(color: DesignToken.shadowColor.opacity(0.10), radius: 8, y: 4)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var kindSwitcher: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(loopingQuickRecordKinds) { item in
                        let kind = item.kind
                        Button {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                                selectedKind = kind
                            }
                            centerKindSwitcher(proxy, on: kind, animated: true)
                        } label: {
                            HStack(spacing: 5) {
                                Text(kind.phaseLetter)
                                    .font(BBBFont.font(size: 10, weight: .heavy))
                                Text(kind.shortTitle.localized)
                                    .font(BBBFont.font(size: 12, weight: .heavy))
                            }
                            .foregroundStyle(selectedKind == kind ? .white : kind.color)
                            .padding(.horizontal, 11)
                            .frame(height: 32)
                            .background(
                                Capsule()
                                    .fill(selectedKind == kind ? kind.color : kind.softColor.opacity(0.72))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(selectedKind == kind ? DesignToken.onPrimary.opacity(0.38) : kind.color.opacity(0.14), lineWidth: 1)
                            )
                        }
                        .id(item.id)
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
                .padding(.horizontal, 18)
            }
            .frame(height: 36)
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: DesignToken.onPrimary, location: 0.035),
                        .init(color: DesignToken.onPrimary, location: 0.965),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .onAppear {
                centerKindSwitcher(proxy, on: selectedKind, animated: false)
            }
            .onChange(of: selectedKind) { _, newValue in
                centerKindSwitcher(proxy, on: newValue, animated: true)
            }
        }
    }

    private var loopingQuickRecordKinds: [LoopingQuickRecordKind] {
        (0..<Self.kindSwitcherLoopCount).flatMap { loop in
            QuickRecordKind.allCases.map { kind in
                LoopingQuickRecordKind(loop: loop, kind: kind)
            }
        }
    }

    private func kindSwitcherID(for kind: QuickRecordKind) -> String {
        "\(Self.kindSwitcherCenterLoop)-\(kind.rawValue)"
    }

    private func centerKindSwitcher(_ proxy: ScrollViewProxy, on kind: QuickRecordKind, animated: Bool) {
        let action = {
            proxy.scrollTo(kindSwitcherID(for: kind), anchor: .center)
        }

        if animated {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                action()
            }
        } else {
            DispatchQueue.main.async {
                action()
            }
        }
    }

    private func adjustValue(_ delta: Int) {
        let range = selectedKind.valueRange
        let direction = delta < 0 ? -1 : 1
        let canonicalStep: Int
        if AppMeasurementFormat.currentSystem == .imperial, selectedKind.usesBottleHero {
            canonicalStep = max(Int(AppMeasurementFormat.milliliters(fromVolumeValue: 0.5).rounded()), 1)
        } else if AppMeasurementFormat.currentSystem == .imperial, selectedKind == .solids {
            canonicalStep = max(Int(AppMeasurementFormat.grams(fromMassValue: 0.5).rounded()), 1)
        } else {
            canonicalStep = abs(delta)
        }
        value = min(max(value + direction * canonicalStep, range.lowerBound), range.upperBound)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private var quickBottleStep: Double {
        AppMeasurementFormat.currentSystem == .metric
            ? Double(selectedKind.step)
            : AppMeasurementFormat.milliliters(fromVolumeValue: 0.5)
    }

    private var displayedQuickValue: String {
        if selectedKind.usesBottleHero {
            return AppMeasurementFormat.inputNumber(
                AppMeasurementFormat.volumeValue(fromMilliliters: Double(value)),
                maximumFractionDigits: AppMeasurementFormat.currentSystem == .metric ? 0 : 1
            )
        }
        if selectedKind == .solids {
            return AppMeasurementFormat.inputNumber(
                AppMeasurementFormat.massValue(fromGrams: Double(value)),
                maximumFractionDigits: AppMeasurementFormat.currentSystem == .metric ? 0 : 1
            )
        }
        return String(value)
    }

    private var displayedQuickUnit: String {
        if selectedKind.usesBottleHero { return AppMeasurementFormat.volumeUnit }
        if selectedKind == .solids { return AppMeasurementFormat.massUnit }
        return selectedKind.unit.localized
    }

    private var bottleAmountBinding: Binding<Double> {
        Binding(
            get: { Double(value) },
            set: { newValue in
                let range = selectedKind.valueRange
                value = min(max(Int(newValue.rounded()), range.lowerBound), range.upperBound)
            }
        )
    }

    private var saveButtonTitle: String {
        if editTarget != nil {
            return "保存修改".localized
        }
        if selectedKind == .activity {
            return canSave ? "保存活动".localized : "选择活动".localized
        }
        guard selectedKind == .sleep else { return "保存".localized }
        if sleepMode == .justAsleep {
            return sleepDraftStore.isRecording ? "保存睡眠".localized : "开始计时".localized
        }
        return "保存睡眠".localized
    }

    private var canSave: Bool {
        switch selectedKind {
        case .activity:
            return !selectedActivityItems.isEmpty
        case .solids:
            return !selectedSolidFoods.isEmpty
        case .nursing:
            return nursingTotalSeconds > 0
        case .sleep:
            return sleepMode == .justAsleep || sleepDurationMinutes >= QuickRecordKind.sleep.valueRange.lowerBound
        default:
            return true
        }
    }

    private func configureDiaperDefaults(force: Bool) {
        guard selectedKind == .diaper else { return }
        guard force || !didConfigureDiaper else { return }

        didConfigureDiaper = true
        poopTexture = defaultPoopTexture
    }

    private var defaultPoopTexture: QuickPoopTexture {
        shouldPreferFormedPoop ? .formed : .paste
    }

    private var orderedPoopTextures: [QuickPoopTexture] {
        if shouldPreferFormedPoop {
            return [.formed, .paste, .watery, .mucus, .hard]
        }
        return [.paste, .watery, .formed, .mucus, .hard]
    }

    private var shouldPreferFormedPoop: Bool {
        BabyProfileStore.shared.currentProfile.ageMonths >= 4 || hasSolidFoodRecord
    }

    private var hasSolidFoodRecord: Bool {
        feedingStore.allSessions.contains { session in
            session.entries.contains { $0.type == .solid }
        }
    }

    private func configureSleepDefaults(force: Bool) {
        guard selectedKind == .sleep else { return }
        guard force || !didConfigureSleep else { return }

        didConfigureSleep = true
        if let activeStart = sleepDraftStore.activeSleepStartAt {
            sleepMode = .justAsleep
            sleepStartAt = activeStart
            sleepEndAt = Date()
            value = max(sleepDraftStore.elapsedSeconds / 60, QuickRecordKind.sleep.defaultValue)
            return
        }

        if let suggestion = smartSleepSuggestion {
            sleepMode = .smartFill
            sleepStartAt = suggestion.startAt
            sleepEndAt = suggestion.endAt
            value = sleepDurationMinutes
            return
        }

        sleepMode = .justWoke
        sleepEndAt = effectiveRecordedAt
        sleepStartAt = sleepEndAt.addingTimeInterval(TimeInterval(-QuickRecordKind.sleep.defaultValue * 60))
        value = QuickRecordKind.sleep.defaultValue
    }

    private func applySleepMode(_ mode: QuickSleepMode) {
        guard mode != .smartFill || smartSleepSuggestion != nil else { return }
        withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
            sleepMode = mode

            switch mode {
            case .justAsleep:
                sleepStartAt = sleepDraftStore.activeSleepStartAt ?? Date()
                sleepEndAt = Date()
                value = max(sleepDraftStore.elapsedSeconds / 60, QuickRecordKind.sleep.defaultValue)
            case .justWoke:
                sleepEndAt = effectiveRecordedAt
                value = QuickRecordKind.sleep.defaultValue
                sleepStartAt = sleepEndAt.addingTimeInterval(TimeInterval(-value * 60))
            case .smartFill:
                if let suggestion = smartSleepSuggestion {
                    sleepStartAt = suggestion.startAt
                    sleepEndAt = suggestion.endAt
                    value = sleepDurationMinutes
                }
            case .manual:
                if sleepEndAt <= sleepStartAt {
                    sleepEndAt = min(Date(), sleepStartAt.addingTimeInterval(TimeInterval(max(value, 1) * 60)))
                }
                value = sleepDurationMinutes
            }
        }
    }

    private func applySleepDuration(_ minutes: Int) {
        value = min(max(minutes, selectedKind.valueRange.lowerBound), selectedKind.valueRange.upperBound)
        guard sleepMode != .justAsleep else { return }
        sleepStartAt = sleepEndAt.addingTimeInterval(TimeInterval(-value * 60))
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func normalizedSleepWindow() -> (start: Date, end: Date)? {
        SleepRecordFormatter.normalizedWindow(
            startTime: sleepStartAt,
            endTime: sleepEndAt,
            anchorDate: sleepAnchorDate
        )
    }

    private var sleepAnchorDate: Date {
        recordDate ?? recordedAt
    }

    private func applyNormalizedSleepWindow(startTime: Date, endTime: Date) {
        guard let window = SleepRecordFormatter.normalizedWindow(
            startTime: startTime,
            endTime: endTime,
            anchorDate: sleepAnchorDate
        ) else {
            sleepStartAt = startTime
            sleepEndAt = min(endTime, Date())
            value = 0
            return
        }

        sleepStartAt = window.start
        sleepEndAt = window.end
        if editTarget != nil {
            recordedAt = window.start
        }
        value = sleepDurationMinutes
    }

    private var smartSleepSuggestion: QuickSleepSuggestion? {
        let now = Date()
        guard let cycle = targetSleepCycle,
              !cycle.linkedRecords.contains(where: { $0.phase == .sleep }) else {
            return fallbackCurrentCycleSleepSuggestion(now: now)
        }

        let starterEvents = starterEvents(for: cycle)
        guard let lastEvent = starterEvents.max(by: { $0.date < $1.date }) else { return nil }
        let start = lastEvent.date.addingTimeInterval(15 * 60)
        guard start < now else { return nil }

        let endCandidates = [
            cycle.endedAt,
            nextCycle(after: cycle)?.startedAt.addingTimeInterval(-10 * 60),
            now
        ].compactMap { $0 }
        let end = min(endCandidates.filter { $0 > start && $0 <= now }.min() ?? now, now)
        guard end.timeIntervalSince(start) >= 20 * 60 else { return nil }

        return QuickSleepSuggestion(
            startAt: start,
            endAt: end,
            reason: AppLocalization.format(
                "根据本轮 %@ %@ 推测",
                sleepClockText(lastEvent.date),
                lastEvent.title.localized
            )
        )
    }

    private var targetSleepCycle: EasyCycle? {
        if let targetCycleID,
           let cycle = easyCycleStore.cycles.first(where: { $0.id == targetCycleID }) {
            return cycle
        }

        return easyCycleStore.currentCycle(on: effectiveRecordedAt)
    }

    private func fallbackCurrentCycleSleepSuggestion(now: Date) -> QuickSleepSuggestion? {
        guard let cycle = easyCycleStore.currentCycle(on: now),
              !cycle.linkedRecords.contains(where: { $0.phase == .sleep }) else {
            return nil
        }

        let starterEvents = starterEvents(for: cycle)
        guard let lastEvent = starterEvents.max(by: { $0.date < $1.date }) else { return nil }
        let start = lastEvent.date.addingTimeInterval(15 * 60)
        guard start < now, now.timeIntervalSince(start) >= 20 * 60 else { return nil }

        return QuickSleepSuggestion(
            startAt: start,
            endAt: now,
            reason: AppLocalization.format(
                "根据当前轮 %@ %@ 推测",
                sleepClockText(lastEvent.date),
                lastEvent.title.localized
            )
        )
    }

    private func starterEvents(for cycle: EasyCycle) -> [(date: Date, title: String)] {
        cycle.linkedRecords.compactMap { link -> (date: Date, title: String)? in
            switch link.type {
            case .feeding:
                guard link.phase == .eat,
                      let session = feedingStore.allSessions.first(where: { $0.id == link.recordID }) else {
                    return nil
                }
                return (session.startAt ?? session.createdAt, "喂养")
            case .care:
                guard link.phase == .activity,
                      let record = activityStore.exportCareRecords().first(where: { $0.id == link.recordID }) else {
                    return nil
                }
                return (record.recordedAt, record.kind == .diaper ? "尿布" : record.title)
            }
        }
    }

    private func nextCycle(after cycle: EasyCycle) -> EasyCycle? {
        easyCycleStore.cycles
            .filter { $0.startedAt > cycle.startedAt }
            .min { $0.startedAt < $1.startedAt }
    }

    private func sleepClockText(_ date: Date) -> String {
        AppDateTimeFormat.time(date)
    }

    private func sleepQuickDurationText(_ minutes: Int) -> String {
        SleepRecordFormatter.durationText(minutes: minutes)
    }

    private func save() {
        if let editTarget {
            update(editTarget)
            return
        }

        if selectedKind == .sleep {
            saveSleep()
            return
        }

        let submittedAt = effectiveRecordedAt
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        let context: SubjectiveStatePromptContext?
        switch selectedKind {
        case .formulaBottle:
            context = saveBottle(milkType: .formula, recordedAt: submittedAt)
        case .expressedBottle:
            context = saveBottle(milkType: .expressed, recordedAt: submittedAt)
        case .nursing:
            context = saveNursing(recordedAt: submittedAt)
        case .solids:
            context = saveSolids(recordedAt: submittedAt)
        case .diaper:
            context = saveDiaper(recordedAt: submittedAt)
        case .activity:
            context = saveActivities(recordedAt: submittedAt)
        case .sleep:
            context = nil
        case .bath, .tummyTime, .massage, .story, .outdoor, .play, .toothbrushing:
            context = activityStore.recordActivity(title: selectedKind.title, recordedAt: submittedAt).map {
                SubjectiveStatePromptContext(sourceType: .care, sourceRecordID: $0.id, recordedAt: $0.recordedAt)
            }
        }

        rebuildEasyCyclesAfterRecordChange()
        finish(with: context)
    }

    private func update(_ target: QuickRecordEditTarget) {
        guard canSave else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        switch target {
        case .feeding(let session):
            guard let entries = currentFeedingEntries(), !entries.isEmpty else { return }
            let updated = FeedingSession(
                id: session.id,
                entries: entries,
                notes: session.notes,
                imageData: session.imageData,
                babyMood: session.babyMood,
                createdAt: effectiveRecordedAt,
                startAt: nil,
                endAt: nil,
                timeSpanSource: .point
            )
            feedingStore.updateSession(updated)

        case .care(let record):
            switch record.kind {
            case .diaper:
                activityStore.updateDiaperRecord(
                    record,
                    type: diaperMode.recordType.rawValue,
                    detail: diaperRecordDetail,
                    note: record.note,
                    recordedAt: effectiveRecordedAt
                )

            case .activity:
                guard let title = activityRecordTitle else { return }
                activityStore.updateActivityRecord(
                    record,
                    title: title,
                    recordedAt: effectiveRecordedAt,
                    note: record.note
                )

            case .sleep:
                guard let window = normalizedSleepWindow() else { return }
                activityStore.updateSleepRecord(
                    record,
                    startTime: window.start,
                    endTime: window.end,
                    note: record.note
                )
            }
        }

        rebuildEasyCyclesAfterRecordChange()
        let context: SubjectiveStatePromptContext
        switch target {
        case .feeding(let session):
            context = SubjectiveStatePromptContext(
                sourceType: .feeding,
                sourceRecordID: session.id,
                recordedAt: effectiveRecordedAt
            )
        case .care(let record):
            let date = record.kind == .sleep ? (normalizedSleepWindow()?.start ?? effectiveRecordedAt) : effectiveRecordedAt
            context = SubjectiveStatePromptContext(sourceType: .care, sourceRecordID: record.id, recordedAt: date)
        }
        finish(with: context)
    }

    private var effectiveRecordedAt: Date {
        min(recordedAt, Date())
    }

    private func saveActivities(recordedAt: Date) -> SubjectiveStatePromptContext? {
        guard let title = activityRecordTitle else { return nil }
        return activityStore.recordActivity(
            title: title,
            recordedAt: recordedAt
        ).map { SubjectiveStatePromptContext(sourceType: .care, sourceRecordID: $0.id, recordedAt: $0.recordedAt) }
    }

    private var activityRecordTitle: String? {
        let titles = selectedActivityItems.map(\.title).sorted()
        guard !titles.isEmpty else { return nil }
        return titles.joined(separator: " ")
    }

    private func saveDiaper(recordedAt: Date) -> SubjectiveStatePromptContext? {
        activityStore.recordDiaper(
            type: diaperMode.recordType.rawValue,
            detail: diaperRecordDetail,
            note: "",
            recordedAt: recordedAt
        ).map { SubjectiveStatePromptContext(sourceType: .care, sourceRecordID: $0.id, recordedAt: $0.recordedAt) }
    }

    private var diaperRecordDetail: String {
        switch diaperMode {
        case .pee:
            return urineAmount.detail
        case .poop:
            return poopTexture.detail
        }
    }

    private func saveSleep() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        var writtenRecord: CareRecord?

        switch sleepMode {
        case .justAsleep:
            if let activeStart = sleepDraftStore.activeSleepStartAt {
                let end = Date()
                guard end > activeStart else { return }
                if let record = activityStore.recordSleep(startTime: activeStart, endTime: end, note: "") {
                    sleepDraftStore.resetDraft()
                    writtenRecord = record
                }
            } else {
                sleepDraftStore.start(at: Date())
            }
        case .justWoke, .smartFill, .manual:
            guard let window = normalizedSleepWindow() else { return }
            guard Int(window.end.timeIntervalSince(window.start) / 60) >= QuickRecordKind.sleep.valueRange.lowerBound else { return }
            writtenRecord = activityStore.recordSleep(startTime: window.start, endTime: window.end, note: "")
        }

        if let writtenRecord {
            rebuildEasyCyclesAfterRecordChange()
            finish(with: SubjectiveStatePromptContext(
                sourceType: .care,
                sourceRecordID: writtenRecord.id,
                recordedAt: writtenRecord.recordedAt
            ))
        } else {
            onDismiss()
        }
    }

    private func rebuildEasyCyclesAfterRecordChange() {
        easyCycleStore.rebuild(
            from: feedingStore.allSessions,
            careRecords: activityStore.exportCareRecords()
        )
    }

    private func saveBottle(milkType: MilkType, recordedAt: Date) -> SubjectiveStatePromptContext {
        let session = FeedingSession(
            entries: bottleEntries(milkType: milkType),
            notes: "",
            babyMood: .happy,
            createdAt: recordedAt
        )
        feedingStore.saveSession(session)
        return SubjectiveStatePromptContext(sourceType: .feeding, sourceRecordID: session.id, recordedAt: recordedAt)
    }

    private func saveNursing(recordedAt: Date) -> SubjectiveStatePromptContext? {
        let entries = nursingEntries()
        guard !entries.isEmpty else { return nil }
        let timingStart = editTarget == nil ? feedingDraftStore.breastTimingStartedAt : nil
        let session = FeedingSession(
            entries: entries,
            notes: "",
            babyMood: .happy,
            createdAt: recordedAt,
            startAt: timingStart,
            endAt: timingStart == nil ? nil : recordedAt,
            timeSpanSource: timingStart == nil ? .point : .confirmed
        )
        feedingStore.saveSession(session)
        if editTarget == nil, timingStart != nil {
            feedingDraftStore.resetDraft()
        }
        return SubjectiveStatePromptContext(
            sourceType: .feeding,
            sourceRecordID: session.id,
            recordedAt: session.startAt ?? session.createdAt
        )
    }

    private func saveSolids(recordedAt: Date) -> SubjectiveStatePromptContext? {
        let entries = solidEntries()
        guard !entries.isEmpty else { return nil }
        let session = FeedingSession(
            entries: entries,
            notes: "",
            babyMood: .happy,
            createdAt: recordedAt
        )
        feedingStore.saveSession(session)
        return SubjectiveStatePromptContext(sourceType: .feeding, sourceRecordID: session.id, recordedAt: recordedAt)
    }

    private func finish(with context: SubjectiveStatePromptContext?) {
        onDismiss()
        guard let context else { return }
        DispatchQueue.main.async {
            onCompletedRecord(context)
        }
    }

    private func currentFeedingEntries() -> [FeedingEntry]? {
        switch selectedKind {
        case .formulaBottle:
            return bottleEntries(milkType: .formula)
        case .expressedBottle:
            return bottleEntries(milkType: .expressed)
        case .nursing:
            return nursingEntries()
        case .solids:
            return solidEntries()
        default:
            return nil
        }
    }

    private func bottleEntries(milkType: MilkType) -> [FeedingEntry] {
        [FeedingEntry(
            type: .bottle,
            milkType: milkType,
            bottleAmount: value
        )]
    }

    private func nursingEntries() -> [FeedingEntry] {
        let leftMinutes = nursingMinutes(from: nursingSeconds(for: .left))
        let rightMinutes = nursingMinutes(from: nursingSeconds(for: .right))
        var entries: [FeedingEntry] = []
        if leftMinutes > 0 {
            entries.append(FeedingEntry(
                type: .breast,
                breastMode: .nursing,
                breastSide: .left,
                breastDuration: leftMinutes
            ))
        }
        if rightMinutes > 0 {
            entries.append(FeedingEntry(
                type: .breast,
                breastMode: .nursing,
                breastSide: .right,
                breastDuration: rightMinutes
            ))
        }
        return entries
    }

    private func solidEntries() -> [FeedingEntry] {
        let foods = selectedSolidFoods.sorted { $0.displayName < $1.displayName }
        guard !foods.isEmpty else { return [] }
        let amountPerFood = Double(value) / Double(max(foods.count, 1))
        return foods.map { food in
            FeedingEntry(
                type: .solid,
                solidFood: food,
                solidAmount: amountPerFood,
                solidUnit: .g
            )
        }
    }

    private func nursingMinutes(from seconds: Int) -> Int {
        guard seconds > 0 else { return 0 }
        return max(Int((Double(seconds) / 60.0).rounded()), 1)
    }
}

#if DEBUG
struct QuickRecordDarkModeDemo: View {
    var body: some View {
        QuickRecordCardOverlay(initialKind: .formulaBottle, onDismiss: {})
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
#endif

private struct QuickBreastMinuteArcScale: View {
    let side: BreastSide
    let seconds: Int
    let accent: Color
    let onSetMinutes: (Int) -> Void

    private var currentMinutes: Int {
        min(max(Int(round(Double(seconds) / 60.0)), 5), 30)
    }

    private var hasValue: Bool {
        seconds > 0
    }

    private var progress: CGFloat {
        hasValue ? CGFloat(currentMinutes - 5) / 25.0 : 0
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let isLeft = side == .left

            ZStack {
                arcPath(width: width, height: height, isLeft: isLeft)
                    .stroke(
                        LinearGradient(
                            colors: [
                                DesignToken.onPrimary.opacity(0.22),
                                accent.opacity(0.16),
                                DesignToken.onPrimary.opacity(0.14)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        style: StrokeStyle(lineWidth: 7, lineCap: .round)
                    )

                arcPath(width: width, height: height, isLeft: isLeft)
                    .trimmedPath(from: max(0, 1 - progress), to: 1)
                    .stroke(
                        LinearGradient(
                            colors: [
                                DesignToken.onPrimary.opacity(0.34),
                                accent.opacity(0.92),
                                accent.opacity(0.62)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        style: StrokeStyle(lineWidth: 7, lineCap: .round)
                    )
                    .shadow(color: accent.opacity(0.24), radius: 7)
                    .animation(.spring(response: 0.34, dampingFraction: 0.78), value: progress)

                ForEach([5, 10, 15, 20, 25, 30], id: \.self) { minute in
                    let point = arcPoint(for: minute, width: width, height: height, isLeft: isLeft)
                    let tickLength: CGFloat = minute == 5 || minute == 15 || minute == 30 ? 13 : 7
                    let tickCenterX = isLeft ? point.x - tickLength * 0.48 : point.x + tickLength * 0.48
                    let labelX = isLeft ? point.x - tickLength - 14 : point.x + tickLength + 14
                    let highlighted = hasValue && minute == currentMinutes
                    let showsLabel = minute == 5 || minute == 30

                    Capsule(style: .continuous)
                        .fill(accent.opacity(highlighted ? 0.96 : 0.42))
                        .frame(width: tickLength, height: highlighted ? 3 : 2)
                        .position(x: tickCenterX, y: point.y)
                        .animation(.spring(response: 0.26, dampingFraction: 0.78), value: highlighted)

                    if highlighted {
                        Circle()
                            .fill(accent.opacity(0.95))
                            .frame(width: 8, height: 8)
                            .overlay(Circle().stroke(DesignToken.onPrimary.opacity(0.78), lineWidth: 1))
                            .shadow(color: accent.opacity(0.34), radius: 5)
                            .position(x: point.x, y: point.y)
                            .transition(.scale(scale: 0.55).combined(with: .opacity))
                    }

                    if showsLabel {
                        Text("\(minute)")
                            .font(BBBFont.font(size: highlighted ? 11 : 9, weight: .bold))
                            .foregroundStyle(accent.opacity(highlighted ? 0.98 : 0.68))
                            .monospacedDigit()
                            .frame(width: 24, height: 18)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(DesignToken.onPrimary.opacity(highlighted ? 0.44 : 0.20))
                                    .overlay(Capsule(style: .continuous).stroke(accent.opacity(highlighted ? 0.34 : 0.14), lineWidth: 1))
                            )
                            .position(x: labelX, y: point.y)
                            .animation(.spring(response: 0.26, dampingFraction: 0.78), value: highlighted)
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        onSetMinutes(minute(for: value.location.y, height: height))
                    }
            )
        }
    }

    private func arcPath(width: CGFloat, height: CGFloat, isLeft: Bool) -> Path {
        var path = Path()
        if isLeft {
            path.move(to: CGPoint(x: width * 0.72, y: height * 0.04))
            path.addQuadCurve(
                to: CGPoint(x: width * 0.72, y: height * 0.96),
                control: CGPoint(x: width * 0.28, y: height * 0.50)
            )
        } else {
            path.move(to: CGPoint(x: width * 0.28, y: height * 0.04))
            path.addQuadCurve(
                to: CGPoint(x: width * 0.28, y: height * 0.96),
                control: CGPoint(x: width * 0.72, y: height * 0.50)
            )
        }
        return path
    }

    private func arcPoint(for minute: Int, width: CGFloat, height: CGFloat, isLeft: Bool) -> CGPoint {
        let normalized = CGFloat(minute - 5) / 25.0
        let t = 1 - normalized
        let start = CGPoint(x: width * (isLeft ? 0.72 : 0.28), y: height * 0.04)
        let control = CGPoint(x: width * (isLeft ? 0.28 : 0.72), y: height * 0.50)
        let end = CGPoint(x: width * (isLeft ? 0.72 : 0.28), y: height * 0.96)
        let oneMinusT = 1 - t
        return CGPoint(
            x: oneMinusT * oneMinusT * start.x + 2 * oneMinusT * t * control.x + t * t * end.x,
            y: oneMinusT * oneMinusT * start.y + 2 * oneMinusT * t * control.y + t * t * end.y
        )
    }

    private func minute(for y: CGFloat, height: CGFloat) -> Int {
        let normalized = min(max((height * 0.92 - y) / (height * 0.84), 0), 1)
        let raw = 5 + normalized * 25
        return min(max(Int(round(raw)), 5), 30)
    }
}

private extension View {
    @ViewBuilder
    func dockGlass<S: Shape>(shape: S) -> some View {
        if #available(iOS 26.0, *) {
            self
                .glassEffect(.regular.tint(DesignToken.glassFill.opacity(0.44)).interactive(), in: shape)
        } else {
            self
                .background(.ultraThinMaterial, in: shape)
                .overlay(shape.stroke(DesignToken.glassStroke.opacity(0.72), lineWidth: 1))
                .shadow(color: DesignToken.shadowColor.opacity(0.22), radius: 18, y: 8)
        }
    }
}

private struct SystemTabBarHiddenController: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller {
        Controller()
    }

    func updateUIViewController(_ uiViewController: Controller, context: Context) {
        uiViewController.hideSystemTabBar()
    }

    final class Controller: UIViewController {
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            hideSystemTabBar()
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            hideSystemTabBar()
        }

        func hideSystemTabBar() {
            if let tabBarController {
                tabBarController.tabBar.isHidden = true
                tabBarController.tabBar.alpha = 0
            }

            view.window?.hideAllSystemTabBars()
        }
    }
}

private extension UIWindow {
    func hideAllSystemTabBars() {
        subviews.forEach { $0.hideSystemTabBarsInHierarchy() }
    }
}

private extension UIView {
    func hideSystemTabBarsInHierarchy() {
        if let tabBar = self as? UITabBar {
            tabBar.isHidden = true
            tabBar.alpha = 0
        }

        subviews.forEach { $0.hideSystemTabBarsInHierarchy() }
    }
}

private enum RecordSheet: Identifiable {
    case diaper
    case sleep
    case weight
    case height

    var id: String {
        switch self {
        case .diaper: return "diaper"
        case .sleep: return "sleep"
        case .weight: return "weight"
        case .height: return "height"
        }
    }
}
