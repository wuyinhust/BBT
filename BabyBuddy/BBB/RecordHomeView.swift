import SwiftUI
import UIKit

struct RecordHomeView: View {
    @EnvironmentObject private var feedingStore: FeedingStore
    @EnvironmentObject private var activityStore: ActivityStore
    @EnvironmentObject private var recruitmentStore: CompanionRecruitmentStore
    @Environment(BabyProfileStore.self) private var profileStore

    @Binding var showBabyInfo: Bool
    var openFeedSheet: () -> Void = {}
    var openYesterdayReport: (YesterdayReport) -> Void = { _ in }

    @State private var selectedDate = Date()
    @State private var didHandleWeekDrag = false
    @State private var weekTransitionDirection = 1
    @State private var editingItem: RecordHomeTimelineItem?
    @State private var pendingDeleteItem: RecordHomeTimelineItem?
    @State private var pendingYesterdayReport: YesterdayReport?

    @AppStorage("record_home_last_yesterday_report_key") private var lastYesterdayReportKey = ""

    var body: some View {
        GeometryReader { proxy in
            let metrics = RecordHomeLayoutMetrics(size: proxy.size, safeAreaInsets: proxy.safeAreaInsets, itemCount: timelineItems.count)

            ZStack {
                recordBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    stickyCalendarHeader(metrics)
                        .padding(.horizontal, metrics.horizontalPadding)
                        .padding(.top, metrics.topPadding)
                        .padding(.bottom, metrics.dayPickerBottom)
                        .frame(maxWidth: metrics.contentMaxWidth, alignment: .leading)
                        .frame(maxWidth: .infinity)
                        .zIndex(1)

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            if let pendingYesterdayReport {
                                yesterdayReportPrompt(pendingYesterdayReport)
                                    .padding(.bottom, metrics.guidanceBottom)
                            }
                            careGuidanceCard
                                .padding(.bottom, metrics.guidanceBottom)
                            feedingSummary
                                .padding(.horizontal, 2)
                                .padding(.bottom, metrics.summaryBottom)
                            dayRhythmCard
                                .padding(.bottom, metrics.rhythmBottom)
                            timelineSection
                        }
                        .padding(.horizontal, metrics.horizontalPadding)
                        .padding(.bottom, metrics.bottomPadding)
                        .frame(maxWidth: metrics.contentMaxWidth, alignment: .leading)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .onAppear {
            presentYesterdayReportIfNeeded()
        }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
            presentYesterdayReportIfNeeded()
        }
        .sheet(item: $editingItem) { item in
            switch item {
            case .feeding(let session):
                FeedingEditSheet(session: session)
            case .care(let record):
                CareRecordEditSheet(record: record)
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: pendingYesterdayReport?.id)
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
        return (feedingItems + careItems)
            .sorted { $0.date > $1.date }
    }

    private var weekDates: [Date] {
        let calendar = Calendar.current
        let start = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start
            ?? calendar.startOfDay(for: selectedDate)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private var brandHeader: some View {
        HStack(alignment: .center) {
            HStack(spacing: 0) {
                Text("BB")
                    .font(BBBFont.font(size: 24, weight: .heavy))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [DesignToken.primary, Color(hex: "#8F6CFF")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text("Buddy")
                    .font(BBBFont.font(size: 24, weight: .heavy))
                    .foregroundStyle(DesignToken.textPrimary)
            }
            .accessibilityLabel("BBBuddy")

            Spacer()

            NavigationLink {
                ProfileView(showBabyInfo: $showBabyInfo)
            } label: {
                profileAvatar(size: 42, emojiSize: 20)
                    .shadow(color: Color(hex: "#7E5DE8").opacity(0.14), radius: 12, y: 6)
            }
            .buttonStyle(ScaleButtonStyle())
            .contentShape(Circle())
        }
        .frame(height: 46)
    }

    private func stickyCalendarHeader(_ metrics: RecordHomeLayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            brandHeader
                .padding(.bottom, metrics.brandBottom)
            dateHeader
                .padding(.bottom, metrics.dateHeaderBottom)
            dayPicker
        }
    }

    @ViewBuilder
    private func profileAvatar(size: CGFloat, emojiSize: CGFloat) -> some View {
        let profile = profileStore.currentProfile

        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.96),
                            DesignToken.primary.opacity(0.18)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if let data = profile.avatarImageData,
               let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Text(profile.displayAvatar)
                    .font(.system(size: emojiSize))
            }
        }
        .frame(width: size, height: size)
        .overlay(
            Circle()
                .stroke(DesignToken.primary.opacity(0.72), lineWidth: size > 30 ? 2 : 1)
        )
    }

    private var dateHeader: some View {
        HStack(alignment: .center) {
            Text(Calendar.current.isDateInToday(selectedDate) ? "今天" : dayTitle)
                .font(BBBFont.font(size: 20, weight: .heavy))
                .foregroundStyle(DesignToken.textPrimary)
                .lineLimit(1)

            if !Calendar.current.isDateInToday(selectedDate) {
                Button {
                    lightHaptic()
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        selectedDate = Date()
                    }
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
        }
        .frame(height: 30)
    }

    private var dayPicker: some View {
        let weekID = weekDates.first ?? selectedDate

        return ZStack {
            HStack(spacing: 0) {
                ForEach(Array(weekDates.enumerated()), id: \.element) { index, date in
                    Button {
                        lightHaptic()
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                            selectedDate = date
                        }
                    } label: {
                        dayPill(date)
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
        .frame(height: 65)
        .clipped()
        .contentShape(Rectangle())
        .animation(.spring(response: 0.34, dampingFraction: 0.88), value: weekID)
        .gesture(
            DragGesture(minimumDistance: 18, coordinateSpace: .local)
                .onChanged { value in
                    guard !didHandleWeekDrag else { return }
                    if value.translation.width <= -44 {
                        didHandleWeekDrag = true
                        shiftWeek(by: 1)
                    } else if value.translation.width >= 44 {
                        didHandleWeekDrag = true
                        shiftWeek(by: -1)
                    }
                }
                .onEnded { _ in
                    didHandleWeekDrag = false
                }
        )
    }

    private var dayRhythmCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(DesignToken.primary)
                Text("今日节奏")
                    .font(BBBFont.font(size: 12, weight: .bold))
                    .foregroundStyle(DesignToken.textPrimary)
                Spacer()
                NavigationLink {
                    WeeklyRhythmPlayerView()
                } label: {
                    Text("本周节奏曲")
                        .font(BBBFont.font(size: 11, weight: .bold))
                        .foregroundStyle(DesignToken.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule(style: .continuous)
                                .fill(DesignToken.primary.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)
            }

            rhythmGrid

            if !rhythmSummaryItems.isEmpty {
                rhythmSummary
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 9)
        .padding(.bottom, 9)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.white.opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(.white.opacity(0.84), lineWidth: 1.2)
                )
                .shadow(color: Color(hex: "#7E5DE8").opacity(0.06), radius: 12, y: 5)
        )
    }

    private var feedingSummary: some View {
        HStack(alignment: .firstTextBaseline) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text("\(selectedSessions.count)")
                    .font(BBBFont.font(size: 17, weight: .heavy))
                Text("次喂养")
                    .font(BBBFont.font(size: 12, weight: .heavy))
            }
            .foregroundStyle(DesignToken.primary)

            Spacer(minLength: 12)

            Text(lastFeedingSummary)
                .font(BBBFont.font(size: 11, weight: .bold))
                .foregroundStyle(DesignToken.textSecondary.opacity(0.78))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
    }

    private var rhythmGrid: some View {
        VStack(spacing: 5) {
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

    private func rhythmMetricRow<Content: View>(
        assetName: String,
        fallbackIcon: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 5) {
            rhythmIcon(assetName: assetName, fallbackIcon: fallbackIcon, color: color)

            content()
                .frame(height: 6)
        }
    }

    @ViewBuilder
    private func rhythmIcon(assetName: String, fallbackIcon: String, color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(color.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(.white.opacity(0.9), lineWidth: 1)
                )

            if UIImage(named: assetName) != nil {
                Image(assetName)
                    .resizable()
                    .scaledToFit()
                    .padding(1.5)
            } else {
                Image(systemName: fallbackIcon)
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(color)
            }
        }
        .frame(width: 13, height: 13)
    }

    private func feedingRhythmHourRow() -> some View {
        GeometryReader { proxy in
            let spacing: CGFloat = 3
            let cellWidth = max((proxy.size.width - spacing * 23) / 24, 2)

            HStack(spacing: spacing) {
                ForEach(0..<24, id: \.self) { hour in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(feedingStyle(for: feedingTypesByHour[hour] ?? []))
                        .frame(width: cellWidth)
                        .frame(height: 6)
                }
            }
        }
        .frame(height: 6)
    }

    private func rhythmHourRow(activeHours: Set<Int>, activeStyle: AnyShapeStyle) -> some View {
        GeometryReader { proxy in
            let spacing: CGFloat = 3
            let cellWidth = max((proxy.size.width - spacing * 23) / 24, 2)

            HStack(spacing: spacing) {
                ForEach(0..<24, id: \.self) { hour in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(activeHours.contains(hour) ? activeStyle : inactiveRhythmStyle)
                        .frame(width: cellWidth)
                        .frame(height: 6)
                }
            }
        }
        .frame(height: 6)
    }

    private func sleepRhythmHourRow() -> some View {
        GeometryReader { proxy in
            let spacing: CGFloat = 3
            let cellWidth = max((proxy.size.width - spacing * 23) / 24, 2)

            HStack(spacing: spacing) {
                ForEach(0..<24, id: \.self) { hour in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(sleepStyle(for: selectedSleepSummary.hourStates[hour] ?? .future))
                        .frame(width: cellWidth)
                        .frame(height: 6)
                }
            }
        }
        .frame(height: 6)
    }

    private var rhythmSummary: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(rhythmSummaryItems) { item in
                    HStack(spacing: 5) {
                        Circle()
                            .fill(item.color)
                            .frame(width: 5.5, height: 5.5)
                        Text(item.text)
                            .font(BBBFont.font(size: 10, weight: .semibold))
                            .foregroundStyle(DesignToken.textSecondary.opacity(0.82))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .padding(.horizontal, 1)
                }
            }
        }
        .frame(height: 14)
    }

    private var careGuidanceCard: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 7) {
                    profileAvatar(size: 24, emojiSize: 13)
                        .overlay(Circle().stroke(.white.opacity(0.96), lineWidth: 1))
                        .shadow(color: Color(hex: "#7E5DE8").opacity(0.10), radius: 7, y: 3)

                    Text("今天\(babyAgeText)了 🎉")
                        .font(BBBFont.font(size: 14, weight: .heavy))
                        .foregroundStyle(DesignToken.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
                }

                Text(feedingGuidanceText)
                    .font(BBBFont.font(size: 11, weight: .semibold))
                    .foregroundStyle(DesignToken.textSecondary)
                    .lineSpacing(3)
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
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "#F4ECFF"),
                            Color(hex: "#FFF1F7"),
                            Color(hex: "#FFF6DF")
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.98),
                                    DesignToken.primary.opacity(0.20),
                                    Color(hex: "#FFD9A8").opacity(0.32)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.3
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(.white.opacity(0.82), lineWidth: 0.45)
                )
                .shadow(color: Color(hex: "#7E5DE8").opacity(0.11), radius: 16, y: 8)
                .shadow(color: Color(hex: "#FFB6C9").opacity(0.07), radius: 8, y: 3)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func yesterdayReportPrompt(_ report: YesterdayReport) -> some View {
        Button {
            lightHaptic()
            lastYesterdayReportKey = report.reportKey
            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                pendingYesterdayReport = nil
            }
            openYesterdayReport(report)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "sunrise.fill")
                    .font(.system(size: 19, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(DesignToken.primaryGradient))

                VStack(alignment: .leading, spacing: 3) {
                    Text("yesterday's 已生成")
                        .font(BBBFont.font(size: 15, weight: .heavy))
                        .foregroundStyle(DesignToken.textPrimary)
                    Text("去陪伴页用昨日产出的 \(CompanionRecruitmentStore.currencyText(report.earnedBBBucks)) 准备小点心")
                        .font(BBBFont.font(size: 12, weight: .semibold))
                        .foregroundStyle(DesignToken.textSecondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.86)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(DesignToken.primary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.white.opacity(0.94))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(.white.opacity(0.84), lineWidth: 1.2)
                    )
                    .shadow(color: Color(hex: "#7E5DE8").opacity(0.06), radius: 12, y: 5)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var buddyImagePlaceholder: some View {
        Image("home_buddy_placeholder")
            .resizable()
            .scaledToFit()
            .frame(width: 152, height: 142)
            .offset(x: 20, y: 8)
            .frame(width: 100, height: 90, alignment: .bottomTrailing)
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
        .padding(.top, 2)
    }

    private var timelineRowSpacing: CGFloat { 10 }
    private var timelineLastRowBottomSpacing: CGFloat { 14 }
    private var timelineConnectorHeight: CGFloat { 72 }

    private var emptyTimeline: some View {
        return HStack(alignment: .top, spacing: 14) {
            timelineRail(isLast: true)
            VStack(alignment: .leading, spacing: 8) {
                Text(Calendar.current.isDateInToday(selectedDate) ? "今天" : dayTitle)
                    .font(BBBFont.font(size: 13, weight: .heavy))
                    .foregroundStyle(DesignToken.primary)
                Text("还没有记录，点右侧添加一条。")
                    .font(BBBFont.font(size: 12, weight: .semibold))
                    .foregroundStyle(DesignToken.textSecondary)
            }
            Spacer()
            Button {
                openFeedSheet()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(DesignToken.primary)
                    .frame(width: 52, height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(DesignToken.primary.opacity(0.10))
                    )
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.top, 6)
    }

    private func timelineRow(_ item: RecordHomeTimelineItem, nextItem: RecordHomeTimelineItem?) -> some View {
        let isLast = nextItem == nil
        let bottomSpacing = isLast ? timelineLastRowBottomSpacing : timelineRowSpacing

        return HStack(alignment: .top, spacing: 12) {
            timelineRail(isLast: isLast, connectorHeight: timelineConnectorHeight)

            VStack(alignment: .leading, spacing: 5) {
                Text(timeText(for: item.date))
                    .font(BBBFont.font(size: 12, weight: .heavy))
                    .foregroundStyle(DesignToken.primary)
                    .lineLimit(1)
                    .padding(.leading, 2)

                timelineCard(item)
                    .recordTimelineActions(
                        edit: { editingItem = item },
                        delete: { pendingDeleteItem = item }
                    )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.bottom, bottomSpacing)
    }

    private func timelineCard(_ item: RecordHomeTimelineItem) -> some View {
        HStack(spacing: 10) {
            itemThumbnail(item)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(BBBFont.font(size: 12, weight: .bold))
                    .foregroundStyle(DesignToken.textPrimary)
                    .lineLimit(1)

                Text(item.detail)
                    .font(BBBFont.font(size: 11, weight: .medium))
                    .foregroundStyle(DesignToken.textSecondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Button {
                editingItem = item
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(DesignToken.primary.opacity(0.72))
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(DesignToken.primary.opacity(0.10))
                    )
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.leading, 10)
        .padding(.trailing, 9)
        .padding(.vertical, 8)
        .frame(minHeight: 58)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white.opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(.white.opacity(0.86), lineWidth: 1.2)
                )
                .shadow(color: Color(hex: "#7E5DE8").opacity(0.06), radius: 12, y: 5)
        )
    }

    private func itemThumbnail(_ item: RecordHomeTimelineItem) -> some View {
        Group {
            if case .feeding(let session) = item,
               let data = session.imageData,
               let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 42, height: 42)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(.white, lineWidth: 2)
                    )
                    .shadow(color: Color.black.opacity(0.06), radius: 6, y: 3)
            } else if case .feeding(let session) = item,
                      session.type == .solid,
	                      let emoji = session.entries.compactMap(\.solidFood?.emoji).first {
                Text(emoji)
                    .font(.system(size: 18))
                    .frame(width: 42, height: 42)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(item.color.opacity(0.10))
                    )
            } else {
                timelineIcon(
                    assetName: item.assetIconName,
                    fallbackIcon: item.icon,
                    color: item.color
                )
            }
        }
    }

    @ViewBuilder
    private func timelineIcon(assetName: String?, fallbackIcon: String, color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(color.opacity(0.11))

            if let assetName, UIImage(named: assetName) != nil {
                Image(assetName)
                    .resizable()
                    .scaledToFit()
                    .padding(9)
            } else {
                Image(systemName: fallbackIcon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(color.opacity(0.86))
            }
        }
        .frame(width: 42, height: 42)
    }

    private func timelineRail(isLast: Bool, connectorHeight: CGFloat = 94) -> some View {
        VStack(spacing: 0) {
            Circle()
                .fill(DesignToken.primary)
                .frame(width: 8, height: 8)
                .shadow(color: DesignToken.primary.opacity(0.45), radius: 5, y: 2)
            if !isLast {
                Rectangle()
                    .fill(DesignToken.primary.opacity(0.18))
                    .frame(width: 0.6, height: connectorHeight)
            }
        }
        .frame(width: 14, alignment: .top)
    }

    private func dayPill(_ date: Date) -> some View {
        let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
        return VStack(spacing: isSelected ? 2 : 3) {
            Text(weekdaySymbol(for: date))
                .font(BBBFont.font(size: 7, weight: .regular))
                .foregroundStyle(isSelected ? .white.opacity(0.86) : DesignToken.textSecondary.opacity(0.56))
            Text(date, format: .dateTime.day())
                .font(BBBFont.font(size: 12, weight: .heavy))
                .foregroundStyle(isSelected ? .white : DesignToken.textPrimary.opacity(0.68))
            if isSelected {
                Circle()
                    .fill(.white)
                    .frame(width: 3, height: 3)
            }
        }
        .frame(width: 36)
        .frame(height: 55)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    isSelected
                    ? AnyShapeStyle(LinearGradient(colors: [DesignToken.primary, Color(hex: "#8F6CFF")], startPoint: .topLeading, endPoint: .bottomTrailing))
                    : AnyShapeStyle(.white.opacity(0.84))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(isSelected ? .white.opacity(0.42) : .white.opacity(0.76), lineWidth: 1)
                )
                .shadow(color: Color(hex: "#7E5DE8").opacity(isSelected ? 0.18 : 0.04), radius: isSelected ? 9 : 6, y: isSelected ? 4 : 2)
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
        HStack(spacing: 14) {
            Circle()
                .fill(DesignToken.primary.opacity(0.2))
                .frame(width: 6, height: 6)
                .frame(width: 18)

            HStack(spacing: 10) {
                Rectangle()
                    .fill(DesignToken.line.opacity(0.6))
                    .frame(height: 1)
                Text(Calendar.current.isDateInToday(selectedDate) ? "今天开始" : "\(dayTitle)开始")
                    .font(BBBFont.font(size: 11, weight: .regular))
                    .foregroundStyle(DesignToken.textSecondary.opacity(0.62))
                    .lineLimit(1)
                Rectangle()
                    .fill(DesignToken.line.opacity(0.6))
                    .frame(height: 1)
            }
        }
        .padding(.top, 2)
    }

    private var recordBackground: some View {
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

            RadialGradient(
                colors: [
                    DesignToken.primary.opacity(0.20),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 360
            )

            RadialGradient(
                colors: [
                    Color(hex: "#FFD9A8").opacity(0.18),
                    .clear
                ],
                center: .bottomLeading,
                startRadius: 30,
                endRadius: 420
            )
        }
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

    private var feedingGuidanceText: String {
        let days = babyAgeDays
        switch days {
        case 0..<7:
            return "新生儿胃容量还小，按需喂养为主，奶量会逐日增加。"
        case 7..<30:
            return "这个阶段通常按需喂养，每天总奶量大约 450-750ml。"
        case 30..<90:
            return "这个月龄每天总奶量大约 600-900ml，观察尿量和体重增长更重要。"
        case 90..<180:
            return "这个月龄每天总奶量大约 700-1000ml，可继续按宝宝节奏调整。"
        case 180..<365:
            return "辅食逐步加入后，奶仍是重要营养来源，每天奶量大约 600-800ml。"
        default:
            return "一岁后饮食更丰富，可以结合正餐、奶量和生长曲线调整。"
        }
    }

    private var rhythmSummaryItems: [RhythmSummaryItem] {
        var items: [RhythmSummaryItem] = []

        let bottleAmount = selectedSessions.reduce(0) { $0 + $1.totalBottleAmount }
        if bottleAmount > 0 {
            items.append(RhythmSummaryItem(text: "奶粉 \(bottleAmount)ml", color: recordBottleColor))
        }

        let breastMinutes = selectedSessions.reduce(0) { $0 + $1.totalBreastDuration }
        if breastMinutes > 0 {
            items.append(RhythmSummaryItem(text: "母乳 \(breastMinutes)分钟", color: recordBreastColor))
        }

        let solidAmount = selectedSessions.reduce(0) { $0 + $1.totalSolidAmount }
        if solidAmount > 0 {
            items.append(RhythmSummaryItem(text: "辅食 \(Int(solidAmount))g", color: recordSolidColor))
        }

        let recordedSleepMinutes = selectedSleepSummary.recordedSleepMinutes
        if recordedSleepMinutes > 0 {
            items.append(RhythmSummaryItem(text: "记录睡眠 \(recordedSleepMinutes)分钟", color: recordSleepColor))
        }

        let diaperCount = selectedCareRecords.filter { $0.kind == .diaper }.count
        if diaperCount > 0 {
            items.append(RhythmSummaryItem(text: "尿布 \(diaperCount)次", color: recordDiaperColor))
        }

        return items
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
        DesignToken.primary
    }

    private var recordBreastColor: Color {
        Color(hex: "#E6B4DF")
    }

    private var recordSolidColor: Color {
        Color(hex: "#A8B8F6")
    }

    private var recordDiaperColor: Color {
        Color(hex: "#D8A64E")
    }

    private var recordSleepColor: Color {
        Color(hex: "#8F93E8")
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

    private func timeText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func delete(_ item: RecordHomeTimelineItem) {
        switch item {
        case .feeding(let session):
            feedingStore.deleteSession(session)
        case .care(let record):
            activityStore.deleteCareRecord(record)
        }
    }

    private func presentYesterdayReportIfNeeded(now: Date = Date()) {
        let calendar = Calendar.current
        guard calendar.component(.hour, from: now) >= 8,
              let yesterday = calendar.date(byAdding: .day, value: -1, to: now) else {
            return
        }

        let reportKey = reportKey(for: yesterday)
        guard lastYesterdayReportKey != reportKey,
              pendingYesterdayReport == nil,
              editingItem == nil else { return }

        let sessions = feedingStore.sessions(on: yesterday)
        let careRecords = activityStore.careRecords(on: yesterday)
        let report = makeYesterdayReport(date: yesterday, sessions: sessions, careRecords: careRecords)
        recruitmentStore.storeReport(report)
        pendingYesterdayReport = recruitmentStore.report(for: report.reportKey) ?? report
    }

    private func makeYesterdayReport(date: Date, sessions: [FeedingSession], careRecords: [CareRecord]) -> YesterdayReport {
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

        let rhythmText: String
        if let firstHour = rhythmHours.min(), let lastHour = rhythmHours.max() {
            rhythmText = "主要记录集中在 \(hourRangeText(firstHour, lastHour))，全天共有 \(rhythmHours.count) 个活跃时段。"
        } else {
            rhythmText = "昨天还没有形成明显节奏，可以从一次喂养或尿布记录开始补充。"
        }

        var analysisParts: [String] = []
        if sessions.isEmpty {
            analysisParts.append("昨天没有喂养记录，今天可以先补上最近一次喂养时间。")
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
            visitorCompanionID: recruitmentStore.visitorCompanion(for: reportKey).id,
            visitorCompanionIDs: recruitmentStore.visitorCompanions(for: reportKey).map(\.id),
            fedCompanionID: nil,
            fedBBBucks: 0,
            feedings: [],
            createdAt: Date()
        )
    }

    private func reportKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func reportDateText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
    }

    private func hourRangeText(_ firstHour: Int, _ lastHour: Int) -> String {
        if firstHour == lastHour {
            return "\(firstHour):00"
        }
        return "\(firstHour):00-\(lastHour):00"
    }

    private var lastFeedingSummary: String {
        guard let last = selectedSessions.sorted(by: { $0.createdAt > $1.createdAt }).first?.createdAt else {
            return "暂无喂养"
        }
        guard Calendar.current.isDateInToday(selectedDate) else {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return "最后 \(formatter.string(from: last))"
        }
        let minutes = max(Int(Date().timeIntervalSince(last) / 60), 0)
        if minutes < 60 {
            return "距上次 \(minutes) 分钟"
        }
        return "距上次 \(minutes / 60)小时\(minutes % 60)分"
    }

    private func weekdaySymbol(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }
}

private struct RecordHomeLayoutMetrics {
    let horizontalPadding: CGFloat
    let contentMaxWidth: CGFloat
    let brandBottom: CGFloat
    let dateHeaderBottom: CGFloat
    let dayPickerBottom: CGFloat
    let rhythmBottom: CGFloat
    let guidanceBottom: CGFloat
    let summaryBottom: CGFloat
    let topPadding: CGFloat
    let bottomPadding: CGFloat

    init(size: CGSize, safeAreaInsets: EdgeInsets, itemCount: Int) {
        let isCompact = size.height < 780
        let hasTimeline = itemCount > 0

        self.horizontalPadding = size.width < 390 ? 18 : 20
        self.contentMaxWidth = size.width > 700 ? 520 : .infinity
        self.brandBottom = isCompact ? 12 : 16
        self.dateHeaderBottom = isCompact ? 10 : 12
        self.dayPickerBottom = 12
        self.rhythmBottom = 16
        self.guidanceBottom = 12
        self.summaryBottom = 8
        self.topPadding = isCompact ? 10 : 12
        self.bottomPadding = max(safeAreaInsets.bottom, hasTimeline ? 72 : 36)
    }
}

private struct RhythmSummaryItem: Identifiable {
    let id = UUID()
    let text: String
    let color: Color
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
    let report: YesterdayReport
    let onDismiss: () -> Void
    @State private var feedingResult: CompanionFeedingResult?

    private var latestReport: YesterdayReport {
        recruitmentStore.report(for: report.reportKey) ?? report
    }

    private var visitors: [BabyCompanion] {
        latestReport.visitorIDs.map { BabyCompanion.companion(for: $0) }
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
                            Text("yesterday's")
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

                    visitorBlock

                    if let feedingResult {
                        feedingResultBlock(feedingResult)
                    }

                    reportRhythmBlock
                    reportBlock(title: "分析", icon: "sparkles", text: report.analysisText)
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
                    Text("昨日产出 \(reportEarnedText) · 余额 \(balanceText)")
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
            reportStat(title: "喂养", value: "\(report.feedingCount)次", color: DesignToken.primary)
            reportStat(title: "奶量", value: report.bottleAmount > 0 ? "\(report.bottleAmount)ml" : "暂无", color: DesignToken.accentBlue)
            reportStat(title: "母乳", value: report.breastMinutes > 0 ? "\(report.breastMinutes)分" : "暂无", color: Color(hex: "#E6B4DF"))
            reportStat(title: "尿布", value: report.diaperCount > 0 ? "\(report.diaperCount)次" : "暂无", color: Color(hex: "#D8A64E"))
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
            Label("当日节奏", systemImage: "chart.line.uptrend.xyaxis")
                .font(BBBFont.font(size: 13, weight: .heavy))
                .foregroundStyle(DesignToken.textPrimary)

            VStack(spacing: 5) {
                reportRhythmRow(icon: "babybottle.fill", color: DesignToken.primary, activeHours: report.feedingHours)
                reportRhythmRow(icon: "drop.degreesign.fill", color: Color(hex: "#D8A64E"), activeHours: report.diaperHours)
                reportRhythmRow(icon: "moon.fill", color: Color(hex: "#8F93E8"), activeHours: report.sleepHours)
            }

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

    private func reportRhythmRow(icon: String, color: Color, activeHours: Set<Int>) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 17, height: 17)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(color.opacity(0.12))
                )

            GeometryReader { proxy in
                let spacing: CGFloat = 2
                let cellWidth = max((proxy.size.width - spacing * 23) / 24, 2)

                HStack(spacing: spacing) {
                    ForEach(0..<24, id: \.self) { hour in
                        RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                            .fill(activeHours.contains(hour) ? color.opacity(0.86) : Color.white.opacity(0.74))
                            .frame(width: cellWidth, height: 5)
                    }
                }
            }
            .frame(height: 5)
        }
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

    var id: String {
        switch self {
        case .feeding(let session): return "feeding-\(session.id.uuidString)"
        case .care(let record): return "care-\(record.id.uuidString)"
        }
    }

    var date: Date {
        switch self {
        case .feeding(let session): return session.createdAt
        case .care(let record): return record.recordedAt
        }
    }

    var title: String {
        switch self {
        case .feeding(let session): return session.type.displayName
        case .care(let record):
            return record.kind == .diaper ? DiaperRecordType.normalizedTitle(record.title) : record.title
        }
    }

    var detail: String {
        switch self {
        case .feeding(let session): return feedingDetail(for: session)
        case .care(let record): return record.detail
        }
    }

    var icon: String {
        switch self {
        case .feeding(let session):
            switch session.type {
            case .bottle: return "babybottle.fill"
            case .breast: return "drop.fill"
            case .solid: return "leaf.fill"
            }
        case .care(let record):
            switch record.kind {
            case .diaper: return "drop.degreesign.fill"
            case .sleep: return "moon.fill"
            }
        }
    }

    var assetIconName: String? {
        switch self {
        case .feeding:
            return "rhythm_feeding_icon"
        case .care(let record):
            switch record.kind {
            case .diaper: return "rhythm_diaper_icon"
            case .sleep: return "rhythm_sleep_icon"
            }
        }
    }

    var color: Color {
        switch self {
        case .feeding(let session): return session.type.accent
        case .care(let record):
            switch record.kind {
            case .diaper: return Color(hex: "#D8A64E")
            case .sleep: return Color(hex: "#8F93E8")
        }
    }
    }

    private func feedingDetail(for session: FeedingSession) -> String {
        switch session.type {
        case .bottle:
            let amount = session.amountML.map { "\($0)ml" } ?? ""
            let duration = session.bottleDurationMin.map { "\($0)分钟" } ?? ""
            return [amount, duration, session.notes].filter { !$0.isEmpty }.joined(separator: " · ")
        case .breast:
            return [breastFeedingDetail(for: session), session.notes]
                .filter { !$0.isEmpty }
                .joined(separator: " · ")
        case .solid:
            let kind = session.solidsKind ?? "辅食"
            let gram = session.solidsGram.map { "\($0)g" } ?? ""
            return [kind, gram, session.notes].filter { !$0.isEmpty }.joined(separator: " · ")
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
            leftMinutes > 0 ? "左胸 \(leftMinutes)分钟" : "",
            rightMinutes > 0 ? "右胸 \(rightMinutes)分钟" : ""
        ].filter { !$0.isEmpty }

        return (["共计 \(totalMinutes)分钟"] + sideDetails).joined(separator: " · ")
    }
}
