import SwiftUI
import UIKit

struct RecordHomeView: View {
    @EnvironmentObject private var feedingStore: FeedingStore
    @EnvironmentObject private var activityStore: ActivityStore
    @EnvironmentObject private var growthMetricStore: GrowthMetricStore
    @EnvironmentObject private var recruitmentStore: CompanionRecruitmentStore
    @EnvironmentObject private var easyCycleStore: EasyCycleStore
    @Environment(BabyProfileStore.self) private var profileStore

    @Binding var homeMode: RecordHomeMode
    @Binding var showBabyInfo: Bool
    @Binding var showYearningDetailRequest: Bool
    var openFeedSheet: (Date) -> Void = { _ in }
    var openActivitySheet: (Date) -> Void = { _ in }
    var openSleepSheet: (Date) -> Void = { _ in }
    var openSleepSheetForCycle: (UUID?, Date) -> Void = { _, _ in }
    var dismissQuickAddMenu: () -> Void = {}

    @State private var selectedDate = Date()
    @State private var didHandleWeekDrag = false
    @State private var weekTransitionDirection = 1
    @State private var isWalletStackExpanded = false
    @State private var headerScrollOffset: CGFloat = 0
    @State private var editingItem: RecordHomeTimelineItem?
    @State private var pendingDeleteItem: RecordHomeTimelineItem?
    @State private var presentedBabyTrendDetail: BabyTrendDetailContext?
    @State private var presentedYearningDetail: YearningDetailContext?
    @State private var now = Date()

    private var easyCycleFeedingRebuildSignature: [String] {
        feedingStore.allSessions.map { session in
            [
                session.id.uuidString,
                "\(session.createdAt.timeIntervalSince1970)",
                "\(session.startAt?.timeIntervalSince1970 ?? -1)",
                "\(session.endAt?.timeIntervalSince1970 ?? -1)"
            ].joined(separator: "|")
        }
    }

    private var easyCycleCareRebuildSignature: [String] {
        activityStore.exportCareRecords().map { record in
            [
                record.id.uuidString,
                record.kind.rawValue,
                "\(record.recordedAt.timeIntervalSince1970)",
                record.detail
            ].joined(separator: "|")
        }
    }

    private let metricTileSpacing: CGFloat = 9
    private let walletCardHorizontalPadding: CGFloat = 18
    private let walletCardHeaderIconSize: CGFloat = 30
    private let walletCardHeaderHitSize: CGFloat = 46
    private let timelineAxisWidth: CGFloat = 30
    private let timelineIconSize: CGFloat = 30

    private var homeBodyText: Color { Color(hex: "#565369") }
    private var homeMetaText: Color { Color(hex: "#8E8C9D") }
    private var homeFaintText: Color { Color(hex: "#A8A6B4") }

    init(
        homeMode: Binding<RecordHomeMode> = .constant(.basic),
        showBabyInfo: Binding<Bool>,
        showYearningDetailRequest: Binding<Bool> = .constant(false),
        openFeedSheet: @escaping (Date) -> Void = { _ in },
        openActivitySheet: @escaping (Date) -> Void = { _ in },
        openSleepSheet: @escaping (Date) -> Void = { _ in },
        openSleepSheetForCycle: @escaping (UUID?, Date) -> Void = { _, _ in },
        dismissQuickAddMenu: @escaping () -> Void = {}
    ) {
        _homeMode = homeMode
        _showBabyInfo = showBabyInfo
        _showYearningDetailRequest = showYearningDetailRequest
        self.openFeedSheet = openFeedSheet
        self.openActivitySheet = openActivitySheet
        self.openSleepSheet = openSleepSheet
        self.openSleepSheetForCycle = openSleepSheetForCycle
        self.dismissQuickAddMenu = dismissQuickAddMenu
    }

    var body: some View {
        GeometryReader { proxy in
            let metrics = RecordHomeLayoutMetrics(size: proxy.size, safeAreaInsets: proxy.safeAreaInsets, itemCount: visibleTimelineCount)
            let headerProgress = metrics.headerProgress(for: headerScrollOffset)
            let headerHeight = metrics.headerHeight(progress: headerProgress)

            ZStack(alignment: .top) {
                recordBackground.ignoresSafeArea()

                ScrollViewReader { scrollProxy in
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            Color.clear
                                .frame(height: metrics.expandedHeaderHeight)
                                .id(RecordHomeScrollTarget.rhythm)
                                .accessibilityHidden(true)

                            homeWalletCardStack
                                .padding(.top, -metrics.headerCardOverlap)
                                .padding(.bottom, metrics.rhythmBottom)
                            if homeMode == .easy, Calendar.current.isDateInToday(selectedDate) {
                                easyCycleCard
                                    .padding(.bottom, metrics.rhythmBottom)
                            }
                            recordTimelineModeSection
                        }
                        .padding(.horizontal, metrics.horizontalPadding)
                        .padding(.bottom, metrics.bottomPadding)
                        .frame(maxWidth: metrics.contentMaxWidth, alignment: .leading)
                        .frame(maxWidth: .infinity)
                        .animation(.walletCardPush, value: isWalletStackExpanded)
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
                    .onScrollGeometryChange(for: CGFloat.self) { geometry in
                        max(0, geometry.contentOffset.y + geometry.contentInsets.top)
                    } action: { _, newOffset in
                        let roundedOffset = (newOffset * 2).rounded() / 2
                        if abs(headerScrollOffset - roundedOffset) > 0.5 {
                            headerScrollOffset = roundedOffset
                            dismissQuickAddMenu()
                        }
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
        .sheet(item: $editingItem) { item in
            switch item {
            case .feeding(let session):
                FeedingEditSheet(session: session)
            case .care(let record):
                CareRecordEditSheet(record: record)
            case .growth(let record):
                GrowthMetricEditSheet(record: record)
            }
        }
        .sheet(item: $presentedBabyTrendDetail) { _ in
            BabyTrendDetailSheet(
                ageText: babyAgeText,
                guidance: ageRhythmGuidance,
                overview: babyTrendOverview,
                detailRows: babyTrendDetailRows
            )
        }
        .sheet(item: $presentedYearningDetail) { _ in
            YearningDetailSheet(
                index: todayYearningIndex,
                overview: todayRhythmOverview,
                cycleOverview: currentEasyCycleOverview,
                cycle: easyCycleStore.currentCycle(on: selectedDate),
                onPrimaryAction: handleEasyCyclePrimaryAction
            )
        }
        .onAppear {
            rebuildEasyCycles()
            awardCompleteEasyCyclesIfNeeded()
        }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { date in
            now = date
        }
        .onChange(of: selectedDate) { _, _ in
            rebuildEasyCycles()
            awardCompleteEasyCyclesIfNeeded()
        }
        .onChange(of: homeMode) { _, _ in
            rebuildEasyCycles()
            awardCompleteEasyCyclesIfNeeded()
        }
        .onChange(of: easyCycleFeedingRebuildSignature) { _, _ in
            now = Date()
            rebuildEasyCycles()
            awardCompleteEasyCyclesIfNeeded()
        }
        .onChange(of: easyCycleCareRebuildSignature) { _, _ in
            now = Date()
            rebuildEasyCycles()
            awardCompleteEasyCyclesIfNeeded()
        }
        .onChange(of: easyCycleStore.cycles.map(\.updatedAt)) { _, _ in
            awardCompleteEasyCyclesIfNeeded()
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
    }

    private var selectedSessions: [FeedingSession] {
        feedingStore.sessions(on: selectedDate)
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
        return (feedingItems + careItems + growthItems)
            .sorted { $0.date > $1.date }
    }

    private var visibleTimelineCount: Int {
        homeMode == .easy ? easyCycleTimelineItems.count : timelineItems.count
    }

    private var easyCycleTimelineItems: [EasyCycle] {
        easyCycleStore.cycles(on: selectedDate)
            .filter(easyCycleHasDisplayRecords)
    }

    private var weekDates: [Date] {
        let calendar = Calendar.current
        let start = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start
            ?? calendar.startOfDay(for: selectedDate)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private var homeWalletCardStack: some View {
        HomeWalletCardStack(isExpanded: $isWalletStackExpanded) {
            walletBabyAgeCard
        } front: {
            dayRhythmCard
        }
    }

    private func presentBabyTrendDetail() {
        lightHaptic()
        dismissQuickAddMenu()
        presentedBabyTrendDetail = BabyTrendDetailContext()
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
            dayPicker(progress: progress, scrollProxy: scrollProxy)
        }
        .padding(.horizontal, metrics.horizontalPadding)
        .padding(.top, metrics.topPadding)
        .padding(.bottom, lerp(metrics.dayPickerBottom, 4, progress))
        .frame(maxWidth: metrics.contentMaxWidth, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .top)
        .background(alignment: .top) {
            stickyHeaderBackground(progress: progress)
        }
        .shadow(color: Color(hex: "#4D4B70").opacity(0.03 + 0.07 * progress), radius: 16, y: 7)
        .zIndex(2)
    }

    @ViewBuilder
    private func profileAvatar(size: CGFloat, emojiSize: CGFloat) -> some View {
        BabyProfileAvatarView(
            profile: profileStore.currentProfile,
            size: size,
            emojiSize: emojiSize,
            lineWidth: size > 30 ? 1.5 : 1,
            motionScale: size > 30 ? 0.8 : 0.45
        )
    }

    private func dateHeader(progress: CGFloat, scrollProxy: ScrollViewProxy) -> some View {
        let titleSize = lerp(31, 21, progress)
        let avatarSize = lerp(38, 31, progress)
        let titleHeight = lerp(52, 40, progress)

        return HStack(alignment: .center) {
            Text(Calendar.current.isDateInToday(selectedDate) ? "今天" : dayTitle)
                .font(BBBFont.font(size: titleSize, weight: .heavy))
                .foregroundStyle(DesignToken.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.76)

            if !Calendar.current.isDateInToday(selectedDate) {
                Button {
                    lightHaptic()
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        selectedDate = Date()
                    }
                    scrollToRhythm(with: scrollProxy)
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(DesignToken.primary)
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(ScaleButtonStyle())
                .transition(.scale(scale: 0.86).combined(with: .opacity))
            }

            Spacer()

            NavigationLink {
                MyPageView()
            } label: {
                profileAvatar(size: avatarSize, emojiSize: avatarSize * 0.47)
                    .shadow(color: Color(hex: "#4D4B70").opacity(0.09), radius: 10, y: 5)
            }
            .buttonStyle(ScaleButtonStyle())
            .contentShape(Circle())
        }
        .frame(height: titleHeight)
    }

    private func dayPicker(progress: CGFloat, scrollProxy: ScrollViewProxy) -> some View {
        let weekID = weekDates.first ?? selectedDate
        let height = lerp(65, 54, progress)

        return ZStack {
            HStack(spacing: 0) {
                ForEach(Array(weekDates.enumerated()), id: \.element) { index, date in
                    Button {
                        lightHaptic()
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                            selectedDate = date
                        }
                        scrollToRhythm(with: scrollProxy)
                    } label: {
                        dayPill(date, progress: progress)
                    }
                    .buttonStyle(ScaleButtonStyle())

                    if index < weekDates.count - 1 {
                        Spacer(minLength: 0)
                    }
                }
            }
            .id(weekID)
            .transition(weekTransition)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipped()
        .contentShape(Rectangle())
        .animation(.spring(response: 0.34, dampingFraction: 0.88), value: weekID)
        .gesture(
            DragGesture(minimumDistance: 28, coordinateSpace: .local)
                .onChanged { value in
                    guard !didHandleWeekDrag else { return }
                    if value.translation.width <= -68 {
                        didHandleWeekDrag = true
                        shiftWeek(by: 1)
                        scrollToRhythm(with: scrollProxy)
                    } else if value.translation.width >= 68 {
                        didHandleWeekDrag = true
                        shiftWeek(by: -1)
                        scrollToRhythm(with: scrollProxy)
                    }
                }
                .onEnded { _ in
                    didHandleWeekDrag = false
                }
        )
    }

    private var dayRhythmCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                walletHeaderSymbolIcon(
                    systemName: "chart.line.uptrend.xyaxis",
                    color: DesignToken.primary,
                    onDarkSurface: false
                )
                Text("今日节奏")
                    .font(BBBFont.font(size: 16, weight: .heavy))
                    .foregroundStyle(DesignToken.textPrimary)
                Spacer()
                NavigationLink {
                    StatisticsAnalysisView()
                        .transaction { transaction in
                            transaction.animation = nil
                        }
                } label: {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(DesignToken.primary.opacity(0.78))
                        .frame(width: walletCardHeaderIconSize, height: walletCardHeaderIconSize)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                                .overlay(Circle().stroke(.white.opacity(0.78), lineWidth: 1))
                        )
                        .frame(width: walletCardHeaderHitSize, height: walletCardHeaderHitSize)
                        .contentShape(Circle())
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel("统计分析")
            }
            .frame(height: walletCardHeaderHitSize)

            Spacer(minLength: 8)

            rhythmSegmentBar

            Spacer(minLength: 6)

            todayRhythmTileRow(todayRhythmOverview)
        }
        .padding(.horizontal, walletCardHorizontalPadding)
        .padding(.top, 10)
        .padding(.bottom, 13)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            dayRhythmSurface
        )
    }

    private var dayRhythmSurface: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.white.opacity(0.70))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(DesignToken.primary.opacity(0.34), lineWidth: 1.15)
            )
            .shadow(color: DesignToken.primary.opacity(0.08), radius: 14, y: 6)
            .shadow(color: Color(hex: "#4D4B70").opacity(0.045), radius: 18, y: 8)
    }

    private var easyCycleCard: some View {
        let overview = currentEasyCycleOverview

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
                                .foregroundStyle(.white.opacity(0.94))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(DesignToken.primary.opacity(0.70)))

                            Text(overview.guidance)
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
                    .shadow(color: Color(hex: "#4D4B70").opacity(0.045), radius: 18, y: 8)
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
            .shadow(color: Color(hex: "#5E4AA8").opacity(0.08), radius: 8, y: 4)
    }

    private var easyCyclePlaceholderBackground: some View {
        Image("easy_cycle_card_background")
            .resizable()
            .scaledToFill()
            .overlay(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0),
                        Color(hex: "#EEE8FF").opacity(0.10),
                        Color(hex: "#EEE8FF").opacity(0.30)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }

    private func easyCycleProgress(_ overview: EasyCycleOverview) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(EasyCycleStep.allCases) { step in
                easyCycleStepNode(step, overview: overview)

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

    private func easyCycleStepNode(_ step: EasyCycleStep, overview: EasyCycleOverview) -> some View {
        let state = overview.state(for: step)
        let hasData = overview.hasData(for: step)
        let nodeSize: CGFloat = state == .current ? 36 : 34
        let letterSize: CGFloat = state == .current ? 16 : 15

        return Button {
            openEasyCycleStep(step)
        } label: {
            VStack(spacing: 7) {
                ZStack(alignment: .topTrailing) {
                    Circle()
                        .fill(.white.opacity(state == .current ? 0.78 : 0.60))
                        .frame(width: nodeSize, height: nodeSize)
                        .overlay(
                            Circle()
                                .stroke(step.color.opacity(state == .current ? 0.94 : 0.74), lineWidth: state == .current ? 1.9 : 1.35)
                        )
                        .shadow(color: step.color.opacity(state == .current ? 0.18 : 0.10), radius: state == .current ? 8 : 6, y: 3)

                    if step == .yearning {
                        easyCycleYearningProgressNode(
                            progress: overview.yearningProgress,
                            size: nodeSize,
                            letterSize: letterSize,
                            state: state
                        )
                    } else {
                        Text(step.letter)
                            .font(BBBFont.font(size: letterSize, weight: .heavy))
                            .foregroundStyle(step.color)
                            .shadow(color: step.color.opacity(state == .current ? 0.18 : 0.10), radius: 4, y: 1.5)
                            .frame(width: nodeSize, height: nodeSize)
                    }

                    if hasData || step.showsEmptyActionBadge {
                        Image(systemName: hasData ? "checkmark" : "plus")
                            .font(.system(size: hasData ? 7 : 8, weight: .black))
                            .foregroundStyle(hasData ? .white : step.color)
                            .frame(width: 15, height: 15)
                            .background(
                                Circle()
                                    .fill(hasData ? step.color : .white.opacity(0.90))
                            )
                            .overlay(
                                Circle()
                                    .stroke(hasData ? .white.opacity(0.78) : step.color.opacity(0.58), lineWidth: 1)
                            )
                            .offset(x: 2, y: -2)
                    }
                }
                .frame(width: 40, height: 36)

                VStack(spacing: 3) {
                    Text(step.title)
                        .font(BBBFont.font(size: 10, weight: .heavy))
                        .foregroundStyle(DesignToken.textPrimary)
                        .lineLimit(1)

                    Text(overview.value(for: step))
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
        .accessibilityLabel("\(step.title)，\(overview.value(for: step))")
    }

    private func easyCycleYearningProgressNode(
        progress: Double,
        size: CGFloat,
        letterSize: CGFloat,
        state: EasyCycleStepState
    ) -> some View {
        let clampedProgress = min(max(progress, 0), 1)

        return ZStack {
            Circle()
                .stroke(DesignToken.easyYearning.opacity(0.16), lineWidth: 3.2)
                .frame(width: max(size - 7, 0), height: max(size - 7, 0))

            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(
                    DesignToken.easyYearning,
                    style: StrokeStyle(lineWidth: 3.2, lineCap: .round)
                )
                .frame(width: max(size - 7, 0), height: max(size - 7, 0))
                .rotationEffect(.degrees(-90))
                .shadow(color: DesignToken.easyYearning.opacity(state == .current ? 0.20 : 0.12), radius: 3, y: 1)

            Text("Y")
                .font(BBBFont.font(size: max(letterSize - 2, 10), weight: .heavy))
                .foregroundStyle(DesignToken.easyYearning)
        }
        .frame(width: size, height: size)
    }

    private func openEasyCycleStep(_ step: EasyCycleStep, cycleID: UUID? = nil) {
        switch step {
        case .eat:
            openFeedSheet(selectedDate)
        case .activity:
            openActivitySheet(selectedDate)
        case .sleep:
            openSleepSheetForCycle(cycleID, selectedDate)
        case .yearning:
            break
        }
    }

    private func easyCycleLineColor(after step: EasyCycleStep, overview: EasyCycleOverview) -> Color {
        step.color.opacity(step.index < overview.currentStep.index ? 0.46 : 0.28)
    }

    private var rhythmSegmentBar: some View {
        TodayRhythmMinimalTimeline(
            date: selectedDate,
            spans: dailyRhythmSpans,
            height: 58
        )
            .padding(.top, 3)
            .padding(.bottom, 3)
    }

    private func walletHeaderSymbolIcon(systemName: String, color: Color, onDarkSurface: Bool) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(onDarkSurface ? .white : .white.opacity(0.94))
            .frame(width: 30, height: 30)
            .background(
                Circle()
                    .fill(
                        onDarkSurface
                        ? AnyShapeStyle(DesignToken.primaryGradient)
                        : AnyShapeStyle(
                            LinearGradient(
                                colors: [
                                    color.opacity(0.48),
                                    Color(hex: "#D8B7EA").opacity(0.46)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    )
                    .overlay(
                        Circle()
                            .fill(Color.white.opacity(onDarkSurface ? 0.10 : 0.18))
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(onDarkSurface ? 0.94 : 0.82), lineWidth: 1)
                    )
            )
            .shadow(
                color: (onDarkSurface ? Color.black : color).opacity(onDarkSurface ? 0.18 : 0.12),
                radius: onDarkSurface ? 8 : 7,
                y: onDarkSurface ? 4 : 3
            )
    }

    private var feedingSummary: some View {
        HStack(alignment: .center, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(currentClockEmoji)
                    .font(.system(size: 14, weight: .semibold))
                    .baselineOffset(-0.5)
                Text(currentClockText)
                    .font(BBBFont.font(size: 16, weight: .heavy))
                    .foregroundStyle(DesignToken.textPrimary)
                    .monospacedDigit()
            }
            .lineLimit(1)
            .layoutPriority(1)

            Spacer(minLength: 3)

            recencyChip(
                badge: "E",
                value: compactElapsedSummaryText(since: lastFeedingDateForSummary),
                color: DesignToken.easyEat
            )
            recencyChip(
                badge: "A",
                value: compactElapsedSummaryText(since: lastActivityDateForSummary),
                color: DesignToken.easyActivity
            )
            recencyChip(
                badge: "S",
                value: compactElapsedSummaryText(since: lastSleepDateForSummary),
                color: DesignToken.easySleep
            )
        }
    }

    private func recencyChip(badge: String, value: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(badge)
                .font(BBBFont.font(size: 7, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 12, height: 12)
                .background(Circle().fill(color.opacity(0.92)))

            Text(value)
                .font(BBBFont.font(size: 9, weight: .heavy))
                .foregroundStyle(homeBodyText)
                .monospacedDigit()
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .padding(.leading, 4)
        .padding(.trailing, 5.5)
        .frame(height: 24)
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.46))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(color.opacity(0.18), lineWidth: 1)
                )
        )
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
                        .stroke(.white.opacity(0.9), lineWidth: 1)
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
                                Color.white.opacity(0.40),
                                Color.white.opacity(0.08),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(Color.white.opacity(0.72), lineWidth: 0.9)
            )
            .shadow(color: Color.white.opacity(0.22), radius: 1, y: -0.5)
            .frame(width: size, height: size)
    }

    private func todayRhythmTileRow(_ overview: TodayRhythmOverview) -> some View {
        GeometryReader { proxy in
            let spacing = metricTileSpacing
            let tileWidth = max((proxy.size.width - spacing * 3) / 4, 0)

            HStack(spacing: spacing) {
                babyTrendTile(
                    badge: "E",
                    title: "喂养",
                    value: overview.feedingText,
                    color: DesignToken.easyEat,
                    style: .light
                )
                .frame(width: tileWidth)
                .onTapGesture {
                    openFeedSheet(selectedDate)
                }

                babyTrendTile(
                    badge: "A",
                    title: "活动",
                    value: overview.activityText,
                    color: DesignToken.easyActivity,
                    style: .light
                )
                .frame(width: tileWidth)
                .onTapGesture {
                    openActivitySheet(selectedDate)
                }

                babyTrendTile(
                    badge: "S",
                    title: "睡眠",
                    value: overview.sleepText,
                    color: DesignToken.easySleep,
                    style: .light
                )
                .frame(width: tileWidth)
                .onTapGesture {
                    openSleepSheet(selectedDate)
                }

                babyTrendTile(
                    badge: "Y",
                    title: "状态",
                    value: overview.yText,
                    color: overview.yColor,
                    showsInfo: true,
                    style: .light
                )
                .frame(width: tileWidth)
            }
        }
        .frame(height: 44)
    }

    private var careGuidanceCard: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 7) {
                    profileAvatar(size: 24, emojiSize: 13)
                        .overlay(Circle().stroke(.white.opacity(0.96), lineWidth: 1))
                        .shadow(color: Color(hex: "#7E5DE8").opacity(0.10), radius: 7, y: 3)

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
            glassSurface(cornerRadius: 24, whiteOpacity: 0.52, shadowOpacity: 0.085)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    DesignToken.primary.opacity(0.10),
                                    Color.white.opacity(0.18),
                                    Color(hex: "#CED6F4").opacity(0.14)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(.white.opacity(0.78), lineWidth: 1.1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var walletBabyAgeCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(feedingGuidanceText)
                .font(BBBFont.font(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.92))
                .lineSpacing(3)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            babyTrendMetricGrid
        }
        .padding(.horizontal, walletCardHorizontalPadding)
        .padding(.top, 68)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .overlay(alignment: .topLeading) {
            walletBabyAgeTitle
                .frame(height: walletCardHeaderHitSize)
                .padding(.horizontal, walletCardHorizontalPadding)
        }
        .background(walletBabyAgeSurface)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: Color(hex: "#6D4DDB").opacity(0.22), radius: 20, y: 11)
        .overlay(alignment: .top) {
            walletBabyAgeToggleArea
        }
    }

    private var walletBabyAgeToggleArea: some View {
        Rectangle()
            .fill(Color.black.opacity(0.001))
            .frame(height: 104)
            .contentShape(Rectangle())
            .onTapGesture {
                toggleWalletStack()
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(isWalletStackExpanded ? "收起宝宝月龄卡" : "展开宝宝月龄卡")
    }

    private var babyTrendMetricGrid: some View {
        let overview = babyTrendOverview

        return VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Text("近7日均")
                    .font(BBBFont.font(size: 10, weight: .heavy))
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(1)

                Button {
                    presentBabyTrendDetail()
                } label: {
                    Image(systemName: "exclamationmark")
                        .font(.system(size: 6, weight: .heavy))
                        .foregroundStyle(.white.opacity(0.92))
                        .frame(width: 12, height: 12)
                        .background(
                            Circle()
                                .fill(.white.opacity(0.16))
                                .overlay(Circle().stroke(.white.opacity(0.48), lineWidth: 0.8))
                        )
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel("查看近7日吃拉玩睡详情")

                Spacer(minLength: 0)
            }

            babyTrendTileRow(overview)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func babyTrendTileRow(_ overview: BabyTrendOverview) -> some View {
        GeometryReader { proxy in
            let spacing = metricTileSpacing
            let tileWidth = max((proxy.size.width - spacing * 3) / 4, 0)

            HStack(spacing: spacing) {
                babyTrendTile(
                    badge: "E",
                    title: "喂养",
                    value: overview.feedingText,
                    color: DesignToken.easyEat
                )
                .frame(width: tileWidth)
                .onTapGesture {
                    presentBabyTrendDetail()
                }

                babyTrendTile(
                    badge: "A",
                    title: "活动",
                    value: overview.activityText,
                    color: DesignToken.easyActivity
                )
                .frame(width: tileWidth)
                .onTapGesture {
                    presentBabyTrendDetail()
                }

                babyTrendTile(
                    badge: "S",
                    title: "睡眠",
                    value: overview.sleepText,
                    color: DesignToken.easySleep
                )
                .frame(width: tileWidth)
                .onTapGesture {
                    presentBabyTrendDetail()
                }

                babyTrendTile(
                    badge: "Y",
                    title: "状态",
                    value: overview.yText,
                    color: overview.yColor
                )
                .frame(width: tileWidth)
                .onTapGesture {
                    presentBabyTrendDetail()
                }
            }
        }
        .frame(height: 44)
    }

    private func babyTrendTile(
        badge: String,
        title: String,
        value: String,
        color: Color,
        showsInfo: Bool = false,
        style: RhythmMetricTileStyle = .dark
    ) -> some View {
        VStack(alignment: .center, spacing: 3) {
            HStack(spacing: 3) {
                Text(badge)
                    .font(BBBFont.font(size: 8, weight: .heavy))
                    .foregroundStyle(style.iconColor(accent: color))
                    .frame(width: 12, height: 12)
                    .background(Circle().fill(style.badgeFillColor(accent: color)))

                Text(title)
                    .font(BBBFont.font(size: 8.5, weight: .heavy))
                    .foregroundStyle(style.titleColor)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)

            babyTrendTileValue(value, style: style, infoAccent: color, showsInfo: showsInfo)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .center)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(style.fillColor(accent: color))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(style.overlayColor(accent: color))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(style.strokeColor(accent: color), lineWidth: 1)
                )
        )
    }

    private func babyTrendTileValue(
        _ value: String,
        style: RhythmMetricTileStyle,
        infoAccent: Color,
        showsInfo: Bool
    ) -> some View {
        let chunks = babyTrendValueChunks(value)

        return HStack(alignment: .firstTextBaseline, spacing: 1) {
            ForEach(chunks) { chunk in
                HStack(alignment: .firstTextBaseline, spacing: 0.5) {
                    if !chunk.separator.isEmpty {
                        Text(chunk.separator)
                            .font(BBBFont.font(size: 8, weight: .heavy))
                            .foregroundStyle(style.prefixColor)
                    }

                    if !chunk.prefix.isEmpty {
                        Text(chunk.prefix)
                            .font(BBBFont.font(size: 8, weight: .heavy))
                            .foregroundStyle(style.prefixColor)
                    }

                    Text(chunk.main)
                        .font(BBBFont.font(size: 12.5, weight: .heavy))
                        .foregroundStyle(style.mainColor)

                    if !chunk.unit.isEmpty {
                        Text(chunk.unit)
                            .font(BBBFont.font(size: 8, weight: .heavy))
                            .foregroundStyle(style.unitColor)
                    }
                }
            }

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
        .lineLimit(1)
        .minimumScaleFactor(0.48)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func babyTrendValueChunks(_ value: String) -> [BabyTrendValueChunk] {
        guard value != "--" else { return [BabyTrendValueChunk(main: "--")] }

        return value
            .split(separator: "+", omittingEmptySubsequences: false)
            .enumerated()
            .map { index, part in
                var working = String(part)
                var prefix = ""
                if working.hasPrefix("~") {
                    prefix = "~"
                    working.removeFirst()
                }

                let digits = working.prefix { character in
                    character.isNumber || character == "."
                }
                let main = String(digits)
                let unit = String(working.dropFirst(main.count))

                guard !main.isEmpty else {
                    return BabyTrendValueChunk(
                        separator: index == 0 ? "" : "+",
                        prefix: prefix,
                        main: working,
                        unit: ""
                    )
                }
                return BabyTrendValueChunk(
                    separator: index == 0 ? "" : "+",
                    prefix: prefix,
                    main: main,
                    unit: unit
                )
            }
    }

    private var walletBabyAgeTitle: some View {
        HStack(spacing: 8) {
            walletHeaderAvatar

            Text(babyAgeText)
                .font(BBBFont.font(size: 16, weight: .heavy))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.76)
                .shadow(color: Color.black.opacity(0.16), radius: 4, y: 2)

            Spacer(minLength: 8)

            walletStackToggleIndicator
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var walletHeaderAvatar: some View {
        profileAvatar(size: 30, emojiSize: 15)
            .overlay(Circle().stroke(.white.opacity(0.96), lineWidth: 1))
            .shadow(color: Color.black.opacity(0.18), radius: 8, y: 4)
    }

    private var walletStackToggleIndicator: some View {
        Button {
            toggleWalletStack()
        } label: {
            Image(systemName: isWalletStackExpanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(.white.opacity(0.94))
                .frame(width: walletCardHeaderIconSize, height: walletCardHeaderIconSize)
                .background(
                    Circle()
                        .fill(.white.opacity(0.16))
                        .overlay(Circle().stroke(.white.opacity(0.30), lineWidth: 1))
                )
                .shadow(color: Color.black.opacity(0.12), radius: 7, y: 3)
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
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(hex: "#7A5BEF"),
                        Color(hex: "#9D7BFF"),
                        Color(hex: "#6B8EF6")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.24),
                                Color.white.opacity(0.05),
                                Color(hex: "#3B2A8F").opacity(0.18)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(.white.opacity(0.64), lineWidth: 1.1)
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

    private var recordTimelineModeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(homeMode == .easy ? "今日 EASY 循环" : "今日单条记录")
                    .font(BBBFont.font(size: 16, weight: .heavy))
                    .foregroundStyle(DesignToken.textPrimary)
                Spacer()
                timelineModeToggleButton
            }
            .padding(.horizontal, 2)

            if homeMode == .easy {
                easyCycleTimelineSection
            } else {
                timelineSection
            }
        }
    }

    private var timelineModeToggleButton: some View {
        Button {
            lightHaptic()
            dismissQuickAddMenu()
            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                homeMode = homeMode == .easy ? .basic : .easy
            }
        } label: {
            Text(homeMode == .easy ? "单条模式" : "EASY模式")
                .font(BBBFont.font(size: 11, weight: .heavy))
                .foregroundStyle(homeMode == .easy ? DesignToken.textSecondary : DesignToken.primary)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.68))
                        .overlay(
                            Capsule()
                                .stroke((homeMode == .easy ? Color.white : DesignToken.primary).opacity(0.46), lineWidth: 1)
                        )
                        .shadow(color: Color(hex: "#4D4B70").opacity(0.055), radius: 9, y: 4)
                )
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(homeMode == .easy ? "切换到单条模式" : "切换到EASY模式")
    }

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            feedingSummary

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
            .padding(.horizontal, 18)
            .padding(.top, timelineItems.isEmpty ? 16 : 18)
            .padding(.bottom, 18)
            .background(
                glassSurface(cornerRadius: 28, whiteOpacity: 0.70, shadowOpacity: 0.085)
            )
        }
    }

    private var easyCycleTimelineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                if easyCycleTimelineItems.isEmpty {
                    emptyEasyCycleTimeline
                } else {
                    ForEach(easyCycleTimelineItems) { cycle in
                        easyCycleTimelineCard(cycle)
                    }
                }
            }
        }
    }

    private var emptyEasyCycleTimeline: some View {
        HStack(alignment: .center, spacing: 10) {
            timelineListIcon(
                assetName: "record_action_easy_yearning_icon",
                systemName: "heart.text.square.fill",
                color: DesignToken.easyYearning,
                size: timelineIconSize,
                cornerRadius: 11,
                assetSize: 20
            )

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
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.68))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(.white.opacity(0.72), lineWidth: 1)
                )
                .shadow(color: Color(hex: "#4D4B70").opacity(0.06), radius: 14, y: 7)
        )
    }

    private func easyCycleTimelineCard(_ cycle: EasyCycle) -> some View {
        let rows = easyCycleTimelineRows(for: cycle)

        return VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .center, spacing: 10) {
                Text(easyCycleOrdinalText(cycle))
                    .font(BBBFont.font(size: 12, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .frame(height: 30)
                    .background(
                        Capsule()
                            .fill(LinearGradient(colors: [DesignToken.primary, Color(hex: "#8F6CFF")], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .overlay(
                                Capsule()
                                    .stroke(.white.opacity(0.42), lineWidth: 1)
                            )
                            .shadow(color: Color(hex: "#7E5DE8").opacity(0.18), radius: 9, y: 4)
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
                    easyCycleTimelineRow(row, cycleID: cycle.id, isLast: index == rows.count - 1)
                }
            }
        }
        .padding(15)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.74))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(.white.opacity(0.74), lineWidth: 1)
                )
                .shadow(color: Color(hex: "#4D4B70").opacity(0.08), radius: 16, y: 8)
        )
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func easyCycleTimelineRow(_ row: EasyCycleTimelineRow, cycleID: UUID, isLast: Bool) -> some View {
        let detailCount = max(row.detailItems.count, 1)
        let connectorHeight = max(48, CGFloat(detailCount) * 37 + 12)

        return HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Button {
                    openEasyCycleStep(row.step, cycleID: cycleID)
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Circle()
                            .fill(.white.opacity(0.82))
                            .frame(width: 36, height: 36)
                            .overlay(Circle().stroke(row.step.color.opacity(0.72), lineWidth: 1.2))
                            .shadow(color: row.step.color.opacity(0.08), radius: 7, y: 4)

                        Text(row.step.letter)
                            .font(BBBFont.font(size: 14, weight: .heavy))
                            .foregroundStyle(row.step.color)
                            .frame(width: 36, height: 36)

                        Image(systemName: row.isComplete ? "checkmark" : "plus")
                            .font(.system(size: row.isComplete ? 7 : 8, weight: .black))
                            .foregroundStyle(row.isComplete ? .white : row.step.color)
                            .frame(width: 15, height: 15)
                            .background(Circle().fill(row.isComplete ? row.step.color : .white.opacity(0.92)))
                            .overlay(Circle().stroke(row.isComplete ? .white.opacity(0.78) : row.step.color.opacity(0.52), lineWidth: 1))
                            .offset(x: 2, y: -2)
                    }
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel("\(row.step.title)，继续记录")

                if !isLast {
                    Rectangle()
                        .fill(row.step.color.opacity(0.22))
                        .frame(width: 1.2, height: connectorHeight)
                        .padding(.top, 4)
                        .padding(.bottom, 4)
                }
            }
            .frame(width: 40)

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(row.title)
                        .font(BBBFont.font(size: 13.5, weight: .heavy))
                        .foregroundStyle(DesignToken.textPrimary)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Text(row.timeText)
                        .font(BBBFont.font(size: 10.5, weight: .heavy))
                        .foregroundStyle(homeMetaText)
                        .lineLimit(1)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    openEasyCycleStep(row.step, cycleID: cycleID)
                }

                if row.detailItems.isEmpty {
                    Text(row.primaryText)
                        .font(BBBFont.font(size: 12, weight: .semibold))
                        .foregroundStyle(homeBodyText)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(1)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(row.detailItems) { detail in
                            easyCycleTimelineDetailRow(detail, step: row.step)
                        }
                    }
                    .padding(.top, 0)
                }

                if !row.secondaryText.isEmpty {
                    Text(row.secondaryText)
                        .font(BBBFont.font(size: 11, weight: .semibold))
                        .foregroundStyle(homeMetaText)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(1)
                }
            }
            .padding(.top, 1)
        }
        .padding(.bottom, isLast ? 0 : 2)
        .contentShape(Rectangle())
        .onTapGesture {
            if row.detailItems.isEmpty {
                openEasyCycleStep(row.step, cycleID: cycleID)
            }
        }
    }

    private func easyCycleTimelineDetailRow(_ detail: EasyCycleTimelineDetailItem, step: EasyCycleStep) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Text(detail.timeText)
                .font(BBBFont.font(size: 8.8, weight: .heavy))
                .foregroundStyle(step.color.opacity(0.78))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .padding(.horizontal, 6)
                .frame(width: 47, height: 19)
                .background(
                    Capsule()
                        .fill(step.color.opacity(0.07))
                        .overlay(Capsule().stroke(step.color.opacity(0.13), lineWidth: 0.8))
                )

            Text(detail.bodyText)
                .font(BBBFont.font(size: 12.2, weight: .heavy))
                .foregroundStyle(homeBodyText)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
                .lineSpacing(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            easyCycleTimelineDetailMenu(for: detail.item, color: step.color)
                .alignmentGuide(.firstTextBaseline) { dimensions in
                    dimensions[VerticalAlignment.center]
                }
        }
        .padding(.vertical, 5)
        .padding(.leading, 0)
        .padding(.trailing, 4)
        .frame(minHeight: 34)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.24))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.38), lineWidth: 0.7)
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func easyCycleTimelineDetailMenu(for item: RecordHomeTimelineItem, color: Color) -> some View {
        Menu {
            Button {
                editingItem = item
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
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(color.opacity(0.70))
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color.white.opacity(0.46)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("更多操作")
    }

    private func easyCycleSummaryPill(step: EasyCycleStep, value: String) -> some View {
        VStack(spacing: 4) {
            Text(step.letter)
                .font(BBBFont.font(size: 11, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(step.color.opacity(0.92)))
            Text(value)
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
            return "本轮循环"
        }
        return "第\(index + 1)轮循环"
    }

    private func easyCycleTimelineRows(for cycle: EasyCycle) -> [EasyCycleTimelineRow] {
        let sessions = cycleFeedingSessions(for: cycle)
        let careRecords = cycleCareRecords(for: cycle)
        let activityRecords = careRecords.filter { $0.kind != .sleep }
        let sleepRecords = careRecords.filter { $0.kind == .sleep }

        return [
            EasyCycleTimelineRow(
                step: .eat,
                title: sessions.isEmpty ? "喂养 待记录" : "喂养 \(sessions.count)次",
                primaryText: sessions.isEmpty ? "醒来先吃 吃得饱饱" : "",
                secondaryText: "",
                timeText: sessions.isEmpty ? easyCycleEmptyElapsedText(step: .eat, before: cycle.startedAt) : easyCycleFeedingTotalText(sessions),
                detailItems: sessions.isEmpty ? [] : easyCycleFeedingDetails(sessions),
                isComplete: !sessions.isEmpty
            ),
            EasyCycleTimelineRow(
                step: .activity,
                title: activityRecords.isEmpty ? "活动 待记录" : "活动 \(activityRecords.count)次",
                primaryText: activityRecords.isEmpty ? "清醒活动 玩得开心" : "",
                secondaryText: "",
                timeText: activityRecords.isEmpty ? easyCycleEmptyElapsedText(step: .activity, before: cycle.startedAt) : "共\(easyCycleActivityTypeCount(activityRecords))项",
                detailItems: activityRecords.isEmpty ? [] : easyCycleActivityDetails(activityRecords),
                isComplete: !activityRecords.isEmpty
            ),
            EasyCycleTimelineRow(
                step: .sleep,
                title: sleepRecords.isEmpty ? "睡眠 待记录" : "睡眠 \(sleepRecords.count)次",
                primaryText: sleepRecords.isEmpty ? "大脑升级 睡得香甜" : "",
                secondaryText: "",
                timeText: sleepRecords.isEmpty ? easyCycleEmptyElapsedText(step: .sleep, before: cycle.startedAt) : easyCycleSleepTotalText(sleepRecords),
                detailItems: sleepRecords.isEmpty ? [] : easyCycleSleepDetails(sleepRecords),
                isComplete: !sleepRecords.isEmpty
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
        if breastCount > 0 { parts.append("母乳\(breastCount)次") }
        if bottleCount > 0 { parts.append("奶瓶\(bottleCount)次") }
        if solidCount > 0 { parts.append("辅食\(solidCount)次") }
        if milkML > 0 { parts.append("奶瓶\(milkML)ml") }
        if breastMinutes > 0 { parts.append("亲喂\(breastMinutes)min") }
        if solidAmount > 0 { parts.append("辅食\(easyCycleAmountText(solidAmount))g") }
        return parts.isEmpty ? "喂养已记录" : parts.joined(separator: " · ")
    }

    private func easyCycleFeedingTotalText(_ sessions: [FeedingSession]) -> String {
        let bottleAmount = sessions.reduce(0) { $0 + $1.totalBottleAmount }
        let breastMinutes = sessions.reduce(0) { $0 + $1.totalBreastDuration }
        let breastEquivalentML = Int(round(Double(breastMinutes) * breastEquivalentRate))
        let milkML = bottleAmount + breastEquivalentML
        let solidAmount = sessions.reduce(0) { $0 + $1.totalSolidAmount }
        var parts: [String] = []
        if milkML > 0 { parts.append("共\(milkML)ml") }
        if solidAmount > 0 { parts.append("辅食\(easyCycleAmountText(solidAmount))g") }
        return parts.isEmpty ? "已记录" : parts.joined(separator: " · ")
    }

    private func easyCycleFeedingDetails(_ sessions: [FeedingSession]) -> [EasyCycleTimelineDetailItem] {
        sessions
            .sorted { ($0.startAt ?? $0.createdAt) < ($1.startAt ?? $1.createdAt) }
            .flatMap { easyCycleFeedingDetails(for: $0) }
    }

    private func easyCycleFeedingTypesSummary(_ sessions: [FeedingSession]) -> String {
        let firstTimes = sessions
            .prefix(2)
            .map { easyCycleClockText($0.startAt ?? $0.createdAt) }
            .joined(separator: "、")
        return firstTimes.isEmpty ? "喂养记录已归入本轮" : "记录时间 \(firstTimes)"
    }

    private func easyCycleFeedingDetails(for session: FeedingSession) -> [EasyCycleTimelineDetailItem] {
        let eventTime = easyCycleClockText(session.startAt ?? session.createdAt)
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
            let sideText = [leftMinutes > 0 ? "左\(leftMinutes)m" : "", rightMinutes > 0 ? "右\(rightMinutes)m" : ""]
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            let breastText = sideText.isEmpty ? "亲喂 \(totalBreastMinutes)m" : "亲喂 \(sideText)"
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
            let label = milkType == .expressed ? "母乳瓶喂" : "瓶喂"
            details.append(EasyCycleTimelineDetailItem(
                id: "\(session.id.uuidString)-bottle-\(milkType.rawValue)",
                timeText: eventTime,
                bodyText: "\(label) \(amount)ml",
                item: item
            ))
        }

        let solidEntries = session.entries.filter { $0.type == .solid }
        for (index, entry) in solidEntries.enumerated() {
            let food = entry.solidFood?.displayName ?? "辅食"
            let amount = entry.solidAmount.map(easyCycleAmountText) ?? ""
            let unit = entry.solidUnit?.displayName ?? ""
            details.append(EasyCycleTimelineDetailItem(
                id: "\(session.id.uuidString)-solid-\(index)",
                timeText: eventTime,
                bodyText: "辅食 \(food)\(amount)\(unit)",
                item: item
            ))
        }

        if details.isEmpty {
            return [EasyCycleTimelineDetailItem(
                id: "\(session.id.uuidString)-feeding",
                timeText: eventTime,
                bodyText: "喂养已记录",
                item: item
            )]
        }

        return details
    }

    private func easyCycleActivityDetail(_ records: [CareRecord]) -> String {
        guard !records.isEmpty else { return "点 A 补充本轮活动/护理记录" }
        return "尿布：" + records
            .map { "\(DiaperRecordType.normalizedTitle($0.title))（\(easyCycleClockText($0.recordedAt))）" }
            .joined(separator: " · ")
    }

    private func easyCycleActivitySummary(_ records: [CareRecord]) -> String {
        let peeCount = records.filter { DiaperRecordType.normalizedTitle($0.title).contains("尿") }.count
        let poopCount = records.filter { DiaperRecordType.normalizedTitle($0.title).contains("拉") }.count
        var parts = ["尿布\(records.count)次"]
        if peeCount > 0 { parts.append("尿\(peeCount)") }
        if poopCount > 0 { parts.append("拉\(poopCount)") }
        return parts.joined(separator: " · ")
    }

    private func easyCycleActivityTypeCount(_ records: [CareRecord]) -> Int {
        Set(records.map(easyCycleActivityTypeName)).count
    }

    private func easyCycleActivityTypeName(_ record: CareRecord) -> String {
        switch record.kind {
        case .diaper:
            return "尿布"
        case .activity:
            return record.title
        case .sleep:
            return "睡眠"
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
                    bodyText = DiaperRecordType.normalizedTitle(record.title)
                case .activity:
                    bodyText = easyCycleActivityLineText(record)
                case .sleep:
                    bodyText = "睡眠"
                }
                return EasyCycleTimelineDetailItem(
                    id: record.id.uuidString,
                    timeText: time,
                    bodyText: bodyText,
                    item: item
                )
            }
    }

    private func easyCycleActivityLineText(_ record: CareRecord) -> String {
        if record.title.hasPrefix("宝宝完成了") {
            return record.title
        }
        let detail = record.detail
            .replacingOccurrences(of: " 分钟", with: "分钟")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !detail.isEmpty else { return record.title }
        return "\(record.title)\(detail)"
    }

    private func easyCycleSleepDetail(_ records: [CareRecord]) -> String {
        guard !records.isEmpty else { return "点 S 补充本轮睡眠记录" }
        return records
            .compactMap { record -> String? in
                guard let minutes = SleepRecordFormatter.durationMinutes(from: record.detail) else { return nil }
                let end = SleepRecordFormatter.endTime(start: record.recordedAt, durationMinutes: minutes)
                let title = minutes >= 180 ? "夜睡" : "小睡"
                return "\(title) \(easyCycleClockText(record.recordedAt))-\(easyCycleClockText(end))，\(easyCycleDurationText(minutes))"
            }
            .joined(separator: "\n")
    }

    private func easyCycleSleepSummary(_ records: [CareRecord]) -> String {
        let totalMinutes = records.reduce(0) { $0 + (SleepRecordFormatter.durationMinutes(from: $1.detail) ?? 0) }
        let nightCount = records.filter { (SleepRecordFormatter.durationMinutes(from: $0.detail) ?? 0) >= 180 }.count
        let napCount = max(records.count - nightCount, 0)
        var parts = ["共\(easyCycleDurationText(totalMinutes))", "\(records.count)段"]
        if napCount > 0 { parts.append("小睡\(napCount)") }
        if nightCount > 0 { parts.append("夜睡\(nightCount)") }
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
                        bodyText: "睡眠已记录",
                        item: item
                    )
                }
                let title = minutes >= 180 ? "夜睡" : "小睡"
                return EasyCycleTimelineDetailItem(
                    id: record.id.uuidString,
                    timeText: easyCycleClockText(record.recordedAt),
                    bodyText: "\(title)\(easyCycleDurationText(minutes))",
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
        guard let first = dates.min(), let last = dates.max() else { return "待记录" }
        if abs(last.timeIntervalSince(first)) < 60 {
            return easyCycleClockText(first)
        }
        return "\(easyCycleClockText(first))-\(easyCycleClockText(last))"
    }

    private func easyCycleDurationText(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes)分钟" }
        let hours = minutes / 60
        let remainder = minutes % 60
        return remainder == 0 ? "\(hours)小时" : "\(hours)小时\(remainder)分"
    }

    private func easyCycleAmountText(_ value: Double) -> String {
        if value.rounded() == value {
            return "\(Int(value))"
        }
        return String(format: "%.1f", value)
    }

    private func easyCycleEmptyElapsedText(step: EasyCycleStep, before date: Date) -> String {
        guard let lastDate = lastRecordDate(for: step, before: date) else {
            return "距上次暂无"
        }
        let minutes = max(Int(date.timeIntervalSince(lastDate) / 60), 0)
        return "距上次\(easyCycleCompactDurationText(minutes))"
    }

    private func lastRecordDate(for step: EasyCycleStep, before date: Date) -> Date? {
        switch step {
        case .eat:
            return selectedSessions
                .filter { $0.createdAt < date }
                .map(\.createdAt)
                .max()
        case .activity:
            return selectedCareRecordsForSleepSummary
                .filter { $0.kind == .diaper && $0.recordedAt < date }
                .map(\.recordedAt)
                .max()
        case .sleep:
            return selectedCareRecordsForSleepSummary
                .filter { $0.kind == .sleep && $0.recordedAt < date }
                .compactMap { record -> Date? in
                    guard let minutes = SleepRecordFormatter.durationMinutes(from: record.detail) else {
                        return record.recordedAt
                    }
                    return SleepRecordFormatter.endTime(start: record.recordedAt, durationMinutes: minutes)
                }
                .filter { $0 < date }
                .max()
        case .yearning:
            return nil
        }
    }

    private func easyCycleCompactDurationText(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        let remainder = minutes % 60
        return remainder == 0 ? "\(hours)h" : "\(hours)h\(remainder)m"
    }

    private var emptyTimeline: some View {
        return HStack(alignment: .center, spacing: 10) {
                timelineListIcon(
                    assetName: "record_action_easy_eat_icon",
                    systemName: "fork.knife.circle.fill",
                    color: DesignToken.easyEat,
                    size: timelineIconSize,
                    cornerRadius: 11,
                    assetSize: 20
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(Calendar.current.isDateInToday(selectedDate) ? "今天" : dayTitle)
                    .font(BBBFont.font(size: 13, weight: .heavy))
                    .foregroundStyle(DesignToken.primary)
                Text("还没有记录，点右侧添加一条。")
                    .font(BBBFont.font(size: 11.5, weight: .semibold))
                    .foregroundStyle(homeBodyText)
            }
            Spacer()
            Button {
                openFeedSheet(selectedDate)
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

    private func timelineRow(_ item: RecordHomeTimelineItem, nextItem: RecordHomeTimelineItem?) -> some View {
        let isLast = nextItem == nil

        return HStack(alignment: .top, spacing: 11) {
            VStack(spacing: 0) {
                timelineListIcon(
                    assetName: item.easyIconAssetName,
                    systemName: item.icon,
                    color: item.color,
                    size: timelineIconSize,
                    cornerRadius: 11,
                    assetSize: 20
                )

                if !isLast {
                    TimelineConnector()
                        .stroke(
                            DesignToken.line.opacity(0.66),
                            style: StrokeStyle(lineWidth: 1.1, lineCap: .round, dash: [3, 5])
                        )
                        .frame(width: timelineAxisWidth, height: 36)
                        .padding(.top, 5)
                }
            }
            .frame(width: timelineAxisWidth)

            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(BBBFont.font(size: 13.5, weight: .heavy))
                        .foregroundStyle(DesignToken.textPrimary)
                        .lineLimit(1)

                    Text(item.detail)
                        .font(BBBFont.font(size: 11.5, weight: .semibold))
                        .foregroundStyle(homeBodyText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(timeText(for: item))
                        .font(BBBFont.font(size: 10, weight: .semibold))
                        .foregroundStyle(homeFaintText)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                timelineMenu(for: item)
            }
            .padding(.top, 1)
            .padding(.bottom, isLast ? 8 : 15)
        }
        .recordTimelineActions(
            edit: { editingItem = item },
            delete: { pendingDeleteItem = item }
        )
    }

    private func timelineMenu(for item: RecordHomeTimelineItem) -> some View {
        Menu {
            Button {
                editingItem = item
            } label: {
                Label("修改", systemImage: "pencil")
            }
            Button(role: .destructive) {
                pendingDeleteItem = item
            } label: {
                Label("删除", systemImage: "trash")
            }
        } label: {
            Text("⋮")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(homeFaintText)
                .frame(width: 28, height: 24)
        }
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
                        .fill(Color.white.opacity(0.34))
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
        let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
        let isCollapsed = progress > 0.58
        let pillWidth = isCollapsed ? 38 : lerp(36, 44, progress)
        let pillHeight = isCollapsed ? 38 : lerp(55, 50, progress)
        let weekdaySize = lerp(7, 10, progress)
        let daySize = lerp(12, 13, progress)
        let unselectedFillOpacity = lerp(0.48, 0.76, progress)
        let unselectedStrokeOpacity = lerp(0.74, 0.88, progress)

        return Group {
            if isCollapsed {
                Text(date, format: .dateTime.day())
                    .font(BBBFont.font(size: 13, weight: .heavy))
                    .foregroundStyle(isSelected ? .white : homeBodyText)
                    .frame(width: pillWidth, height: pillHeight)
            } else {
                VStack(spacing: isSelected ? 2 : 3) {
                    Text(weekdaySymbol(for: date))
                        .font(BBBFont.font(size: weekdaySize, weight: .regular))
                        .foregroundStyle(isSelected ? .white.opacity(0.86) : homeMetaText)
                    Text(date, format: .dateTime.day())
                        .font(BBBFont.font(size: daySize, weight: .heavy))
                        .foregroundStyle(isSelected ? .white : homeBodyText)
                    if isSelected {
                        Circle()
                            .fill(.white)
                            .frame(width: 3, height: 3)
                    }
                }
                .frame(width: pillWidth)
                .frame(height: pillHeight)
            }
        }
        .frame(width: pillWidth)
        .frame(height: pillHeight)
        .background(
            RoundedRectangle(cornerRadius: isCollapsed ? 19 : 28, style: .continuous)
                .fill(
                    isSelected
                    ? AnyShapeStyle(LinearGradient(colors: [DesignToken.primary, Color(hex: "#8F6CFF")], startPoint: .topLeading, endPoint: .bottomTrailing))
                    : AnyShapeStyle(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isCollapsed ? 0.84 : unselectedFillOpacity),
                                Color(hex: "#F7F3FF").opacity(isCollapsed ? 0.68 : max(unselectedFillOpacity - 0.06, 0.24))
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: isCollapsed ? 19 : 28, style: .continuous)
                        .fill(isSelected ? Color.clear : Color.white.opacity(isCollapsed ? 0.22 : 0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: isCollapsed ? 19 : 28, style: .continuous)
                        .stroke(
                            isSelected
                            ? .white.opacity(0.42)
                            : .white.opacity(isCollapsed ? 0.94 : unselectedStrokeOpacity),
                            lineWidth: 1
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: isCollapsed ? 19 : 28, style: .continuous)
                        .stroke(
                            isSelected
                            ? DesignToken.primary.opacity(0.16)
                            : Color(hex: "#8D86AA").opacity(isCollapsed ? 0.20 : 0.10),
                            lineWidth: 0.8
                        )
                )
                .shadow(color: Color(hex: "#7E5DE8").opacity(isSelected ? 0.18 : (isCollapsed ? 0.10 : 0.08)), radius: isSelected ? 9 : 8, y: isSelected ? 4 : 3)
        )
    }

    private var weekTransition: AnyTransition {
        let insertionEdge: Edge = weekTransitionDirection >= 0 ? .trailing : .leading
        let removalEdge: Edge = weekTransitionDirection >= 0 ? .leading : .trailing
        return .asymmetric(
            insertion: .move(edge: insertionEdge).combined(with: .opacity),
            removal: .move(edge: removalEdge).combined(with: .opacity)
        )
    }

    private var timelineEnd: some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(DesignToken.line.opacity(0.38))
                .frame(height: 1)
            Text(Calendar.current.isDateInToday(selectedDate) ? "今天开始" : "\(dayTitle)开始")
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
        ZStack(alignment: .top) {
            Color(hex: "#F3F3F6")

            ZStack {
                LinearGradient(
                    colors: [
                        Color(hex: "#E8DBFA"),
                        Color(hex: "#E1E7FB"),
                        Color(hex: "#F4E4DA")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(DesignToken.primary.opacity(0.24))
                    .frame(width: 280, height: 280)
                    .blur(radius: 68)
                    .offset(x: 132, y: -72)

                Circle()
                    .fill(Color(hex: "#BFD0FA").opacity(0.27))
                    .frame(width: 320, height: 320)
                    .blur(radius: 78)
                    .offset(x: -116, y: 128)

                Circle()
                    .fill(Color(hex: "#F0CFBE").opacity(0.22))
                    .frame(width: 240, height: 240)
                    .blur(radius: 72)
                    .offset(x: 24, y: -196)

                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(0.16)

                LinearGradient(
                    colors: [
                        Color(hex: "#F3F3F6").opacity(0),
                        Color(hex: "#F3F3F6").opacity(0.22),
                        Color(hex: "#F3F3F6")
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .frame(height: 430)
            .clipped()
        }
    }

    private func glassSurface(cornerRadius: CGFloat, whiteOpacity: Double, shadowOpacity: Double) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(whiteOpacity))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.78), lineWidth: 1.1)
            )
            .shadow(color: Color(hex: "#4D4B70").opacity(shadowOpacity), radius: 18, y: 8)
    }

    private var dayTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "M月d日"
        return formatter.string(from: selectedDate)
    }

    private func shiftWeek(by value: Int) {
        guard let newDate = Calendar.current.date(byAdding: .day, value: value * 7, to: selectedDate) else {
            return
        }
        lightHaptic()
        weekTransitionDirection = value >= 0 ? 1 : -1
        withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
            selectedDate = newDate
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
        let glassProgress = min(max((progress - 0.35) / 0.65, 0), 1)

        return ZStack {
            Color(hex: "#F8F5FF")
                .opacity(0.04 + 0.80 * glassProgress)

            LinearGradient(
                colors: [
                    Color(hex: "#F3EEFF").opacity(0.04 + 0.18 * glassProgress),
                    Color(hex: "#FBFAFF").opacity(0.03 + 0.34 * glassProgress),
                    Color(hex: "#EFEAFB").opacity(0.02 + 0.16 * glassProgress)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.04 + 0.52 * glassProgress)

            LinearGradient(
                colors: [
                    Color.white.opacity(0.18 * glassProgress),
                    Color.white.opacity(0.34 * glassProgress),
                    Color.white.opacity(0.16 * glassProgress)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            LinearGradient(
                colors: [
                    Color.clear,
                    Color(hex: "#DDD5F4").opacity(0.18 * glassProgress)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea(edges: .top)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.0),
                            Color(hex: "#BDA7FF").opacity(0.16 * glassProgress),
                            Color(hex: "#CFC3F6").opacity(0.10 * glassProgress)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 0.8)
        }
    }

    private func lightHaptic() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private var babyAgeText: String {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: profileStore.currentProfile.birthDate)
        let end = calendar.startOfDay(for: selectedDate)
        let components = calendar.dateComponents([.year, .month, .day], from: start, to: end)
        let years = max(components.year ?? 0, 0)
        let months = max(components.month ?? 0, 0)
        let days = max(components.day ?? 0, 0)

        var parts: [String] = []
        if years > 0 {
            parts.append("\(years)岁")
        }
        if months > 0 {
            parts.append("\(months)个月")
        }
        if days > 0 || parts.isEmpty {
            parts.append("\(days)天")
        }
        return parts.joined()
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
            let day = calendar.startOfDay(for: session.createdAt)
            return day >= start && day <= end
        }
        let bottleTotal = recentSessions.reduce(0) { $0 + $1.totalBottleAmount }
        let breastTotal = recentSessions.reduce(0) { $0 + $1.totalBreastDuration }
        let solidTotal = recentSessions.reduce(0.0) { $0 + $1.totalSolidAmount }
        let bottleAverage = roundedAverage(bottleTotal, days: dayCount, step: 10)
        let breastAverage = roundedAverage(breastTotal, days: dayCount, step: 5)
        let solidAverage = roundedAverage(solidTotal, days: dayCount, step: 1)
        let feedingDurationAverage = roundedAverage(recentSessions.reduce(0) { $0 + $1.totalBottleDuration + $1.totalBreastDuration }, days: dayCount, step: 5)

        let recentCareRecords = activityStore.careRecords.filter { record in
            let day = calendar.startOfDay(for: record.recordedAt)
            return day >= start && day <= end
        }
        let diaperAverage = roundedAverage(recentCareRecords.filter { $0.kind == .diaper }.count, days: dayCount, step: 1)
        let sleepAverageMinutes = roundedAverage(recentCareRecords
            .filter { $0.kind == .sleep }
            .reduce(0) { $0 + (SleepRecordFormatter.durationMinutes(from: $1.detail) ?? 0) }, days: dayCount, step: 15)
        let activitySegmentAverage = roundedAverage(recentPlaySegmentCount(sessions: recentSessions, careRecords: recentCareRecords, calendar: calendar), days: dayCount, step: 1)
        let breastEquivalentML = Int(round(Double(breastAverage) * breastEquivalentRate))
        let equivalentMilk = bottleAverage + breastEquivalentML
        let weeklyFeedingText = feedingAmountText(
            equivalentMilkML: equivalentMilk,
            solidGrams: solidAverage,
            approximate: true
        )
        let yearning = weeklyYearningIndex(
            feedingML: equivalentMilk,
            activitySegments: activitySegmentAverage,
            sleepMinutes: sleepAverageMinutes,
            feedingText: weeklyFeedingText,
            activityText: activitySummaryText(diaperCount: diaperAverage, activitySegments: activitySegmentAverage),
            sleepText: sleepAverageMinutes > 0 ? averageSleepText(minutes: sleepAverageMinutes) : "--"
        )

        return BabyTrendOverview(
            bottleML: bottleAverage,
            breastMinutes: breastAverage,
            breastEquivalentML: breastEquivalentML,
            solidGrams: solidAverage,
            equivalentMilkML: equivalentMilk,
            feedingMinutes: feedingDurationAverage,
            diaperCount: diaperAverage,
            activitySegments: activitySegmentAverage,
            urineEstimateText: "--g",
            sleepText: sleepAverageMinutes > 0 ? averageSleepText(minutes: sleepAverageMinutes) : "--",
            yText: yearning.scoreWithUnitText,
            yDetailText: yearning.detailText,
            yColor: yearning.color
        )
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
            ),
            BabyTrendDetailRow(
                title: "Y",
                summary: overview.yText,
                detail: overview.yDetailText,
                color: overview.yColor
            )
        ]
    }

    private func roundedAverage(_ total: Int, days: Int, step: Int) -> Int {
        guard total > 0, days > 0 else { return 0 }
        let raw = Double(total) / Double(days)
        let rounded = Int((raw / Double(step)).rounded()) * step
        return max(rounded, step)
    }

    private func roundedAverage(_ total: Double, days: Int, step: Int) -> Int {
        guard total > 0, days > 0 else { return 0 }
        let raw = total / Double(days)
        let rounded = Int((raw / Double(step)).rounded()) * step
        return max(rounded, step)
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
        if minutes < 60 {
            return "\(minutes)m"
        }
        let hours = Double(minutes) / 60.0
        return String(format: "%.1fh", hours)
    }

    private func activitySummaryText(diaperCount: Int, activitySegments: Int) -> String {
        var parts: [String] = []
        if diaperCount > 0 {
            parts.append("\(diaperCount)拉")
        }
        if activitySegments > 0 {
            parts.append("\(activitySegments)玩")
        }
        return parts.isEmpty ? "--" : parts.joined(separator: "+")
    }

    private func feedingAmountText(equivalentMilkML: Int, solidGrams: Int, approximate: Bool) -> String {
        guard equivalentMilkML > 0 || solidGrams > 0 else { return "--" }
        var text = ""
        if equivalentMilkML > 0 {
            text = "\(approximate ? "~" : "")\(equivalentMilkML)ml"
        }
        if solidGrams > 0 {
            text += text.isEmpty ? "\(solidGrams)g" : "+\(solidGrams)g"
        }
        return text
    }

    private func recentPlaySegmentCount(sessions: [FeedingSession], careRecords: [CareRecord], calendar: Calendar) -> Int {
        let feedingHours = sessions.map { calendar.component(.hour, from: $0.createdAt) }
        let diaperHours = careRecords
            .filter { $0.kind == .diaper }
            .map { calendar.component(.hour, from: $0.recordedAt) }
        let sleepHours = careRecords
            .filter { $0.kind == .sleep }
            .flatMap { record -> [Int] in
                guard let minutes = SleepRecordFormatter.durationMinutes(from: record.detail) else { return [] }
                let end = SleepRecordFormatter.endTime(start: record.recordedAt, durationMinutes: minutes)
                var hours: [Int] = []
                var cursor = record.recordedAt
                while cursor < end {
                    hours.append(calendar.component(.hour, from: cursor))
                    guard let next = calendar.date(byAdding: .hour, value: 1, to: cursor) else { break }
                    cursor = next
                }
                return hours
            }
        return Set(feedingHours + diaperHours).subtracting(Set(sleepHours)).count
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
        return "\(change >= 0 ? "+" : "")\(String(format: "%.1f", change))kg"
    }

    private var rhythmSummaryItems: [RhythmSummaryItem] {
        var items: [RhythmSummaryItem] = []

        let bottleAmount = selectedSessions.reduce(0) { $0 + $1.totalBottleAmount }
        if bottleAmount > 0 {
            items.append(RhythmSummaryItem(text: "瓶喂 \(bottleAmount)ml", color: recordBottleColor))
        }

        let breastMinutes = selectedSessions.reduce(0) { $0 + $1.totalBreastDuration }
        if breastMinutes > 0 {
            items.append(RhythmSummaryItem(text: "亲喂 \(breastMinutes)分钟", color: recordBreastColor))
        }

        let solidAmount = selectedSessions.reduce(0) { $0 + $1.totalSolidAmount }
        if solidAmount > 0 {
            items.append(RhythmSummaryItem(text: "辅食 \(Int(solidAmount))g", color: recordSolidColor))
        }

        if bottleAmount == 0 && breastMinutes == 0 && solidAmount == 0 {
            items.append(RhythmSummaryItem(text: "瓶喂：今天还没喂过", color: recordBottleColor))
        }

        let recordedSleepMinutes = selectedSleepSummary.recordedSleepMinutes
        if recordedSleepMinutes > 0 {
            items.append(RhythmSummaryItem(text: "睡眠 \(averageSleepText(minutes: recordedSleepMinutes))", color: recordSleepColor))
        }

        let diaperCount = selectedCareRecords.filter { $0.kind == .diaper }.count
        if diaperCount > 0 {
            items.append(RhythmSummaryItem(text: "尿布 \(diaperCount)次", color: recordDiaperColor))
        } else {
            items.append(RhythmSummaryItem(text: "尿布：今天还没尿过", color: recordDiaperColor))
        }

        return items
    }

    private var todayRhythmOverview: TodayRhythmOverview {
        let bottleAmount = selectedSessions.reduce(0) { $0 + $1.totalBottleAmount }
        let breastMinutes = selectedSessions.reduce(0) { $0 + $1.totalBreastDuration }
        let solidAmount = Int(selectedSessions.reduce(0) { $0 + $1.totalSolidAmount }.rounded())
        let breastEquivalentML = Int(round(Double(breastMinutes) * breastEquivalentRate))
        let equivalentMilk = bottleAmount + breastEquivalentML

        let feedingText = feedingAmountText(equivalentMilkML: equivalentMilk, solidGrams: solidAmount, approximate: false)

        let sleepMinutes = selectedSleepSummary.recordedSleepMinutes
        let diaperCount = selectedCareRecords.filter { $0.kind == .diaper }.count
        let playSegments = todayPlaySegmentCount()
        let yearning = todayYearningIndex

        return TodayRhythmOverview(
            feedingText: feedingText,
            activityText: activitySummaryText(diaperCount: diaperCount, activitySegments: playSegments),
            sleepText: sleepMinutes > 0 ? averageSleepText(minutes: sleepMinutes) : "--",
            yText: yearning.scoreWithUnitText,
            yColor: yearning.color
        )
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
            .filter { $0.createdAt <= effectiveNow }
            .sorted { $0.createdAt < $1.createdAt }
        let latestEat = sessions.last
        let cycleStart = latestEat?.createdAt ?? dayStart
        let cycleSessions = sessions.filter { $0.createdAt >= cycleStart }
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
            ? "待开始"
            : feedingAmountText(equivalentMilkML: equivalentMilk, solidGrams: solidAmount, approximate: false)

        let diaperCount = cycleCareRecords.filter { $0.kind == .diaper }.count
        let activityMinutes = max(Int(effectiveNow.timeIntervalSince(cycleStart) / 60), 0)
        let activityText = diaperCount > 0 ? "\(diaperCount)拉" : elapsedShortText(minutes: activityMinutes)
        let sleepMinutes = cycleSleepRecords.reduce(0) { $0 + $1.minutes }
        let sleepText = sleepMinutes > 0 ? averageSleepText(minutes: sleepMinutes) : "--"
        let activitySegments = max(diaperCount, activityMinutes >= 20 ? 1 : 0)
        let yearning = yearningIndex(
            feedingML: equivalentMilk,
            activitySegments: activitySegments,
            sleepMinutes: latestCompletedSleep?.minutes ?? activeSleep?.minutes ?? sleepMinutes,
            feedingText: eatText,
            activityText: activityText,
            sleepText: sleepText
        )

        return EasyCycleOverview(
            startedAt: cycleStart,
            currentStep: currentStep,
            eatText: eatText,
            activityText: activityText,
            sleepText: sleepText,
            yearningText: yearning.scoreWithUnitText,
            yearningProgress: Double(yearning.score) / 100,
            hasEatData: latestEat != nil,
            hasActivityData: diaperCount > 0,
            hasSleepData: sleepMinutes > 0,
            hasYearningData: false,
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
            ? "待记录"
            : feedingAmountText(equivalentMilkML: equivalentMilk, solidGrams: solidAmount, approximate: false)

        let diaperCount = cycleCareRecords.filter { $0.kind == .diaper }.count
        let activityStart = cycle.activityStartedAt ?? cycle.startedAt
        let activityEnd = cycle.activityEndedAt ?? (cycle.currentPhase == .activity ? effectiveEnd : nil)
        let activityMinutes = activityEnd.map { max(Int($0.timeIntervalSince(activityStart) / 60), 0) } ?? 0
        let activityText: String
        if diaperCount > 0, activityMinutes > 0 {
            activityText = "\(elapsedShortText(minutes: activityMinutes)) · \(diaperCount)尿布"
        } else if diaperCount > 0 {
            activityText = "\(diaperCount)尿布"
        } else if activityMinutes > 0 {
            activityText = elapsedShortText(minutes: activityMinutes)
        } else {
            activityText = "待记录"
        }

        let sleepMinutes = sleepRecords.reduce(0) { $0 + $1.minutes }
        let activeSleepMinutes: Int? = cycle.currentPhase == .sleep
            ? max(Int(effectiveEnd.timeIntervalSince(cycle.startedAt) / 60), 0)
            : nil
        let sleepText = sleepMinutes > 0 ? averageSleepText(minutes: sleepMinutes) : "待记录"
        let yearning = yearningIndex(
            feedingML: equivalentMilk,
            activitySegments: max(diaperCount, activityMinutes >= 20 ? 1 : 0),
            sleepMinutes: sleepMinutes,
            feedingText: eatText,
            activityText: activityText,
            sleepText: sleepText
        )

        return EasyCycleOverview(
            startedAt: cycle.startedAt,
            currentStep: EasyCycleStep(cycle.currentPhase),
            eatText: eatText,
            activityText: activityText,
            sleepText: sleepText,
            yearningText: yearning.scoreWithUnitText,
            yearningProgress: Double(yearning.score) / 100,
            hasEatData: !cycleSessions.isEmpty,
            hasActivityData: diaperCount > 0 || activityMinutes > 0,
            hasSleepData: sleepMinutes > 0,
            hasYearningData: easyCycleCompletion(for: cycle) == .complete,
            guidance: easyCycleGuidance(
                step: EasyCycleStep(cycle.currentPhase),
                minutesSinceCycleStart: max(Int(effectiveEnd.timeIntervalSince(cycle.startedAt) / 60), 0),
                activeSleepMinutes: activeSleepMinutes,
                minutesSinceWake: cycle.status == .readyToPublish ? 0 : nil
            )
        )
    }

    private func handleEasyCyclePrimaryAction() {
        rebuildEasyCycles()
        let actionDate = Calendar.current.isDateInToday(selectedDate) ? Date() : easyCycleStartAnchor(for: selectedDate)
        easyCycleStore.performPrimaryAction(now: actionDate, startedAt: easyCycleStartAnchor(for: selectedDate))
        awardCompleteEasyCyclesIfNeeded()
    }

    private func easyCycleStartAnchor(for date: Date) -> Date {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(24 * 60 * 60)
        let sessionDates = selectedSessions
            .map { $0.startAt ?? $0.createdAt }
            .filter { $0 >= dayStart && $0 < dayEnd }
        let careDates = selectedCareRecordsForSleepSummary
            .filter { $0.kind != .sleep }
            .map(\.recordedAt)
            .filter { $0 >= dayStart && $0 < dayEnd }
        let candidateDates = sessionDates + careDates
        return candidateDates.min() ?? date
    }

    private func ensureEasyCycleDataIfNeeded() {
        rebuildEasyCycles()
    }

    private func rebuildEasyCycles() {
        easyCycleStore.rebuild(
            from: feedingStore.allSessions,
            careRecords: activityStore.exportCareRecords()
        )
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
                let eventDate = $0.startAt ?? $0.createdAt
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
            .sorted { $0.createdAt < $1.createdAt }
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
        let start = easyCycleClockText(cycle.startedAt)
        if let endedAt = cycle.endedAt {
            return "\(start)-\(easyCycleClockText(endedAt))"
        }
        return "\(start)开始"
    }

    private func easyCycleClockText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func easyCycleHasDisplayRecords(_ cycle: EasyCycle) -> Bool {
        !cycleFeedingSessions(for: cycle).isEmpty || !cycleCareRecords(for: cycle).isEmpty
    }

    private func easyCycleHeaderTimeText(_ cycle: EasyCycle) -> String {
        let start = easyCycleClockText(cycle.startedAt)
        guard easyCycleCompletion(for: cycle) == .complete else {
            if cycle.endedAt != nil, !cycleCareRecords(for: cycle).contains(where: { $0.kind == .sleep }) {
                return "\(start)-待补S"
            }
            return "\(start)-进行中"
        }
        let end = easyCycleCompletedEndDate(for: cycle) ?? cycleEffectiveEnd(cycle)
        return "\(start)-\(easyCycleClockText(end))"
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

    private func awardCompleteEasyCyclesIfNeeded() {
        for cycle in easyCycleTimelineItems where easyCycleCompletion(for: cycle) == .complete {
            let completedAt = cycle.endedAt ?? cycleEffectiveEnd(cycle)
            recruitmentStore.awardBBBucks(forEasyCycle: cycle.id, completedAt: completedAt)
        }
    }

    private func easyCycleStatusText(_ cycle: EasyCycle) -> String {
        switch easyCycleCompletion(for: cycle) {
        case .complete: return easyCycleHeaderTimeText(cycle)
        case .partial, .empty: return easyCycleHeaderTimeText(cycle)
        }
    }

    private func easyCycleStatusColor(_ cycle: EasyCycle) -> Color {
        switch easyCycleCompletion(for: cycle) {
        case .complete: return DesignToken.easyActivity
        case .partial: return DesignToken.primary
        case .empty: return DesignToken.primary
        }
    }

    private func easyCycleGuidance(
        step: EasyCycleStep,
        minutesSinceCycleStart: Int,
        activeSleepMinutes: Int?,
        minutesSinceWake: Int?
    ) -> String {
        switch step {
        case .eat:
            return "从第一顿开始记录，建立今天的节奏。"
        case .activity:
            if minutesSinceCycleStart >= 75 {
                return "清醒已经 \(elapsedShortText(minutes: minutesSinceCycleStart))，可以准备睡前过渡。"
            }
            return "刚吃完，适合安静互动，观察清醒窗口。"
        case .sleep:
            if let activeSleepMinutes {
                return "已睡 \(elapsedShortText(minutes: activeSleepMinutes))，尽量保持低光和安静。"
            }
            return "已经进入睡眠，尽量保持低光和安静。"
        case .yearning:
            if let minutesSinceWake, minutesSinceWake <= 20 {
                return "自然醒后先观察探索欲，再进入下一轮 Eat。"
            }
            return "这一轮已完成，可以准备下一轮 Eat。"
        }
    }

    private func elapsedShortText(minutes: Int) -> String {
        let minutes = max(minutes, 0)
        if minutes < 60 {
            return "\(minutes)分钟"
        }
        let hours = minutes / 60
        let remaining = minutes % 60
        return remaining == 0 ? "\(hours)h" : "\(hours)h\(remaining)m"
    }

    private var todayYearningIndex: YearningIndex {
        let bottleAmount = selectedSessions.reduce(0) { $0 + $1.totalBottleAmount }
        let breastMinutes = selectedSessions.reduce(0) { $0 + $1.totalBreastDuration }
        let breastEquivalentML = Int(round(Double(breastMinutes) * breastEquivalentRate))
        let effectiveMilk = bottleAmount + breastEquivalentML
        let sleepMinutes = latestSleepDurationMinutes ?? selectedSleepSummary.recordedSleepMinutes
        let diaperCount = selectedCareRecords.filter { $0.kind == .diaper }.count
        let activitySegments = todayPlaySegmentCount()
        let solidAmount = Int(selectedSessions.reduce(0) { $0 + $1.totalSolidAmount }.rounded())
        let feedingText = feedingAmountText(equivalentMilkML: effectiveMilk, solidGrams: solidAmount, approximate: false)

        return yearningIndex(
            feedingML: effectiveMilk,
            activitySegments: activitySegments,
            sleepMinutes: sleepMinutes,
            feedingText: feedingText,
            activityText: activitySummaryText(diaperCount: diaperCount, activitySegments: activitySegments),
            sleepText: sleepMinutes > 0 ? averageSleepText(minutes: sleepMinutes) : "--"
        )
    }

    private var latestSleepDurationMinutes: Int? {
        selectedCareRecordsForSleepSummary
            .filter { $0.kind == .sleep }
            .sorted { $0.recordedAt > $1.recordedAt }
            .compactMap { SleepRecordFormatter.durationMinutes(from: $0.detail) }
            .first
    }

    private func weeklyYearningIndex(
        feedingML: Int,
        activitySegments: Int,
        sleepMinutes: Int,
        feedingText: String,
        activityText: String,
        sleepText: String
    ) -> YearningIndex {
        let sleepScore: Int
        switch sleepMinutes {
        case 0:
            sleepScore = 55
        case ..<720:
            sleepScore = 68
        case 720...1020:
            sleepScore = 96
        default:
            sleepScore = 80
        }

        return yearningIndex(
            feedingML: feedingML,
            activitySegments: activitySegments,
            sleepMinutes: sleepMinutes,
            feedingText: feedingText,
            activityText: activityText,
            sleepText: sleepText,
            overrideSleepScore: sleepScore
        )
    }

    private func yearningIndex(
        feedingML: Int,
        activitySegments: Int,
        sleepMinutes: Int,
        feedingText: String,
        activityText: String,
        sleepText: String,
        overrideSleepScore: Int? = nil
    ) -> YearningIndex {
        let eatScore = yearningEatScore(feedingML: feedingML)
        let activityScore = yearningActivityScore(activitySegments: activitySegments)
        let sleepScore = overrideSleepScore ?? yearningSleepScore(sleepMinutes: sleepMinutes)
        let score = Int(round(Double(eatScore) * 0.35 + Double(activityScore) * 0.25 + Double(sleepScore) * 0.40))
        return YearningIndex(
            score: max(0, min(score, 100)),
            eatText: feedingText,
            activityText: activityText,
            sleepText: sleepText
        )
    }

    private func yearningEatScore(feedingML: Int) -> Int {
        guard feedingML > 0 else { return 52 }
        let target = max(yearningTargetFeedML, 1)
        let ratio = Double(feedingML) / Double(target)
        switch ratio {
        case ..<0.65: return 58
        case ..<0.85: return 80
        case ...1.15: return 100
        case ...1.35: return 84
        default: return 70
        }
    }

    private var yearningTargetFeedML: Int {
        switch selectedAgeMonths {
        case 0: return 80
        case 1: return 110
        case 2: return 130
        case 3: return 150
        case 4...5: return 170
        case 6...12: return 180
        default: return 160
        }
    }

    private func yearningActivityScore(activitySegments: Int) -> Int {
        switch activitySegments {
        case 0: return 64
        case 1...2: return 84
        case 3...8: return 100
        case 9...12: return 76
        default: return 58
        }
    }

    private func yearningSleepScore(sleepMinutes: Int) -> Int {
        switch sleepMinutes {
        case 0: return 55
        case ..<45: return 35
        case 45..<75: return 76
        case 75...120: return 100
        case 121...180: return 84
        default: return 70
        }
    }

    private func todayPlaySegmentCount() -> Int {
        let calendar = Calendar.current
        let feedingHours = selectedSessions.map { calendar.component(.hour, from: $0.createdAt) }
        let diaperHours = selectedCareRecords
            .filter { $0.kind == .diaper }
            .map { calendar.component(.hour, from: $0.recordedAt) }
        let sleepHours = selectedCareRecordsForSleepSummary
            .filter { $0.kind == .sleep }
            .flatMap { record -> [Int] in
                guard let minutes = SleepRecordFormatter.durationMinutes(from: record.detail) else { return [] }
                let end = SleepRecordFormatter.endTime(start: record.recordedAt, durationMinutes: minutes)
                var hours: [Int] = []
                var cursor = record.recordedAt
                while cursor < end {
                    hours.append(calendar.component(.hour, from: cursor))
                    guard let next = calendar.date(byAdding: .hour, value: 1, to: cursor) else { break }
                    cursor = next
                }
                return hours
            }
        return Set(feedingHours + diaperHours).subtracting(Set(sleepHours)).count
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
        var recordsByID = Dictionary(uniqueKeysWithValues: selectedCareRecords.map { ($0.id, $0) })
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
            let hour = hour(from: session.createdAt)
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
        Color(hex: "#C9D4F6")
    }

    private var elapsedEmptyColor: Color {
        Color(hex: "#DCD8E8")
    }

    private var futureTimeColor: Color {
        Color(hex: "#F0EEF8")
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

    private func delete(_ item: RecordHomeTimelineItem) {
        switch item {
        case .feeding(let session):
            feedingStore.deleteSession(session)
        case .care(let record):
            activityStore.deleteCareRecord(record)
        case .growth(let record):
            growthMetricStore.deleteRecord(record)
        }
    }

    private var currentClockText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: now)
    }

    private var currentClockEmoji: String {
        let components = Calendar.current.dateComponents([.hour, .minute], from: now)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        let hourIndex = hour % 12
        let clockHours = ["🕛", "🕐", "🕑", "🕒", "🕓", "🕔", "🕕", "🕖", "🕗", "🕘", "🕙", "🕚"]
        let halfClockHours = ["🕧", "🕜", "🕝", "🕞", "🕟", "🕠", "🕡", "🕢", "🕣", "🕤", "🕥", "🕦"]
        return minute >= 30 ? halfClockHours[hourIndex] : clockHours[hourIndex]
    }

    private var lastFeedingDateForSummary: Date? {
        let sessions = Calendar.current.isDateInToday(selectedDate) ? feedingStore.allSessions : selectedSessions
        return sessions
            .filter { $0.createdAt <= now }
            .max(by: { $0.createdAt < $1.createdAt })?
            .createdAt
    }

    private var lastActivityDateForSummary: Date? {
        let records = Calendar.current.isDateInToday(selectedDate) ? activityStore.careRecords : selectedCareRecords
        return records
            .filter { $0.kind == .diaper && $0.recordedAt <= now }
            .max(by: { $0.recordedAt < $1.recordedAt })?
            .recordedAt
    }

    private var lastSleepDateForSummary: Date? {
        let records = Calendar.current.isDateInToday(selectedDate) ? activityStore.careRecords : selectedCareRecordsForSleepSummary
        return records
            .filter { $0.kind == .sleep }
            .compactMap { sleepEndDate(for: $0) }
            .filter { $0 <= now }
            .max()
    }

    private func sleepEndDate(for record: CareRecord) -> Date? {
        guard let minutes = SleepRecordFormatter.durationMinutes(from: record.detail) else {
            return record.recordedAt
        }
        return SleepRecordFormatter.endTime(start: record.recordedAt, durationMinutes: minutes)
    }

    private func elapsedSummaryText(since date: Date?) -> String {
        guard let date else { return "--" }
        let minutes = max(Int(now.timeIntervalSince(date) / 60), 0)
        switch minutes {
        case ..<1:
            return "刚刚"
        case ..<60:
            return "\(minutes)分"
        case ..<(24 * 60):
            let hours = minutes / 60
            let remainder = minutes % 60
            if hours < 10, remainder > 0 {
                return "\(hours)时\(remainder)分"
            }
            return "\(hours)时"
        case ..<(7 * 24 * 60):
            return "\(minutes / (24 * 60))天"
        default:
            return "7天+"
        }
    }

    private func compactElapsedSummaryText(since date: Date?) -> String {
        guard let date else { return "--" }
        let minutes = max(Int(now.timeIntervalSince(date) / 60), 0)
        switch minutes {
        case ..<1:
            return "刚刚"
        case ..<60:
            return "\(minutes)m前"
        case ..<(24 * 60):
            let hours = minutes / 60
            let remainder = minutes % 60
            return remainder > 0 ? "\(hours)h\(remainder)m前" : "\(hours)h前"
        case ..<(7 * 24 * 60):
            return "\(minutes / (24 * 60))d前"
        default:
            return "7d+"
        }
    }

    private func weekdaySymbol(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }

    private func compactWeekdaySymbol(for date: Date) -> String {
        let index = Calendar.current.component(.weekday, from: date) - 1
        let symbols = ["日", "一", "二", "三", "四", "五", "六"]
        return symbols[max(0, min(index, symbols.count - 1))]
    }

    private func lerp(_ start: CGFloat, _ end: CGFloat, _ progress: CGFloat) -> CGFloat {
        start + (end - start) * max(0, min(progress, 1))
    }
}

private enum RecordHomeScrollTarget: Hashable {
    case rhythm
}

private struct StatisticsAnalysisView: View {
    @EnvironmentObject private var feedingStore: FeedingStore
    @EnvironmentObject private var activityStore: ActivityStore
    @Environment(BabyProfileStore.self) private var profileStore
    @State private var selectedMonthIndex: Int?

    var body: some View {
        ZStack {
            HomeSoftBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    monthRhythmCard
                    legend
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 96)
            }
        }
        .navigationTitle("统计分析")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Statistics & Analysis")
                .font(BBBFont.font(size: 28, weight: .heavy))
                .foregroundStyle(DesignToken.textPrimary)

            Text("按宝宝月龄查看每天的照护时间段")
                .font(BBBFont.font(size: 13, weight: .bold))
                .foregroundStyle(DesignToken.textSecondary)
        }
    }

    private var monthRhythmCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 10) {
                monthNavButton(systemName: "chevron.left", isEnabled: currentMonthIndex > 0) {
                    selectedMonthIndex = currentMonthIndex - 1
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(monthTitle)
                        .font(BBBFont.font(size: 18, weight: .heavy))
                        .foregroundStyle(DesignToken.textPrimary)
                    Text(monthDateRangeText)
                        .font(BBBFont.font(size: 11, weight: .bold))
                        .foregroundStyle(DesignToken.textSecondary)
                }

                Spacer()

                monthNavButton(systemName: "chevron.right", isEnabled: currentMonthIndex < maxMonthIndex) {
                    selectedMonthIndex = min(currentMonthIndex + 1, maxMonthIndex)
                }
            }

            LazyVStack(spacing: 7) {
                hourGuide

                ForEach(monthDays, id: \.self) { date in
                    rhythmMonthRow(for: date)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.white.opacity(0.70))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(.white.opacity(0.86), lineWidth: 1)
                )
                .shadow(color: Color(hex: "#4D4B70").opacity(0.07), radius: 18, y: 10)
        )
    }

    private var hourGuide: some View {
        HStack(spacing: 8) {
            Text("Day")
                .font(BBBFont.font(size: 10, weight: .heavy))
                .foregroundStyle(DesignToken.textSecondary)
                .frame(width: 34, alignment: .leading)

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
            .foregroundStyle(DesignToken.textSecondary.opacity(0.72))
        }
    }

    private func rhythmMonthRow(for date: Date) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text("D\(babyDayNumber(for: date))")
                    .font(BBBFont.font(size: 10, weight: .heavy))
                    .foregroundStyle(DesignToken.textPrimary.opacity(0.84))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(dayLabel(for: date))
                    .font(BBBFont.font(size: 8, weight: .bold))
                    .foregroundStyle(DesignToken.textSecondary.opacity(0.72))
                    .lineLimit(1)
            }
            .frame(width: 34, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                RhythmSpanTimeline(
                    date: date,
                    spans: spans(for: date),
                    height: 34,
                    showsGuide: false
                )

                Text(daySummaryText(for: date))
                    .font(BBBFont.font(size: 9, weight: .bold))
                    .foregroundStyle(DesignToken.textSecondary.opacity(0.78))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 12) {
            legendItem("睡眠", color: DailyRhythmKind.sleep.color)
            legendItem("瓶喂", color: DailyRhythmKind.bottle.color)
            legendItem("亲喂", color: DailyRhythmKind.breast.color)
            legendItem("辅食", color: DailyRhythmKind.solid.color)
            legendItem("尿布", color: DailyRhythmKind.diaper.color)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.white.opacity(0.58))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(.white.opacity(0.76), lineWidth: 1)
                )
        )
    }

    private func legendItem(_ title: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Capsule()
                .fill(color)
                .frame(width: 14, height: 6)
            Text(title)
                .font(BBBFont.font(size: 10, weight: .heavy))
                .foregroundStyle(DesignToken.textSecondary)
        }
    }

    private func monthNavButton(systemName: String, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(isEnabled ? DesignToken.primary : DesignToken.textSecondary.opacity(0.32))
                .frame(width: 34, height: 34)
                .background(Circle().fill(.white.opacity(0.72)))
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!isEnabled)
    }

    private var monthTitle: String {
        "\(currentMonthIndex)-\(currentMonthIndex + 1)月龄"
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

    private func spans(for date: Date) -> [RhythmTimelineSpan] {
        let sessions = feedingStore.sessions(on: date)
        let careRecords = activityStore.careRecordsForSleepSummary(on: date)
        return rhythmTimelineSpans(
            for: date,
            sessions: sessions,
            careRecords: careRecords,
            ageMonths: profileStore.currentProfile.ageMonths
        )
    }

    private func rhythmKinds(hour: Int, feedingTypes: Set<FeedingType>, diaperHours: Set<Int>, sleepHours: Set<Int>) -> [DailyRhythmKind] {
        var kinds: [DailyRhythmKind] = []
        if sleepHours.contains(hour) { kinds.append(.sleep) }
        if feedingTypes.contains(.bottle) { kinds.append(.bottle) }
        if feedingTypes.contains(.breast) { kinds.append(.breast) }
        if feedingTypes.contains(.solid) { kinds.append(.solid) }
        if diaperHours.contains(hour) { kinds.append(.diaper) }
        return kinds
    }

    private func daySummaryText(for date: Date) -> String {
        let sessions = feedingStore.sessions(on: date)
        let bottleAmount = sessions.reduce(0) { $0 + $1.totalBottleAmount }
        let breastMinutes = sessions.reduce(0) { $0 + $1.totalBreastDuration }
        let intervalText = averageIntervalText(for: sessions)
        var parts = ["喂养\(sessions.count)次"]
        if bottleAmount > 0 { parts.append("\(bottleAmount)ml") }
        if breastMinutes > 0 { parts.append("亲喂\(breastMinutes)分") }
        if !intervalText.isEmpty { parts.append(intervalText) }
        return parts.joined(separator: " · ")
    }

    private func averageIntervalText(for sessions: [FeedingSession]) -> String {
        let sortedDates = sessions.map(\.createdAt).sorted()
        guard sortedDates.count >= 2 else { return "" }
        let intervals = zip(sortedDates, sortedDates.dropFirst()).map { later, next in
            next.timeIntervalSince(later) / 60
        }
        let average = intervals.reduce(0, +) / Double(intervals.count)
        if average < 60 { return "均隔\(Int(average))分" }
        return "均隔\(Int(average) / 60)时\(Int(average) % 60)分"
    }

    private func babyDayNumber(for date: Date) -> Int {
        let days = Calendar.current.dateComponents([.day], from: birthStart, to: Calendar.current.startOfDay(for: date)).day ?? 0
        return max(days + 1, 1)
    }

    private func dayLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }

    private func compactDateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
    }
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
        topPadding + 52 + dateHeaderBottom + 65 + dayPickerBottom
    }

    var collapsedHeaderHeight: CGFloat {
        topPadding + 40 + 4 + 54 + 4
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
        self.headerCardOverlap = isCompact ? 8 : 10
    }
}

private struct RhythmSummaryItem: Identifiable {
    let id = UUID()
    let text: String
    let color: Color
}

private enum EasyCycleStep: Int, CaseIterable, Identifiable {
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

    var showsEmptyActionBadge: Bool {
        switch self {
        case .eat, .activity, .sleep: return true
        case .yearning: return false
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

private enum EasyCycleStepState {
    case pending
    case current
    case done
}

private enum EasyCycleCardCompletion {
    case empty
    case partial
    case complete
}

private struct EasyCycleTimelineRow: Identifiable {
    var id: EasyCycleStep { step }
    let step: EasyCycleStep
    let title: String
    let primaryText: String
    let secondaryText: String
    let timeText: String
    let detailItems: [EasyCycleTimelineDetailItem]
    let isComplete: Bool
}

private struct EasyCycleTimelineDetailItem: Identifiable {
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
    let yearningProgress: Double
    let hasEatData: Bool
    let hasActivityData: Bool
    let hasSleepData: Bool
    let hasYearningData: Bool
    let guidance: String

    var startedAtText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "HH:mm开始"
        return formatter.string(from: startedAt)
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
    let id = "baby-trend-detail"
}

private struct YearningDetailContext: Identifiable {
    let id = "yearning-detail"
}

private struct BabyTrendValueChunk: Identifiable {
    let id = UUID()
    var separator = ""
    var prefix = ""
    var main: String
    var unit = ""
}

private enum RhythmMetricTileStyle {
    case dark
    case light

    func iconColor(accent: Color) -> Color {
        switch self {
        case .dark: return .white.opacity(0.92)
        case .light: return .white.opacity(0.94)
        }
    }

    func badgeFillColor(accent: Color) -> Color {
        switch self {
        case .dark: return accent.opacity(0.72)
        case .light: return accent.opacity(0.72)
        }
    }

    var titleColor: Color {
        switch self {
        case .dark: return .white.opacity(0.70)
        case .light: return Color(hex: "#777487")
        }
    }

    var prefixColor: Color {
        switch self {
        case .dark: return .white.opacity(0.66)
        case .light: return Color(hex: "#9997A6")
        }
    }

    var mainColor: Color {
        switch self {
        case .dark: return .white.opacity(0.96)
        case .light: return Color(hex: "#2F2D40")
        }
    }

    var unitColor: Color {
        switch self {
        case .dark: return .white.opacity(0.68)
        case .light: return Color(hex: "#8E8C9D")
        }
    }

    var extraColor: Color {
        switch self {
        case .dark: return .white.opacity(0.72)
        case .light: return Color(hex: "#8E8C9D")
        }
    }

    func fillColor(accent: Color) -> Color {
        switch self {
        case .dark: return .white.opacity(0.12)
        case .light: return .white.opacity(0.52)
        }
    }

    func overlayColor(accent: Color) -> Color {
        switch self {
        case .dark: return accent.opacity(0.08)
        case .light: return accent.opacity(0.06)
        }
    }

    func strokeColor(accent: Color) -> Color {
        switch self {
        case .dark: return accent.opacity(0.24)
        case .light: return accent.opacity(0.14)
        }
    }

    func infoIconColor(accent: Color) -> Color {
        switch self {
        case .dark: return .white.opacity(0.90)
        case .light: return accent.opacity(0.88)
        }
    }

    func infoFillColor(accent: Color) -> Color {
        switch self {
        case .dark: return .white.opacity(0.14)
        case .light: return accent.opacity(0.10)
        }
    }

    func infoStrokeColor(accent: Color) -> Color {
        switch self {
        case .dark: return .white.opacity(0.34)
        case .light: return accent.opacity(0.18)
        }
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

private struct BabyTrendOverview {
    let bottleML: Int
    let breastMinutes: Int
    let breastEquivalentML: Int
    let solidGrams: Int
    let equivalentMilkML: Int
    let feedingMinutes: Int
    let diaperCount: Int
    let activitySegments: Int
    let urineEstimateText: String
    let sleepText: String
    let yText: String
    let yDetailText: String
    let yColor: Color

    var feedingAmountText: String {
        guard equivalentMilkML > 0 || solidGrams > 0 else { return "--" }

        var text = ""
        if equivalentMilkML > 0 {
            text = "~\(equivalentMilkML)ml"
        }
        if solidGrams > 0 {
            text += text.isEmpty ? "\(solidGrams)g" : "+\(solidGrams)g"
        }
        return text
    }

    var feedingText: String {
        feedingAmountText
    }

    var activityText: String {
        var parts: [String] = []
        if diaperCount > 0 {
            parts.append("\(diaperCount)拉")
        }
        if activitySegments > 0 {
            parts.append("\(activitySegments)玩")
        }
        return parts.isEmpty ? "--" : parts.joined(separator: "+")
    }

    var feedingDetailText: String {
        var parts: [String] = []
        if feedingMinutes > 0 {
            parts.append("平均喂养\(feedingMinutes)分钟")
        }
        if bottleML > 0 {
            parts.append("\(bottleML)ml奶")
        }
        if breastMinutes > 0 {
            parts.append("\(breastMinutes)分钟亲喂（换算\(breastEquivalentML)ml）")
        }
        if solidGrams > 0 {
            parts.append("\(solidGrams)g辅食")
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

private struct TodayRhythmOverview {
    let feedingText: String
    let activityText: String
    let sleepText: String
    let yText: String
    let yColor: Color
}

private struct YearningIndex {
    let score: Int
    let eatText: String
    let activityText: String
    let sleepText: String

    var scoreText: String {
        "\(score)%"
    }

    var scoreWithUnitText: String {
        "\(score)%"
    }

    var phase: YearningPhase {
        YearningPhase(score: score)
    }

    var color: Color {
        phase.color
    }

    var detailText: String {
        "Yearning \(score)%｜\(phase.title)\nE \(eatText) · A \(activityText) · S \(sleepText)"
    }
}

private enum YearningPhase {
    case golden
    case gentle
    case earlySleep

    init(score: Int) {
        if score >= 85 {
            self = .golden
        } else if score >= 60 {
            self = .gentle
        } else {
            self = .earlySleep
        }
    }

    var title: String {
        switch self {
        case .golden: return "黄金探索期"
        case .gentle: return "温和互动期"
        case .earlySleep: return "提前接觉期"
        }
    }

    var rangeText: String {
        switch self {
        case .golden: return "85%-100%"
        case .gentle: return "60%-84%"
        case .earlySleep: return "<60%"
        }
    }

    var guidance: String {
        switch self {
        case .golden:
            return "适合 Tummy Time、抓握练习、看卡片和主动互动。"
        case .gentle:
            return "适合抱看窗外、听音乐、轻声说话，避免高强度刺激。"
        case .earlySleep:
            return "减少逗玩，调暗灯光，启动睡前仪式，准备提前接觉。"
        }
    }

    var color: Color {
        switch self {
        case .golden: return DesignToken.easyYearning
        case .gentle: return DesignToken.activityDiaper
        case .earlySleep: return Color(hex: "#E07070")
        }
    }
}

private struct BabyTrendDetailRow: Identifiable {
    let id = UUID()
    let title: String
    let summary: String
    let detail: String
    let color: Color
}

private struct BabyTrendDetailSheet: View {
    @Environment(\.dismiss) private var dismiss

    let ageText: String
    let guidance: AgeRhythmGuidance
    let overview: BabyTrendOverview
    let detailRows: [BabyTrendDetailRow]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(ageText)
                            .font(BBBFont.font(size: 22, weight: .heavy))
                            .foregroundStyle(DesignToken.textPrimary)
                        Text(guidance.detailText)
                            .font(BBBFont.font(size: 13, weight: .semibold))
                            .foregroundStyle(DesignToken.textSecondary)
                            .lineSpacing(4)
                    }
                    .padding(16)
                    .background(detailCardBackground)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("近7日 EASY")
                            .font(BBBFont.font(size: 16, weight: .heavy))
                            .foregroundStyle(DesignToken.textPrimary)

                        ForEach(detailRows) { row in
                            trendDetailRow(row)
                        }
                    }
                    .padding(16)
                    .background(detailCardBackground)

                    Text("亲喂换算按当前月龄估算；尿量换算字段暂未上线，后续记录尿布重量后会补全。")
                        .font(BBBFont.font(size: 11, weight: .semibold))
                        .foregroundStyle(DesignToken.textSecondary.opacity(0.78))
                        .padding(.horizontal, 4)
                }
                .padding(18)
            }
            .background(DesignToken.background.ignoresSafeArea())
            .navigationTitle("月龄节奏详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .font(BBBFont.font(size: 14, weight: .heavy))
                }
            }
        }
    }

    private var detailCardBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(0.58))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(.white.opacity(0.82), lineWidth: 1)
            )
    }

    private func trendDetailRow(_ row: BabyTrendDetailRow) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(row.title)
                .font(BBBFont.font(size: 13, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(Circle().fill(row.color.opacity(0.92)))

            VStack(alignment: .leading, spacing: 4) {
                Text(row.summary)
                    .font(BBBFont.font(size: 14, weight: .heavy))
                    .foregroundStyle(DesignToken.textPrimary)
                Text(row.detail)
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

private struct YearningDetailSheet: View {
    @Environment(\.dismiss) private var dismiss

    let index: YearningIndex
    let overview: TodayRhythmOverview
    let cycleOverview: EasyCycleOverview
    let cycle: EasyCycle?
    let onPrimaryAction: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    publisherHeader

                    publisherStepCards

                    Button {
                        onPrimaryAction()
                    } label: {
                        Text(primaryActionTitle)
                            .font(BBBFont.font(size: 16, weight: .heavy))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(Capsule(style: .continuous).fill(DesignToken.primaryGradient))
                    }
                    .buttonStyle(ScaleButtonStyle())

                    VStack(alignment: .leading, spacing: 10) {
                        Text("当前 EASY")
                            .font(BBBFont.font(size: 16, weight: .heavy))
                            .foregroundStyle(DesignToken.textPrimary)

                        easRow(title: "喂养", value: cycleOverview.eatText, color: DesignToken.easyEat)
                        easRow(title: "活动", value: cycleOverview.activityText, color: DesignToken.easyActivity)
                        easRow(title: "睡眠", value: cycleOverview.sleepText, color: DesignToken.easySleep)
                        easRow(title: "状态", value: cycleOverview.yearningText, color: DesignToken.easyYearning)
                    }
                    .padding(16)
                    .background(detailCardBackground)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(index.scoreText)
                                .font(BBBFont.font(size: 34, weight: .heavy))
                                .foregroundStyle(index.color)
                            Text(index.phase.title)
                                .font(BBBFont.font(size: 15, weight: .heavy))
                                .foregroundStyle(DesignToken.textPrimary)
                        }

                        Text("Yearning 会把最近的 Eat、Activity、Sleep 状态压缩成一个判断：现在更适合主动探索、温和互动，还是提前进入安静过渡。")
                            .font(BBBFont.font(size: 12, weight: .semibold))
                            .foregroundStyle(DesignToken.textSecondary)
                            .lineSpacing(3)
                    }
                    .padding(16)
                    .background(detailCardBackground)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Yearning 百分比指导")
                            .font(BBBFont.font(size: 16, weight: .heavy))
                            .foregroundStyle(DesignToken.textPrimary)

                        phaseRow(.golden)
                        phaseRow(.gentle)
                        phaseRow(.earlySleep)
                    }
                    .padding(16)
                    .background(detailCardBackground)

                    easyPhilosophyCard
                }
                .padding(18)
            }
            .background(DesignToken.background.ignoresSafeArea())
            .navigationTitle("EASY 发布器")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .font(BBBFont.font(size: 14, weight: .heavy))
                }
            }
        }
    }

    private var publisherHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(cycle == nil ? "还没有开始循环" : cycleStatusText)
                        .font(BBBFont.font(size: 20, weight: .heavy))
                        .foregroundStyle(DesignToken.textPrimary)
                    Text("\(cycleOverview.startedAtText) · \(elapsedText)")
                        .font(BBBFont.font(size: 12, weight: .heavy))
                        .foregroundStyle(DesignToken.textSecondary)
                }

                Spacer()

                Text(cycleOverview.currentStep.letter)
                    .font(BBBFont.font(size: 18, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(cycleOverview.currentStep.color.opacity(0.92)))
            }

            Text(cycleOverview.guidance)
                .font(BBBFont.font(size: 13, weight: .semibold))
                .foregroundStyle(DesignToken.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(detailCardBackground)
    }

    private var publisherStepCards: some View {
        VStack(spacing: 10) {
            ForEach(EasyCycleStep.allCases) { step in
                let state = cycleOverview.state(for: step)
                HStack(spacing: 11) {
                    Text(step.letter)
                        .font(BBBFont.font(size: 13, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(step.color.opacity(state == .pending ? 0.34 : 0.92)))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(step.title)
                            .font(BBBFont.font(size: 14, weight: .heavy))
                            .foregroundStyle(DesignToken.textPrimary)
                        Text(cycleOverview.value(for: step))
                            .font(BBBFont.font(size: 12, weight: .semibold))
                            .foregroundStyle(DesignToken.textSecondary)
                    }

                    Spacer()

                    Text(stepStateText(state))
                        .font(BBBFont.font(size: 11, weight: .heavy))
                        .foregroundStyle(state == .current ? step.color : DesignToken.textSecondary.opacity(0.64))
                }
                .padding(13)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(state == .current ? step.color.opacity(0.12) : Color.white.opacity(0.56))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(state == .current ? step.color.opacity(0.34) : Color.white.opacity(0.72), lineWidth: 1)
                        )
                )
            }
        }
    }

    private var primaryActionTitle: String {
        guard let cycle else { return "开始一轮" }
        switch cycle.status {
        case .active:
            switch cycle.currentPhase {
            case .eat: return "结束吃，进入玩"
            case .activity: return "开始睡"
            case .sleep: return "醒来了，完成本轮"
            case .yearning: return "发布"
            }
        case .readyToPublish:
            return "发布"
        case .published:
            return "开始下一轮"
        }
    }

    private var cycleStatusText: String {
        guard let cycle else { return "未开始" }
        switch cycle.status {
        case .active: return "正在\(cycle.currentPhase.title)"
        case .readyToPublish: return "待发布"
        case .published: return "已发布"
        }
    }

    private var elapsedText: String {
        guard let cycle else { return "等待开始" }
        let end = cycle.endedAt ?? Date()
        let minutes = max(Int(end.timeIntervalSince(cycle.startedAt) / 60), 0)
        if minutes < 60 { return "已进行 \(minutes)分钟" }
        let hours = minutes / 60
        let remaining = minutes % 60
        return remaining == 0 ? "已进行 \(hours)小时" : "已进行 \(hours)小时\(remaining)分"
    }

    private func stepStateText(_ state: EasyCycleStepState) -> String {
        switch state {
        case .pending: return "待开始"
        case .current: return "当前"
        case .done: return "完成"
        }
    }

    private var easyPhilosophyCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text("作息表是蓝图，不是法律。")
                Text("宝宝是人类，不是机器。")
            }
            .font(BBBFont.font(size: 15, weight: .heavy))
            .foregroundStyle(DesignToken.textPrimary)
            .lineSpacing(2)

            Text("我们希望用 E·A·S·Y 的方式，把一整天的记录变成下一步提示：先照顾宝宝的节奏，也把家长从持续监控的焦虑里放出来。")
                .font(BBBFont.font(size: 12, weight: .semibold))
                .foregroundStyle(DesignToken.textSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            Divider()
                .overlay(DesignToken.line.opacity(0.42))

            VStack(alignment: .leading, spacing: 10) {
                meaningRow(
                    badge: "You",
                    title: "对家长",
                    text: "宝宝安稳睡下后，就是你的恢复时间。能休息就先休息，不需要一边做事一边反复担心。"
                )
                meaningRow(
                    badge: "Yearning",
                    title: "对宝宝",
                    text: "宝宝自然醒来时，大脑和身体刚完成一轮修复。Yearning 关注的，就是他此刻重新进入吃、玩、睡循环前的探索准备度。"
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            DesignToken.easyYearningSoft.opacity(0.72),
                            Color.white.opacity(0.72)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(DesignToken.easyYearning.opacity(0.18), lineWidth: 1)
                )
        )
    }

    private func meaningRow(badge: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            let isLongBadge = badge.count > 1
            Text(badge)
                .font(BBBFont.font(size: isLongBadge ? 8.5 : 12, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: isLongBadge ? 62 : 28, height: 28)
                .background(
                    Capsule(style: .continuous)
                        .fill(DesignToken.easyYearning.opacity(0.88))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(BBBFont.font(size: 12, weight: .heavy))
                    .foregroundStyle(DesignToken.textPrimary)
                Text(text)
                    .font(BBBFont.font(size: 11.5, weight: .semibold))
                    .foregroundStyle(DesignToken.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var detailCardBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(0.58))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(.white.opacity(0.82), lineWidth: 1)
            )
    }

    private func easRow(title: String, value: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Text(String(title.prefix(1)))
                .font(BBBFont.font(size: 12, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(Circle().fill(color.opacity(0.92)))

            Text(title)
                .font(BBBFont.font(size: 13, weight: .heavy))
                .foregroundStyle(DesignToken.textPrimary)

            Spacer()

            Text(value)
                .font(BBBFont.font(size: 13, weight: .heavy))
                .foregroundStyle(DesignToken.textSecondary)
        }
    }

    private func phaseRow(_ phase: YearningPhase) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Circle()
                    .fill(phase.color)
                    .frame(width: 8, height: 8)

                Text("\(phase.rangeText)｜\(phase.title)")
                    .font(BBBFont.font(size: 13, weight: .heavy))
                    .foregroundStyle(DesignToken.textPrimary)
            }

            Text(phase.guidance)
                .font(BBBFont.font(size: 12, weight: .semibold))
                .foregroundStyle(DesignToken.textSecondary)
                .lineSpacing(3)
                .padding(.leading, 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private enum RhythmTimelineKind: Hashable {
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

    var lane: Int {
        switch self {
        case .sleep:
            return 0
        case .bottle, .breast, .solid:
            return 1
        case .diaper:
            return 2
        }
    }
}

private struct RhythmTimelineSpan: Identifiable {
    let id = UUID()
    let startAt: Date
    let endAt: Date
    let kinds: [RhythmTimelineKind]
    let isEstimated: Bool
    let isPoint: Bool

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
            return Gradient(colors: [Color(hex: "#BDA3FF"), DesignToken.easyEat, Color(hex: "#8A70EF")])
        case .activity:
            return Gradient(colors: [Color(hex: "#FFAAB9"), DesignToken.easyActivity, Color(hex: "#F45F79")])
        case .sleep:
            return Gradient(colors: [Color(hex: "#54B1FB"), DesignToken.easySleep, Color(hex: "#3B7EEA")])
        }
    }

    static var diaperCanvasGradient: Gradient {
        Gradient(colors: [Color(hex: "#FFC1A8"), DesignToken.activityDiaper, Color(hex: "#F4875D")])
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

    func centerY(in height: CGFloat) -> CGFloat {
        switch self {
        case .eat: return max(height * 0.22, 9)
        case .activity: return height * 0.50
        case .sleep: return min(height * 0.78, height - 9)
        }
    }
}

private struct TodayRhythmMinimalTimeline: View {
    let date: Date
    let spans: [RhythmTimelineSpan]
    var height: CGFloat

    private let laneLabelWidth: CGFloat = 16
    private let laneSpacing: CGFloat = 12
    private let timeTicks: [(hour: Int, label: String)] = [(0, "00"), (6, "06"), (12, "12"), (18, "18"), (24, "24")]

    private struct RenderMark {
        let id: UUID
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
        let trackHeight = max(height - 16, 42)

        VStack(spacing: 3) {
            HStack(spacing: laneSpacing) {
                laneLabels(trackHeight: trackHeight)
                    .frame(width: laneLabelWidth, height: trackHeight)

                chartCanvas(trackHeight: trackHeight)
            }
            .frame(height: trackHeight)

            HStack(spacing: laneSpacing) {
                Color.clear
                    .frame(width: laneLabelWidth)
                    .accessibilityHidden(true)

                timeScaleLabels
            }
            .frame(height: 10)
        }
        .frame(height: height)
    }

    private func laneLabels(trackHeight: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(TodayRhythmMinimalStage.allCases, id: \.self) { stage in
                Text(stage.badgeTitle)
                    .font(BBBFont.font(size: 7.5, weight: .heavy))
                    .foregroundStyle(stage.color)
                    .frame(width: 14, height: 14)
                    .background(Circle().fill(stage.softColor.opacity(0.74)))
                    .overlay {
                        Circle()
                            .stroke(stage.color.opacity(0.16), lineWidth: 0.7)
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
        .accessibilityLabel("今日 EASY 时间线")
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
        context.stroke(path, with: .color(Color.white.opacity(mark.isEstimated ? 0.18 : 0.36)), lineWidth: 0.55)
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
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                ForEach(timeTicks, id: \.hour) { tick in
                    Text(tick.label)
                        .font(BBBFont.font(size: 7.5, weight: .heavy))
                        .foregroundStyle(DesignToken.textSecondary.opacity(0.58))
                        .frame(width: 20, height: 10)
                        .position(
                            x: clamp(CGFloat(tick.hour) / 24 * proxy.size.width, lower: 10, upper: max(proxy.size.width - 10, 10)),
                            y: 5
                        )
                }
            }
        }
        .frame(height: 10)
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
        if span.isDiaper { return .activity }
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

private struct HomeWalletCardStack<Back: View, Front: View>: View {
    @Binding var isExpanded: Bool
    @ViewBuilder var back: () -> Back
    @ViewBuilder var front: () -> Front

    @State private var stackWidth: CGFloat = 0

    private let collapsedPeekHeight: CGFloat = 52
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
        let id: UUID
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
                                .fill(Color.white.opacity(showsGuide ? 0.26 : 0.16))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: showsGuide ? 16 : 8, style: .continuous)
                                .stroke(Color.white.opacity(showsGuide ? 0.70 : 0.48), lineWidth: 0.8)
                        )

                    Rectangle()
                        .fill(Color.white.opacity(showsGuide ? 0.28 : 0.18))
                        .frame(height: 1)
                        .position(x: width / 2, y: centerY)

                    ForEach([0, 6, 12, 18, 24], id: \.self) { hour in
                        let x = width * CGFloat(hour) / 24
                        Rectangle()
                            .fill(Color.white.opacity(hour == 0 || hour == 24 ? 0.24 : 0.34))
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
                                    Color.white.opacity(0.92),
                                    Color(hex: "#EEF0F5").opacity(0.96)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: railHeight / 2, style: .continuous)
                                .stroke(Color.white.opacity(0.72), lineWidth: 0.6)
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
                                Color.white.opacity(span.isEstimated ? 0.08 : 0.24),
                                Color.white.opacity(0)
                            ],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(span.isEstimated ? 0.26 : 0.48), lineWidth: 0.7)
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
                    .stroke(Color.white.opacity(strokeOpacity), lineWidth: span.isEstimated ? 0.8 : 1)
            )
            .shadow(color: Color.white.opacity(span.isEstimated ? 0.08 : 0.20), radius: 1, y: -0.5)
    }

    @ViewBuilder
    private func diaperMarker(_ span: RhythmTimelineSpan) -> some View {
        Capsule(style: .continuous)
            .fill((span.colors.first ?? DesignToken.activityDiaper).opacity(0.92))
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(0.82), lineWidth: 1)
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
                kinds: [.diaper],
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
                                Color.white.opacity(segment.kinds.isEmpty ? 0.32 : 0.48),
                                Color.white.opacity(0.10),
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
                    .stroke(Color.white.opacity(segment.kinds.isEmpty ? 0.56 : 0.76), lineWidth: 0.8)
            }
            .shadow(color: Color.white.opacity(segment.kinds.isEmpty ? 0.10 : 0.26), radius: 1, y: -0.5)
            .frame(height: height)
            .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private var segmentFill: some View {
        if segment.kinds.isEmpty {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(segment.isFuture ? Color(hex: "#F0EEF8") : Color(hex: "#DCD8E8"))
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
enum DailyVisitorReportFactory {
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

        let report = makeReport(
            date: sourceDate,
            sessions: feedingStore.sessions(on: sourceDate),
            careRecords: activityStore.careRecords(on: sourceDate),
            recruitmentStore: recruitmentStore
        )
        recruitmentStore.storeReport(report)
        return recruitmentStore.report(for: report.reportKey) ?? report
    }

    private static func makeReport(
        date: Date,
        sessions: [FeedingSession],
        careRecords: [CareRecord],
        recruitmentStore: CompanionRecruitmentStore
    ) -> YesterdayReport {
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
            sessions.map(\.createdAt).map { hour(from: $0) } +
            careRecords.map(\.recordedAt).map { hour(from: $0) }
        )
        let feedingHours = Set(sessions.map(\.createdAt).map { hour(from: $0) })
        let diaperHours = Set(careRecords.filter { $0.kind == .diaper }.map { hour(from: $0.recordedAt) })
        let sleepHours = sleepSummary.recordedSleepHours
        let visitContext = CompanionVisitContext(
            reportKey: reportKey,
            feedingCount: sessions.count,
            diaperCount: diaperCount,
            sleepMinutes: recordedSleepMinutes,
            earnedBBBucks: earnedBBBucks,
            activeHourCount: rhythmHours.count
        )
        let visitorCompanions = recruitmentStore.visitorCompanions(for: reportKey, context: visitContext)
        let visitorIDs = visitorCompanions.map(\.id)
        let primaryVisitorID = visitorIDs.first ?? recruitmentStore.visitorCompanion(for: reportKey).id

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
            analysisParts.append("记录睡眠累计 \(recordedSleepMinutes) 分钟。")
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
            visitorCompanionID: primaryVisitorID,
            visitorCompanionIDs: visitorIDs.isEmpty ? [primaryVisitorID] : visitorIDs,
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
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
    }

    private static func hourRangeText(_ firstHour: Int, _ lastHour: Int) -> String {
        if firstHour == lastHour {
            return "\(firstHour):00"
        }
        return "\(firstHour):00-\(lastHour):00"
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

struct YesterdayReportOverlay: View {
    @EnvironmentObject private var recruitmentStore: CompanionRecruitmentStore
    @EnvironmentObject private var easyCycleStore: EasyCycleStore
    @EnvironmentObject private var feedingStore: FeedingStore
    @EnvironmentObject private var activityStore: ActivityStore
    let report: YesterdayReport
    let onDismiss: () -> Void
    @State private var feedingResult: CompanionFeedingResult?

    private var latestReport: YesterdayReport {
        recruitmentStore.report(for: report.reportKey) ?? report
    }

    private var visitors: [BabyCompanion] {
        latestReport.visitorIDs
            .prefix(CompanionRecruitmentStore.dailyBuddyFeedLimit)
            .map { BabyCompanion.companion(for: $0) }
    }

    private var reportEarnedText: String {
        CompanionRecruitmentStore.currencyText(latestReport.earnedBBBucks)
    }

    private var balanceText: String {
        CompanionRecruitmentStore.currencyText(recruitmentStore.bbBucks)
    }

    private var feedingSlotText: String {
        "今日还能照顾 \(recruitmentStore.remainingFeedBuddySlots(in: latestReport)) 位来访伙伴"
    }

    var body: some View {
        ZStack {
            Color(hex: "#3A3A50")
                .opacity(0.16)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("来访卡")
                                .font(BBBFont.font(size: 24, weight: .heavy))
                                .foregroundStyle(DesignToken.textPrimary)
                            Text(report.dateText)
                                .font(BBBFont.font(size: 11, weight: .bold))
                                .foregroundStyle(DesignToken.textSecondary)
                        }

                        Spacer()

                        Button {
                            onDismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .heavy))
                                .foregroundStyle(DesignToken.textSecondary)
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(.white.opacity(0.86)))
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }

                    reportStatGrid

                    reportRhythmBlock
                    reportBlock(title: "分析", icon: "sparkles", text: report.analysisText)
                    visitorBlock

                    if let feedingResult {
                        feedingResultBlock(feedingResult)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.96),
                                    Color(hex: "#FFF7FB").opacity(0.94)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(.white.opacity(0.9), lineWidth: 1.2)
                        )
                        .shadow(color: Color(hex: "#7E5DE8").opacity(0.12), radius: 20, y: 10)
                )
            }
            .frame(maxWidth: 420)
            .frame(maxHeight: 760)
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
    }

    private var visitorBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("来访伙伴")
                        .font(BBBFont.font(size: 14, weight: .heavy))
                        .foregroundStyle(DesignToken.textPrimary)
                    Text("来访奖励 \(reportEarnedText) · 余额 \(balanceText)")
                        .font(BBBFont.font(size: 10, weight: .bold))
                        .foregroundStyle(DesignToken.textSecondary)
                }

                Spacer()

                Text(feedingSlotText)
                    .font(BBBFont.font(size: 10, weight: .heavy))
                    .foregroundStyle(DesignToken.primary)
                    .padding(.horizontal, 9)
                    .frame(height: 24)
                    .background(Capsule().fill(DesignToken.primary.opacity(0.12)))
            }

            VStack(spacing: 9) {
                ForEach(visitors) { visitor in
                    visitorRow(visitor)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(DesignToken.primary.opacity(0.10))
        )
    }

    private func visitorRow(_ visitor: BabyCompanion) -> some View {
        let progress = recruitmentStore.friendshipPercent(for: visitor.id)
        let remainingServings = recruitmentStore.remainingServings(for: visitor.id, in: latestReport)
        let canFeed = recruitmentStore.canFeed(companionID: visitor.id, from: latestReport)
        let feeding = recruitmentStore.feeding(for: visitor.id, in: latestReport)
        let servedText = "\(visitor.chineseName)今天还能吃 \(remainingServings) 份"

        return HStack(spacing: 10) {
            Image(visitor.portraitAssetName)
                .resizable()
                .scaledToFit()
                .frame(width: 50, height: 50)
                .padding(4)
                .background(Circle().fill(.white.opacity(0.88)))
                .overlay(Circle().stroke(DesignToken.primary.opacity(0.22), lineWidth: 1))

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 7) {
                    Text(visitor.chineseName)
                        .font(BBBFont.font(size: 13, weight: .heavy))
                        .foregroundStyle(DesignToken.textPrimary)
                    Text(visitor.rarity.title)
                        .font(BBBFont.font(size: 9, weight: .heavy))
                        .foregroundStyle(DesignToken.primary)
                        .padding(.horizontal, 6)
                        .frame(height: 18)
                        .background(Capsule().fill(DesignToken.primary.opacity(0.12)))

                    Spacer()

                    Text("\(Int((progress * 100).rounded()))%")
                        .font(BBBFont.font(size: 12, weight: .heavy))
                        .foregroundStyle(DesignToken.primary)
                }

                ProgressView(value: progress)
                    .tint(DesignToken.primary)

                HStack(spacing: 8) {
                    Text(remainingServings > 0 ? servedText : "\(visitor.chineseName)吃饱啦，明天再来吧")
                        .font(BBBFont.font(size: 10, weight: .bold))
                        .foregroundStyle(DesignToken.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    if let feeding, feeding.bonusServings > 0 {
                        Text("合口味")
                            .font(BBBFont.font(size: 9, weight: .heavy))
                            .foregroundStyle(Color(hex: "#D8A64E"))
                            .padding(.horizontal, 6)
                            .frame(height: 18)
                            .background(Capsule().fill(Color(hex: "#FFF3D1")))
                    }

                    Spacer()

                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                            feedingResult = recruitmentStore.feedVisitor(companionID: visitor.id, from: latestReport)
                        }
                    } label: {
                        Text(recruitmentStore.feedButtonTitle(for: visitor.id, in: latestReport))
                            .font(BBBFont.font(size: 11, weight: .heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 11)
                            .frame(height: 30)
                            .background(Capsule().fill(canFeed ? DesignToken.primaryGradient : LinearGradient(colors: [Color(hex: "#D6D4DF"), Color(hex: "#C9C5D6")], startPoint: .leading, endPoint: .trailing)))
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(!canFeed)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.white.opacity(0.72))
        )
    }

    private func feedingResultBlock(_ result: CompanionFeedingResult) -> some View {
        let companion = BabyCompanion.companion(for: result.companionID)
        let progressPercent = Int((result.progress * 100).rounded())

        return HStack(spacing: 10) {
            Image(systemName: result.didRecruit ? "checkmark.seal.fill" : "heart.fill")
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(result.didRecruit ? Color(hex: "#67C587") : DesignToken.primary)
                .frame(width: 32, height: 32)
                .background(Circle().fill(.white.opacity(0.82)))

            VStack(alignment: .leading, spacing: 3) {
                Text(result.didRecruit ? "\(companion.chineseName) 已解锁" : "友情值增加到 \(progressPercent)%")
                    .font(BBBFont.font(size: 13, weight: .heavy))
                    .foregroundStyle(DesignToken.textPrimary)
                Text(feedingResultText(result))
                    .font(BBBFont.font(size: 10, weight: .bold))
                    .foregroundStyle(DesignToken.textSecondary)
            }

            Spacer()
        }
        .padding(11)
        .background(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill((result.didRecruit ? Color(hex: "#67C587") : DesignToken.primary).opacity(0.12))
        )
    }

    private func feedingResultText(_ result: CompanionFeedingResult) -> String {
        let base = "使用 1 BB Buck 换一份小点心"
        guard result.isBonus else { return base }
        return "\(base)，很合口味，友情增加 3 倍"
    }

    private var reportStatGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 8)], spacing: 8) {
            reportStat(title: "喂养", value: "\(report.feedingCount)次", color: DesignToken.easyEat)
            reportStat(title: "奶量", value: report.bottleAmount > 0 ? "\(report.bottleAmount)ml" : "暂无", color: DesignToken.feedingBottle)
            reportStat(title: "母乳", value: report.breastMinutes > 0 ? "\(report.breastMinutes)分" : "暂无", color: DesignToken.feedingBreast)
            reportStat(title: "尿布", value: report.diaperCount > 0 ? "\(report.diaperCount)次" : "暂无", color: DesignToken.activityDiaper)
        }
    }

    private func reportStat(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(BBBFont.font(size: 9, weight: .bold))
                .foregroundStyle(DesignToken.textSecondary)
            Text(value)
                .font(BBBFont.font(size: 13, weight: .heavy))
                .foregroundStyle(DesignToken.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(color.opacity(0.10))
        )
    }

    private var reportRhythmBlock: some View {
        VStack(alignment: .leading, spacing: 9) {
            DailyVisitRhythmSequenceChart(
                report: latestReport,
                cycles: easyCycleStore.cycles(on: latestReport.date),
                feedingSessions: feedingStore.sessions(on: latestReport.date),
                careRecords: activityStore.careRecordsForSleepSummary(on: latestReport.date)
            )

            Text(report.rhythmText)
                .font(BBBFont.font(size: 11, weight: .semibold))
                .foregroundStyle(DesignToken.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(DesignToken.iconSoftBG.opacity(0.54))
        )
    }

    private func reportBlock(title: String, icon: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(title, systemImage: icon)
                .font(BBBFont.font(size: 13, weight: .heavy))
                .foregroundStyle(DesignToken.textPrimary)
            Text(text)
                .font(BBBFont.font(size: 11, weight: .semibold))
                .foregroundStyle(DesignToken.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(DesignToken.iconSoftBG.opacity(0.56))
        )
    }
}

private struct DailyVisitRhythmSequenceChart: View {
    let report: YesterdayReport
    let cycles: [EasyCycle]
    let feedingSessions: [FeedingSession]
    let careRecords: [CareRecord]

    private var events: [DailyVisitRhythmEvent] {
        DailyVisitRhythmEvent.events(for: report)
    }

    private var rawSpans: [DailyVisitRhythmSpan] {
        let cycleSpans = DailyVisitRhythmSpan.spans(
            cycles: cycles,
            feedingSessions: feedingSessions,
            careRecords: careRecords
        )
        return cycleSpans.isEmpty ? DailyVisitRhythmSpan.fallbackSpans(for: report) : cycleSpans
    }

    private var spans: [DailyVisitRhythmSpan] {
        DailyVisitRhythmSpan.mergingContinuousSleepSpans(rawSpans)
    }

    private var steadiness: Int {
        guard !spans.isEmpty else { return 0 }
        let activeHours = Set(spans.flatMap(\.coveredHours)).count
        let totalEvents = spans.count
        let repetitionScore = min(totalEvents * 7, 55)
        let spreadScore = min(activeHours * 4, 35)
        let balanceScore = (report.feedingCount > 0 && report.sleepMinutes > 0) ? 10 : 0
        return min(repetitionScore + spreadScore + balanceScore, 95)
    }

    private var timeLabels: [String] {
        ["00:00", "06:00", "12:00", "18:00", "24:00"]
    }

    private let laneLabelWidth: CGFloat = 18
    private let rhythmTrackHeight: CGFloat = 72
    private let rhythmTrackSpacing: CGFloat = 8

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                Text("Daily Rhythm")
                    .font(BBBFont.font(size: 13, weight: .heavy))
                    .foregroundStyle(DesignToken.textPrimary)

                Spacer()

                Text(spans.isEmpty ? "待记录" : "\(steadiness)% Steady")
                    .font(BBBFont.font(size: 11, weight: .heavy))
                    .foregroundStyle(DesignToken.primary)
            }

            if spans.isEmpty {
                Text("还没有形成明显节奏")
                    .font(BBBFont.font(size: 12, weight: .bold))
                    .foregroundStyle(DesignToken.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 46, alignment: .center)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(.white.opacity(0.58))
                    )
            } else {
                layeredRhythmTrack

                HStack(spacing: rhythmTrackSpacing) {
                    Color.clear
                        .frame(width: laneLabelWidth)
                        .accessibilityHidden(true)

                    HStack {
                        ForEach(timeLabels, id: \.self) { label in
                            Text(label)
                                .font(BBBFont.font(size: 9, weight: .heavy))
                                .foregroundStyle(DesignToken.textSecondary.opacity(0.62))
                                .frame(maxWidth: .infinity, alignment: label == timeLabels.first ? .leading : (label == timeLabels.last ? .trailing : .center))
                        }
                    }
                }
            }
        }
    }

    private var layeredRhythmTrack: some View {
        GeometryReader { proxy in
            let dayStart = Calendar.current.startOfDay(for: report.date)
            let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart) ?? report.date

            HStack(spacing: rhythmTrackSpacing) {
                laneLabels
                    .frame(width: laneLabelWidth, height: rhythmTrackHeight)

                DailyVisitRhythmCanvasChart(
                    spans: spans,
                    dayStart: dayStart,
                    dayEnd: dayEnd
                )
            }
        }
        .frame(height: rhythmTrackHeight)
    }

    private var laneLabels: some View {
        ZStack(alignment: .topLeading) {
            ForEach(DailyVisitRhythmKind.allCases, id: \.self) { kind in
                Text(kind.badgeTitle)
                    .font(BBBFont.font(size: 8, weight: .heavy))
                    .foregroundStyle(kind.color)
                    .frame(width: 16, height: 16)
                    .background(
                        Circle()
                            .fill(kind.softColor.opacity(0.74))
                    )
                    .overlay {
                        Circle()
                            .stroke(kind.color.opacity(0.16), lineWidth: 0.7)
                    }
                    .position(x: laneLabelWidth / 2, y: kind.centerY)
            }
        }
    }

    fileprivate static func hourText(_ hour: Int) -> String {
        "\(String(format: "%02d", hour)):00"
    }

    fileprivate static func timeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

private struct DailyVisitRhythmCanvasChart: View {
    let spans: [DailyVisitRhythmSpan]
    let dayStart: Date
    let dayEnd: Date

    private struct RenderMark {
        let id: String
        let kind: DailyVisitRhythmKind
        let startAt: Date
        let endAt: Date
        let cycleID: UUID?
        let startX: CGFloat
        let endX: CGFloat
        let centerX: CGFloat
        let width: CGFloat
        let usesDiaperAccent: Bool

        var centerY: CGFloat {
            kind.centerY
        }

        var rect: CGRect {
            CGRect(
                x: centerX - width / 2,
                y: kind.centerY - kind.trackHeight / 2,
                width: width,
                height: kind.trackHeight
            )
        }

        var accentColor: Color {
            usesDiaperAccent ? DesignToken.activityDiaper : kind.color
        }

        var fillGradient: Gradient {
            usesDiaperAccent ? DailyVisitRhythmKind.diaperCanvasGradient : kind.canvasGradient
        }
    }

    var body: some View {
        let cleanedSpans = cleanedTimelineSpans()
        Canvas { context, size in
            let bounds = CGRect(origin: .zero, size: size)
            let marks = renderMarks(from: cleanedSpans, in: bounds)
            drawBackground(in: bounds, context: &context)
            drawStageConnections(marks: marks, context: &context)
            drawSleepLayer(marks: marks, context: &context)
            drawEatLayer(marks: marks, context: &context)
            drawActivityLayer(marks: marks, context: &context)
            drawHourTicks(in: bounds, context: &context)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("每日节奏图")
    }

    private func drawBackground(in bounds: CGRect, context: inout GraphicsContext) {
        let path = Path(roundedRect: bounds, cornerRadius: 16)
        context.fill(
            path,
            with: .linearGradient(
                Gradient(colors: [
                    Color.white.opacity(0.66),
                    Color(hex: "#F5F3FA").opacity(0.34),
                    Color(hex: "#EEF4FA").opacity(0.26)
                ]),
                startPoint: CGPoint(x: bounds.minX, y: bounds.minY),
                endPoint: CGPoint(x: bounds.maxX, y: bounds.maxY)
            )
        )
        context.stroke(path, with: .color(DesignToken.borderSubtle.opacity(0.34)), lineWidth: 0.65)
    }

    private func drawStageConnections(marks: [RenderMark], context: inout GraphicsContext) {
        let groupedMarks = Dictionary(grouping: marks.compactMap { mark -> (UUID, RenderMark)? in
            guard let cycleID = mark.cycleID else { return nil }
            return (cycleID, mark)
        }, by: \.0)

        for (_, pairs) in groupedMarks {
            let orderedMarks = pairs
                .map(\.1)
                .sorted {
                    if $0.startAt == $1.startAt {
                        return $0.kind.drawOrder < $1.kind.drawOrder
                    }
                    return $0.startAt < $1.startAt
                }

            guard orderedMarks.count > 1 else { continue }

            var previous = orderedMarks[0]
            for mark in orderedMarks.dropFirst() {
                guard previous.kind != mark.kind else {
                    previous = mark
                    continue
                }

                let connection = stageConnection(from: previous, to: mark)

                context.stroke(
                    connection.path,
                    with: .color(DailyVisitRhythmKind.connectorColor),
                    lineWidth: 1.15
                )

                previous = mark
            }
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
            start = CGPoint(
                x: centerX,
                y: movingDown ? previous.rect.maxY : previous.rect.minY
            )
            end = CGPoint(
                x: centerX,
                y: movingDown ? mark.rect.minY : mark.rect.maxY
            )
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

    private func drawSleepLayer(marks: [RenderMark], context: inout GraphicsContext) {
        for mark in marks where mark.kind == .sleep {
            drawRhythmCapsule(
                rect: mark.rect,
                kind: mark.kind,
                context: &context,
                shadowOpacity: 0.10,
                glowOpacity: 0.15
            )
        }
    }

    private func drawEatLayer(marks: [RenderMark], context: inout GraphicsContext) {
        for mark in marks where mark.kind == .eat {
            drawRhythmCapsule(
                rect: mark.rect,
                kind: mark.kind,
                context: &context,
                shadowOpacity: 0.10,
                glowOpacity: 0.15
            )
        }
    }

    private func drawActivityLayer(marks: [RenderMark], context: inout GraphicsContext) {
        for mark in marks where mark.kind == .activity {
            drawRhythmCapsule(
                rect: mark.rect,
                kind: mark.kind,
                context: &context,
                fillGradient: mark.fillGradient,
                accentColor: mark.accentColor,
                shadowOpacity: 0.10,
                glowOpacity: 0.14
            )
        }
    }

    private func drawHourTicks(in bounds: CGRect, context: inout GraphicsContext) {
        for hour in [0, 6, 12, 18, 24] {
            let x = clamp(xPosition(hour, width: bounds.width), lower: 1, upper: bounds.width - 1)
            let rect = CGRect(x: x - 0.5, y: bounds.maxY - 9, width: 1, height: 5)
            let opacity = hour == 0 || hour == 24 ? 0.08 : 0.11
            context.fill(Path(roundedRect: rect, cornerRadius: 0.5), with: .color(DesignToken.textSecondary.opacity(opacity)))
        }
    }

    private func drawRhythmCapsule(
        rect: CGRect,
        kind: DailyVisitRhythmKind,
        context: inout GraphicsContext,
        fillGradient: Gradient? = nil,
        accentColor: Color? = nil,
        shadowOpacity: Double,
        glowOpacity: Double
    ) {
        let cornerRadius = kind.markCornerRadius(for: rect.height)
        let path = Path(roundedRect: rect, cornerRadius: cornerRadius)
        let resolvedGradient = fillGradient ?? kind.canvasGradient
        let resolvedAccent = accentColor ?? kind.color

        context.drawLayer { layer in
            layer.addFilter(.shadow(color: resolvedAccent.opacity(shadowOpacity), radius: 3.2, x: 0, y: 1.2))
            layer.fill(
                path,
                with: .linearGradient(
                    resolvedGradient,
                    startPoint: CGPoint(x: rect.minX, y: rect.minY),
                    endPoint: CGPoint(x: rect.maxX, y: rect.maxY)
                )
            )
            layer.fill(
                Path(
                    roundedRect: rect.insetBy(dx: 1, dy: 1).offsetBy(dx: 0, dy: -1),
                    cornerRadius: max(cornerRadius - 1, 1)
                ),
                with: .linearGradient(
                    Gradient(colors: [
                        Color.white.opacity(0.22),
                        Color.white.opacity(0.02)
                    ]),
                    startPoint: CGPoint(x: rect.midX, y: rect.minY),
                    endPoint: CGPoint(x: rect.midX, y: rect.midY)
                )
            )
            layer.stroke(path, with: .color(Color.white.opacity(0.38)), lineWidth: 0.55)
            layer.stroke(path, with: .color(resolvedAccent.opacity(glowOpacity)), lineWidth: 0.8)
        }
    }

    private func cleanedTimelineSpans() -> [DailyVisitRhythmSpan] {
        let clamped = spans.compactMap { span -> DailyVisitRhythmSpan? in
            let start = max(span.startAt, dayStart)
            let end = min(max(span.endAt, span.startAt.addingTimeInterval(60)), dayEnd)
            guard end > start else { return nil }
            return DailyVisitRhythmSpan(
                id: span.id,
                kind: span.kind,
                startAt: start,
                endAt: end,
                cycleID: span.cycleID,
                isPointEvent: span.isPointEvent,
                usesDiaperAccent: span.usesDiaperAccent
            )
        }
        .sorted {
            if $0.startAt == $1.startAt {
                return $0.kind.drawOrder < $1.kind.drawOrder
            }
            return $0.startAt < $1.startAt
        }

        return clamped.reduce(into: [DailyVisitRhythmSpan]()) { result, span in
            guard let previous = result.last,
                  !previous.isPointEvent,
                  !span.isPointEvent,
                  previous.kind == span.kind,
                  previous.cycleID == span.cycleID,
                  span.startAt <= previous.endAt.addingTimeInterval(3 * 60) else {
                result.append(span)
                return
            }

            result[result.count - 1] = DailyVisitRhythmSpan(
                id: "\(previous.id)-cleaned-\(span.id)",
                kind: previous.kind,
                startAt: min(previous.startAt, span.startAt),
                endAt: max(previous.endAt, span.endAt),
                cycleID: previous.cycleID,
                isPointEvent: false,
                usesDiaperAccent: previous.usesDiaperAccent && span.usesDiaperAccent
            )
        }
    }

    private func renderMarks(from timelineSpans: [DailyVisitRhythmSpan], in bounds: CGRect) -> [RenderMark] {
        DailyVisitRhythmKind.allCases.flatMap { kind in
            let laneSpans = timelineSpans.filter { $0.kind == kind }
            return renderMarks(for: laneSpans, kind: kind, width: bounds.width)
        }
    }

    private func renderMarks(for laneSpans: [DailyVisitRhythmSpan], kind: DailyVisitRhythmKind, width: CGFloat) -> [RenderMark] {
        let baseMarks = laneSpans.map { span -> (span: DailyVisitRhythmSpan, startX: CGFloat, endX: CGFloat, centerX: CGFloat, width: CGFloat) in
            let startX = xPosition(span.startAt, width: width)
            let endX = xPosition(span.endAt, width: width)
            let rawWidth = max(endX - startX, 1)
            let visualWidth = span.isPointEvent ? kind.minimumWidth : max(rawWidth, span.minimumVisualWidth)
            let centerX = clamp(startX + rawWidth / 2, lower: visualWidth / 2, upper: width - visualWidth / 2)
            return (span, startX, endX, centerX, visualWidth)
        }

        let compactMarks = baseMarks.enumerated().map { index, item in
            var visualWidth = item.width
            if item.span.isPointEvent {
                let leftGap = index > 0 ? item.centerX - baseMarks[index - 1].centerX : CGFloat.greatestFiniteMagnitude
                let rightGap = index < baseMarks.count - 1 ? baseMarks[index + 1].centerX - item.centerX : CGFloat.greatestFiniteMagnitude
                let nearestGap = min(leftGap, rightGap)
                if nearestGap.isFinite {
                    visualWidth = min(visualWidth, max(kind.minimumCompactWidth, nearestGap - 2))
                }
            }

            let centerX = clamp(item.centerX, lower: visualWidth / 2, upper: width - visualWidth / 2)
            return (
                span: item.span,
                startX: item.startX,
                endX: item.endX,
                centerX: centerX,
                width: visualWidth
            )
        }

        let resolvedCenters = nonOverlappingCenters(
            compactMarks.map { ($0.centerX, $0.width) },
            in: width,
            gap: kind.minimumVisualGap
        )

        return compactMarks.enumerated().map { index, item in
            RenderMark(
                id: item.span.id,
                kind: kind,
                startAt: item.span.startAt,
                endAt: item.span.endAt,
                cycleID: item.span.cycleID,
                startX: item.startX,
                endX: item.endX,
                centerX: resolvedCenters[index],
                width: item.width,
                usesDiaperAccent: item.span.usesDiaperAccent
            )
        }
    }

    private func nonOverlappingCenters(_ marks: [(center: CGFloat, width: CGFloat)], in totalWidth: CGFloat, gap: CGFloat) -> [CGFloat] {
        guard !marks.isEmpty else { return [] }
        var centers = marks.map(\.center)

        for index in centers.indices.dropFirst() {
            let minimumCenter = centers[index - 1] + marks[index - 1].width / 2 + marks[index].width / 2 + gap
            centers[index] = max(centers[index], minimumCenter)
        }

        if let lastIndex = centers.indices.last {
            centers[lastIndex] = min(centers[lastIndex], totalWidth - marks[lastIndex].width / 2)
            if lastIndex > 0 {
                for index in stride(from: lastIndex - 1, through: 0, by: -1) {
                    let maximumCenter = centers[index + 1] - marks[index + 1].width / 2 - marks[index].width / 2 - gap
                    centers[index] = min(centers[index], maximumCenter)
                    centers[index] = max(centers[index], marks[index].width / 2)
                }
            }
        }

        return centers.enumerated().map { index, center in
            clamp(center, lower: marks[index].width / 2, upper: totalWidth - marks[index].width / 2)
        }
    }

    private func xPosition(_ hour: Int, width: CGFloat) -> CGFloat {
        guard let date = Calendar.current.date(byAdding: .hour, value: hour, to: dayStart) else { return 0 }
        return xPosition(date, width: width)
    }

    private func xPosition(_ date: Date, width: CGFloat) -> CGFloat {
        let total = max(dayEnd.timeIntervalSince(dayStart), 1)
        let seconds = min(max(date.timeIntervalSince(dayStart), 0), total)
        return CGFloat(seconds / total) * width
    }

    private func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        min(max(value, lower), upper)
    }
}

private struct DailyVisitRhythmEvent: Identifiable {
    let id: String
    let hour: Int
    let kind: DailyVisitRhythmKind

    var accessibilityLabel: String {
        "\(DailyVisitRhythmSequenceChart.hourText(hour)) \(kind.title)"
    }

    static func events(for report: YesterdayReport) -> [DailyVisitRhythmEvent] {
        var result: [DailyVisitRhythmEvent] = []
        for hour in 0..<24 {
            if report.sleepHours.contains(hour) {
                result.append(DailyVisitRhythmEvent(id: "\(hour)-sleep", hour: hour, kind: .sleep))
            }
            if report.feedingHours.contains(hour) {
                result.append(DailyVisitRhythmEvent(id: "\(hour)-eat", hour: hour, kind: .eat))
            }
            if report.diaperHours.contains(hour) {
                result.append(DailyVisitRhythmEvent(id: "\(hour)-activity", hour: hour, kind: .activity))
            }
        }
        return result
    }
}

private struct DailyVisitRhythmSpan: Identifiable {
    let id: String
    let kind: DailyVisitRhythmKind
    let startAt: Date
    let endAt: Date
    let cycleID: UUID?
    var isPointEvent: Bool = false
    var usesDiaperAccent: Bool = false

    var accessibilityLabel: String {
        "\(DailyVisitRhythmSequenceChart.timeText(startAt))-\(DailyVisitRhythmSequenceChart.timeText(endAt)) \(kind.title)"
    }

    var coveredHours: [Int] {
        let calendar = Calendar.current
        let clampedEnd = max(endAt, startAt.addingTimeInterval(60))
        var hours: [Int] = []
        var cursor = startAt
        while cursor <= clampedEnd {
            hours.append(calendar.component(.hour, from: cursor))
            guard let next = calendar.date(byAdding: .hour, value: 1, to: cursor) else { break }
            cursor = next
        }
        return hours
    }

    var minimumVisualWidth: CGFloat {
        if isPointEvent {
            return kind.minimumWidth
        }
        return kind.durationMinimumWidth
    }

    static func spans(
        cycles: [EasyCycle],
        feedingSessions: [FeedingSession],
        careRecords: [CareRecord]
    ) -> [DailyVisitRhythmSpan] {
        let sessionsByID = Dictionary(uniqueKeysWithValues: feedingSessions.map { ($0.id, $0) })
        let careRecordsByID = Dictionary(uniqueKeysWithValues: careRecords.map { ($0.id, $0) })

        return cycles.flatMap { cycle -> [DailyVisitRhythmSpan] in
            cycle.linkedRecords.compactMap { link -> DailyVisitRhythmSpan? in
                switch (link.type, link.phase) {
                case (.feeding, .eat):
                    guard let session = sessionsByID[link.recordID] else { return nil }
                    let timeSpan = session.resolvedTimeSpan(ageMonths: nil)
                    let endAt = timeSpan.isPoint ? timeSpan.startAt.addingTimeInterval(8 * 60) : timeSpan.endAt
                    return DailyVisitRhythmSpan(
                        id: "\(cycle.id.uuidString)-eat-\(session.id.uuidString)",
                        kind: .eat,
                        startAt: timeSpan.startAt,
                        endAt: max(endAt, timeSpan.startAt.addingTimeInterval(60)),
                        cycleID: cycle.id
                    )
                case (.care, .activity):
                    guard let record = careRecordsByID[link.recordID],
                          record.kind != .sleep else { return nil }
                    let isDiaper = record.kind == .diaper
                    let duration = isDiaper ? 6 : (SleepRecordFormatter.durationMinutes(from: record.detail) ?? 10)
                    return DailyVisitRhythmSpan(
                        id: "\(cycle.id.uuidString)-activity-\(record.id.uuidString)",
                        kind: .activity,
                        startAt: record.recordedAt,
                        endAt: record.recordedAt.addingTimeInterval(TimeInterval(duration * 60)),
                        cycleID: cycle.id,
                        isPointEvent: isDiaper,
                        usesDiaperAccent: isDiaper
                    )
                case (.care, .sleep):
                    guard let record = careRecordsByID[link.recordID],
                          record.kind == .sleep,
                          let duration = SleepRecordFormatter.durationMinutes(from: record.detail) else {
                        return nil
                    }
                    return DailyVisitRhythmSpan(
                        id: "\(cycle.id.uuidString)-sleep-\(record.id.uuidString)",
                        kind: .sleep,
                        startAt: record.recordedAt,
                        endAt: SleepRecordFormatter.endTime(start: record.recordedAt, durationMinutes: duration),
                        cycleID: cycle.id
                    )
                default:
                    return nil
                }
            }
        }
        .sorted {
            if $0.startAt == $1.startAt {
                return $0.kind.drawOrder < $1.kind.drawOrder
            }
            return $0.startAt < $1.startAt
        }
    }

    static func fallbackSpans(for report: YesterdayReport) -> [DailyVisitRhythmSpan] {
        [
            fallbackSpans(for: report.sleepHours, kind: .sleep, date: report.date),
            fallbackSpans(for: report.feedingHours, kind: .eat, date: report.date),
            fallbackSpans(for: report.diaperHours, kind: .activity, date: report.date)
        ]
        .flatMap { $0 }
        .sorted {
            if $0.startAt == $1.startAt {
                return $0.kind.drawOrder < $1.kind.drawOrder
            }
            return $0.startAt < $1.startAt
        }
    }

    static func mergingContinuousSleepSpans(_ spans: [DailyVisitRhythmSpan]) -> [DailyVisitRhythmSpan] {
        let nonSleepSpans = spans.filter { $0.kind != .sleep }
        let sleepSpans = spans
            .filter { $0.kind == .sleep }
            .sorted { $0.startAt < $1.startAt }
        let mergedSleepSpans = sleepSpans.reduce(into: [DailyVisitRhythmSpan]()) { result, span in
            guard let previous = result.last else {
                result.append(span)
                return
            }

            let mergeTolerance: TimeInterval = 2 * 60
            guard span.startAt <= previous.endAt.addingTimeInterval(mergeTolerance) else {
                result.append(span)
                return
            }

            result[result.count - 1] = DailyVisitRhythmSpan(
                id: "\(previous.id)-merged-\(span.id)",
                kind: .sleep,
                startAt: min(previous.startAt, span.startAt),
                endAt: max(previous.endAt, span.endAt),
                cycleID: previous.cycleID == span.cycleID ? previous.cycleID : nil,
                isPointEvent: false,
                usesDiaperAccent: false
            )
        }

        return (mergedSleepSpans + nonSleepSpans)
            .sorted {
                if $0.startAt == $1.startAt {
                    return $0.kind.drawOrder < $1.kind.drawOrder
                }
                return $0.startAt < $1.startAt
            }
    }

    private static func fallbackSpans(for hours: Set<Int>, kind: DailyVisitRhythmKind, date: Date) -> [DailyVisitRhythmSpan] {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        return hours
            .filter { (0..<24).contains($0) }
            .sorted()
            .compactMap { hour in
                guard let start = calendar.date(byAdding: .hour, value: hour, to: dayStart) else { return nil }
                let duration: TimeInterval = kind == .sleep ? 60 * 60 : (kind == .eat ? 18 * 60 : 8 * 60)
                return DailyVisitRhythmSpan(
                    id: "fallback-\(kind.title)-\(hour)",
                    kind: kind,
                    startAt: start,
                    endAt: start.addingTimeInterval(duration),
                    cycleID: nil,
                    isPointEvent: kind == .activity,
                    usesDiaperAccent: kind == .activity
                )
            }
    }
}

private enum DailyVisitRhythmKind {
    case sleep
    case eat
    case activity

    static let allCases: [DailyVisitRhythmKind] = [.eat, .activity, .sleep]

    var title: String {
        switch self {
        case .sleep: return "Sleep"
        case .eat: return "Eat"
        case .activity: return "Activity"
        }
    }

    var badgeTitle: String {
        switch self {
        case .eat: return "E"
        case .activity: return "A"
        case .sleep: return "S"
        }
    }

    var color: Color {
        switch self {
        case .sleep: return DesignToken.easySleep
        case .eat: return DesignToken.easyEat
        case .activity: return DesignToken.easyActivity
        }
    }

    var softColor: Color {
        switch self {
        case .sleep: return DesignToken.easySleepSoft
        case .eat: return DesignToken.easyEatSoft
        case .activity: return DesignToken.easyActivitySoft
        }
    }

    var gradient: LinearGradient {
        switch self {
        case .sleep:
            return LinearGradient(
                colors: [Color(hex: "#4EA4F6"), DesignToken.easySleep, Color(hex: "#3D7DE8")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .eat:
            return LinearGradient(
                colors: [Color(hex: "#B798FF"), DesignToken.easyEat, Color(hex: "#8D72F1")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .activity:
            return LinearGradient(
                colors: [Color(hex: "#FFA4B4"), DesignToken.easyActivity, Color(hex: "#F35F78")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    var canvasGradient: Gradient {
        switch self {
        case .sleep:
            return Gradient(colors: [Color(hex: "#54B1FB"), DesignToken.easySleep, Color(hex: "#3B7EEA")])
        case .eat:
            return Gradient(colors: [Color(hex: "#BDA3FF"), DesignToken.easyEat, Color(hex: "#8A70EF")])
        case .activity:
            return Gradient(colors: [Color(hex: "#FFAAB9"), DesignToken.easyActivity, Color(hex: "#F45F79")])
        }
    }

    static var diaperCanvasGradient: Gradient {
        Gradient(colors: [Color(hex: "#FFC1A8"), DesignToken.activityDiaper, Color(hex: "#F4875D")])
    }

    static var connectorColor: Color {
        DesignToken.textMuted.opacity(0.28)
    }

    var centerY: CGFloat {
        switch self {
        case .eat: return 15
        case .activity: return 34
        case .sleep: return 53
        }
    }

    var trackHeight: CGFloat {
        11
    }

    var minimumWidth: CGFloat {
        switch self {
        case .activity: return 5
        case .eat: return 5
        case .sleep: return 6
        }
    }

    var durationMinimumWidth: CGFloat {
        switch self {
        case .activity: return 5
        case .eat: return 5
        case .sleep: return 8
        }
    }

    var minimumCompactWidth: CGFloat {
        switch self {
        case .activity: return 3
        case .eat: return durationMinimumWidth
        case .sleep: return durationMinimumWidth
        }
    }

    var minimumVisualGap: CGFloat {
        switch self {
        case .activity: return 2
        case .eat: return 2
        case .sleep: return 1
        }
    }

    func markCornerRadius(for height: CGFloat) -> CGFloat {
        max(height / 6, 2)
    }

    var drawOrder: Int {
        switch self {
        case .sleep: return 0
        case .eat: return 1
        case .activity: return 2
        }
    }
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

private enum RecordHomeTimelineItem: Identifiable {
    case feeding(FeedingSession)
    case care(CareRecord)
    case growth(GrowthMetricRecord)

    var id: String {
        switch self {
        case .feeding(let session): return "feeding-\(session.id.uuidString)"
        case .care(let record): return "care-\(record.id.uuidString)"
        case .growth(let record): return "growth-\(record.id.uuidString)"
        }
    }

    var date: Date {
        switch self {
        case .feeding(let session): return session.createdAt
        case .care(let record): return record.recordedAt
        case .growth(let record): return record.recordedAt
        }
    }

    var title: String {
        switch self {
        case .feeding(let session): return session.displayName
        case .care(let record):
            return record.kind == .diaper ? DiaperRecordType.normalizedTitle(record.title) : record.title
        case .growth(let record): return "记录\(record.kind.title)"
        }
    }

    var detail: String {
        switch self {
        case .feeding(let session): return feedingDetail(for: session)
        case .care(let record): return careDetail(for: record)
        case .growth(let record):
            let value = String(format: "%.1f", record.value)
            let note = record.note.trimmingCharacters(in: .whitespacesAndNewlines)
            return note.isEmpty ? "\(value)\(record.unit)" : "\(value)\(record.unit) · \(note)"
        }
    }

    var timeText: String {
        switch self {
        case .feeding(let session):
            if let startAt = session.startAt,
               let endAt = session.endAt,
               endAt > startAt {
                return timeRangeText(start: startAt, end: endAt)
            }
            return timeText(for: session.createdAt)
        case .care(let record):
            if record.kind == .sleep,
               let durationMinutes = SleepRecordFormatter.durationMinutes(from: record.detail) {
                let endAt = SleepRecordFormatter.endTime(start: record.recordedAt, durationMinutes: durationMinutes)
                return timeRangeText(start: record.recordedAt, end: endAt)
            }
            return timeText(for: record.recordedAt)
        case .growth(let record):
            return timeText(for: record.recordedAt)
        }
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
        }
    }

    var easyIconAssetName: String {
        switch self {
        case .feeding:
            return "record_action_easy_eat_icon"
        case .care(let record):
            switch record.kind {
            case .diaper: return "record_action_easy_activity_icon"
            case .activity: return "record_action_easy_activity_icon"
            case .sleep: return "record_action_easy_sleep_icon"
            }
        case .growth:
            return "record_action_easy_yearning_icon"
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
        case .growth: return DesignToken.easyYearning
    }
    }

    private func feedingDetail(for session: FeedingSession) -> String {
        let cleanedNotes = session.notes
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
        let imageText = session.imageData == nil ? "" : "有图片"
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

    private func careDetail(for record: CareRecord) -> String {
        let cleanedDetail = record.detail
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

        let amountByMilkType = Dictionary(grouping: bottleEntries, by: { $0.milkType ?? .formula })
            .compactMap { milkType, entries -> String? in
                let amount = entries.compactMap(\.bottleAmount).reduce(0, +)
                guard amount > 0 else { return nil }
                return "\(milkType.displayName)\(amount)ml"
            }
            .sorted()
        let duration = bottleEntries.compactMap(\.bottleDuration).reduce(0, +)
        let durationText = duration > 0 ? "\(duration)分钟" : ""

        return amountByMilkType + [durationText]
    }

    private func solidFeedingDetails(for session: FeedingSession) -> [String] {
        let solidEntries = session.entries.filter { $0.type == .solid }
        guard !solidEntries.isEmpty else { return [] }

        return solidEntries.map { entry in
            let food = entry.solidFood?.displayName ?? "辅食"
            guard let amount = entry.solidAmount else { return food }
            let unit = entry.solidUnit?.displayName ?? SolidUnit.g.displayName
            return "\(food)\(amountText(amount))\(unit)"
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
            leftMinutes > 0 ? "左\(leftMinutes)分钟" : "",
            rightMinutes > 0 ? "右\(rightMinutes)分钟" : ""
        ].filter { !$0.isEmpty }

        return (["共\(totalMinutes)分钟"] + sideDetails).joined(separator: " · ")
    }

    private func amountText(_ value: Double) -> String {
        if value.rounded() == value {
            return "\(Int(value))"
        }
        return String(format: "%.1f", value)
    }

    private func timeText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func timeRangeText(start: Date, end: Date) -> String {
        "\(timeText(for: start))-\(timeText(for: end))"
    }
}
