import SwiftUI
import UIKit
import Combine

/// The compact EASY metric tiles use canonical Chinese source keys because
/// they are also used by the model and accessibility layer. Resolve those
/// keys explicitly at render time so a debug language override cannot leave a
/// stale catalog value in the visible tile title.
private func localizedEasyMetricTitle(_ title: String) -> String {
    let translations: (simplified: String, traditional: String, english: String)
    switch title {
    case "喂养":
        translations = ("喂养", "餵養", "Eat")
    case "活动":
        translations = ("活动", "活動", "Activity")
    case "睡眠":
        translations = ("睡眠", "睡眠", "Sleep")
    case "状态":
        translations = ("状态", "狀態", "You")
    default:
        return title.localized
    }

    switch AppLanguage.current {
    case .simplifiedChinese:
        return translations.simplified
    case .traditionalChinese:
        return translations.traditional
    case .english:
        return translations.english
    }
}

private enum RecordHomeCreationAction {
    case feed
    case activity
    case sleep(cycleID: UUID?)
    case advanceEasyCycle

    var title: String {
        switch self {
        case .feed:
            return "喂养记录"
        case .activity:
            return "活动记录"
        case .sleep:
            return "睡眠记录"
        case .advanceEasyCycle:
            return "EASY 循环"
        }
    }

    var withoutHistoricalCycleContext: RecordHomeCreationAction {
        switch self {
        case .sleep:
            return .sleep(cycleID: nil)
        default:
            return self
        }
    }
}

private struct PendingHistoricalRecordIntent {
    let action: RecordHomeCreationAction
    let date: Date
}

private struct EasyCycleSplitReviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("easy_cycle_automatically_keep_splits_v1")
    private var automaticallyKeepSplits = false

    let notice: EasyCycleSplitNotice
    let store: EasyCycleStore

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Capsule()
                .fill(DesignToken.textFaint.opacity(0.35))
                .frame(width: 36, height: 5)
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 8) {
                Text("补录改变了这一轮的划分")
                    .font(BBBFont.font(size: 21, weight: .heavy))
                    .foregroundStyle(DesignToken.textPrimary)

                Text(explanationText)
                    .font(BBBFont.font(size: 13, weight: .semibold))
                    .foregroundStyle(DesignToken.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 12) {
                cycleChangeSection(
                    title: "拆分前",
                    icon: "rectangle.stack",
                    ranges: [notice.replacedCycle],
                    tint: DesignToken.textSecondary
                )
                Image(systemName: "arrow.down")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(DesignToken.primary)
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)
                cycleChangeSection(
                    title: "拆分后",
                    icon: "square.split.2x1",
                    ranges: notice.replacementCycles,
                    tint: DesignToken.primary
                )
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(DesignToken.surfaceSoft)
            )

            Toggle("以后自动保留拆分结果，不再提示", isOn: $automaticallyKeepSplits)
                .font(BBBFont.font(size: 12, weight: .semibold))
                .foregroundStyle(DesignToken.textPrimary)
                .tint(DesignToken.primary)

            VStack(spacing: 10) {
                Button {
                    store.acknowledgeSplit(notice.id)
                    dismiss()
                } label: {
                    Text("保留拆分结果")
                        .font(BBBFont.font(size: 15, weight: .heavy))
                        .foregroundStyle(DesignToken.onPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(DesignToken.primaryGradient)
                        )
                }
                .buttonStyle(ScaleButtonStyle())

                Button {
                    automaticallyKeepSplits = false
                    store.mergeSplitBack(notice.id)
                    dismiss()
                } label: {
                    Text("仍合并为原来一轮")
                        .font(BBBFont.font(size: 14, weight: .heavy))
                        .foregroundStyle(DesignToken.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .fill(DesignToken.primary.opacity(0.10))
                        )
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 20)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled()
    }

    private var explanationText: String {
        "你补录了 \(AppDateTimeFormat.time(notice.sourceRecordedAt)) 的\(notice.sourcePhase.title)记录。按 EASY 的时间顺序，这条记录会让原来的一轮分成两轮。所有记录都已保留，请确认如何整理。"
    }

    private func cycleChangeSection(
        title: String,
        icon: String,
        ranges: [EasyCycleSplitNotice.CycleRange],
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(BBBFont.font(size: 11, weight: .heavy))
                .foregroundStyle(tint)

            ForEach(Array(ranges.enumerated()), id: \.element.id) { index, range in
                HStack {
                    Text(ranges.count == 1 ? "一轮" : "第 \(index + 1) 轮")
                        .font(BBBFont.font(size: 12, weight: .heavy))
                        .foregroundStyle(DesignToken.textPrimary)
                    Spacer()
                    Text(rangeText(range))
                        .font(BBBFont.font(size: 12, weight: .heavy))
                        .foregroundStyle(tint)
                        .monospacedDigit()
                }
            }
        }
    }

    private func rangeText(_ range: EasyCycleSplitNotice.CycleRange) -> String {
        AppDateTimeFormat.timeRange(from: range.startedAt, to: range.endedAt)
    }
}

struct RecordHomeView: View {
    @EnvironmentObject private var feedingStore: FeedingStore
    @EnvironmentObject private var feedingDraftStore: FeedingDraftStore
    @EnvironmentObject private var activityStore: ActivityStore
    @EnvironmentObject private var sleepDraftStore: SleepDraftStore
    @EnvironmentObject private var growthMetricStore: GrowthMetricStore
    @EnvironmentObject private var recruitmentStore: CompanionRecruitmentStore
    @EnvironmentObject private var bbBriefStore: BBBriefStore
    @EnvironmentObject private var easyCycleStore: EasyCycleStore
    @EnvironmentObject private var feedbackCenter: AppFeedbackCenter
    @ObservedObject private var subjectiveStateStore = SubjectiveStateStore.shared
    @StateObject private var membershipStore = PlusMembershipStore.shared
    @Environment(BabyProfileStore.self) private var profileStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("easy_cycle_automatically_keep_splits_v1")
    private var automaticallyKeepEasyCycleSplits = false

    @Binding var homeMode: RecordHomeMode
    @Binding var showYearningDetailRequest: Bool
    var openFeedSheet: (Date) -> Void = { _ in }
    var openActivitySheet: (Date) -> Void = { _ in }
    var openSleepSheet: (Date) -> Void = { _ in }
    var openSleepSheetForCycle: (UUID?, Date) -> Void = { _, _ in }
    var openFeedingTiming: () -> Void = {}
    var dismissQuickAddMenu: () -> Void = {}
    var onSubjectiveStatePrompt: (SubjectiveStatePromptContext) -> Void = { _ in }
    var onEditQuickRecord: ((QuickRecordEditTarget) -> Void)? = nil
    private let isReadOnlyDemo: Bool

    @State private var selectedDate = Date()
    @State private var visibleWeekStart: Date? = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start
    @State private var dateTransitionDirection = 1
    @State private var isWalletStackExpanded = false
    @State private var isHeaderCollapsed = false
    @State private var isRecordScrollActive = false
    @State private var pendingMinuteRefresh: Date?
    @State private var easyFeedState = EasyCycleFeedState()
    @State private var easyFeedSnapshots: [RecordHomeDayKey: RecordHomeDaySnapshot] = [:]
    @State private var easyFeedRevision = 0
    @State private var easyFeedSnapshotGeneration = 0
    @State private var easyFeedSnapshotTask: Task<Void, Never>?
    @StateObject private var easyFeedVisibilityRuntime = RecordHomeEasyFeedVisibilityRuntime()
    @State private var editingItem: RecordHomeTimelineItem?
    @State private var pendingDeleteItem: RecordHomeTimelineItem?
    @State private var presentedBabyTrendDetail: BabyTrendDetailContext?
    @State private var presentedYearningDetail: YearningDetailContext?
    @State private var now = Date()
    @State private var easyCycleCardOverview: EasyCycleOverview?
    @State private var pendingTimingCancellation: ActiveTimingKind?
    @State private var showSingleRecordPage = false
    @State private var showProfilePage = false
    @State private var showStatisticsPage = false
    @State private var presentedBBBrief: DailyReportSnapshot?
    @State private var pendingBBBriefReward: BBBuckTransaction?
    @AppStorage("daily_report_celebration_last_transaction_id_v1")
    private var lastPresentedReportRewardTransactionID = ""
    @State private var surfacedRewardCycleIDs: Set<UUID> = []
    @State private var isBootstrappingEasyFeedback = true
    @State private var pendingHistoricalRecordIntent: PendingHistoricalRecordIntent?
    @State private var presentedEasyCycleSplitNotice: EasyCycleSplitNotice?

    private let metricTileSpacing: CGFloat = 8
    // Fits the widest compact value, "999ml+999m", without making units a
    // secondary, smaller value.
    private let metricTileValueFontSize: CGFloat = 10
    private let walletCardHorizontalPadding: CGFloat = 16
    private let walletCardHeaderIconSize: CGFloat = 24
    private let walletCardHeaderHitSize: CGFloat = 44
    private let timelineAxisWidth: CGFloat = 30
    private let timelineIconSize: CGFloat = 30
    private let compactTimelineNodeSize: CGFloat = 22
    private let compactTimelineRowHeight: CGFloat = 42

    private var homeBodyText: Color { DesignToken.textMuted }
    private var homeMetaText: Color { DesignToken.textFaint }
    private var homeFaintText: Color { DesignToken.textFaint.opacity(0.78) }

    init(
        homeMode: Binding<RecordHomeMode> = .constant(.basic),
        showYearningDetailRequest: Binding<Bool> = .constant(false),
        openFeedSheet: @escaping (Date) -> Void = { _ in },
        openActivitySheet: @escaping (Date) -> Void = { _ in },
        openSleepSheet: @escaping (Date) -> Void = { _ in },
        openSleepSheetForCycle: @escaping (UUID?, Date) -> Void = { _, _ in },
        openFeedingTiming: @escaping () -> Void = {},
        dismissQuickAddMenu: @escaping () -> Void = {},
        onSubjectiveStatePrompt: @escaping (SubjectiveStatePromptContext) -> Void = { _ in },
        onEditQuickRecord: ((QuickRecordEditTarget) -> Void)? = nil,
        isReadOnlyDemo: Bool = false
    ) {
        _homeMode = homeMode
        _showYearningDetailRequest = showYearningDetailRequest
        self.openFeedSheet = openFeedSheet
        self.openActivitySheet = openActivitySheet
        self.openSleepSheet = openSleepSheet
        self.openSleepSheetForCycle = openSleepSheetForCycle
        self.openFeedingTiming = openFeedingTiming
        self.dismissQuickAddMenu = dismissQuickAddMenu
        self.onSubjectiveStatePrompt = onSubjectiveStatePrompt
        self.onEditQuickRecord = onEditQuickRecord
        self.isReadOnlyDemo = isReadOnlyDemo
    }

    var body: some View {
        GeometryReader { proxy in
            let metrics = RecordHomeLayoutMetrics(size: proxy.size, safeAreaInsets: proxy.safeAreaInsets, itemCount: visibleTimelineCount)
            let headerProgress: CGFloat = isHeaderCollapsed ? 1 : 0
            let headerHeight = metrics.headerHeight(progress: headerProgress)

            ZStack(alignment: .top) {
                recordBackground.ignoresSafeArea()

                ScrollViewReader { scrollProxy in
                    ScrollView(showsIndicators: false) {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            Color.clear
                                .frame(height: metrics.expandedHeaderHeight)
                                .id(RecordHomeScrollTarget.rhythm)
                                .accessibilityHidden(true)

                            homeWalletCardStack
                                .padding(.top, -metrics.headerCardOverlap)
                                .padding(.bottom, metrics.rhythmBottom)
                            recordTimelineModeSection(scrollProxy: scrollProxy)
                        }
                        .padding(.horizontal, metrics.horizontalPadding)
                        .padding(.bottom, metrics.bottomPadding)
                        .frame(maxWidth: metrics.contentMaxWidth, alignment: .leading)
                        .frame(maxWidth: .infinity)
                        .scrollTargetLayout()
                    }
                    .simultaneousGesture(
                        TapGesture()
                            .onEnded {
                                dismissQuickAddMenu()
                            }
                    )
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 2)
                            .onChanged { _ in
                                dismissQuickAddMenu()
                            }
                    )
                    .onScrollGeometryChange(for: Bool.self) { geometry in
                        max(0, geometry.contentOffset.y + geometry.contentInsets.top) >= 56
                    } action: { _, shouldCollapse in
                        guard isHeaderCollapsed != shouldCollapse else { return }
                        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.20)) {
                            isHeaderCollapsed = shouldCollapse
                        }
                    }
                    .onScrollPhaseChange { _, newPhase in
                        handleRecordScrollPhaseChange(newPhase)
                    }
                    .onScrollTargetVisibilityChange(idType: UUID.self, threshold: 0.35) { identifiers in
                        handleVisibleEasyCycleIDs(identifiers)
                    }
                    .onChange(of: selectedDate) { _, newDate in
                        restoreEasyFeedPosition(for: newDate, with: scrollProxy)
                    }
                    .onChange(of: currentEasyFeedSnapshot?.id) { _, _ in
                        restoreEasyFeedPosition(for: selectedDate, with: scrollProxy)
                    }
                    .overlay(alignment: .top) {
                        stickyCalendarHeader(
                            metrics,
                            progress: headerProgress,
                            scrollProxy: scrollProxy
                        )
                        .frame(height: headerHeight, alignment: .top)
                        .frame(maxWidth: .infinity, alignment: .top)
                    }
                }
            }
        }
        .overlay {
            if let target = localQuickRecordEditTarget {
                QuickRecordCardOverlay(
                    editTarget: target,
                    onDismiss: { editingItem = nil },
                    onCompletedRecord: { context in
                        onSubjectiveStatePrompt(context)
                    }
                )
                .ignoresSafeArea()
                .transition(.opacity)
                .zIndex(20)
            }
        }
        .fullScreenCover(isPresented: $showSingleRecordPage) {
            singleRecordPage
        }
        .fullScreenCover(isPresented: $showProfilePage) {
            NavigationStack {
                ProfileView()
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            AppPageCloseButton { showProfilePage = false }
                        }
                    }
            }
        }
        .fullScreenCover(isPresented: $showStatisticsPage) {
            NavigationStack {
                StatisticsAnalysisView()
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            AppPageCloseButton { showStatisticsPage = false }
                        }
                    }
            }
        }
        .fullScreenCover(item: $presentedBBBrief, onDismiss: presentPendingBBBriefReward) { snapshot in
            BBBriefPage(
                snapshot: snapshot,
                snapshots: bbBriefStore.snapshots,
                lastPresentedReportRewardTransactionID: lastPresentedReportRewardTransactionID,
                onRewardReady: { pendingBBBriefReward = $0 },
                onDismiss: { presentedBBBrief = nil }
            )
        }
        .sheet(item: growthMetricEditBinding) { record in
            GrowthMetricEditSheet(record: record)
        }
        .sheet(item: $presentedBabyTrendDetail) { context in
            BabyTrendDetailSheet(
                metric: context.metric,
                referenceDate: selectedDate,
                loadSnapshot: {
                    BabyTrendDetailSnapshot(
                        ageText: babyAgeText,
                        guidance: ageRhythmGuidance,
                        overview: babyTrendOverview,
                        careSummary: weeklyCareSummary,
                        recentBabyState: recentSevenDayBabyState
                    )
                }
            )
        }
        .sheet(item: $presentedYearningDetail) { _ in
            SubjectiveStateDetailView()
        }
        .sheet(item: $presentedEasyCycleSplitNotice) { notice in
            EasyCycleSplitReviewSheet(
                notice: notice,
                store: easyCycleStore
            )
        }
        .onAppear {
            if !isReadOnlyDemo {
                isBootstrappingEasyFeedback = true
                rebuildEasyCycles()
                awardCompleteEasyCyclesIfNeeded(surfaceFeedback: false)
                if let pendingSplitNotice = easyCycleStore.pendingSplitNotice {
                    handleEasyCycleSplitNotice(pendingSplitNotice, surfaceFeedback: false)
                }
                isBootstrappingEasyFeedback = false
            }
            refreshEasyCycleCardOverview()
            requestEasyFeedSnapshots(immediate: true)
        }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { date in
            handleMinuteRefresh(date)
        }
        .onChange(of: selectedDate) { _, _ in
            refreshEasyCycleCardOverview()
            requestEasyFeedSnapshots(immediate: currentEasyFeedSnapshot == nil)
        }
        .onChange(of: homeMode) { _, _ in
            refreshEasyCycleCardOverview()
        }
        .onReceive(feedingStore.$sessions.dropFirst()) { _ in
            if !isReadOnlyDemo {
                handleEasyCycleRecordMutation()
            }
        }
        .onReceive(activityStore.$careRecords.dropFirst()) { _ in
            if !isReadOnlyDemo {
                handleEasyCycleRecordMutation()
            }
        }
        .onReceive(subjectiveStateStore.$checkIns.dropFirst()) { checkIns in
            // A Y submission is already committed to the local store at this
            // point. Refresh the current cycle immediately, using a fresh
            // reference time so a newly recorded manual Y is not excluded from
            // an in-progress cycle by a stale page-open timestamp.
            handleSubjectiveStateMutation(checkIns)
        }
        .onReceive(easyCycleStore.$cycles.dropFirst()) { _ in
            if !isReadOnlyDemo {
                awardCompleteEasyCyclesIfNeeded(
                    surfaceFeedback: !isBootstrappingEasyFeedback
                )
            }
            now = Date()
            refreshEasyCycleCardOverview()
            markEasyFeedDataChanged(immediate: true)
        }
        .onReceive(easyCycleStore.$pendingSplitNotice.compactMap { $0 }) { notice in
            if !isReadOnlyDemo {
                handleEasyCycleSplitNotice(
                    notice,
                    surfaceFeedback: !isBootstrappingEasyFeedback
                )
            }
        }
        .onChange(of: showYearningDetailRequest) { _, shouldPresent in
            guard shouldPresent else { return }
            presentYearningDetail()
            showYearningDetailRequest = false
        }
        .confirmationDialog(
            "删除这条记录？",
            isPresented: Binding(
                get: { pendingDeleteItem != nil },
                set: { if !$0 { pendingDeleteItem = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("删除记录", role: .destructive) {
                if let pendingDeleteItem {
                    delete(pendingDeleteItem)
                }
                pendingDeleteItem = nil
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除后会从当天记录和统计中移除。")
        }
        .confirmationDialog(
            "取消这次计时？",
            isPresented: Binding(
                get: { pendingTimingCancellation != nil },
                set: { if !$0 { pendingTimingCancellation = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("取消计时", role: .destructive) {
                cancelActiveTiming()
            }
            Button("继续计时", role: .cancel) {}
        } message: {
            Text("这条计时草稿不会生成正式记录。")
        }
        .confirmationDialog(
            historicalRecordDialogTitle,
            isPresented: Binding(
                get: { pendingHistoricalRecordIntent != nil },
                set: { if !$0 { pendingHistoricalRecordIntent = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(historicalBackfillButtonTitle) {
                confirmHistoricalBackfill()
            }
            Button("回到今天并记录") {
                rerouteHistoricalRecordToToday()
            }
            Button("取消", role: .cancel) {
                pendingHistoricalRecordIntent = nil
            }
        } message: {
            Text(historicalRecordDialogMessage)
        }
        .onDisappear {
            easyFeedSnapshotTask?.cancel()
        }
    }

    private var selectedSessions: [FeedingSession] {
        feedingStore.sessions(on: selectedDate)
    }

    private var localQuickRecordEditTarget: QuickRecordEditTarget? {
        switch editingItem {
        case .feeding(let session):
            return .feeding(session)
        case .care(let record):
            return .care(record)
        case .growth(_), .subjective(_), .none:
            return nil
        }
    }

    private func presentQuickRecordEdit(_ item: RecordHomeTimelineItem) {
        let target: QuickRecordEditTarget
        switch item {
        case .feeding(let session):
            target = .feeding(session)
        case .care(let record):
            target = .care(record)
        case .growth(_), .subjective(_):
            return
        }

        if let onEditQuickRecord {
            onEditQuickRecord(target)
        } else {
            editingItem = item
        }
    }

    private var growthMetricEditBinding: Binding<GrowthMetricRecord?> {
        Binding(
            get: {
                guard case .growth(let record) = editingItem else { return nil }
                return record
            },
            set: { newValue in
                if newValue == nil {
                    editingItem = nil
                }
            }
        )
    }

    private var selectedCareRecords: [CareRecord] {
        activityStore.careRecords(on: selectedDate)
    }

    private var selectedCareRecordsForSleepSummary: [CareRecord] {
        activityStore.careRecordsForSleepSummary(on: selectedDate)
    }

    private var selectedGrowthRecords: [GrowthMetricRecord] {
        growthMetricStore.records(on: selectedDate)
    }

    private var selectedSleepSummary: SleepComputationSummary {
        DayTimelineCalculator.summary(
            for: selectedDate,
            sessions: selectedSessions,
            careRecords: selectedCareRecordsForSleepSummary
        )
    }

    private var timelineItems: [RecordHomeTimelineItem] {
        let feedingItems = selectedSessions.map { RecordHomeTimelineItem.feeding($0) }
        let careItems = selectedCareRecords.map { RecordHomeTimelineItem.care($0) }
        let growthItems = selectedGrowthRecords.map { RecordHomeTimelineItem.growth($0) }
        let subjectiveItems = subjectiveStateStore.checkIns(on: selectedDate)
            .filter { $0.sourceType == .manual }
            .map { RecordHomeTimelineItem.subjective($0) }
        return (feedingItems + careItems + growthItems + subjectiveItems)
            .sorted { $0.date > $1.date }
    }

    private var visibleTimelineCount: Int {
        currentEasyFeedSnapshot?.cards.count ?? 0
    }

    private var selectedDayKey: RecordHomeDayKey {
        RecordHomeDayKey(selectedDate)
    }

    private var currentEasyFeedSnapshot: RecordHomeDaySnapshot? {
        // Keep the last valid snapshot on screen while a newer one is built.
        // Invalidating it by revision briefly rendered placeholder cards and
        // made the EASY feed visibly disappear during ordinary mutations.
        easyFeedSnapshots[selectedDayKey]
    }

    private var visibleEasyCycleCardModels: [EasyCycleCardModel] {
        guard let snapshot = currentEasyFeedSnapshot else { return [] }
        let count = easyFeedState.visibleCount(
            for: selectedDayKey,
            totalCount: snapshot.cards.count
        )
        return Array(snapshot.cards.prefix(count))
    }

    private var easyCycleTimelineItems: [EasyCycle] {
        easyCycleStore.cycles(on: selectedDate)
            .filter(easyCycleHasDisplayRecords)
    }

    private var weekDates: [Date] {
        datesInWeek(starting: weekStart(containing: selectedDate))
    }

    private var firstSelectableDate: Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return min(calendar.startOfDay(for: profileStore.currentProfile.birthDate), today)
    }

    private var lastSelectableDate: Date {
        Calendar.current.startOfDay(for: Date())
    }

    private var availableWeekStarts: [Date] {
        let calendar = Calendar.current
        let firstWeek = weekStart(containing: firstSelectableDate)
        let lastWeek = weekStart(containing: lastSelectableDate)
        var result: [Date] = []
        var cursor = firstWeek

        while cursor <= lastWeek {
            result.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 7, to: cursor),
                  next > cursor else {
                break
            }
            cursor = next
        }
        return result
    }

    private func weekStart(containing date: Date) -> Date {
        Calendar.current.dateInterval(of: .weekOfYear, for: date)?.start
            ?? Calendar.current.startOfDay(for: date)
    }

    private func datesInWeek(starting start: Date) -> [Date] {
        let calendar = Calendar.current
        return (0..<7).compactMap {
            calendar.date(byAdding: .day, value: $0, to: start)
        }
    }

    private func isRecordDateAvailable(_ date: Date) -> Bool {
        let day = Calendar.current.startOfDay(for: date)
        return day >= firstSelectableDate && day <= lastSelectableDate
    }

    private func normalizedSelectableDate(_ date: Date) -> Date {
        let day = Calendar.current.startOfDay(for: date)
        return min(max(day, firstSelectableDate), lastSelectableDate)
    }

    private func syncVisibleWeekWithSelectedDate() {
        let target = weekStart(containing: normalizedSelectableDate(selectedDate))
        guard visibleWeekStart != target else { return }
        visibleWeekStart = target
    }

    private func handleVisibleWeekChange(to newValue: Date?) {
        guard let newValue else { return }
        let calendar = Calendar.current
        let selectedDay = calendar.startOfDay(for: selectedDate)
        let currentWeek = weekStart(containing: selectedDay)
        guard !calendar.isDate(currentWeek, inSameDayAs: newValue) else { return }

        let weekdayOffset = calendar.dateComponents([.day], from: currentWeek, to: selectedDay).day ?? 0
        let proposedDate = calendar.date(byAdding: .day, value: weekdayOffset, to: newValue) ?? newValue
        let targetDate = normalizedSelectableDate(proposedDate)

        lightHaptic()
        selectRecordDate(targetDate)
    }

    private var homeWalletCardStack: some View {
        HomeWalletCardStack(isExpanded: $isWalletStackExpanded) {
            walletBabyAgeCard
        } front: {
            dayRhythmCard
        }
    }

    private func presentBabyTrendDetail(_ metric: EasyCycleStep = .eat) {
        lightHaptic()
        dismissQuickAddMenu()
        presentedBabyTrendDetail = BabyTrendDetailContext(metric: metric)
    }

    private func presentYearningDetail() {
        lightHaptic()
        dismissQuickAddMenu()
        presentedYearningDetail = YearningDetailContext()
    }

    private func stickyCalendarHeader(
        _ metrics: RecordHomeLayoutMetrics,
        progress: CGFloat,
        scrollProxy: ScrollViewProxy
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            dateHeader(progress: progress, scrollProxy: scrollProxy)
                .padding(.bottom, lerp(metrics.dateHeaderBottom, 4, progress))
            dayPicker(progress: progress)
        }
        .padding(.horizontal, metrics.horizontalPadding)
        .padding(.top, metrics.topPadding)
        .padding(.bottom, lerp(metrics.dayPickerBottom, 4, progress))
        .frame(maxWidth: metrics.contentMaxWidth, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .top)
        .background(alignment: .top) {
            stickyHeaderBackground(progress: progress)
        }
        .shadow(color: DesignToken.shadowColor.opacity(0.06 + 0.08 * progress), radius: 16, y: 7)
        .zIndex(2)
    }

    @ViewBuilder
    private func profileAvatar(size: CGFloat, emojiSize: CGFloat) -> some View {
        BabyProfileAvatarView(
            profile: profileStore.currentProfile,
            size: size,
            emojiSize: emojiSize,
            lineWidth: size > 30 ? 1.5 : 1,
            motionScale: size > 30 ? 0.8 : 0.45,
            allowsMotion: false
        )
    }

    private func dateHeader(progress: CGFloat, scrollProxy: ScrollViewProxy) -> some View {
        let titleSize = lerp(27, 20, progress)
        let titleHeight = lerp(46, 38, progress)
        let title = Calendar.current.isDateInToday(selectedDate) ? "今天".localized : dayTitle

        return HStack(alignment: .center) {
            Text(title)
                .font(BBBFont.font(size: titleSize, weight: .bold))
                .foregroundStyle(DesignToken.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.76)
                .monospacedDigit()
                .contentTransition(.numericText(countsDown: dateTransitionDirection < 0))
                .animation(
                    reduceMotion ? nil : .snappy(duration: 0.26, extraBounce: 0),
                    value: title
                )

            if !Calendar.current.isDateInToday(selectedDate) {
                Button {
                    lightHaptic()
                    selectRecordDate(Date())
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(DesignToken.primary)
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(ScaleButtonStyle())
                .transition(.scale(scale: 0.86).combined(with: .opacity))
                .accessibilityLabel("回到今天".localized)
            }

            Spacer()

            HStack(spacing: 4) {
                headerIconButton(
                    systemName: "sun.horizon.fill",
                    accessibilityLabel: "查看 BBBrief",
                    isEnabled: bbBriefForSelectedDate != nil
                ) {
                    presentedBBBrief = bbBriefForSelectedDate
                }

                headerIconButton(
                    systemName: "gearshape.fill",
                    accessibilityLabel: "设置"
                ) {
                    showProfilePage = true
                }
            }
        }
        .frame(height: titleHeight)
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.18),
            value: Calendar.current.isDateInToday(selectedDate)
        )
    }

    private func headerIconButton(
        systemName: String,
        accessibilityLabel: String,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(DesignToken.textPrimary)
                .frame(width: 36, height: 36)
                .background(Circle().fill(DesignToken.surfaceRaised.opacity(0.88)))
                .overlay(Circle().stroke(DesignToken.glassStroke.opacity(0.72), lineWidth: 1))
                .shadow(color: DesignToken.shadowColor.opacity(0.10), radius: 7, y: 3)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.38)
        .accessibilityLabel(accessibilityLabel)
    }

    private func dayPicker(progress: CGFloat) -> some View {
        let height = lerp(54, 48, progress)

        return ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(availableWeekStarts, id: \.self) { start in
                    HStack(spacing: 0) {
                        let dates = datesInWeek(starting: start)
                        ForEach(Array(dates.enumerated()), id: \.element) { index, date in
                            let isAvailable = isRecordDateAvailable(date)
                            Button {
                                lightHaptic()
                                selectRecordDate(date)
                            } label: {
                                dayPill(date, progress: progress)
                            }
                            .buttonStyle(ScaleButtonStyle())
                            .frame(minWidth: 44, minHeight: 44)
                            .disabled(!isAvailable)
                            .opacity(isAvailable ? 1 : 0.34)

                            if index < dates.count - 1 {
                                Spacer(minLength: 0)
                            }
                        }
                    }
                    .containerRelativeFrame(.horizontal)
                    .id(start)
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $visibleWeekStart, anchor: .center)
        .scrollDisabled(availableWeekStarts.count <= 1)
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipped()
        .onAppear {
            syncVisibleWeekWithSelectedDate()
        }
        .onChange(of: selectedDate) { _, _ in
            syncVisibleWeekWithSelectedDate()
        }
        .onScrollPhaseChange { oldPhase, newPhase in
            guard oldPhase.isScrolling, !newPhase.isScrolling else { return }
            handleVisibleWeekChange(to: visibleWeekStart)
        }
    }

    private var dayRhythmCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                walletHeaderSymbolIcon(
                    systemName: "chart.line.uptrend.xyaxis"
                )
                Text("当日节奏")
                    .font(BBBFont.font(size: 15, weight: .bold))
                    .foregroundStyle(DesignToken.textPrimary)
                Spacer()
                Button {
                    showStatisticsPage = true
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(DesignToken.textSecondary)
                        .frame(width: walletCardHeaderIconSize, height: walletCardHeaderIconSize)
                        .background(
                            Circle()
                                .fill(DesignToken.surfaceRaised.opacity(0.78))
                                .overlay(Circle().stroke(DesignToken.glassStroke.opacity(0.68), lineWidth: 1))
                        )
                        .frame(width: walletCardHeaderHitSize, height: walletCardHeaderHitSize)
                        .contentShape(Circle())
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel("统计分析")
            }
            .frame(height: walletCardHeaderHitSize)

            Spacer(minLength: 6)

            rhythmSegmentBar

            Spacer(minLength: 6)

            todayRhythmTileRow(todayRhythmOverview)
        }
        .padding(.horizontal, walletCardHorizontalPadding)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            dayRhythmSurface
        )
    }

    private var bbBriefForSelectedDate: DailyReportSnapshot? {
        if Calendar.current.isDateInToday(selectedDate) {
            return bbBriefStore.latestSnapshot()
        }
        return bbBriefStore.snapshot(on: selectedDate)
    }

    private func presentPendingBBBriefReward() {
        guard let transaction = pendingBBBriefReward else { return }
        pendingBBBriefReward = nil
        BBBriefRewardFeedback.present(transaction)
        lastPresentedReportRewardTransactionID = transaction.id
    }

    private var dayRhythmSurface: some View {
        RoundedRectangle(cornerRadius: DesignToken.largeCardRadius, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: DesignToken.largeCardRadius, style: .continuous)
                    .fill(DesignToken.glassFill.opacity(0.66))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignToken.largeCardRadius, style: .continuous)
                    .strokeBorder(DesignToken.primary.opacity(0.24), lineWidth: 1)
            )
            .shadow(color: DesignToken.primary.opacity(0.06), radius: 12, y: 5)
            .shadow(color: DesignToken.shadowColor.opacity(0.08), radius: 16, y: 7)
    }

    private var easyCycleCard: some View {
        let overview = easyCycleCardOverview ?? currentEasyCycleOverview

        return Color.clear
            .aspectRatio(2, contentMode: .fit)
            .overlay {
                GeometryReader { proxy in
                    ZStack(alignment: .topLeading) {
                        easyCyclePlaceholderBackground
                        easyCycleCompletedBabyLayer(overview, size: proxy.size)

                        HStack(spacing: 5) {
                            Text("Tips")
                                .font(BBBFont.font(size: 8, weight: .heavy))
                                .foregroundStyle(DesignToken.onPrimary.opacity(0.94))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(DesignToken.primary.opacity(0.70)))

                            Text(overview.guidance.localized)
                                .font(BBBFont.font(size: 10, weight: .heavy))
                                .foregroundStyle(DesignToken.textPrimary.opacity(0.80))
                                .lineLimit(1)
                                .minimumScaleFactor(0.58)
                        }
                        .frame(width: min(proxy.size.width * 0.72, 260), alignment: .leading)
                        .padding(.leading, 18)
                        .padding(.top, 16)

                        VStack {
                            Spacer()
                            easyCycleProgress(overview)
                                .padding(.horizontal, 18)
                                .padding(.bottom, 11)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .strokeBorder(DesignToken.primary.opacity(0.34), lineWidth: 1.15)
                    )
                    .shadow(color: DesignToken.primary.opacity(0.08), radius: 14, y: 6)
                    .shadow(color: DesignToken.shadowColor.opacity(0.09), radius: 18, y: 8)
                }
            }
            .frame(maxWidth: .infinity)
            .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("这一轮 EASY，当前在\(overview.currentStep.title)，\(overview.guidance)")
    }

    private func easyCycleCompletedBabyLayer(_ overview: EasyCycleOverview, size: CGSize) -> some View {
        let imageSize = min(max(size.width * 0.18, 52), 68)
        let y = size.height * 0.42

        return ZStack {
            if overview.hasData(for: .eat) {
                easyCycleBabyImage("easy_cycle_baby_eat", imageSize: imageSize)
                    .position(x: easyCycleInterStepImageX(after: .eat, in: size.width), y: y)
            }

            if overview.hasData(for: .activity) {
                easyCycleBabyImage("easy_cycle_baby_activity", imageSize: imageSize)
                    .position(x: easyCycleInterStepImageX(after: .activity, in: size.width), y: y)
            }

            if overview.hasData(for: .sleep) {
                easyCycleBabyImage("easy_cycle_baby_sleep", imageSize: imageSize)
                    .position(x: easyCycleInterStepImageX(after: .sleep, in: size.width), y: y)
            }
        }
        .allowsHitTesting(false)
    }

    private func easyCycleBabyImage(_ assetName: String, imageSize: CGFloat) -> some View {
        Image(assetName)
            .resizable()
            .scaledToFit()
            .frame(width: imageSize, height: imageSize)
            .shadow(color: DesignToken.shadowColor.opacity(0.10), radius: 8, y: 4)
    }

    private var easyCyclePlaceholderBackground: some View {
        Image("easy_cycle_card_background")
            .resizable()
            .scaledToFill()
            .overlay {
                if colorScheme == .dark {
                    LinearGradient(
                        colors: [
                            DesignToken.surface.opacity(0.74),
                            DesignToken.surfaceSoft.opacity(0.82),
                            DesignToken.surface.opacity(0.88)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
            .overlay(
                LinearGradient(
                    colors: [
                        DesignToken.onPrimary.opacity(0),
                        DesignToken.easyEatSoft.opacity(0.14),
                        DesignToken.easyEatSoft.opacity(0.34)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }

    private func easyCycleProgress(_ overview: EasyCycleOverview) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(EasyCycleStep.allCases) { step in
                easyCycleStepNode(
                    step,
                    overview: overview,
                    recencyText: easyCycleStepRecencyText(for: step, overview: overview)
                )

                if step.index < EasyCycleStep.allCases.count - 1 {
                    Rectangle()
                        .fill(easyCycleLineColor(after: step, overview: overview))
                        .frame(height: 5)
                        .clipShape(Capsule())
                        .padding(.top, 15)
                        .padding(.horizontal, -4)
                }
            }
        }
    }

    private func easyCycleStepCenterX(_ step: EasyCycleStep, in width: CGFloat) -> CGFloat {
        let inset: CGFloat = 18
        let columnCount = CGFloat(EasyCycleStep.allCases.count)
        let availableWidth = max(width - inset * 2, 0)
        return inset + availableWidth * (CGFloat(step.index) + 0.5) / columnCount
    }

    private func easyCycleInterStepImageX(after step: EasyCycleStep, in width: CGFloat) -> CGFloat {
        let steps = EasyCycleStep.allCases
        guard step.index < steps.count - 1 else {
            return easyCycleStepCenterX(step, in: width)
        }

        let startX = easyCycleStepCenterX(step, in: width)
        let endX = easyCycleStepCenterX(steps[step.index + 1], in: width)
        return startX + (endX - startX) * 0.38
    }

    private func easyCycleStepRecencyText(
        for step: EasyCycleStep,
        overview: EasyCycleOverview
    ) -> String {
        switch step {
        case .eat:
            return compactElapsedSummaryText(since: lastFeedingDateForSummary)
        case .activity:
            let latestActivity = activityStore.careRecords
                .filter { record in
                    (record.kind == .diaper || record.kind == .activity)
                        && record.recordedAt <= now
                }
                .map(\.recordedAt)
                .max()
            return compactElapsedSummaryText(since: latestActivity)
        case .sleep:
            return compactElapsedSummaryText(since: lastSleepDateForSummary)
        case .yearning:
            return overview.yearningText
        }
    }

    private func easyCycleStepNode(
        _ step: EasyCycleStep,
        overview: EasyCycleOverview,
        recencyText: String
    ) -> some View {
        let state = overview.state(for: step)
        let nodeSize: CGFloat = 34
        let letterSize: CGFloat = 15

        return Button {
            openEasyCycleStep(step)
        } label: {
            VStack(spacing: 7) {
                easyEmphasisMarker(
                    letter: step.letter,
                    color: step.color,
                    size: nodeSize,
                    letterSize: letterSize
                )
                .shadow(color: step.color.opacity(state == .current ? 0.24 : 0.14), radius: 8, y: 3)
                .frame(width: 40, height: 36)

                VStack(spacing: 3) {
                    Text(step.title.localized)
                        .font(BBBFont.font(size: 10, weight: .heavy))
                        .foregroundStyle(DesignToken.textPrimary)
                        .lineLimit(1)

                    Text(recencyText)
                        .font(BBBFont.font(size: 11, weight: .heavy))
                        .foregroundStyle(state == .current ? step.color : DesignToken.textSecondary.opacity(0.64))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                .frame(width: 58)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("\(step.title)，\(recencyText)")
    }

    private func openEasyCycleStep(_ step: EasyCycleStep, cycleID: UUID? = nil) {
        switch step {
        case .eat:
            requestRecordCreation(.feed)
        case .activity:
            requestRecordCreation(.activity)
        case .sleep:
            requestRecordCreation(.sleep(cycleID: cycleID))
        case .yearning:
            onSubjectiveStatePrompt(.manual(at: subjectiveStatePromptDate(for: cycleID)))
        }
    }

    private func subjectiveStatePromptDate(for cycleID: UUID?) -> Date {
        guard let cycleID,
              let cycle = easyCycleStore.cycles.first(where: { $0.id == cycleID }) else {
            return Calendar.current.isDateInToday(selectedDate) ? now : selectedDate
        }
        if let endedAt = cycle.endedAt {
            // Manual Y entries use the feed's strict [start, end) association.
            // Keep a check-in opened from a completed card inside that card.
            return max(cycle.startedAt, endedAt.addingTimeInterval(-1))
        }
        return Calendar.current.isDateInToday(selectedDate) ? now : max(cycle.startedAt, selectedDate)
    }

    private var historicalRecordDialogTitle: String {
        guard let intent = pendingHistoricalRecordIntent else {
            return "确认记录日期"
        }
        return "你正在查看 \(AppDateTimeFormat.date(intent.date))"
    }

    private var historicalRecordDialogMessage: String {
        guard let intent = pendingHistoricalRecordIntent else {
            return "请选择记录日期。"
        }
        return "这条\(intent.action.title.localized)要记在哪一天？"
    }

    private var historicalBackfillButtonTitle: String {
        guard let intent = pendingHistoricalRecordIntent else {
            return "补录当前日期"
        }
        return "补录 \(AppDateTimeFormat.date(intent.date))"
    }

    private func requestRecordCreation(_ action: RecordHomeCreationAction) {
        let calendar = Calendar.current
        let targetDate = normalizedSelectableDate(selectedDate)
        guard isRecordDateAvailable(targetDate) else { return }

        if calendar.isDateInToday(targetDate) {
            performRecordCreation(action, on: Date())
        } else {
            pendingHistoricalRecordIntent = PendingHistoricalRecordIntent(
                action: action,
                date: targetDate
            )
        }
    }

    private func confirmHistoricalBackfill() {
        guard let intent = pendingHistoricalRecordIntent else { return }
        pendingHistoricalRecordIntent = nil
        performRecordCreation(intent.action, on: intent.date)
    }

    private func rerouteHistoricalRecordToToday() {
        guard let intent = pendingHistoricalRecordIntent else { return }
        pendingHistoricalRecordIntent = nil

        let today = Date()
        selectRecordDate(today)
        performRecordCreation(intent.action.withoutHistoricalCycleContext, on: today)
    }

    private func performRecordCreation(_ action: RecordHomeCreationAction, on date: Date) {
        switch action {
        case .feed:
            openFeedSheet(date)
        case .activity:
            openActivitySheet(date)
        case .sleep(let cycleID):
            openSleepSheetForCycle(cycleID, date)
        case .advanceEasyCycle:
            performEasyCyclePrimaryAction(on: date)
        }
    }

    private func easyCycleLineColor(after step: EasyCycleStep, overview: EasyCycleOverview) -> Color {
        step.color.opacity(step.index < overview.currentStep.index ? 0.46 : 0.28)
    }

    private var rhythmSegmentBar: some View {
        TodayRhythmMinimalTimeline(
            date: selectedDate,
            spans: dailyRhythmSpans,
            height: 54
        )
            .padding(.vertical, 2)
    }

    private func walletHeaderSymbolIcon(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(DesignToken.onPrimary.opacity(0.96))
            .frame(width: walletCardHeaderIconSize, height: walletCardHeaderIconSize)
            .background(
                Circle()
                    .fill(DesignToken.easyCycleGradient)
                    .overlay(
                        Circle()
                            .fill(DesignToken.onPrimary.opacity(0.10))
                    )
                    .overlay(
                        Circle()
                            .stroke(DesignToken.onPrimary.opacity(0.72), lineWidth: 1)
                    )
            )
            .shadow(
                color: DesignToken.primary.opacity(0.18),
                radius: 6,
                y: 3
            )
    }

    private var feedingSummary: some View {
        let feedingRecency = compactElapsedSummaryText(since: lastFeedingDateForSummary)
        let activityRecency = compactElapsedSummaryText(since: lastActivityDateForSummary)
        let sleepRecency = compactElapsedSummaryText(since: lastSleepDateForSummary)

        return Button {
            lightHaptic()
            dismissQuickAddMenu()
            showSingleRecordPage = true
        } label: {
            HStack(alignment: .center, spacing: 0) {
                HStack(spacing: 8) {
                    Text("距上次")
                        .font(BBBFont.font(size: 10.5, weight: .semibold))
                        .foregroundStyle(homeMetaText)
                        .lineLimit(1)

                    HStack(spacing: 10) {
                        recencyMetric(
                            badge: "E",
                            value: feedingRecency,
                            color: DesignToken.easyEat
                        )
                        recencyMetric(
                            badge: "A",
                            value: activityRecency,
                            color: DesignToken.easyActivity
                        )
                        recencyMetric(
                            badge: "S",
                            value: sleepRecency,
                            color: DesignToken.easySleep
                        )
                    }
                }

                Spacer(minLength: 10)

                HStack(spacing: 3) {
                    Text("明细")
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8.5, weight: .bold))
                }
                .font(BBBFont.font(size: 11, weight: .bold))
                .foregroundStyle(DesignToken.primary)
                .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 28)
            .background {
                Rectangle()
                    .fill(DesignToken.scrim.opacity(0.001))
                    .frame(height: DesignToken.minimumTapSize)
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "距上次：喂养\(feedingRecency)，活动\(activityRecency)，睡眠\(sleepRecency)。打开单条记录"
        )
    }

    private func recencyMetric(badge: String, value: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(badge)
                .font(BBBFont.font(size: 7.5, weight: .heavy))
                .foregroundStyle(DesignToken.onPrimary)
                .frame(width: 14, height: 14)
                .background(Circle().fill(color.opacity(0.92)))

            Text(value.localized)
                .font(BBBFont.font(size: 11.5, weight: .semibold))
                .foregroundStyle(homeBodyText)
                .monospacedDigit()
        }
        .lineLimit(1)
        .minimumScaleFactor(0.82)
    }

    private var rhythmGrid: some View {
        ZStack {
            rhythmGridGlow

            VStack(spacing: 8) {
                rhythmMetricRow(assetName: "rhythm_feeding_icon", fallbackIcon: "babybottle.fill", color: recordBottleColor) {
                    feedingRhythmHourRow()
                }
                rhythmMetricRow(assetName: "rhythm_diaper_icon", fallbackIcon: "drop.degreesign.fill", color: recordDiaperColor) {
                    rhythmHourRow(activeHours: diaperHours, activeStyle: AnyShapeStyle(recordDiaperColor))
                }
                rhythmMetricRow(assetName: "rhythm_sleep_icon", fallbackIcon: "moon.fill", color: recordSleepColor) {
                    sleepRhythmHourRow()
                }
            }
        }
        .padding(.top, 1)
        .padding(.bottom, 2)
    }

    private var rhythmGridGlow: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        recordBottleColor.opacity(0.18),
                        recordBreastColor.opacity(0.12),
                        recordSleepColor.opacity(0.18),
                        recordDiaperColor.opacity(0.10)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .blur(radius: 10)
            .opacity(0.38)
            .padding(.leading, 24)
            .padding(.trailing, 2)
            .padding(.vertical, -3)
    }

    private func rhythmMetricRow<Content: View>(
        assetName: String,
        fallbackIcon: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 8) {
            rhythmIcon(assetName: assetName, fallbackIcon: fallbackIcon, color: color)

            content()
                .frame(height: 14)
        }
    }

    @ViewBuilder
    private func rhythmIcon(assetName: String, fallbackIcon: String, color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(color.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(DesignToken.glassStroke.opacity(0.9), lineWidth: 1)
                )

            if UIImage(named: assetName) != nil {
                Image(assetName)
                    .resizable()
                    .scaledToFit()
                    .padding(3)
            } else {
                Image(systemName: fallbackIcon)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(color)
            }
        }
        .frame(width: 20, height: 20)
    }

    private func feedingRhythmHourRow() -> some View {
        GeometryReader { proxy in
            let spacing: CGFloat = 4
            let cellSize = rhythmCellSize(in: proxy.size.width, spacing: spacing)

            HStack(spacing: spacing) {
                ForEach(0..<24, id: \.self) { hour in
                    let types = feedingTypesByHour[hour] ?? []
                    rhythmGlassCell(
                        style: feedingStyle(for: types),
                        intensity: types.isEmpty ? 0.28 : 0.90,
                        size: cellSize
                    )
                }
            }
        }
        .frame(height: 13)
    }

    private func rhythmHourRow(activeHours: Set<Int>, activeStyle: AnyShapeStyle) -> some View {
        GeometryReader { proxy in
            let spacing: CGFloat = 4
            let cellSize = rhythmCellSize(in: proxy.size.width, spacing: spacing)

            HStack(spacing: spacing) {
                ForEach(0..<24, id: \.self) { hour in
                    let isActive = activeHours.contains(hour)
                    rhythmGlassCell(
                        style: isActive ? activeStyle : inactiveRhythmStyle,
                        intensity: isActive ? 0.88 : 0.28,
                        size: cellSize
                    )
                }
            }
        }
        .frame(height: 13)
    }

    private func sleepRhythmHourRow() -> some View {
        GeometryReader { proxy in
            let spacing: CGFloat = 4
            let cellSize = rhythmCellSize(in: proxy.size.width, spacing: spacing)

            HStack(spacing: spacing) {
                ForEach(0..<24, id: \.self) { hour in
                    let state = selectedSleepSummary.hourStates[hour] ?? .future
                    rhythmGlassCell(
                        style: sleepStyle(for: state),
                        intensity: sleepIntensity(for: state),
                        size: cellSize
                    )
                }
            }
        }
        .frame(height: 13)
    }

    private func rhythmCellSize(in availableWidth: CGFloat, spacing: CGFloat) -> CGFloat {
        min(max((availableWidth - spacing * 23) / 24, 2), 13)
    }

    private func rhythmGlassCell(style: AnyShapeStyle, intensity: Double, size: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(style)
                    .opacity(intensity)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                DesignToken.onPrimary.opacity(0.40),
                                DesignToken.onPrimary.opacity(0.08),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(DesignToken.glassStroke.opacity(0.72), lineWidth: 0.9)
            )
            .shadow(color: DesignToken.onPrimary.opacity(0.22), radius: 1, y: -0.5)
            .frame(width: size, height: size)
    }

    private func todayRhythmTileRow(_ overview: TodayRhythmOverview) -> some View {
        GeometryReader { proxy in
            let spacing = metricTileSpacing
            let tileWidth = max((proxy.size.width - spacing * 3) / 4, 0)

            HStack(spacing: spacing) {
                metricTileButton(.eat, width: tileWidth) {
                    babyTrendTile(
                        badge: "E",
                        title: "喂养",
                        value: overview.feedingText,
                        color: DesignToken.easyEat,
                        style: colorScheme == .dark ? .dark : .light
                    )
                }
                metricTileButton(.activity, width: tileWidth) {
                    babyTrendTile(
                        badge: "A",
                        title: "活动",
                        value: overview.activityText,
                        color: DesignToken.easyActivity,
                        style: colorScheme == .dark ? .dark : .light
                    )
                }
                metricTileButton(.sleep, width: tileWidth) {
                    babyTrendTile(
                        badge: "S",
                        title: "睡眠",
                        value: overview.sleepText,
                        color: DesignToken.easySleep,
                        style: colorScheme == .dark ? .dark : .light
                    )
                }
                metricTileButton(.yearning, width: tileWidth) {
                    subjectiveStateTile(
                        babyState: subjectiveStateStore.latestBabyState(on: selectedDate),
                        style: colorScheme == .dark ? .dark : .light
                    )
                }
            }
        }
        .frame(height: 44)
    }

    private var careGuidanceCard: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 7) {
                    profileAvatar(size: 24, emojiSize: 13)
                        .overlay(Circle().stroke(DesignToken.glassStroke.opacity(0.96), lineWidth: 1))
                        .shadow(color: DesignToken.shadowColor.opacity(0.12), radius: 7, y: 3)

                    Text(babyAgeText)
                        .font(BBBFont.font(size: 14, weight: .heavy))
                        .foregroundStyle(DesignToken.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
                }

                Text(feedingGuidanceText)
                    .font(BBBFont.font(size: 11, weight: .semibold))
                    .foregroundStyle(DesignToken.textSecondary)
                    .lineSpacing(3)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)

            Spacer(minLength: 0)

            buddyImagePlaceholder
        }
        .padding(.leading, 16)
        .padding(.trailing, 12)
        .padding(.vertical, 13)
        .background(
            glassSurface(cornerRadius: DesignToken.largeCardRadius, whiteOpacity: 0.52, shadowOpacity: 0.085)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignToken.largeCardRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    DesignToken.primary.opacity(0.10),
                                    DesignToken.glassFill.opacity(0.18),
                                    DesignToken.easySleepSoft.opacity(0.20)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignToken.largeCardRadius, style: .continuous)
                        .stroke(DesignToken.glassStroke.opacity(0.78), lineWidth: 1.1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignToken.largeCardRadius, style: .continuous))
    }

    private var walletBabyAgeCard: some View {
        BabyTrendSummaryCard(
            profile: profileStore.currentProfile,
            ageText: babyAgeText,
            dateTransitionDirection: dateTransitionDirection,
            summary: weeklyCareSummary,
            overview: babyTrendOverview,
            babyState: recentSevenDayBabyState,
            showsToggle: true,
            isExpanded: isWalletStackExpanded,
            onToggle: toggleWalletStack,
            onSelect: { step in
                if step == .yearning {
                    presentYearningDetail()
                } else {
                    presentBabyTrendDetail(step)
                }
            }
        )
    }

    private var walletBabyAgeToggleArea: some View {
        Rectangle()
            .fill(DesignToken.scrim.opacity(0.001))
            .frame(height: 104)
            .contentShape(Rectangle())
            .onTapGesture {
                toggleWalletStack()
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(isWalletStackExpanded ? "收起宝宝月龄卡" : "展开宝宝月龄卡")
    }

    private var babyTrendMetricGrid: some View {
        babyTrendTileRow(babyTrendOverview)
    }

    private var weeklyCareSummaryView: some View {
        let summary = weeklyCareSummary

        return VStack(alignment: .leading, spacing: 3) {
            ForEach(Array(summary.lines.enumerated()), id: \.offset) { _, line in
                summaryFactRow(line)
            }
        }
        .foregroundStyle(DesignToken.onPrimary.opacity(0.94))
        .allowsTightening(true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func summaryFactRow(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Circle()
                .fill(DesignToken.onPrimary.opacity(0.72))
                .frame(width: 3, height: 3)
            Text(text)
                .font(BBBFont.font(size: 9.8, weight: .semibold))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.82)
        }
    }

    private func babyTrendTileRow(_ overview: BabyTrendOverview) -> some View {
        GeometryReader { proxy in
            let spacing = metricTileSpacing
            let tileWidth = max((proxy.size.width - spacing * 3) / 4, 0)

            HStack(spacing: spacing) {
                metricTileButton(.eat, width: tileWidth) {
                    babyTrendTile(
                        badge: "E",
                        title: "喂养",
                        value: overview.feedingText,
                        color: DesignToken.easyEat
                    )
                }
                metricTileButton(.activity, width: tileWidth) {
                    babyTrendTile(
                        badge: "A",
                        title: "活动",
                        value: overview.activityText,
                        color: DesignToken.easyActivity
                    )
                }
                metricTileButton(.sleep, width: tileWidth) {
                    babyTrendTile(
                        badge: "S",
                        title: "睡眠",
                        value: overview.sleepText,
                        color: DesignToken.easySleep
                    )
                }
                metricTileButton(.yearning, width: tileWidth) {
                    subjectiveStateTile(
                        babyState: recentSevenDayBabyState,
                        style: .dark
                    )
                }
            }
        }
        .frame(height: 44)
    }

    private func metricTileButton<Label: View>(
        _ step: EasyCycleStep,
        width: CGFloat,
        @ViewBuilder label: () -> Label
    ) -> some View {
        Button {
            if step == .yearning {
                presentYearningDetail()
            } else {
                presentBabyTrendDetail(step)
            }
        } label: {
            label()
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle())
        .frame(width: width, height: 44)
        .contentShape(Rectangle())
        .accessibilityIdentifier("record-home-easy-tile-\(step.letter.lowercased())")
        .accessibilityLabel(step.pageTitle)
    }

    private func babyTrendTile(
        badge: String,
        title: String,
        value: String,
        color: Color,
        showsInfo: Bool = false,
        style: RhythmMetricTileStyle = .dark
    ) -> some View {
        RhythmMetricTile(
            badge: badge,
            title: title,
            value: value,
            color: color,
            showsInfo: showsInfo,
            style: style
        )
    }

    private func rhythmMetricBadge(
        _ letter: String,
        color: Color
    ) -> some View {
        easyEmphasisMarker(letter: letter, color: color, size: 12, letterSize: 8)
    }

    private func easyEmphasisMarker(
        letter: String,
        color: Color,
        size: CGFloat,
        letterSize: CGFloat
    ) -> some View {
        Text(letter)
            .font(BBBFont.font(size: letterSize, weight: .heavy))
            .foregroundStyle(DesignToken.onPrimary)
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(color)
                    .overlay(Circle().stroke(DesignToken.onPrimary.opacity(0.56), lineWidth: 1))
            )
    }

    private func easySemanticMarker(
        letter: String,
        color: Color,
        size: CGFloat,
        letterSize: CGFloat
    ) -> some View {
        Text(letter)
            .font(BBBFont.font(size: letterSize, weight: .heavy))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(color.opacity(0.16))
                    .overlay(Circle().stroke(color.opacity(0.84), lineWidth: size >= 28 ? 1.25 : 1))
            )
    }

    private var recentSevenDayBabyState: BabySubjectiveState? {
        let calendar = Calendar.current
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: selectedDate))
            ?? selectedDate.addingTimeInterval(24 * 60 * 60)
        let start = calendar.date(byAdding: .day, value: -7, to: end) ?? end
        return subjectiveStateStore.dominantBabyState(from: start, to: end)
    }

    private func subjectiveStateTile(
        babyState: BabySubjectiveState?,
        style: RhythmMetricTileStyle
    ) -> some View {
        RhythmSubjectiveStateTile(babyState: babyState, style: style)
    }

    @ViewBuilder
    private func subjectiveTileValue(
        icon: SubjectiveStateIcon.Kind?,
        title: String,
        style: RhythmMetricTileStyle
    ) -> some View {
        HStack(spacing: 1.5) {
            if let icon {
                SubjectiveStateIcon(kind: icon, size: 14)
            }
            Text(title.localized)
                .font(BBBFont.font(size: metricTileValueFontSize, weight: .heavy))
                .foregroundStyle(style.mainColor)
                .lineLimit(1)
                .minimumScaleFactor(0.01)
                .allowsTightening(true)
        }
        .frame(maxWidth: .infinity)
    }

    private func babyTrendTileValue(
        _ value: String,
        style: RhythmMetricTileStyle,
        infoAccent: Color,
        showsInfo: Bool
    ) -> some View {
        return HStack(alignment: .firstTextBaseline, spacing: 1) {
            Text(value.localized)
                .font(BBBFont.font(size: metricTileValueFontSize, weight: .heavy))
                .foregroundStyle(style.mainColor)
                .lineLimit(1)
                .minimumScaleFactor(0.01)
                .allowsTightening(true)

            if showsInfo {
                Image(systemName: "exclamationmark")
                    .font(.system(size: 5.5, weight: .black))
                    .foregroundStyle(style.infoIconColor(accent: infoAccent))
                    .frame(width: 10, height: 10)
                    .background(
                        Circle()
                            .fill(style.infoFillColor(accent: infoAccent))
                            .overlay(Circle().stroke(style.infoStrokeColor(accent: infoAccent), lineWidth: 0.7))
                    )
                    .alignmentGuide(.firstTextBaseline) { dimensions in
                        dimensions[VerticalAlignment.center] + 3
                    }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var walletBabyAgeTitle: some View {
        HStack(spacing: 8) {
            walletHeaderAvatar

            Text(babyAgeText)
                .font(BBBFont.font(size: 15, weight: .bold))
                .foregroundStyle(DesignToken.onPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.76)
                .shadow(color: DesignToken.shadowColor.opacity(0.28), radius: 4, y: 2)

            Spacer(minLength: 8)

            walletStackToggleIndicator
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var walletHeaderAvatar: some View {
        profileAvatar(size: walletCardHeaderIconSize, emojiSize: walletCardHeaderIconSize * 0.5)
            .overlay(Circle().stroke(DesignToken.onPrimary.opacity(0.96), lineWidth: 1))
            .shadow(color: DesignToken.shadowColor.opacity(0.24), radius: 6, y: 3)
    }

    private var walletStackToggleIndicator: some View {
        Button {
            toggleWalletStack()
        } label: {
            Image(systemName: isWalletStackExpanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(DesignToken.onPrimary.opacity(0.94))
                .frame(width: walletCardHeaderIconSize, height: walletCardHeaderIconSize)
                .background(
                    Circle()
                        .fill(DesignToken.onPrimary.opacity(0.16))
                        .overlay(Circle().stroke(DesignToken.onPrimary.opacity(0.30), lineWidth: 1))
                )
                .shadow(color: DesignToken.shadowColor.opacity(0.24), radius: 7, y: 3)
                .frame(width: walletCardHeaderHitSize, height: walletCardHeaderHitSize)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isWalletStackExpanded ? "收起宝宝月龄卡" : "展开宝宝月龄卡")
    }

    private func toggleWalletStack() {
        lightHaptic()
        withAnimation(.walletCardPush) {
            isWalletStackExpanded.toggle()
        }
    }

    private var walletBabyAgeSurface: some View {
        RoundedRectangle(cornerRadius: DesignToken.largeCardRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        DesignToken.primary.opacity(0.98),
                        DesignToken.feedingBreast.opacity(0.92)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignToken.largeCardRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                DesignToken.onPrimary.opacity(0.13),
                                DesignToken.onPrimary.opacity(0.02)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignToken.largeCardRadius, style: .continuous)
                    .strokeBorder(DesignToken.onPrimary.opacity(0.56), lineWidth: 1)
            )
    }

    private var buddyImagePlaceholder: some View {
        Image("home_buddy_placeholder")
            .resizable()
            .scaledToFit()
            .frame(width: 152, height: 142)
            .offset(x: 20, y: 8)
            .frame(width: 100, height: 90, alignment: .bottomTrailing)
    }

    private func recordTimelineModeSection(scrollProxy: ScrollViewProxy) -> some View {
        LazyVStack(alignment: .leading, spacing: 10) {
            feedingSummary

            if !activeTimingItems.isEmpty {
                activeTimingCards
            }

            easyCycleTimelineSection

            if currentEasyFeedSnapshot?.cards.isEmpty == false {
                Button {
                    lightHaptic()
                    scrollToRhythm(with: scrollProxy)
                } label: {
                    Label("回到顶部", systemImage: "arrow.up")
                        .font(BBBFont.font(size: 11, weight: .bold))
                        .foregroundStyle(homeMetaText)
                        .padding(.horizontal, 14)
                        .frame(height: 34)
                        .background(Capsule().fill(DesignToken.glassFill.opacity(0.62)))
                }
                .buttonStyle(ScaleButtonStyle())
                .frame(maxWidth: .infinity)
                .padding(.top, 2)
            }
        }
    }

    private var singleRecordPage: some View {
        NavigationStack {
            ZStack {
                recordBackground.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        if Calendar.current.isDateInToday(selectedDate) {
                            easyCycleCard
                        }

                        if !activeTimingItems.isEmpty {
                            activeTimingCards
                        }
                        timelineSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 36)
                }
            }
            .navigationTitle("单条记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    AppPageCloseButton { showSingleRecordPage = false }
                }
            }
        }
    }

    private var activeTimingItems: [ActiveTimingItem] {
        guard Calendar.current.isDateInToday(selectedDate) else { return [] }
        return [feedingDraftStore.activeTimingItem, sleepDraftStore.activeTimingItem]
            .compactMap { $0 }
            .sorted { $0.startedAt > $1.startedAt }
    }

    private var activeTimingCards: some View {
        VStack(spacing: 8) {
            ForEach(activeTimingItems) { item in
                activeTimingCard(item)
            }
        }
    }

    private func activeTimingCard(_ item: ActiveTimingItem) -> some View {
        let color = item.kind == .sleep ? DesignToken.easySleep : DesignToken.easyEat

        return HStack(spacing: 10) {
            Button {
                lightHaptic()
                dismissQuickAddMenu()
                if item.kind == .sleep {
                    openSleepSheet(Date())
                } else {
                    openFeedingTiming()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: item.kind == .sleep ? "moon.zzz.fill" : "timer")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(DesignToken.onPrimary)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(color))

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 5) {
                            Text(item.kind.title.localized)
                            Text("记录中")
                                .foregroundStyle(color)
                        }
                        .font(BBBFont.font(size: 12.5, weight: .bold))
                        .foregroundStyle(DesignToken.textPrimary)

                        Text(activeTimingStartText(item))
                            .font(BBBFont.font(size: 11, weight: .semibold))
                            .foregroundStyle(homeMetaText)
                    }

                    Spacer(minLength: 8)

                    Text(item.detail.localized)
                        .font(BBBFont.font(size: 11, weight: .semibold))
                        .foregroundStyle(homeBodyText)
                        .lineLimit(1)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Menu {
                Button("取消计时", role: .destructive) {
                    pendingTimingCancellation = item.kind
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(homeMetaText.opacity(0.72))
                    .frame(width: 30, height: 30)
            }
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 54)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(DesignToken.glassFill.opacity(0.72))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(color.opacity(0.22), lineWidth: 1)
                )
                .shadow(color: color.opacity(0.08), radius: 12, y: 6)
        )
    }

    private func activeTimingStartText(_ item: ActiveTimingItem) -> String {
        let action: String
        switch item.kind {
        case .nursing: action = "开始亲喂"
        case .bottle: action = "开始瓶喂"
        case .sleep: action = "开始入睡"
        }
        return "\(AppDateTimeFormat.time(item.startedAt)) \(action)"
    }

    private func cancelActiveTiming() {
        guard let kind = pendingTimingCancellation else { return }
        if kind == .sleep {
            sleepDraftStore.resetDraft()
        } else {
            feedingDraftStore.resetDraft()
        }
        pendingTimingCancellation = nil
    }

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 0) {
                if timelineItems.isEmpty {
                    emptyTimeline
                } else {
                    ForEach(Array(timelineItems.enumerated()), id: \.element.id) { index, item in
                        let nextItem = index + 1 < timelineItems.count ? timelineItems[index + 1] : nil
                        timelineRow(item, nextItem: nextItem)
                    }
                    timelineEnd
                }
        }
        .padding(.horizontal, 16)
        .padding(.top, timelineItems.isEmpty ? 18 : 16)
        .padding(.bottom, timelineItems.isEmpty ? 20 : 18)
        .background(
            glassSurface(cornerRadius: DesignToken.largeCardRadius, whiteOpacity: 0.66, shadowOpacity: 0.07)
        )
    }

    private var easyCycleTimelineSection: some View {
        LazyVStack(alignment: .leading, spacing: 12) {
            if let snapshot = currentEasyFeedSnapshot {
                if snapshot.cards.isEmpty {
                    emptyEasyCycleTimeline
                } else {
                    ForEach(visibleEasyCycleCardModels) { model in
                        EasyCycleTimelineCardView(
                            model: model,
                            onOpenStep: { step in
                                openEasyCycleStep(step, cycleID: model.id)
                            },
                            onEdit: { item in
                                presentQuickRecordEdit(item)
                            },
                            onDelete: { item in
                                pendingDeleteItem = item
                            }
                        )
                        .equatable()
                        .id(model.id)
                    }

                    if visibleEasyCycleCardModels.count < snapshot.cards.count {
                        Color.clear
                            .frame(height: 1)
                            .accessibilityHidden(true)
                            .onAppear {
                                loadNextEasyCyclePage()
                            }
                    }
                }
            }
        }
        .scrollTargetLayout()
    }

    private var emptyEasyCycleTimeline: some View {
        HStack(alignment: .center, spacing: 10) {
            easyLetterTile(letter: "Y", color: DesignToken.easyYearning, size: timelineIconSize)

            VStack(alignment: .leading, spacing: 5) {
                Text("还没有 EASY 循环")
                    .font(BBBFont.font(size: 13, weight: .heavy))
                    .foregroundStyle(DesignToken.textPrimary)
                Text("记录喂养或尿布后，会自动生成第一轮。")
                    .font(BBBFont.font(size: 11.5, weight: .semibold))
                    .foregroundStyle(homeBodyText)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: DesignToken.largeCardRadius, style: .continuous)
                .fill(DesignToken.glassFill.opacity(0.68))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignToken.largeCardRadius, style: .continuous)
                        .stroke(DesignToken.glassStroke.opacity(0.72), lineWidth: 1)
                )
                .shadow(color: DesignToken.shadowColor.opacity(0.12), radius: 14, y: 7)
        )
    }

    private func easyCycleTimelineCard(_ cycle: EasyCycle) -> some View {
        let rows = easyCycleTimelineRows(for: cycle) + [easyCycleYearningTimelineRow(for: cycle)]

        return VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .center, spacing: 10) {
                Text(easyCycleOrdinalText(cycle))
                    .font(BBBFont.font(size: 12, weight: .heavy))
                    .foregroundStyle(DesignToken.onPrimary)
                    .padding(.horizontal, 12)
                    .frame(height: 30)
                    .background(
                        Capsule()
                            .fill(DesignToken.easyCycleGradient)
                            .overlay(
                                Capsule()
                                    .stroke(DesignToken.onPrimary.opacity(0.42), lineWidth: 1)
                            )
                            .shadow(color: DesignToken.shadowColor.opacity(0.20), radius: 9, y: 4)
                    )

                Rectangle()
                    .fill(DesignToken.primary.opacity(0.12))
                    .frame(height: 1)

                Text(easyCycleHeaderTimeText(cycle))
                    .font(BBBFont.font(size: 11, weight: .heavy))
                    .foregroundStyle(easyCycleStatusColor(cycle))
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(Capsule().fill(easyCycleStatusColor(cycle).opacity(0.14)))
            }

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    easyCycleTimelineRow(
                        row,
                        cycle: cycle,
                        isLast: index == rows.count - 1
                    )
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: DesignToken.largeCardRadius, style: .continuous)
                .fill(DesignToken.glassFill.opacity(0.74))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignToken.largeCardRadius, style: .continuous)
                        .stroke(DesignToken.glassStroke.opacity(0.74), lineWidth: 1)
                )
                .shadow(color: DesignToken.shadowColor.opacity(0.16), radius: 16, y: 8)
        )
        .contentShape(RoundedRectangle(cornerRadius: DesignToken.largeCardRadius, style: .continuous))
    }

    private func easyCycleTimelineRow(_ row: EasyCycleTimelineRow, cycle: EasyCycle, isLast: Bool) -> some View {
        let detailCount = max(row.detailItems.count, 1)
        let connectorHeight = max(36, CGFloat(detailCount) * 32 + 4)

        return HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                if row.step == .yearning {
                    Button {
                        openEasyCycleStep(.yearning, cycleID: cycle.id)
                    } label: {
                        easyCycleTimelineNode(row)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityLabel("状态，记录这一刻".localized)
                } else {
                    Button {
                        openEasyCycleStep(row.step, cycleID: cycle.id)
                    } label: {
                        easyCycleTimelineNode(row)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityLabel("\(row.step.title)，继续记录")
                }

                if !isLast {
                    Rectangle()
                        .fill(row.step.color.opacity(0.22))
                        .frame(width: 1.2, height: connectorHeight)
                        .padding(.top, 4)
                        .padding(.bottom, 4)
                }
            }
            .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    if !row.title.isEmpty {
                        Text(row.title.localized)
                            .font(BBBFont.font(size: 13.5, weight: .heavy))
                            .foregroundStyle(DesignToken.textPrimary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    Text(row.timeText.localized)
                        .font(BBBFont.font(size: 10.5, weight: .heavy))
                        .foregroundStyle(homeMetaText)
                        .lineLimit(1)
                }

                if row.step == .yearning {
                    easyCycleSubjectiveStateContent(for: cycle)
                } else if row.detailItems.isEmpty {
                    Text(row.primaryText.localized)
                        .font(BBBFont.font(size: 12, weight: .semibold))
                        .foregroundStyle(homeBodyText)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(1)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(row.detailItems) { detail in
                            easyCycleTimelineDetailRow(detail)
                        }
                    }
                    .padding(.top, 0)
                }

                if !row.secondaryText.isEmpty {
                    Text(row.secondaryText.localized)
                        .font(BBBFont.font(size: 11, weight: .semibold))
                        .foregroundStyle(homeMetaText)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(1)
                }
            }
            .padding(.top, 1)
        }
        .padding(.bottom, isLast ? 0 : 1)
    }

    private func easyCycleTimelineNode(_ row: EasyCycleTimelineRow) -> some View {
        easySemanticMarker(letter: row.step.letter, color: row.step.color, size: 36, letterSize: 14)
            .shadow(color: row.step.color.opacity(0.08), radius: 7, y: 4)
    }

    private func easyCycleYearningTimelineRow(for cycle: EasyCycle) -> EasyCycleTimelineRow {
        return EasyCycleTimelineRow(
            step: .yearning,
            title: "",
            primaryText: "",
            secondaryText: "",
            timeText: "",
            detailItems: []
        )
    }

    private func easyCycleSubjectiveStateContent(for cycle: EasyCycle) -> some View {
        let end = easyCycleBoundaryDate(for: cycle)
        let baby = subjectiveStateStore.babySequenceSummary(from: cycle.startedAt, to: end)
        let parent = subjectiveStateStore.parentSequenceSummary(from: cycle.startedAt, to: end)
        let showsYearning = subjectiveStateStore.showsYearningMarker(from: cycle.startedAt, to: end)

        return VStack(alignment: .leading, spacing: 7) {
            if !baby.values.isEmpty {
                HStack(spacing: 5) {
                    ForEach(Array(baby.values.enumerated()), id: \.offset) { _, state in
                        SubjectiveStateIcon(kind: .baby(state), size: 28)
                    }

                    if showsYearning {
                        Text("Yearning!".localized)
                            .font(BBBFont.font(size: 11.5, weight: .heavy))
                            .foregroundStyle(DesignToken.easyYearning)
                            .lineLimit(1)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                    (baby.values.map(\.accessibilityLabel) + (showsYearning ? ["Yearning!".localized] : [])).joined(separator: ", ")
                )
            }

            if let parentState = parent.values.last {
                Text(
                    "\(Text(AppLocalization.format("You %@ · ", parentState.title.localized)).font(BBBFont.font(size: 10.5, weight: .heavy)).foregroundColor(homeBodyText))\(Text(parentState.carePrompt(at: cycle.startedAt).localized).font(BBBFont.font(size: 10.5, weight: .semibold)).foregroundColor(homeMetaText))"
                )
                .lineLimit(1)
                .truncationMode(.tail)
                .minimumScaleFactor(0.88)
                .accessibilityLabel(
                    "\(parentState.accessibilityLabel)，\(parentState.carePrompt(at: cycle.startedAt).localized)"
                )
            }
        }
    }

    private func easyCycleTimelineDetailRow(_ detail: EasyCycleTimelineDetailItem) -> some View {
        HStack(alignment: .center, spacing: 7) {
            compactTimelineTimestamp(detail.timeText)

            Text(detail.bodyText.localized)
                .font(BBBFont.font(size: 11.8, weight: .semibold))
                .foregroundStyle(homeBodyText)
                .lineLimit(detail.item.isActivityRecord ? 1 : 2)
                .truncationMode(.tail)
                .minimumScaleFactor(0.78)
                .lineSpacing(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            easyCycleTimelineDetailMenu(for: detail.item)
        }
        .padding(.vertical, 3)
        .padding(.leading, 0)
        .padding(.trailing, 2)
        .frame(minHeight: 30)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(DesignToken.glassFill.opacity(0.18))
        )
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func easyCycleTimelineDetailMenu(for item: RecordHomeTimelineItem) -> some View {
        Menu {
            Button {
                presentQuickRecordEdit(item)
            } label: {
                Label("修改", systemImage: "pencil")
            }

            Button(role: .destructive) {
                pendingDeleteItem = item
            } label: {
                Label("删除", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(homeMetaText.opacity(0.82))
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("更多操作")
    }

    private func compactTimelineTimestamp(_ text: String) -> some View {
        Text(text.localized)
            .font(BBBFont.font(size: 7.8, weight: .semibold))
            .foregroundStyle(homeMetaText)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .frame(width: 40, height: 15)
            .background(
                Capsule()
                    .fill(homeMetaText.opacity(0.065))
                    .overlay(Capsule().stroke(homeMetaText.opacity(0.14), lineWidth: 0.7))
            )
    }

    private func easyCycleSummaryPill(step: EasyCycleStep, value: String) -> some View {
        VStack(spacing: 4) {
            easySemanticMarker(letter: step.letter, color: step.color, size: 24, letterSize: 11)
            Text(value.localized)
                .font(BBBFont.font(size: 10.5, weight: .heavy))
                .foregroundStyle(DesignToken.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
        }
        .frame(maxWidth: .infinity)
    }

    private func easyCycleOrdinalText(_ cycle: EasyCycle) -> String {
        let cycles = easyCycleTimelineItems.sorted { $0.startedAt < $1.startedAt }
        guard let index = cycles.firstIndex(where: { $0.id == cycle.id }) else {
            return "本轮循环".localized
        }
        return AppLocalization.format("第 %d 轮循环", index + 1)
    }

    private func easyCycleTimelineRows(for cycle: EasyCycle) -> [EasyCycleTimelineRow] {
        let sessions = cycleFeedingSessions(for: cycle)
        let careRecords = cycleCareRecords(for: cycle)
        let activityRecords = careRecords.filter { $0.kind != .sleep }
        let sleepRecords = careRecords.filter { $0.kind == .sleep }

        return [
            EasyCycleTimelineRow(
                step: .eat,
                title: sessions.isEmpty ? AppLocalization.format("%@ %@", "喂养".localized, "待记录".localized) : AppLocalization.format("喂养 %@", AppQuantityFormat.records(sessions.count)),
                primaryText: sessions.isEmpty ? "醒来先吃 吃得饱饱".localized : "",
                secondaryText: "",
                timeText: sessions.isEmpty ? easyCycleEmptyElapsedText(step: .eat, cycle: cycle) : easyCycleFeedingTotalText(sessions),
                detailItems: sessions.isEmpty ? [] : easyCycleFeedingDetails(sessions)
            ),
            EasyCycleTimelineRow(
                step: .activity,
                title: activityRecords.isEmpty ? AppLocalization.format("%@ %@", "活动".localized, "待记录".localized) : AppLocalization.format("活动 %@", AppQuantityFormat.records(activityRecords.count)),
                primaryText: activityRecords.isEmpty ? "清醒活动 玩得开心".localized : "",
                secondaryText: "",
                timeText: activityRecords.isEmpty ? easyCycleEmptyElapsedText(step: .activity, cycle: cycle) : AppLocalization.format("共 %d 项", easyCycleActivityTypeCount(activityRecords)),
                detailItems: activityRecords.isEmpty ? [] : easyCycleActivityDetails(activityRecords)
            ),
            EasyCycleTimelineRow(
                step: .sleep,
                title: sleepRecords.isEmpty ? AppLocalization.format("%@ %@", "睡眠".localized, "待记录".localized) : AppLocalization.format("睡眠 %@", AppQuantityFormat.records(sleepRecords.count)),
                primaryText: sleepRecords.isEmpty ? "大脑升级 睡得香甜".localized : "",
                secondaryText: "",
                timeText: sleepRecords.isEmpty ? easyCycleEmptyElapsedText(step: .sleep, cycle: cycle) : easyCycleSleepTotalText(sleepRecords),
                detailItems: sleepRecords.isEmpty ? [] : easyCycleSleepDetails(sleepRecords)
            )
        ]
    }

    private func easyCycleFeedingSummary(_ sessions: [FeedingSession]) -> String {
        let breastCount = sessions.filter { $0.totalBreastDuration > 0 }.count
        let bottleCount = sessions.filter { $0.totalBottleAmount > 0 }.count
        let solidCount = sessions.filter { $0.totalSolidAmount > 0 }.count
        let milkML = sessions.reduce(0) { $0 + $1.totalBottleAmount }
        let breastMinutes = sessions.reduce(0) { $0 + $1.totalBreastDuration }
        let solidAmount = sessions.reduce(0) { $0 + $1.totalSolidAmount }
        var parts: [String] = []
        if breastCount > 0 { parts.append(AppLocalization.format("母乳 %@", AppQuantityFormat.records(breastCount))) }
        if bottleCount > 0 { parts.append(AppLocalization.format("奶瓶 %@", AppQuantityFormat.records(bottleCount))) }
        if solidCount > 0 { parts.append(AppLocalization.format("辅食 %@", AppQuantityFormat.records(solidCount))) }
        if milkML > 0 { parts.append(AppLocalization.format("奶瓶 %@", AppMeasurementFormat.volume(Double(milkML)))) }
        if breastMinutes > 0 { parts.append(AppLocalization.format("亲喂 %@", AppQuantityFormat.compactDuration(breastMinutes))) }
        if solidAmount > 0 { parts.append(AppLocalization.format("辅食 %@", AppMeasurementFormat.mass(solidAmount))) }
        return parts.isEmpty ? "喂养已记录".localized : parts.joined(separator: " · ")
    }

    private func easyCycleFeedingTotalText(_ sessions: [FeedingSession]) -> String {
        let bottleAmount = sessions.reduce(0) { $0 + $1.totalBottleAmount }
        let breastMinutes = sessions.reduce(0) { $0 + $1.totalBreastDuration }
        let solidAmount = sessions.reduce(0) { $0 + $1.totalSolidAmount }
        var parts: [String] = []
        if bottleAmount > 0 { parts.append(AppMeasurementFormat.volume(Double(bottleAmount))) }
        if breastMinutes > 0 { parts.append(AppQuantityFormat.compactDuration(breastMinutes)) }
        if solidAmount > 0 { parts.append(AppLocalization.format("辅食 %@", AppMeasurementFormat.mass(solidAmount))) }
        return parts.isEmpty ? "已记录".localized : parts.joined(separator: " · ")
    }

    private func easyCycleFeedingDetails(_ sessions: [FeedingSession]) -> [EasyCycleTimelineDetailItem] {
        sessions
            .sorted { $0.eventDate < $1.eventDate }
            .flatMap { easyCycleFeedingDetails(for: $0) }
    }

    private func easyCycleFeedingTypesSummary(_ sessions: [FeedingSession]) -> String {
        let firstTimes = sessions
            .prefix(2)
            .map { easyCycleClockText($0.eventDate) }
            .joined(separator: "、")
        return firstTimes.isEmpty ? "喂养记录已归入本轮".localized : AppLocalization.format("记录时间 %@", firstTimes)
    }

    private func easyCycleFeedingDetails(for session: FeedingSession) -> [EasyCycleTimelineDetailItem] {
        let eventTime = easyCycleClockText(session.eventDate)
        let item = RecordHomeTimelineItem.feeding(session)
        var details: [EasyCycleTimelineDetailItem] = []

        let breastEntries = session.entries.filter { $0.type == .breast }
        let leftMinutes = breastEntries
            .filter { $0.breastSide == .left }
            .compactMap(\.breastDuration)
            .reduce(0, +)
        let rightMinutes = breastEntries
            .filter { $0.breastSide == .right }
            .compactMap(\.breastDuration)
            .reduce(0, +)
        let totalBreastMinutes = breastEntries.compactMap(\.breastDuration).reduce(0, +)
        if totalBreastMinutes > 0 {
            let sideText = [leftMinutes > 0 ? AppLocalization.format("左 %@", AppQuantityFormat.compactDuration(leftMinutes)) : "", rightMinutes > 0 ? AppLocalization.format("右 %@", AppQuantityFormat.compactDuration(rightMinutes)) : ""]
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            let breastText = sideText.isEmpty
                ? AppLocalization.format("亲喂 %@", AppQuantityFormat.compactDuration(totalBreastMinutes))
                : AppLocalization.format("亲喂 %@ %@", AppQuantityFormat.compactDuration(totalBreastMinutes), sideText)
            details.append(EasyCycleTimelineDetailItem(
                id: "\(session.id.uuidString)-breast",
                timeText: eventTime,
                bodyText: breastText,
                item: item
            ))
        }

        let bottleGroups = Dictionary(grouping: session.entries.filter { $0.type == .bottle }, by: { $0.milkType ?? .formula })
        for (milkType, entries) in bottleGroups.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            let amount = entries.compactMap(\.bottleAmount).reduce(0, +)
            guard amount > 0 else { continue }
            let label = (milkType == .expressed ? "母乳瓶喂" : "瓶喂").localized
            details.append(EasyCycleTimelineDetailItem(
                id: "\(session.id.uuidString)-bottle-\(milkType.rawValue)",
                timeText: eventTime,
                bodyText: "\(label) \(AppMeasurementFormat.volume(Double(amount)))",
                item: item
            ))
        }

        let solidEntries = session.entries.filter { $0.type == .solid }
        for (index, entry) in solidEntries.enumerated() {
            let food = entry.solidFood?.displayName ?? "辅食".localized
            let amount: String
            if let canonicalAmount = entry.solidAmount {
                switch entry.solidUnit ?? .g {
                case .g: amount = AppMeasurementFormat.mass(canonicalAmount)
                case .ml: amount = AppMeasurementFormat.volume(canonicalAmount)
                default:
                    amount = "\(AppMeasurementFormat.inputNumber(canonicalAmount)) \((entry.solidUnit ?? .g).localizedDisplayName)"
                }
            } else {
                amount = ""
            }
            details.append(EasyCycleTimelineDetailItem(
                id: "\(session.id.uuidString)-solid-\(index)",
                timeText: eventTime,
                bodyText: "\(food) \(amount)",
                item: item
            ))
        }

        if details.isEmpty {
            return [EasyCycleTimelineDetailItem(
                id: "\(session.id.uuidString)-feeding",
                timeText: eventTime,
                bodyText: "喂养已记录".localized,
                item: item
            )]
        }

        return details
    }

    private func easyCycleActivityDetail(_ records: [CareRecord]) -> String {
        guard !records.isEmpty else { return "点 A 补充本轮活动/护理记录".localized }
        return "尿布：".localized + records
            .map { "\(DiaperRecordType.normalizedTitle($0.title))（\(easyCycleClockText($0.recordedAt))）" }
            .joined(separator: " · ")
    }

    private func easyCycleActivitySummary(_ records: [CareRecord]) -> String {
        let peeCount = records.filter { DiaperRecordType.normalizedTitle($0.title).contains("尿") }.count
        let poopCount = records.filter { DiaperRecordType.normalizedTitle($0.title).contains("拉") }.count
        var parts = [AppLocalization.format("尿布 %@", AppQuantityFormat.records(records.count))]
        if peeCount > 0 { parts.append(AppLocalization.format("尿 %@", AppQuantityFormat.records(peeCount))) }
        if poopCount > 0 { parts.append(AppLocalization.format("拉 %@", AppQuantityFormat.records(poopCount))) }
        return parts.joined(separator: " · ")
    }

    private func easyCycleActivityTypeCount(_ records: [CareRecord]) -> Int {
        Set(records.map(easyCycleActivityTypeName)).count
    }

    private func easyCycleActivityTypeName(_ record: CareRecord) -> String {
        switch record.kind {
        case .diaper:
            return "尿布".localized
        case .activity:
            return record.title
        case .sleep:
            return "睡眠".localized
        }
    }

    private func easyCycleActivityDetails(_ records: [CareRecord]) -> [EasyCycleTimelineDetailItem] {
        records
            .sorted { $0.recordedAt < $1.recordedAt }
            .map { record in
                let time = easyCycleClockText(record.recordedAt)
                let item = RecordHomeTimelineItem.care(record)
                let bodyText: String
                switch record.kind {
                case .diaper:
                    bodyText = easyCycleDiaperLineText(record)
                case .activity:
                    bodyText = easyCycleActivityLineText(record)
                case .sleep:
                    bodyText = "睡眠".localized
                }
                return EasyCycleTimelineDetailItem(
                    id: record.id.uuidString,
                    timeText: time,
                    bodyText: bodyText,
                    item: item
                )
            }
    }

    private func easyCycleDiaperLineText(_ record: CareRecord) -> String {
        DiaperRecordType.displayDetail(title: record.title, detail: record.detail)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func easyCycleActivityLineText(_ record: CareRecord) -> String {
        let compactTitle = ActivityRecordDisplayFormatter.compactSummary(from: record.title)
        if record.title.hasPrefix("宝宝完成") {
            return compactTitle
        }
        let detail = record.detail
            .replacingOccurrences(of: " 分钟", with: "分钟")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !detail.isEmpty else { return compactTitle }
        return "\(compactTitle) \(detail)"
    }

    private func easyCycleSleepDetail(_ records: [CareRecord]) -> String {
        guard !records.isEmpty else { return "点 S 补充本轮睡眠记录".localized }
        return records
            .compactMap { record -> String? in
                guard let minutes = SleepRecordFormatter.durationMinutes(from: record.detail) else { return nil }
                let end = SleepRecordFormatter.endTime(start: record.recordedAt, durationMinutes: minutes)
                let title = SleepRecordFormatter.sleepTitle(start: record.recordedAt, end: end)
                return AppLocalization.format(
                    "%@ %@，%@",
                    title,
                    AppDateTimeFormat.timeRange(from: record.recordedAt, to: end),
                    easyCycleDurationText(minutes)
                )
            }
            .joined(separator: "\n")
    }

    private func easyCycleSleepSummary(_ records: [CareRecord]) -> String {
        let totalMinutes = records.reduce(0) { $0 + (SleepRecordFormatter.durationMinutes(from: $1.detail) ?? 0) }
        let nightCount = records.filter {
            NightSleepAnalyzer.isNightWindowStart($0.recordedAt)
        }.count
        let napCount = max(records.count - nightCount, 0)
        var parts = [AppLocalization.format("共 %@", easyCycleDurationText(totalMinutes)), AppLocalization.format("%@ 段", AppQuantityFormat.records(records.count))]
        if napCount > 0 { parts.append(AppLocalization.format("小睡 %@", AppQuantityFormat.records(napCount))) }
        if nightCount > 0 { parts.append(AppLocalization.format("夜睡 %@", AppQuantityFormat.records(nightCount))) }
        return parts.joined(separator: " · ")
    }

    private func easyCycleSleepTotalText(_ records: [CareRecord]) -> String {
        let totalMinutes = records.reduce(0) { $0 + (SleepRecordFormatter.durationMinutes(from: $1.detail) ?? 0) }
        return easyCycleDurationText(totalMinutes)
    }

    private func easyCycleSleepDetails(_ records: [CareRecord]) -> [EasyCycleTimelineDetailItem] {
        records
            .sorted { $0.recordedAt < $1.recordedAt }
            .map { record in
                let item = RecordHomeTimelineItem.care(record)
                guard let minutes = SleepRecordFormatter.durationMinutes(from: record.detail) else {
                    return EasyCycleTimelineDetailItem(
                        id: record.id.uuidString,
                        timeText: easyCycleClockText(record.recordedAt),
                        bodyText: "睡眠已记录".localized,
                        item: item
                    )
                }
                let end = SleepRecordFormatter.endTime(start: record.recordedAt, durationMinutes: minutes)
                let title = SleepRecordFormatter.sleepTitle(start: record.recordedAt, end: end)
                return EasyCycleTimelineDetailItem(
                    id: record.id.uuidString,
                    timeText: easyCycleClockText(record.recordedAt),
                    bodyText: AppLocalization.format("%@ %@ %@ 醒来", title, AppQuantityFormat.compactDuration(minutes), easyCycleClockText(end)),
                    item: item
                )
            }
    }

    private func easyCycleSleepRangeText(_ records: [CareRecord]) -> String {
        let dates = records.flatMap { record -> [Date] in
            guard let minutes = SleepRecordFormatter.durationMinutes(from: record.detail) else {
                return [record.recordedAt]
            }
            return [record.recordedAt, SleepRecordFormatter.endTime(start: record.recordedAt, durationMinutes: minutes)]
        }
        return easyCycleRangeText(dates: dates)
    }

    private func easyCycleRangeText(dates: [Date]) -> String {
        guard let first = dates.min(), let last = dates.max() else { return "待记录".localized }
        if abs(last.timeIntervalSince(first)) < 60 {
            return easyCycleClockText(first)
        }
        return AppDateTimeFormat.timeRange(from: first, to: last)
    }

    private func easyCycleDurationText(_ minutes: Int) -> String {
        AppQuantityFormat.compactDuration(minutes)
    }

    private func easyCycleAmountText(_ value: Double) -> String {
        guard value.isFinite else { return "—" }
        if value.rounded() == value {
            return "\(Int(value))"
        }
        return String(format: "%.1f", value)
    }

    private func easyCycleEmptyElapsedText(step: EasyCycleStep, cycle: EasyCycle) -> String {
        let reference = Calendar.current.isDateInToday(selectedDate)
            ? now
            : easyCycleBoundaryDate(for: cycle)
        let lastDate: Date?
        switch step {
        case .eat:
            lastDate = lastFeedingDateForSummary
        case .activity:
            lastDate = lastActivityDateForSummary
        case .sleep:
            lastDate = lastSleepDateForSummary
        case .yearning:
            lastDate = nil
        }
        guard let lastDate else {
            return "距上次暂无".localized
        }
        let elapsed = CareRecencyTimeFormatter.liveCompactText(
            since: lastDate,
            relativeTo: reference,
            emptyText: "暂无"
        )
        return AppLocalization.format("距上次 %@", elapsed)
    }

    private func pendingStepAnchor(_ step: EasyCycleStep, cycle: EasyCycle, reference: Date) -> Date? {
        let cycleSessions = cycleFeedingSessions(for: cycle)
        let cycleCare = cycleCareRecords(for: cycle)
        switch step {
        case .eat:
            return feedingStore.allSessions
                .map(\.eventDate)
                .filter { $0 < reference }
                .max()
        case .activity:
            return cycleSessions.map { $0.endAt ?? $0.startAt ?? $0.createdAt }.max() ?? cycle.startedAt
        case .sleep:
            let latestActivity = cycleCare.filter { $0.kind != .sleep }.map(\.recordedAt).max()
            let latestFeeding = cycleSessions.map { $0.endAt ?? $0.startAt ?? $0.createdAt }.max()
            return [latestActivity, latestFeeding, cycle.startedAt].compactMap { $0 }.max()
        case .yearning:
            return nil
        }
    }

    private func easyCycleCompactDurationText(_ minutes: Int) -> String {
        AppQuantityFormat.compactDuration(minutes)
    }

    private var emptyTimeline: some View {
        return HStack(alignment: .center, spacing: 10) {
            easyLetterTile(letter: "E", color: DesignToken.easyEat, size: timelineIconSize)

            VStack(alignment: .leading, spacing: 6) {
                Text(Calendar.current.isDateInToday(selectedDate) ? "今天".localized : dayTitle)
                    .font(BBBFont.font(size: 13, weight: .heavy))
                    .foregroundStyle(DesignToken.primary)
                Text("还没有记录，点右侧添加一条。")
                    .font(BBBFont.font(size: 11.5, weight: .semibold))
                    .foregroundStyle(homeBodyText)
            }
            Spacer()
            Button {
                requestRecordCreation(.feed)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(DesignToken.primary)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(DesignToken.primary.opacity(0.10))
                    )
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.vertical, 10)
    }

    private func easyLetterTile(letter: String, color: Color, size: CGFloat) -> some View {
        easySemanticMarker(letter: letter, color: color, size: size, letterSize: size * 0.42)
            .shadow(color: color.opacity(0.10), radius: 5, y: 2)
    }

    private func timelineRow(_ item: RecordHomeTimelineItem, nextItem: RecordHomeTimelineItem?) -> some View {
        let isLast = nextItem == nil
        let step = item.easyCycleStep

        return HStack(alignment: .center, spacing: 8) {
            ZStack {
                if !isLast {
                    Capsule()
                        .fill(homeMetaText.opacity(0.22))
                        .frame(width: 1, height: 18)
                        .offset(y: 22)
                }

                timelineEasyStepNode(step)
            }
            .frame(width: 24, height: compactTimelineRowHeight)

            HStack(alignment: .center, spacing: 7) {
                compactTimelineTimestamp(timeText(for: item))

                compactTimelineRecordText(item)
                    .font(BBBFont.font(size: 11.8, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .allowsTightening(true)
                .frame(maxWidth: .infinity, alignment: .leading)

                timelineSubjectiveStateSummary(for: item)

                easyCycleTimelineDetailMenu(for: item)
            }
            .padding(.vertical, 4)
            .padding(.leading, 0)
            .padding(.trailing, 2)
            .frame(height: 38)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(DesignToken.onPrimary.opacity(0.15))
            )
        }
        .frame(minHeight: compactTimelineRowHeight)
        .padding(.bottom, isLast ? 8 : 5)
        .recordTimelineActions(
            edit: {
                if case .subjective(let checkIn) = item {
                    onSubjectiveStatePrompt(.editing(checkIn))
                } else {
                    presentQuickRecordEdit(item)
                }
            },
            delete: { pendingDeleteItem = item }
        )
    }

    @ViewBuilder
    private func timelineSubjectiveStateSummary(for item: RecordHomeTimelineItem) -> some View {
        if let checkIn = subjectiveCheckIn(for: item) {
            HStack(spacing: 4) {
                if let babyState = checkIn.babyState {
                    subjectiveTimelineChip(icon: .baby(babyState), title: babyState.title)
                }
                if let parentState = checkIn.parentState {
                    subjectiveTimelineChip(icon: .parent(parentState), title: parentState.title)
                }
            }
            .fixedSize(horizontal: true, vertical: false)
        }
    }

    private func subjectiveTimelineChip(icon: SubjectiveStateIcon.Kind, title: String) -> some View {
        HStack(spacing: 2) {
            SubjectiveStateIcon(kind: icon, size: 16)
            Text(title.localized)
                .font(BBBFont.font(size: 8.5, weight: .semibold))
                .foregroundStyle(homeMetaText)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }

    private func subjectiveCheckIn(for item: RecordHomeTimelineItem) -> SubjectiveStateCheckIn? {
        switch item {
        case .feeding(let session):
            return subjectiveStateStore.linkedCheckIn(sourceType: .feeding, sourceRecordID: session.id)
        case .care(let record):
            return subjectiveStateStore.linkedCheckIn(sourceType: .care, sourceRecordID: record.id)
        case .subjective(let checkIn):
            return checkIn
        case .growth:
            return nil
        }
    }

    private func timelineEasyStepNode(_ step: EasyCycleStep) -> some View {
        easySemanticMarker(
            letter: step.letter,
            color: step.color,
            size: compactTimelineNodeSize,
            letterSize: 9.5
        )
        .shadow(color: step.color.opacity(0.10), radius: 4, y: 2)
        .accessibilityHidden(true)
    }

    private func compactTimelineRecordText(_ item: RecordHomeTimelineItem) -> Text {
        let detail = timelineDetailText(for: item)
        var value = AttributedString(item.titleText)
        value.foregroundColor = DesignToken.textPrimary

        if !detail.isEmpty {
            var detailValue = AttributedString(" \(detail)")
            detailValue.foregroundColor = homeMetaText
            value.append(detailValue)
        }

        return Text(value)
    }

    @ViewBuilder
    private func timelineListIcon(
        assetName: String? = nil,
        systemName: String,
        color: Color,
        size: CGFloat = 30,
        cornerRadius: CGFloat = 10,
        iconSize: CGFloat = 15,
        assetSize: CGFloat = 22
    ) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(color.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(DesignToken.glassFill.opacity(0.34))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(color.opacity(0.24), lineWidth: 1)
                )

            if let assetName {
                Image(assetName)
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFill()
                    .frame(width: assetSize, height: assetSize)
                    .clipShape(Circle())
            } else {
                Image(systemName: systemName)
                    .font(.system(size: iconSize, weight: .heavy))
                    .foregroundStyle(color.opacity(0.90))
            }
        }
        .frame(width: size, height: size)
        .shadow(color: color.opacity(0.10), radius: 7, y: 3)
    }

    private func dayPill(_ date: Date, progress: CGFloat) -> some View {
        let isToday = Calendar.current.isDateInToday(date)
        let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
        let isCollapsed = progress > 0.58
        let pillWidth = lerp(36, 32, progress)
        let pillHeight = lerp(44, 34, progress)

        return dayPillLabel(
            date,
            isToday: isToday,
            isSelected: isSelected,
            isCollapsed: isCollapsed,
            width: pillWidth,
            height: pillHeight
        )
        .frame(width: pillWidth)
        .frame(height: pillHeight)
        .background(
            dayPillBackground(
                isToday: isToday,
                isSelected: isSelected,
                isCollapsed: isCollapsed,
                progress: progress
            )
        )
        .overlay(alignment: .topTrailing) {
            if isCollapsed && isToday {
                Circle()
                    .fill(isSelected ? DesignToken.onPrimary : DesignToken.primary)
                    .frame(width: 5, height: 5)
                    .padding(3)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(weekdaySymbol(for: date)) \(AppDateTimeFormat.date(date))")
        .accessibilityValue(
            isSelected
                ? (isToday ? "已选择，今天".localized : "已选择".localized)
                : (isToday ? "今天".localized : "")
        )
        .animation(
            reduceMotion ? nil : .snappy(duration: 0.20, extraBounce: 0),
            value: isSelected
        )
    }

    @ViewBuilder
    private func dayPillLabel(
        _ date: Date,
        isToday: Bool,
        isSelected: Bool,
        isCollapsed: Bool,
        width: CGFloat,
        height: CGFloat
    ) -> some View {
        let dayText = String(Calendar.current.component(.day, from: date))
        let textColor = dayPillTextColor(isToday: isToday, isSelected: isSelected)

        if isCollapsed {
            Text(dayText)
                .font(BBBFont.font(size: 13, weight: .heavy))
                .foregroundStyle(textColor)
                .frame(width: width, height: height)
        } else {
            VStack(spacing: isToday ? 2 : 3) {
                Text(weekdaySymbol(for: date))
                    .font(BBBFont.font(size: 8, weight: .regular))
                    .foregroundStyle(dayPillSecondaryTextColor(isToday: isToday, isSelected: isSelected))
                Text(dayText)
                    .font(BBBFont.font(size: 12, weight: .heavy))
                    .foregroundStyle(textColor)
                if isToday {
                    Circle()
                        .fill(isSelected ? DesignToken.onPrimary : DesignToken.primary)
                        .frame(width: 3, height: 3)
                }
            }
            .frame(width: width, height: height)
        }
    }

    private func dayPillBackground(
        isToday: Bool,
        isSelected: Bool,
        isCollapsed: Bool,
        progress: CGFloat
    ) -> some View {
        let cornerRadius = lerp(
            DesignToken.controlRadius + 2,
            DesignToken.controlRadius,
            progress
        )
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let unselectedFillOpacity = lerp(0.40, 0.62, progress)
        let unselectedStrokeOpacity = lerp(0.58, 0.76, progress)
        let fillStyle: AnyShapeStyle
        let primaryStroke: Color
        let primaryLineWidth: CGFloat

        if isSelected {
            fillStyle = AnyShapeStyle(
                LinearGradient(
                    colors: [DesignToken.primary, DesignToken.feedingBreast],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            primaryStroke = DesignToken.onPrimary.opacity(0.42)
            primaryLineWidth = 1
        } else {
            fillStyle = AnyShapeStyle(
                LinearGradient(
                    colors: [
                        DesignToken.glassFill.opacity(isCollapsed ? 0.84 : unselectedFillOpacity),
                        DesignToken.surfaceSoft.opacity(isCollapsed ? 0.68 : max(unselectedFillOpacity - 0.06, 0.24))
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            primaryStroke = isToday
                ? DesignToken.primary.opacity(0.72)
                : DesignToken.onPrimary.opacity(isCollapsed ? 0.94 : unselectedStrokeOpacity)
            primaryLineWidth = isToday ? 1.6 : 1
        }

        return shape
            .fill(fillStyle)
            .overlay(shape.fill(isSelected ? Color.clear : DesignToken.glassFill.opacity(isCollapsed ? 0.22 : 0.12)))
            .overlay(shape.stroke(primaryStroke, lineWidth: primaryLineWidth))
            .overlay(
                shape.stroke(
                    isSelected
                        ? DesignToken.primary.opacity(0.16)
                        : DesignToken.textFaint.opacity(isCollapsed ? 0.20 : 0.10),
                    lineWidth: 0.8
                )
            )
            .shadow(
                color: DesignToken.shadowColor.opacity(isSelected ? 0.18 : 0.08),
                radius: isSelected ? 8 : 6,
                y: isSelected ? 3 : 2
            )
    }

    private func dayPillTextColor(isToday: Bool, isSelected: Bool) -> Color {
        if isSelected { return DesignToken.onPrimary }
        return isToday ? DesignToken.primary : homeBodyText
    }

    private func dayPillSecondaryTextColor(isToday: Bool, isSelected: Bool) -> Color {
        if isSelected { return DesignToken.onPrimary.opacity(0.86) }
        return isToday ? DesignToken.primary.opacity(0.82) : homeMetaText
    }

    private var timelineEnd: some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(DesignToken.line.opacity(0.38))
                .frame(height: 1)
            Text(
                Calendar.current.isDateInToday(selectedDate)
                    ? "今天开始".localized
                    : AppLocalization.format("%@开始", dayTitle)
            )
                .font(BBBFont.font(size: 10, weight: .regular))
                .foregroundStyle(homeFaintText)
                .lineLimit(1)
            Rectangle()
                .fill(DesignToken.line.opacity(0.38))
                .frame(height: 1)
        }
        .padding(.top, 2)
    }

    private var recordBackground: some View {
        DesignToken.canvas
    }

    private func glassSurface(cornerRadius: CGFloat, whiteOpacity: Double, shadowOpacity: Double) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(DesignToken.glassFill.opacity(whiteOpacity))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(DesignToken.glassStroke.opacity(0.78), lineWidth: 1.1)
            )
            .shadow(color: DesignToken.shadowColor.opacity(shadowOpacity + 0.04), radius: 18, y: 8)
    }

    private var dayTitle: String {
        AppDateTimeFormat.date(selectedDate)
    }

    private func selectRecordDate(_ date: Date) {
        let calendar = Calendar.current
        let currentDate = normalizedSelectableDate(selectedDate)
        let targetDate = normalizedSelectableDate(date)
        guard !calendar.isDate(currentDate, inSameDayAs: targetDate) else { return }

        persistCurrentEasyFeedAnchor()
        dateTransitionDirection = targetDate > currentDate ? 1 : -1
        selectedDate = targetDate
    }

    private func handleRecordScrollPhaseChange(_ phase: ScrollPhase) {
        let isActive = phase.isScrolling
        guard isRecordScrollActive != isActive else { return }
        isRecordScrollActive = isActive

        guard !isActive else { return }
        persistCurrentEasyFeedAnchor()

        if let pendingMinuteRefresh {
            self.pendingMinuteRefresh = nil
            now = pendingMinuteRefresh
            refreshEasyCycleCardOverview()
            easyFeedRevision &+= 1
            requestEasyFeedSnapshots()
        } else if easyFeedVisibilityRuntime.needsSnapshotRefresh {
            easyFeedVisibilityRuntime.needsSnapshotRefresh = false
            easyFeedRevision &+= 1
            requestEasyFeedSnapshots()
        }
    }

    private func handleMinuteRefresh(_ date: Date) {
        guard !isRecordScrollActive else {
            pendingMinuteRefresh = date
            easyFeedVisibilityRuntime.needsSnapshotRefresh = true
            return
        }
        now = date
        refreshEasyCycleCardOverview()
        easyFeedRevision &+= 1
        requestEasyFeedSnapshots()
    }

    private func handleVisibleEasyCycleIDs(_ identifiers: [UUID]) {
        guard let snapshot = currentEasyFeedSnapshot else {
            easyFeedVisibilityRuntime.visibleCycleIDs = []
            return
        }
        let allIDs = snapshot.cards.map(\.id)
        let validIDs = Set(allIDs)
        let visibleIDs = identifiers.filter(validIDs.contains)
        easyFeedVisibilityRuntime.visibleCycleIDs = visibleIDs

        let loadedCount = easyFeedState.visibleCount(
            for: selectedDayKey,
            totalCount: snapshot.cards.count
        )
        guard loadedCount < snapshot.cards.count else { return }
        let triggerStart = max(loadedCount - 2, 0)
        let triggerIDs = Set(snapshot.cards[triggerStart..<loadedCount].map(\.id))
        guard !triggerIDs.isDisjoint(with: visibleIDs) else { return }

        loadNextEasyCyclePage()
    }

    private func loadNextEasyCyclePage() {
        guard let snapshot = currentEasyFeedSnapshot else { return }

        var updatedState = easyFeedState
        guard updatedState.loadNextPage(
            for: selectedDayKey,
            totalCount: snapshot.cards.count
        ) else {
            return
        }
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            easyFeedState = updatedState
        }
    }

    private func persistCurrentEasyFeedAnchor() {
        guard let snapshot = currentEasyFeedSnapshot else { return }
        let validIDs = Set(snapshot.cards.map(\.id))
        let topID = easyFeedVisibilityRuntime.visibleCycleIDs.first(where: validIDs.contains)
        var updatedState = easyFeedState
        updatedState.rememberTopVisibleCycle(topID, for: selectedDayKey)
        easyFeedState = updatedState
    }

    private func restoreEasyFeedPosition(
        for date: Date,
        with proxy: ScrollViewProxy
    ) {
        let dayKey = RecordHomeDayKey(date)
        let target = easyFeedState.anchor(for: dayKey)
        DispatchQueue.main.async {
            if let target {
                proxy.scrollTo(target, anchor: .top)
            } else {
                proxy.scrollTo(RecordHomeScrollTarget.rhythm, anchor: .top)
            }
        }
    }

    private func markEasyFeedDataChanged(
        subjectiveCheckIns: [SubjectiveStateCheckIn]? = nil,
        immediate: Bool = false
    ) {
        guard !isRecordScrollActive || immediate else {
            easyFeedVisibilityRuntime.needsSnapshotRefresh = true
            return
        }
        easyFeedRevision &+= 1
        requestEasyFeedSnapshots(immediate: immediate, subjectiveCheckIns: subjectiveCheckIns)
    }

    private func requestEasyFeedSnapshots(
        immediate: Bool = false,
        subjectiveCheckIns: [SubjectiveStateCheckIn]? = nil
    ) {
        guard !isRecordScrollActive || immediate else {
            easyFeedVisibilityRuntime.needsSnapshotRefresh = true
            return
        }

        let dates = [selectedDate] + weekDates
        let revision = easyFeedRevision
        easyFeedSnapshotGeneration &+= 1
        let generation = easyFeedSnapshotGeneration
        let input = RecordHomeEasyFeedInput(
            dates: dates,
            cycles: easyCycleStore.cycles,
            feedingSessions: feedingStore.allSessions,
            careRecords: activityStore.exportCareRecords(),
            subjectiveCheckIns: subjectiveCheckIns ?? subjectiveStateStore.exportCheckIns(),
            referenceDate: now,
            revision: revision
        )

        easyFeedSnapshotTask?.cancel()
        easyFeedSnapshotTask = Task { @MainActor in
            if !immediate {
                try? await Task.sleep(for: .milliseconds(40))
            }
            guard !Task.isCancelled else { return }
            let snapshots = await Task.detached(priority: .utility) {
                RecordHomeEasyFeedSnapshotBuilder.build(input)
            }.value
            guard !Task.isCancelled,
                  generation == easyFeedSnapshotGeneration,
                  revision == easyFeedRevision else {
                return
            }

            var mergedSnapshots = easyFeedSnapshots
            for (key, snapshot) in snapshots {
                mergedSnapshots[key] = snapshot
            }
            let keepKeys = Set(dates.map { RecordHomeDayKey($0) })
            if mergedSnapshots.count > 21 {
                let removableKeys = mergedSnapshots.keys.filter { !keepKeys.contains($0) }
                for key in removableKeys.prefix(mergedSnapshots.count - 21) {
                    mergedSnapshots.removeValue(forKey: key)
                }
            }
            easyFeedSnapshots = mergedSnapshots

            var updatedState = easyFeedState
            updatedState.ensureDay(selectedDayKey)
            updatedState.trim(keeping: keepKeys)
            easyFeedState = updatedState
        }
    }

    private func scrollToRhythm(with proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            withAnimation(.smooth(duration: 0.24)) {
                proxy.scrollTo(RecordHomeScrollTarget.rhythm, anchor: .top)
            }
        }
    }

    private func stickyHeaderBackground(progress: CGFloat) -> some View {
        let collapseProgress = min(max((progress - 0.35) / 0.65, 0), 1)

        return ZStack {
            DesignToken.canvas
                .opacity(0.98 * collapseProgress)

            LinearGradient(
                colors: [
                    DesignToken.primary.opacity(0.04 * collapseProgress),
                    DesignToken.canvas.opacity(0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea(edges: .top)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(DesignToken.primary.opacity(0.10 * collapseProgress))
                .frame(height: 0.6)
        }
    }

    private func lightHaptic() {
        AppHapticFeedback.impact(.light)
    }

    private var babyAgeText: String {
        BabyAgeFormatter.displayText(
            birthDate: profileStore.currentProfile.birthDate,
            on: selectedDate
        )
    }

    private var babyAgeDays: Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: profileStore.currentProfile.birthDate)
        let end = calendar.startOfDay(for: selectedDate)
        return max(calendar.dateComponents([.day], from: start, to: end).day ?? 0, 0)
    }

    private var selectedAgeMonths: Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: profileStore.currentProfile.birthDate)
        let end = calendar.startOfDay(for: selectedDate)
        return max(calendar.dateComponents([.month], from: start, to: end).month ?? 0, 0)
    }

    private var feedingGuidanceText: String {
        ageRhythmGuidance.cardText
    }

    private var ageRhythmGuidance: AgeRhythmGuidance {
        AgeRhythmGuidance.guidance(for: selectedAgeMonths)
    }

    private var babyTrendOverview: BabyTrendOverview {
        let calendar = Calendar.current
        let end = calendar.startOfDay(for: selectedDate)
        let start = calendar.date(byAdding: .day, value: -6, to: end) ?? end
        let dayCount = 7

        let recentSessions = feedingStore.allSessions.filter { session in
            let day = calendar.startOfDay(for: session.eventDate)
            return day >= start && day <= end
        }
        let bottleTotal = recentSessions.reduce(0) { $0 + $1.totalBottleAmount }
        let breastTotal = recentSessions.reduce(0) { $0 + $1.totalBreastDuration }
        let solidTotal = recentSessions.reduce(0.0) { $0 + $1.totalSolidAmount }
        let bottleAverage = roundedAverage(bottleTotal, days: dayCount, step: 10)
        let breastAverage = roundedAverage(breastTotal, days: dayCount, step: 5)
        let solidAverage = roundedAverage(solidTotal, days: dayCount, step: 1)
        let feedingDurationAverage = roundedAverage(recentSessions.reduce(0) { $0 + $1.totalBottleDuration + $1.totalBreastDuration }, days: dayCount, step: 5)

        let allCareRecords = activityStore.careRecords
        let recentCareRecords = allCareRecords.filter { record in
            let day = calendar.startOfDay(for: record.recordedAt)
            return day >= start && day <= end
        }
        let diaperRecords = recentCareRecords.filter { $0.kind == .diaper }
        let poopAverage = roundedAverage(diaperRecords.filter { DiaperRecordType.normalizedTitle($0.title).contains("拉") }.count, days: dayCount, step: 1)
        let peeAverage = roundedAverage(diaperRecords.filter { DiaperRecordType.normalizedTitle($0.title).contains("尿") }.count, days: dayCount, step: 1)
        let diaperAverage = roundedAverage(diaperRecords.count, days: dayCount, step: 1)
        let recentSleepTotalMinutes = (0..<dayCount).reduce(0) { total, offset in
            let day = calendar.date(byAdding: .day, value: offset, to: start) ?? start
            return total + calendarDaySleepMinutes(on: day, records: allCareRecords)
        }
        let sleepAverageMinutes = roundedAverage(recentSleepTotalMinutes, days: dayCount, step: 15)
        let activitySegmentAverage = roundedAverage(recentActivityCount(careRecords: recentCareRecords), days: dayCount, step: 1)
        let breastEquivalentML = Int(round(Double(breastAverage) * breastEquivalentRate))
        let equivalentMilk = bottleAverage + breastEquivalentML

        return BabyTrendOverview(
            bottleML: bottleAverage,
            breastMinutes: breastAverage,
            breastEquivalentML: breastEquivalentML,
            solidGrams: solidAverage,
            equivalentMilkML: equivalentMilk,
            feedingMinutes: feedingDurationAverage,
            diaperCount: diaperAverage,
            poopCount: poopAverage,
            peeCount: peeAverage,
            activitySegments: activitySegmentAverage,
            urineEstimateText: "--g",
            sleepText: sleepAverageMinutes > 0 ? averageSleepText(minutes: sleepAverageMinutes) : "--"
        )
    }

    private var weeklyCareSummary: BabyWeeklyCareSummary {
        let calendar = Calendar.current
        let selectedDay = calendar.startOfDay(for: selectedDate)
        let currentStart = calendar.date(byAdding: .day, value: -6, to: selectedDay) ?? selectedDay
        let currentEnd = calendar.date(byAdding: .day, value: 1, to: selectedDay) ?? selectedDay
        let previousStart = calendar.date(byAdding: .day, value: -13, to: selectedDay) ?? currentStart

        let currentSessions = feedingStore.allSessions.filter {
            $0.eventDate >= currentStart && $0.eventDate < currentEnd
        }
        let currentMaximumBottleML = currentSessions
            .flatMap(\.entries)
            .compactMap(\.bottleAmount)
            .filter { $0 > 0 }
            .max() ?? 0
        let currentBreastMinutes = currentSessions.reduce(0) { $0 + $1.totalBreastDuration }
        let currentSolidGrams = Int(currentSessions.reduce(0) { $0 + $1.totalSolidAmount }.rounded())

        let feedingFact: String
        if currentMaximumBottleML > 0 {
            feedingFact = AppLocalization.format(
                "baby.summary.feeding.highest",
                AppMeasurementFormat.volume(Double(currentMaximumBottleML))
            )
        } else if currentBreastMinutes > 0 {
            feedingFact = AppLocalization.format(
                "baby.summary.feeding.breast",
                AppQuantityFormat.compactDuration(currentBreastMinutes)
            )
        } else if currentSolidGrams > 0 {
            feedingFact = AppLocalization.format(
                "baby.summary.feeding.solid",
                AppMeasurementFormat.mass(Double(currentSolidGrams))
            )
        } else {
            feedingFact = "baby.summary.feeding.empty".localized
        }

        let allPoopRecords = activityStore.careRecords
            .filter {
                $0.kind == .diaper
                    && DiaperRecordType.normalizedTitle($0.title).contains("拉")
                    && $0.recordedAt >= previousStart
                    && $0.recordedAt < currentEnd
            }
            .sorted { $0.recordedAt < $1.recordedAt }
        let currentPoopCount = allPoopRecords.filter { $0.recordedAt >= currentStart }.count
        let currentPoopIntervals = zip(allPoopRecords, allPoopRecords.dropFirst()).compactMap { previous, current -> Int? in
            guard current.recordedAt >= currentStart else { return nil }
            let interval = current.recordedAt.timeIntervalSince(previous.recordedAt)
            return interval > 0 ? Int(interval.rounded()) : nil
        }
        let poopFact: String
        if let typicalInterval = NightSleepAnalyzer.median(currentPoopIntervals),
           let lastPoopAt = allPoopRecords.last?.recordedAt {
            let prediction = lastPoopAt.addingTimeInterval(TimeInterval(typicalInterval))
            poopFact = AppLocalization.format(
                "baby.summary.poop.prediction",
                stoolIntervalText(seconds: TimeInterval(typicalInterval)),
                AppDateTimeFormat.date(prediction)
            )
        } else if currentPoopCount > 0 {
            poopFact = AppLocalization.format("baby.summary.poop.count", currentPoopCount)
        } else {
            poopFact = "baby.summary.poop.empty".localized
        }

        let sleepRecords = activityStore.careRecords.filter { record in
            guard record.kind == .sleep,
                  let minutes = SleepRecordFormatter.durationMinutes(from: record.detail) else {
                return false
            }
            let endAt = SleepRecordFormatter.endTime(start: record.recordedAt, durationMinutes: minutes)
            return endAt > previousStart && record.recordedAt < currentEnd
        }
        let currentNightEpisodes = NightSleepAnalyzer.episodes(
            records: sleepRecords,
            from: currentStart,
            to: currentEnd,
            calendar: calendar
        )
        .filter { $0.anchor >= currentStart && $0.anchor < currentEnd }

        let sleepFact: String
        if currentNightEpisodes.count >= 3,
           let bedtimeMinute = NightSleepAnalyzer.median(
               currentNightEpisodes.map { NightSleepAnalyzer.bedtimeMinute(for: $0, calendar: calendar) }
           ),
           let wakeMinute = NightSleepAnalyzer.median(
               currentNightEpisodes.map { NightSleepAnalyzer.wakeMinute(for: $0, calendar: calendar) }
           ),
           let nightMinutes = NightSleepAnalyzer.median(currentNightEpisodes.map(\.sleepMinutes)) {
            sleepFact = AppLocalization.format(
                "baby.summary.sleep.usual",
                clockText(minutes: bedtimeMinute),
                clockText(minutes: wakeMinute),
                AppQuantityFormat.compactDuration(nightMinutes)
            )
        } else {
            sleepFact = "baby.summary.sleep.insufficient".localized
        }

        let nightRecordIDs = Set(currentNightEpisodes.flatMap { $0.segments.map(\.recordID) })
        let daytimeNaps = sleepRecords.compactMap { record -> Int? in
            guard record.recordedAt >= currentStart,
                  record.recordedAt < currentEnd,
                  !nightRecordIDs.contains(record.id) else {
                return nil
            }
            let hour = calendar.component(.hour, from: record.recordedAt)
            guard hour >= 8, hour < 20 else { return nil }
            return SleepRecordFormatter.durationMinutes(from: record.detail)
        }
        let napFact: String
        if let shortestNap = daytimeNaps.min(), let longestNap = daytimeNaps.max() {
            let dailyCount = max(Int((Double(daytimeNaps.count) / 7).rounded()), 1)
            if shortestNap == longestNap {
                napFact = AppLocalization.format(
                    "baby.summary.nap.same",
                    dailyCount,
                    AppQuantityFormat.compactDuration(shortestNap)
                )
            } else {
                napFact = AppLocalization.format(
                    "baby.summary.nap.range",
                    dailyCount,
                    AppQuantityFormat.compactDuration(shortestNap),
                    AppQuantityFormat.compactDuration(longestNap)
                )
            }
        } else {
            napFact = "baby.summary.nap.insufficient".localized
        }

        return BabyWeeklyCareSummary(lines: [feedingFact, poopFact, sleepFact, napFact])
    }

    private func stoolIntervalText(seconds: TimeInterval) -> String {
        let hours = max(Int((seconds / 3_600).rounded()), 1)
        if hours < 24 {
            return AppQuantityFormat.hours(hours)
        }
        let days = Double(hours) / 24
        let rounded = (days * 10).rounded() / 10
        if rounded.rounded() == rounded {
            return AppQuantityFormat.days(Int(rounded))
        }
        return AppLocalization.format("baby.summary.duration.days.decimal", rounded)
    }

    private func clockText(minutes: Int) -> String {
        let normalized = ((minutes % (24 * 60)) + (24 * 60)) % (24 * 60)
        return String(format: "%02d:%02d", normalized / 60, normalized % 60)
    }

    private var babyTrendDetailRows: [BabyTrendDetailRow] {
        let overview = babyTrendOverview
        return [
            BabyTrendDetailRow(
                title: "E",
                summary: overview.feedingText,
                detail: overview.feedingDetailText,
                color: DesignToken.easyEat
            ),
            BabyTrendDetailRow(
                title: "A",
                summary: overview.activityText,
                detail: overview.activityDetailText,
                color: DesignToken.easyActivity
            ),
            BabyTrendDetailRow(
                title: "S",
                summary: overview.sleepText,
                detail: overview.sleepDetailText,
                color: DesignToken.easySleep
            )
        ]
    }

    private func roundedAverage(_ total: Int, days: Int, step: Int) -> Int {
        guard total > 0, days > 0 else { return 0 }
        let raw = Double(total) / Double(days)
        return Int((raw / Double(step)).rounded()) * step
    }

    private func roundedAverage(_ total: Double, days: Int, step: Int) -> Int {
        guard total > 0, days > 0 else { return 0 }
        let raw = total / Double(days)
        return Int((raw / Double(step)).rounded()) * step
    }

    private var breastEquivalentRate: Double {
        let months = selectedAgeMonths
        switch months {
        case 1...4:
            return 5.2
        case 5...12:
            return 5.8
        default:
            return 5.5
        }
    }

    private func averageSleepText(minutes: Int) -> String {
        AppQuantityFormat.compactDuration(minutes)
    }

    private func feedingAmountText(equivalentMilkML: Int, solidGrams: Int, approximate: Bool) -> String {
        guard equivalentMilkML > 0 || solidGrams > 0 else { return "--" }
        var text = ""
        if equivalentMilkML > 0 {
            text = AppMeasurementFormat.volume(Double(equivalentMilkML))
        }
        if solidGrams > 0 {
            let solidText = AppMeasurementFormat.mass(Double(solidGrams))
            text += text.isEmpty ? solidText : " \(solidText)"
        }
        return text
    }

    private func feedingTileText(bottleML: Int, breastMinutes: Int, solidGrams: Int, approximate: Bool = false) -> String {
        var parts: [String] = []
        if bottleML > 0 {
            parts.append(AppMeasurementFormat.volume(Double(bottleML)))
        }
        if breastMinutes > 0 {
            parts.append(AppQuantityFormat.compactDuration(breastMinutes))
        }
        if solidGrams > 0 {
            parts.append(AppMeasurementFormat.mass(Double(solidGrams)))
        }
        return parts.isEmpty ? "--" : parts.joined(separator: "+")
    }

    private func recentActivityCount(careRecords: [CareRecord]) -> Int {
        careRecords.filter { $0.kind == .activity }.count
    }

    private var weightChangeText: String? {
        let calendar = Calendar.current
        let selectedEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: selectedDate)) ?? selectedDate
        let cutoff = calendar.date(byAdding: .day, value: -30, to: selectedEnd) ?? selectedEnd
        let records = growthMetricStore.records(kind: .weight)
            .filter { $0.recordedAt <= selectedEnd }
            .sorted { $0.recordedAt > $1.recordedAt }
        guard let latest = records.first else { return nil }
        let baseline = records.first(where: { $0.recordedAt <= cutoff }) ?? records.last
        guard let baseline, latest.id != baseline.id else { return nil }
        let change = latest.value - baseline.value
        guard abs(change) >= 0.05 else { return nil }
        return "\(change >= 0 ? "+" : "-")\(AppMeasurementFormat.weight(abs(change)))"
    }

    private var rhythmSummaryItems: [RhythmSummaryItem] {
        var items: [RhythmSummaryItem] = []

        let bottleAmount = selectedSessions.reduce(0) { $0 + $1.totalBottleAmount }
        if bottleAmount > 0 {
            items.append(RhythmSummaryItem(
                text: AppLocalization.format("瓶喂 %@", AppMeasurementFormat.volume(Double(bottleAmount))),
                color: recordBottleColor
            ))
        }

        let breastMinutes = selectedSessions.reduce(0) { $0 + $1.totalBreastDuration }
        if breastMinutes > 0 {
            items.append(RhythmSummaryItem(
                text: AppLocalization.format("亲喂 %@", AppQuantityFormat.compactDuration(breastMinutes)),
                color: recordBreastColor
            ))
        }

        let solidAmount = selectedSessions.reduce(0) { $0 + $1.totalSolidAmount }
        if solidAmount > 0 {
            items.append(RhythmSummaryItem(
                text: AppLocalization.format("辅食 %@", AppMeasurementFormat.mass(solidAmount)),
                color: recordSolidColor
            ))
        }

        if bottleAmount == 0 && breastMinutes == 0 && solidAmount == 0 {
            items.append(RhythmSummaryItem(text: "今天还没有瓶喂记录".localized, color: recordBottleColor))
        }

        let recordedSleepMinutes = selectedSleepSummary.recordedSleepMinutes
        if recordedSleepMinutes > 0 {
            items.append(RhythmSummaryItem(
                text: AppLocalization.format("睡眠 %@", averageSleepText(minutes: recordedSleepMinutes)),
                color: recordSleepColor
            ))
        }

        let diaperCount = selectedCareRecords.filter { $0.kind == .diaper }.count
        if diaperCount > 0 {
            items.append(RhythmSummaryItem(
                text: AppLocalization.format("尿布 %d 次", diaperCount),
                color: recordDiaperColor
            ))
        } else {
            items.append(RhythmSummaryItem(text: "今天还没有尿布记录".localized, color: recordDiaperColor))
        }

        return items
    }

    private var todayRhythmOverview: TodayRhythmOverview {
        let bottleAmount = selectedSessions.reduce(0) { $0 + $1.totalBottleAmount }
        let breastMinutes = selectedSessions.reduce(0) { $0 + $1.totalBreastDuration }
        let solidAmount = Int(selectedSessions.reduce(0) { $0 + $1.totalSolidAmount }.rounded())
        let feedingText = feedingTileText(bottleML: bottleAmount, breastMinutes: breastMinutes, solidGrams: solidAmount)

        let sleepMinutes = selectedSleepSummary.recordedSleepMinutes
        return TodayRhythmOverview(
            feedingText: feedingText,
            activityText: todayActivityText,
            sleepText: sleepMinutes > 0 ? averageSleepText(minutes: sleepMinutes) : "--"
        )
    }

    private var todayActivityText: String {
        let diaperRecords = selectedCareRecords.filter { $0.kind == .diaper }
        let poopCount = diaperRecords.filter {
            DiaperRecordType.type(for: $0.title) == .poop
        }.count
        let peeCount = diaperRecords.filter {
            DiaperRecordType.type(for: $0.title) == .pee
        }.count
        let activityCount = selectedCareRecords.filter { $0.kind == .activity }.count

        var parts: [String] = []
        if poopCount > 0 { parts.append(AppLocalization.format("%d拉", poopCount)) }
        if peeCount > 0 { parts.append(AppLocalization.format("%d尿", peeCount)) }
        if activityCount > 0 { parts.append(AppLocalization.format("%d玩", activityCount)) }
        return parts.isEmpty ? "--" : parts.joined(separator: " · ")
    }

    private var currentEasyCycleOverview: EasyCycleOverview {
        if let cycle = easyCycleStore.currentCycle(on: selectedDate) {
            return easyCycleOverview(for: cycle)
        }

        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: selectedDate)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(24 * 60 * 60)
        let effectiveNow: Date
        if calendar.isDateInToday(selectedDate) {
            effectiveNow = max(now, Date())
        } else {
            effectiveNow = dayEnd.addingTimeInterval(-1)
        }

        let sessions = selectedSessions
            .filter { $0.eventDate <= effectiveNow }
            .sorted { $0.eventDate < $1.eventDate }
        let latestEat = sessions.last
        let cycleStart = latestEat?.eventDate ?? dayStart
        let cycleSessions = sessions.filter { $0.eventDate >= cycleStart }
        let cycleCareRecords = selectedCareRecordsForSleepSummary.filter { record in
            record.recordedAt >= cycleStart && record.recordedAt <= effectiveNow
        }
        let cycleSleepRecords = cycleCareRecords
            .filter { $0.kind == .sleep }
            .compactMap { record -> (record: CareRecord, endAt: Date, minutes: Int)? in
                guard let minutes = SleepRecordFormatter.durationMinutes(from: record.detail) else { return nil }
                return (record, SleepRecordFormatter.endTime(start: record.recordedAt, durationMinutes: minutes), minutes)
            }
        let activeSleep = cycleSleepRecords.first { sleep in
            sleep.record.recordedAt <= effectiveNow && sleep.endAt > effectiveNow
        }
        let latestCompletedSleep = cycleSleepRecords
            .filter { $0.endAt <= effectiveNow }
            .sorted { $0.endAt > $1.endAt }
            .first

        let currentStep: EasyCycleStep
        if activeSleep != nil {
            currentStep = .sleep
        } else if latestCompletedSleep != nil {
            currentStep = .yearning
        } else if latestEat != nil {
            currentStep = .activity
        } else {
            currentStep = .eat
        }

        let bottleAmount = cycleSessions.reduce(0) { $0 + $1.totalBottleAmount }
        let breastMinutes = cycleSessions.reduce(0) { $0 + $1.totalBreastDuration }
        let solidAmount = Int(cycleSessions.reduce(0) { $0 + $1.totalSolidAmount }.rounded())
        let breastEquivalentML = Int(round(Double(breastMinutes) * breastEquivalentRate))
        let equivalentMilk = bottleAmount + breastEquivalentML
        let eatText = latestEat == nil
            ? "待开始".localized
            : feedingAmountText(equivalentMilkML: equivalentMilk, solidGrams: solidAmount, approximate: false)

        let diaperCount = cycleCareRecords.filter { $0.kind == .diaper }.count
        let activityMinutes = max(Int(effectiveNow.timeIntervalSince(cycleStart) / 60), 0)
        let activityText = diaperCount > 0
            ? AppLocalization.format("便便 %d 次", diaperCount)
            : elapsedShortText(minutes: activityMinutes)
        let sleepMinutes = cycleSleepRecords.reduce(0) { $0 + $1.minutes }
        let sleepText = sleepMinutes > 0 ? averageSleepText(minutes: sleepMinutes) : "--"
        let subjectiveState = subjectiveStateOverview(
            from: cycleStart,
            to: effectiveNow.addingTimeInterval(1)
        )

        return EasyCycleOverview(
            startedAt: cycleStart,
            currentStep: currentStep,
            eatText: eatText,
            activityText: activityText,
            sleepText: sleepText,
            yearningText: subjectiveState.text,
            hasEatData: latestEat != nil,
            hasActivityData: diaperCount > 0,
            hasSleepData: sleepMinutes > 0,
            hasYearningData: subjectiveState.hasData,
            guidance: easyCycleGuidance(
                step: currentStep,
                minutesSinceCycleStart: activityMinutes,
                activeSleepMinutes: activeSleep.map { max(Int(effectiveNow.timeIntervalSince($0.record.recordedAt) / 60), 0) },
                minutesSinceWake: latestCompletedSleep.map { max(Int(effectiveNow.timeIntervalSince($0.endAt) / 60), 0) }
            )
        )
    }

    private func easyCycleOverview(for cycle: EasyCycle) -> EasyCycleOverview {
        let effectiveEnd = cycleEffectiveEnd(cycle)
        let cycleSessions = cycleFeedingSessions(for: cycle)
        let cycleCareRecords = cycleCareRecords(for: cycle)
        let sleepRecords = cycleCareRecords
            .filter { $0.kind == .sleep }
            .compactMap { record -> (record: CareRecord, minutes: Int, endAt: Date)? in
                guard let minutes = SleepRecordFormatter.durationMinutes(from: record.detail) else { return nil }
                return (record, minutes, SleepRecordFormatter.endTime(start: record.recordedAt, durationMinutes: minutes))
            }

        let bottleAmount = cycleSessions.reduce(0) { $0 + $1.totalBottleAmount }
        let breastMinutes = cycleSessions.reduce(0) { $0 + $1.totalBreastDuration }
        let solidAmount = Int(cycleSessions.reduce(0) { $0 + $1.totalSolidAmount }.rounded())
        let breastEquivalentML = Int(round(Double(breastMinutes) * breastEquivalentRate))
        let equivalentMilk = bottleAmount + breastEquivalentML
        let eatText = cycleSessions.isEmpty
            ? "待记录".localized
            : feedingAmountText(equivalentMilkML: equivalentMilk, solidGrams: solidAmount, approximate: false)

        let diaperCount = cycleCareRecords.filter { $0.kind == .diaper }.count
        let activityStart = cycle.activityStartedAt ?? cycle.startedAt
        let activityEnd = cycle.activityEndedAt ?? (cycle.currentPhase == .activity ? effectiveEnd : nil)
        let activityMinutes = activityEnd.map { max(Int($0.timeIntervalSince(activityStart) / 60), 0) } ?? 0
        let activityText: String
        if diaperCount > 0, activityMinutes > 0 {
            activityText = AppLocalization.format(
                "%@ · 尿布 %d 次",
                elapsedShortText(minutes: activityMinutes),
                diaperCount
            )
        } else if diaperCount > 0 {
            activityText = AppLocalization.format("尿布 %d 次", diaperCount)
        } else if activityMinutes > 0 {
            activityText = elapsedShortText(minutes: activityMinutes)
        } else {
            activityText = "待记录".localized
        }

        let sleepMinutes = sleepRecords.reduce(0) { $0 + $1.minutes }
        let activeSleepMinutes: Int? = cycle.currentPhase == .sleep
            ? max(Int(effectiveEnd.timeIntervalSince(cycle.startedAt) / 60), 0)
            : nil
        let sleepText = sleepMinutes > 0 ? averageSleepText(minutes: sleepMinutes) : "待记录".localized
        let subjectiveState = subjectiveStateOverview(
            from: cycle.startedAt,
            to: effectiveEnd.addingTimeInterval(1)
        )

        return EasyCycleOverview(
            startedAt: cycle.startedAt,
            currentStep: EasyCycleStep(cycle.currentPhase),
            eatText: eatText,
            activityText: activityText,
            sleepText: sleepText,
            yearningText: subjectiveState.text,
            hasEatData: !cycleSessions.isEmpty,
            hasActivityData: diaperCount > 0 || activityMinutes > 0,
            hasSleepData: sleepMinutes > 0,
            hasYearningData: subjectiveState.hasData,
            guidance: easyCycleGuidance(
                step: EasyCycleStep(cycle.currentPhase),
                minutesSinceCycleStart: max(Int(effectiveEnd.timeIntervalSince(cycle.startedAt) / 60), 0),
                activeSleepMinutes: activeSleepMinutes,
                minutesSinceWake: cycle.status == .readyToPublish ? 0 : nil
            )
        )
    }

    private func subjectiveStateOverview(from start: Date, to end: Date) -> (text: String, hasData: Bool) {
        let checkIns = subjectiveStateStore.checkIns(from: start, to: end)
        let babyState = checkIns.reversed().compactMap(\.babyState).first
        let parentState = checkIns.reversed().compactMap(\.parentState).first
        let text = [babyState?.title, parentState?.title]
            .compactMap { $0 }
            .joined(separator: " · ")
        return (text.isEmpty ? "--" : text, !text.isEmpty)
    }

    private func handleEasyCyclePrimaryAction() {
        requestRecordCreation(.advanceEasyCycle)
    }

    private func performEasyCyclePrimaryAction(on date: Date) {
        rebuildEasyCycles()
        let anchor = easyCycleStartAnchor(for: date)
        let actionDate = Calendar.current.isDateInToday(date) ? Date() : anchor
        easyCycleStore.performPrimaryAction(now: actionDate, startedAt: anchor)
        awardCompleteEasyCyclesIfNeeded()
        refreshEasyCycleCardOverview()
    }

    private func easyCycleStartAnchor(for date: Date) -> Date {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(24 * 60 * 60)
        let sessionDates = feedingStore.sessions(on: date)
            .map(\.eventDate)
            .filter { $0 >= dayStart && $0 < dayEnd }
        let careDates = activityStore.careRecordsForSleepSummary(on: date)
            .filter { $0.kind != .sleep }
            .map(\.recordedAt)
            .filter { $0 >= dayStart && $0 < dayEnd }
        let candidateDates = sessionDates + careDates
        return candidateDates.min() ?? date
    }

    private func rebuildEasyCycles() {
        easyCycleStore.rebuild(
            from: feedingStore.allSessions,
            careRecords: activityStore.exportCareRecords()
        )
    }

    private func handleEasyCycleRecordMutation() {
        now = Date()
        rebuildEasyCycles()
        refreshEasyCycleCardOverview()
        markEasyFeedDataChanged(immediate: true)
    }

    private func handleSubjectiveStateMutation(_ checkIns: [SubjectiveStateCheckIn]) {
        now = Date()
        refreshEasyCycleCardOverview()
        markEasyFeedDataChanged(subjectiveCheckIns: checkIns, immediate: true)
    }

    private func handleEasyCycleSplitNotice(
        _ notice: EasyCycleSplitNotice,
        surfaceFeedback: Bool = true
    ) {
        guard easyCycleStore.pendingSplitNotice?.id == notice.id else { return }
        if automaticallyKeepEasyCycleSplits {
            easyCycleStore.acknowledgeSplit(notice.id)
            if surfaceFeedback {
                feedbackCenter.presentToast(AppToastMessage(
                    text: "补录已保存，这一轮已整理为两轮".localized,
                    style: .success,
                    deduplicationKey: "easy-split:\(notice.id.uuidString)"
                ))
            }
        } else {
            presentedEasyCycleSplitNotice = notice
        }
    }

    private func refreshEasyCycleCardOverview() {
        guard homeMode == .easy, Calendar.current.isDateInToday(selectedDate) else {
            easyCycleCardOverview = nil
            return
        }
        easyCycleCardOverview = currentEasyCycleOverview
    }

    private func inferredLinksForSelectedDate() -> [EasyCycleRecordLink] {
        var links: [EasyCycleRecordLink] = []

        links.append(contentsOf: selectedSessions
            .map { EasyCycleRecordLink(type: .feeding, recordID: $0.id, phase: .eat) })

        links.append(contentsOf: selectedCareRecordsForSleepSummary
            .filter { $0.kind != .sleep }
            .map {
                EasyCycleRecordLink(
                    type: .care,
                    recordID: $0.id,
                    phase: .activity
                )
            })

        return links
    }

    private func inferredLinks(for cycle: EasyCycle) -> [EasyCycleRecordLink] {
        let end = cycleEffectiveEnd(cycle)
        var links: [EasyCycleRecordLink] = []

        links.append(contentsOf: selectedSessions
            .filter {
                let eventDate = $0.eventDate
                return eventDate >= cycle.startedAt && eventDate <= end
            }
            .map { EasyCycleRecordLink(type: .feeding, recordID: $0.id, phase: .eat) })

        links.append(contentsOf: selectedCareRecordsForSleepSummary
            .filter { $0.recordedAt >= cycle.startedAt && $0.recordedAt <= end }
            .map {
                EasyCycleRecordLink(
                    type: .care,
                    recordID: $0.id,
                    phase: $0.kind == .sleep ? .sleep : .activity
                )
            })

        return links
    }

    private func cycleFeedingSessions(for cycle: EasyCycle) -> [FeedingSession] {
        let linkedIDs = Set(cycle.linkedRecords.filter { $0.type == .feeding }.map(\.recordID))
        return selectedSessions
            .filter { linkedIDs.contains($0.id) }
            .sorted { $0.eventDate < $1.eventDate }
    }

    private func cycleCareRecords(for cycle: EasyCycle) -> [CareRecord] {
        let linkedIDs = Set(cycle.linkedRecords.filter { $0.type == .care }.map(\.recordID))
        return selectedCareRecordsForSleepSummary
            .filter { linkedIDs.contains($0.id) }
            .sorted { $0.recordedAt < $1.recordedAt }
    }

    private func cycleEffectiveEnd(_ cycle: EasyCycle) -> Date {
        cycle.endedAt ?? (Calendar.current.isDateInToday(selectedDate) ? now : selectedDate)
    }

    private func easyCycleTimeRangeText(_ cycle: EasyCycle) -> String {
        AppDateTimeFormat.timeRange(from: cycle.startedAt, to: cycle.endedAt)
    }

    private func easyCycleClockText(_ date: Date) -> String {
        AppDateTimeFormat.time(date)
    }

    private func easyCycleHasDisplayRecords(_ cycle: EasyCycle) -> Bool {
        !cycleFeedingSessions(for: cycle).isEmpty || !cycleCareRecords(for: cycle).isEmpty
    }

    private func easyCycleHeaderTimeText(_ cycle: EasyCycle) -> String {
        AppDateTimeFormat.timeRange(
            from: cycle.startedAt,
            to: easyCycleClosedBoundary(for: cycle)
        )
    }

    private func easyCycleClosedBoundary(for cycle: EasyCycle) -> Date? {
        if let endedAt = cycle.endedAt {
            return endedAt
        }
        return easyCycleTimelineItems
            .map(\.startedAt)
            .filter { $0 > cycle.startedAt }
            .min()
    }

    private func easyCycleBoundaryDate(for cycle: EasyCycle) -> Date {
        if let boundary = easyCycleClosedBoundary(for: cycle) {
            return boundary
        }
        if Calendar.current.isDateInToday(selectedDate) {
            return now
        }
        return Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: selectedDate)) ?? selectedDate
    }

    private func easyCycleCompletedEndDate(for cycle: EasyCycle) -> Date? {
        let sleepEnds = cycleCareRecords(for: cycle)
            .filter { $0.kind == .sleep }
            .compactMap { record -> Date? in
                guard let minutes = SleepRecordFormatter.durationMinutes(from: record.detail) else { return nil }
                return SleepRecordFormatter.endTime(start: record.recordedAt, durationMinutes: minutes)
            }
        return sleepEnds.max() ?? cycle.endedAt
    }

    private func easyCycleCompletion(for cycle: EasyCycle) -> EasyCycleCardCompletion {
        let sessions = cycleFeedingSessions(for: cycle)
        let activityRecords = cycleCareRecords(for: cycle).filter { $0.kind != .sleep }
        let sleepRecords = cycleCareRecords(for: cycle).filter { $0.kind == .sleep }
        return easyCycleCompletion(
            hasEat: !sessions.isEmpty,
            hasActivity: !activityRecords.isEmpty,
            hasSleep: !sleepRecords.isEmpty
        )
    }

    private func easyCycleCompletion(
        hasEat: Bool,
        hasActivity: Bool,
        hasSleep: Bool
    ) -> EasyCycleCardCompletion {
        if hasEat && hasActivity && hasSleep {
            return .complete
        }
        if !hasEat && !hasActivity && !hasSleep {
            return .empty
        }
        return .partial
    }

    private func awardCompleteEasyCyclesIfNeeded(surfaceFeedback: Bool = true) {
        let completeCycles = easyCycleTimelineItems
            .filter {
                $0.pendingSplitReviewID == nil
                    && easyCycleCompletion(for: $0) == .complete
            }
            .sorted { ($0.endedAt ?? cycleEffectiveEnd($0)) < ($1.endedAt ?? cycleEffectiveEnd($1)) }
        var latestReward: (amount: Int, title: String, key: String)?
        var reachedDailyLimit = false

        for cycle in completeCycles where !surfacedRewardCycleIDs.contains(cycle.id) {
            let completedAt = easyCycleCompletedEndDate(for: cycle)
                ?? cycle.endedAt
                ?? cycleEffectiveEnd(cycle)
            let result = recruitmentStore.awardBBBucks(
                forEasyCycle: cycle.id,
                superseding: cycle.supersedes ?? [],
                completedAt: completedAt,
                isPlusActive: membershipStore.isPlusActive
            )
            switch result.status {
            case .awarded:
                surfacedRewardCycleIDs.insert(cycle.id)
                let title = result.plusBonus > 0
                    ? "完整 EASY · Plus 加成".localized
                    : "完整 EASY 循环".localized
                latestReward = (
                    amount: result.amount,
                    title: title,
                    key: "easy-reward:\(cycle.id.uuidString.lowercased())"
                )
            case .dailyLimitReached:
                surfacedRewardCycleIDs.insert(cycle.id)
                reachedDailyLimit = true
            case .historical:
                surfacedRewardCycleIDs.insert(cycle.id)
            case .duplicate:
                surfacedRewardCycleIDs.insert(cycle.id)
            }
        }

        guard surfaceFeedback else { return }

        if let latestReward {
            feedbackCenter.presentReward(
                amount: latestReward.amount,
                title: latestReward.title,
                subtitle: "完成一轮照护节奏，奖励已经到账".localized,
                deduplicationKey: latestReward.key
            )
        } else if reachedDailyLimit {
            feedbackCenter.presentToast(AppToastMessage(
                text: "完整循环已记录 · 今日 EASY 奖励已全部获得".localized,
                style: .info,
                deduplicationKey: "easy-daily-limit:\(Calendar.current.startOfDay(for: now).timeIntervalSince1970)"
            ))
        }
    }

    private func easyCycleStatusText(_ cycle: EasyCycle) -> String {
        switch easyCycleCompletion(for: cycle) {
        case .complete: return easyCycleHeaderTimeText(cycle)
        case .partial, .empty: return easyCycleHeaderTimeText(cycle)
        }
    }

    private func easyCycleStatusColor(_ cycle: EasyCycle) -> Color {
        // The cycle state is communicated by the rows and completion markers;
        // keep the header time capsule as one stable purple navigation affordance.
        DesignToken.primary
    }

    private func easyCycleGuidance(
        step: EasyCycleStep,
        minutesSinceCycleStart: Int,
        activeSleepMinutes: Int?,
        minutesSinceWake: Int?
    ) -> String {
        switch step {
        case .eat:
            return "先让宝宝吃饱，妈妈也记得喝口水。".localized
        case .activity:
            return "宝宝吃饱啦，清醒活动，玩得开心。".localized
        case .sleep:
            return "宝宝玩好啦，大脑升级，睡得香甜。".localized
        case .yearning:
            return "宝宝吃饱、玩好、睡足啦，妈妈也该休息一下。".localized
        }
    }

    private func elapsedShortText(minutes: Int) -> String {
        let minutes = max(minutes, 0)
        return AppQuantityFormat.compactDuration(minutes)
    }

    private var latestSleepDurationMinutes: Int? {
        selectedCareRecordsForSleepSummary
            .filter { $0.kind == .sleep }
            .sorted { $0.recordedAt > $1.recordedAt }
            .compactMap { SleepRecordFormatter.durationMinutes(from: $0.detail) }
            .first
    }

    private var dailyRhythmSegments: [DailyRhythmHourSegment] {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: selectedDate)
        let now = Date()
        let isFutureDay = dayStart > calendar.startOfDay(for: now)
        let currentHour = calendar.component(.hour, from: now)

        return (0..<24).map { hour in
            let isFutureHour = isFutureDay || (calendar.isDateInToday(selectedDate) && hour > currentHour)
            let kinds = dailyRhythmKinds(for: hour)
            let intensity: Double
            if !kinds.isEmpty {
                intensity = 0.94
            } else if isFutureHour {
                intensity = 0.30
            } else {
                intensity = 0.44
            }

            return DailyRhythmHourSegment(
                hour: hour,
                kinds: kinds,
                intensity: intensity,
                isFuture: isFutureHour
            )
        }
    }

    private var dailyRhythmSpans: [RhythmTimelineSpan] {
        rhythmTimelineSpans(
            for: selectedDate,
            sessions: selectedSessions,
            careRecords: selectedCareRecordsForRhythmTimeline,
            ageMonths: profileStore.currentProfile.ageMonths
        )
    }

    private var selectedCareRecordsForRhythmTimeline: [CareRecord] {
        // CloudKit/import reconciliation can briefly surface duplicate IDs.
        // Keep the latest encountered record instead of trapping while the
        // homepage rhythm is being rendered.
        var recordsByID: [UUID: CareRecord] = [:]
        for record in selectedCareRecords {
            recordsByID[record.id] = record
        }
        for record in selectedCareRecordsForSleepSummary where record.kind == .sleep {
            recordsByID[record.id] = record
        }
        return Array(recordsByID.values)
    }

    private func dailyRhythmKinds(for hour: Int) -> [DailyRhythmKind] {
        var kinds: [DailyRhythmKind] = []

        if selectedSleepSummary.recordedSleepHours.contains(hour) {
            kinds.append(.sleep)
        }

        let feedingTypes = feedingTypesByHour[hour] ?? []
        if feedingTypes.contains(.bottle) {
            kinds.append(.bottle)
        }
        if feedingTypes.contains(.breast) {
            kinds.append(.breast)
        }
        if feedingTypes.contains(.solid) {
            kinds.append(.solid)
        }

        if diaperHours.contains(hour) {
            kinds.append(.diaper)
        }

        return kinds
    }

    private var feedingTypesByHour: [Int: Set<FeedingType>] {
        selectedSessions.reduce(into: [:]) { result, session in
            let hour = hour(from: session.eventDate)
            let types = Set(session.entries.map(\.type))
            result[hour, default: []].formUnion(types)
        }
    }

    private var diaperHours: Set<Int> {
        Set(selectedCareRecords.filter { $0.kind == .diaper }.map { hour(from: $0.recordedAt) })
    }

    private func hour(from date: Date) -> Int {
        Calendar.current.component(.hour, from: date)
    }

    private var inactiveRhythmStyle: AnyShapeStyle {
        AnyShapeStyle(DesignToken.iconSoftBG.opacity(0.82))
    }

    private var recordBottleColor: Color {
        DesignToken.feedingBottle
    }

    private var recordBreastColor: Color {
        DesignToken.feedingBreast
    }

    private var recordSolidColor: Color {
        DesignToken.feedingSolid
    }

    private var recordDiaperColor: Color {
        DesignToken.activityDiaper
    }

    private var recordSleepColor: Color {
        DesignToken.easySleep
    }

    private var possibleSleepColor: Color {
        DesignToken.easySleepSoft
    }

    private var elapsedEmptyColor: Color {
        DesignToken.borderSubtle
    }

    private var futureTimeColor: Color {
        DesignToken.iconSoftBG
    }

    private func feedingStyle(for types: Set<FeedingType>) -> AnyShapeStyle {
        let colors = types
            .sorted { $0.rawValue < $1.rawValue }
            .map(feedingColor)

        guard !colors.isEmpty else { return inactiveRhythmStyle }
        guard colors.count > 1 else { return AnyShapeStyle(colors[0].opacity(0.9)) }

        return AnyShapeStyle(
            LinearGradient(
                colors: colors.map { $0.opacity(0.9) },
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }

    private func feedingColor(for type: FeedingType) -> Color {
        switch type {
        case .bottle:
            return recordBottleColor
        case .breast:
            return recordBreastColor
        case .solid:
            return recordSolidColor
        }
    }

    private func sleepStyle(for state: TimelineHourState) -> AnyShapeStyle {
        switch state {
        case .future:
            return AnyShapeStyle(futureTimeColor)
        case .elapsed:
            return AnyShapeStyle(elapsedEmptyColor)
        case .possibleSleep:
            return AnyShapeStyle(possibleSleepColor)
        case .recordedSleep:
            return AnyShapeStyle(recordSleepColor)
        }
    }

    private func sleepIntensity(for state: TimelineHourState) -> Double {
        switch state {
        case .future:
            return 0.42
        case .elapsed:
            return 0.62
        case .possibleSleep:
            return 0.78
        case .recordedSleep:
            return 0.90
        }
    }

    private func timeText(for item: RecordHomeTimelineItem) -> String {
        item.timeText
    }

    private func timelineDetailText(for item: RecordHomeTimelineItem) -> String {
        if case .care(let record) = item, record.kind == .activity {
            return ""
        }
        return item.detailText
            .replacingOccurrences(of: "💧", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func delete(_ item: RecordHomeTimelineItem) {
        switch item {
        case .feeding(let session):
            feedingStore.deleteSession(session)
            // Deletion is initiated from this view, so refresh the derived EASY
            // cycle and its snapshot in the same turn instead of waiting for an
            // eventual object-publisher delivery.
            handleEasyCycleRecordMutation()
        case .care(let record):
            activityStore.deleteCareRecord(record)
            handleEasyCycleRecordMutation()
        case .growth(let record):
            growthMetricStore.deleteRecord(record)
        case .subjective(let checkIn):
            subjectiveStateStore.delete(checkIn)
        }
    }

    private var lastFeedingDateForSummary: Date? {
        let sessions = Calendar.current.isDateInToday(selectedDate) ? feedingStore.allSessions : selectedSessions
        return CareRecencyCalculator.snapshot(
            feedingSessions: sessions,
            careRecords: [],
            referenceDate: now
        ).feeding.completedAt
    }

    private var lastActivityDateForSummary: Date? {
        let records = Calendar.current.isDateInToday(selectedDate) ? activityStore.careRecords : selectedCareRecords
        let snapshot = CareRecencyCalculator.snapshot(
            feedingSessions: [],
            careRecords: records,
            referenceDate: now
        )
        return [snapshot.pee.completedAt, snapshot.poop.completedAt]
            .compactMap { $0 }
            .max()
    }

    private var lastSleepDateForSummary: Date? {
        let records = Calendar.current.isDateInToday(selectedDate) ? activityStore.careRecords : selectedCareRecordsForSleepSummary
        return CareRecencyCalculator.snapshot(
            feedingSessions: [],
            careRecords: records,
            referenceDate: now
        ).sleep.completedAt
    }

    private func compactElapsedSummaryText(since date: Date?) -> String {
        CareRecencyTimeFormatter.liveCompactText(
            since: date,
            relativeTo: now,
            emptyText: "--"
        )
    }

    private func weekdaySymbol(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = AppLocalization.locale
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }

    private func lerp(_ start: CGFloat, _ end: CGFloat, _ progress: CGFloat) -> CGFloat {
        start + (end - start) * max(0, min(progress, 1))
    }
}

private enum RecordHomeScrollTarget: Hashable {
    case rhythm
}

private enum RhythmAnalysisScope: String, CaseIterable, Identifiable {
    case week
    case month

    var id: String { rawValue }

    var title: String {
        switch self {
        case .week: return "周节奏"
        case .month: return "月节奏"
        }
    }
}

private struct StatisticsAnalysisView: View {
    @EnvironmentObject private var feedingStore: FeedingStore
    @EnvironmentObject private var activityStore: ActivityStore
    @EnvironmentObject private var companionStore: CompanionStore
    @EnvironmentObject private var recruitmentStore: CompanionRecruitmentStore
    @EnvironmentObject private var bbBriefStore: BBBriefStore
    @Environment(BabyProfileStore.self) private var profileStore
    @State private var selectedScope: RhythmAnalysisScope = .week
    @State private var selectedWeekOffset: Int = 0
    @State private var selectedMonthIndex: Int?
    @State private var daySummaries: [RhythmAnalysisDaySummary] = []
    @State private var selectedRhythmReport: DailyReportSnapshot?
    @State private var pendingReportReward: BBBuckTransaction?
    @AppStorage("daily_report_celebration_last_transaction_id_v1")
    private var lastPresentedReportRewardTransactionID = ""

    private let dateColumnWidth: CGFloat = 58

    var body: some View {
        ZStack {
            HomeSoftBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    scopeSwitcher
                    rhythmCard
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 96)
            }
        }
        .navigationTitle("统计分析")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $selectedRhythmReport, onDismiss: presentPendingReportReward) { report in
            BBBriefPage(
                snapshot: report,
                snapshots: bbBriefStore.snapshots,
                lastPresentedReportRewardTransactionID: lastPresentedReportRewardTransactionID,
                onRewardReady: { pendingReportReward = $0 }
            ) {
                selectedRhythmReport = nil
            }
            .environmentObject(recruitmentStore)
        }
        .onAppear(perform: refreshDaySummaries)
        .onChange(of: selectedScope) { _, _ in
            refreshDaySummaries()
        }
        .onChange(of: selectedWeekOffset) { _, _ in
            refreshDaySummaries()
        }
        .onChange(of: selectedMonthIndex) { _, _ in
            refreshDaySummaries()
        }
        .onChange(of: profileStore.currentProfile.birthDate) { _, _ in
            refreshDaySummaries()
        }
        .onReceive(
            feedingStore.$sessions
                .combineLatest(activityStore.$careRecords)
                .dropFirst()
                .debounce(for: .milliseconds(60), scheduler: RunLoop.main)
        ) { _ in
            refreshDaySummaries()
        }
    }

    private func presentPendingReportReward() {
        guard let transaction = pendingReportReward else { return }
        pendingReportReward = nil

        BBBriefRewardFeedback.present(transaction)
        lastPresentedReportRewardTransactionID = transaction.id
    }

    private var scopeSwitcher: some View {
        HStack(spacing: 4) {
            ForEach(RhythmAnalysisScope.allCases) { scope in
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        selectedScope = scope
                    }
                } label: {
                    Text(scope.title.localized)
                        .font(BBBFont.font(size: 13, weight: .heavy))
                        .foregroundStyle(selectedScope == scope ? DesignToken.onPrimary : DesignToken.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(
                            Capsule()
                                .fill(selectedScope == scope ? DesignToken.primary : Color.clear)
                                .shadow(color: selectedScope == scope ? DesignToken.primary.opacity(0.22) : .clear, radius: 10, y: 5)
                        )
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(4)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(Capsule().fill(DesignToken.surfaceRaised.opacity(0.58)))
                .overlay(Capsule().stroke(DesignToken.glassStroke.opacity(0.78), lineWidth: 0.9))
        )
    }

    private var rhythmCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                VStack(spacing: 2) {
                    Text(periodTitle)
                        .font(BBBFont.font(size: 18, weight: .heavy))
                        .foregroundStyle(DesignToken.textPrimary)
                    Text(periodDateRangeText)
                        .font(BBBFont.font(size: 11, weight: .bold))
                        .foregroundStyle(DesignToken.textSecondary)
                }
                .multilineTextAlignment(.center)

                HStack {
                    monthNavButton(systemName: "chevron.left", isEnabled: canNavigateBackward) {
                        navigateBackward()
                    }

                    Spacer()

                    monthNavButton(systemName: "chevron.right", isEnabled: canNavigateForward) {
                        navigateForward()
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 34)

            rhythmLegend

            LazyVStack(spacing: 0) {
                hourGuide

                ForEach(daySummaries) { summary in
                    rhythmMonthRow(summary)
                }
            }
        }
        .padding(.horizontal, 2)
    }

    private var hourGuide: some View {
        HStack(spacing: 6) {
            Text("日期")
                .font(BBBFont.font(size: 9, weight: .heavy))
                .foregroundStyle(DesignToken.textSecondary)
                .frame(width: dateColumnWidth, alignment: .leading)

            RhythmTimelineTimeScale()
        }
        .frame(height: 10)
        .padding(.bottom, 3)
    }

    private func rhythmMonthRow(_ summary: RhythmAnalysisDaySummary) -> some View {
        Button {
            openRhythmDetail(for: summary.date)
        } label: {
            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(summary.dateText)
                        .font(BBBFont.font(size: 10.5, weight: summary.isToday ? .heavy : .bold))
                        .foregroundStyle(DesignToken.textPrimary.opacity(0.88))
                        .lineLimit(1)

                    Text(summary.ageDayText)
                        .font(BBBFont.font(size: 8.5, weight: .bold))
                        .foregroundStyle(DesignToken.textSecondary.opacity(0.70))
                        .lineLimit(1)
                }
                .frame(width: dateColumnWidth, alignment: .leading)

                TodayRhythmMinimalTimeline(
                    date: summary.date,
                    spans: summary.spans,
                    height: 42,
                    showsTimeScale: false,
                    showsLaneLabels: false
                )
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(bbBriefStore.snapshot(on: summary.date) == nil)
        .background(
            summary.isToday
                ? DesignToken.primary.opacity(0.055)
                : Color.clear,
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(DesignToken.borderSubtle.opacity(0.42))
                .frame(height: 0.5)
                .padding(.leading, dateColumnWidth + 6)
        }
        .accessibilityLabel("\(summary.accessibilityDateText)，\(bbBriefStore.snapshot(on: summary.date) == nil ? "尚无 BBBrief" : "查看 BBBrief")")
        .accessibilityHint("打开这一天已经定稿的 BBBrief")
    }

    private var rhythmLegend: some View {
        HStack(spacing: 10) {
            legendItem(.eat)
            legendItem(.activity)
            legendItem(.sleep)
        }
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func legendItem(_ stage: TodayRhythmMinimalStage) -> some View {
        Text(stage.badgeTitle)
            .font(BBBFont.font(size: 6.5, weight: .heavy))
            .foregroundStyle(stage.color)
            .frame(width: 12, height: 12)
            .background(Circle().fill(stage.color.opacity(0.16)))
            .overlay {
                Circle()
                    .stroke(stage.color.opacity(0.84), lineWidth: 0.9)
            }
    }

    private func monthNavButton(systemName: String, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(isEnabled ? DesignToken.primary : DesignToken.textSecondary.opacity(0.32))
                .frame(width: 34, height: 34)
                .background(
                    Circle()
                        .fill(DesignToken.surfaceRaised.opacity(isEnabled ? 0.52 : 0.20))
                )
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!isEnabled)
    }

    private var monthTitle: String {
        "\(currentMonthIndex)-\(currentMonthIndex + 1)月龄"
    }

    private var periodTitle: String {
        switch selectedScope {
        case .week:
            return selectedWeekOffset == 0 ? "近7日节奏" : "前\(selectedWeekOffset + 1)周节奏"
        case .month:
            return monthTitle
        }
    }

    private var periodDateRangeText: String {
        switch selectedScope {
        case .week:
            return "\(compactDateText(weekStart)) - \(compactDateText(weekEnd))"
        case .month:
            return monthDateRangeText
        }
    }

    private var periodDays: [Date] {
        switch selectedScope {
        case .week:
            return weekDays
        case .month:
            return monthDays
        }
    }

    private var weekEnd: Date {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: .day, value: -(selectedWeekOffset * 7), to: todayStart) ?? todayStart
    }

    private var weekStart: Date {
        Calendar.current.date(byAdding: .day, value: -6, to: weekEnd) ?? weekEnd
    }

    private var weekDays: [Date] {
        let calendar = Calendar.current
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: weekEnd)
        }
    }

    private var canNavigateBackward: Bool {
        switch selectedScope {
        case .week:
            return weekStart > birthStart
        case .month:
            return currentMonthIndex > 0
        }
    }

    private var canNavigateForward: Bool {
        switch selectedScope {
        case .week:
            return selectedWeekOffset > 0
        case .month:
            return currentMonthIndex < maxMonthIndex
        }
    }

    private func navigateBackward() {
        switch selectedScope {
        case .week:
            selectedWeekOffset += 1
        case .month:
            selectedMonthIndex = currentMonthIndex - 1
        }
    }

    private func navigateForward() {
        switch selectedScope {
        case .week:
            selectedWeekOffset = max(selectedWeekOffset - 1, 0)
        case .month:
            selectedMonthIndex = min(currentMonthIndex + 1, maxMonthIndex)
        }
    }

    private var monthDateRangeText: String {
        "\(compactDateText(monthStart)) - \(compactDateText(visibleMonthEnd))"
    }

    private var monthStart: Date {
        Calendar.current.date(byAdding: .month, value: currentMonthIndex, to: birthStart) ?? birthStart
    }

    private var monthEndExclusive: Date {
        Calendar.current.date(byAdding: .month, value: currentMonthIndex + 1, to: birthStart)
            ?? Calendar.current.date(byAdding: .day, value: 30, to: monthStart)
            ?? monthStart
    }

    private var monthEnd: Date {
        Calendar.current.date(byAdding: .day, value: -1, to: monthEndExclusive) ?? monthStart
    }

    private var visibleMonthEnd: Date {
        guard currentMonthIndex == maxMonthIndex else { return monthEnd }
        return min(monthEnd, Calendar.current.startOfDay(for: Date()))
    }

    private var monthDays: [Date] {
        let calendar = Calendar.current
        var dates: [Date] = []
        var cursor = monthStart
        let todayStart = calendar.startOfDay(for: Date())

        while cursor < monthEndExclusive {
            dates.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        let visibleDates = currentMonthIndex == maxMonthIndex
            ? dates.filter { $0 <= todayStart }
            : dates
        return visibleDates.sorted(by: >)
    }

    private var birthStart: Date {
        Calendar.current.startOfDay(for: profileStore.currentProfile.birthDate)
    }

    private var maxMonthIndex: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return max(calendar.dateComponents([.month], from: birthStart, to: today).month ?? 0, 0)
    }

    private var currentMonthIndex: Int {
        min(max(selectedMonthIndex ?? maxMonthIndex, 0), maxMonthIndex)
    }

    private func rhythmDaySummary(for date: Date) -> RhythmAnalysisDaySummary {
        let sessions = feedingStore.sessions(on: date)
        let careRecords = activityStore.careRecordsForSleepSummary(on: date)
        let spans = rhythmTimelineSpans(
            for: date,
            sessions: sessions,
            careRecords: careRecords,
            ageMonths: profileStore.currentProfile.ageMonths
        )

        return RhythmAnalysisDaySummary(
            date: date,
            dateText: dayLabel(for: date),
            ageDayText: "\(babyDayNumber(for: date))天",
            spans: spans,
            hasRecords: !(sessions.isEmpty && careRecords.isEmpty),
            isToday: Calendar.current.isDateInToday(date)
        )
    }

    private func babyDayNumber(for date: Date) -> Int {
        let days = Calendar.current.dateComponents([.day], from: birthStart, to: Calendar.current.startOfDay(for: date)).day ?? 0
        return max(days + 1, 1)
    }

    private func dayLabel(for date: Date) -> String {
        AppDateTimeFormat.date(date)
    }

    private func compactDateText(_ date: Date) -> String {
        AppDateTimeFormat.date(date)
    }

    private func refreshDaySummaries() {
        daySummaries = periodDays.map { rhythmDaySummary(for: $0) }
    }

    private func openRhythmDetail(for date: Date) {
        selectedRhythmReport = bbBriefStore.snapshot(on: date)
    }
}

private struct RhythmAnalysisDaySummary: Identifiable {
    let date: Date
    let dateText: String
    let ageDayText: String
    let spans: [RhythmTimelineSpan]
    let hasRecords: Bool
    let isToday: Bool

    var id: Date { date }
    var accessibilityDateText: String { "\(dateText)，\(ageDayText)" }
}

private struct RecordHomeLayoutMetrics {
    let horizontalPadding: CGFloat
    let contentMaxWidth: CGFloat
    let dateHeaderBottom: CGFloat
    let dayPickerBottom: CGFloat
    let rhythmBottom: CGFloat
    let guidanceBottom: CGFloat
    let topPadding: CGFloat
    let bottomPadding: CGFloat
    let headerCardOverlap: CGFloat

    var expandedHeaderHeight: CGFloat {
        topPadding + 46 + dateHeaderBottom + 58 + dayPickerBottom
    }

    var collapsedHeaderHeight: CGFloat {
        topPadding + 38 + 4 + 52 + 4
    }

    func headerProgress(for offset: CGFloat) -> CGFloat {
        min(max(offset / 110, 0), 1)
    }

    func headerHeight(progress: CGFloat) -> CGFloat {
        let clampedProgress = min(max(progress, 0), 1)
        return expandedHeaderHeight + (collapsedHeaderHeight - expandedHeaderHeight) * clampedProgress
    }

    init(size: CGSize, safeAreaInsets: EdgeInsets, itemCount: Int) {
        let isCompact = size.height < 780
        let hasTimeline = itemCount > 0

        self.horizontalPadding = size.width < 390 ? 18 : 20
        self.contentMaxWidth = size.width > 700 ? 520 : .infinity
        self.dateHeaderBottom = isCompact ? 10 : 12
        self.dayPickerBottom = 12
        self.rhythmBottom = 16
        self.guidanceBottom = 12
        self.topPadding = isCompact ? 10 : 12
        self.bottomPadding = max(safeAreaInsets.bottom + 118, hasTimeline ? 142 : 72)
        self.headerCardOverlap = 0
    }
}

private struct RhythmSummaryItem: Identifiable {
    let id = UUID()
    let text: String
    let color: Color
}

enum EasyCycleStep: Int, CaseIterable, Identifiable, Sendable {
    case eat
    case activity
    case sleep
    case yearning

    var id: Int { rawValue }
    var index: Int { rawValue }

    var letter: String {
        switch self {
        case .eat: return "E"
        case .activity: return "A"
        case .sleep: return "S"
        case .yearning: return "Y"
        }
    }

    var title: String {
        switch self {
        case .eat: return "喂养"
        case .activity: return "活动"
        case .sleep: return "睡眠"
        case .yearning: return "状态"
        }
    }

    var color: Color {
        switch self {
        case .eat: return DesignToken.easyEat
        case .activity: return DesignToken.easyActivity
        case .sleep: return DesignToken.easySleep
        case .yearning: return DesignToken.easyYearning
        }
    }

    init(_ phase: EasyCyclePhase) {
        switch phase {
        case .eat: self = .eat
        case .activity: self = .activity
        case .sleep: self = .sleep
        case .yearning: self = .yearning
        }
    }
}

private extension EasyCycleStep {
    var pageTitle: String {
        switch self {
        case .eat: return "喂养详情".localized
        case .activity: return "活动详情".localized
        case .sleep: return "睡眠详情".localized
        case .yearning: return "状态记录".localized
        }
    }

    var weekTitle: String {
        switch self {
        case .eat: return "近7天喂养".localized
        case .activity: return "近7天活动".localized
        case .sleep: return "近7天睡眠".localized
        case .yearning: return "近7天状态".localized
        }
    }
}

private enum EasyCycleStepState {
    case pending
    case current
    case done
}

enum EasyCycleCardCompletion: Equatable, Sendable {
    case empty
    case partial
    case complete
}

struct EasyCycleTimelineRow: Identifiable {
    var id: EasyCycleStep { step }
    let step: EasyCycleStep
    let title: String
    let primaryText: String
    let secondaryText: String
    let timeText: String
    let detailItems: [EasyCycleTimelineDetailItem]
}

struct EasyCycleTimelineDetailItem: Identifiable {
    let id: String
    let timeText: String
    let bodyText: String
    let item: RecordHomeTimelineItem
}

private struct EasyCycleOverview {
    let startedAt: Date
    let currentStep: EasyCycleStep
    let eatText: String
    let activityText: String
    let sleepText: String
    let yearningText: String
    let hasEatData: Bool
    let hasActivityData: Bool
    let hasSleepData: Bool
    let hasYearningData: Bool
    let guidance: String

    var startedAtText: String {
        "\(AppDateTimeFormat.time(startedAt))开始"
    }

    var stageBadgeText: String {
        "正在\(currentStep.title)"
    }

    func state(for step: EasyCycleStep) -> EasyCycleStepState {
        if step == currentStep { return .current }
        return step.index < currentStep.index ? .done : .pending
    }

    func value(for step: EasyCycleStep) -> String {
        switch step {
        case .eat: return eatText
        case .activity: return activityText
        case .sleep: return sleepText
        case .yearning: return yearningText
        }
    }

    func hasData(for step: EasyCycleStep) -> Bool {
        switch step {
        case .eat: return hasEatData
        case .activity: return hasActivityData
        case .sleep: return hasSleepData
        case .yearning: return hasYearningData
        }
    }
}

private struct SpeechBubble: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cornerRadius: CGFloat = min(16, rect.height * 0.34)
        let tailWidth: CGFloat = min(18, rect.width * 0.12)
        let tailHeight: CGFloat = min(10, rect.height * 0.22)
        let bubbleRect = CGRect(
            x: rect.minX,
            y: rect.minY,
            width: rect.width,
            height: rect.height - tailHeight
        )

        path.addRoundedRect(in: bubbleRect, cornerSize: CGSize(width: cornerRadius, height: cornerRadius))
        path.move(to: CGPoint(x: bubbleRect.minX + 30, y: bubbleRect.maxY - 1))
        path.addLine(to: CGPoint(x: bubbleRect.minX + 30 + tailWidth * 0.46, y: rect.maxY))
        path.addLine(to: CGPoint(x: bubbleRect.minX + 30 + tailWidth, y: bubbleRect.maxY - 1))
        path.closeSubpath()
        return path
    }
}

private struct BabyTrendDetailContext: Identifiable {
    let metric: EasyCycleStep
    var id: Int { metric.rawValue }
}

private struct BabyTrendDetailSnapshot {
    let ageText: String
    let guidance: AgeRhythmGuidance
    let overview: BabyTrendOverview
    let careSummary: BabyWeeklyCareSummary
    let recentBabyState: BabySubjectiveState?
}

private struct YearningDetailContext: Identifiable {
    let id = "yearning-detail"
}

enum RhythmMetricTileStyle {
    case dark
    case light

    var titleColor: Color {
        switch self {
        case .dark: return DesignToken.onPrimary.opacity(0.76)
        case .light: return DesignToken.textMuted
        }
    }

    var prefixColor: Color {
        switch self {
        case .dark: return DesignToken.onPrimary.opacity(0.70)
        case .light: return DesignToken.textFaint
        }
    }

    var mainColor: Color {
        switch self {
        case .dark: return DesignToken.onPrimary.opacity(0.96)
        case .light: return DesignToken.textStrong
        }
    }

    var unitColor: Color {
        switch self {
        case .dark: return DesignToken.onPrimary.opacity(0.72)
        case .light: return DesignToken.textMuted
        }
    }

    var extraColor: Color {
        switch self {
        case .dark: return DesignToken.onPrimary.opacity(0.76)
        case .light: return DesignToken.textMuted
        }
    }

    func fillColor(accent: Color) -> Color {
        switch self {
        case .dark: return DesignToken.onPrimary.opacity(0.18)
        case .light: return DesignToken.surface.opacity(0.52)
        }
    }

    func overlayColor(accent: Color) -> Color {
        switch self {
        case .dark: return accent.opacity(0.10)
        case .light: return accent.opacity(0.06)
        }
    }

    func strokeColor(accent: Color) -> Color {
        switch self {
        case .dark: return DesignToken.onPrimary.opacity(0.26)
        case .light: return accent.opacity(0.14)
        }
    }

    func infoIconColor(accent: Color) -> Color {
        switch self {
        case .dark: return DesignToken.onPrimary.opacity(0.90)
        case .light: return accent.opacity(0.88)
        }
    }

    func infoFillColor(accent: Color) -> Color {
        switch self {
        case .dark: return DesignToken.onPrimary.opacity(0.14)
        case .light: return accent.opacity(0.10)
        }
    }

    func infoStrokeColor(accent: Color) -> Color {
        switch self {
        case .dark: return DesignToken.onPrimary.opacity(0.34)
        case .light: return accent.opacity(0.18)
        }
    }
}

struct RhythmMetricTile: View {
    let badge: String
    let title: String
    let value: String
    let color: Color
    var showsInfo = false
    let style: RhythmMetricTileStyle

    var body: some View {
        VStack(alignment: .center, spacing: 3) {
            HStack(spacing: 3) {
                RhythmMetricBadge(letter: badge, color: color)

                Text(localizedEasyMetricTitle(title))
                    .font(BBBFont.font(size: 8.5, weight: .heavy))
                    .foregroundStyle(style.titleColor)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)

            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(value.localized)
                    .font(BBBFont.font(size: 10, weight: .heavy))
                    .foregroundStyle(style.mainColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.01)
                    .allowsTightening(true)

                if showsInfo {
                    Image(systemName: "exclamationmark")
                        .font(.system(size: 5.5, weight: .black))
                        .foregroundStyle(style.infoIconColor(accent: color))
                        .frame(width: 10, height: 10)
                        .background(
                            Circle()
                                .fill(style.infoFillColor(accent: color))
                                .overlay(Circle().stroke(style.infoStrokeColor(accent: color), lineWidth: 0.7))
                        )
                        .alignmentGuide(.firstTextBaseline) { dimensions in
                            dimensions[VerticalAlignment.center] + 3
                        }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .center)
        .background(
            RoundedRectangle(cornerRadius: DesignToken.controlRadius, style: .continuous)
                .fill(style.fillColor(accent: color))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignToken.controlRadius, style: .continuous)
                        .fill(style.overlayColor(accent: color))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignToken.controlRadius, style: .continuous)
                        .stroke(style.strokeColor(accent: color), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
    }
}

struct RhythmSubjectiveStateTile: View {
    let babyState: BabySubjectiveState?
    let style: RhythmMetricTileStyle

    var body: some View {
        VStack(alignment: .center, spacing: 3) {
            HStack(spacing: 3) {
                RhythmMetricBadge(letter: "Y", color: DesignToken.easyYearning)

                Text(localizedEasyMetricTitle("状态"))
                    .font(BBBFont.font(size: 8.5, weight: .heavy))
                    .foregroundStyle(style.titleColor)
                    .lineLimit(1)
            }

            HStack(spacing: 1.5) {
                if let babyState {
                    SubjectiveStateIcon(kind: .baby(babyState), size: 14)
                }
                Text(babyState?.title ?? "--")
                    .font(BBBFont.font(size: 10, weight: .heavy))
                    .foregroundStyle(style.mainColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.01)
                    .allowsTightening(true)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 3)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .center)
        .background(
            RoundedRectangle(cornerRadius: DesignToken.controlRadius, style: .continuous)
                .fill(style.fillColor(accent: DesignToken.easyYearning))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignToken.controlRadius, style: .continuous)
                        .fill(style.overlayColor(accent: DesignToken.easyYearning))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignToken.controlRadius, style: .continuous)
                        .stroke(style.strokeColor(accent: DesignToken.easyYearning), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
    }
}

private struct RhythmMetricBadge: View {
    let letter: String
    let color: Color

    var body: some View {
        Text(letter)
            .font(BBBFont.font(size: 8, weight: .heavy))
            .foregroundStyle(DesignToken.onPrimary)
            .frame(width: 12, height: 12)
            .background(
                Circle()
                    .fill(color)
                    .overlay(Circle().stroke(DesignToken.onPrimary.opacity(0.56), lineWidth: 1))
            )
    }
}

private struct AgeRhythmGuidance {
    let cardText: String
    let detailText: String

    static func guidance(for month: Int) -> AgeRhythmGuidance {
        let safeMonth = min(max(month, 0), 36)
        switch safeMonth {
        case 0:
            return item("按需喂养为主，配方奶可参考体重×150ml/日；清醒约45-60分钟，重点看尿布和体重增长。",
                        "新生儿以按需喂养和安全睡眠为核心。白天用自然光帮助建立昼夜感，清醒时短暂趴卧练习即可。")
        case 1:
            return item("每次60-90ml，约2-3小时一喂；清醒45-60分钟，尿布频繁、睡眠不规律都常见。",
                        "1个月宝宝主要看吃奶反应、尿布湿度和体重增长。活动以黑白卡、轻声互动、1-2分钟趴卧为主。")
        case 2:
            return item("每次90-120ml，约2.5-3小时一喂；宝宝可能攒肚，清醒间隔约60-75分钟。",
                        "2个月开始有更清楚的昼夜节奏。观察尿布和精神状态，练习视觉追踪、听音辨位和俯卧抬头。")
        case 3:
            return item("每次120-150ml，约3-3.5小时一喂；清醒75-90分钟，可开始稳定吃-玩-睡。",
                        "3个月可逐步固定吃-玩-睡节奏。夜间可能拉长到4-6小时，白天用抓握、抬头和咿呀互动消耗精力。")
        case 4:
            return item("每次150-180ml，约3.5-4小时一喂；清醒1.5-2小时，留意4月龄睡眠倒退。",
                        "4个月睡眠周期变化明显。翻身迹象出现后停止包巾，清醒时练翻身、照镜子和手眼协调。")
        case 5:
            return item("每次180-210ml，全天奶量接近高峰但不超1000ml；清醒约2-2.25小时。",
                        "5个月黄昏觉可能抗拒，睡前仪式要固定。活动可加入靠坐、抓脚和双手玩具交换。")
        case 6:
            return item("每次180-240ml，全天约800-900ml；可加1餐高铁辅食，清醒2.25-2.5小时。",
                        "6个月仍以奶为重要营养，辅食从少量单一食材开始。练独坐、撕纸和双手倒换玩具。")
        case 7:
            return item("全天奶量约700-800ml，配1餐辅食；清醒2.5-2.75小时，活动量开始上来。",
                        "7个月进入大运动爆发前段，腹爬、连续翻身和躲猫猫能帮助白天放电。")
        case 8:
            return item("全天奶量约650-800ml，配2餐辅食；清醒2.75-3小时，两次小睡更稳定。",
                        "8个月多数宝宝上午觉和下午觉更固定。练手膝爬、扶站和手指捏取食物。")
        case 9:
            return item("全天奶量约600-700ml，配2餐辅食；清醒约3小时，夜醒时尽量低互动。",
                        "9个月可逐步减少夜间高互动喂养。白天练扶物移动、精细抓握和简单回应。")
        case 10:
            return item("全天奶量约600ml，配3餐辅食；清醒3-3.25小时，三餐节奏接近家庭。",
                        "10个月副食可同步家庭三餐节奏。活动以模仿发音、指认物品和扶物蹲起为主。")
        case 11:
            return item("全天奶量约500-600ml，辅食可到软饭碎菜；清醒3.25-3.5小时。",
                        "11个月饮食质地可更丰富。练独站、拍手、挥手再见和简单指令理解。")
        case 12:
            return item("全天奶量约500ml，三餐逐渐成为主能量；清醒3.5-4小时，注意保护午睡。",
                        "12个月辅食逐渐成为主要能量来源。牵手走路、搭积木和听懂简单指令是重点。")
        case 13:
            return item("三餐两点为主，奶量约350-480ml；清醒约4小时，可能开始并觉过渡。",
                        "13个月开始从2觉向1觉过渡。活动以独走、涂鸦和指认身体部位为主。")
        case 14:
            return item("三餐两点更规律，奶量约350-480ml；清醒4-4.5小时，上午觉可逐步缩短。",
                        "14个月如果下午觉受影响，可以先压缩上午觉。鼓励自主进食和安全探索。")
        case 15:
            return item("三餐两点为主，奶量约350-480ml；清醒约4.5小时，白天小睡可能合并。",
                        "15个月常处在1-2次小睡切换期。观察下午精神状态，比强行固定时钟更重要。")
        case 16:
            return item("鼓励自主用勺，奶量维持350-480ml；清醒4.5-5小时，午餐后适合长午觉。",
                        "16个月语言和运动都在加速。可练倒退走、指物命名和简单收纳。")
        case 17:
            return item("三餐两点保持稳定，奶量别挤占正餐；清醒约5小时，1次午觉更清晰。",
                        "17个月重点是规律餐点和稳定午睡。白天活动量不足会直接影响夜间入睡。")
        case 18:
            return item("继续自主进食，奶量控制350-480ml；清醒5-5.5小时，午觉多为1.5-2.5小时。",
                        "18个月多已合并为一次午觉。语言爆发期可多做命名、回应和生活场景对话。")
        case 19:
            return item("三餐两点少盐少糖，奶量作为补充；清醒5.5-6小时，运动需求更明显。",
                        "19个月开始能表达更多需求。踢球、脱鞋袜、双词短句练习都适合。")
        case 20:
            return item("重点看三餐结构，奶量不宜过多；清醒5.5-6小时，午觉结束别太晚。",
                        "20个月如果晚上难睡，先检查午觉结束时间和下午活动量。")
        case 21:
            return item("三餐两点稳定，奶量作为补钙补充；清醒约6小时，午觉通常1.5-2小时。",
                        "21个月适合增加跑跳、搬运和模仿类游戏，同时保留安静睡前流程。")
        case 22:
            return item("餐点可同步成人，奶量约350-480ml；清醒约6小时，可引入如厕认知。",
                        "22个月可认识小马桶但不强迫训练。角色扮演和颜色分类能帮助表达。")
        case 23:
            return item("奶逐渐变成膳食补充，三餐更关键；清醒约6小时，稳定午觉保护夜睡。",
                        "23个月重点是固定边界和睡前流程。白天给足运动，晚上减少刺激。")
        case 24:
            return item("奶量约350-400ml，三餐两点为主；清醒约6小时，警惕2岁睡眠倒退。",
                        "2岁可能出现睡眠倒退和分离焦虑。保持作息一致，比临时拉长清醒更有效。")
        case 25...30:
            return item("三餐两点为主，奶量约300-360ml；清醒6-6.5小时，午觉尽量16点前醒。",
                        "25-30个月适合训练裤、定时如厕和更多户外运动。午觉过晚会明显推迟夜间入睡。")
        case 31...36:
            return item("家庭饮食为主，奶量约300-360ml；清醒6.5-7小时，不午睡也保留安静休息。",
                        "31-36个月开始建立进餐礼仪和定时排便。部分孩子不午睡，也需要安排安静时间。")
        default:
            return item("建议继续保持稳定吃拉玩睡节奏，重点观察精神状态、食欲和生长曲线。",
                        "3岁后个体差异更明显，只要精神状态好、生长达标，可围绕家庭作息微调。")
        }
    }

    private static func item(_ cardText: String, _ detailText: String) -> AgeRhythmGuidance {
        AgeRhythmGuidance(cardText: cardText, detailText: detailText)
    }
}

private struct BabyWeeklyCareSummary {
    let lines: [String]
}

private func calendarDaySleepMinutes(on date: Date, records: [CareRecord]) -> Int {
    let calendar = Calendar.current
    let dayStart = calendar.startOfDay(for: date)
    guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
        return 0
    }

    return records.reduce(0) { total, record in
        guard record.kind == .sleep,
              let minutes = SleepRecordFormatter.durationMinutes(from: record.detail) else {
            return total
        }
        let sleepStart = record.recordedAt
        let sleepEnd = SleepRecordFormatter.endTime(start: sleepStart, durationMinutes: minutes)
        let overlapStart = max(sleepStart, dayStart)
        let overlapEnd = min(sleepEnd, dayEnd)
        guard overlapEnd > overlapStart else { return total }

        let overlapMinutes = Int(overlapEnd.timeIntervalSince(overlapStart) / 60)
        return total + max(overlapMinutes, 0)
    }
}

private struct BabyTrendOverview {
    let bottleML: Int
    let breastMinutes: Int
    let breastEquivalentML: Int
    let solidGrams: Int
    let equivalentMilkML: Int
    let feedingMinutes: Int
    let diaperCount: Int
    let poopCount: Int
    let peeCount: Int
    let activitySegments: Int
    let urineEstimateText: String
    let sleepText: String

    var feedingAmountText: String {
        guard equivalentMilkML > 0 || solidGrams > 0 else { return "--" }

        var text = ""
        if equivalentMilkML > 0 {
            text = AppMeasurementFormat.volume(Double(equivalentMilkML))
        }
        if solidGrams > 0 {
            let solidText = AppMeasurementFormat.mass(Double(solidGrams))
            text += text.isEmpty ? solidText : " \(solidText)"
        }
        return text
    }

    var feedingText: String {
        var parts: [String] = []
        if bottleML > 0 { parts.append(AppMeasurementFormat.volume(Double(bottleML))) }
        if breastMinutes > 0 { parts.append(AppQuantityFormat.compactDuration(breastMinutes)) }
        if solidGrams > 0 { parts.append(AppMeasurementFormat.mass(Double(solidGrams))) }
        return parts.isEmpty ? "--" : parts.joined(separator: " ")
    }

    var activityText: String {
        var parts: [String] = []
        if poopCount > 0 { parts.append("\(poopCount)拉") }
        if peeCount > 0 { parts.append("\(peeCount)尿") }
        if activitySegments > 0 {
            parts.append("\(activitySegments)玩")
        }
        return parts.isEmpty ? "--" : parts.joined()
    }

    var feedingDetailText: String {
        var parts: [String] = []
        if feedingMinutes > 0 {
            parts.append("平均喂养\(AppQuantityFormat.compactDuration(feedingMinutes))")
        }
        if bottleML > 0 {
            parts.append("\(AppMeasurementFormat.volume(Double(bottleML)))奶")
        }
        if breastMinutes > 0 {
            parts.append("\(AppQuantityFormat.compactDuration(breastMinutes))亲喂（换算\(AppMeasurementFormat.volume(Double(breastEquivalentML)))）")
        }
        if solidGrams > 0 {
            parts.append("\(AppMeasurementFormat.mass(Double(solidGrams)))辅食")
        }
        let detail = parts.isEmpty ? "近7日还没有喂养数据。" : parts.joined(separator: " + ")
        return "\(detail)\n折合：\(feedingAmountText)"
    }

    var activityDetailText: String {
        var parts: [String] = []
        if diaperCount > 0 {
            parts.append("尿布\(diaperCount)次")
        }
        if activitySegments > 0 {
            parts.append("玩/清醒互动\(activitySegments)次")
        }
        return parts.isEmpty ? "近7日还没有可估算的清醒照护数据。" : parts.joined(separator: "\n")
    }

    var sleepDetailText: String {
        sleepText == "--" ? "近7日还没有睡眠记录。" : "平均睡眠 \(sleepText)"
    }
}

private struct BabyTrendSummaryCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let profile: BabyProfileData
    let ageText: String
    var dateTransitionDirection = 1
    let summary: BabyWeeklyCareSummary
    let overview: BabyTrendOverview
    let babyState: BabySubjectiveState?
    var showsToggle = false
    var isExpanded = false
    var onToggle: () -> Void = {}
    var onSelect: (EasyCycleStep) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array(summary.lines.enumerated()), id: \.offset) { _, line in
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Circle()
                            .fill(DesignToken.onPrimary.opacity(0.72))
                            .frame(width: 3, height: 3)
                        Text(line)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .minimumScaleFactor(0.82)
                    }
                }
            }
            .font(BBBFont.font(size: 9.8, weight: .semibold))
            .foregroundStyle(DesignToken.onPrimary.opacity(0.94))
            .allowsTightening(true)

            Spacer(minLength: 10)

            GeometryReader { proxy in
                let spacing: CGFloat = 8
                let width = max((proxy.size.width - spacing * 3) / 4, 0)
                HStack(spacing: spacing) {
                    metricTile(.eat, value: overview.feedingText).frame(width: width)
                    metricTile(.activity, value: overview.activityText).frame(width: width)
                    metricTile(.sleep, value: overview.sleepText).frame(width: width)
                    Button { onSelect(.yearning) } label: {
                        RhythmSubjectiveStateTile(babyState: babyState, style: .dark)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .frame(width: width, height: 44)
                    .contentShape(Rectangle())
                    .accessibilityIdentifier("record-home-easy-tile-y")
                    .accessibilityLabel(EasyCycleStep.yearning.pageTitle)
                }
            }
            .frame(height: 44)
        }
        .padding(.horizontal, 16)
        .padding(.top, 54)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .overlay(alignment: .topLeading) { header.padding(.horizontal, 16) }
        .background(surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignToken.largeCardRadius, style: .continuous))
        .shadow(color: DesignToken.shadowColor.opacity(0.24), radius: 16, y: 8)
        .overlay(alignment: .top) {
            if showsToggle {
                Rectangle()
                    .fill(DesignToken.scrim.opacity(0.001))
                    .frame(height: 54)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onToggle)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            BabyProfileAvatarView(
                profile: profile,
                size: 24,
                emojiSize: 12,
                lineWidth: 1,
                motionScale: 0.45,
                allowsMotion: false
            )
            .overlay(Circle().stroke(DesignToken.onPrimary.opacity(0.96), lineWidth: 1))

            Text(ageText)
                .font(BBBFont.font(size: 15, weight: .bold))
                .foregroundStyle(DesignToken.onPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.76)
                .monospacedDigit()
                .contentTransition(.numericText(countsDown: dateTransitionDirection < 0))
                .animation(
                    reduceMotion ? nil : .snappy(duration: 0.26, extraBounce: 0),
                    value: ageText
                )

            Spacer(minLength: 8)

            if showsToggle {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(DesignToken.onPrimary.opacity(0.94))
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(DesignToken.onPrimary.opacity(0.16)))
                    .frame(width: DesignToken.minimumTapSize, height: DesignToken.minimumTapSize)
            } else {
                Text("近7日".localized)
                    .font(BBBFont.font(size: 9, weight: .heavy))
                    .foregroundStyle(DesignToken.onPrimary.opacity(0.84))
                    .padding(.horizontal, 9)
                    .frame(height: 24)
                    .background(Capsule().fill(DesignToken.onPrimary.opacity(0.14)))
            }
        }
        .frame(height: 44)
    }

    private func metricTile(_ step: EasyCycleStep, value: String) -> some View {
        Button { onSelect(step) } label: {
            RhythmMetricTile(
                badge: step.letter,
                title: step.title,
                value: value,
                color: step.color,
                style: .dark
            )
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .accessibilityIdentifier("record-home-easy-tile-\(step.letter.lowercased())")
        .accessibilityLabel(step.pageTitle)
    }

    private var surface: some View {
        RoundedRectangle(cornerRadius: DesignToken.largeCardRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [DesignToken.primary.opacity(0.98), DesignToken.feedingBreast.opacity(0.92)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignToken.largeCardRadius, style: .continuous)
                    .fill(LinearGradient(colors: [DesignToken.onPrimary.opacity(0.13), DesignToken.onPrimary.opacity(0.02)], startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .overlay(RoundedRectangle(cornerRadius: DesignToken.largeCardRadius, style: .continuous).strokeBorder(DesignToken.onPrimary.opacity(0.56), lineWidth: 1))
    }
}

private struct TodayRhythmOverview {
    let feedingText: String
    let activityText: String
    let sleepText: String
}

private struct BabyTrendDetailRow: Identifiable {
    let id = UUID()
    let title: String
    let summary: String
    let detail: String
    let color: Color
}

private enum RhythmSummaryScope: String, CaseIterable, Identifiable, Hashable {
    case week
    case month

    var id: String { rawValue }

    var title: String {
        switch self {
        case .week: return "周"
        case .month: return "月"
        }
    }

    var shortTitle: String {
        switch self {
        case .week: return "近7日"
        case .month: return "本月龄"
        }
    }
}

private struct RhythmMetricsCacheKey: Hashable {
    let scope: RhythmSummaryScope
    let offset: Int
}

private struct RhythmDailyMetric: Identifiable {
    let id = UUID()
    let date: Date
    let feedingML: Int
    let diaperCount: Int
    let activityCount: Int
    let sleepMinutes: Int

    var activityTotal: Int {
        diaperCount + activityCount
    }
}

private struct RhythmPeriodMetrics {
    let scope: RhythmSummaryScope
    let start: Date
    let end: Date
    let dayCount: Int
    let activeDays: Int
    let feedingCount: Int
    let bottleML: Int
    let breastMinutes: Int
    let breastEquivalentML: Int
    let solidGrams: Int
    let equivalentMilkML: Int
    let diaperCount: Int
    let activityCount: Int
    let sleepMinutes: Int
    let daily: [RhythmDailyMetric]

    var feedingAverageText: String {
        guard equivalentMilkML > 0 || solidGrams > 0 else { return "--" }
        var text = "~\(AppMeasurementFormat.volume(Double(equivalentMilkML)))"
        if solidGrams > 0 {
            text += "+\(AppMeasurementFormat.mass(Double(solidGrams)))"
        }
        return text
    }

    var activityAverageText: String {
        let parts = [
            diaperCount > 0 ? "\(diaperCount)尿布" : nil,
            activityCount > 0 ? "\(activityCount)玩" : nil
        ].compactMap { $0 }
        return parts.isEmpty ? "--" : parts.joined(separator: "+")
    }

    var sleepAverageText: String {
        RhythmPeriodMetrics.shortSleepText(minutes: sleepMinutes)
    }

    var feedingDetailText: String {
        var parts: [String] = []
        if bottleML > 0 { parts.append("\(AppMeasurementFormat.volume(Double(bottleML)))奶") }
        if breastMinutes > 0 { parts.append("\(AppQuantityFormat.compactDuration(breastMinutes))亲喂（换算\(AppMeasurementFormat.volume(Double(breastEquivalentML)))）") }
        if solidGrams > 0 { parts.append("\(AppMeasurementFormat.mass(Double(solidGrams)))辅食") }
        return parts.isEmpty ? "暂无喂养记录" : parts.joined(separator: " + ")
    }

    var activeDayText: String {
        "\(activeDays)/\(dayCount)天"
    }

    static func shortSleepText(minutes: Int) -> String {
        if minutes <= 0 { return "--" }
        return AppQuantityFormat.compactDuration(minutes)
    }
}

private struct BabyTrendDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var feedingStore: FeedingStore
    @EnvironmentObject private var activityStore: ActivityStore
    @Environment(BabyProfileStore.self) private var profileStore
    @State private var selectedScope: RhythmSummaryScope = .week
    @State private var selectedWeekOffset: Int = 0
    @State private var selectedMonthOffset: Int = 0
    @State private var snapshot: BabyTrendDetailSnapshot?
    @State private var metricsCache: [RhythmMetricsCacheKey: RhythmPeriodMetrics] = [:]
    @State private var cachedMonthMetrics: RhythmPeriodMetrics?
    @State private var cachedYearMetrics: RhythmPeriodMetrics?
    @State private var selectedMetric: EasyCycleStep?
    @State private var presentedYearningDetail: YearningDetailContext?

    let metric: EasyCycleStep
    let referenceDate: Date
    let loadSnapshot: () -> BabyTrendDetailSnapshot

    var body: some View {
        NavigationStack {
            Group {
                if snapshot != nil {
                    detailContent
                } else {
                    detailLoadingView
                }
            }
            .background(DesignToken.background.ignoresSafeArea())
            .navigationTitle(displayedMetric.pageTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    AppPageCloseButton {
                        dismiss()
                    }
                }
            }
        }
        .sheet(item: $presentedYearningDetail) { _ in
            SubjectiveStateDetailView()
        }
        .task {
            await prepareDetail()
        }
    }

    private var detailContent: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 14) {
                BabyTrendSummaryCard(
                    profile: profileStore.currentProfile,
                    ageText: ageText,
                    summary: careSummary,
                    overview: overview,
                    babyState: recentBabyState,
                    onSelect: handleMetricSelection
                )
                .frame(height: 230)

                weeklyMetricCard
                periodSummaryCard(title: "本月".localized, metrics: monthMetrics)
                periodSummaryCard(title: "本年".localized, metrics: yearMetrics)
                dailyRecordCard
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
    }

    private var detailLoadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(displayedMetric.color)
            Text("正在整理\(displayedMetric.title.localized)数据…")
                .font(BBBFont.font(size: 13, weight: .semibold))
                .foregroundStyle(DesignToken.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func prepareDetail() async {
        guard snapshot == nil else { return }
        await Task.yield()
        guard !Task.isCancelled else { return }

        let loadedSnapshot = loadSnapshot()
        let week = metrics(for: .week, offset: 0)
        let previousWeek = metrics(for: .week, offset: 1)
        let month = makeMonthMetrics()
        let year = makeYearMetrics()

        guard !Task.isCancelled else { return }
        metricsCache = [
            RhythmMetricsCacheKey(scope: .week, offset: 0): week,
            RhythmMetricsCacheKey(scope: .week, offset: 1): previousWeek,
            RhythmMetricsCacheKey(scope: .month, offset: 0): month
        ]
        cachedMonthMetrics = month
        cachedYearMetrics = year
        snapshot = loadedSnapshot
    }

    private var loadedSnapshot: BabyTrendDetailSnapshot {
        guard let snapshot else {
            preconditionFailure("Baby trend detail content rendered before snapshot was ready")
        }
        return snapshot
    }

    private var displayedMetric: EasyCycleStep {
        selectedMetric ?? metric
    }

    private func handleMetricSelection(_ step: EasyCycleStep) {
        if step == .yearning {
            presentedYearningDetail = YearningDetailContext()
        } else if step != displayedMetric {
            selectedMetric = step
        }
    }

    private var ageText: String { loadedSnapshot.ageText }
    private var guidance: AgeRhythmGuidance { loadedSnapshot.guidance }
    private var overview: BabyTrendOverview { loadedSnapshot.overview }
    private var careSummary: BabyWeeklyCareSummary { loadedSnapshot.careSummary }
    private var recentBabyState: BabySubjectiveState? { loadedSnapshot.recentBabyState }

    private func makeMonthMetrics() -> RhythmPeriodMetrics {
        let calendar = Calendar.current
        let start = max(calendar.dateInterval(of: .month, for: referenceDate)?.start ?? referenceDate, birthStart)
        return metrics(from: start, through: calendar.startOfDay(for: referenceDate))
    }

    private func makeYearMetrics() -> RhythmPeriodMetrics {
        let calendar = Calendar.current
        let start = max(calendar.dateInterval(of: .year, for: referenceDate)?.start ?? referenceDate, birthStart)
        return metrics(from: start, through: calendar.startOfDay(for: referenceDate))
    }

    private var summaryScopeSwitcher: some View {
        HStack(spacing: 4) {
            ForEach(RhythmSummaryScope.allCases) { scope in
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        selectedScope = scope
                    }
                } label: {
                    Text(scope.title.localized)
                        .font(BBBFont.font(size: 12, weight: .heavy))
                        .foregroundStyle(selectedScope == scope ? DesignToken.textPrimary : DesignToken.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(selectedScope == scope ? DesignToken.surfaceRaised.opacity(0.58) : Color.clear)
                        )
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(DesignToken.textPrimary.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(DesignToken.glassStroke.opacity(0.55), lineWidth: 0.8)
                )
        )
    }

    private var periodNavigator: some View {
        HStack {
            Button {
                navigatePeriodBackward()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(canNavigatePeriodBackward ? DesignToken.textPrimary.opacity(0.74) : DesignToken.textSecondary.opacity(0.24))
                    .frame(width: 36, height: 34)
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(!canNavigatePeriodBackward)

            Spacer()

            Text(periodRangeTitle)
                .font(BBBFont.font(size: 15, weight: .heavy))
                .foregroundStyle(DesignToken.textPrimary)
                .monospacedDigit()

            Spacer()

            Button {
                navigatePeriodForward()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(canNavigatePeriodForward ? DesignToken.textPrimary.opacity(0.74) : DesignToken.textSecondary.opacity(0.24))
                    .frame(width: 36, height: 34)
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(!canNavigatePeriodForward)
        }
        .padding(.horizontal, 4)
    }

    private func comparisonAgeCard(current: RhythmPeriodMetrics, previous: RhythmPeriodMetrics) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(ageText)
                        .font(BBBFont.font(size: 24, weight: .heavy))
                        .foregroundStyle(DesignToken.onPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text(periodComparisonText(current: current, previous: previous))
                        .font(BBBFont.font(size: 12, weight: .semibold))
                        .foregroundStyle(DesignToken.onPrimary.opacity(0.90))
                        .lineSpacing(3)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Text(current.scope.shortTitle)
                    .font(BBBFont.font(size: 10, weight: .heavy))
                    .foregroundStyle(DesignToken.onPrimary.opacity(0.88))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(DesignToken.onPrimary.opacity(0.14)))
            }
            .frame(minHeight: 66, alignment: .top)

            Spacer(minLength: 8)

            HStack(spacing: 9) {
                summaryPurpleTile("E", "喂养", current.feedingAverageText, DesignToken.easyEat)
                summaryPurpleTile("A", "活动", current.activityAverageText, DesignToken.easyActivity)
                summaryPurpleTile("S", "睡眠", current.sleepAverageText, DesignToken.easySleep)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity)
        .frame(height: 162)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            DesignToken.primary,
                            DesignToken.primary.opacity(0.86),
                            DesignToken.accentBlue.opacity(0.82)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [DesignToken.onPrimary.opacity(0.18), .clear, DesignToken.onPrimary.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(DesignToken.glassStroke.opacity(0.34), lineWidth: 1.2)
                )
                .shadow(color: DesignToken.primary.opacity(0.20), radius: 22, y: 10)
        )
    }

    private func summaryPurpleTile(_ badge: String, _ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .center, spacing: 3) {
            HStack(spacing: 3) {
                Text(badge)
                    .font(BBBFont.font(size: 8, weight: .heavy))
                    .foregroundStyle(DesignToken.onPrimary)
                    .frame(width: 12, height: 12)
                    .background(Circle().fill(color.opacity(0.95)))

                Text(title.localized)
                    .font(BBBFont.font(size: 8.5, weight: .heavy))
                    .foregroundStyle(DesignToken.onPrimary.opacity(0.74))
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
            }
            .frame(maxWidth: .infinity)

            Text(value.localized)
                .font(BBBFont.font(size: 14, weight: .heavy))
                .foregroundStyle(DesignToken.onPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.54)
                .monospacedDigit()
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(DesignToken.onPrimary.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(DesignToken.onPrimary.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(color.opacity(0.30), lineWidth: 1)
                )
        )
    }

    private func rhythmBarCard(
        title: String,
        subtitle: String,
        value: String,
        color: Color,
        values: [Int],
        labels: [String],
        formatter: @escaping (Int) -> String
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title.localized)
                        .font(BBBFont.font(size: 20, weight: .heavy))
                        .foregroundStyle(DesignToken.textPrimary)
                    Text(subtitle.localized)
                        .font(BBBFont.font(size: 11, weight: .heavy))
                        .foregroundStyle(DesignToken.textSecondary)
                }

                Spacer()

                Text(value.localized)
                    .font(BBBFont.font(size: 18, weight: .heavy))
                    .foregroundStyle(color)
                    .monospacedDigit()
            }

            RhythmSingleMetricBarChart(color: color, values: values, labels: labels, formatter: formatter)
                .frame(height: 156)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(color.opacity(0.055))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(color.opacity(0.22), lineWidth: 1)
                )
                .shadow(color: color.opacity(0.08), radius: 16, y: 7)
        )
    }

    private var ageInsightCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(ageText)
                .font(BBBFont.font(size: 24, weight: .heavy))
                .foregroundStyle(DesignToken.textPrimary)
            Text(guidance.detailText)
                .font(BBBFont.font(size: 13, weight: .semibold))
                .foregroundStyle(DesignToken.textSecondary)
                .lineSpacing(4)
        }
        .padding(16)
        .background(detailCardBackground)
    }

    private var scopeSwitcher: some View {
        HStack(spacing: 4) {
            ForEach(RhythmSummaryScope.allCases) { scope in
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        selectedScope = scope
                    }
                } label: {
                    Text(scope.title.localized)
                        .font(BBBFont.font(size: 13, weight: .heavy))
                        .foregroundStyle(selectedScope == scope ? DesignToken.onPrimary : DesignToken.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(
                            Capsule()
                                .fill(selectedScope == scope ? DesignToken.primary : Color.clear)
                                .shadow(color: selectedScope == scope ? DesignToken.primary.opacity(0.20) : .clear, radius: 10, y: 5)
                        )
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(4)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(Capsule().fill(DesignToken.surfaceRaised.opacity(0.58)))
                .overlay(Capsule().stroke(DesignToken.glassStroke.opacity(0.76), lineWidth: 0.9))
        )
    }

    private func rhythmSummaryDashboard(metrics: RhythmPeriodMetrics) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(metrics.scope.shortTitle)
                        .font(BBBFont.font(size: 13, weight: .heavy))
                        .foregroundStyle(DesignToken.primary)
                    Text("\(compactDateText(metrics.start)) - \(compactDateText(metrics.end))")
                        .font(BBBFont.font(size: 11, weight: .bold))
                        .foregroundStyle(DesignToken.textSecondary)
                }

                Spacer()

                Text(metrics.activeDayText)
                    .font(BBBFont.font(size: 13, weight: .heavy))
                    .foregroundStyle(DesignToken.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(DesignToken.primary.opacity(0.10)))
            }

            HStack(spacing: 8) {
                summaryMetricTile("E", "喂养", metrics.feedingAverageText, DesignToken.easyEat)
                summaryMetricTile("A", "活动", metrics.activityAverageText, DesignToken.easyActivity)
                summaryMetricTile("S", "睡眠", metrics.sleepAverageText, DesignToken.easySleep)
            }
        }
        .padding(16)
        .background(detailCardBackground)
    }

    private func summaryMetricTile(_ badge: String, _ title: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 6) {
            Text(badge)
                .font(BBBFont.font(size: 10, weight: .heavy))
                .foregroundStyle(DesignToken.onPrimary)
                .frame(width: 22, height: 22)
                .background(Circle().fill(color))

            Text(title.localized)
                .font(BBBFont.font(size: 8.5, weight: .heavy))
                .foregroundStyle(DesignToken.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(value.localized)
                .font(BBBFont.font(size: 15, weight: .heavy))
                .foregroundStyle(DesignToken.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .frame(height: 82)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(color.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(color.opacity(0.18), lineWidth: 1)
                )
        )
    }

    private func easAverageCard(metrics: RhythmPeriodMetrics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("E·A·S 平均值")
                .font(BBBFont.font(size: 16, weight: .heavy))
                .foregroundStyle(DesignToken.textPrimary)

            easAverageRow(
                badge: "E",
                title: "喂养",
                value: metrics.feedingAverageText,
                detail: metrics.feedingDetailText,
                color: DesignToken.easyEat,
                progress: normalized(metrics.equivalentMilkML, max: 900)
            )
            easAverageRow(
                badge: "A",
                title: "活动",
                value: metrics.activityAverageText,
                detail: "尿布\(metrics.diaperCount)次 · 清醒互动\(metrics.activityCount)次",
                color: DesignToken.easyActivity,
                progress: normalized(metrics.diaperCount + metrics.activityCount, max: 10)
            )
            easAverageRow(
                badge: "S",
                title: "睡眠",
                value: metrics.sleepAverageText,
                detail: "平均睡眠 \(metrics.sleepAverageText)",
                color: DesignToken.easySleep,
                progress: normalized(metrics.sleepMinutes, max: 960)
            )
        }
        .padding(16)
        .background(detailCardBackground)
    }

    private func easAverageRow(
        badge: String,
        title: String,
        value: String,
        detail: String,
        color: Color,
        progress: CGFloat
    ) -> some View {
        HStack(spacing: 12) {
            Text(badge)
                .font(BBBFont.font(size: 13, weight: .heavy))
                .foregroundStyle(DesignToken.onPrimary)
                .frame(width: 34, height: 34)
                .background(Circle().fill(color))

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title.localized)
                        .font(BBBFont.font(size: 13, weight: .heavy))
                        .foregroundStyle(DesignToken.textPrimary)
                    Spacer()
                    Text(value.localized)
                        .font(BBBFont.font(size: 15, weight: .heavy))
                        .foregroundStyle(DesignToken.textPrimary)
                        .monospacedDigit()
                }

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(color.opacity(0.10))
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [color.opacity(0.78), color.opacity(0.38)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(proxy.size.width * progress, 6))
                    }
                }
                .frame(height: 8)

                Text(detail.localized)
                    .font(BBBFont.font(size: 11, weight: .semibold))
                    .foregroundStyle(DesignToken.textSecondary)
                    .lineLimit(2)
            }
        }
    }

    private func dailyTrendCard(metrics: RhythmPeriodMetrics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("每日趋势")
                    .font(BBBFont.font(size: 16, weight: .heavy))
                    .foregroundStyle(DesignToken.textPrimary)
                Spacer()
                Text("E / A / S / Y")
                    .font(BBBFont.font(size: 10, weight: .heavy))
                    .foregroundStyle(DesignToken.textSecondary.opacity(0.74))
            }

            RhythmSummaryTrendChart(metrics: metrics)
                .frame(height: selectedScope == .week ? 118 : 132)
        }
        .padding(16)
        .background(detailCardBackground)
    }

    private var detailCardBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(DesignToken.surfaceRaised.opacity(0.58))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(DesignToken.glassStroke.opacity(0.82), lineWidth: 1)
            )
    }

    private var selectedMetrics: RhythmPeriodMetrics {
        let key = RhythmMetricsCacheKey(scope: selectedScope, offset: currentPeriodOffset)
        return metricsCache[key] ?? metrics(for: selectedScope, offset: currentPeriodOffset)
    }

    private var previousMetrics: RhythmPeriodMetrics {
        let key = RhythmMetricsCacheKey(scope: selectedScope, offset: currentPeriodOffset + 1)
        return metricsCache[key] ?? metrics(for: selectedScope, offset: currentPeriodOffset + 1)
    }

    private var currentPeriodOffset: Int {
        switch selectedScope {
        case .week: return selectedWeekOffset
        case .month: return selectedMonthOffset
        }
    }

    private var periodRangeTitle: String {
        "\(compactDateText(selectedMetrics.start))-\(compactDateText(selectedMetrics.end))"
    }

    private var canNavigatePeriodBackward: Bool {
        switch selectedScope {
        case .week:
            return selectedMetrics.start > birthStart
        case .month:
            return selectedAgeMonthIndex(offset: selectedMonthOffset) > 0
        }
    }

    private var canNavigatePeriodForward: Bool {
        switch selectedScope {
        case .week:
            return selectedWeekOffset > 0
        case .month:
            return selectedMonthOffset > 0
        }
    }

    private func navigatePeriodBackward() {
        switch selectedScope {
        case .week:
            selectedWeekOffset += 1
        case .month:
            selectedMonthOffset += 1
        }
    }

    private func navigatePeriodForward() {
        switch selectedScope {
        case .week:
            selectedWeekOffset = max(selectedWeekOffset - 1, 0)
        case .month:
            selectedMonthOffset = max(selectedMonthOffset - 1, 0)
        }
    }

    private func selectedAgeMonthIndex(offset: Int) -> Int {
        let calendar = Calendar.current
        let referenceStart = calendar.startOfDay(for: referenceDate)
        let current = max(calendar.dateComponents([.month], from: birthStart, to: referenceStart).month ?? 0, 0)
        return max(current - offset, 0)
    }

    private func periodComparisonText(current: RhythmPeriodMetrics, previous: RhythmPeriodMetrics) -> String {
        guard previous.activeDays > 0 else {
            return "\(current.scope.shortTitle)数据正在积累，记录越完整，对比越稳定。"
        }

        let periodName = current.scope == .week ? "本周" : "本月龄"
        let previousName = current.scope == .week ? "上周" : "上个月龄"
        let feedingDelta = current.equivalentMilkML - previous.equivalentMilkML
        let feeding = feedingDelta == 0
            ? "持平"
            : "\(feedingDelta > 0 ? "+" : "-")\(AppMeasurementFormat.volume(Double(abs(feedingDelta))))"
        let activity = deltaText(current.diaperCount + current.activityCount - previous.diaperCount - previous.activityCount, unit: "次")
        let sleep = deltaSleepText(current.sleepMinutes - previous.sleepMinutes)
        return "\(periodName)对比\(previousName)：喂养\(feeding)，活动\(activity)，睡眠\(sleep)。"
    }

    private func deltaText(_ value: Int, unit: String) -> String {
        if value == 0 { return "持平" }
        return value > 0 ? "+\(value)\(unit)" : "\(value)\(unit)"
    }

    private func deltaSleepText(_ minutes: Int) -> String {
        if minutes == 0 { return "持平" }
        let prefix = minutes > 0 ? "+" : "-"
        return "\(prefix)\(RhythmPeriodMetrics.shortSleepText(minutes: abs(minutes)))"
    }

    private func metrics(for scope: RhythmSummaryScope, offset: Int) -> RhythmPeriodMetrics {
        let calendar = Calendar.current
        let referenceStart = calendar.startOfDay(for: referenceDate)
        let start: Date
        let end: Date

        switch scope {
        case .week:
            let periodEnd = calendar.date(byAdding: .day, value: -(offset * 7), to: referenceStart) ?? referenceStart
            end = max(periodEnd, birthStart)
            let proposedStart = calendar.date(byAdding: .day, value: -6, to: end) ?? end
            start = max(proposedStart, birthStart)
        case .month:
            let ageMonthIndex = selectedAgeMonthIndex(offset: offset)
            start = calendar.date(byAdding: .month, value: ageMonthIndex, to: birthStart) ?? birthStart
            let monthEndExclusive = calendar.date(byAdding: .month, value: ageMonthIndex + 1, to: birthStart) ?? referenceStart
            let naturalEnd = calendar.date(byAdding: .day, value: -1, to: monthEndExclusive) ?? referenceStart
            end = min(naturalEnd, referenceStart)
        }

        var days: [Date] = []
        var cursor = start
        while cursor <= end {
            days.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        let dayCount = max(days.count, 1)

        var activeDays = 0
        var feedingCount = 0
        var bottleTotal = 0
        var breastTotal = 0
        var solidTotal = 0.0
        var diaperTotal = 0
        var activityTotal = 0
        var sleepTotal = 0
        var daily: [RhythmDailyMetric] = []
        let allCareRecords = activityStore.careRecords

        for day in days {
            let sessions = feedingStore.sessions(on: day)
            // Point records belong to their recorded day. Sleep duration is
            // different: it is clipped to this 0-24h calendar day so a
            // cross-midnight record contributes to each day only once.
            let careRecords = activityStore.careRecords(on: day)
            let bottle = sessions.reduce(0) { $0 + $1.totalBottleAmount }
            let breast = sessions.reduce(0) { $0 + $1.totalBreastDuration }
            let solid = sessions.reduce(0.0) { $0 + $1.totalSolidAmount }
            let diaper = careRecords.filter { $0.kind == .diaper }.count
            let activity = careRecords.filter { $0.kind == .activity }.count
            let sleep = calendarDaySleepMinutes(on: day, records: allCareRecords)
            let equivalent = bottle + Int(round(Double(breast) * breastEquivalentRateForSummary))

            if !sessions.isEmpty || !careRecords.isEmpty || sleep > 0 {
                activeDays += 1
            }
            feedingCount += sessions.count
            bottleTotal += bottle
            breastTotal += breast
            solidTotal += solid
            diaperTotal += diaper
            activityTotal += activity
            sleepTotal += sleep
            daily.append(
                RhythmDailyMetric(
                    date: day,
                    feedingML: equivalent,
                    diaperCount: diaper,
                    activityCount: activity,
                    sleepMinutes: sleep
                )
            )
        }

        let averageBottle = roundedAverage(bottleTotal, days: dayCount, step: 10)
        let averageBreast = roundedAverage(breastTotal, days: dayCount, step: 5)
        let averageSolid = roundedAverage(solidTotal, days: dayCount, step: 1)
        let breastEquivalent = Int(round(Double(averageBreast) * breastEquivalentRateForSummary))
        let equivalentMilk = averageBottle + breastEquivalent
        let averageDiaper = roundedAverage(diaperTotal, days: dayCount, step: 1)
        let averageActivity = roundedAverage(activityTotal, days: dayCount, step: 1)
        let averageSleep = roundedAverage(sleepTotal, days: dayCount, step: 15)

        return RhythmPeriodMetrics(
            scope: scope,
            start: start,
            end: end,
            dayCount: dayCount,
            activeDays: activeDays,
            feedingCount: feedingCount,
            bottleML: averageBottle,
            breastMinutes: averageBreast,
            breastEquivalentML: breastEquivalent,
            solidGrams: averageSolid,
            equivalentMilkML: equivalentMilk,
            diaperCount: averageDiaper,
            activityCount: averageActivity,
            sleepMinutes: averageSleep,
            daily: daily
        )
    }

    private var birthStart: Date {
        Calendar.current.startOfDay(for: profileStore.currentProfile.birthDate)
    }

    private var breastEquivalentRateForSummary: Double {
        let month = max(Calendar.current.dateComponents([.month], from: birthStart, to: referenceDate).month ?? 0, 0)
        switch month {
        case 1...4:
            return 5.2
        case 5...12:
            return 5.8
        default:
            return 5.5
        }
    }

    private func roundedAverage(_ total: Int, days: Int, step: Int) -> Int {
        guard total > 0, days > 0 else { return 0 }
        let raw = Double(total) / Double(days)
        return Int((raw / Double(step)).rounded()) * step
    }

    private func roundedAverage(_ total: Double, days: Int, step: Int) -> Int {
        guard total > 0, days > 0 else { return 0 }
        let raw = total / Double(days)
        return Int((raw / Double(step)).rounded()) * step
    }

    private func normalized(_ value: Int, max maxValue: Int) -> CGFloat {
        guard maxValue > 0 else { return 0 }
        return CGFloat(Swift.max(0.08, Swift.min(Double(value) / Double(maxValue), 1.0)))
    }

    private func compactDateText(_ date: Date) -> String {
        AppDateTimeFormat.date(date)
    }

    private func trendDetailRow(_ row: BabyTrendDetailRow) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(row.title.localized)
                .font(BBBFont.font(size: 13, weight: .heavy))
                .foregroundStyle(DesignToken.onPrimary)
                .frame(width: 30, height: 30)
                .background(Circle().fill(row.color.opacity(0.92)))

            VStack(alignment: .leading, spacing: 4) {
                Text(row.summary)
                    .font(BBBFont.font(size: 14, weight: .heavy))
                    .foregroundStyle(DesignToken.textPrimary)
                Text(row.detail.localized)
                    .font(BBBFont.font(size: 12, weight: .semibold))
                    .foregroundStyle(DesignToken.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
    }
}

private extension BabyTrendDetailSheet {
    var weeklyMetricCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Text("\(displayedMetric.weekTitle)  \(headlineValue)")
                    .font(BBBFont.font(size: 20, weight: .heavy))
                    .foregroundStyle(DesignToken.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                    .layoutPriority(1)
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 5) {
                    Text(comparisonText).foregroundStyle(displayedMetric.color)
                    Text("\("日均".localized) \(averageText)")
                    Text("\("峰值".localized) \(peakText)")
                }
                .font(BBBFont.font(size: 11, weight: .heavy))
                .foregroundStyle(DesignToken.textSecondary)
                .monospacedDigit()
                .lineLimit(1)
            }

            RhythmSingleMetricBarChart(
                color: displayedMetric.color,
                values: currentValues,
                previousValues: previousValues,
                labels: selectedMetrics.daily.map { compactDateText($0.date) },
                formatter: metricValueText
            )
            .frame(height: 176)
        }
        .padding(16)
        .background(metricCardBackground)
    }

    func periodSummaryCard(title: String, metrics: RhythmPeriodMetrics) -> some View {
        let values = values(in: metrics)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(BBBFont.font(size: 16, weight: .heavy))
                        .foregroundStyle(DesignToken.textPrimary)
                    Text("\(compactDateText(metrics.start))–\(compactDateText(metrics.end))")
                        .font(BBBFont.font(size: 10, weight: .bold))
                        .foregroundStyle(DesignToken.textSecondary)
                        .monospacedDigit()
                }
                Spacer(minLength: 0)
                summaryStat(label: "日均".localized, value: averageText(for: values))
                summaryStat(label: "峰值".localized, value: metricValueText(values.max() ?? 0))
                summaryStat(label: "记录".localized, value: "\(values.filter { $0 > 0 }.count)\("天".localized)")
            }

            RhythmSingleMetricBarChart(
                color: displayedMetric.color,
                values: values,
                labels: metrics.daily.map { compactDateText($0.date) },
                formatter: metricValueText
            )
            .frame(height: 148)
        }
        .padding(16)
        .background(metricCardBackground)
    }

    func summaryStat(label: String, value: String) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(label)
                .font(BBBFont.font(size: 9, weight: .bold))
                .foregroundStyle(DesignToken.textSecondary)
            Text(value)
                .font(BBBFont.font(size: 12, weight: .heavy))
                .foregroundStyle(DesignToken.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
                .monospacedDigit()
        }
    }

    var dailyRecordCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(selectedMetrics.daily.reversed())) { item in
                HStack(spacing: 12) {
                    Text(compactDateText(item.date))
                        .font(BBBFont.font(size: 12, weight: .heavy))
                        .foregroundStyle(DesignToken.textSecondary)
                        .frame(width: 76, alignment: .leading)
                    Circle()
                        .fill(displayedMetric.color.opacity(0.16))
                        .frame(width: 28, height: 28)
                        .overlay {
                            Text(displayedMetric.letter)
                                .font(BBBFont.font(size: 10, weight: .heavy))
                                .foregroundStyle(displayedMetric.color)
                        }
                    Text(metricValueText(value(in: item)))
                        .font(BBBFont.font(size: 14, weight: .heavy))
                        .foregroundStyle(DesignToken.textPrimary)
                        .monospacedDigit()
                    Spacer(minLength: 0)
                    Text(recordCountText(on: item.date))
                        .font(BBBFont.font(size: 10, weight: .bold))
                        .foregroundStyle(DesignToken.textSecondary)
                }
                .frame(minHeight: 52)
                .overlay(alignment: .bottom) { Divider().opacity(0.34) }
            }
        }
        .padding(.horizontal, 16)
        .background(metricCardBackground)
    }

    var metricCardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(displayedMetric.color.opacity(0.05)))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(displayedMetric.color.opacity(0.20), lineWidth: 1))
    }

    var currentValues: [Int] { values(in: selectedMetrics) }
    var previousValues: [Int] { values(in: previousMetrics) }

    func values(in metrics: RhythmPeriodMetrics) -> [Int] { metrics.daily.map(value(in:)) }

    func value(in item: RhythmDailyMetric) -> Int {
        switch displayedMetric {
        case .eat: return item.feedingML
        case .activity: return item.activityTotal
        case .sleep: return item.sleepMinutes
        case .yearning: return 0
        }
    }

    var headlineValue: String {
        switch displayedMetric {
        case .eat: return overview.feedingText
        case .activity: return overview.activityText
        case .sleep: return overview.sleepText
        case .yearning: return "--"
        }
    }

    var averageText: String { averageText(for: currentValues) }

    func averageText(for values: [Int]) -> String {
        guard values.contains(where: { $0 > 0 }) else { return "--" }
        return metricValueText(Int((Double(values.reduce(0, +)) / Double(max(values.count, 1))).rounded()))
    }

    var peakText: String { metricValueText(currentValues.max() ?? 0) }

    var comparisonText: String {
        let current = averageValue(currentValues)
        let previous = averageValue(previousValues)
        let comparisonTitle = selectedMetrics.scope == .week ? "较前7天" : "较上个月龄"
        guard let current, let previous, previous > 0 else {
            return "\(comparisonTitle.localized) --"
        }
        let percentage = Int(((current - previous) / previous * 100).rounded())
        return "\(comparisonTitle.localized) \(percentage >= 0 ? "+" : "")\(percentage)%"
    }

    private func averageValue(_ values: [Int]) -> Double? {
        guard !values.isEmpty else { return nil }
        return Double(values.reduce(0, +)) / Double(values.count)
    }

    func metricValueText(_ value: Int) -> String {
        guard value > 0 else { return "--" }
        switch displayedMetric {
        case .eat: return AppMeasurementFormat.volume(Double(value))
        case .activity: return "\(value)\("次".localized)"
        case .sleep: return RhythmPeriodMetrics.shortSleepText(minutes: value)
        case .yearning: return "--"
        }
    }

    func recordCountText(on date: Date) -> String {
        let count: Int
        switch displayedMetric {
        case .eat:
            count = feedingStore.sessions(on: date).count
        case .activity:
            count = activityStore.careRecordsForSleepSummary(on: date).filter { $0.kind == .diaper || $0.kind == .activity }.count
        case .sleep:
            count = activityStore.careRecordsForSleepSummary(on: date).filter { $0.kind == .sleep }.count
        case .yearning:
            count = 0
        }
        return count > 0 ? "\(count)\("次".localized)" : "--"
    }

    var monthMetrics: RhythmPeriodMetrics {
        cachedMonthMetrics ?? makeMonthMetrics()
    }

    var yearMetrics: RhythmPeriodMetrics {
        cachedYearMetrics ?? makeYearMetrics()
    }

    func metrics(from start: Date, through end: Date) -> RhythmPeriodMetrics {
        let calendar = Calendar.current
        var days: [Date] = []
        var cursor = calendar.startOfDay(for: start)
        let finalDay = calendar.startOfDay(for: end)
        while cursor <= finalDay {
            days.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        let allCareRecords = activityStore.careRecords
        let daily = days.map { day -> RhythmDailyMetric in
            let sessions = feedingStore.sessions(on: day)
            // Keep point records on their recorded day, while clipping sleep
            // durations to this calendar day for a true 0-24h daily average.
            let records = activityStore.careRecords(on: day)
            let feeding = sessions.reduce(0) { partial, session in
                partial + session.totalBottleAmount + Int(round(Double(session.totalBreastDuration) * breastEquivalentRateForSummary))
            }
            return RhythmDailyMetric(
                date: day,
                feedingML: feeding,
                diaperCount: records.filter { $0.kind == .diaper }.count,
                activityCount: records.filter { $0.kind == .activity }.count,
                sleepMinutes: calendarDaySleepMinutes(on: day, records: allCareRecords)
            )
        }
        let dayCount = max(daily.count, 1)
        let activeDays = daily.filter { $0.feedingML > 0 || $0.activityTotal > 0 || $0.sleepMinutes > 0 }.count
        let feedingAverage = Int((Double(daily.map(\.feedingML).reduce(0, +)) / Double(dayCount)).rounded())
        let diaperAverage = Int((Double(daily.map(\.diaperCount).reduce(0, +)) / Double(dayCount)).rounded())
        let activityAverage = Int((Double(daily.map(\.activityCount).reduce(0, +)) / Double(dayCount)).rounded())
        let sleepAverage = Int((Double(daily.map(\.sleepMinutes).reduce(0, +)) / Double(dayCount)).rounded())
        return RhythmPeriodMetrics(
            scope: .month, start: start, end: end, dayCount: dayCount, activeDays: activeDays,
            feedingCount: 0, bottleML: feedingAverage, breastMinutes: 0, breastEquivalentML: 0,
            solidGrams: 0, equivalentMilkML: feedingAverage, diaperCount: diaperAverage,
            activityCount: activityAverage, sleepMinutes: sleepAverage, daily: daily
        )
    }
}

private struct RhythmSingleMetricBarChart: View {
    let color: Color
    let values: [Int]
    var previousValues: [Int] = []
    let labels: [String]
    let formatter: (Int) -> String
    @State private var selectedIndex: Int?

    private var maxValue: Int {
        max(max(values.max() ?? 0, previousValues.max() ?? 0), 1)
    }

    private var selectedIndexForDisplay: Int? {
        guard !values.isEmpty else { return nil }
        let index = selectedIndex ?? values.count - 1
        return min(max(index, 0), values.count - 1)
    }

    private var minimumSlotWidth: CGFloat {
        switch values.count {
        case 0...12:
            return 44
        case 13...90:
            return 10
        default:
            return 8
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let viewportWidth = max(proxy.size.width, 1)
            let chartHeight = max(proxy.size.height, 1)
            let contentWidth = max(viewportWidth, minimumSlotWidth * CGFloat(max(values.count, 1)))

            ScrollView(.horizontal, showsIndicators: false) {
                chartContent(width: contentWidth, height: chartHeight)
                    .frame(width: contentWidth, height: chartHeight)
            }
            .defaultScrollAnchor(.trailing)
            .accessibilityLabel("每日柱状图")
            .accessibilityHint("点按或滑动查看每日数据")
            .accessibilityValue(selectedAccessibilityValue)
        }
    }

    private func chartContent(width: CGFloat, height: CGFloat) -> some View {
        let count = max(values.count, 1)
        let labelHeight: CGFloat = values.count > 12 ? 26 : 22
        let plotHeight = max(height - labelHeight, 1)
        let slotWidth = width / CGFloat(count)
        let maximumBarWidth: CGFloat = values.count > 90 ? 6 : (values.count > 12 ? 10 : 34)
        let barWidth = max(2, min(maximumBarWidth, slotWidth * 0.68))
        let selected = selectedIndexForDisplay

        return VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(color.opacity(0.045))
                    .frame(width: width, height: plotHeight)

                HStack(spacing: 0) {
                    ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                        let isSelected = index == selected

                        ZStack(alignment: .bottom) {
                            Capsule()
                                .fill(color.opacity(0.12))
                                .frame(width: barWidth, height: plotHeight)

                            if value > 0 {
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: isSelected
                                                ? [color.opacity(0.98), color.opacity(0.78)]
                                                : [color.opacity(0.46), color.opacity(0.25)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .frame(width: barWidth, height: barHeight(value, maxHeight: plotHeight))
                                    .shadow(color: isSelected ? color.opacity(0.24) : .clear, radius: 9, y: 4)
                            }

                            if isSelected {
                                Capsule()
                                    .stroke(color.opacity(0.92), lineWidth: 1)
                                    .frame(width: barWidth + 5, height: plotHeight)
                            }
                        }
                        .frame(width: slotWidth, height: plotHeight, alignment: .bottom)
                    }
                }
                .frame(width: width, height: plotHeight, alignment: .bottom)

                if previousValues.count == values.count, previousValues.count > 1 {
                    previousValueLine(width: width, plotHeight: plotHeight)
                        .accessibilityHidden(true)
                }

                if let selected, values.indices.contains(selected) {
                    selectionBubble(
                        index: selected,
                        x: xPosition(index: selected, count: count, width: width),
                        width: width
                    )
                }
            }
            .frame(width: width, height: plotHeight)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        updateSelection(at: gesture.location.x, width: width)
                    }
            )

            labelStrip(width: width, height: labelHeight, slotWidth: slotWidth, count: count)
        }
        .frame(width: width, height: height, alignment: .bottom)
    }

    private func labelStrip(width: CGFloat, height: CGFloat, slotWidth: CGFloat, count: Int) -> some View {
        let labelWidth = count > 12 ? 70 : slotWidth
        let selected = selectedIndexForDisplay

        return ZStack(alignment: .topLeading) {
            ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                if labelVisible(index: index, count: count, selectedIndex: selected) {
                    Text(label)
                        .font(BBBFont.font(size: count > 12 ? 8 : 9, weight: index == selected ? .heavy : .bold))
                        .foregroundStyle(index == selected ? DesignToken.textPrimary : DesignToken.textSecondary.opacity(0.70))
                        .lineLimit(1)
                        .minimumScaleFactor(0.62)
                        .frame(width: labelWidth, height: height)
                        .position(
                            x: labelX(index: index, count: count, width: width, labelWidth: labelWidth),
                            y: height / 2
                        )
                }
            }
        }
        .frame(width: width, height: height)
    }

    private func selectionBubble(index: Int, x: CGFloat, width: CGFloat) -> some View {
        let label = labels.indices.contains(index) ? labels[index] : ""
        let horizontalInset: CGFloat = 68
        let clampedX = min(max(x, horizontalInset), max(horizontalInset, width - horizontalInset))

        return HStack(spacing: 6) {
            Text(label)
            Text(formatter(values[index]))
                .fontWeight(.heavy)
        }
        .font(BBBFont.font(size: 9, weight: .semibold))
        .foregroundStyle(DesignToken.onPrimary)
        .lineLimit(1)
        .minimumScaleFactor(0.72)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Capsule().fill(DesignToken.textPrimary.opacity(0.88)))
        .position(x: clampedX, y: 16)
    }

    private func previousValueLine(width: CGFloat, plotHeight: CGFloat) -> some View {
        Path { path in
            for (index, value) in previousValues.enumerated() {
                let x = xPosition(index: index, count: previousValues.count, width: width)
                let ratio = min(max(CGFloat(value) / CGFloat(maxValue), 0), 1)
                let y = plotHeight * (1 - ratio)
                if index == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
        }
        .stroke(
            DesignToken.textSecondary.opacity(0.48),
            style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round, dash: [5, 5])
        )
    }

    private func barHeight(_ value: Int, maxHeight: CGFloat) -> CGFloat {
        guard value > 0 else { return 0 }
        let ratio = min(max(CGFloat(value) / CGFloat(maxValue), 0), 1)
        return max(maxHeight * 0.10, min(maxHeight, maxHeight * ratio))
    }

    private func labelVisible(index: Int, count: Int, selectedIndex: Int?) -> Bool {
        if count <= 12 { return true }
        if index == 0 || index == count - 1 || index == selectedIndex { return true }
        return count <= 90 && index.isMultiple(of: 7)
    }

    private func xPosition(index: Int, count: Int, width: CGFloat) -> CGFloat {
        width * (CGFloat(index) + 0.5) / CGFloat(max(count, 1))
    }

    private func labelX(index: Int, count: Int, width: CGFloat, labelWidth: CGFloat) -> CGFloat {
        let x = xPosition(index: index, count: count, width: width)
        return min(max(x, labelWidth / 2), max(labelWidth / 2, width - labelWidth / 2))
    }

    private func updateSelection(at x: CGFloat, width: CGFloat) {
        guard !values.isEmpty else { return }
        let normalized = min(max(x / max(width, 1), 0), 1)
        let index = min(max(Int(normalized * CGFloat(values.count)), 0), values.count - 1)
        if selectedIndex != index {
            selectedIndex = index
        }
    }

    private var selectedAccessibilityValue: String {
        guard let selected = selectedIndexForDisplay,
              labels.indices.contains(selected),
              values.indices.contains(selected) else {
            return ""
        }
        return "\(labels[selected]) \(formatter(values[selected]))"
    }
}

private struct RhythmSummaryTrendChart: View {
    let metrics: RhythmPeriodMetrics

    private var maxFeeding: Int {
        max(metrics.daily.map(\.feedingML).max() ?? 0, 1)
    }

    private var maxActivity: Int {
        max(metrics.daily.map { $0.diaperCount + $0.activityCount }.max() ?? 0, 1)
    }

    private var maxSleep: Int {
        max(metrics.daily.map(\.sleepMinutes).max() ?? 0, 1)
    }

    var body: some View {
        GeometryReader { proxy in
            let availableWidth = max(proxy.size.width, 1)
            let count = max(metrics.daily.count, 1)
            let spacing: CGFloat = metrics.scope == .week ? 8 : 3
            let columnWidth = max((availableWidth - spacing * CGFloat(count - 1)) / CGFloat(count), metrics.scope == .week ? 22 : 6)

            HStack(alignment: .bottom, spacing: spacing) {
                ForEach(metrics.daily) { item in
                    VStack(spacing: 4) {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [DesignToken.easySleep.opacity(0.92), DesignToken.easySleep.opacity(0.52)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: min(columnWidth, 18), height: scaledHeight(item.sleepMinutes, maxValue: maxSleep, minimum: 8, maximum: 42))

                        Capsule()
                            .fill(DesignToken.easyEat.opacity(0.88))
                            .frame(width: min(columnWidth, 14), height: scaledHeight(item.feedingML, maxValue: maxFeeding, minimum: item.feedingML > 0 ? 6 : 0, maximum: 26))

                        Capsule()
                            .fill(DesignToken.easyActivity.opacity(0.82))
                            .frame(width: min(columnWidth, 12), height: scaledHeight(item.diaperCount + item.activityCount, maxValue: maxActivity, minimum: item.diaperCount + item.activityCount > 0 ? 5 : 0, maximum: 22))
                    }
                    .frame(width: columnWidth, height: proxy.size.height - 18, alignment: .bottom)
                    .overlay(alignment: .bottom) {
                        Text(dayLabel(item.date))
                            .font(BBBFont.font(size: metrics.scope == .week ? 8 : 0, weight: .heavy))
                            .foregroundStyle(DesignToken.textSecondary.opacity(metrics.scope == .week ? 0.66 : 0))
                            .offset(y: 16)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(DesignToken.textSecondary.opacity(0.10))
                    .frame(height: 1)
                    .offset(y: -15)
            }
        }
    }

    private func scaledHeight(_ value: Int, maxValue: Int, minimum: CGFloat, maximum: CGFloat) -> CGFloat {
        guard value > 0, maxValue > 0 else { return 0 }
        let ratio = CGFloat(value) / CGFloat(maxValue)
        return max(minimum, min(maximum, maximum * ratio))
    }

    private func dayLabel(_ date: Date) -> String {
        AppDateTimeFormat.date(date)
    }
}


enum RhythmTimelineKind: Hashable {
    case sleep
    case bottle
    case breast
    case solid
    case diaper
    case activity

    var color: Color {
        switch self {
        case .sleep:
            return DesignToken.easySleep
        case .bottle, .breast, .solid:
            return DesignToken.easyEat
        case .diaper:
            return DesignToken.activityDiaper
        case .activity:
            return DesignToken.easyActivity
        }
    }

    var lane: Int {
        switch self {
        case .sleep:
            return 0
        case .bottle, .breast, .solid:
            return 1
        case .diaper, .activity:
            return 2
        }
    }
}

struct RhythmTimelineSpan: Identifiable {
    let startAt: Date
    let endAt: Date
    let kinds: [RhythmTimelineKind]
    let isEstimated: Bool
    let isPoint: Bool

    var id: String {
        let kindKey = kinds.map { String(describing: $0) }.joined(separator: "-")
        return "\(startAt.timeIntervalSinceReferenceDate)-\(endAt.timeIntervalSinceReferenceDate)-\(kindKey)-\(isEstimated)-\(isPoint)"
    }

    var lane: Int {
        kinds.first?.lane ?? 1
    }

    var colors: [Color] {
        kinds.map(\.color)
    }

    var isSleep: Bool {
        kinds.contains(.sleep)
    }

    var isDiaper: Bool {
        kinds.contains(.diaper)
    }

    var isActivity: Bool {
        kinds.contains(.activity)
    }

    var isFeeding: Bool {
        kinds.contains(.bottle) || kinds.contains(.breast) || kinds.contains(.solid)
    }
}

private enum RhythmSpanTimelineStyle {
    case layered
    case thinRail
}

private enum TodayRhythmMinimalStage: Hashable, CaseIterable {
    case eat
    case activity
    case sleep

    var badgeTitle: String {
        switch self {
        case .eat: return "E"
        case .activity: return "A"
        case .sleep: return "S"
        }
    }

    var color: Color {
        switch self {
        case .eat: return DesignToken.easyEat
        case .activity: return DesignToken.easyActivity
        case .sleep: return DesignToken.easySleep
        }
    }

    var softColor: Color {
        switch self {
        case .eat: return DesignToken.easyEatSoft
        case .activity: return DesignToken.easyActivitySoft
        case .sleep: return DesignToken.easySleepSoft
        }
    }

    var canvasGradient: Gradient {
        switch self {
        case .eat:
            return Gradient(colors: [DesignToken.easyEat.opacity(0.62), DesignToken.easyEat, DesignToken.easyEat.opacity(0.82)])
        case .activity:
            return Gradient(colors: [DesignToken.easyActivity.opacity(0.62), DesignToken.easyActivity, DesignToken.easyActivity.opacity(0.82)])
        case .sleep:
            return Gradient(colors: [DesignToken.easySleep.opacity(0.62), DesignToken.easySleep, DesignToken.easySleep.opacity(0.82)])
        }
    }

    static var diaperCanvasGradient: Gradient {
        Gradient(colors: [DesignToken.activityDiaper.opacity(0.62), DesignToken.activityDiaper, DesignToken.activityDiaper.opacity(0.82)])
    }

    static var connectorColor: Color {
        DesignToken.textMuted.opacity(0.36)
    }

    var drawOrder: Int {
        switch self {
        case .eat: return 0
        case .activity: return 1
        case .sleep: return 2
        }
    }

    var nextStage: TodayRhythmMinimalStage? {
        switch self {
        case .eat: return .activity
        case .activity: return .sleep
        case .sleep: return nil
        }
    }

    func centerY(in height: CGFloat) -> CGFloat {
        switch self {
        case .eat: return max(height * 0.22, 9)
        case .activity: return height * 0.50
        case .sleep: return min(height * 0.78, height - 9)
        }
    }
}

struct TodayRhythmMinimalTimeline: View {
    let date: Date
    let spans: [RhythmTimelineSpan]
    var height: CGFloat
    var showsTimeScale: Bool = true
    var showsLaneLabels: Bool = true

    private let laneLabelWidth: CGFloat = 16
    private let laneSpacing: CGFloat = 12

    private struct RenderMark {
        let id: String
        let stage: TodayRhythmMinimalStage
        let startAt: Date
        let endAt: Date
        let centerX: CGFloat
        let width: CGFloat
        let trackHeight: CGFloat
        let usesDiaperAccent: Bool
        let isEstimated: Bool

        var centerY: CGFloat {
            stage.centerY(in: trackHeight)
        }

        var rect: CGRect {
            CGRect(
                x: centerX - width / 2,
                y: centerY - markHeight / 2,
                width: width,
                height: markHeight
            )
        }

        var markHeight: CGFloat {
            switch stage {
            case .eat: return 10
            case .activity: return 10
            case .sleep: return 11
            }
        }

        var accentColor: Color {
            usesDiaperAccent ? DesignToken.activityDiaper : stage.color
        }

        var fillGradient: Gradient {
            usesDiaperAccent ? TodayRhythmMinimalStage.diaperCanvasGradient : stage.canvasGradient
        }
    }

    var body: some View {
        let trackHeight = max(height - (showsTimeScale ? 16 : 0), 42)

        VStack(spacing: showsTimeScale ? 3 : 0) {
            HStack(spacing: showsLaneLabels ? laneSpacing : 0) {
                if showsLaneLabels {
                    laneLabels(trackHeight: trackHeight)
                        .frame(width: laneLabelWidth, height: trackHeight)
                }

                chartCanvas(trackHeight: trackHeight)
            }
            .frame(height: trackHeight)

            if showsTimeScale {
                HStack(spacing: laneSpacing) {
                    Color.clear
                        .frame(width: laneLabelWidth)
                        .accessibilityHidden(true)

                    timeScaleLabels
                }
                .frame(height: 10)
            }
        }
        .frame(height: height)
    }

    private func laneLabels(trackHeight: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(TodayRhythmMinimalStage.allCases, id: \.self) { stage in
                Text(stage.badgeTitle)
                    .font(BBBFont.font(size: 6.5, weight: .heavy))
                    .foregroundStyle(stage.color)
                    .frame(width: 12, height: 12)
                    .background(Circle().fill(stage.color.opacity(0.16)))
                    .overlay {
                        Circle()
                            .stroke(stage.color.opacity(0.84), lineWidth: 0.9)
                    }
                    .position(x: laneLabelWidth / 2, y: stage.centerY(in: trackHeight))
            }
        }
    }

    private func chartCanvas(trackHeight: CGFloat) -> some View {
        Canvas { context, size in
            let bounds = CGRect(origin: .zero, size: size)
            let marks = renderMarks(in: bounds, trackHeight: trackHeight)
            drawLaneTracks(in: bounds, trackHeight: trackHeight, context: &context)
            drawHourTicks(in: bounds, context: &context)
            drawCurrentTimeIndicator(in: bounds, context: &context)
            drawStageConnections(marks: marks, context: &context)
            drawMarks(marks: marks, context: &context)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("当日 EASY 时间线")
    }

    private func drawLaneTracks(in bounds: CGRect, trackHeight: CGFloat, context: inout GraphicsContext) {
        for stage in TodayRhythmMinimalStage.allCases {
            let y = stage.centerY(in: trackHeight)
            let rect = CGRect(x: bounds.minX, y: y - 0.5, width: bounds.width, height: 1)
            context.fill(
                Path(roundedRect: rect, cornerRadius: 0.5),
                with: .color(DesignToken.borderSubtle.opacity(0.56))
            )
        }
    }

    private func drawStageConnections(marks: [RenderMark], context: inout GraphicsContext) {
        let orderedMarks = marks.sorted {
            if $0.startAt == $1.startAt {
                return $0.stage.drawOrder < $1.stage.drawOrder
            }
            return $0.startAt < $1.startAt
        }
        guard orderedMarks.count > 1 else { return }

        var previous = orderedMarks[0]
        for mark in orderedMarks.dropFirst() {
            guard previous.stage != mark.stage else {
                previous = mark
                continue
            }

            let interval = mark.startAt.timeIntervalSince(previous.endAt)
            guard previous.stage.nextStage == mark.stage,
                  interval >= -5 * 60,
                  interval <= 6 * 60 * 60 else {
                previous = mark
                continue
            }

            let connection = stageConnection(from: previous, to: mark)
            context.stroke(
                connection.path,
                with: .color(TodayRhythmMinimalStage.connectorColor),
                lineWidth: 0.95
            )
            previous = mark
        }
    }

    private func stageConnection(from previous: RenderMark, to mark: RenderMark) -> (path: Path, start: CGPoint, end: CGPoint) {
        let centerX = (previous.rect.midX + mark.rect.midX) / 2
        let movingDown = mark.rect.midY >= previous.rect.midY
        let centersAreClose = abs(mark.rect.midX - previous.rect.midX) < 8
        let rectsOverlapHorizontally = previous.rect.maxX >= mark.rect.minX - 2 && mark.rect.maxX >= previous.rect.minX - 2
        let useVerticalAnchor = centersAreClose || rectsOverlapHorizontally
        let start: CGPoint
        let end: CGPoint

        if useVerticalAnchor {
            start = CGPoint(x: centerX, y: movingDown ? previous.rect.maxY : previous.rect.minY)
            end = CGPoint(x: centerX, y: movingDown ? mark.rect.minY : mark.rect.maxY)
        } else {
            start = CGPoint(x: previous.rect.maxX, y: previous.rect.midY)
            end = CGPoint(x: mark.rect.minX, y: mark.rect.midY)
        }

        let deltaX = end.x - start.x
        var path = Path()
        path.move(to: start)
        if useVerticalAnchor {
            path.addLine(to: end)
        } else {
            path.addCurve(
                to: end,
                control1: CGPoint(x: start.x + deltaX * 0.30, y: start.y),
                control2: CGPoint(x: start.x + deltaX * 0.70, y: end.y)
            )
        }

        return (path, start, end)
    }

    private func drawMarks(marks: [RenderMark], context: inout GraphicsContext) {
        for stage in [TodayRhythmMinimalStage.sleep, .eat, .activity] {
            for mark in marks where mark.stage == stage {
                drawMark(mark, context: &context)
            }
        }
    }

    private func drawMark(_ mark: RenderMark, context: inout GraphicsContext) {
        let path = Path(roundedRect: mark.rect, cornerRadius: max(mark.rect.height / 5, 2))
        let opacity = mark.isEstimated ? 0.44 : 0.92

        context.opacity = opacity
        context.fill(
            path,
            with: .linearGradient(
                mark.fillGradient,
                startPoint: CGPoint(x: mark.rect.minX, y: mark.rect.minY),
                endPoint: CGPoint(x: mark.rect.maxX, y: mark.rect.maxY)
            )
        )
        context.stroke(path, with: .color(DesignToken.glassStroke.opacity(mark.isEstimated ? 0.18 : 0.36)), lineWidth: 0.55)
        context.stroke(path, with: .color(mark.accentColor.opacity(mark.isEstimated ? 0.08 : 0.18)), lineWidth: 0.75)
        context.opacity = 1
    }

    private func drawHourTicks(in bounds: CGRect, context: inout GraphicsContext) {
        for hour in [0, 6, 12, 18, 24] {
            let x = clamp(CGFloat(hour) / 24 * bounds.width, lower: 1, upper: bounds.width - 1)
            let rect = CGRect(x: x - 0.5, y: bounds.minY + 4, width: 1, height: bounds.height - 8)
            let opacity = hour == 0 || hour == 24 ? 0.12 : 0.16
            context.fill(Path(roundedRect: rect, cornerRadius: 0.5), with: .color(DesignToken.textSecondary.opacity(opacity)))
        }
    }

    private func drawCurrentTimeIndicator(in bounds: CGRect, context: inout GraphicsContext) {
        let now = Date()
        guard Calendar.current.isDate(now, inSameDayAs: date) else { return }

        let x = clamp(xPosition(now, width: bounds.width), lower: 1, upper: bounds.width - 1)
        let rect = CGRect(x: x - 0.5, y: bounds.minY + 2, width: 1, height: bounds.height - 4)
        context.fill(
            Path(roundedRect: rect, cornerRadius: 0.5),
            with: .color(DesignToken.textPrimary.opacity(0.14))
        )
    }

    private var timeScaleLabels: some View {
        RhythmTimelineTimeScale()
    }

    private func renderMarks(in bounds: CGRect, trackHeight: CGFloat) -> [RenderMark] {
        spans.compactMap { span -> RenderMark? in
            guard let stage = stage(for: span) else { return nil }
            let startX = xPosition(span.startAt, width: bounds.width)
            let endX = xPosition(span.endAt, width: bounds.width)
            let rawWidth = max(endX - startX, 1)
            let minimumWidth = minimumWidth(for: stage, span: span)
            let visualWidth = min(max(rawWidth, minimumWidth), bounds.width)
            let centerX = clamp(startX + rawWidth / 2, lower: visualWidth / 2, upper: bounds.width - visualWidth / 2)
            return RenderMark(
                id: span.id,
                stage: stage,
                startAt: span.startAt,
                endAt: span.endAt,
                centerX: centerX,
                width: visualWidth,
                trackHeight: trackHeight,
                usesDiaperAccent: span.isDiaper,
                isEstimated: span.isEstimated
            )
        }
    }

    private func stage(for span: RhythmTimelineSpan) -> TodayRhythmMinimalStage? {
        if span.isSleep { return .sleep }
        if span.isFeeding { return .eat }
        if span.isActivity || span.isDiaper { return .activity }
        return nil
    }

    private func minimumWidth(for stage: TodayRhythmMinimalStage, span: RhythmTimelineSpan) -> CGFloat {
        switch stage {
        case .eat:
            return span.isPoint ? 6 : 5
        case .activity:
            return span.isPoint ? 6 : 5
        case .sleep:
            return 8
        }
    }

    private func xPosition(_ date: Date, width: CGFloat) -> CGFloat {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: self.date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        let total = max(dayEnd.timeIntervalSince(dayStart), 1)
        let seconds = min(max(date.timeIntervalSince(dayStart), 0), total)
        return CGFloat(seconds / total) * width
    }

    private func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        min(max(value, lower), upper)
    }
}

private struct RhythmTimelineTimeScale: View {
    private let timeTicks: [(hour: Int, label: String)] = [(0, "00"), (6, "06"), (12, "12"), (18, "18"), (24, "24")]

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                ForEach(timeTicks, id: \.hour) { tick in
                    Text(tick.label.localized)
                        .font(BBBFont.font(size: 7.5, weight: .heavy))
                        .foregroundStyle(DesignToken.textSecondary.opacity(0.58))
                        .frame(width: 20, height: 10)
                        .position(
                            x: xPosition(for: tick.hour, width: proxy.size.width),
                            y: 5
                        )
                }
            }
        }
        .frame(height: 10)
    }

    private func xPosition(for hour: Int, width: CGFloat) -> CGFloat {
        min(
            max(CGFloat(hour) / 24 * width, 10),
            max(width - 10, 10)
        )
    }
}

private struct HomeWalletCardStack<Back: View, Front: View>: View {
    @Binding var isExpanded: Bool
    @ViewBuilder var back: () -> Back
    @ViewBuilder var front: () -> Front

    @State private var stackWidth: CGFloat = 0

    private let collapsedPeekHeight: CGFloat = 46
    private let expandedSpacing: CGFloat = 12

    var body: some View {
        let cardHeight = stackWidth > 0 ? stackWidth / 2 : 194
        let stackHeight = isExpanded
            ? cardHeight + expandedSpacing + cardHeight
            : collapsedPeekHeight + cardHeight

        ZStack(alignment: .top) {
            back()
                .frame(height: cardHeight)
                .offset(y: 0)
                .zIndex(1)

            front()
                // Keep all metric labels in the same rendered layer as their
                // card while the card moves between collapsed and expanded.
                .compositingGroup()
                .frame(height: cardHeight)
                .offset(y: isExpanded ? cardHeight + expandedSpacing : collapsedPeekHeight)
                .zIndex(2)
        }
        .frame(height: stackHeight, alignment: .top)
        .background(
            GeometryReader { proxy in
                Color.clear
                    .preference(key: WalletCardWidthKey.self, value: proxy.size.width)
            }
        )
        .onPreferenceChange(WalletCardWidthKey.self) { value in
            guard value > 0, abs(stackWidth - value) > 0.5 else { return }
            stackWidth = value
        }
        .animation(.walletCardPush, value: isExpanded)
        .animation(.easeOut(duration: 0.16), value: stackWidth)
        .accessibilityElement(children: .contain)
    }
}

private extension Animation {
    static var walletCardPush: Animation {
        .interactiveSpring(response: 0.44, dampingFraction: 0.88, blendDuration: 0.10)
    }
}

private struct WalletCardWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct RhythmSpanTimeline: View {
    let date: Date
    let spans: [RhythmTimelineSpan]
    var height: CGFloat
    var showsGuide: Bool
    var style: RhythmSpanTimelineStyle = .layered

    private struct ThinRailPlacement: Identifiable {
        let id: String
        let span: RhythmTimelineSpan
        let actualStartX: CGFloat
        let actualEndX: CGFloat
        var centerX: CGFloat
        let width: CGFloat

        var visualLeft: CGFloat { centerX - width / 2 }
        var visualRight: CGFloat { centerX + width / 2 }
    }

    var body: some View {
        switch style {
        case .layered:
            layeredBody
        case .thinRail:
            thinRailBody
        }
    }

    private var layeredBody: some View {
        VStack(spacing: showsGuide ? 6 : 0) {
            if showsGuide {
                HStack {
                    Text("0")
                    Spacer()
                    Text("6")
                    Spacer()
                    Text("12")
                    Spacer()
                    Text("18")
                    Spacer()
                    Text("24")
                }
                .font(BBBFont.font(size: 9, weight: .bold))
                .foregroundStyle(DesignToken.textSecondary.opacity(0.70))
                .padding(.horizontal, 3)
            }

            GeometryReader { proxy in
                let width = proxy.size.width
                let trackHeight = proxy.size.height
                let sleepHeight = min(max(trackHeight * 0.42, showsGuide ? 12 : 7), showsGuide ? 22 : 12)
                let feedingHeight = min(max(trackHeight * 0.48, showsGuide ? 13 : 8), showsGuide ? 24 : 13)
                let diaperHeight = min(max(trackHeight * 0.38, showsGuide ? 10 : 7), showsGuide ? 16 : 10)
                let centerY = trackHeight * 0.54
                let sleepY = min(centerY + trackHeight * 0.14, trackHeight - sleepHeight / 2 - 2)
                let feedingY = centerY
                let diaperY = max(centerY - trackHeight * 0.25, diaperHeight / 2 + 2)

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: showsGuide ? 16 : 8, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: showsGuide ? 16 : 8, style: .continuous)
                                .fill(DesignToken.surfaceRaised.opacity(showsGuide ? 0.26 : 0.16))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: showsGuide ? 16 : 8, style: .continuous)
                                .stroke(DesignToken.glassStroke.opacity(showsGuide ? 0.70 : 0.48), lineWidth: 0.8)
                        )

                    Rectangle()
                        .fill(DesignToken.glassStroke.opacity(showsGuide ? 0.28 : 0.18))
                        .frame(height: 1)
                        .position(x: width / 2, y: centerY)

                    ForEach([0, 6, 12, 18, 24], id: \.self) { hour in
                        let x = width * CGFloat(hour) / 24
                        Rectangle()
                            .fill(DesignToken.glassStroke.opacity(hour == 0 || hour == 24 ? 0.24 : 0.34))
                            .frame(width: 0.8, height: trackHeight * 0.72)
                            .position(x: min(max(x, 0.4), width - 0.4), y: centerY)
                    }

                    ForEach(spans.filter(\.isSleep)) { span in
                        let placement = placement(for: span, width: width, minimumWidth: max(width / 144, 3))
                        spanCapsule(span)
                            .frame(width: placement.width, height: sleepHeight)
                            .position(x: placement.centerX, y: sleepY)
                    }

                    ForEach(spans.filter(\.isFeeding)) { span in
                        let placement = placement(for: span, width: width, minimumWidth: span.isPoint ? max(width / 96, 5) : max(width / 144, 4))
                        spanCapsule(span)
                            .frame(width: placement.width, height: feedingHeight)
                            .position(x: placement.centerX, y: feedingY)
                    }

                    ForEach(spans.filter(\.isDiaper)) { span in
                        let placement = placement(for: span, width: width, minimumWidth: diaperHeight)
                        diaperMarker(span)
                            .frame(width: placement.width, height: diaperHeight)
                            .position(x: placement.centerX, y: diaperY)
                    }

                    if spans.isEmpty, showsGuide {
                        Text("暂无照护记录")
                            .font(BBBFont.font(size: 11, weight: .bold))
                            .foregroundStyle(DesignToken.textSecondary.opacity(0.62))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .frame(height: height)
    }

    private var thinRailBody: some View {
        VStack(spacing: showsGuide ? 10 : 0) {
            GeometryReader { proxy in
                let width = proxy.size.width
                let railHeight = min(max(proxy.size.height * 0.42, 10), 14)
                let placements = thinRailPlacements(width: width, railHeight: railHeight)

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: railHeight / 2, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    DesignToken.surfaceRaised.opacity(0.92),
                                    DesignToken.surfaceSoft.opacity(0.96)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: railHeight / 2, style: .continuous)
                                .stroke(DesignToken.glassStroke.opacity(0.72), lineWidth: 0.6)
                        )

                    ForEach(placements) { placement in
                        thinRailSegment(placement, railHeight: railHeight)
                    }

                    if spans.isEmpty, showsGuide {
                        Text("暂无照护记录")
                            .font(BBBFont.font(size: 10, weight: .bold))
                            .foregroundStyle(DesignToken.textSecondary.opacity(0.58))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(height: railHeight)
                .frame(maxHeight: .infinity, alignment: .center)
            }

            if showsGuide {
                HStack {
                    Text("00:00")
                    Spacer()
                    Text("06:00")
                    Spacer()
                    Text("12:00")
                    Spacer()
                    Text("18:00")
                    Spacer()
                    Text("24:00")
                }
                .font(BBBFont.font(size: 8, weight: .bold))
                .foregroundStyle(DesignToken.textSecondary.opacity(0.62))
                .padding(.horizontal, 1)
                .padding(.top, 1)
            }
        }
        .frame(height: height)
    }

    private func thinRailSegment(_ placement: ThinRailPlacement, railHeight: CGFloat) -> some View {
        let span = placement.span
        let segmentHeight = thinRailHeight(for: span, railHeight: railHeight)
        let opacity = span.isEstimated ? 0.42 : 0.92

        return Capsule(style: .continuous)
            .fill(spanFill(span))
            .opacity(opacity)
            .overlay(
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                DesignToken.glassFill.opacity(span.isEstimated ? 0.08 : 0.24),
                                DesignToken.glassFill.opacity(0)
                            ],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(DesignToken.glassStroke.opacity(span.isEstimated ? 0.26 : 0.48), lineWidth: 0.7)
            )
            .shadow(color: (span.colors.first ?? DesignToken.primary).opacity(span.isEstimated ? 0.04 : 0.10), radius: 3, y: 1)
            .frame(width: placement.width, height: segmentHeight)
            .position(x: placement.centerX, y: railHeight / 2)
    }

    private func thinRailPlacements(width: CGFloat, railHeight: CGFloat) -> [ThinRailPlacement] {
        let minGap: CGFloat = 2.5
        let sortedSpans = spans.sorted {
            if $0.startAt == $1.startAt {
                return $0.lane < $1.lane
            }
            return $0.startAt < $1.startAt
        }

        var placements: [ThinRailPlacement] = []

        for span in sortedSpans {
            let actualStartX = xPosition(for: span.startAt, width: width)
            let actualEndX = xPosition(for: span.endAt, width: width)
            let minimumWidth = thinRailMinimumWidth(for: span, width: width, railHeight: railHeight)
            let visualWidth = min(max(actualEndX - actualStartX, minimumWidth), width)
            let rawCenterX = min(max(actualStartX + visualWidth / 2, visualWidth / 2), width - visualWidth / 2)
            var placement = ThinRailPlacement(
                id: span.id,
                span: span,
                actualStartX: actualStartX,
                actualEndX: actualEndX,
                centerX: rawCenterX,
                width: visualWidth
            )

            if let previous = placements.last,
               previous.actualEndX <= placement.actualStartX,
               previous.visualRight + minGap > placement.visualLeft {
                let pushedCenterX = previous.visualRight + minGap + placement.width / 2
                placement.centerX = min(max(pushedCenterX, placement.width / 2), width - placement.width / 2)
            }

            placements.append(placement)
        }

        guard placements.count > 1 else { return placements }

        for index in stride(from: placements.count - 2, through: 0, by: -1) {
            let next = placements[index + 1]
            let current = placements[index]
            guard current.actualEndX <= next.actualStartX,
                  current.visualRight + minGap > next.visualLeft else { continue }
            let pulledCenterX = next.visualLeft - minGap - current.width / 2
            placements[index].centerX = max(min(pulledCenterX, width - current.width / 2), current.width / 2)
        }

        return placements
    }

    private func thinRailMinimumWidth(for span: RhythmTimelineSpan, width: CGFloat, railHeight: CGFloat) -> CGFloat {
        if span.isDiaper {
            return railHeight * 0.72
        }
        if span.isPoint {
            return railHeight * 0.78
        }
        if span.isFeeding {
            return max(width / 160, railHeight * 0.72)
        }
        return max(width / 180, 3)
    }

    private func thinRailHeight(for span: RhythmTimelineSpan, railHeight: CGFloat) -> CGFloat {
        if span.isDiaper {
            return railHeight * 0.72
        }
        if span.isFeeding {
            return railHeight * 0.84
        }
        return railHeight
    }

    @ViewBuilder
    private func spanCapsule(_ span: RhythmTimelineSpan) -> some View {
        let opacity = span.isEstimated ? 0.42 : 0.88
        let strokeOpacity = span.isEstimated ? 0.34 : 0.72

        Capsule(style: .continuous)
            .fill(spanFill(span))
            .opacity(opacity)
            .overlay(
                Capsule(style: .continuous)
                    .stroke(DesignToken.glassStroke.opacity(strokeOpacity), lineWidth: span.isEstimated ? 0.8 : 1)
            )
            .shadow(color: DesignToken.glassFill.opacity(span.isEstimated ? 0.08 : 0.20), radius: 1, y: -0.5)
    }

    @ViewBuilder
    private func diaperMarker(_ span: RhythmTimelineSpan) -> some View {
        Capsule(style: .continuous)
            .fill((span.colors.first ?? DesignToken.activityDiaper).opacity(0.92))
            .overlay(
                Capsule(style: .continuous)
                    .stroke(DesignToken.glassStroke.opacity(0.82), lineWidth: 1)
            )
            .shadow(color: DesignToken.activityDiaper.opacity(0.22), radius: 2, y: 1)
    }

    private func spanFill(_ span: RhythmTimelineSpan) -> AnyShapeStyle {
        let colors = span.colors
        guard colors.count > 1 else {
            let color = colors.first ?? DesignToken.primary
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        color.opacity(0.70),
                        color.opacity(0.95)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        return AnyShapeStyle(
            LinearGradient(
                colors: colors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private func xPosition(for time: Date, width: CGFloat) -> CGFloat {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let seconds = max(time.timeIntervalSince(dayStart), 0)
        return min(max(CGFloat(seconds / (24 * 60 * 60)) * width, 0), width)
    }

    private func placement(for span: RhythmTimelineSpan, width: CGFloat, minimumWidth: CGFloat) -> (centerX: CGFloat, width: CGFloat) {
        let startX = xPosition(for: span.startAt, width: width)
        let endX = xPosition(for: span.endAt, width: width)
        let visualWidth = min(max(endX - startX, minimumWidth), width)
        let centerX = min(max(startX + visualWidth / 2, visualWidth / 2), width - visualWidth / 2)
        return (centerX, visualWidth)
    }
}

private func rhythmTimelineSpans(
    for date: Date,
    sessions: [FeedingSession],
    careRecords: [CareRecord],
    ageMonths: Int?
) -> [RhythmTimelineSpan] {
    let feedingSpans = sessions.compactMap { session -> RhythmTimelineSpan? in
        let span = session.resolvedTimeSpan(ageMonths: ageMonths)
        let kinds = feedingTimelineKinds(for: session)
        guard !kinds.isEmpty else { return nil }
        return clippedTimelineSpan(
            date: date,
            startAt: span.startAt,
            endAt: span.endAt,
            kinds: kinds,
            isEstimated: span.isEstimated,
            isPoint: span.isPoint
        )
    }

    let careSpans = careRecords.compactMap { record -> RhythmTimelineSpan? in
        switch record.kind {
        case .diaper:
            return clippedTimelineSpan(
                date: date,
                startAt: record.recordedAt,
                endAt: record.recordedAt,
                kinds: [.diaper],
                isEstimated: false,
                isPoint: true
            )
        case .activity:
            return clippedTimelineSpan(
                date: date,
                startAt: record.recordedAt,
                endAt: record.recordedAt,
                kinds: [.activity],
                isEstimated: false,
                isPoint: true
            )
        case .sleep:
            guard let minutes = SleepRecordFormatter.durationMinutes(from: record.detail) else {
                return nil
            }
            let endAt = SleepRecordFormatter.endTime(start: record.recordedAt, durationMinutes: minutes)
            return clippedTimelineSpan(
                date: date,
                startAt: record.recordedAt,
                endAt: endAt,
                kinds: [.sleep],
                isEstimated: false,
                isPoint: false
            )
        }
    }

    return (feedingSpans + careSpans).sorted { $0.startAt < $1.startAt }
}

private func feedingTimelineKinds(for session: FeedingSession) -> [RhythmTimelineKind] {
    var kinds: [RhythmTimelineKind] = []
    let types = Set(session.entries.map(\.type))
    if types.contains(.bottle) { kinds.append(.bottle) }
    if types.contains(.breast) { kinds.append(.breast) }
    if types.contains(.solid) { kinds.append(.solid) }
    return kinds
}

private func clippedTimelineSpan(
    date: Date,
    startAt: Date,
    endAt: Date,
    kinds: [RhythmTimelineKind],
    isEstimated: Bool,
    isPoint: Bool
) -> RhythmTimelineSpan? {
    let calendar = Calendar.current
    let dayStart = calendar.startOfDay(for: date)
    let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart

    if isPoint {
        guard startAt >= dayStart && startAt < dayEnd else { return nil }
        return RhythmTimelineSpan(startAt: startAt, endAt: startAt, kinds: kinds, isEstimated: isEstimated, isPoint: true)
    }

    let clippedStart = max(startAt, dayStart)
    let clippedEnd = min(endAt, dayEnd)
    guard clippedEnd > clippedStart else { return nil }
    return RhythmTimelineSpan(startAt: clippedStart, endAt: clippedEnd, kinds: kinds, isEstimated: isEstimated, isPoint: false)
}

private enum DailyRhythmKind: Hashable, CaseIterable {
    case sleep
    case bottle
    case breast
    case solid
    case diaper

    var color: Color {
        switch self {
        case .sleep:
            return DesignToken.easySleep
        case .bottle:
            return DesignToken.feedingBottle
        case .breast:
            return DesignToken.feedingBreast
        case .solid:
            return DesignToken.feedingSolid
        case .diaper:
            return DesignToken.activityDiaper
        }
    }
}

private struct DailyRhythmHourSegment: Identifiable {
    var id: Int { hour }
    let hour: Int
    let kinds: [DailyRhythmKind]
    let intensity: Double
    let isFuture: Bool
}

private struct DailyRhythmSegmentBar: View {
    let segments: [DailyRhythmHourSegment]
    var height: CGFloat = 58
    var segmentHeight: CGFloat = 50
    var spacing: CGFloat = 5
    var cornerRadius: CGFloat = 9

    var body: some View {
        GeometryReader { proxy in
            let segmentWidth = max((proxy.size.width - spacing * 23) / 24, 3)

            HStack(alignment: .center, spacing: spacing) {
                ForEach(segments) { segment in
                    DailyRhythmSegment(segment: segment, height: segmentHeight, cornerRadius: cornerRadius)
                        .frame(width: segmentWidth)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(height: height)
    }
}

private struct DailyRhythmSegment: View {
    let segment: DailyRhythmHourSegment
    let height: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                segmentFill
                    .opacity(segment.intensity)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                DesignToken.glassFill.opacity(segment.kinds.isEmpty ? 0.32 : 0.48),
                                DesignToken.glassFill.opacity(0.10),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(DesignToken.glassStroke.opacity(segment.kinds.isEmpty ? 0.56 : 0.76), lineWidth: 0.8)
            }
            .shadow(color: DesignToken.glassFill.opacity(segment.kinds.isEmpty ? 0.10 : 0.26), radius: 1, y: -0.5)
            .frame(height: height)
            .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private var segmentFill: some View {
        if segment.kinds.isEmpty {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(segment.isFuture ? DesignToken.surfaceSoft : DesignToken.borderSubtle)
        } else if segment.kinds.count == 1, let kind = segment.kinds.first {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(kind.color)
        } else {
            VStack(spacing: 0) {
                ForEach(Array(segment.kinds.enumerated()), id: \.offset) { _, kind in
                    Rectangle()
                        .fill(kind.color)
                }
            }
        }
    }

    private var accessibilityLabel: String {
        let hourText = "\(segment.hour)点"
        guard !segment.kinds.isEmpty else {
            return segment.isFuture ? "\(hourText)，尚未开始" : "\(hourText)，暂无记录"
        }
        return "\(hourText)，有照护记录"
    }
}

private struct TimelineConnector: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return path
    }
}

@MainActor
@available(*, unavailable, message: "Use BBBriefStore and BBBriefGenerator; report entry points must never regenerate snapshots.")
enum DailyCareReportFactory {
    static func availableReport(
        now: Date = Date(),
        feedingStore: FeedingStore,
        activityStore: ActivityStore,
        recruitmentStore: CompanionRecruitmentStore
    ) -> YesterdayReport? {
        let calendar = Calendar.current
        guard calendar.component(.hour, from: now) >= 8,
              let sourceDate = calendar.date(byAdding: .day, value: -1, to: now) else {
            return recruitmentStore.latestReport()
        }

        let key = reportKey(for: sourceDate)
        if let existing = recruitmentStore.report(for: key) {
            return existing
        }

        guard let report = makeReport(
            date: sourceDate,
            sessions: feedingStore.sessions(on: sourceDate),
            careRecords: activityStore.careRecords(on: sourceDate),
            recruitmentStore: recruitmentStore
        ) else {
            return nil
        }
        recruitmentStore.storeReport(report)
        return recruitmentStore.report(for: report.reportKey) ?? report
    }

    static func rhythmReport(
        for date: Date,
        feedingStore: FeedingStore,
        activityStore: ActivityStore,
        recruitmentStore: CompanionRecruitmentStore
    ) -> YesterdayReport? {
        let key = reportKey(for: date)
        if let existing = recruitmentStore.report(for: key) {
            return existing
        }

        return makeReport(
            date: date,
            sessions: feedingStore.sessions(on: date),
            careRecords: activityStore.careRecords(on: date),
            recruitmentStore: recruitmentStore
        )
    }

    private static func makeReport(
        date: Date,
        sessions: [FeedingSession],
        careRecords: [CareRecord],
        recruitmentStore: CompanionRecruitmentStore
    ) -> YesterdayReport? {
        let reportKey = reportKey(for: date)
        let bottleAmount = sessions.reduce(0) { $0 + $1.totalBottleAmount }
        let breastMinutes = sessions.reduce(0) { $0 + $1.totalBreastDuration }
        let solidAmount = sessions.reduce(0) { $0 + $1.totalSolidAmount }
        let diaperCount = careRecords.filter { $0.kind == .diaper }.count
        let earnedBBBucks = recruitmentStore.earnedBBBucks(on: date)
        let sleepSummary = DayTimelineCalculator.summary(for: date, sessions: sessions, careRecords: careRecords)
        let recordedSleepMinutes = sleepSummary.recordedSleepMinutes
        let possibleSleepMinutes = sleepSummary.possibleSleepMinutes

        let rhythmHours = Set(
            sessions.map(\.eventDate).map { hour(from: $0) } +
            careRecords.map(\.recordedAt).map { hour(from: $0) }
        )
        let feedingHours = Set(sessions.map(\.eventDate).map { hour(from: $0) })
        let diaperHours = Set(careRecords.filter { $0.kind == .diaper }.map { hour(from: $0.recordedAt) })
        let sleepHours = sleepSummary.recordedSleepHours
        let rhythmText: String
        if let firstHour = rhythmHours.min(), let lastHour = rhythmHours.max() {
            rhythmText = "主要记录集中在 \(hourRangeText(firstHour, lastHour))，全天共有 \(rhythmHours.count) 个活跃时段。"
        } else {
            rhythmText = "还没有形成明显节奏，可以从一次喂养或尿布记录开始补充。"
        }

        var analysisParts: [String] = []
        if sessions.isEmpty {
            analysisParts.append("没有喂养记录，可以先补上最近一次喂养时间。")
        } else if sessions.count < 4 {
            analysisParts.append("喂养记录偏少，适合继续观察间隔是否稳定。")
        } else {
            analysisParts.append("喂养节奏比较清楚，可以继续保持固定记录。")
        }

        if diaperCount == 0 {
            analysisParts.append("尿布记录为空，尿量会影响喂养判断。")
        } else {
            analysisParts.append("尿布记录 \(diaperCount) 次，可结合奶量观察状态。")
        }

        if recordedSleepMinutes > 0 {
            analysisParts.append("记录睡眠累计 \(AppQuantityFormat.compactDuration(recordedSleepMinutes))。")
        } else if possibleSleepMinutes > 0 {
            analysisParts.append("有较长未记录空档，可能包含睡眠，但未计入记录睡眠。")
        }

        return YesterdayReport(
            reportKey: reportKey,
            date: Calendar.current.startOfDay(for: date),
            dateText: reportDateText(for: date),
            feedingCount: sessions.count,
            bottleAmount: bottleAmount,
            breastMinutes: breastMinutes,
            solidAmount: Int(solidAmount),
            diaperCount: diaperCount,
            sleepMinutes: recordedSleepMinutes,
            feedingHours: feedingHours,
            diaperHours: diaperHours,
            sleepHours: sleepHours,
            rhythmText: rhythmText,
            analysisText: analysisParts.joined(separator: " "),
            earnedBBBucks: earnedBBBucks,
            visitorCompanionID: "",
            visitorCompanionIDs: [],
            fedCompanionID: nil,
            fedBBBucks: 0,
            feedings: [],
            createdAt: Date()
        )
    }

    private static func reportKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func reportDateText(for date: Date) -> String {
        AppDateTimeFormat.date(date)
    }

    private static func hourRangeText(_ firstHour: Int, _ lastHour: Int) -> String {
        AppDateTimeFormat.hourRange(from: firstHour, to: lastHour)
    }

    private static func hour(from date: Date) -> Int {
        Calendar.current.component(.hour, from: date)
    }
}

private enum TimelineHourState {
    case future
    case elapsed
    case possibleSleep
    case recordedSleep
}

private struct SleepComputationSummary {
    let recordedSleepMinutes: Int
    let possibleSleepMinutes: Int
    let hourStates: [Int: TimelineHourState]
    let recordedSleepHours: Set<Int>
}

private enum DayTimelineCalculator {
    private struct TimeBlock {
        var start: Date
        var end: Date
    }

    static func summary(for date: Date, sessions: [FeedingSession], careRecords: [CareRecord]) -> SleepComputationSummary {
        let calendar = Calendar.current
        let now = Date()
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? date
        let effectiveEnd = min(dayEnd, max(dayStart, now))

        guard effectiveEnd > dayStart else {
            return SleepComputationSummary(
                recordedSleepMinutes: 0,
                possibleSleepMinutes: 0,
                hourStates: hourStates(
                    elapsedBlocks: [],
                    possibleSleepBlocks: [],
                    recordedSleepBlocks: [],
                    dayStart: dayStart,
                    effectiveEnd: dayStart,
                    dayEnd: dayEnd,
                    calendar: calendar
                ),
                recordedSleepHours: []
            )
        }

        let awakeBlocks = merge(
            sessions.compactMap { clipped(feedingBlock(for: $0), dayStart: dayStart, dayEnd: effectiveEnd) } +
            careRecords
                .filter { $0.kind == .diaper }
                .compactMap { clipped(diaperBlock(for: $0), dayStart: dayStart, dayEnd: effectiveEnd) }
        )

        let defaultSleepBlocks = complement(of: awakeBlocks, from: dayStart, to: effectiveEnd)
        let recordedSleepBlocks = careRecords
            .filter { $0.kind == .sleep }
                .compactMap { clipped(recordedSleepBlock(for: $0), dayStart: dayStart, dayEnd: effectiveEnd) }

        let possibleSleepBlocks = possibleSleepCandidates(from: defaultSleepBlocks, calendar: calendar)
        let recordedSleepMinutes = minutes(in: merge(recordedSleepBlocks))
        let possibleSleepMinutes = minutes(in: subtract(possibleSleepBlocks, removing: recordedSleepBlocks))

        return SleepComputationSummary(
            recordedSleepMinutes: recordedSleepMinutes,
            possibleSleepMinutes: possibleSleepMinutes,
            hourStates: hourStates(
                elapsedBlocks: defaultSleepBlocks,
                possibleSleepBlocks: possibleSleepBlocks,
                recordedSleepBlocks: recordedSleepBlocks,
                dayStart: dayStart,
                effectiveEnd: effectiveEnd,
                dayEnd: dayEnd,
                calendar: calendar
            ),
            recordedSleepHours: activeHours(in: recordedSleepBlocks, calendar: calendar)
        )
    }

    private static func feedingBlock(for session: FeedingSession) -> TimeBlock? {
        if let startAt = session.startAt,
           let endAt = session.endAt,
           startAt < endAt {
            return TimeBlock(start: startAt, end: endAt)
        }

        let minutes = session.entries.reduce(0) { total, entry in
            total + feedingMinutes(for: entry)
        }
        guard minutes > 0 else { return nil }
        return TimeBlock(
            start: session.createdAt.addingTimeInterval(TimeInterval(-minutes * 60)),
            end: session.createdAt
        )
    }

    private static func feedingMinutes(for entry: FeedingEntry) -> Int {
        switch entry.type {
        case .breast:
            return max(entry.breastDuration ?? 0, 0)
        case .bottle:
            if let duration = entry.bottleDuration, duration > 0 {
                return duration
            }
            let amount = entry.bottleAmount ?? 0
            return amount > 0 ? max(Int(ceil(Double(amount) / 10.0)), 5) : 0
        case .solid:
            guard let amount = entry.solidAmount, amount > 0 else { return 0 }
            let normalizedAmount: Double
            switch entry.solidUnit ?? .g {
            case .g, .ml:
                normalizedAmount = amount
            case .mg:
                normalizedAmount = amount / 1000
            case .oz, .flOz:
                normalizedAmount = amount * 30
            case .drop:
                normalizedAmount = amount * 0.05
            case .piece:
                normalizedAmount = amount * 10
            case .tsp:
                normalizedAmount = amount * 5
            case .tbsp:
                normalizedAmount = amount * 15
            }
            return max(Int(ceil(normalizedAmount / 10.0)), 5)
        }
    }

    private static func diaperBlock(for record: CareRecord) -> TimeBlock {
        TimeBlock(
            start: record.recordedAt.addingTimeInterval(-5 * 60),
            end: record.recordedAt
        )
    }

    private static func recordedSleepBlock(for record: CareRecord) -> TimeBlock? {
        guard let minutes = sleepMinutes(from: record.detail), minutes > 0 else {
            return nil
        }
        return TimeBlock(
            start: record.recordedAt,
            end: record.recordedAt.addingTimeInterval(TimeInterval(minutes * 60))
        )
    }

    private static func clipped(_ block: TimeBlock?, dayStart: Date, dayEnd: Date) -> TimeBlock? {
        guard let block else { return nil }
        let start = max(block.start, dayStart)
        let end = min(block.end, dayEnd)
        guard end > start else { return nil }
        return TimeBlock(start: start, end: end)
    }

    private static func merge(_ blocks: [TimeBlock]) -> [TimeBlock] {
        let sorted = blocks.sorted { $0.start < $1.start }
        return sorted.reduce(into: []) { result, block in
            guard var last = result.popLast() else {
                result.append(block)
                return
            }
            if block.start <= last.end {
                last.end = max(last.end, block.end)
                result.append(last)
            } else {
                result.append(last)
                result.append(block)
            }
        }
    }

    private static func complement(of blocks: [TimeBlock], from dayStart: Date, to dayEnd: Date) -> [TimeBlock] {
        var cursor = dayStart
        var result: [TimeBlock] = []

        for block in blocks {
            if block.start > cursor {
                result.append(TimeBlock(start: cursor, end: block.start))
            }
            cursor = max(cursor, block.end)
        }

        if cursor < dayEnd {
            result.append(TimeBlock(start: cursor, end: dayEnd))
        }

        return result
    }

    private static func possibleSleepCandidates(from blocks: [TimeBlock], calendar: Calendar) -> [TimeBlock] {
        blocks.filter { block in
            let minutes = block.end.timeIntervalSince(block.start) / 60
            let threshold: Double = isNightBlock(block, calendar: calendar) ? 45 : 90
            return minutes >= threshold
        }
    }

    private static func isNightBlock(_ block: TimeBlock, calendar: Calendar) -> Bool {
        let midpoint = block.start.addingTimeInterval(block.end.timeIntervalSince(block.start) / 2)
        let hour = calendar.component(.hour, from: midpoint)
        return hour >= 20 || hour < 8
    }

    private static func subtract(_ blocks: [TimeBlock], removing removalBlocks: [TimeBlock]) -> [TimeBlock] {
        let removals = merge(removalBlocks)
        return blocks.flatMap { block -> [TimeBlock] in
            var fragments = [block]
            for removal in removals {
                fragments = fragments.flatMap { subtract($0, removing: removal) }
            }
            return fragments
        }
    }

    private static func subtract(_ block: TimeBlock, removing removal: TimeBlock) -> [TimeBlock] {
        guard removal.end > block.start, removal.start < block.end else {
            return [block]
        }

        var result: [TimeBlock] = []
        if removal.start > block.start {
            result.append(TimeBlock(start: block.start, end: min(removal.start, block.end)))
        }
        if removal.end < block.end {
            result.append(TimeBlock(start: max(removal.end, block.start), end: block.end))
        }
        return result.filter { $0.end > $0.start }
    }

    private static func minutes(in blocks: [TimeBlock]) -> Int {
        let totalSeconds = blocks.reduce(0) { $0 + max($1.end.timeIntervalSince($1.start), 0) }
        return Int((totalSeconds / 60).rounded())
    }

    private static func hourStates(
        elapsedBlocks: [TimeBlock],
        possibleSleepBlocks: [TimeBlock],
        recordedSleepBlocks: [TimeBlock],
        dayStart: Date,
        effectiveEnd: Date,
        dayEnd: Date,
        calendar: Calendar
    ) -> [Int: TimelineHourState] {
        var states: [Int: TimelineHourState] = [:]

        for hour in 0..<24 {
            guard
                let hourStart = calendar.date(byAdding: .hour, value: hour, to: dayStart),
                let hourEnd = calendar.date(byAdding: .hour, value: 1, to: hourStart)
            else {
                states[hour] = .future
                continue
            }

            if hourStart >= min(effectiveEnd, dayEnd) {
                states[hour] = .future
            } else {
                let slice = TimeBlock(start: hourStart, end: min(hourEnd, effectiveEnd))
                if overlaps(recordedSleepBlocks, with: slice) {
                    states[hour] = .recordedSleep
                } else if overlaps(possibleSleepBlocks, with: slice) {
                    states[hour] = .possibleSleep
                } else if overlaps(elapsedBlocks, with: slice) {
                    states[hour] = .elapsed
                } else {
                    states[hour] = .elapsed
                }
            }
        }

        return states
    }

    private static func overlaps(_ blocks: [TimeBlock], with block: TimeBlock) -> Bool {
        blocks.contains { $0.start < block.end && $0.end > block.start }
    }

    private static func activeHours(in blocks: [TimeBlock], calendar: Calendar) -> Set<Int> {
        var hours: Set<Int> = []

        for block in blocks where block.end > block.start {
            var cursor = block.start
            while cursor < block.end {
                hours.insert(calendar.component(.hour, from: cursor))
                guard let nextHour = calendar.nextDate(
                    after: cursor,
                    matching: DateComponents(minute: 0, second: 0),
                    matchingPolicy: .nextTime,
                    direction: .forward
                ) else {
                    break
                }
                cursor = min(nextHour, block.end)
            }
        }

        return hours
    }

    private static func sleepMinutes(from detail: String) -> Int? {
        let digits = detail.prefix { $0.isNumber }
        return Int(digits)
    }
}

enum YesterdayReportPresentationMode: Equatable {
    case careReport
    case rhythmDetail
}

enum ReportRewardPresentationPolicy {
    static func transactionToPresent(
        from transactions: [BBBuckTransaction],
        reportKey: String,
        now: Date,
        lastPresentedTransactionID: String,
        calendar: Calendar = .current
    ) -> BBBuckTransaction? {
        transactions
            .filter {
                $0.source == .dailyTask
                    && $0.taskID == .viewReport
                    && $0.referenceID == reportKey
                    && calendar.isDate($0.createdAt, inSameDayAs: now)
                    && $0.id != lastPresentedTransactionID
            }
            .max(by: { $0.createdAt < $1.createdAt })
    }
}

/// Legacy renderer retained only for persisted `YesterdayReport` compatibility.
/// Production entry points use `BBBriefPage` and never instantiate this view.
struct YesterdayReportOverlay: View {
    @EnvironmentObject private var recruitmentStore: CompanionRecruitmentStore
    @EnvironmentObject private var feedingStore: FeedingStore
    @EnvironmentObject private var activityStore: ActivityStore
    @Environment(BabyProfileStore.self) private var profileStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var subjectiveStateStore = SubjectiveStateStore.shared
    @AppStorage("buddy_card_reduced_effects_enabled") private var reducedBuddyCardEffects = false
    @StateObject private var cardMotion = BuddyCardMotionModel()
    @State private var selectedReportKey: String?
    @State private var checkedReportRewardKeys = Set<String>()
    @State private var preparedRewardTransactionID: String?

    let report: YesterdayReport
    var reports: [YesterdayReport] = []
    var presentationMode: YesterdayReportPresentationMode = .careReport
    let lastPresentedReportRewardTransactionID: String
    let onRewardReady: (BBBuckTransaction) -> Void
    let onDismiss: () -> Void

    var body: some View {
        let tint = VisitorWeekdayGiftPalette.color(for: displayedReport.date)

        ZStack {
            AppModalBackdrop(bodyColor: DesignToken.surfaceSoft, accent: tint)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: dismissReport)

            GeometryReader { proxy in
                let bottomPadding = max(proxy.safeAreaInsets.bottom + 128, 150)

                VStack(spacing: 10) {
                    Spacer(minLength: 0)

                    reportCard(tint: tint)
                        .contentShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                        .gesture(cardSwipeGesture)
                        .onTapGesture {}

                    if reportDeck.count > 1 {
                        CardCarouselIndicator(
                            index: selectedReportIndex,
                            total: reportDeck.count,
                            tint: tint,
                            accessibilityTitle: "每日报告卡"
                        )
                        .padding(.top, 2)
                        .onTapGesture {}
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, proxy.safeAreaInsets.top + 18)
                .padding(.bottom, bottomPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
        }
        .onAppear {
            selectedReportKey = displayedReport.reportKey
            refreshCardMotion()
        }
        .onDisappear {
            prepareReportRewardForDismissal()
            cardMotion.stop()
        }
        // Opening the report records the daily task immediately. Presentation
        // is handed back to the parent only when this sheet is closing, so the
        // reward can never interrupt report reading.
        .task(id: displayedReport.reportKey) {
            await Task.yield()
            guard !Task.isCancelled else { return }
            awardReportRewardIfNeeded()
        }
        .onChange(of: reducedBuddyCardEffects) { _, _ in refreshCardMotion() }
        .onChange(of: reduceMotion) { _, _ in refreshCardMotion() }
    }

    private func reportCard(tint: Color) -> some View {
        let snapshot = dailySnapshot
        let average = sevenDayAverageSnapshot
        let tilt = activeCardTilt

        return VStack(alignment: .leading, spacing: 12) {
            reportHeader(tint: tint)

            TodayRhythmMinimalTimeline(
                date: displayedReport.date,
                spans: reportRhythmSpans,
                height: 82
            )
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(DesignToken.iconSoftBG.opacity(0.48))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(DesignToken.glassStroke.opacity(0.56), lineWidth: 0.8)
                    )
            )

            VStack(alignment: .leading, spacing: 7) {
                Text("当日")
                    .font(BBBFont.font(size: 8.5, weight: .heavy))
                    .foregroundStyle(DesignToken.textSecondary.opacity(0.70))

                reportMetricRow(snapshot)
                comparisonConnectors(current: snapshot, average: average)

                Text("近7日平均")
                    .font(BBBFont.font(size: 8.5, weight: .heavy))
                    .foregroundStyle(DesignToken.textSecondary.opacity(0.70))

                reportMetricRow(average)
            }
        }
        .padding(16)
        .frame(maxWidth: 430)
        .background(
            BuddyCardSurface(
                tint: tint,
                tilt: tilt,
                isHolographic: true,
                reducedEffects: reducedBuddyCardEffects || reduceMotion
            )
        )
        .buddyCardTiltEffect(tilt, enabled: isCardMotionEnabled)
    }

    private func reportHeader(tint: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(tint)
                    Text(presentationMode == .rhythmDetail ? "节奏详情" : "每日报告")
                        .font(BBBFont.font(size: 9, weight: .heavy))
                        .foregroundStyle(DesignToken.textSecondary)
                        .tracking(1.2)
                }

                Text(displayedReport.dateText.localized)
                    .font(BBBFont.font(size: 22, weight: .heavy))
                    .foregroundStyle(DesignToken.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
            }

            Spacer(minLength: 0)

            Button(action: dismissReport) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(DesignToken.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(DesignToken.surfaceRaised.opacity(0.72)))
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel("关闭每日报告")
        }
    }

    private func reportMetricRow(_ snapshot: DailyReportMetricSnapshot) -> some View {
        GeometryReader { proxy in
            let spacing: CGFloat = 8
            let tileWidth = max((proxy.size.width - spacing * 3) / 4, 0)

            HStack(spacing: spacing) {
                RhythmMetricTile(
                    badge: "E",
                    title: "喂养",
                    value: snapshot.feedingText,
                    color: DesignToken.easyEat,
                    style: .light
                )
                .frame(width: tileWidth)

                RhythmMetricTile(
                    badge: "A",
                    title: "活动",
                    value: snapshot.activityText,
                    color: DesignToken.easyActivity,
                    style: .light
                )
                .frame(width: tileWidth)

                RhythmMetricTile(
                    badge: "S",
                    title: "睡眠",
                    value: snapshot.sleepText,
                    color: DesignToken.easySleep,
                    style: .light
                )
                .frame(width: tileWidth)

                RhythmSubjectiveStateTile(babyState: snapshot.babyState, style: .light)
                    .frame(width: tileWidth)
            }
        }
        .frame(height: 44)
    }

    private func comparisonConnectors(
        current: DailyReportMetricSnapshot,
        average: DailyReportMetricSnapshot
    ) -> some View {
        let deltas = comparisonDeltas(current: current, average: average)

        return GeometryReader { proxy in
            let spacing: CGFloat = 8
            let columnWidth = max((proxy.size.width - spacing * 3) / 4, 0)

            HStack(spacing: spacing) {
                ForEach(Array(deltas.enumerated()), id: \.offset) { _, delta in
                    VStack(spacing: 2) {
                        Rectangle()
                            .fill(delta.color.opacity(0.34))
                            .frame(width: 1, height: 5)

                        Text(delta.text)
                            .font(BBBFont.font(size: 8, weight: .heavy))
                            .foregroundStyle(delta.color)
                            .monospacedDigit()
                            .padding(.horizontal, 6)
                            .frame(minHeight: 16)
                            .background(Capsule().fill(delta.color.opacity(0.10)))

                        Rectangle()
                            .fill(delta.color.opacity(0.34))
                            .frame(width: 1, height: 5)
                    }
                    .frame(width: columnWidth)
                }
            }
        }
        .frame(height: 30)
    }

    private var reportDeck: [YesterdayReport] {
        var seen = Set<String>()
        var source = reports
        if !source.contains(where: { $0.reportKey == report.reportKey }) {
            source.insert(report, at: 0)
        }
        if source.isEmpty { source = [report] }
        return source.filter { seen.insert($0.reportKey).inserted }
    }

    private var displayedReport: YesterdayReport {
        let selected = reportDeck.first { $0.reportKey == selectedReportKey } ?? report
        return recruitmentStore.report(for: selected.reportKey) ?? selected
    }

    private var selectedReportIndex: Int {
        reportDeck.firstIndex { $0.reportKey == displayedReport.reportKey } ?? 0
    }

    private var reportRhythmSpans: [RhythmTimelineSpan] {
        rhythmTimelineSpans(
            for: displayedReport.date,
            sessions: feedingStore.sessions(on: displayedReport.date),
            careRecords: reportCareRecordsForRhythm,
            ageMonths: profileStore.currentProfile.ageMonths
        )
    }

    private var reportCareRecordsForRhythm: [CareRecord] {
        var recordsByID: [UUID: CareRecord] = [:]
        for record in activityStore.careRecords(on: displayedReport.date) {
            recordsByID[record.id] = record
        }
        for record in activityStore.careRecordsForSleepSummary(on: displayedReport.date) where record.kind == .sleep {
            recordsByID[record.id] = record
        }
        return Array(recordsByID.values)
    }

    private var dailySnapshot: DailyReportMetricSnapshot {
        makeSnapshot(
            sessions: feedingStore.sessions(on: displayedReport.date),
            careRecords: activityStore.careRecords(on: displayedReport.date),
            sleepMinutes: DayTimelineCalculator.summary(
                for: displayedReport.date,
                sessions: feedingStore.sessions(on: displayedReport.date),
                careRecords: activityStore.careRecordsForSleepSummary(on: displayedReport.date)
            ).recordedSleepMinutes,
            babyState: subjectiveStateStore.latestBabyState(on: displayedReport.date)
        )
    }

    private var sevenDayAverageSnapshot: DailyReportMetricSnapshot {
        let calendar = Calendar.current
        let end = calendar.startOfDay(for: displayedReport.date)
        let start = calendar.date(byAdding: .day, value: -6, to: end) ?? end
        let dayCount = 7
        let sessions = feedingStore.allSessions.filter {
            let day = calendar.startOfDay(for: $0.eventDate)
            return day >= start && day <= end
        }
        let careRecords = activityStore.careRecords.filter {
            let day = calendar.startOfDay(for: $0.recordedAt)
            return day >= start && day <= end
        }
        let bottle = roundedAverage(sessions.reduce(0) { $0 + $1.totalBottleAmount }, days: dayCount, step: 10)
        let breast = roundedAverage(sessions.reduce(0) { $0 + $1.totalBreastDuration }, days: dayCount, step: 5)
        let solid = roundedAverage(sessions.reduce(0.0) { $0 + $1.totalSolidAmount }, days: dayCount, step: 1)
        let diapers = careRecords.filter { $0.kind == .diaper }
        let poop = roundedAverage(diapers.filter { DiaperRecordType.type(for: $0.title) == .poop }.count, days: dayCount, step: 1)
        let pee = roundedAverage(diapers.filter { DiaperRecordType.type(for: $0.title) == .pee }.count, days: dayCount, step: 1)
        let activity = roundedAverage(careRecords.filter { $0.kind == .activity }.count, days: dayCount, step: 1)
        let sleepTotalMinutes = (0..<dayCount).reduce(0) { total, offset in
            let day = calendar.date(byAdding: .day, value: offset, to: start) ?? start
            return total + calendarDaySleepMinutes(on: day, records: activityStore.careRecords)
        }
        let sleep = roundedAverage(sleepTotalMinutes, days: dayCount, step: 15)
        let endExclusive = calendar.date(byAdding: .day, value: 1, to: end) ?? end
        let state = subjectiveStateStore.dominantBabyState(from: start, to: endExclusive)

        return DailyReportMetricSnapshot(
            feedingText: feedingText(bottle: bottle, breast: breast, solid: solid),
            activityText: activityText(poop: poop, pee: pee, activity: activity),
            sleepText: sleep > 0 ? AppQuantityFormat.compactDuration(sleep) : "--",
            babyState: state,
            feedingValue: Double(bottle) + Double(breast) * breastEquivalentRate + Double(solid),
            activityValue: Double(poop + pee + activity),
            sleepValue: Double(sleep)
        )
    }

    private func makeSnapshot(
        sessions: [FeedingSession],
        careRecords: [CareRecord],
        sleepMinutes: Int,
        babyState: BabySubjectiveState?
    ) -> DailyReportMetricSnapshot {
        let bottle = sessions.reduce(0) { $0 + $1.totalBottleAmount }
        let breast = sessions.reduce(0) { $0 + $1.totalBreastDuration }
        let solid = Int(sessions.reduce(0.0) { $0 + $1.totalSolidAmount }.rounded())
        let diapers = careRecords.filter { $0.kind == .diaper }
        let poop = diapers.filter { DiaperRecordType.type(for: $0.title) == .poop }.count
        let pee = diapers.filter { DiaperRecordType.type(for: $0.title) == .pee }.count
        let activity = careRecords.filter { $0.kind == .activity }.count

        return DailyReportMetricSnapshot(
            feedingText: feedingText(bottle: bottle, breast: breast, solid: solid),
            activityText: activityText(poop: poop, pee: pee, activity: activity),
            sleepText: sleepMinutes > 0 ? AppQuantityFormat.compactDuration(sleepMinutes) : "--",
            babyState: babyState,
            feedingValue: Double(bottle) + Double(breast) * breastEquivalentRate + Double(solid),
            activityValue: Double(poop + pee + activity),
            sleepValue: Double(sleepMinutes)
        )
    }

    private func feedingText(bottle: Int, breast: Int, solid: Int) -> String {
        var parts: [String] = []
        if bottle > 0 { parts.append(AppMeasurementFormat.volume(Double(bottle))) }
        if breast > 0 { parts.append(AppQuantityFormat.compactDuration(breast)) }
        if solid > 0 { parts.append(AppMeasurementFormat.mass(Double(solid))) }
        return parts.isEmpty ? "--" : parts.joined(separator: " ")
    }

    private func activityText(poop: Int, pee: Int, activity: Int) -> String {
        var parts: [String] = []
        if poop > 0 { parts.append("\(poop)拉") }
        if pee > 0 { parts.append("\(pee)尿") }
        if activity > 0 { parts.append("\(activity)玩") }
        return parts.isEmpty ? "--" : parts.joined()
    }

    private func roundedAverage(_ total: Int, days: Int, step: Int) -> Int {
        guard total > 0, days > 0 else { return 0 }
        return Int((Double(total) / Double(days) / Double(step)).rounded()) * step
    }

    private func roundedAverage(_ total: Double, days: Int, step: Int) -> Int {
        guard total > 0, days > 0 else { return 0 }
        return Int((total / Double(days) / Double(step)).rounded()) * step
    }

    private var breastEquivalentRate: Double {
        switch profileStore.currentProfile.ageMonths {
        case 1...4: return 5.2
        case 5...12: return 5.8
        default: return 5.5
        }
    }

    private func comparisonDeltas(
        current: DailyReportMetricSnapshot,
        average: DailyReportMetricSnapshot
    ) -> [DailyReportComparisonDelta] {
        [
            percentageDelta(current: current.feedingValue, average: average.feedingValue, color: DesignToken.easyEat),
            percentageDelta(current: current.activityValue, average: average.activityValue, color: DesignToken.easyActivity),
            percentageDelta(current: current.sleepValue, average: average.sleepValue, color: DesignToken.easySleep),
            DailyReportComparisonDelta(
                text: stateDeltaText(current: current.babyState, average: average.babyState),
                color: DesignToken.easyYearning
            )
        ]
    }

    private func percentageDelta(current: Double, average: Double, color: Color) -> DailyReportComparisonDelta {
        guard current > 0 || average > 0 else {
            return DailyReportComparisonDelta(text: "--", color: DesignToken.textSecondary)
        }
        guard average > 0 else {
            return DailyReportComparisonDelta(text: "+100%", color: color)
        }
        let percent = Int(((current - average) / average * 100).rounded())
        return DailyReportComparisonDelta(text: "\(percent >= 0 ? "+" : "")\(percent)%", color: color)
    }

    private func stateDeltaText(current: BabySubjectiveState?, average: BabySubjectiveState?) -> String {
        guard let current, let average else { return "--" }
        return current == average ? "一致" : "变化"
    }

    private var cardSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 18)
            .onEnded { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height
                guard reportDeck.count > 1,
                      abs(horizontal) > abs(vertical),
                      abs(horizontal) > 42 else { return }

                withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
                    moveSelectedReport(by: horizontal < 0 ? 1 : -1)
                }
            }
    }

    private func moveSelectedReport(by offset: Int) {
        let deck = reportDeck
        guard !deck.isEmpty else { return }
        let nextIndex = (selectedReportIndex + offset + deck.count) % deck.count
        selectedReportKey = deck[nextIndex].reportKey
    }

    private var isCardMotionEnabled: Bool {
        !reducedBuddyCardEffects && !reduceMotion
    }

    private var activeCardTilt: BuddyCardTilt {
        isCardMotionEnabled ? cardMotion.tilt : .zero
    }

    private func refreshCardMotion() {
        cardMotion.start(enabled: isCardMotionEnabled)
    }

    private func awardReportRewardIfNeeded(now: Date = Date()) {
        let activeReport = displayedReport
        guard checkedReportRewardKeys.insert(activeReport.reportKey).inserted else { return }

        _ = recruitmentStore.awardDailyTask(
            .viewReport,
            eventDate: now,
            referenceID: activeReport.reportKey,
            now: now
        )
    }

    private func dismissReport() {
        prepareReportRewardForDismissal()
        onDismiss()
    }

    private func prepareReportRewardForDismissal(now: Date = Date()) {
        let activeReport = displayedReport
        awardReportRewardIfNeeded(now: now)

        guard let transaction = ReportRewardPresentationPolicy.transactionToPresent(
            from: recruitmentStore.transactions,
            reportKey: activeReport.reportKey,
            now: now,
            lastPresentedTransactionID: lastPresentedReportRewardTransactionID
        ), preparedRewardTransactionID != transaction.id else { return }

        preparedRewardTransactionID = transaction.id
        onRewardReady(transaction)
    }
}

private struct DailyReportMetricSnapshot {
    let feedingText: String
    let activityText: String
    let sleepText: String
    let babyState: BabySubjectiveState?
    let feedingValue: Double
    let activityValue: Double
    let sleepValue: Double
}

private struct DailyReportComparisonDelta {
    let text: String
    let color: Color
}

private extension View {
    func recordTimelineActions(edit: @escaping () -> Void, delete: @escaping () -> Void) -> some View {
        self
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive, action: delete) {
                    Label("删除", systemImage: "trash")
                }

                Button(action: edit) {
                    Label("修改", systemImage: "pencil")
                }
                .tint(DesignToken.primary)
            }
            .contextMenu {
                Button(action: edit) {
                    Label("修改", systemImage: "pencil")
                }

                Button(role: .destructive, action: delete) {
                    Label("删除", systemImage: "trash")
                }
            }
    }
}

enum ActivityRecordDisplayFormatter {
    private static let knownActivityNames: Set<String> = [
        "趴卧", "翻身训练", "黑白卡", "追物训练", "抓握", "健身架", "悬挂玩具",
        "对视聊天", "照镜子", "绘本", "布书", "音乐律动", "听儿歌", "户外活动", "室内活动",
        "抚触", "排气操", "排嗝", "飞机抱", "洗澡", "剪指甲"
    ]

    static func compactSummary(from rawTitle: String) -> String {
        let names = activityNames(from: rawTitle)
        guard !names.isEmpty else {
            return rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let fullText = names.joined(separator: " ")
        guard names.count > 4 || fullText.count > 20 else { return fullText }
        return names.prefix(3).joined(separator: " ") + "...等"
    }

    private static func activityNames(from rawTitle: String) -> [String] {
        var payload = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if payload.hasPrefix("宝宝完成了") {
            payload.removeFirst("宝宝完成了".count)
        } else if payload.hasPrefix("宝宝完成") {
            payload.removeFirst("宝宝完成".count)
        }

        payload = payload
            .replacingOccurrences(of: "，", with: "、")
            .replacingOccurrences(of: ",", with: "、")

        let isCombinedTitle = payload.contains("、")
        if payload.hasSuffix("活动"), isCombinedTitle || !knownActivityNames.contains(payload) {
            payload.removeLast("活动".count)
        }

        var seen = Set<String>()
        return payload
            .split(separator: "、")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
    }
}

enum RecordHomeTimelineItem: Identifiable {
    case feeding(FeedingSession)
    case care(CareRecord)
    case growth(GrowthMetricRecord)
    case subjective(SubjectiveStateCheckIn)

    var id: String {
        switch self {
        case .feeding(let session): return "feeding-\(session.id.uuidString)"
        case .care(let record): return "care-\(record.id.uuidString)"
        case .growth(let record): return "growth-\(record.id.uuidString)"
        case .subjective(let checkIn): return "subjective-\(checkIn.id.uuidString)"
        }
    }

    var date: Date {
        switch self {
        case .feeding(let session): return session.eventDate
        case .care(let record): return record.recordedAt
        case .growth(let record): return record.recordedAt
        case .subjective(let checkIn): return checkIn.recordedAt
        }
    }

    var title: String {
        titleText
    }

    var titleText: String {
        switch self {
        case .feeding(let session): return feedingTitle(for: session)
        case .care(let record):
            switch record.kind {
            case .diaper:
                return DiaperRecordType.normalizedTitle(record.title)
            case .activity:
                return ActivityRecordDisplayFormatter.compactSummary(from: record.title)
            case .sleep:
                return sleepTitle(for: record)
            }
        case .growth(let record): return AppLocalization.format("记录 %@", record.kind.title.localized)
        case .subjective: return "状态".localized
        }
    }

    var detail: String {
        detailText
    }

    var detailText: String {
        switch self {
        case .feeding(let session): return feedingDetail(for: session)
        case .care(let record): return careDetail(for: record)
        case .growth(let record):
            let value: String
            switch record.kind {
            case .weight:
                value = AppMeasurementFormat.weight(record.value)
            case .height:
                value = AppMeasurementFormat.height(record.value)
            }
            let note = record.note.trimmingCharacters(in: .whitespacesAndNewlines)
            return note.isEmpty ? value : "\(value) · \(note)"
        case .subjective:
            return ""
        }
    }

    var timeText: String {
        switch self {
        case .feeding(let session):
            return timeText(for: session.eventDate)
        case .care(let record):
            return timeText(for: record.recordedAt)
        case .growth(let record):
            return timeText(for: record.recordedAt)
        case .subjective(let checkIn):
            return timeText(for: checkIn.recordedAt)
        }
    }

    var easyCycleStep: EasyCycleStep {
        switch self {
        case .feeding:
            return .eat
        case .care(let record):
            switch record.kind {
            case .diaper, .activity:
                return .activity
            case .sleep:
                return .sleep
            }
        case .growth, .subjective:
            return .yearning
        }
    }

    var isActivityRecord: Bool {
        guard case .care(let record) = self else { return false }
        return record.kind == .activity
    }

    var icon: String {
        switch self {
        case .feeding(let session):
            switch session.type {
            case .bottle, .breast, .solid: return "fork.knife.circle.fill"
            }
        case .care(let record):
            switch record.kind {
            case .diaper: return "drop.circle.fill"
            case .activity: return "sparkles"
            case .sleep: return "moon.circle.fill"
            }
        case .growth: return "chart.line.uptrend.xyaxis.circle.fill"
        case .subjective: return "face.smiling.inverse"
        }
    }

    var color: Color {
        switch self {
        case .feeding:
            return DesignToken.easyEat
        case .care(let record):
            switch record.kind {
            case .diaper: return DesignToken.easyActivity
            case .activity: return DesignToken.easyActivity
            case .sleep: return DesignToken.easySleep
        }
        case .growth, .subjective: return DesignToken.easyYearning
    }
    }

    private func feedingDetail(for session: FeedingSession) -> String {
        let cleanedNotes = session.notes
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
        let imageText = session.imageData == nil ? "" : "有图片".localized
        let trailingDetails = [cleanedNotes, imageText].filter { !$0.isEmpty }
        switch session.type {
        case .bottle:
            return (bottleFeedingDetails(for: session) + trailingDetails)
                .filter { !$0.isEmpty }
                .joined(separator: " · ")
        case .breast:
            return ([breastFeedingDetail(for: session)] + trailingDetails)
                .filter { !$0.isEmpty }
                .joined(separator: " · ")
        case .solid:
            return (solidFeedingDetails(for: session) + trailingDetails)
                .filter { !$0.isEmpty }
                .joined(separator: " · ")
        }
    }

    private func feedingTitle(for session: FeedingSession) -> String {
        switch session.type {
        case .bottle:
            return (session.bottleMilkType == .expressed ? "母乳瓶喂" : "瓶喂").localized
        case .breast:
            return "亲喂".localized
        case .solid:
            return "辅食".localized
        }
    }

    private func careDetail(for record: CareRecord) -> String {
        let rawDetail: String
        switch record.kind {
        case .diaper:
            rawDetail = DiaperRecordType.displayDetail(title: record.title, detail: record.detail)
        case .activity:
            rawDetail = ""
        case .sleep:
            rawDetail = sleepDetail(for: record)
        }
        let cleanedDetail = rawDetail
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
        let cleanedNote = record.note
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")

        guard !cleanedNote.isEmpty else { return cleanedDetail }
        guard !cleanedDetail.contains(cleanedNote) else { return cleanedDetail }
        return [cleanedDetail, cleanedNote].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private func bottleFeedingDetails(for session: FeedingSession) -> [String] {
        let bottleEntries = session.entries.filter { $0.type == .bottle }
        guard !bottleEntries.isEmpty else { return [] }

        let groups = Dictionary(grouping: bottleEntries, by: { $0.milkType ?? .formula })
            .compactMap { milkType, entries -> (MilkType, Int)? in
                let amount = entries.compactMap(\.bottleAmount).reduce(0, +)
                guard amount > 0 else { return nil }
                return (milkType, amount)
            }
            .sorted { $0.0.rawValue < $1.0.rawValue }

        if groups.count == 1, let only = groups.first {
            return [AppMeasurementFormat.volume(Double(only.1))]
        }

        return groups.map { milkType, amount in
            let label = (milkType == .expressed ? "母乳瓶喂" : "瓶喂").localized
            return "\(label) \(AppMeasurementFormat.volume(Double(amount)))"
        }
    }

    private func solidFeedingDetails(for session: FeedingSession) -> [String] {
        let solidEntries = session.entries.filter { $0.type == .solid }
        guard !solidEntries.isEmpty else { return [] }

        return solidEntries.map { entry in
            let food = (entry.solidFood?.displayName ?? "辅食").localized
            guard let amount = entry.solidAmount else { return food }
            let displayAmount: String
            switch entry.solidUnit ?? .g {
            case .g: displayAmount = AppMeasurementFormat.mass(amount)
            case .ml: displayAmount = AppMeasurementFormat.volume(amount)
            default:
                displayAmount = "\(AppMeasurementFormat.inputNumber(amount)) \((entry.solidUnit ?? .g).localizedDisplayName)"
            }
            return "\(food) \(displayAmount)"
        }
    }

    private func breastFeedingDetail(for session: FeedingSession) -> String {
        let breastEntries = session.entries.filter { $0.type == .breast }
        let totalMinutes = breastEntries
            .map { max($0.breastDuration ?? 0, 0) }
            .reduce(0, +)
        let leftMinutes = breastEntries
            .filter { ($0.breastSide ?? .left) == .left }
            .map { max($0.breastDuration ?? 0, 0) }
            .reduce(0, +)
        let rightMinutes = breastEntries
            .filter { $0.breastSide == .right }
            .map { max($0.breastDuration ?? 0, 0) }
            .reduce(0, +)

        let sideDetails = [
            leftMinutes > 0 ? "左\(AppQuantityFormat.compactDuration(leftMinutes))" : "",
            rightMinutes > 0 ? "右\(AppQuantityFormat.compactDuration(rightMinutes))" : ""
        ].filter { !$0.isEmpty }

        return ([AppQuantityFormat.compactDuration(totalMinutes)] + sideDetails).joined(separator: " ")
    }

    private func sleepTitle(for record: CareRecord) -> String {
        guard let minutes = SleepRecordFormatter.durationMinutes(from: record.detail) else {
            return record.title
        }
        let end = SleepRecordFormatter.endTime(start: record.recordedAt, durationMinutes: minutes)
        return SleepRecordFormatter.sleepTitle(start: record.recordedAt, end: end)
    }

    private func sleepDetail(for record: CareRecord) -> String {
        guard let minutes = SleepRecordFormatter.durationMinutes(from: record.detail) else {
            return record.detail
        }
        let end = SleepRecordFormatter.endTime(start: record.recordedAt, durationMinutes: minutes)
        return "\(AppQuantityFormat.compactDuration(minutes)) \(timeText(for: end))醒来"
    }

    private func amountText(_ value: Double) -> String {
        guard value.isFinite else { return "—" }
        if value.rounded() == value {
            return "\(Int(value))"
        }
        return String(format: "%.1f", value)
    }

    private func timeText(for date: Date) -> String {
        AppDateTimeFormat.time(date)
    }

}
