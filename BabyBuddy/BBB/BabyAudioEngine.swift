import Foundation
import AVFoundation

// MARK: - Fast PRNG for Audio Thread

private struct FastRNG {
    var seed: UInt64
    init(seed: UInt64) { self.seed = seed }
    mutating func next() -> Float {
        seed = seed &* 6364136223846793005 &+ 1
        return Float((seed >> 33) & 0xFFFF) / Float(0xFFFF)
    }
}

// MARK: - Noise Generators

private struct WhiteNoiseGen {
    private var rng: FastRNG
    init(seed: UInt64) { rng = FastRNG(seed: seed) }
    mutating func next() -> Float { rng.next() * 2 - 1 }
}

private struct PinkNoiseGen {
    private var rows: [Float] = [0, 0, 0, 0, 0, 0, 0]
    private var runningSum: Float = 0
    private var idx: Int = 0
    private var white: WhiteNoiseGen
    init(seed: UInt64) { white = WhiteNoiseGen(seed: seed) }
    mutating func next() -> Float {
        let prev = idx
        idx = (idx + 1) % 7
        runningSum -= rows[prev]
        rows[prev] = white.next()
        runningSum += rows[prev]
        return runningSum / 2.8
    }
}

private struct BrownNoiseGen {
    private var state: Float = 0
    private var white: WhiteNoiseGen
    init(seed: UInt64) { white = WhiteNoiseGen(seed: seed) }
    mutating func next() -> Float {
        state = (state + white.next() * 0.02) * 0.995
        return state.clamped(to: -1...1)
    }
}

// MARK: - Melody Generator (Pentatonic)

private struct MelodyGen {
    private var phase: Float = 0
    private var notePhase: Float = 0
    private var noteIdx: Int = 0
    private let noteFreqs: [Float]
    private let sampleRate: Float
    private let complexity: Float
    private let notesPerCycle: Int = 8

    init(bpm: Int, complexity: Double, sampleRate: Float) {
        self.sampleRate = sampleRate
        self.complexity = Float(complexity)
        let base = Float(bpm) / 60.0 * 27.5 // BPM → Hz
        let ratios: [Float] = [1.0, 9.0/8.0, 5.0/4.0, 3.0/2.0, 5.0/3.0, 2.0, 9.0/4.0, 5.0/2.0]
        self.noteFreqs = Array(ratios.prefix(notesPerCycle)).map { base * $0 }
    }

    mutating func next() -> Float {
        let noteLen: Float = sampleRate * 4.5
        notePhase += 1
        if notePhase >= noteLen {
            notePhase = 0
            noteIdx = (noteIdx + 1) % noteFreqs.count
        }
        let freq = noteFreqs[noteIdx]
        phase += 2 * .pi * freq / sampleRate
        let fund  = sinf(phase)
        let harm1 = sinf(phase * 2) * 0.12 * complexity
        let harm2 = sinf(phase * 3) * 0.05 * complexity
        let trem  = 1.0 + sinf(notePhase / sampleRate * 0.55) * 0.06
        return (fund + harm1 + harm2) * trem / 1.25
    }
}

// MARK: - Single-Pole Low-Pass Filter

private struct LowPass {
    private var prev: Float = 0
    let alpha: Float
    init(cutoff: Float, sampleRate: Float) {
        let rc = 1.0 / (2 * .pi * cutoff)
        let dt = 1.0 / sampleRate
        alpha = dt / (rc + dt)
    }
    mutating func filter(_ input: Float) -> Float {
        prev = prev + alpha * (input - prev)
        return prev
    }
}

// MARK: - Safety Config

struct SafetyConfig {
    /// 输出幅度硬上限
    static let maxAmplitude: Float = 0.40
    /// 自适应安全上限（播放器中随场景可微调）
    static let adaptiveAmplitude: Float = 0.35
    /// 建议距宝宝床距离（cm）
    static let recommendedDistanceCm: Double = 200
    /// 最高连续播放（秒），超过自动暂停
    static let absoluteMaxContinuousSec: TimeInterval = 3600

    /// 医学定位文案
    static let medicalDisclaimer = "本功能定位为「睡眠环境与安抚辅助」，不是医疗器械，不宣称治疗。请将设备放在距宝宝床至少 2 米处，保持低音量，并避免长时间连续播放。若宝宝异常哭闹，请及时就医。"
}

// MARK: - Baby Audio Engine

@MainActor
final class BabyAudioEngine: ObservableObject {
    @Published var isPlaying = false
    @Published var elapsedSec: TimeInterval = 0
    @Published var currentPresetName: String = ""
    @Published var errorMessage: String?

    private var engine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?

    private var currentParams: RhythmParameters?
    private var bufferSeed: UInt64 = 0
    private var elapsedTimer: Timer?

    private let sampleRate: Float = 22_050
    private var bufferDuration: TimeInterval { currentParams?.totalLoopSec ?? 90 }

    init() {
        // Lazy initialization — engine is created only when play() is first called
    }

    // MARK: - Playback

    func play(with params: RhythmParameters) {
        stop()

        // Lazy engine initialization
        if engine == nil {
            let newEngine = AVAudioEngine()
            let newPlayerNode = AVAudioPlayerNode()
            newEngine.attach(newPlayerNode)
            newEngine.connect(newPlayerNode, to: newEngine.mainMixerNode, format: nil)
            engine = newEngine
            playerNode = newPlayerNode
        }

        guard let engine = engine, let playerNode = playerNode else { return }

        currentParams = params
        currentPresetName = params.presetName
        bufferSeed = UInt64(Date().timeIntervalSince1970 * 1000) & 0x7FFFFFFFFFFF

        errorMessage = nil
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            try engine.start()
        } catch {
            isPlaying = false
            errorMessage = "无法启动音频引擎：\(error.localizedDescription)"
            NSLog("[BabyAudioEngine] Playback error: \(error)")
            return
        }

        let buffer = generateBuffer(params: params, seed: bufferSeed)
        playerNode.scheduleBuffer(buffer, at: nil, options: .loops)
        playerNode.play()
        isPlaying = true
        elapsedSec = 0

        startElapsedTimer(params: params)
    }

    func stop() {
        playerNode?.stop()
        engine?.stop()
        isPlaying = false
        elapsedTimer?.invalidate()
        elapsedTimer = nil
    }

    func toggle(with params: RhythmParameters) {
        isPlaying ? stop() : play(with: params)
    }

    // MARK: - Elapsed Timer

    private func startElapsedTimer(params: RhythmParameters) {
        elapsedTimer?.invalidate()
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                guard self.isPlaying else { return }
                self.elapsedSec += 0.5
                if self.elapsedSec >= params.maxContinuousPlaySec {
                    self.stop()
                }
            }
        }
    }

    // MARK: - Buffer Generation

    private func generateBuffer(params: RhythmParameters, seed: UInt64) -> AVAudioPCMBuffer {
        let frameCount = AVAudioFrameCount(sampleRate * Float(params.totalLoopSec))
        let format = AVAudioFormat(standardFormatWithSampleRate: Double(sampleRate), channels: 2)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        let left  = buffer.floatChannelData![0]
        let right = buffer.floatChannelData![1]

        let totalFrames = Int(frameCount)
        let introFrames    = Int(sampleRate * Float(params.introSec))
        let settlingFrames = Int(sampleRate * Float(params.settlingSec))

        var whiteGen  = WhiteNoiseGen(seed: seed)
        var pinkGen   = PinkNoiseGen(seed: seed &+ 1)
        var brownGen  = BrownNoiseGen(seed: seed &+ 2)
        var melodyGen = MelodyGen(bpm: params.bpm, complexity: params.melodyComplexity, sampleRate: sampleRate)
        var hfFilter  = LowPass(cutoff: mapHFAttenuation(params.highFreqAttenuation), sampleRate: sampleRate)

        let wRatio = Float(params.whiteRatio)
        let pRatio = Float(params.pinkRatio)
        let bRatio = Float(params.brownRatio)
        let noiseLvl = Float(params.noiseLevel)
        let melVol   = Float(params.melodyVolume)
        let dynRange = Float(params.dynamicRange)

        for frame in 0..<totalFrames {
            let segmentPhase = segmentProgress(frame: frame, introFrames: introFrames, settlingFrames: settlingFrames)

            // Blended noise
            let noise = whiteGen.next() * wRatio + pinkGen.next() * pRatio + brownGen.next() * bRatio
            let filteredNoise = hfFilter.filter(noise) * noiseLvl

            // Melody
            let melody = melodyGen.next() * melVol

            // Segment envelope: intro fades in noise, settling shifts, sustain holds
            let envNoise  = noiseEnvelope(segmentPhase)
            let envMelody = melodyEnvelope(segmentPhase, complexity: params.melodyComplexity)

            var sample = filteredNoise * envNoise + melody * envMelody

            // Dynamic range compression
            sample *= dynRange

            // Hard safety clamp
            sample = max(min(sample, SafetyConfig.maxAmplitude), -SafetyConfig.maxAmplitude)

            left[frame]  = sample
            right[frame] = sample * 0.97
        }

        return buffer
    }

    // MARK: - Segment Helpers

    private func segmentProgress(frame: Int, introFrames: Int, settlingFrames: Int) -> Float {
        if frame < introFrames {
            return 0.0 + 1.0 * Float(frame) / Float(introFrames) // 0→1 over intro
        } else if frame < introFrames + settlingFrames {
            return 1.0 + 1.0 * Float(frame - introFrames) / Float(settlingFrames) // 1→2 over settling
        } else {
            return 2.0 // sustain
        }
    }

    private func noiseEnvelope(_ phase: Float) -> Float {
        if phase < 1.0 {
            // Intro: ramp noise from 70% → 100%
            return 0.7 + 0.3 * phase
        } else if phase < 2.0 {
            // Settling: ramp noise from 100% → 80%
            return 1.0 - 0.2 * (phase - 1.0)
        } else {
            // Sustain: hold at 80%
            return 0.8
        }
    }

    private func melodyEnvelope(_ phase: Float, complexity: Double) -> Float {
        let melGain: Float = Float(0.4 + complexity * 0.6) // complexity越高,旋律越突出
        if phase < 0.3 {
            return melGain * (phase / 0.3) * 0.4
        } else if phase < 1.0 {
            return melGain * (0.4 + 0.6 * (phase - 0.3) / 0.7)
        } else if phase < 2.0 {
            return melGain
        } else {
            return melGain
        }
    }

    private func mapHFAttenuation(_ att: Double) -> Float {
        // att 0.3 → cutoff ~12000 Hz, att 0.9 → cutoff ~800 Hz
        let minHz: Float = 600
        let maxHz: Float = 11000
        return maxHz - Float(att) * (maxHz - minHz)
    }
}

private extension Float {
    func clamped(to r: ClosedRange<Float>) -> Float {
        min(max(self, r.lowerBound), r.upperBound)
    }
}
