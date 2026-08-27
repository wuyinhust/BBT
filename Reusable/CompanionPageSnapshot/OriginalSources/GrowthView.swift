import SwiftUI
import UIKit

struct MyPageView: View {
    @Environment(BabyProfileStore.self) private var profileStore
    @EnvironmentObject private var stickerStore: AchievementStickerStore
    @Binding private var isGrowthDiaryPresented: Bool

    init(
        initialTab: MyPageTab = .badge,
        showsProfileHeader: Bool = true,
        visibleTabs: [MyPageTab] = [.badge],
        isGrowthDiaryPresented: Binding<Bool> = .constant(false)
    ) {
        _isGrowthDiaryPresented = isGrowthDiaryPresented
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                HomeSoftBackground()

                VStack(spacing: DesignToken.contentSpacing) {
                    growthTopBar
                        .padding(.top, 10)

                    BabyAchievementsView(showsHeader: false, isEmbedded: true)
                        .environmentObject(stickerStore)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(.horizontal, RootPageTitleBarLayout.horizontalPadding(for: proxy.size.width))
                .padding(.bottom, 0)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $isGrowthDiaryPresented) {
            GrowthDiaryView()
        }
    }

    private var profile: BabyProfileData {
        profileStore.currentProfile
    }

    private var growthTopBar: some View {
        RootPageTitleBar(title: RootTab.growth.title) {
            Button {
                isGrowthDiaryPresented = true
            } label: {
                BabyProfileAvatarView(
                    profile: profile,
                    size: 34,
                    emojiSize: 16,
                    lineWidth: 1.5,
                    motionScale: 0.65
                )
                .frame(width: 40, height: DesignToken.minimumTapSize)
                .contentShape(Circle())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel("成长日记")
            .accessibilityHint("查看宝宝从出生到今天的重要成长")
        }
    }
}

private struct GrowthDiaryEvent: Identifiable {
    let id: String
    let date: Date
    let title: String
    let detail: String?
    let note: String?
    let kind: GrowthDiaryEventKind
    let symbol: String
    let order: Int
}

private enum GrowthDiaryEventKind {
    case importantDate
    case milestone
    case feeding

    var tint: Color {
        switch self {
        case .importantDate: return DesignToken.reward
        case .milestone: return DesignToken.primary
        case .feeding: return DesignToken.easyEat
        }
    }

    var softTint: Color {
        switch self {
        case .importantDate: return DesignToken.rewardSoft
        case .milestone: return DesignToken.primarySoft
        case .feeding: return DesignToken.easyEatSoft
        }
    }
}

private struct GrowthDiaryDay: Identifiable {
    let date: Date
    let events: [GrowthDiaryEvent]
    let photoAchievement: CustomAchievement?
    let thumbnail: UIImage?

    var id: Date { date }
}

private struct GrowthDiaryImportantDate {
    let id: String
    let elapsedDay: Int
    let text: String
    let symbol: String
}

private struct GrowthDiaryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(BabyProfileStore.self) private var profileStore
    @EnvironmentObject private var stickerStore: AchievementStickerStore
    @EnvironmentObject private var feedingStore: FeedingStore
    @State private var selectedPhoto: CustomAchievement?

    private let calendar = Calendar.current

    var body: some View {
        ZStack {
            HomeSoftBackground()

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 12) {
                    ForEach(days) { day in
                        GrowthDiaryDayRow(
                            day: day,
                            birthDate: birthDate,
                            onOpenPhoto: {
                                selectedPhoto = day.photoAchievement
                            }
                        )
                    }
                }
                .padding(.horizontal, DesignToken.compactHorizontalPadding)
                .padding(.top, 10)
                .padding(.bottom, 28)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top, spacing: 0) {
            diaryTopBar
        }
        .fullScreenCover(item: $selectedPhoto) { achievement in
            GrowthDiaryPhotoViewer(achievement: achievement)
                .environmentObject(stickerStore)
        }
    }

    private var diaryTopBar: some View {
        HStack(spacing: 0) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(DesignToken.textPrimary)
                    .frame(width: DesignToken.minimumTapSize, height: DesignToken.minimumTapSize)
                    .background(Circle().fill(DesignToken.surfaceRaised.opacity(0.90)))
                    .overlay {
                        Circle()
                            .stroke(DesignToken.glassStroke.opacity(0.68), lineWidth: 1)
                    }
                    .shadow(color: DesignToken.shadowColor.opacity(0.12), radius: 10, y: 4)
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel("返回")

            Spacer()

            Text("成长日记")
                .font(BBBFont.font(size: 24, weight: .bold))
                .foregroundStyle(DesignToken.textPrimary)
                .lineLimit(1)

            Spacer()

            Color.clear
                .frame(width: DesignToken.minimumTapSize, height: DesignToken.minimumTapSize)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, DesignToken.compactHorizontalPadding)
        .padding(.top, 6)
        .padding(.bottom, 8)
        .background(DesignToken.canvas.opacity(0.96))
    }

    private var birthDate: Date {
        calendar.startOfDay(for: profileStore.currentProfile.birthDate)
    }

    private var days: [GrowthDiaryDay] {
        let groupedEvents = Dictionary(grouping: diaryEvents) {
            calendar.startOfDay(for: $0.date)
        }

        return groupedEvents.keys.sorted(by: >).map { date in
            let photoAchievement = photoAchievement(on: date)
            return GrowthDiaryDay(
                date: date,
                events: (groupedEvents[date] ?? []).sorted {
                    if $0.order != $1.order { return $0.order < $1.order }
                    return $0.title.localizedStandardCompare($1.title) == .orderedAscending
                },
                photoAchievement: photoAchievement,
                thumbnail: photoAchievement.flatMap {
                    stickerStore.displayThumbnailImage(for: $0, maxSide: 220)
                }
            )
        }
    }

    private var diaryEvents: [GrowthDiaryEvent] {
        let today = calendar.startOfDay(for: Date())
        var events = automaticImportantDateEvents(through: today)
        events.append(contentsOf: achievedMilestoneEvents(through: today))
        if let feedingEvent = firstBottleMilestoneEvent(through: today) {
            events.append(feedingEvent)
        }
        return events
    }

    private func automaticImportantDateEvents(through today: Date) -> [GrowthDiaryEvent] {
        importantDates.compactMap { importantDate in
            guard let date = calendar.date(
                byAdding: .day,
                value: importantDate.elapsedDay,
                to: birthDate
            ), date <= today else {
                return nil
            }

            let linkedAchievement = stickerStore.achievements.first {
                milestoneID(for: $0) == importantDate.id
            }
            return GrowthDiaryEvent(
                id: "important-\(importantDate.id)",
                date: date,
                title: importantDate.text,
                detail: nil,
                note: normalizedNote(linkedAchievement?.note),
                kind: .importantDate,
                symbol: importantDate.symbol,
                order: 0
            )
        }
    }

    private func achievedMilestoneEvents(through today: Date) -> [GrowthDiaryEvent] {
        var earliestByMilestoneID: [String: CustomAchievement] = [:]

        for achievement in stickerStore.achievements {
            guard achievement.completedAt >= birthDate,
                  calendar.startOfDay(for: achievement.completedAt) <= today,
                  let milestoneID = milestoneID(for: achievement),
                  !importantDateIDs.contains(milestoneID),
                  isGrowthDiaryEligibleAchievement(
                    achievement,
                    birthDate: birthDate,
                    calendar: calendar
                  ) else {
                continue
            }

            if let current = earliestByMilestoneID[milestoneID],
               current.completedAt <= achievement.completedAt {
                continue
            }
            earliestByMilestoneID[milestoneID] = achievement
        }

        return earliestByMilestoneID.map { milestoneID, achievement in
            GrowthDiaryEvent(
                id: "milestone-\(milestoneID)",
                date: achievement.completedAt,
                title: diaryTitle(for: achievement, milestoneID: milestoneID),
                detail: nil,
                note: normalizedNote(achievement.note),
                kind: .milestone,
                symbol: growthDiaryMilestoneSymbol(for: milestoneID),
                order: 1
            )
        }
    }

    private func firstBottleMilestoneEvent(through today: Date) -> GrowthDiaryEvent? {
        let threshold = 150
        guard let session = feedingStore.allSessions
            .filter({ session in
                session.eventDate >= birthDate
                    && calendar.startOfDay(for: session.eventDate) <= today
                    && session.totalBottleAmount > threshold
            })
            .min(by: { $0.eventDate < $1.eventDate }) else {
            return nil
        }

        let thresholdText = AppMeasurementFormat.volume(Double(threshold))
        let amountText = AppMeasurementFormat.volume(Double(session.totalBottleAmount))
        return GrowthDiaryEvent(
            id: "feeding-first-over-150",
            date: session.eventDate,
            title: "单次奶量首次超过 \(thresholdText)",
            detail: "这次喝了 \(amountText)",
            note: nil,
            kind: .feeding,
            symbol: "drop.fill",
            order: 2
        )
    }

    private func photoAchievement(on date: Date) -> CustomAchievement? {
        stickerStore.achievements
            .filter {
                calendar.isDate($0.completedAt, inSameDayAs: date)
                    && ($0.originalFilename != nil || $0.stickerFilename != nil)
            }
            .sorted { lhs, rhs in
                let lhsCover = lhs.isDayCover == true
                let rhsCover = rhs.isDayCover == true
                if lhsCover != rhsCover { return lhsCover }

                let lhsMilestone = milestoneID(for: lhs) != nil
                let rhsMilestone = milestoneID(for: rhs) != nil
                if lhsMilestone != rhsMilestone { return lhsMilestone }
                return lhs.completedAt > rhs.completedAt
            }
            .first
    }

    private func diaryTitle(for achievement: CustomAchievement, milestoneID: String) -> String {
        switch milestoneID {
        case "three-steady-head":
            return "能稳定抬头了"
        case "zero-first-smile":
            return "第一次笑了"
        case "four-roll-over":
            return "学会翻身了"
        default:
            let title = achievement.name.trimmingCharacters(in: .whitespacesAndNewlines)
            return title.isEmpty ? "新的成长成就" : title
        }
    }

    private func normalizedNote(_ note: String?) -> String? {
        guard let note else { return nil }
        let normalized = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    private func milestoneID(for achievement: CustomAchievement) -> String? {
        achievement.milestoneID ?? achievement.templateID
    }

    private var importantDates: [GrowthDiaryImportantDate] {
        [
            .init(id: "birth-day", elapsedDay: 0, text: "宝宝今天出生了。", symbol: "sparkles"),
            .init(id: "one-month", elapsedDay: 29, text: "宝宝今天满月了。", symbol: "moon.stars.fill"),
            .init(id: "hundred-days", elapsedDay: 99, text: "宝宝今天百天了。", symbol: "100.circle.fill"),
            .init(id: "half-year", elapsedDay: 179, text: "宝宝今天半岁了。", symbol: "seal.fill"),
            .init(id: "first-birthday", elapsedDay: 364, text: "宝宝今天一周岁了。", symbol: "birthday.cake.fill")
        ]
    }

    private var importantDateIDs: Set<String> {
        Set(importantDates.map(\.id))
    }
}

private struct GrowthDiaryDayRow: View {
    let day: GrowthDiaryDay
    let birthDate: Date
    let onOpenPhoto: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            dateHeader

            Rectangle()
                .fill(DesignToken.line.opacity(0.36))
                .frame(height: 1)

            HStack(alignment: .top, spacing: 14) {
                eventList

                if let thumbnail = day.thumbnail {
                    Button(action: onOpenPhoto) {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 88, height: 88)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(DesignToken.glassStroke.opacity(0.72), lineWidth: 1)
                            }
                            .shadow(color: DesignToken.shadowColor.opacity(0.10), radius: 8, y: 4)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityLabel("查看当天照片")
                }
            }
        }
        .padding(.horizontal, DesignToken.cardPadding)
        .padding(.vertical, 14)
        .background {
            let shape = RoundedRectangle(cornerRadius: DesignToken.largeCardRadius, style: .continuous)
            shape
                .fill(.ultraThinMaterial)
                .overlay {
                    shape.fill(DesignToken.glassFill.opacity(0.72))
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: DesignToken.largeCardRadius, style: .continuous)
                .stroke(DesignToken.glassStroke.opacity(0.72), lineWidth: 1)
        }
        .shadow(color: DesignToken.shadowColor.opacity(0.10), radius: 14, y: 7)
    }

    private var dateHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(dateText)
                .font(BBBFont.font(size: 19, weight: .bold))
                .foregroundStyle(DesignToken.textPrimary)
                .monospacedDigit()

            if let yearText {
                Text(yearText)
                    .font(BBBFont.font(size: 11, weight: .medium))
                    .foregroundStyle(DesignToken.textSecondary)
            }

            Spacer(minLength: 8)

            Text(ageText)
                .font(BBBFont.font(size: 11, weight: .semibold))
                .foregroundStyle(DesignToken.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(Capsule().fill(DesignToken.primarySoft.opacity(0.52)))
        }
        .accessibilityElement(children: .combine)
    }

    private var eventList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(day.events.enumerated()), id: \.element.id) { index, event in
                if index > 0 {
                    Rectangle()
                        .fill(DesignToken.line.opacity(0.30))
                        .frame(height: 1)
                        .padding(.leading, 40)
                }

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: event.symbol)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(event.kind.tint)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(event.kind.softTint.opacity(0.72)))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(event.title)
                            .font(BBBFont.font(size: 15.5, weight: .semibold))
                            .foregroundStyle(DesignToken.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        if let detail = event.detail {
                            Text(detail)
                                .font(BBBFont.font(size: 12.5, weight: .medium))
                                .foregroundStyle(DesignToken.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if let note = event.note {
                            Text(note)
                                .font(BBBFont.font(size: 12, weight: .regular))
                                .foregroundStyle(DesignToken.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var dateText: String {
        let calendar = Calendar.current
        return "\(calendar.component(.month, from: day.date))月\(calendar.component(.day, from: day.date))日"
    }

    private var yearText: String? {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: day.date)
        return year == calendar.component(.year, from: Date()) ? nil : "\(year)年"
    }

    private var ageText: String {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: birthDate)
        let end = max(calendar.startOfDay(for: day.date), start)
        let components = calendar.dateComponents([.year, .month, .day], from: start, to: end)
        let years = max(components.year ?? 0, 0)
        let months = max(components.month ?? 0, 0)
        let days = max(components.day ?? 0, 0)

        if years == 0, months == 0 {
            return "第\(days)天"
        }

        var parts: [String] = []
        if years > 0 { parts.append("\(years)岁") }
        if months > 0 { parts.append("\(months)个月") }
        if days > 0 { parts.append("\(days)天") }
        return parts.joined(separator: "+")
    }
}

private struct GrowthDiaryPhotoViewer: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var stickerStore: AchievementStickerStore
    let achievement: CustomAchievement

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let image = stickerStore.displayImage(for: achievement) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 12)
                    .accessibilityLabel("成长日记照片")
            }
        }
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(.black.opacity(0.46)))
                    .overlay(Circle().stroke(.white.opacity(0.20), lineWidth: 1))
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel("关闭")
            .padding(.top, 12)
            .padding(.trailing, 16)
        }
        .statusBarHidden(true)
    }
}

enum MyPageTab: String, CaseIterable, Identifiable {
    case calendar
    case badge

    var id: String { rawValue }

    var title: String {
        switch self {
        case .calendar: return "日历"
        case .badge: return "徽章"
        }
    }
}
