import Foundation
import AVFoundation

struct WeeklyRhythmSnapshot {
    let weekStart: Date
    let weekEnd: Date
    let feedingCount: Int
    let diaperCount: Int
    let sleepRecordCount: Int
    let totalSleepMinutes: Int
    let averageFeedingIntervalHours: Double

    var title: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        return "自然周节奏曲 · \(formatter.string(from: weekStart))-\(formatter.string(from: weekEnd))"
    }

    var description: String {
        let avgIntervalText = averageFeedingIntervalHours > 0
            ? String(format: "%.1f", averageFeedingIntervalHours)
            : "--"
        let sleepHours = Double(totalSleepMinutes) / 60.0
        return "这周共记录喂养\(feedingCount)次、尿布\(diaperCount)次、睡眠\(sleepRecordCount)段（约\(String(format: "%.1f", sleepHours))小时）。我们把喂养间隔（均值\(avgIntervalText)小时）映射为主旋律起伏，把尿布频次映射为轻打击点，把睡眠总量映射为底噪与和声密度，所以你听到的是‘熟悉且稳定、带少量变化’的本周节奏。"
    }
}

enum WeeklyRhythmAnalyzer {
    static func snapshot(referenceDate: Date, sessions: [FeedingSession], careRecords: [CareRecord]) -> WeeklyRhythmSnapshot {
        let calendar = Calendar.current
        let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: referenceDate)?.start ?? calendar.startOfDay(for: referenceDate)
        let weekStart = calendar.date(byAdding: .day, value: -7, to: currentWeekStart) ?? currentWeekStart
        let weekEndExclusive = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? currentWeekStart
        let weekEnd = calendar.date(byAdding: .second, value: -1, to: weekEndExclusive) ?? weekEndExclusive

        let weekSessions = sessions.filter { $0.createdAt >= weekStart && $0.createdAt < weekEndExclusive }
        let weekCare = careRecords.filter { $0.recordedAt >= weekStart && $0.recordedAt < weekEndExclusive }

        let feedingTimes = weekSessions.map(\.createdAt).sorted()
        let intervals: [Double] = zip(feedingTimes, feedingTimes.dropFirst()).map { lhs, rhs in
            rhs.timeIntervalSince(lhs) / 3600
        }.filter { $0 > 0 }
        let avgInterval = intervals.isEmpty ? 0 : intervals.reduce(0, +) / Double(intervals.count)

        let diaperCount = weekCare.filter { $0.kind == .diaper }.count
        let sleepRecords = weekCare.filter { $0.kind == .sleep }
        let sleepMinutes = sleepRecords.reduce(0) { partial, record in
            partial + (SleepRecordFormatter.durationMinutes(from: record.detail) ?? 0)
        }

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
}

@MainActor
final class WeeklyRhythmPlayer: ObservableObject {
    @Published var isPlaying = false

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()

    init() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: nil)
    }

    func togglePlay(snapshot: WeeklyRhythmSnapshot) {
        isPlaying ? stop() : play(snapshot: snapshot)
    }

    func stop() {
        player.stop()
        engine.stop()
        isPlaying = false
    }

    private func play(snapshot: WeeklyRhythmSnapshot) {
        do {
            if !engine.isRunning {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                try AVAudioSession.sharedInstance().setActive(true)
                try engine.start()
            }
            let buffer = makeBuffer(snapshot: snapshot)
            player.scheduleBuffer(buffer, at: nil, options: .loops)
            player.play()
            isPlaying = true
        } catch {
            isPlaying = false
        }
    }

    private func makeBuffer(snapshot: WeeklyRhythmSnapshot) -> AVAudioPCMBuffer {
        let sampleRate = 44_100.0
        let duration: Double = 24
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        let left = buffer.floatChannelData![0]
        let right = buffer.floatChannelData![1]

        let baseFreq = Float(max(180, 320 - snapshot.feedingCount * 2))
        let sleepFactor = Float(min(max(Double(snapshot.totalSleepMinutes) / 600.0, 0.4), 1.4))
        let noiseLevel = Float(min(max(Double(snapshot.diaperCount) / 80.0, 0.03), 0.15))
        let pulseStride = max(1, Int(frameCount) / max(snapshot.diaperCount, 1))

        var phase: Float = 0
        var noiseSeed: UInt64 = 0x12345678ABCDEF
        let twoPi = Float.pi * 2

        for frame in 0..<Int(frameCount) {
            let t = Float(frame) / Float(sampleRate)
            let section = sinf(twoPi * t / 8)
            let freq = baseFreq + section * 24
            phase += twoPi * freq / Float(sampleRate)

            noiseSeed = noiseSeed &* 6364136223846793005 &+ 1
            let rand = Float((noiseSeed >> 33) & 0xFFFF) / Float(0xFFFF)
            let whiteNoise = (rand * 2 - 1) * noiseLevel

            let pulse: Float = (frame % pulseStride < 180) ? 0.06 : 0
            let tone = sinf(phase) * 0.08 * sleepFactor
            let pad = sinf(phase * 0.5) * 0.05
            let sample = max(min(tone + pad + whiteNoise + pulse, 0.4), -0.4)

            left[frame] = sample
            right[frame] = sample * 0.98
        }

        return buffer
    }
}
