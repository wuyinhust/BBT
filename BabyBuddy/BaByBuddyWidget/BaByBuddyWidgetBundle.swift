import ActivityKit
import SwiftUI
import WidgetKit

@main
struct BaByBuddyWidgetBundle: WidgetBundle {
    var body: some Widget {
        BaByBuddyWidget()
        #if !targetEnvironment(simulator)
        FeedingLiveActivity()
        #endif
    }
}

enum WidgetStorageKey {
    static let appGroupID = "group.73AUQDMCJ2.babybuddy"
    static let feedingSessions = "feeding_sessions"
    static let babyInfo = "baby_info"
    static let lastFeedingWidgetKind = "v.babybuddy.LastFeeding"
}

struct WidgetBabyInfo: Decodable {
    var name: String
    var birthDate: Date

    func ageMonths(asOf date: Date = Date()) -> Int {
        max(Calendar.current.dateComponents([.month], from: birthDate, to: date).month ?? 0, 0)
    }
}

struct WidgetFeedingSession: Decodable {
    struct Entry: Decodable {
        var type: String
        var breastDuration: Int?
        var bottleAmount: Int?
        var solidAmount: Double?
    }

    var entries: [Entry]
    var createdAt: Date
}

struct FeedingWidgetEntry: TimelineEntry {
    var date: Date
    var lastFeedingDate: Date?
    var babyInfo: WidgetBabyInfo?
}

struct FeedingWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> FeedingWidgetEntry {
        FeedingWidgetEntry(date: Date(), lastFeedingDate: Date().addingTimeInterval(-3 * 3600), babyInfo: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (FeedingWidgetEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FeedingWidgetEntry>) -> Void) {
        let entry = loadEntry()
        completion(Timeline(entries: [entry], policy: nextPolicy(for: entry)))
    }

    private func loadEntry() -> FeedingWidgetEntry {
        let defaults = UserDefaults(suiteName: WidgetStorageKey.appGroupID)
        let sessions = defaults?.data(forKey: WidgetStorageKey.feedingSessions)
            .flatMap { try? JSONDecoder().decode([WidgetFeedingSession].self, from: $0) } ?? []
        let babyInfo = defaults?.data(forKey: WidgetStorageKey.babyInfo)
            .flatMap { try? JSONDecoder().decode(WidgetBabyInfo.self, from: $0) }
        return FeedingWidgetEntry(date: Date(), lastFeedingDate: sessions.sorted { $0.createdAt > $1.createdAt }.first?.createdAt, babyInfo: babyInfo)
    }

    private func nextPolicy(for entry: FeedingWidgetEntry) -> TimelineReloadPolicy {
        guard let lastFeedingDate = entry.lastFeedingDate else {
            return .after(Date().addingTimeInterval(30 * 60))
        }

        let months = entry.babyInfo?.ageMonths(asOf: entry.date)
        let thresholds = FeedingIntervalStatus.thresholds(for: months)
        let checkpoints = [
            thresholds.justFed,
            thresholds.tooSoon,
            thresholds.safe,
            thresholds.maybeHungry,
            thresholds.definitelyHungry
        ]

        let elapsedHours = entry.date.timeIntervalSince(lastFeedingDate) / 3600
        if let nextHour = checkpoints.first(where: { $0 > elapsedHours }) {
            let refreshDate = lastFeedingDate.addingTimeInterval(nextHour * 3600 + 5)
            return .after(max(refreshDate, entry.date.addingTimeInterval(60)))
        }

        return .after(entry.date.addingTimeInterval(60 * 60))
    }
}

struct BaByBuddyWidget: Widget {
    let kind = WidgetStorageKey.lastFeedingWidgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FeedingWidgetProvider()) { entry in
            LastFeedingWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(hex: "#F8F4FA")
                }
        }
        .configurationDisplayName("BabyBuddy")
        .description("查看距上次喂养时间")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct LastFeedingWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: FeedingWidgetEntry

    private var status: FeedingIntervalStatus {
        guard let lastFeedingDate = entry.lastFeedingDate else { return .warning }
        return FeedingIntervalStatus(
            lastFeedingDate: lastFeedingDate,
            babyAgeMonths: entry.babyInfo?.ageMonths(asOf: entry.date),
            now: entry.date
        )
    }

    var body: some View {
        switch family {
        case .systemSmall:
            compactCard
        default:
            mediumCard
        }
    }

    private var compactCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                Text("BaByBuddy")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(hex: "#4D4B70"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
            }
            Spacer(minLength: 12)
            HStack(alignment: .center, spacing: 10) {
                statusEmojiBadge(size: 42, fontSize: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(status.label)
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(hex: status.accentColorHex))
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                    Text(shortStatusTag)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: "#A29FBB"))
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            HStack(spacing: 5) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 10, weight: .bold))
                Text(lastTimeText + " 上次喂养")
                    .lineLimit(1)
            }
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(Color(hex: "#8E8AA8"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }

    private var mediumCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                Text("BaByBuddy")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(hex: "#4D4B70"))
                Spacer()
                HStack(spacing: 5) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text(lastTimeText + " 上次喂养")
                }
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: "#8E8AA8"))
            }
            Spacer(minLength: 14)
            HStack(alignment: .center, spacing: 14) {
                statusEmojiBadge(size: 62, fontSize: 34)

                VStack(alignment: .leading, spacing: 6) {
                    Text(status.label)
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(hex: status.accentColorHex))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(shortStatusDetail)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(hex: "#8E8AA8"))
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var shortStatusDetail: String {
        switch status {
        case .justFed:
            return "刚完成喂养，暂时不用着急。"
        case .tooSoon:
            return "还不太饿，继续观察就可以。"
        case .safe:
            return "状态正好，按当前节奏陪伴。"
        case .maybeHungry:
            return "可以开始留意饥饿信号。"
        case .definitelyHungry:
            return "宝宝已经饿了，建议准备喂养。"
        case .warning:
            return "建议尽快安排下一次喂养。"
        }
    }

    private var shortStatusTag: String {
        switch status {
        case .justFed:
            return "轻松陪伴"
        case .tooSoon:
            return "继续观察"
        case .safe:
            return "状态稳定"
        case .maybeHungry:
            return "留意信号"
        case .definitelyHungry:
            return "准备喂养"
        case .warning:
            return "尽快安排"
        }
    }

    private func statusEmojiBadge(size: CGFloat, fontSize: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Color(hex: status.backgroundColorHex).opacity(0.92))
            Circle()
                .stroke(Color.white.opacity(0.65), lineWidth: 1)
            Text(status.emoji)
                .font(.system(size: fontSize))
        }
        .frame(width: size, height: size)
    }

    private var lastTimeText: String {
        guard let last = entry.lastFeedingDate else { return "--:--" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: last)
    }

}

struct FeedingLiveActivity: Widget {
    private let liveActivityTint = Color(hex: "#8E79FF")

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FeedingActivityAttributes.self) { context in
            LockScreenView(state: context.state, babyAgeMonths: context.attributes.babyAgeMonths)
                .activityBackgroundTint(Color(hex: "#171827").opacity(0.92))
                .activitySystemActionForegroundColor(liveActivityTint)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    DynamicIslandExpandedHeader(
                        lastFeedingDate: context.state.lastFeedingDate,
                        babyAgeMonths: context.attributes.babyAgeMonths
                    )
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("BaByBuddy")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.center) {
                    DynamicIslandExpandedStatus(
                        lastFeedingDate: context.state.lastFeedingDate,
                        babyAgeMonths: context.attributes.babyAgeMonths
                    )
                }
                DynamicIslandExpandedRegion(.bottom) {
                    DynamicIslandEmojiTrail(
                        lastFeedingDate: context.state.lastFeedingDate,
                        babyAgeMonths: context.attributes.babyAgeMonths
                    )
                }
            } compactLeading: {
                DynamicCompactStatusEmoji(
                    lastFeedingDate: context.state.lastFeedingDate,
                    babyAgeMonths: context.attributes.babyAgeMonths
                )
            } compactTrailing: {
                DynamicCompactStatusLabel(
                    lastFeedingDate: context.state.lastFeedingDate,
                    babyAgeMonths: context.attributes.babyAgeMonths
                )
            } minimal: {
                DynamicStatusEmoji(
                    lastFeedingDate: context.state.lastFeedingDate,
                    babyAgeMonths: context.attributes.babyAgeMonths
                )
            }
            .keylineTint(liveActivityTint)
        }
    }
}

struct LockScreenView: View {
    let state: FeedingActivityAttributes.ContentState
    let babyAgeMonths: Int?

    var body: some View {
        TimelineView(.periodic(from: Date(), by: 60)) { timeline in
            let status = FeedingIntervalStatus(
                lastFeedingDate: state.lastFeedingDate,
                babyAgeMonths: babyAgeMonths,
                now: timeline.date
            )
            let accent = Color(hex: status.accentColorHex)

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Text("BaByBuddy")
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(.white)
                    Spacer(minLength: 12)
                    Text(clockText(from: state.lastFeedingDate) + " 上次喂养")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.68))
                }

                HStack(alignment: .center, spacing: 14) {
                    Text(status.emoji)
                        .font(.system(size: 40))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(status.label)
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                            .foregroundStyle(accent)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text(lockScreenDetailText(status: status))
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.72))
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "#262741").opacity(0.96),
                                Color(hex: "#171827").opacity(0.94)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(.white.opacity(0.14), lineWidth: 1)
                    )
            }
        }
    }
}

private struct DynamicIslandExpandedHeader: View {
    let lastFeedingDate: Date
    let babyAgeMonths: Int?

    var body: some View {
        TimelineView(.periodic(from: Date(), by: 60)) { context in
            let status = FeedingIntervalStatus(
                lastFeedingDate: lastFeedingDate,
                babyAgeMonths: babyAgeMonths,
                now: context.date
            )

            HStack(spacing: 8) {
                Text(status.emoji)
                    .font(.title3)
                Text(status.label)
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(Color(hex: status.accentColorHex))
                    .lineLimit(1)
            }
        }
    }
}

private struct DynamicIslandExpandedStatus: View {
    let lastFeedingDate: Date
    let babyAgeMonths: Int?

    var body: some View {
        TimelineView(.periodic(from: Date(), by: 60)) { context in
            let status = FeedingIntervalStatus(
                lastFeedingDate: lastFeedingDate,
                babyAgeMonths: babyAgeMonths,
                now: context.date
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(status.label)
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(Color(hex: status.accentColorHex))
                    .lineLimit(1)
                Text(clockText(from: lastFeedingDate) + " 上次喂养")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct DynamicIslandEmojiTrail: View {
    let lastFeedingDate: Date
    let babyAgeMonths: Int?

    var body: some View {
        TimelineView(.periodic(from: Date(), by: 60)) { context in
            let status = FeedingIntervalStatus(
                lastFeedingDate: lastFeedingDate,
                babyAgeMonths: babyAgeMonths,
                now: context.date
            )
            let accent = Color(hex: status.accentColorHex)

            HStack(spacing: 8) {
                Text("🍼")
                ForEach(0..<5, id: \.self) { _ in
                    Text(status.emoji)
                        .opacity(0.9)
                }
                Text("🍼")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(accent)
        }
    }
}

private struct DynamicCompactStatusEmoji: View {
    let lastFeedingDate: Date
    let babyAgeMonths: Int?

    var body: some View {
        TimelineView(.periodic(from: Date(), by: 60)) { context in
            let status = FeedingIntervalStatus(
                lastFeedingDate: lastFeedingDate,
                babyAgeMonths: babyAgeMonths,
                now: context.date
            )
            Text(status.emoji)
                .font(.system(.caption, design: .rounded))
        }
    }
}

private struct DynamicCompactStatusLabel: View {
    let lastFeedingDate: Date
    let babyAgeMonths: Int?

    var body: some View {
        TimelineView(.periodic(from: Date(), by: 60)) { context in
            let status = FeedingIntervalStatus(
                lastFeedingDate: lastFeedingDate,
                babyAgeMonths: babyAgeMonths,
                now: context.date
            )
            Text(status.label)
                .font(.system(.caption2, design: .rounded).weight(.bold))
                .lineLimit(1)
        }
    }
}

private struct DynamicStatusEmoji: View {
    let lastFeedingDate: Date
    let babyAgeMonths: Int?

    var body: some View {
        TimelineView(.periodic(from: Date(), by: 60)) { context in
            let status = FeedingIntervalStatus(
                lastFeedingDate: lastFeedingDate,
                babyAgeMonths: babyAgeMonths,
                now: context.date
            )
            Text(status.emoji)
        }
    }
}

private func clockText(from date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    return formatter.string(from: date)
}

private func lockScreenDetailText(status: FeedingIntervalStatus) -> String {
    switch status {
    case .justFed:
        return "刚完成喂养，暂时不用着急。"
    case .tooSoon:
        return "还不太饿，继续观察就可以。"
    case .safe:
        return "状态正好，按当前节奏陪伴。"
    case .maybeHungry:
        return "可以开始留意饥饿信号。"
    case .definitelyHungry:
        return "宝宝已经饿了，建议准备喂养。"
    case .warning:
        return "建议尽快安排下一次喂养。"
    }
}
