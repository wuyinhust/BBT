import Foundation

// MARK: - Baby Age Tier

enum BabyAgeTier: Equatable {
    case newborn   // 0-3 months
    case infant    // 4-12 months
    case toddler   // 13-36 months

    var displayName: String {
        switch self {
        case .newborn: return "新生宝宝 (0-3月)"
        case .infant:  return "宝宝 (4-12月)"
        case .toddler: return "宝宝 (1-3岁)"
        }
    }

    static func from(months: Int) -> Self {
        if months <= 3 { return .newborn }
        if months <= 12 { return .infant }
        return .toddler
    }

    static func from(birthDate: Date, now: Date = Date()) -> Self {
        let months = Calendar.current.dateComponents([.month], from: birthDate, to: now).month ?? 6
        return from(months: max(0, months))
    }
}

// MARK: - Rhythm Signal Models

struct RhythmStability {
    let feedingIntervalVariance: Double
    let sleepSegmentVariance: Double
    let nightWakeCount: Int

    /// 0 = very unstable, 1 = very stable
    var score: Double {
        let feedingScore = max(0, 1 - feedingIntervalVariance / 4.0)
        let sleepScore   = max(0, 1 - sleepSegmentVariance / 3600.0)
        let wakeScore    = max(0, 1 - Double(nightWakeCount) / 5.0)
        return (feedingScore * 0.35 + sleepScore * 0.35 + wakeScore * 0.3).clamped(to: 0...1)
    }
}

struct DayNightPhase {
    let longestSleepStartHour: Double
    let lastFeedingHour: Double
    let eveningActivityDensity: Double
    let currentHour: Double

    var isNightTarget: Bool { currentHour >= 19 || currentHour < 6 }
    var isNapTarget: Bool   { currentHour >= 11 && currentHour < 15 }
}

struct CareLoad {
    let feedingCount: Int
    let diaperCount: Int
    let totalAwakeMinutes: Int

    /// 0 = low load, 1 = very high load
    var score: Double {
        let feedingScore = min(Double(feedingCount) / 12.0, 1.0)
        let diaperScore  = min(Double(diaperCount) / 15.0, 1.0)
        let awakeScore   = min(Double(totalAwakeMinutes) / 720.0, 1.0)
        return (feedingScore * 0.35 + diaperScore * 0.15 + awakeScore * 0.5).clamped(to: 0...1)
    }
}

// MARK: - Combined Inputs

struct RhythmInputs {
    let ageTier: BabyAgeTier
    let stability: RhythmStability
    let dayNight: DayNightPhase
    let careLoad: CareLoad
    let weekWeight: Double
    let dayWeight: Double

    /// 场景分类
    var scenario: PlaybackScenario {
        if dayNight.isNightTarget { return .nightSleep }
        if dayNight.isNapTarget   { return .nap }
        if careLoad.score > 0.65 || stability.score < 0.35 { return .fussy }
        return .calm
    }

    /// Fallback 用于无数据时
    static let weeklyDefault = RhythmInputs(
        ageTier: .infant,
        stability: RhythmStability(feedingIntervalVariance: 1.2, sleepSegmentVariance: 1200, nightWakeCount: 2),
        dayNight: DayNightPhase(longestSleepStartHour: 21, lastFeedingHour: 20, eveningActivityDensity: 0.5, currentHour: 21),
        careLoad: CareLoad(feedingCount: 8, diaperCount: 8, totalAwakeMinutes: 620),
        weekWeight: 0.7, dayWeight: 0.3
    )
}

// MARK: - Playback Scenario

enum PlaybackScenario: String, CaseIterable {
    case nightSleep = "night_sleep"
    case nap        = "nap"
    case fussy      = "fussy"
    case calm       = "calm"

    var label: String {
        switch self {
        case .nightSleep: return "夜间安眠"
        case .nap:        return "白天小睡"
        case .fussy:      return "安抚舒缓"
        case .calm:       return "平静陪伴"
        }
    }
}

// MARK: - Rhythm Preset (Template)

struct RhythmPreset {
    let name: String
    let description: String
    let ageTier: BabyAgeTier
    let scenario: PlaybackScenario

    let baseBpm: Int
    let noiseRatios: (white: Double, pink: Double, brown: Double)
    let noiseLevel: Double
    let melodyVolume: Double
    let melodyComplexity: Double
    let highFreqAttenuation: Double
    let dynamicRange: Double
    let segmentRatios: (intro: Double, settling: Double, sustain: Double)

    /// 12 预设，覆盖 3 年龄层 × 4 场景
    static let all: [RhythmPreset] = [
        // ── 0-3 月 新生宝宝 ──
        RhythmPreset(
            name: "子宫模拟", description: "模拟宫内环境，棕噪+低频振动",
            ageTier: .newborn, scenario: .nightSleep,
            baseBpm: 65, noiseRatios: (0.08, 0.22, 0.70), noiseLevel: 0.12,
            melodyVolume: 0.02, melodyComplexity: 0.05, highFreqAttenuation: 0.85,
            dynamicRange: 0.4, segmentRatios: (0.30, 0.40, 0.30)
        ),
        RhythmPreset(
            name: "轻柔摇篮", description: "粉噪为主+极简旋律",
            ageTier: .newborn, scenario: .calm,
            baseBpm: 60, noiseRatios: (0.12, 0.68, 0.20), noiseLevel: 0.09,
            melodyVolume: 0.04, melodyComplexity: 0.12, highFreqAttenuation: 0.70,
            dynamicRange: 0.5, segmentRatios: (0.20, 0.35, 0.45)
        ),
        RhythmPreset(
            name: "昼夜节律引导", description: "白天稍活跃/夜间更安抚",
            ageTier: .newborn, scenario: .nap,
            baseBpm: 70, noiseRatios: (0.15, 0.65, 0.20), noiseLevel: 0.08,
            melodyVolume: 0.06, melodyComplexity: 0.18, highFreqAttenuation: 0.60,
            dynamicRange: 0.55, segmentRatios: (0.15, 0.30, 0.55)
        ),
        RhythmPreset(
            name: "深度安抚", description: "高白噪掩蔽，应对哭闹",
            ageTier: .newborn, scenario: .fussy,
            baseBpm: 72, noiseRatios: (0.55, 0.30, 0.15), noiseLevel: 0.15,
            melodyVolume: 0.01, melodyComplexity: 0.03, highFreqAttenuation: 0.60,
            dynamicRange: 0.35, segmentRatios: (0.40, 0.35, 0.25)
        ),

        // ── 4-12 月 宝宝 ──
        RhythmPreset(
            name: "安稳入睡", description: "均衡噪色+轻柔旋律，助眠过渡",
            ageTier: .infant, scenario: .nightSleep,
            baseBpm: 58, noiseRatios: (0.15, 0.50, 0.35), noiseLevel: 0.10,
            melodyVolume: 0.06, melodyComplexity: 0.20, highFreqAttenuation: 0.65,
            dynamicRange: 0.45, segmentRatios: (0.25, 0.40, 0.35)
        ),
        RhythmPreset(
            name: "夜醒安抚", description: "快速重建睡眠，短引入+高掩蔽",
            ageTier: .infant, scenario: .fussy,
            baseBpm: 62, noiseRatios: (0.35, 0.40, 0.25), noiseLevel: 0.14,
            melodyVolume: 0.04, melodyComplexity: 0.10, highFreqAttenuation: 0.55,
            dynamicRange: 0.40, segmentRatios: (0.45, 0.30, 0.25)
        ),
        RhythmPreset(
            name: "白天小睡", description: "轻粉噪+旋律，短周期",
            ageTier: .infant, scenario: .nap,
            baseBpm: 66, noiseRatios: (0.10, 0.70, 0.20), noiseLevel: 0.07,
            melodyVolume: 0.08, melodyComplexity: 0.25, highFreqAttenuation: 0.55,
            dynamicRange: 0.55, segmentRatios: (0.12, 0.28, 0.60)
        ),
        RhythmPreset(
            name: "出牙安抚", description: "高白噪+低复杂度，麻痹不适感",
            ageTier: .infant, scenario: .fussy,
            baseBpm: 64, noiseRatios: (0.60, 0.30, 0.10), noiseLevel: 0.16,
            melodyVolume: 0.02, melodyComplexity: 0.06, highFreqAttenuation: 0.50,
            dynamicRange: 0.35, segmentRatios: (0.35, 0.35, 0.30)
        ),

        // ── 1-3 岁 宝宝 ──
        RhythmPreset(
            name: "睡前故事配乐", description: "更多旋律，更少噪，更长引入",
            ageTier: .toddler, scenario: .nightSleep,
            baseBpm: 55, noiseRatios: (0.05, 0.55, 0.40), noiseLevel: 0.07,
            melodyVolume: 0.12, melodyComplexity: 0.45, highFreqAttenuation: 0.45,
            dynamicRange: 0.60, segmentRatios: (0.35, 0.35, 0.30)
        ),
        RhythmPreset(
            name: "午睡时光", description: "轻粉噪+欢快旋律",
            ageTier: .toddler, scenario: .nap,
            baseBpm: 62, noiseRatios: (0.08, 0.72, 0.20), noiseLevel: 0.06,
            melodyVolume: 0.10, melodyComplexity: 0.40, highFreqAttenuation: 0.40,
            dynamicRange: 0.65, segmentRatios: (0.10, 0.25, 0.65)
        ),
        RhythmPreset(
            name: "夜间安眠", description: "棕噪主导+深沉旋律，长时稳定",
            ageTier: .toddler, scenario: .nightSleep,
            baseBpm: 52, noiseRatios: (0.05, 0.25, 0.70), noiseLevel: 0.08,
            melodyVolume: 0.09, melodyComplexity: 0.35, highFreqAttenuation: 0.50,
            dynamicRange: 0.50, segmentRatios: (0.25, 0.40, 0.35)
        ),
        RhythmPreset(
            name: "过度刺激日", description: "极简白噪，最小刺激",
            ageTier: .toddler, scenario: .fussy,
            baseBpm: 56, noiseRatios: (0.50, 0.35, 0.15), noiseLevel: 0.11,
            melodyVolume: 0.03, melodyComplexity: 0.08, highFreqAttenuation: 0.55,
            dynamicRange: 0.35, segmentRatios: (0.30, 0.35, 0.35)
        ),
    ]

    /// 按年龄+场景查找预设
    static func find(ageTier: BabyAgeTier, scenario: PlaybackScenario) -> RhythmPreset {
        all.first { $0.ageTier == ageTier && $0.scenario == scenario }
            ?? all.first { $0.ageTier == ageTier }
            ?? all.first { $0.scenario == scenario }
            ?? all[5] // 默认 fallback："安稳入睡"
    }
}

// MARK: - Final Audio Parameters

struct RhythmParameters: Sendable {
    let bpm: Int
    let whiteRatio: Double; let pinkRatio: Double; let brownRatio: Double
    let noiseLevel: Double
    let melodyVolume: Double
    let melodyComplexity: Double
    let highFreqAttenuation: Double
    let dynamicRange: Double
    let introSec: TimeInterval; let settlingSec: TimeInterval; let sustainSec: TimeInterval
    let totalLoopSec: TimeInterval

    let presetName: String
    let scenarioLabel: String
    let ageLabel: String

    /// 单次最大连续播放（秒）
    var maxContinuousPlaySec: TimeInterval {
        switch scenarioLabel {
        case "夜间安眠": return 3600  // 1h
        case "白天小睡": return 2700  // 45min
        default:         return 1800  // 30min
        }
    }
}

// MARK: - Parameter Mapper

enum RhythmParameterMapper {

    /// 从信号+预设计算最终音频参数
    static func derive(from inputs: RhythmInputs) -> RhythmParameters {
        let preset = RhythmPreset.find(ageTier: inputs.ageTier, scenario: inputs.scenario)
        let stability = inputs.stability.score
        let load      = inputs.careLoad.score

        // 当天波动大 → 加宽周权重 → 更稳定
        let effectiveWeekWeight: Double
        if stability < 0.3 { effectiveWeekWeight = 0.85 }
        else if stability < 0.5 { effectiveWeekWeight = 0.7 }
        else { effectiveWeekWeight = inputs.weekWeight }

        let effectiveDayWeight = 1.0 - effectiveWeekWeight

        // BPM 微调 (±3)
        let bpmDelta = (load - 0.5) * 6 * effectiveDayWeight
        let bpm = max(40, min(80, Int(round(Double(preset.baseBpm) + bpmDelta))))

        // 噪色配比：负载高 → 更多白噪，稳定 → 更多棕/粉噪
        let wAdj = preset.noiseRatios.white  + load * 0.12 * effectiveDayWeight
        let pAdj = preset.noiseRatios.pink   - load * 0.04 * effectiveDayWeight
        let bAdj = preset.noiseRatios.brown  - load * 0.08 * effectiveDayWeight
        let sum  = max(wAdj + pAdj + bAdj, 0.01)
        let wR = (wAdj / sum).clamped(to: 0...1)
        let pR = (pAdj / sum).clamped(to: 0...1)
        let bR = (bAdj / sum).clamped(to: 0...1)

        // 噪声音量：负载↑ → 噪声↑
        let noiseLvl = (preset.noiseLevel + load * 0.02 * effectiveDayWeight).clamped(to: 0.03...0.18)

        // 旋律：稳定↑ → 旋律丰富↑，负载↑ → 旋律↓
        let melVol = (preset.melodyVolume * (0.6 + stability * 0.4) * (1.0 - load * 0.3)).clamped(to: 0...0.18)
        let melCpx = (preset.melodyComplexity * (0.5 + stability * 0.5) * (1.0 - load * 0.35)).clamped(to: 0...0.55)

        // 高频衰减：负载↑ → 更多衰减
        let hfAtt = (preset.highFreqAttenuation + load * 0.1 * effectiveDayWeight).clamped(to: 0.3...0.9)

        // 动态范围：稳定↑ → 动态更大
        let dynR = (preset.dynamicRange * (0.7 + stability * 0.3)).clamped(to: 0.3...0.7)

        // 段时长（目标总循环约 180 秒）
        let targetTotal = 180.0
        let introSec    = round(preset.segmentRatios.intro * targetTotal)
        let settlingSec = round(preset.segmentRatios.settling * targetTotal)
        let sustainSec  = targetTotal - introSec - settlingSec

        // 当天特别不稳定 → 缩短引入段
        let adjustedIntro = stability < 0.35 ? max(18, introSec * 0.6) : introSec

        return RhythmParameters(
            bpm: bpm,
            whiteRatio: wR, pinkRatio: pR, brownRatio: bR,
            noiseLevel: noiseLvl,
            melodyVolume: melVol,
            melodyComplexity: melCpx,
            highFreqAttenuation: hfAtt,
            dynamicRange: dynR,
            introSec: adjustedIntro, settlingSec: settlingSec, sustainSec: sustainSec,
            totalLoopSec: targetTotal,
            presetName: preset.name,
            scenarioLabel: inputs.scenario.label,
            ageLabel: inputs.ageTier.displayName
        )
    }

    /// 从周快照 + 当天数据 + 宝宝生日计算 inputs
    static func extractInputs(
        weekSnapshot: WeeklyRhythmSnapshot,
        todaySessions: [FeedingSession],
        todayCare: [CareRecord],
        birthDate: Date?,
        now: Date = Date()
    ) -> RhythmInputs {
        let ageTier: BabyAgeTier = birthDate.map { BabyAgeTier.from(birthDate: $0, now: now) } ?? .infant
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: now)
        let todayEnd   = calendar.date(byAdding: .day, value: 1, to: todayStart)!

        let daySessions = todaySessions.filter { $0.createdAt >= todayStart && $0.createdAt < todayEnd }
        let dayCare     = todayCare.filter { $0.recordedAt >= todayStart && $0.recordedAt < todayEnd }

        let feedingTimes = daySessions.map(\.createdAt).sorted()
        let intervals: [Double] = zip(feedingTimes, feedingTimes.dropFirst()).map { a, b in
            b.timeIntervalSince(a) / 3600
        }.filter { $0 > 0 }
        let avgInt = intervals.isEmpty ? 0 : intervals.reduce(0, +) / Double(intervals.count)
        let varInt = intervals.isEmpty ? 0 : intervals.map { pow($0 - avgInt, 2) }.reduce(0, +) / Double(intervals.count)

        let sleepRecords    = dayCare.filter { $0.kind == .sleep }
        let sleepDurations  = sleepRecords.compactMap { SleepRecordFormatter.durationMinutes(from: $0.detail) }
        let avgSleep        = sleepDurations.isEmpty ? 0 : Double(sleepDurations.reduce(0, +)) / Double(sleepDurations.count)
        let varSleep        = sleepDurations.isEmpty ? 0 : sleepDurations.map { pow(Double($0) - avgSleep, 2) }.reduce(0, +) / Double(sleepDurations.count)

        let nightWakeCount  = sleepRecords.filter { rec in
            let h = calendar.component(.hour, from: rec.recordedAt)
            return h >= 22 || h < 5
        }.count

        let diaperCount  = dayCare.filter { $0.kind == .diaper }.count
        let totalAwake   = max(0, 24 * 60 - sleepDurations.reduce(0, +))

        let longestSleep  = sleepRecords.max(by: {
            (SleepRecordFormatter.durationMinutes(from: $0.detail) ?? 0)
            < (SleepRecordFormatter.durationMinutes(from: $1.detail) ?? 0)
        })
        let sleepStartHour: Double = longestSleep.map {
            Double(calendar.component(.hour, from: $0.recordedAt))
                + Double(calendar.component(.minute, from: $0.recordedAt)) / 60
        } ?? 21

        let lastFeeding = feedingTimes.last
        let feedHour: Double = lastFeeding.map {
            Double(calendar.component(.hour, from: $0))
                + Double(calendar.component(.minute, from: $0)) / 60
        } ?? 20

        let eveningActivity = dayCare.filter { rec in
            let h = calendar.component(.hour, from: rec.recordedAt)
            return h >= 17 && h < 20
        }.count

        let hourOfDay = Double(calendar.component(.hour, from: now))
            + Double(calendar.component(.minute, from: now)) / 60

        let weekStability = RhythmStability(
            feedingIntervalVariance: max(0.1, pow(weekSnapshot.averageFeedingIntervalHours > 0
                ? max(0.5, 4 - weekSnapshot.averageFeedingIntervalHours) : 2, 2)),
            sleepSegmentVariance: max(100, pow(Double(max(60, weekSnapshot.totalSleepMinutes)) / 7.0, 2)),
            nightWakeCount: max(1, weekSnapshot.sleepRecordCount / 7)
        )

        let dayStability = RhythmStability(
            feedingIntervalVariance: max(0.05, varInt),
            sleepSegmentVariance: max(50, varSleep),
            nightWakeCount: nightWakeCount
        )

        let blendedStability = RhythmStability(
            feedingIntervalVariance: weekStability.feedingIntervalVariance * 0.7 + dayStability.feedingIntervalVariance * 0.3,
            sleepSegmentVariance: weekStability.sleepSegmentVariance * 0.7 + dayStability.sleepSegmentVariance * 0.3,
            nightWakeCount: Int(round(Double(weekStability.nightWakeCount) * 0.7 + Double(dayStability.nightWakeCount) * 0.3))
        )

        return RhythmInputs(
            ageTier: ageTier,
            stability: blendedStability,
            dayNight: DayNightPhase(
                longestSleepStartHour: sleepStartHour,
                lastFeedingHour: feedHour,
                eveningActivityDensity: min(Double(eveningActivity) / 6.0, 1.0),
                currentHour: hourOfDay
            ),
            careLoad: CareLoad(
                feedingCount: daySessions.count,
                diaperCount: diaperCount,
                totalAwakeMinutes: totalAwake
            ),
            weekWeight: 0.7,
            dayWeight: 0.3
        )
    }
}

// MARK: - Convenience

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
