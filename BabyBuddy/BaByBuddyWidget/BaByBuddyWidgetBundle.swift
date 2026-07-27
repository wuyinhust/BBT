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
    static let careRecencySnapshot = "care_recency_snapshot_v1"
    static let babyInfo = "baby_info"
    static let lastFeedingWidgetKind = "v.babybuddy.LastFeeding"
}

/// Shared semantic colors only. The catalog is included in this target so
/// widgets and Live Activities follow the system appearance independently of
/// the app's in-app appearance override.
enum WidgetColor {
    static let canvas = Color("BB_Canvas")
    static let surface = Color("BB_Surface")
    static let surfaceRaised = Color("BB_SurfaceRaised")
    static let surfaceSoft = Color("BB_SurfaceSoft")
    static let borderSubtle = Color("BB_Border")
    static let textStrong = Color("BB_TextStrong")
    static let textMuted = Color("BB_TextMuted")
    static let glassFill = Color("BB_GlassFill")
    static let glassStroke = Color("BB_GlassStroke")
    static let shadow = Color("BB_Shadow")
    static let onPrimary = Color("BB_OnPrimary")
    static let primary = Color("BB_PrimaryAction")

    static let eat = Color("BB_EasyEat")
    static let eatSoft = Color("BB_EasyEatSoft")
    static let eatText = Color("BB_EasyEatText")
    static let activity = Color("BB_EasyActivity")
    static let activitySoft = Color("BB_EasyActivitySoft")
    static let activityText = Color("BB_EasyActivityText")
    static let diaper = Color("BB_Diaper")
    static let diaperSoft = Color("BB_DiaperSoft")
    static let diaperText = Color("BB_DiaperText")
    static let sleep = Color("BB_EasySleep")
    static let sleepSoft = Color("BB_EasySleepSoft")
    static let sleepText = Color("BB_EasySleepText")
    static let yearning = Color("BB_EasyYearning")
    static let yearningSoft = Color("BB_EasyYearningSoft")
    static let yearningText = Color("BB_EasyYearningText")
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
    var startAt: Date?
    var endAt: Date?

    var completedAt: Date {
        if let startAt, let endAt, startAt <= endAt {
            return endAt
        }
        return createdAt
    }

    var summaryText: String {
        if let bottleAmount = entries.compactMap(\.bottleAmount).first {
            return AppMeasurementFormat.volume(Double(bottleAmount))
        }
        let breastMinutes = entries.compactMap(\.breastDuration).reduce(0, +)
        if breastMinutes > 0 {
            return "\(breastMinutes)分钟"
        }
        if let solidAmount = entries.compactMap(\.solidAmount).first {
            return AppMeasurementFormat.mass(solidAmount)
        }
        return "已记录"
    }
}

enum WidgetCareRecordKind: String, Decodable {
    case diaper
    case activity
    case sleep
}

struct WidgetCareRecord: Decodable {
    var kind: WidgetCareRecordKind
    var title: String
    var detail: String
    var note: String
    var recordedAt: Date

    var completedAt: Date {
        guard kind == .sleep,
              let minutes = detail.split(separator: " ").first.flatMap({ Int($0) }) else {
            return recordedAt
        }
        return recordedAt.addingTimeInterval(TimeInterval(max(minutes, 1) * 60))
    }
}

enum RecentCareActivityKind: String, CaseIterable {
    case feeding
    case pee
    case poop
    case sleep

    var title: String {
        switch self {
        case .feeding: return "喂养"
        case .pee: return "尿尿"
        case .poop: return "粑粑"
        case .sleep: return "睡眠"
        }
    }

    var fullTitle: String {
        switch self {
        case .feeding: return "最近喂养"
        case .pee: return "最近尿尿"
        case .poop: return "最近粑粑"
        case .sleep: return "最近睡眠"
        }
    }

    var imageResource: ImageResource {
        switch self {
        case .feeding: return .rhythmFeedingIcon
        case .pee, .poop: return .rhythmDiaperIcon
        case .sleep: return .rhythmSleepIcon
        }
    }

    var accentColor: Color {
        switch self {
        case .feeding: return WidgetColor.eat
        case .pee, .poop: return WidgetColor.diaper
        case .sleep: return WidgetColor.sleep
        }
    }

    var softColor: Color {
        switch self {
        case .feeding: return WidgetColor.eatSoft
        case .pee, .poop: return WidgetColor.diaperSoft
        case .sleep: return WidgetColor.sleepSoft
        }
    }

    var textColor: Color {
        switch self {
        case .feeding: return WidgetColor.eatText
        case .pee, .poop: return WidgetColor.diaperText
        case .sleep: return WidgetColor.sleepText
        }
    }

    var sharedKind: CareRecencyKind {
        CareRecencyKind(rawValue: rawValue) ?? .feeding
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
    var activeTiming: ActiveTimingSnapshot

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
                RecentCareActivity(kind: .pee, lastDate: now.addingTimeInterval(-55 * 60), detail: "尿了不少"),
                RecentCareActivity(kind: .poop, lastDate: now.addingTimeInterval(-3 * 3600 - 8 * 60), detail: "糊状便"),
                RecentCareActivity(kind: .sleep, lastDate: now.addingTimeInterval(-4 * 3600 - 20 * 60), detail: "小睡")
            ],
            activeTiming: .empty(at: now)
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (CareActivityWidgetEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CareActivityWidgetEntry>) -> Void) {
        let entry = loadEntry()
        completion(Timeline(entries: [entry], policy: .after(entry.date.addingTimeInterval(15 * 60))))
    }

    private func loadEntry(date: Date = Date()) -> CareActivityWidgetEntry {
        let defaults = UserDefaults(suiteName: WidgetStorageKey.appGroupID)
        let feedingData = defaults?.data(forKey: WidgetStorageKey.feedingSessions)
        let decodedSessions = feedingData
            .flatMap { try? JSONDecoder().decode([WidgetFeedingSession].self, from: $0) }
        let sessions = decodedSessions ?? []
        let babyInfo = defaults?.data(forKey: WidgetStorageKey.babyInfo)
            .flatMap { try? JSONDecoder().decode(WidgetBabyInfo.self, from: $0) }
        let careRecordsData = defaults?.data(forKey: WidgetStorageKey.careRecords)
        let decodedCareRecords = careRecordsData
            .flatMap { try? JSONDecoder().decode([WidgetCareRecord].self, from: $0) }
        let careRecords = decodedCareRecords ?? []
        let persistedSnapshot = defaults?.data(forKey: WidgetStorageKey.careRecencySnapshot)
            .flatMap { try? JSONDecoder().decode(CareRecencySnapshot.self, from: $0) }
        let recomputedSnapshot = legacySnapshot(sessions: sessions, careRecords: careRecords, date: date)
        let snapshot = reconciledSnapshot(
            persisted: persistedSnapshot,
            recomputed: recomputedSnapshot,
            hasFeedingData: decodedSessions != nil,
            hasCareData: decodedCareRecords != nil,
            date: date
        )
        let activeTiming = defaults?.data(forKey: ActiveTimingStorage.snapshotKey)
            .flatMap { try? JSONDecoder().decode(ActiveTimingSnapshot.self, from: $0) }
            ?? .empty(at: date)

        return CareActivityWidgetEntry(
            date: date,
            babyInfo: babyInfo,
            activities: RecentCareActivityKind.allCases.map { kind in
                let item = snapshot.item(for: kind.sharedKind)
                return RecentCareActivity(kind: kind, lastDate: item.completedAt, detail: item.detail)
            },
            activeTiming: activeTiming
        )
    }

    private func reconciledSnapshot(
        persisted: CareRecencySnapshot?,
        recomputed: CareRecencySnapshot,
        hasFeedingData: Bool,
        hasCareData: Bool,
        date: Date
    ) -> CareRecencySnapshot {
        guard var snapshot = persisted else { return recomputed }

        // Raw shared records are authoritative whenever their key exists. The
        // cached snapshot remains a fallback for a first launch or a transient
        // app-group read before the stores have written their keys.
        if hasFeedingData {
            snapshot.feeding = recomputed.feeding
        }
        if hasCareData {
            snapshot.pee = recomputed.pee
            snapshot.poop = recomputed.poop
            snapshot.sleep = recomputed.sleep
        }
        snapshot.generatedAt = date
        return snapshot
    }

    private func legacySnapshot(
        sessions: [WidgetFeedingSession],
        careRecords: [WidgetCareRecord],
        date: Date
    ) -> CareRecencySnapshot {
        let latestFeeding = sessions
            .filter { $0.completedAt <= date }
            .max { $0.completedAt < $1.completedAt }
        let latestPee = careRecords
            .filter { $0.kind == .diaper && $0.recordedAt <= date && DiaperRecordTitle.containsPee($0.title) }
            .max { $0.recordedAt < $1.recordedAt }
        let latestPoop = careRecords
            .filter { $0.kind == .diaper && $0.recordedAt <= date && DiaperRecordTitle.containsPoop($0.title) }
            .max { $0.recordedAt < $1.recordedAt }
        let latestSleep = careRecords
            .filter { $0.kind == .sleep && $0.completedAt <= date }
            .max { $0.completedAt < $1.completedAt }

        return CareRecencySnapshot(
            generatedAt: date,
            feeding: CareRecencyItem(kind: .feeding, completedAt: latestFeeding?.completedAt, detail: latestFeeding?.summaryText ?? "暂无记录"),
            pee: CareRecencyItem(kind: .pee, completedAt: latestPee?.recordedAt, detail: latestPee?.detail ?? "暂无记录"),
            poop: CareRecencyItem(kind: .poop, completedAt: latestPoop?.recordedAt, detail: latestPoop?.detail ?? "暂无记录"),
            sleep: CareRecencyItem(kind: .sleep, completedAt: latestSleep?.completedAt, detail: latestSleep?.title ?? "暂无记录")
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
        .description("查看最近喂养、尿尿、粑粑和睡眠")
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

    static func containsPee(_ title: String) -> Bool {
        title == "混合" || normalized(title) == "尿了"
    }

    static func containsPoop(_ title: String) -> Bool {
        title == "混合" || normalized(title) == "拉了"
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

            if entry.activeTiming.hasActiveTiming {
                VStack(spacing: 6) {
                    ForEach(entry.activeTiming.items) { item in
                        widgetTimingBanner(item, compact: true)
                    }
                }
            } else {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 2),
                    spacing: 6
                ) {
                    ForEach(RecentCareActivityKind.allCases, id: \.rawValue) { kind in
                        activityTile(entry.activity(kind), style: .small)
                            .frame(height: 48)
                    }
                }
            }
        }
        .padding(10)
        .widgetRecordBackground()
    }

    private var mediumWidget: some View {
        VStack(alignment: .leading, spacing: 10) {
            widgetHeader(titleSize: 17, subtitleSize: 9, showsSubtitle: true)

            if let item = entry.activeTiming.items.first {
                widgetTimingBanner(item, compact: true)
            }

            HStack(spacing: 6) {
                ForEach(RecentCareActivityKind.allCases, id: \.rawValue) { kind in
                    activityTile(entry.activity(kind), style: .medium)
                }
            }
        }
        .padding(14)
        .widgetRecordBackground()
    }

    private var largeWidget: some View {
        VStack(alignment: .leading, spacing: 10) {
            widgetHeader(titleSize: 21, subtitleSize: 10, showsSubtitle: true)

            if !entry.activeTiming.items.isEmpty {
                HStack(spacing: 8) {
                    ForEach(entry.activeTiming.items) { item in
                        widgetTimingBanner(item, compact: false)
                    }
                }
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 9), count: 2),
                spacing: 9
            ) {
                ForEach(RecentCareActivityKind.allCases, id: \.rawValue) { kind in
                    activityTile(entry.activity(kind), style: .large)
                        .frame(height: 120)
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
                    .foregroundStyle(WidgetColor.textStrong)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                if showsSubtitle {
                    Text("Eat · Activity · Sleep · You")
                        .font(.system(size: subtitleSize, weight: .bold, design: .rounded))
                        .foregroundStyle(WidgetColor.textMuted)
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
            Circle().fill(WidgetColor.eat)
            Circle().fill(WidgetColor.activity)
            Circle().fill(WidgetColor.sleep)
            Circle().fill(WidgetColor.yearning)
        }
        .frame(width: 34, height: 8)
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            Capsule(style: .continuous)
                .fill(WidgetColor.surfaceRaised.opacity(0.72))
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(WidgetColor.borderSubtle, lineWidth: 1)
                }
        )
    }

    private func widgetTimingBanner(_ item: ActiveTimingItem, compact: Bool) -> some View {
        let accent = item.kind == .sleep
            ? WidgetColor.sleep
            : WidgetColor.eat

        return HStack(spacing: 7) {
            Image(systemName: item.kind == .sleep ? "moon.zzz.fill" : "timer")
                .font(.system(size: compact ? 10 : 12, weight: .bold))
                .foregroundStyle(WidgetColor.onPrimary)
                .frame(width: compact ? 22 : 28, height: compact ? 22 : 28)
                .background(Circle().fill(accent))

            VStack(alignment: .leading, spacing: 1) {
                Text("\(item.kind.title) 记录中")
                    .font(.system(size: compact ? 9 : 11, weight: .bold, design: .rounded))
                    .foregroundStyle(WidgetColor.textStrong)
                Text(item.startedAt, format: .dateTime.hour().minute())
                    .font(.system(size: compact ? 8 : 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(WidgetColor.textMuted)
            }

            Spacer(minLength: 2)

            Text(timerInterval: item.startedAt...Date.distantFuture, countsDown: false)
                .font(.system(size: compact ? 9 : 11, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(accent)
        }
        .padding(.horizontal, compact ? 8 : 10)
        .frame(maxWidth: .infinity)
        .frame(height: compact ? 34 : 42)
        .background(RoundedRectangle(cornerRadius: compact ? 11 : 14, style: .continuous).fill(accent.opacity(0.09)))
    }

    private func activityTile(_ activity: RecentCareActivity, style: ActivityTileStyle) -> some View {
        Group {
            if style.usesHorizontalLayout {
                HStack(spacing: 6) {
                    activityIcon(activity.kind, size: style.iconSize)
                    activityTileLabels(activity, style: style)
                }
            } else {
                VStack(alignment: .leading, spacing: style.spacing) {
                    activityIcon(activity.kind, size: style.iconSize)
                    Spacer(minLength: 0)
                    activityTileLabels(activity, style: style)
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
                        .stroke(WidgetColor.glassStroke.opacity(0.88), lineWidth: 1.2)
                }
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(activity.kind.accentColor.opacity(0.13))
                        .frame(width: style.iconSize * 2.2, height: style.iconSize * 2.2)
                        .offset(x: style.iconSize * 0.7, y: -style.iconSize * 0.8)
                }
                .shadow(color: activity.kind.accentColor.opacity(0.10), radius: 10, y: 5)
        )
    }

    private func activityTileLabels(_ activity: RecentCareActivity, style: ActivityTileStyle) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(activity.kind.title.localized)
                .font(.system(size: style.titleSize, weight: .heavy, design: .rounded))
                .foregroundStyle(WidgetColor.textMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
            elapsedText(for: activity)
                .font(.system(size: style.valueSize, weight: .heavy, design: .rounded))
                .foregroundStyle(activity.kind.textColor)
                .lineLimit(style.valueLines)
                .minimumScaleFactor(0.58)
            if style.showsDetail {
                HStack(spacing: 5) {
                    Text(activity.detail.localized)
                        .lineLimit(1)
                    Spacer(minLength: 2)
                    Text(clockText(for: activity))
                        .monospacedDigit()
                }
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(WidgetColor.textMuted)
                .minimumScaleFactor(0.68)
            }
        }
    }

    @ViewBuilder
    private func elapsedText(for activity: RecentCareActivity) -> some View {
        if let lastDate = activity.lastDate {
            TimelineView(.periodic(from: .now, by: 60)) { context in
                Text(
                    CareRecencyTimeFormatter.compactText(
                        since: lastDate,
                        relativeTo: context.date
                    )
                )
                .monospacedDigit()
            }
        } else {
            Text("暂无")
        }
    }

    private func activityRow(_ activity: RecentCareActivity) -> some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(activity.kind.accentColor)
                .frame(width: 4)

            activityIcon(activity.kind, size: 34)
                .frame(width: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text(activity.kind.fullTitle.localized)
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(WidgetColor.textMuted)
                    .lineLimit(1)
                elapsedText(for: activity)
                    .font(.system(size: 25, weight: .heavy, design: .rounded))
                    .foregroundStyle(activity.kind.textColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Text(activity.detail.localized)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(WidgetColor.textStrong)
                    .lineLimit(1)
                Text(clockText(for: activity))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(WidgetColor.textMuted)
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
                        .stroke(WidgetColor.glassStroke.opacity(0.88), lineWidth: 1.2)
                )
                .shadow(color: activity.kind.accentColor.opacity(0.08), radius: 12, y: 6)
        )
    }

    private func activityIcon(_ kind: RecentCareActivityKind, size: CGFloat) -> some View {
        Image(kind.imageResource)
            .resizable()
            .scaledToFit()
            .frame(width: size * 1.18, height: size * 1.18)
            .shadow(color: kind.textColor.opacity(0.18), radius: 5, y: 2)
            .padding(max(size * 0.18, 5))
            .background(
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                WidgetColor.surfaceRaised.opacity(0.96),
                                kind.softColor.opacity(0.90)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        Circle()
                            .stroke(kind.accentColor.opacity(0.34), lineWidth: 1.2)
                    )
            )
    }

    private func tileFill(for kind: RecentCareActivityKind) -> LinearGradient {
        LinearGradient(
            colors: [
                kind.softColor.opacity(0.96),
                WidgetColor.surface.opacity(0.74)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
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
    let usesHorizontalLayout: Bool

    static let small = ActivityTileStyle(
        padding: EdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 5),
        iconSize: 12,
        titleSize: 8,
        valueSize: 10,
        spacing: 2,
        cornerRadius: 15,
        valueLines: 1,
        showsDetail: false,
        usesCompactElapsedText: true,
        usesHorizontalLayout: true
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
        usesCompactElapsedText: true,
        usesHorizontalLayout: false
    )

    static let large = ActivityTileStyle(
        padding: EdgeInsets(top: 11, leading: 12, bottom: 11, trailing: 10),
        iconSize: 24,
        titleSize: 12,
        valueSize: 20,
        spacing: 5,
        cornerRadius: 24,
        valueLines: 1,
        showsDetail: true,
        usesCompactElapsedText: false,
        usesHorizontalLayout: false
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
                        WidgetColor.surface.opacity(0.92),
                        WidgetColor.surfaceSoft.opacity(0.84),
                        WidgetColor.canvas.opacity(0.78)
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
                    .fill(WidgetColor.yearningSoft.opacity(0.72))
                    .frame(width: 96, height: 96)
                    .blur(radius: 18)
                    .offset(x: 28, y: -34)
            }
            .overlay(alignment: .bottomLeading) {
                Circle()
                    .fill(WidgetColor.eatSoft.opacity(0.78))
                    .frame(width: 118, height: 118)
                    .blur(radius: 22)
                    .offset(x: -34, y: 34)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(WidgetColor.glassStroke.opacity(0.82), lineWidth: 1.2)
            )
            .shadow(color: WidgetColor.sleep.opacity(0.12), radius: 18, y: 9)
    }
}

struct FeedingLiveActivity: Widget {
    private let liveActivityTint = WidgetColor.primary

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FeedingActivityAttributes.self) { context in
            LockScreenView(state: context.state)
                .activityBackgroundTint(WidgetColor.surface)
                .activitySystemActionForegroundColor(liveActivityTint)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(
                        context.state.activeTiming.hasActiveTiming ? "记录中" : "最近照护",
                        systemImage: context.state.activeTiming.hasActiveTiming ? "timer" : "heart.text.square.fill"
                    )
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(liveActivityTint)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    latestClock(snapshot: context.state.snapshot)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if context.state.activeTiming.hasActiveTiming {
                        HStack(spacing: 6) {
                            ForEach(context.state.activeTiming.items) { item in
                                DynamicTimingChip(item: item)
                            }
                        }
                    } else {
                        HStack(spacing: 6) {
                            ForEach(CareRecencyKind.allCases) { kind in
                                DynamicCareChip(item: context.state.snapshot.item(for: kind))
                            }
                        }
                    }
                }
            } compactLeading: {
                if let item = context.state.activeTiming.items.first {
                    Image(systemName: item.kind == .sleep ? "moon.zzz.fill" : "timer")
                        .foregroundStyle(item.kind == .sleep ? WidgetColor.sleep : WidgetColor.eat)
                } else {
                    CompactCareIcon(item: context.state.snapshot.mostRecentItem)
                }
            } compactTrailing: {
                if let item = context.state.activeTiming.items.first {
                    Text(timerInterval: item.startedAt...Date.distantFuture, countsDown: false)
                        .monospacedDigit()
                        .font(.caption2.weight(.bold))
                } else {
                    CompactCareTimer(item: context.state.snapshot.mostRecentItem)
                }
            } minimal: {
                if let item = context.state.activeTiming.items.first {
                    Image(systemName: item.kind == .sleep ? "moon.zzz.fill" : "timer")
                } else {
                    CompactCareIcon(item: context.state.snapshot.mostRecentItem)
                }
            }
            .keylineTint(liveActivityTint)
        }
    }

    @ViewBuilder
    private func latestClock(snapshot: CareRecencySnapshot) -> some View {
        if let date = snapshot.mostRecentItem?.completedAt {
            Text(twentyFourHourClockText(date))
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(.secondary)
        } else {
            Text("BBBuddy")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
}

struct LockScreenView: View {
    let state: FeedingActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Label("BBBuddy", systemImage: "heart.text.square.fill")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(WidgetColor.textStrong)
                Spacer(minLength: 8)
                Text("最近照护")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WidgetColor.textMuted)
            }


            if state.activeTiming.hasActiveTiming {
                VStack(spacing: 6) {
                    ForEach(state.activeTiming.items) { item in
                        ActiveTimingLockRow(item: item)
                    }
                }
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 2),
                spacing: 7
            ) {
                ForEach(CareRecencyKind.allCases) { kind in
                    LockScreenCareTile(item: state.snapshot.item(for: kind))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            WidgetColor.surfaceRaised,
                            WidgetColor.surfaceSoft
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(WidgetColor.glassStroke.opacity(0.86), lineWidth: 1)
                )
        }
    }
}

private struct ActiveTimingLockRow: View {
    let item: ActiveTimingItem

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: item.kind == .sleep ? "moon.zzz.fill" : "timer")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(WidgetColor.onPrimary)
                .frame(width: 26, height: 26)
                .background(Circle().fill(accent))

            VStack(alignment: .leading, spacing: 1) {
                Text("\(item.kind.title) 记录中")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(WidgetColor.textStrong)
                Text(item.startedAt, format: .dateTime.hour().minute())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(WidgetColor.textMuted)
            }

            Spacer(minLength: 6)

            Text(timerInterval: item.startedAt...Date.distantFuture, countsDown: false)
                .font(.caption.monospacedDigit().weight(.bold))
                .foregroundStyle(accent)
        }
        .padding(.horizontal, 9)
        .frame(height: 40)
        .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(accent.opacity(0.09)))
    }

    private var accent: Color {
        item.kind == .sleep ? WidgetColor.sleep : WidgetColor.eat
    }
}

private struct DynamicTimingChip: View {
    let item: ActiveTimingItem

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: item.kind == .sleep ? "moon.zzz.fill" : "timer")
            Text(item.kind.title.localized)
            Text(timerInterval: item.startedAt...Date.distantFuture, countsDown: false)
                .monospacedDigit()
        }
        .font(.caption2.weight(.bold))
        .foregroundStyle(WidgetColor.onPrimary)
        .padding(.horizontal, 8)
        .frame(height: 28)
        .background(Capsule().fill(accent.opacity(0.92)))
    }

    private var accent: Color {
        item.kind == .sleep ? WidgetColor.sleep : WidgetColor.eat
    }
}

private struct LockScreenCareTile: View {
    let item: CareRecencyItem

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(item.kind.fullTitle.localized)
                        .font(.system(size: 9, weight: .semibold))
                    if let date = item.completedAt {
                        Text(twentyFourHourClockText(date))
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                    } else {
                        Text("--:--")
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
                .foregroundStyle(item.kind.liveTextColor.opacity(0.82))

                ViewThatFits(in: .horizontal) {
                    Text(item.completedAt == nil ? "暂无记录" : item.lockScreenDetailText)
                        .fixedSize(horizontal: true, vertical: false)
                    Text(item.completedAt == nil ? "暂无" : item.lockScreenFallbackDetailText)
                        .fixedSize(horizontal: true, vertical: false)
                }
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(item.kind.liveTextColor)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ViewThatFits(in: .horizontal) {
                primaryElapsedText(size: 22)
                primaryElapsedText(size: 19)
            }
            .layoutPriority(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(item.kind.liveSoftColor.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(item.kind.liveAccentColor.opacity(0.16), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
    }

    private func primaryElapsedText(size: CGFloat) -> some View {
        LockScreenPrimaryElapsedText(date: item.completedAt, emptyText: "--")
            .font(.system(size: size, weight: .heavy, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(item.kind.liveTextColor)
            .fixedSize(horizontal: true, vertical: false)
    }
}

private struct LockScreenPrimaryElapsedText: View {
    let date: Date?
    let emptyText: String

    @ViewBuilder
    var body: some View {
        if let date {
            TimelineView(.periodic(from: .now, by: 60)) { context in
                Text(
                    CareRecencyTimeFormatter.lockScreenPrimaryText(
                        since: date,
                        relativeTo: context.date,
                        emptyText: emptyText
                    )
                )
            }
        } else {
            Text(emptyText)
        }
    }
}

private struct DynamicCareChip: View {
    let item: CareRecencyItem

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: item.kind.systemImage)
                .font(.system(size: 11, weight: .bold))
            LiveCompactElapsedText(date: item.completedAt, emptyText: "--")
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .foregroundStyle(item.kind.liveTextColor)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(item.kind.liveSoftColor.opacity(0.88))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.kind.fullTitle)
    }
}

private struct CompactCareIcon: View {
    let item: CareRecencyItem?

    var body: some View {
        let kind = item?.kind ?? .feeding
        Image(systemName: kind.systemImage)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(kind.liveAccentColor)
            .accessibilityLabel(kind.fullTitle)
    }
}

private struct CompactCareTimer: View {
    let item: CareRecencyItem?

    @ViewBuilder
    var body: some View {
        LiveCompactElapsedText(date: item?.completedAt, emptyText: "--")
            .font(.system(size: 11, weight: .heavy, design: .rounded))
            .monospacedDigit()
            .frame(maxWidth: 48)
            .foregroundStyle(item?.kind.liveAccentColor ?? WidgetColor.primary)
    }
}

private struct LiveCompactElapsedText: View {
    let date: Date?
    let emptyText: String

    @ViewBuilder
    var body: some View {
        if let date {
            TimelineView(.periodic(from: .now, by: 60)) { context in
                Text(
                    CareRecencyTimeFormatter.liveCompactText(
                        since: date,
                        relativeTo: context.date,
                        emptyText: emptyText
                    )
                )
            }
        } else {
            Text(emptyText)
        }
    }
}

private extension CareRecencyKind {
    var liveAccentColor: Color {
        switch self {
        case .feeding: return WidgetColor.eat
        case .pee, .poop: return WidgetColor.diaper
        case .sleep: return WidgetColor.sleep
        }
    }

    var liveSoftColor: Color {
        switch self {
        case .feeding: return WidgetColor.eatSoft
        case .pee, .poop: return WidgetColor.diaperSoft
        case .sleep: return WidgetColor.sleepSoft
        }
    }

    var liveTextColor: Color {
        switch self {
        case .feeding: return WidgetColor.eatText
        case .pee, .poop: return WidgetColor.diaperText
        case .sleep: return WidgetColor.sleepText
        }
    }
}

private extension CareRecencyItem {
    var lockScreenDetailText: String {
        switch kind {
        case .feeding:
            return compactDuration(detail)
        case .pee:
            if detail.contains("一点") || detail.contains("少量") || detail.contains("尿量少") {
                return "少量"
            }
            if detail.contains("很多") || detail.contains("大量") || detail.contains("尿量多") {
                return "大量"
            }
            if detail.contains("不少") || detail.contains("中量") || detail.contains("尿量中") {
                return "中量"
            }
            return detail
        case .poop:
            return detail
        case .sleep:
            return compactDuration(detail.replacingOccurrences(of: " · ", with: " "))
        }
    }

    private func compactDuration(_ text: String) -> String {
        text
            .replacingOccurrences(of: "小时", with: "h")
            .replacingOccurrences(of: "分钟", with: "m")
            .replacingOccurrences(of: "分", with: "m")
    }

    var lockScreenFallbackDetailText: String {
        switch kind {
        case .feeding: return "已喂养"
        case .pee, .poop: return "已记录"
        case .sleep: return "已睡眠"
        }
    }
}

private func twentyFourHourClockText(_ date: Date) -> String {
    let components = Calendar.autoupdatingCurrent.dateComponents([.hour, .minute], from: date)
    return String(format: "%02d:%02d", components.hour ?? 0, components.minute ?? 0)
}
