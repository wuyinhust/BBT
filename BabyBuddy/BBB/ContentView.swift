import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var feedingDraftStore: FeedingDraftStore
    @EnvironmentObject private var sleepDraftStore: SleepDraftStore
    @AppStorage("has_completed_onboarding") private var hasCompletedOnboarding = false

    @State private var selectedTab: RootTab = .record
    @State private var showCompanionPicker = false
    @State private var activeRecordSheet: RecordSheet?
    @State private var showBabyInfo = false
    @State private var showQuickActions = false
    @State private var statusTick = Date()
    @State private var activeYesterdayReport: YesterdayReport?
    @Namespace private var tabSelectionNamespace

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
        NavigationStack {
                ZStack {
                    RecordHomeView(
                        showBabyInfo: $showBabyInfo,
                        openFeedSheet: {
                            openRecordSheet(.feeding)
                        },
                        openYesterdayReport: { report in
                            openYesterdayReport(report)
                        }
                    )
                    .opacity(selectedTab == .record ? 1 : 0)
                    .allowsHitTesting(selectedTab == .record)

                    CompanionLiveView(openFeedSheet: {
                        openRecordSheet(.feeding)
                    }, openCompanionPicker: {
                        showCompanionPicker = true
                    }, activeYesterdayReport: $activeYesterdayReport)
                        .opacity(selectedTab == .companion ? 1 : 0)
                        .allowsHitTesting(selectedTab == .companion)

                    BabyAchievementsView()
                        .opacity(selectedTab == .growth ? 1 : 0)
                        .allowsHitTesting(selectedTab == .growth)
                }
                .safeAreaInset(edge: .bottom) {
                    GeometryReader { proxy in
                        let horizontalPadding: CGFloat = proxy.size.width < 390 ? 18 : 26
                        ZStack(alignment: .bottom) {
                            Color.black.opacity(0.001)
                                .contentShape(Rectangle())

                            bottomNavigation
                                .padding(.horizontal, horizontalPadding)
                        }
                    }
                    .frame(height: showQuickActions ? 104 : 66)
                    .padding(.bottom, 2)
                }
                .tint(DesignToken.primary)
                .navigationBarHidden(true)
            }
            .overlay(alignment: .bottomTrailing) {
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
                .padding(.bottom, 130)
                .padding(.trailing, 20)
            }
            .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { date in
                statusTick = date
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
            .sheet(item: $activeRecordSheet) { sheet in
                switch sheet {
                case .feeding:
                    FeedingSheet(isPresented: recordSheetBinding(for: .feeding))
                        .presentationDetents([.large])
                        .presentationBackground(.clear)
                case .diaper:
                    DiaperSheet(isPresented: recordSheetBinding(for: .diaper))
                        .presentationDetents([.large])
                        .presentationBackground(.clear)
                case .sleep:
                    SleepSheet(isPresented: recordSheetBinding(for: .sleep))
                        .presentationDetents([.large])
                        .presentationBackground(.clear)
                }
            }
            .sheet(isPresented: $showBabyInfo) {
                BabyInfoEditView(isPresented: $showBabyInfo)
            }
    }

    private func openRecordSheet(_ sheet: RecordSheet) {
        showQuickActions = false
        activeRecordSheet = sheet
    }

    private func openYesterdayReport(_ report: YesterdayReport) {
        showQuickActions = false
        activeYesterdayReport = report
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            selectedTab = .companion
        }
    }

    private var shouldShowFeedingStatus: Bool {
        feedingDraftStore.isRecording && activeRecordSheet != .feeding
    }

    private var shouldShowSleepStatus: Bool {
        sleepDraftStore.isRecording && activeRecordSheet != .sleep
    }

    private var feedingStatusButton: some View {
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

    private var sleepStatusButton: some View {
        Button {
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

    private var bottomNavigation: some View {
        VStack(spacing: 10) {
            if showQuickActions {
                HStack(spacing: 10) {
                    quickActionButton(title: "喂养", icon: "fork.knife.circle.fill") {
                        openRecordSheet(.feeding)
                    }

                    quickActionButton(title: "尿布", icon: "drop.fill") {
                        openRecordSheet(.diaper)
                    }

                    quickActionButton(title: "睡眠", icon: "moon.fill") {
                        openRecordSheet(.sleep)
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            HStack(spacing: 12) {
                HStack(spacing: 3) {
                    capsuleTabButton(tab: .record)
                    capsuleTabButton(tab: .companion)
                    capsuleTabButton(tab: .growth)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 5)
                .padding(.vertical, 3)
                .background(
                    Capsule(style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Capsule(style: .continuous)
                                .fill(.white.opacity(0.54))
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(.white.opacity(0.78), lineWidth: 1)
                        )
                )
                .shadow(color: Color(hex: "#7E5DE8").opacity(0.12), radius: 22, y: 10)

                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                        showQuickActions.toggle()
                    }
                } label: {
                    Circle()
                        .fill(.white.opacity(0.92))
                        .frame(width: 54, height: 54)
                        .overlay(
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [DesignToken.primary, Color(hex: "#8F6CFF")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 44, height: 44)
                        )
                        .overlay(
                            Image(systemName: showQuickActions ? "xmark" : "plus")
                                .font(.system(size: 20, weight: .heavy))
                                .foregroundStyle(.white.opacity(0.96))
                        )
                        .overlay(Circle().stroke(.white.opacity(0.92), lineWidth: 1.2))
                        .shadow(color: Color(hex: "#7E5DE8").opacity(0.24), radius: 24, y: 10)
                }
                .buttonStyle(ScaleButtonStyle())
                .frame(width: 64, height: 64)
                .contentShape(Circle())
            }
        }
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

    private func capsuleTabButton(tab: RootTab) -> some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 15, weight: .heavy))
                Text(tab.title)
                    .font(BBBFont.font(size: 10, weight: .heavy))
            }
                .foregroundStyle(selectedTab == tab ? DesignToken.primary : Color(hex: "#8D8AA4"))
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background {
                    if selectedTab == tab {
                        Capsule(style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        DesignToken.primary.opacity(0.18),
                                        Color.white.opacity(0.62)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .matchedGeometryEffect(id: "selectedTab", in: tabSelectionNamespace)
                        }
                }
        }
        .buttonStyle(ScaleButtonStyle())
        .frame(height: 48)
        .contentShape(Rectangle())
    }

    private func quickActionButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
            }
            .font(BBBFont.font(size: 14, weight: .semibold))
            .foregroundStyle(DesignToken.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Capsule().fill(.white))
            .shadow(color: Color(hex: "#4D4B70").opacity(0.08), radius: 10, y: 5)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

private enum RecordSheet: Identifiable {
    case feeding
    case diaper
    case sleep

    var id: String {
        switch self {
        case .feeding: return "feeding"
        case .diaper: return "diaper"
        case .sleep: return "sleep"
        }
    }
}
