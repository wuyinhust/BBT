import Foundation

// MARK: - Weekly Rhythm Snapshot (data model, unchanged)

struct WeeklyRhythmSnapshot {
    let weekStart: Date
    let weekEnd: Date
    let feedingCount: Int
    let diaperCount: Int
    let sleepRecordCount: Int
    let totalSleepMinutes: Int
    let averageFeedingIntervalHours: Double

    private static let titleFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M月d日"
        return f
    }()

    var title: String {
        "本周节奏曲 · \(Self.titleFormatter.string(from: weekStart))-\(Self.titleFormatter.string(from: weekEnd))"
    }

    var description: String {
        let avgText = averageFeedingIntervalHours > 0
            ? String(format: "%.1f", averageFeedingIntervalHours) : "--"
        let sleepH = Double(totalSleepMinutes) / 60.0
        return "这周共记录喂养\(feedingCount)次、尿布\(diaperCount)次、睡眠\(sleepRecordCount)段（约\(String(format: "%.1f", sleepH))小时）。"
            + "喂养间隔（均值\(avgText)小时）映射为主旋律起伏，尿布频次映射为轻打击点，"
            + "睡眠总量映射为底噪与和声密度——你听到的是「熟悉且稳定、带少量变化」的本周节奏。"
    }
}

// MARK: - Weekly Rhythm Analyzer

enum WeeklyRhythmAnalyzer {
    static func snapshot(
        referenceDate: Date,
        sessions: [FeedingSession],
        careRecords: [CareRecord]
    ) -> WeeklyRhythmSnapshot {
        let calendar = Calendar.current
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: referenceDate)?.start
            ?? calendar.startOfDay(for: referenceDate)
        let weekEndExclusive = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
        let weekEnd = calendar.date(byAdding: .second, value: -1, to: weekEndExclusive) ?? weekEndExclusive

        let weekSessions = sessions.filter { $0.createdAt >= weekStart && $0.createdAt < weekEndExclusive }
        let weekCare     = careRecords.filter { $0.recordedAt >= weekStart && $0.recordedAt < weekEndExclusive }

        let feedingTimes = weekSessions.map(\.createdAt).sorted()
        let intervals: [Double] = zip(feedingTimes, feedingTimes.dropFirst()).map { a, b in
            b.timeIntervalSince(a) / 3600
        }.filter { $0 > 0 }
        let avgInterval = intervals.isEmpty ? 0 : intervals.reduce(0, +) / Double(intervals.count)

        let diaperCount  = weekCare.filter { $0.kind == .diaper }.count
        let sleepRecords = weekCare.filter { $0.kind == .sleep }
        let sleepMinutes = sleepRecords.reduce(0) { $0 + (SleepRecordFormatter.durationMinutes(from: $1.detail) ?? 0) }

        return WeeklyRhythmSnapshot(
            weekStart: weekStart,
            weekEnd: weekEnd,
            feedingCount: weekSessions.count,
            diaperCount: diaperCount,
            sleepRecordCount: sleepRecords.count,
            totalSleepMinutes: sleepMinutes,
            averageFeedingIntervalHours: avgInterval
        )
    }

    /// 便捷方法：从 store 直接生成 RhythmInputs（供音频引擎使用）
    static func rhythmInputs(
        weekSnapshot: WeeklyRhythmSnapshot,
        sessions: [FeedingSession],
        careRecords: [CareRecord],
        birthDate: Date?,
        now: Date = Date()
    ) -> RhythmInputs {
        RhythmParameterMapper.extractInputs(
            weekSnapshot: weekSnapshot,
            todaySessions: sessions,
            todayCare: careRecords,
            birthDate: birthDate,
            now: now
        )
    }
}
