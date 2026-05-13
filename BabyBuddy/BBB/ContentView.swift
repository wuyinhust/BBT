import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var feedingDraftStore: FeedingDraftStore
    @AppStorage("has_completed_onboarding") private var hasCompletedOnboarding = false

    @State private var selectedTab: RootTab = .record
    @State private var showCompanionPicker = false
    @State private var activeRecordSheet: RecordSheet?
    @State private var showBabyInfo = false
    @State private var showQuickActions = false
    @State private var statusTick = Date()

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
                    HomeView(
                        selectedTab: $selectedTab,
                        showBabyInfo: $showBabyInfo,
                        showCompanionPicker: $showCompanionPicker,
                        openFeedSheet: {
                            openRecordSheet(.feeding)
                        }
                    )
                    .opacity(selectedTab == .record ? 1 : 0)
                    .allowsHitTesting(selectedTab == .record)

                    BabyAchievementsView()
                        .opacity(selectedTab == .companion ? 1 : 0)
                        .allowsHitTesting(selectedTab == .companion)
                }
                .safeAreaInset(edge: .bottom) {
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
                            HStack(spacing: 8) {
                                capsuleTabButton(tab: .record)
                                capsuleTabButton(tab: .companion)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(.white))
                            .shadow(color: Color(hex: "#4D4B70").opacity(0.08), radius: 14, y: 8)

                            Button {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                                    showQuickActions.toggle()
                                }
                            } label: {
                                Circle()
                                    .fill(DesignToken.primary)
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Image(systemName: showQuickActions ? "xmark" : "plus")
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundStyle(.white)
                                    )
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                }
                .tint(DesignToken.primary)
                .navigationBarHidden(true)
            }
            .overlay(alignment: .bottomTrailing) {
                if shouldShowFeedingStatus {
                    feedingStatusButton
                        .padding(.bottom, 132)
                        .padding(.trailing, 20)
                        .transition(.scale(scale: 0.92).combined(with: .opacity))
                }
            }
            .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { date in
                statusTick = date
                if feedingDraftStore.isRecording {
                    feedingDraftStore.updateCurrentTime(date)
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

    private var shouldShowFeedingStatus: Bool {
        feedingDraftStore.isRecording && activeRecordSheet != .feeding
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
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(DesignToken.textPrimary)
                    Text("\(feedingDraftStore.statusTitle) · \(feedingDraftStore.statusDetail)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
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

    private func capsuleTabButton(tab: RootTab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            Text(tab.title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(selectedTab == tab ? .white : DesignToken.textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(selectedTab == tab ? DesignToken.primary : .clear)
                )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func quickActionButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.system(size: 14, weight: .semibold, design: .rounded))
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
