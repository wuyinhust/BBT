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
    static let careRecords = "care_records_v1"
    static let babyInfo = "baby_info"
    static let lastFeedingWidgetKind = "v.babybuddy.LastFeeding"
}

enum WidgetEASYPalette {
    // E/A/S/Y flower colors: Iris, Camellia, Delphinium, Viburnum.
    static let eat = "#7C5CFF"
    static let eatSoft = "#EDE7FF"
    static let eatText = "#4936A8"

    static let activity = "#FF7A90"
    static let activitySoft = "#FFE8EE"
    static let activityText = "#9B3147"

    static let diaper = "#F59A6B"
    static let diaperSoft = "#FFF0E6"
    static let diaperText = "#8C4930"

    static let sleep = "#2F80ED"
    static let sleepSoft = "#E7F1FF"
    static let sleepText = "#1856B6"

    static let yearning = "#29B87A"
    static let yearningSoft = "#E4F8EE"

    static let canvas = "#FAFAFC"
    static let surface = "#FFFFFF"
    static let surfaceSoft = "#F6F2FF"
    static let borderSubtle = "#E5E3EC"
    static let textStrong = "#282738"
    static let textMuted = "#737286"
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

    var summaryText: String {
        if let bottleAmount = entries.compactMap(\.bottleAmount).first {
            return "\(bottleAmount)ml"
        }
        let breastMinutes = entries.compactMap(\.breastDuration).reduce(0, +)
        if breastMinutes > 0 {
            return "\(breastMinutes)分钟"
        }
        if let solidAmount = entries.compactMap(\.solidAmount).first {
            return "\(Int(solidAmount))g"
        }
        return "已记录"
    }
}

enum WidgetCareRecordKind: String, Decodable {
    case diaper
    case sleep
}

struct WidgetCareRecord: Decodable {
    var kind: WidgetCareRecordKind
    var title: String
    var detail: String
    var note: String
    var recordedAt: Date
}

enum RecentCareActivityKind: String, CaseIterable {
    case feeding
    case diaper
    case sleep

    var title: String {
        switch self {
        case .feeding: return "喂养"
        case .diaper: return "尿布"
        case .sleep: return "睡眠"
        }
    }

    var fullTitle: String {
        switch self {
        case .feeding: return "最近喂养"
        case .diaper: return "最近尿布"
        case .sleep: return "最近睡眠"
        }
    }

    var imageResource: ImageResource {
        switch self {
        case .feeding: return .rhythmFeedingIcon
        case .diaper: return .rhythmDiaperIcon
        case .sleep: return .rhythmSleepIcon
        }
    }

    var accentHex: String {
        switch self {
        case .feeding: return WidgetEASYPalette.eat
        case .diaper: return WidgetEASYPalette.diaper
        case .sleep: return WidgetEASYPalette.sleep
        }
    }

    var lightHex: String {
        switch self {
        case .feeding: return WidgetEASYPalette.eatSoft
        case .diaper: return WidgetEASYPalette.diaperSoft
        case .sleep: return WidgetEASYPalette.sleepSoft
        }
    }

    var textHex: String {
        switch self {
        case .feeding: return WidgetEASYPalette.eatText
        case .diaper: return WidgetEASYPalette.diaperText
        case .sleep: return WidgetEASYPalette.sleepText
        }
    }
}

struct RecentCareActivity: Identifiable {
    let kind: RecentCareActivityKind
    let lastDate: Date?
    let detail: String

    var id: String { kind.rawValue }
}

struct CareActivityWidgetEntry: TimelineEntry {
    var date: Date
    var babyInfo: WidgetBabyInfo?
    var activities: [RecentCareActivity]

    func activity(_ kind: RecentCareActivityKind) -> RecentCareActivity {
        activities.first { $0.kind == kind } ?? RecentCareActivity(kind: kind, lastDate: nil, detail: "暂无记录")
    }
}

struct CareActivityWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> CareActivityWidgetEntry {
        let now = Date()
        return CareActivityWidgetEntry(
            date: now,
            babyInfo: WidgetBabyInfo(name: "33", birthDate: Calendar.current.date(byAdding: .day, value: -22, to: now) ?? now),
            activities: [
                RecentCareActivity(kind: .feeding, lastDate: now.addingTimeInterval(-2 * 3600 - 12 * 60), detail: "120ml"),
                RecentCareActivity(kind: .diaper, lastDate: now.addingTimeInterval(-55 * 60), detail: "尿了"),
                RecentCareActivity(kind: .sleep, lastDate: now.addingTimeInterval(-4 * 3600 - 20 * 60), detail: "小睡")
            ]
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (CareActivityWidgetEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CareActivityWidgetEntry>) -> Void) {
        let entry = loadEntry()
        completion(Timeline(entries: [entry], policy: .after(entry.date.addingTimeInterval(60))))
    }

    private func loadEntry(date: Date = Date()) -> CareActivityWidgetEntry {
        let defaults = UserDefaults(suiteName: WidgetStorageKey.appGroupID)
        let sessions = defaults?.data(forKey: WidgetStorageKey.feedingSessions)
            .flatMap { try? JSONDecoder().decode([WidgetFeedingSession].self, from: $0) } ?? []
        let babyInfo = defaults?.data(forKey: WidgetStorageKey.babyInfo)
            .flatMap { try? JSONDecoder().decode(WidgetBabyInfo.self, from: $0) }
        let careRecords = defaults?.data(forKey: WidgetStorageKey.careRecords)
            .flatMap { try? JSONDecoder().decode([WidgetCareRecord].self, from: $0) } ?? []
        let latestFeeding = sessions.max { $0.createdAt < $1.createdAt }
        let latestDiaper = careRecords.filter { $0.kind == .diaper }.max { $0.recordedAt < $1.recordedAt }
        let latestSleep = careRecords.filter { $0.kind == .sleep }.max { $0.recordedAt < $1.recordedAt }

        return CareActivityWidgetEntry(
            date: date,
            babyInfo: babyInfo,
            activities: [
                RecentCareActivity(kind: .feeding, lastDate: latestFeeding?.createdAt, detail: latestFeeding?.summaryText ?? "暂无记录"),
                RecentCareActivity(kind: .diaper, lastDate: latestDiaper?.recordedAt, detail: latestDiaper.map { DiaperRecordTitle.normalized($0.title) } ?? "暂无记录"),
                RecentCareActivity(kind: .sleep, lastDate: latestSleep?.recordedAt, detail: latestSleep?.title ?? "暂无记录")
            ]
        )
    }

}

struct BaByBuddyWidget: Widget {
    let kind = WidgetStorageKey.lastFeedingWidgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CareActivityWidgetProvider()) { entry in
            CareActivityWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color.clear
                }
        }
        .configurationDisplayName("BabyBuddy")
        .description("查看最近喂养、尿布和睡眠")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

private enum DiaperRecordTitle {
    static func normalized(_ title: String) -> String {
        switch title {
        case "湿尿布":
            return "尿了"
        case "便便", "混合":
            return "拉了"
        default:
            return title
        }
    }
}

struct CareActivityWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CareActivityWidgetEntry

    var body: some View {
        switch family {
        case .systemSmall:
            smallWidget
        case .systemMedium:
            mediumWidget
        default:
            largeWidget
        }
    }

    private var smallWidget: some View {
        VStack(alignment: .leading, spacing: 8) {
            widgetHeader(titleSize: 12, subtitleSize: 8, showsSubtitle: false)

            HStack(spacing: 7) {
                activityTile(entry.activity(.feeding), style: .hero)
                VStack(spacing: 7) {
                    activityTile(entry.activity(.diaper), style: .mini)
                    activityTile(entry.activity(.sleep), style: .mini)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(10)
        .widgetRecordBackground()
    }

    private var mediumWidget: some View {
        VStack(alignment: .leading, spacing: 10) {
            widgetHeader(titleSize: 17, subtitleSize: 9, showsSubtitle: true)

            HStack(spacing: 8) {
                ForEach(RecentCareActivityKind.allCases, id: \.rawValue) { kind in
                    activityTile(entry.activity(kind), style: .medium)
                }
            }
        }
        .padding(14)
        .widgetRecordBackground()
    }

    private var largeWidget: some View {
        VStack(alignment: .leading, spacing: 12) {
            widgetHeader(titleSize: 21, subtitleSize: 10, showsSubtitle: true)

            HStack(spacing: 8) {
                ForEach(RecentCareActivityKind.allCases, id: \.rawValue) { kind in
                    let activity = entry.activity(kind)
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(hex: kind.accentHex))
                            .frame(width: 7, height: 7)
                        Text(kind.title)
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color(hex: WidgetEASYPalette.textMuted))
                            .lineLimit(1)
                        Text(elapsedText(for: activity, compact: true))
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color(hex: kind.textHex))
                            .lineLimit(1)
                            .minimumScaleFactor(0.76)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 7)
                    .frame(maxWidth: .infinity)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color(hex: kind.lightHex).opacity(0.72))
                            .overlay {
                                Capsule(style: .continuous)
                                    .stroke(Color.white.opacity(0.82), lineWidth: 1)
                            }
                    )
                }
            }

            VStack(spacing: 9) {
                ForEach(RecentCareActivityKind.allCases, id: \.rawValue) { kind in
                    activityRow(entry.activity(kind))
                }
            }
        }
        .padding(16)
        .widgetRecordBackground()
    }

    private func widgetHeader(titleSize: CGFloat, subtitleSize: CGFloat, showsSubtitle: Bool) -> some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(entry.babyInfo?.name ?? "宝宝")的最近照护")
                    .font(.system(size: titleSize, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(hex: WidgetEASYPalette.textStrong))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                if showsSubtitle {
                    Text("Eat · Activity · Sleep · You")
                        .font(.system(size: subtitleSize, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: WidgetEASYPalette.textMuted))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
            }

            Spacer(minLength: 6)

            easyBadge
        }
    }

    private var easyBadge: some View {
        HStack(spacing: 3) {
            Circle().fill(Color(hex: WidgetEASYPalette.eat))
            Circle().fill(Color(hex: WidgetEASYPalette.activity))
            Circle().fill(Color(hex: WidgetEASYPalette.sleep))
            Circle().fill(Color(hex: WidgetEASYPalette.yearning))
        }
        .frame(width: 34, height: 8)
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.72))
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(Color(hex: WidgetEASYPalette.borderSubtle), lineWidth: 1)
                }
        )
    }

    private func activityTile(_ activity: RecentCareActivity, style: ActivityTileStyle) -> some View {
        VStack(alignment: .leading, spacing: style.spacing) {
            activityIcon(activity.kind, size: style.iconSize)

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 2) {
                Text(activity.kind.title)
                    .font(.system(size: style.titleSize, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(hex: WidgetEASYPalette.textMuted))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Text(elapsedText(for: activity, compact: style.usesCompactElapsedText))
                    .font(.system(size: style.valueSize, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(hex: activity.kind.textHex))
                    .lineLimit(style.valueLines)
                    .minimumScaleFactor(0.58)
                if style.showsDetail {
                    Text(activity.detail)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: WidgetEASYPalette.textMuted))
                        .lineLimit(1)
                        .minimumScaleFactor(0.74)
                }
            }
        }
        .padding(style.padding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                .fill(tileFill(for: activity.kind))
                .overlay {
                    RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.88), lineWidth: 1.2)
                }
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(Color(hex: activity.kind.accentHex).opacity(0.13))
                        .frame(width: style.iconSize * 2.2, height: style.iconSize * 2.2)
                        .offset(x: style.iconSize * 0.7, y: -style.iconSize * 0.8)
                }
                .shadow(color: Color(hex: activity.kind.accentHex).opacity(0.10), radius: 10, y: 5)
        )
    }

    private func activityRow(_ activity: RecentCareActivity) -> some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color(hex: activity.kind.accentHex))
                .frame(width: 4)

            activityIcon(activity.kind, size: 34)
                .frame(width: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text(activity.kind.fullTitle)
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(hex: WidgetEASYPalette.textMuted))
                    .lineLimit(1)
                Text(elapsedText(for: activity))
                    .font(.system(size: 25, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(hex: activity.kind.textHex))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Text(activity.detail)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: WidgetEASYPalette.textStrong))
                    .lineLimit(1)
                Text(clockText(for: activity))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: WidgetEASYPalette.textMuted))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 27, style: .continuous)
                .fill(tileFill(for: activity.kind))
                .overlay(
                    RoundedRectangle(cornerRadius: 27, style: .continuous)
                        .stroke(Color.white.opacity(0.88), lineWidth: 1.2)
                )
                .shadow(color: Color(hex: activity.kind.accentHex).opacity(0.08), radius: 12, y: 6)
        )
    }

    private func activityIcon(_ kind: RecentCareActivityKind, size: CGFloat) -> some View {
        Image(kind.imageResource)
            .resizable()
            .scaledToFit()
            .frame(width: size * 1.18, height: size * 1.18)
            .shadow(color: Color(hex: kind.textHex).opacity(0.18), radius: 5, y: 2)
            .padding(max(size * 0.18, 5))
            .background(
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.96),
                                Color(hex: kind.lightHex).opacity(0.90)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        Circle()
                            .stroke(Color(hex: kind.accentHex).opacity(0.34), lineWidth: 1.2)
                    )
            )
    }

    private func tileFill(for kind: RecentCareActivityKind) -> LinearGradient {
        LinearGradient(
            colors: [
                Color(hex: kind.lightHex).opacity(0.96),
                Color(hex: WidgetEASYPalette.surface).opacity(0.74)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func elapsedText(for activity: RecentCareActivity, compact: Bool = false) -> String {
        guard let lastDate = activity.lastDate else { return "暂无" }
        let minutes = max(Int(entry.date.timeIntervalSince(lastDate) / 60), 0)
        if minutes < 1 {
            return "刚刚"
        }
        if minutes < 60 {
            return compact ? "\(minutes)分" : "\(minutes)分钟前"
        }
        if minutes < 24 * 60 {
            let hours = minutes / 60
            let remaining = minutes % 60
            if compact {
                return remaining == 0 ? "\(hours)时" : "\(hours)时\(remaining)分"
            }
            return remaining == 0 ? "\(hours)小时前" : "\(hours)小时\(remaining)分前"
        }
        let days = minutes / (24 * 60)
        let hours = (minutes % (24 * 60)) / 60
        if compact {
            return hours == 0 ? "\(days)天" : "\(days)天\(hours)时"
        }
        return hours == 0 ? "\(days)天前" : "\(days)天\(hours)小时前"
    }

    private func clockText(for activity: RecentCareActivity) -> String {
        guard let lastDate = activity.lastDate else { return "--:--" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: lastDate)
    }
}

private struct ActivityTileStyle {
    let padding: EdgeInsets
    let iconSize: CGFloat
    let titleSize: CGFloat
    let valueSize: CGFloat
    let spacing: CGFloat
    let cornerRadius: CGFloat
    let valueLines: Int
    let showsDetail: Bool
    let usesCompactElapsedText: Bool

    static let hero = ActivityTileStyle(
        padding: EdgeInsets(top: 11, leading: 11, bottom: 11, trailing: 9),
        iconSize: 25,
        titleSize: 12,
        valueSize: 19,
        spacing: 5,
        cornerRadius: 24,
        valueLines: 2,
        showsDetail: false,
        usesCompactElapsedText: true
    )

    static let mini = ActivityTileStyle(
        padding: EdgeInsets(top: 8, leading: 9, bottom: 8, trailing: 7),
        iconSize: 16,
        titleSize: 10,
        valueSize: 13,
        spacing: 3,
        cornerRadius: 19,
        valueLines: 2,
        showsDetail: false,
        usesCompactElapsedText: true
    )

    static let medium = ActivityTileStyle(
        padding: EdgeInsets(top: 11, leading: 12, bottom: 11, trailing: 10),
        iconSize: 22,
        titleSize: 12,
        valueSize: 17,
        spacing: 5,
        cornerRadius: 23,
        valueLines: 2,
        showsDetail: true,
        usesCompactElapsedText: true
    )
}

private extension View {
    func widgetRecordBackground() -> some View {
        background {
            WidgetRecordBackground()
        }
    }
}

private struct WidgetRecordBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 30, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(hex: WidgetEASYPalette.surface).opacity(0.92),
                        Color(hex: WidgetEASYPalette.surfaceSoft).opacity(0.84),
                        Color(hex: WidgetEASYPalette.canvas).opacity(0.78)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(alignment: .topTrailing) {
                Circle()
                    .fill(Color(hex: WidgetEASYPalette.yearningSoft).opacity(0.72))
                    .frame(width: 96, height: 96)
                    .blur(radius: 18)
                    .offset(x: 28, y: -34)
            }
            .overlay(alignment: .bottomLeading) {
                Circle()
                    .fill(Color(hex: WidgetEASYPalette.eatSoft).opacity(0.78))
                    .frame(width: 118, height: 118)
                    .blur(radius: 22)
                    .offset(x: -34, y: 34)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(Color.white.opacity(0.82), lineWidth: 1.2)
            )
            .shadow(color: Color(hex: WidgetEASYPalette.sleep).opacity(0.12), radius: 18, y: 9)
    }
}

struct FeedingLiveActivity: Widget {
    private let liveActivityTint = Color(hex: "#8E79FF")

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FeedingActivityAttributes.self) { context in
            LockScreenView(state: context.state)
                .activityBackgroundTint(Color(hex: "#171827").opacity(0.92))
                .activitySystemActionForegroundColor(liveActivityTint)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    DynamicIslandExpandedHeader(
                        lastFeedingDate: context.state.lastFeedingDate,
                        babyAgeMonths: context.state.babyAgeMonths
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
                        babyAgeMonths: context.state.babyAgeMonths
                    )
                }
                DynamicIslandExpandedRegion(.bottom) {
                    DynamicIslandEmojiTrail(
                        lastFeedingDate: context.state.lastFeedingDate,
                        babyAgeMonths: context.state.babyAgeMonths
                    )
                }
            } compactLeading: {
                DynamicCompactStatusEmoji(
                    lastFeedingDate: context.state.lastFeedingDate,
                    babyAgeMonths: context.state.babyAgeMonths
                )
            } compactTrailing: {
                DynamicCompactStatusLabel(
                    lastFeedingDate: context.state.lastFeedingDate,
                    babyAgeMonths: context.state.babyAgeMonths
                )
            } minimal: {
                DynamicStatusEmoji(
                    lastFeedingDate: context.state.lastFeedingDate,
                    babyAgeMonths: context.state.babyAgeMonths
                )
            }
            .keylineTint(liveActivityTint)
        }
    }
}

struct LockScreenView: View {
    let state: FeedingActivityAttributes.ContentState

    var body: some View {
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
                Text("🍼")
                    .font(.system(size: 40))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    ElapsedFeedingTimerText(prefix: "距上次喂养 ", lastFeedingDate: state.lastFeedingDate)
                        .font(.system(size: 25, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(hex: "#C2B7FF"))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Text("打开应用查看最新照护建议")
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

private struct DynamicIslandExpandedHeader: View {
    let lastFeedingDate: Date
    let babyAgeMonths: Int?

    var body: some View {
        HStack(spacing: 8) {
            Text("🍼")
                .font(.title3)
            ElapsedFeedingTimerText(lastFeedingDate: lastFeedingDate)
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(Color(hex: "#C2B7FF"))
                .lineLimit(1)
        }
    }
}

private struct DynamicIslandExpandedStatus: View {
    let lastFeedingDate: Date
    let babyAgeMonths: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ElapsedFeedingTimerText(prefix: "距上次喂养 ", lastFeedingDate: lastFeedingDate)
                .font(.headline.weight(.heavy))
                .foregroundStyle(Color(hex: "#C2B7FF"))
                .lineLimit(1)
            Text(clockText(from: lastFeedingDate) + " 上次喂养")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
}

private struct DynamicIslandEmojiTrail: View {
    let lastFeedingDate: Date
    let babyAgeMonths: Int?

    var body: some View {
        HStack(spacing: 8) {
            Text("🍼")
            Text("打开应用查看最新照护建议")
            Text("🍼")
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(Color(hex: "#C2B7FF"))
    }
}

private struct DynamicCompactStatusEmoji: View {
    let lastFeedingDate: Date
    let babyAgeMonths: Int?

    var body: some View {
        Text("🍼")
            .font(.system(.caption, design: .rounded))
    }
}

private struct DynamicCompactStatusLabel: View {
    let lastFeedingDate: Date
    let babyAgeMonths: Int?

    var body: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: 11, weight: .heavy))
            .foregroundStyle(Color(hex: "#C2B7FF"))
            .frame(width: 18, height: 18)
    }
}

private struct DynamicStatusEmoji: View {
    let lastFeedingDate: Date
    let babyAgeMonths: Int?

    var body: some View {
        Text("🍼")
    }
}

private struct ElapsedFeedingTimerText: View {
    var prefix = ""
    let lastFeedingDate: Date

    var body: some View {
        HStack(spacing: 0) {
            if !prefix.isEmpty {
                Text(prefix)
            }
            Text(
                timerInterval: lastFeedingDate...lastFeedingDate.addingTimeInterval(24 * 60 * 60),
                countsDown: false,
                showsHours: true
            )
        }
        .monospacedDigit()
    }
}

private func clockText(from date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    return formatter.string(from: date)
}

private func elapsedFeedingText(from date: Date, now: Date) -> String {
    "距上次喂养 " + elapsedShortText(from: date, now: now)
}

private func elapsedShortText(from date: Date, now: Date) -> String {
    let minutes = max(Int(now.timeIntervalSince(date) / 60), 0)
    if minutes < 60 {
        return "\(minutes)分钟"
    }
    return "\(minutes / 60)小时\(minutes % 60)分"
}
