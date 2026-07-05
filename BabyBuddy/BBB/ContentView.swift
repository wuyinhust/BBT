import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var feedingDraftStore: FeedingDraftStore
    @EnvironmentObject private var sleepDraftStore: SleepDraftStore
    @AppStorage("has_completed_onboarding") private var hasCompletedOnboarding = false
    @AppStorage(RecordHomeMode.storageKey) private var recordHomeModeRaw = RecordHomeMode.basic.rawValue

    @State private var selectedTab: RootTab = .record
    @State private var showCompanionPicker = false
    @State private var activeRecordSheet: RecordSheet?
    @State private var activeQuickRecordKind: QuickRecordKind?
    @State private var activeQuickRecordCycleID: UUID?
    @State private var activeQuickRecordDate: Date?
    @State private var showBabyInfo = false
    @State private var showQuickAddMenu = false
    @State private var showYearningDetailFromQuickAdd = false
    @State private var recordStackResetID = UUID()
    @State private var companionStackResetID = UUID()
    @State private var growthStackResetID = UUID()

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
            .onChange(of: showBabyInfo) { _, isPresented in
                if isPresented {
                    dismissQuickAddMenu()
                }
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
            .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { date in
                if feedingDraftStore.isRecording {
                    feedingDraftStore.updateCurrentTime(date)
                }
                if sleepDraftStore.isRecording {
                    sleepDraftStore.updateCurrentTime(date)
                }
            }
            .sheet(isPresented: $showCompanionPicker) {
                CompanionPickerView(isPresented: $showCompanionPicker)
            }
            .sheet(isPresented: recordSheetBinding(for: .feeding)) {
                recordSheetContent(for: .feeding)
            }
            .fullScreenCover(item: nonFeedingRecordSheetBinding) { sheet in
                recordSheetContent(for: sheet)
            }
            .sheet(isPresented: $showBabyInfo) {
                BabyInfoEditView(isPresented: $showBabyInfo)
            }
    }

    private var tabViewShell: some View {
        rootTabs
            .toolbar(.hidden, for: .tabBar)
            .background(SystemTabBarHiddenController())
            .tint(DesignToken.primary)
            .safeAreaInset(edge: .bottom) {
                Color.clear
                    .frame(height: bottomDockContentClearance)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .bottom) {
                bottomDockOverlay
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
                        onOpenFullRecord: { sheet in
                            closeQuickRecordCard()
                            openRecordSheet(sheet)
                        }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
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
                        showBabyInfo: $showBabyInfo,
                        showYearningDetailRequest: $showYearningDetailFromQuickAdd,
                        openFeedSheet: { recordDate in
                            openQuickRecordCard(.formulaBottle, recordDate: recordDate)
                        },
                        openActivitySheet: { recordDate in
                            openQuickRecordCard(.diaper, recordDate: recordDate)
                        },
                        openSleepSheet: { recordDate in
                            openQuickRecordCard(.sleep, recordDate: recordDate)
                        },
                        openSleepSheetForCycle: { cycleID, recordDate in
                            openQuickRecordCard(.sleep, targetCycleID: cycleID, recordDate: recordDate)
                        },
                        dismissQuickAddMenu: {
                            dismissQuickAddMenu()
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
                            openRecordSheet(.feeding)
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

    private var bottomDockOverlay: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                if shouldShowBottomDock {
                    BottomDockVisualProtection(safeAreaBottom: proxy.safeAreaInsets.bottom)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }

                if shouldShowBottomDock {
                    BottomNavigationDock(
                        selectedTab: $selectedTab,
                        isQuickAddExpanded: $showQuickAddMenu,
                        safeAreaBottom: proxy.safeAreaInsets.bottom,
                        onTabSelected: handleTabSelection,
                        onEat: { openRecordSheet(.feeding) },
                        onPoop: { openQuickRecordCard(.diaper) },
                        onYearning: {
                            dismissQuickAddMenu()
                            selectedTab = .record
                            showYearningDetailFromQuickAdd = true
                        },
                        onSleep: { openRecordSheet(.sleep) }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                statusButtonsOverlay(safeAreaBottom: proxy.safeAreaInsets.bottom)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
    }

    private func statusButtonsOverlay(safeAreaBottom: CGFloat) -> some View {
        VStack(alignment: .trailing, spacing: 10) {
            if shouldShowFeedingStatus {
                feedingStatusButton
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
            }

            if shouldShowSleepStatus {
                sleepStatusButton
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
            }
        }
        .padding(.bottom, statusBottomPadding(safeAreaBottom: safeAreaBottom))
        .padding(.trailing, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
    }

    @ViewBuilder
    private func recordSheetContent(for sheet: RecordSheet) -> some View {
        switch sheet {
        case .feeding:
            FeedingSheet(isPresented: recordSheetBinding(for: .feeding))
                .toolbar(.hidden, for: .tabBar)
                .presentationDetents([.fraction(0.92), .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(34)
                .presentationBackground(DesignToken.canvas)
        case .diaper:
            DiaperSheet(isPresented: recordSheetBinding(for: .diaper))
                .ignoresSafeArea()
                .toolbar(.hidden, for: .tabBar)
                .presentationBackground(Color(hex: "#DDD5FF"))
        case .sleep:
            SleepSheet(isPresented: recordSheetBinding(for: .sleep))
                .ignoresSafeArea()
                .toolbar(.hidden, for: .tabBar)
                .presentationBackground(Color(hex: "#DDD5FF"))
        case .weight:
            GrowthMetricSheet(kind: .weight, isPresented: recordSheetBinding(for: .weight))
                .ignoresSafeArea()
                .toolbar(.hidden, for: .tabBar)
                .presentationBackground(Color(hex: "#DDD5FF"))
        case .height:
            GrowthMetricSheet(kind: .height, isPresented: recordSheetBinding(for: .height))
                .ignoresSafeArea()
                .toolbar(.hidden, for: .tabBar)
                .presentationBackground(Color(hex: "#DDD5FF"))
        }
    }

    private var nonFeedingRecordSheetBinding: Binding<RecordSheet?> {
        Binding {
            guard activeRecordSheet != .feeding else { return nil }
            return activeRecordSheet
        } set: { value in
            activeRecordSheet = value
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
                showBabyInfo = false
            }
        }
    }

    private func openRecordSheet(_ sheet: RecordSheet) {
        dismissQuickAddMenu()
        activeRecordSheet = sheet
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

    private var shouldShowFeedingStatus: Bool {
        feedingDraftStore.hasDraft && activeRecordSheet != .feeding
    }

    private var shouldShowSleepStatus: Bool {
        sleepDraftStore.isRecording && activeRecordSheet != .sleep
    }

    private var shouldShowBottomDock: Bool {
        activeRecordSheet == nil
    }

    private var bottomDockContentClearance: CGFloat {
        92
    }

    private func statusBottomPadding(safeAreaBottom: CGFloat) -> CGFloat {
        max(safeAreaBottom, 10) + 82
    }

    private var feedingStatusButton: some View {
        HStack(spacing: 8) {
            Button {
                openRecordSheet(.feeding)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: feedingDraftStore.statusIcon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(DesignToken.primaryGradient))

                    VStack(alignment: .leading, spacing: 1) {
                        Text("喂养记录中")
                            .font(BBBFont.font(size: 12, weight: .bold))
                            .foregroundStyle(DesignToken.textPrimary)
                        Text("\(feedingDraftStore.statusTitle) · \(feedingDraftStore.statusDetail)")
                            .font(BBBFont.font(size: 11, weight: .semibold))
                            .foregroundStyle(DesignToken.textSecondary)
                            .lineLimit(1)
                    }
                }
            }
            .buttonStyle(.plain)

            Button {
                feedingDraftStore.resetDraft()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(DesignToken.textSecondary)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(DesignToken.iconSoftBG))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("关闭喂养记录")
        }
        .padding(.leading, 7)
        .padding(.trailing, 8)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(.white.opacity(0.96))
                .shadow(color: Color(hex: "#4D4B70").opacity(0.12), radius: 14, y: 7)
        )
        .buttonStyle(ScaleButtonStyle())
    }

    private var sleepStatusButton: some View {
        return Button {
            openRecordSheet(.sleep)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color(hex: "#6DA5F2")))

                VStack(alignment: .leading, spacing: 1) {
                    Text("睡眠记录中")
                        .font(BBBFont.font(size: 12, weight: .bold))
                        .foregroundStyle(DesignToken.textPrimary)
                    Text("已睡 \(sleepDraftStore.statusDetail)")
                        .font(BBBFont.font(size: 11, weight: .semibold))
                        .foregroundStyle(DesignToken.textSecondary)
                        .lineLimit(1)
                }
            }
            .padding(.leading, 7)
            .padding(.trailing, 12)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(.white.opacity(0.96))
                    .shadow(color: Color(hex: "#4D4B70").opacity(0.12), radius: 14, y: 7)
            )
        }
        .buttonStyle(ScaleButtonStyle())
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
    let safeAreaBottom: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            bottomMaterial
        }
        .ignoresSafeArea(.container, edges: .bottom)
    }

    private var bottomMaterial: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .overlay(
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(0), location: 0),
                        .init(color: .white.opacity(0.28), location: 0.56),
                        .init(color: .white.opacity(0.56), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black.opacity(0.46), location: 0.44),
                        .init(color: .black, location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(height: max(108, safeAreaBottom + 82))
    }
}

private struct BottomNavigationDock: View {
    @Binding var selectedTab: RootTab
    @Binding var isQuickAddExpanded: Bool
    let safeAreaBottom: CGFloat
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
        .padding(.bottom, max(safeAreaBottom - 6, 12))
        .offset(y: safeAreaBottom)
        .ignoresSafeArea(.container, edges: .bottom)
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
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .contentShape(Circle())
                    .rotationEffect(.degrees(isExpanded ? 45 : 0))
            }
            .buttonStyle(.plain)
            .background(mainButtonSurface)
            .overlay(Circle().stroke(.white.opacity(0.38), lineWidth: 1))
            .shadow(color: Color(hex: "#6D4DDB").opacity(0.18), radius: 16, y: 8)
            .accessibilityLabel(isExpanded ? "收起记录菜单" : "打开记录菜单")
        }
        .animation(.interactiveSpring(response: 0.28, dampingFraction: 0.82), value: isExpanded)
    }

    private var quickActionMenu: some View {
        ZStack(alignment: .bottomTrailing) {
            quickActionButton(
                assetName: "record_action_easy_eat_icon",
                accessibilityLabel: "记录喂养",
                tint: DesignToken.easyEat,
                angle: 0,
                index: 0,
                action: onEat
            )

            quickActionButton(
                assetName: "record_action_easy_activity_icon",
                accessibilityLabel: "记录活动",
                tint: DesignToken.easyActivity,
                angle: 30,
                index: 1,
                action: onPoop
            )

            quickActionButton(
                assetName: "record_action_easy_sleep_icon",
                accessibilityLabel: "记录睡眠",
                tint: DesignToken.easySleep,
                angle: 60,
                index: 2,
                action: onSleep
            )

            quickActionButton(
                assetName: "record_action_easy_yearning_icon",
                accessibilityLabel: "查看 Yearning 详情",
                tint: DesignToken.easyYearning,
                angle: 90,
                index: 3,
                action: onYearning
            )
        }
    }

    private func quickActionButton(
        assetName: String,
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
                Image(assetName)
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFill()
                    .frame(width: 38, height: 38)
                    .clipShape(Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .background(
                Circle()
                    .fill(.white.opacity(0.24))
            )
            .overlay(
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.82),
                                tint.opacity(0.28)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                    lineWidth: 0.9
                )
            )
        .shadow(color: tint.opacity(0.14), radius: 8, y: 4)
        .shadow(color: Color.black.opacity(0.04), radius: 2, y: 1)
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
                                Color.white.opacity(0.24),
                                Color.white.opacity(0.04),
                                Color(hex: "#3B2A8F").opacity(0.16)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
    }

    private static let babyAgeGradient = LinearGradient(
        colors: [
            Color(hex: "#7A5BEF"),
            Color(hex: "#9D7BFF"),
            Color(hex: "#6B8EF6")
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

    var easyIconAssetName: String {
        switch self {
        case .formulaBottle, .expressedBottle, .nursing, .solids:
            return "record_action_easy_eat_icon"
        case .diaper, .activity, .bath, .tummyTime, .massage, .story, .outdoor, .play, .toothbrushing:
            return "record_action_easy_activity_icon"
        case .sleep:
            return "record_action_easy_sleep_icon"
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
        case .formulaBottle, .expressedBottle: return 10...300
        case .nursing: return 1...60
        case .solids: return 5...300
        case .diaper: return 1...6
        case .activity: return 1...120
        case .bath, .tummyTime, .massage, .story, .outdoor, .play: return 1...120
        case .toothbrushing: return 1...10
        case .sleep: return 5...720
        }
    }

    var fullRecordSheet: RecordSheet {
        switch self {
        case .formulaBottle, .expressedBottle, .nursing, .solids:
            return .feeding
        case .diaper, .activity, .bath, .tummyTime, .massage, .story, .outdoor, .play, .toothbrushing:
            return .diaper
        case .sleep:
            return .sleep
        }
    }

    var placeholderText: String {
        switch self {
        case .formulaBottle, .expressedBottle:
            return "图片素材待接入，后续可做液面互动"
        case .nursing:
            return "后续接入左右亲喂互动"
        case .solids:
            return "后续接入辅食碗/勺互动"
        case .diaper:
            return "后续接入尿布/护理素材"
        case .activity:
            return "多选活动，按类型合并记录"
        case .sleep:
            return "后续接入睡眠小环互动"
        default:
            return "后续接入活动素材"
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
        "尿量：\(title)"
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
        "便便：\(title) · \(guidance)"
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
            return ["趴卧", "抚触", "排气操", "排嗝", "飞机抱", "对视聊天", "照镜子", "黑白卡", "追物训练", "抓握"]
                .map { QuickActivityItem(category: self, title: $0) }
        case .family:
            return ["绘本", "布书", "音乐律动", "听儿歌", "健身架", "悬挂玩具", "户外活动", "室内活动"]
                .map { QuickActivityItem(category: self, title: $0) }
        case .care:
            return ["洗澡", "剪指甲"]
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

private struct QuickRecordCardOverlay: View {
    @EnvironmentObject private var feedingStore: FeedingStore
    @EnvironmentObject private var activityStore: ActivityStore
    @EnvironmentObject private var sleepDraftStore: SleepDraftStore
    @EnvironmentObject private var easyCycleStore: EasyCycleStore

    let initialKind: QuickRecordKind
    let targetCycleID: UUID?
    let recordDate: Date?
    let onDismiss: () -> Void
    let onOpenFullRecord: (RecordSheet) -> Void

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

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
    private static let kindSwitcherLoopCount = 5
    private static let kindSwitcherCenterLoop = 2

    init(
        initialKind: QuickRecordKind,
        targetCycleID: UUID? = nil,
        recordDate: Date? = nil,
        onDismiss: @escaping () -> Void,
        onOpenFullRecord: @escaping (RecordSheet) -> Void
    ) {
        self.initialKind = initialKind
        self.targetCycleID = targetCycleID
        self.recordDate = recordDate
        self.onDismiss = onDismiss
        self.onOpenFullRecord = onOpenFullRecord
        _selectedKind = State(initialValue: initialKind)
        _value = State(initialValue: initialKind.defaultValue)
        _recordedAt = State(initialValue: Self.defaultRecordedAt(for: recordDate))
    }

    var body: some View {
        ZStack {
            Color(hex: "#191827")
                .opacity(0.20)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            VStack(spacing: 12) {
                quickCard
                kindSwitcher
                    .padding(.horizontal, 2)
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: 430)
        }
        .onChange(of: selectedKind) { _, newValue in
            value = newValue.defaultValue
            activeNursingSide = nil
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
            guard selectedKind == .nursing, let activeNursingSide else { return }
            if activeNursingSide == .left {
                nursingLeftSeconds += 1
            } else {
                nursingRightSeconds += 1
            }
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

    private var quickCard: some View {
        VStack(spacing: 16) {
            header
            if showRecordTimePicker {
                recordTimeEditor
                    .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
            }
            hero
            if selectedKind == .sleep {
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
            saveButton
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.96), Color(hex: "#F9F6FF").opacity(0.94)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 36, style: .continuous)
                        .stroke(.white.opacity(0.90), lineWidth: 1)
                )
                .shadow(color: Color(hex: "#6D5BAA").opacity(0.16), radius: 28, y: 16)
        )
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                quickPhaseIcon(kind: selectedKind)

                VStack(alignment: .leading, spacing: 3) {
                    Text(selectedKind.title)
                        .font(BBBFont.font(size: 20, weight: .heavy))
                        .foregroundStyle(DesignToken.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }

                Spacer(minLength: 6)

                quickRecordTimePicker
            }
        }
    }

    private func quickPhaseIcon(kind: QuickRecordKind) -> some View {
        ZStack {
            Circle()
                .fill(kind.softColor.opacity(0.46))
                .frame(width: 42, height: 42)
                .overlay(Circle().stroke(kind.color.opacity(0.88), lineWidth: 1.8))
                .shadow(color: kind.color.opacity(0.12), radius: 8, y: 4)

            Text(kind.phaseLetter)
                .font(BBBFont.font(size: 18, weight: .heavy))
                .foregroundStyle(kind.color)
        }
        .frame(width: 46, height: 46)
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
                    .font(.system(size: 13, weight: .bold))
                Text(recordedAtDayText)
                    .font(BBBFont.font(size: 11, weight: .heavy))
                    .lineLimit(1)
                Text(Self.timeFormatter.string(from: recordedAt))
                    .font(BBBFont.font(size: 13, weight: .heavy))
                    .monospacedDigit()
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .black))
            }
            .foregroundStyle(selectedKind.color)
            .padding(.horizontal, 10)
            .frame(height: 36)
            .frame(width: 150)
            .background(Capsule().fill(Color.white.opacity(0.76)))
            .overlay(Capsule().stroke(selectedKind.color.opacity(0.22), lineWidth: 1))
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("记录时间")
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
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .frame(height: 30)
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
        "\(recordedAtDayText) \(Self.timeFormatter.string(from: recordedAt))"
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
        recordedAt = min(candidate, Date())
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
        if Calendar.current.isDateInToday(recordedAt) {
            return "今天"
        }
        if Calendar.current.isDateInYesterday(recordedAt) {
            return "昨天"
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "M月d日"
        return formatter.string(from: recordedAt)
    }

    private var hero: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [
                            selectedKind.softColor.opacity(0.48),
                            Color.white.opacity(0.58),
                            Color.white.opacity(0.18)
                        ],
                        center: .center,
                        startRadius: 12,
                        endRadius: 190
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(.white.opacity(0.72), lineWidth: 1)
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
                    step: Double(selectedKind.step),
                    tint: selectedKind.color
                )
                .frame(width: 210, height: 250)
                .padding(.top, 2)
                .padding(.bottom, 4)
            } else {
                VStack(spacing: 13) {
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.68))
                            .frame(width: 118, height: 118)
                            .shadow(color: selectedKind.color.opacity(0.12), radius: 16, y: 9)

                        Image(systemName: selectedKind.symbolName)
                            .font(.system(size: 46, weight: .bold))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(selectedKind.color)
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text("\(value)")
                            .font(BBBFont.font(size: 38, weight: .heavy))
                            .foregroundStyle(selectedKind.color)
                        Text(selectedKind.unit)
                            .font(BBBFont.font(size: 19, weight: .heavy))
                            .foregroundStyle(DesignToken.textSecondary)
                    }

                    Text(selectedKind.placeholderText)
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
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
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
            .padding(.vertical, 16)
            .padding(.horizontal, 14)
        }
        .scrollIndicators(.hidden)
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
                Text(food.emoji)
                    .font(.system(size: 22))
                Text(food.displayName)
                    .font(BBBFont.font(size: 12, weight: .heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
            }
            .foregroundStyle(isSelected ? DesignToken.textPrimary : DesignToken.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: 66)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? selectedKind.softColor.opacity(0.86) : Color.white.opacity(0.60))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? selectedKind.color.opacity(0.44) : .white.opacity(0.46), lineWidth: 1.1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var solidsSelectionSummary: String {
        let names = selectedSolidFoods
            .sorted { $0.displayName < $1.displayName }
            .map(\.displayName)
            .joined(separator: "、")
        return "已选 \(names)"
    }

    private var sleepSegmentHero: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                sleepEndpointColumn(
                    title: "入睡",
                    timeText: sleepClockText(sleepStartAt),
                    binding: sleepMode == .justAsleep && sleepDraftStore.isRecording ? nil : sleepStartTimeBinding
                )

                VStack(spacing: 8) {
                    Rectangle()
                        .fill(selectedKind.color.opacity(0.20))
                        .frame(height: 1)
                        .overlay(
                            Image(systemName: "moon.zzz.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(selectedKind.color)
                                .padding(.horizontal, 8)
                                .background(Capsule().fill(Color.white.opacity(0.72)))
                        )
                        .padding(.top, 33)

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
        .padding(18)
    }

    private func sleepEndpointColumn(title: String, timeText: String, binding: Binding<Date>?) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(BBBFont.font(size: 30, weight: .heavy))
                .foregroundStyle(DesignToken.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            if let binding {
                DatePicker("", selection: binding, displayedComponents: [.hourAndMinute])
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .tint(selectedKind.color)
                    .environment(\.locale, Locale(identifier: "zh_Hans_CN"))
                    .frame(width: 102, height: 36)
                    .padding(.horizontal, 4)
                    .background(Capsule().fill(Color.white.opacity(0.78)))
                    .overlay(Capsule().stroke(selectedKind.color.opacity(0.24), lineWidth: 1))
                    .accessibilityLabel("\(title)时间")
            } else {
                Text(timeText)
                    .font(BBBFont.font(size: 15, weight: .heavy))
                    .foregroundStyle(DesignToken.textSecondary)
                    .monospacedDigit()
                    .frame(width: 102, height: 36)
                    .background(Capsule().fill(Color.white.opacity(0.48)))
            }
        }
        .frame(width: 108, alignment: .center)
    }

    @ViewBuilder
    private var sleepModeBody: some View {
        switch sleepMode {
        case .justAsleep:
            VStack(spacing: 8) {
                Text(sleepDraftStore.isRecording ? "宝宝正在睡，醒来后点保存。" : "记录从现在入睡开始，醒来后再保存。")
                    .font(BBBFont.font(size: 12, weight: .semibold))
                    .foregroundStyle(DesignToken.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        case .justWoke:
            sleepDurationChips
        case .smartFill:
            VStack(spacing: 8) {
                Text(smartSleepSuggestion?.reason ?? "根据本轮记录推测一段睡眠。")
                    .font(BBBFont.font(size: 12, weight: .semibold))
                    .foregroundStyle(DesignToken.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                sleepDurationChips
            }
        case .manual:
            Text("直接点上方时间胶囊调整。")
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
                    Text(mode.title)
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
            return "睡眠中 \(SleepRecordFormatter.durationText(minutes: max(sleepDraftStore.elapsedSeconds / 60, 0)))"
        }
        if sleepMode == .justAsleep {
            return "准备计时"
        }
        return "\(SleepRecordFormatter.durationText(minutes: sleepDurationMinutes))"
    }

    private var sleepDurationMinutes: Int {
        max(Int(sleepEndAt.timeIntervalSince(sleepStartAt) / 60), 0)
    }

    private var sleepStartTimeBinding: Binding<Date> {
        Binding(
            get: { sleepStartAt },
            set: { candidate in
                sleepStartAt = normalizedSleepStart(from: candidate, endingAt: sleepEndAt)
                value = sleepDurationMinutes
            }
        )
    }

    private var sleepEndTimeBinding: Binding<Date> {
        Binding(
            get: { sleepEndAt },
            set: { candidate in
                sleepEndAt = normalizedSleepEnd(from: candidate, startingAt: sleepStartAt)
                value = sleepDurationMinutes
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
                    Text(mode.title)
                        .font(BBBFont.font(size: 15, weight: .heavy))
                    Text(mode.subtitle)
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
                    .stroke(diaperMode == mode ? .white.opacity(0.32) : mode.accent.opacity(0.16), lineWidth: 1)
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
                Text(amount.title)
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
                    .stroke(urineAmount == amount ? .white.opacity(0.34) : DiaperRecordType.pee.accent.opacity(0.16), lineWidth: 1)
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
                Text(texture.title)
                    .font(BBBFont.font(size: 18, weight: .heavy))
                Text(texture.shortText)
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
                    .stroke(poopTexture == texture ? .white.opacity(0.34) : DiaperRecordType.poop.accent.opacity(0.16), lineWidth: 1)
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
            return "尿量\(urineAmount.title)"
        case .poop:
            return "\(poopTexture.title)便"
        }
    }

    private var diaperSummaryDetail: String {
        switch diaperMode {
        case .pee:
            return "\(urineAmount.dropCount)级尿量，保存为一次尿布记录"
        case .poop:
            return poopTexture.guidance
        }
    }

    private var activityHero: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
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

                ForEach(QuickActivityCategory.allCases) { category in
                    activityCategorySection(category)
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 14)
        }
        .scrollIndicators(.hidden)
    }

    private func activityCategorySection(_ category: QuickActivityCategory) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: category.symbolName)
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(selectedKind.color)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(selectedKind.softColor.opacity(0.72)))
                Text(category.title)
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
            Text(item.title)
                .font(BBBFont.font(size: 12, weight: .heavy))
                .foregroundStyle(isSelected ? .white : selectedKind.color)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .padding(.horizontal, 11)
                .frame(height: 31)
                .frame(maxWidth: .infinity)
                .background(Capsule().fill(isSelected ? selectedKind.color : selectedKind.softColor.opacity(0.62)))
                .overlay(Capsule().stroke(isSelected ? .white.opacity(0.34) : selectedKind.color.opacity(0.16), lineWidth: 1))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var activitySelectionSummary: String {
        guard !selectedActivityItems.isEmpty else { return "选择今天刚做过的活动" }
        let categories = Set(selectedActivityItems.map(\.category)).count
        return "已选 \(selectedActivityItems.count) 项，将合并为 \(categories) 条记录"
    }

    private var controlBar: some View {
        HStack(spacing: 12) {
            stepButton(systemName: "minus") {
                adjustValue(-selectedKind.step)
            }
            .disabled(value <= selectedKind.valueRange.lowerBound)

            HStack(spacing: 8) {
                Spacer(minLength: 0)

                Text("\(value)")
                    .font(BBBFont.font(size: 38, weight: .heavy))
                    .foregroundStyle(DesignToken.textPrimary)
                    .monospacedDigit()
                Text(selectedKind.unit)
                    .font(BBBFont.font(size: 19, weight: .heavy))
                    .foregroundStyle(DesignToken.textSecondary)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .frame(height: 58)
            .frame(maxWidth: .infinity)
            .background(Capsule().fill(Color(hex: "#F1EFF8").opacity(0.88)))
            .overlay(Capsule().stroke(.white.opacity(0.86), lineWidth: 1))

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
            .background(Capsule().fill(Color(hex: "#F1EFF8").opacity(0.88)))
            .overlay(Capsule().stroke(.white.opacity(0.86), lineWidth: 1))

            nursingTimerButton(side: .right)
        }
    }

    private func nursingTimerButton(side: BreastSide) -> some View {
        let isActive = activeNursingSide == side
        let seconds = side == .left ? nursingLeftSeconds : nursingRightSeconds

        return Button {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.86)) {
                activeNursingSide = isActive ? nil : side
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
            .foregroundStyle(isActive ? .white : selectedKind.color)
            .frame(width: 84, height: 58)
            .background(
                Capsule(style: .continuous)
                    .fill(isActive ? selectedKind.color : Color.white.opacity(0.86))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(isActive ? .white.opacity(0.34) : selectedKind.color.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: selectedKind.color.opacity(isActive ? 0.18 : 0.08), radius: 10, y: 5)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var nursingTotalSeconds: Int {
        nursingLeftSeconds + nursingRightSeconds
    }

    private func setNursingMinutes(_ side: BreastSide, minutes: Int) {
        let seconds = max(minutes, 0) * 60
        activeNursingSide = nil
        if side == .left {
            nursingLeftSeconds = seconds
        } else {
            nursingRightSeconds = seconds
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
        Button {
            save()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22, weight: .bold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(selectedKind.color, .white)
                Text(saveButtonTitle)
                    .font(BBBFont.font(size: 19, weight: .heavy))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(
                Capsule()
                    .fill(LinearGradient(colors: [selectedKind.color.opacity(0.78), selectedKind.color], startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .overlay(Capsule().stroke(.white.opacity(0.36), lineWidth: 1))
            .shadow(color: selectedKind.color.opacity(0.20), radius: 14, y: 8)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!canSave)
        .opacity(canSave ? 1 : 0.52)
    }

    private func stepButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(selectedKind.color)
                .frame(width: 56, height: 56)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white.opacity(0.86)))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.86), lineWidth: 1))
                .shadow(color: Color(hex: "#4D4B70").opacity(0.06), radius: 8, y: 4)
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
                                Text(kind.shortTitle)
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
                                    .stroke(selectedKind == kind ? .white.opacity(0.38) : kind.color.opacity(0.14), lineWidth: 1)
                            )
                        }
                        .id(item.id)
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
                .padding(.horizontal, 2)
            }
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
        value = min(max(value + delta, range.lowerBound), range.upperBound)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
        if selectedKind == .activity {
            return "保存活动"
        }
        guard selectedKind == .sleep else { return "保存" }
        if sleepMode == .justAsleep {
            return sleepDraftStore.isRecording ? "保存睡眠" : "开始计时"
        }
        return "保存睡眠"
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

    private func normalizedSleepStart(from candidate: Date, endingAt endDate: Date) -> Date {
        let end = min(endDate, Date())
        var start = date(onSameDayAs: end, usingTimeFrom: candidate)
        if start >= end {
            start = Calendar.current.date(byAdding: .day, value: -1, to: start) ?? start.addingTimeInterval(-24 * 60 * 60)
        }
        return min(start, end.addingTimeInterval(-60))
    }

    private func normalizedSleepEnd(from candidate: Date, startingAt startDate: Date) -> Date {
        var end = date(onSameDayAs: startDate, usingTimeFrom: candidate)
        if end <= startDate {
            end = Calendar.current.date(byAdding: .day, value: 1, to: end) ?? end.addingTimeInterval(24 * 60 * 60)
        }
        end = min(end, Date())
        if end <= startDate {
            end = min(Date(), startDate.addingTimeInterval(60))
        }
        return end
    }

    private func normalizedSleepWindow() -> (start: Date, end: Date)? {
        let end = min(sleepEndAt, Date())
        var start = sleepStartAt
        if start >= end {
            start = normalizedSleepStart(from: start, endingAt: end)
        }
        guard end > start else { return nil }
        return (start, end)
    }

    private func date(onSameDayAs anchor: Date, usingTimeFrom timeSource: Date) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: anchor)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: timeSource)
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        components.second = 0
        return calendar.date(from: components) ?? anchor
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
            reason: "根据本轮 \(sleepClockText(lastEvent.date)) \(lastEvent.title) 推测"
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
            reason: "根据当前轮 \(sleepClockText(lastEvent.date)) \(lastEvent.title) 推测"
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
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func sleepQuickDurationText(_ minutes: Int) -> String {
        SleepRecordFormatter.durationText(minutes: minutes)
    }

    private func save() {
        if selectedKind == .sleep {
            saveSleep()
            return
        }

        let submittedAt = effectiveRecordedAt
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        switch selectedKind {
        case .formulaBottle:
            saveBottle(milkType: .formula, recordedAt: submittedAt)
        case .expressedBottle:
            saveBottle(milkType: .expressed, recordedAt: submittedAt)
        case .nursing:
            saveNursing(recordedAt: submittedAt)
        case .solids:
            saveSolids(recordedAt: submittedAt)
        case .diaper:
            saveDiaper(recordedAt: submittedAt)
        case .activity:
            saveActivities(recordedAt: submittedAt)
        case .sleep:
            break
        case .bath, .tummyTime, .massage, .story, .outdoor, .play, .toothbrushing:
            activityStore.recordActivity(title: selectedKind.title, durationMinutes: value, recordedAt: submittedAt)
        }

        rebuildEasyCyclesAfterRecordChange()
        onDismiss()
    }

    private var effectiveRecordedAt: Date {
        min(recordedAt, Date())
    }

    private func saveActivities(recordedAt: Date) {
        let itemTitles = selectedActivityItems
            .map(\.title)
            .sorted()
            .joined(separator: "、")
        guard !itemTitles.isEmpty else { return }
        activityStore.recordActivity(
            title: "宝宝完成了\(itemTitles)活动",
            durationMinutes: value,
            recordedAt: recordedAt
        )
    }

    private func saveDiaper(recordedAt: Date) {
        activityStore.recordDiaper(
            type: diaperMode.recordType.rawValue,
            detail: diaperRecordDetail,
            note: "",
            recordedAt: recordedAt
        )
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
        var didWriteRecord = false

        switch sleepMode {
        case .justAsleep:
            if let activeStart = sleepDraftStore.activeSleepStartAt {
                let end = Date()
                guard end > activeStart else { return }
                activityStore.recordSleep(startTime: activeStart, endTime: end, note: "")
                sleepDraftStore.resetDraft()
                didWriteRecord = true
            } else {
                sleepDraftStore.start(at: Date())
            }
        case .justWoke, .smartFill, .manual:
            guard let window = normalizedSleepWindow() else { return }
            guard Int(window.end.timeIntervalSince(window.start) / 60) >= QuickRecordKind.sleep.valueRange.lowerBound else { return }
            activityStore.recordSleep(startTime: window.start, endTime: window.end, note: "")
            didWriteRecord = true
        }

        if didWriteRecord {
            rebuildEasyCyclesAfterRecordChange()
        }

        onDismiss()
    }

    private func rebuildEasyCyclesAfterRecordChange() {
        easyCycleStore.rebuild(
            from: feedingStore.allSessions,
            careRecords: activityStore.exportCareRecords()
        )
    }

    private func saveBottle(milkType: MilkType, recordedAt: Date) {
        let entry = FeedingEntry(
            type: .bottle,
            milkType: milkType,
            bottleAmount: value
        )
        let session = FeedingSession(
            entries: [entry],
            notes: "",
            babyMood: .happy,
            createdAt: recordedAt
        )
        feedingStore.saveSession(session)
    }

    private func saveNursing(recordedAt: Date) {
        let leftMinutes = nursingMinutes(from: nursingLeftSeconds)
        let rightMinutes = nursingMinutes(from: nursingRightSeconds)
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
        guard !entries.isEmpty else { return }
        let session = FeedingSession(
            entries: entries,
            notes: "",
            babyMood: .happy,
            createdAt: recordedAt
        )
        feedingStore.saveSession(session)
    }

    private func saveSolids(recordedAt: Date) {
        let foods = selectedSolidFoods.sorted { $0.displayName < $1.displayName }
        guard !foods.isEmpty else { return }
        let amountPerFood = Double(value) / Double(max(foods.count, 1))
        let entries = foods.map { food in
            FeedingEntry(
                type: .solid,
                solidFood: food,
                solidAmount: amountPerFood,
                solidUnit: .g
            )
        }
        let session = FeedingSession(
            entries: entries,
            notes: "",
            babyMood: .happy,
            createdAt: recordedAt
        )
        feedingStore.saveSession(session)
    }

    private func nursingMinutes(from seconds: Int) -> Int {
        guard seconds > 0 else { return 0 }
        return max(Int((Double(seconds) / 60.0).rounded()), 1)
    }
}

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
                                Color.white.opacity(0.22),
                                accent.opacity(0.16),
                                Color.white.opacity(0.14)
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
                                Color.white.opacity(0.34),
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
                            .overlay(Circle().stroke(Color.white.opacity(0.78), lineWidth: 1))
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
                                    .fill(Color.white.opacity(highlighted ? 0.44 : 0.20))
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
                .glassEffect(.regular.tint(Color.white.opacity(0.18)).interactive(), in: shape)
        } else {
            self
                .background(.ultraThinMaterial, in: shape)
                .overlay(shape.stroke(.white.opacity(0.72), lineWidth: 1))
                .shadow(color: Color(hex: "#4D4B70").opacity(0.14), radius: 18, y: 8)
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
    case feeding
    case diaper
    case sleep
    case weight
    case height

    var id: String {
        switch self {
        case .feeding: return "feeding"
        case .diaper: return "diaper"
        case .sleep: return "sleep"
        case .weight: return "weight"
        case .height: return "height"
        }
    }
}
