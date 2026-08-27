import SwiftUI

struct WeeklyRhythmPlayerView: View {
    @EnvironmentObject private var feedingStore: FeedingStore
    @EnvironmentObject private var activityStore: ActivityStore
    @StateObject private var engine = BabyAudioEngine()

    @AppStorage("safety_onboarding_completed") private var onboardingCompleted = false
    @State private var showOnboarding = false
    @State private var hasCheckedOnboarding = false

    // MARK: - Computed Playback Inputs

    private var snapshot: WeeklyRhythmSnapshot {
        WeeklyRhythmAnalyzer.snapshot(
            referenceDate: Date(),
            sessions: feedingStore.sessions,
            careRecords: activityStore.exportCareRecords()
        )
    }

    private var rhythmParams: RhythmParameters {
        let birthDate = BabyProfileStore.shared.profile?.birthDate
        let inputs = WeeklyRhythmAnalyzer.rhythmInputs(
            weekSnapshot: snapshot,
            sessions: feedingStore.sessions,
            careRecords: activityStore.exportCareRecords(),
            birthDate: birthDate
        )
        return RhythmParameterMapper.derive(from: inputs)
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerSection
                playSection
                if engine.isPlaying { safetyStatusSection }
                noiseMixSection
                statsSection
                descriptionSection
                safetyTipSection
            }
            .padding(DesignToken.compactHorizontalPadding)
        }
        .background(DesignToken.background.ignoresSafeArea())
        .navigationTitle("节奏音乐")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !hasCheckedOnboarding {
                hasCheckedOnboarding = true
                if !onboardingCompleted { showOnboarding = true }
            }
        }
        .onDisappear { engine.stop() }
        .sheet(isPresented: $showOnboarding) {
            SafetyOnboardingView()
        }
        .alert("播放异常", isPresented: Binding(
            get: { engine.errorMessage != nil },
            set: { if !$0 { engine.errorMessage = nil } }
        )) {
            Button("好的") { engine.errorMessage = nil }
        } message: {
            Text(engine.errorMessage ?? "")
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(snapshot.title.localized)
                .font(BBBFont.font(size: 21, weight: .bold))
                .foregroundStyle(DesignToken.textPrimary)
            HStack(spacing: 8) {
                Text(rhythmParams.ageLabel)
                    .font(BBBFont.font(size: 12, weight: .semibold))
                    .foregroundStyle(DesignToken.onPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(DesignToken.primary))
                Text(rhythmParams.scenarioLabel)
                    .font(BBBFont.font(size: 12, weight: .semibold))
                    .foregroundStyle(DesignToken.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(DesignToken.primarySoft.opacity(0.72)))
            }
        }
    }

    // MARK: - Play Button

    private var playSection: some View {
        VStack(spacing: 10) {
            Button {
                engine.toggle(with: rhythmParams)
            } label: {
                HStack(spacing: 10) {
                    if engine.isPreparing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: engine.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 18, weight: .bold))
                    }
                    Text(playButtonLabel)
                        .font(BBBFont.font(size: 16, weight: .bold))
                }
                .foregroundStyle(DesignToken.onPrimary)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 50)
                .background(Capsule().fill(DesignToken.primaryGradient))
            }
            .buttonStyle(ScaleButtonStyle())

            Text(rhythmParams.presetName)
                .font(BBBFont.font(size: 12, weight: .medium))
                .foregroundStyle(DesignToken.textSecondary)
        }
    }

    private var playButtonLabel: String {
        if engine.isPreparing { return "取消音频准备" }
        if engine.isPlaying { return "暂停 · \(rhythmParams.presetName)" }
        return "播放 · \(rhythmParams.presetName)"
    }

    // MARK: - Safety Status Bar

    private var safetyStatusSection: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            SafetyStatusBar(
                elapsedSec: engine.elapsed(at: context.date),
                maxSec: rhythmParams.maxContinuousPlaySec,
                presetName: rhythmParams.presetName,
                noiseRatios: (rhythmParams.whiteRatio, rhythmParams.pinkRatio, rhythmParams.brownRatio)
            )
        }
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.easeInOut(duration: 0.3), value: engine.isPlaying)
    }

    // MARK: - Noise Mix Visualization

    private var noiseMixSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("噪色配比")
                .font(BBBFont.font(size: 13, weight: .bold))
                .foregroundStyle(DesignToken.textPrimary)

            VStack(spacing: 8) {
                noiseBar(
                    label: "白噪", ratio: rhythmParams.whiteRatio,
                    color: DesignToken.grayNeutral,
                    desc: "均匀掩蔽，适合出牙/哭闹"
                )
                noiseBar(
                    label: "粉噪", ratio: rhythmParams.pinkRatio,
                    color: DesignToken.easyActivitySoft,
                    desc: "类似风雨声，自然安抚"
                )
                noiseBar(
                    label: "棕噪", ratio: rhythmParams.brownRatio,
                    color: DesignToken.rewardSoft,
                    desc: "低沉浑厚，模拟宫内环境"
                )
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(DesignToken.surfaceRaised.opacity(0.9))
            )
        }
    }

    private func noiseBar(label: String, ratio: Double, color: Color, desc: String) -> some View {
        HStack(spacing: 8) {
            Text(label.localized)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 26, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(DesignToken.grayNeutral)
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(ratio))
                }
            }
            .frame(height: 5)

            Text(String(format: "%.0f%%", ratio * 100))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(DesignToken.textSecondary)
                .frame(width: 34, alignment: .trailing)

            Text(desc)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(DesignToken.textSecondary.opacity(0.6))
                .lineLimit(1)
        }
    }

    // MARK: - Stats

    private var statsSection: some View {
        HStack(spacing: 10) {
            statPill(title: "本周喂养", value: "\(snapshot.feedingCount)次", color: DesignToken.easyEat)
            statPill(title: "本周尿布", value: "\(snapshot.diaperCount)次", color: DesignToken.activityDiaper)
            statPill(title: "本周睡眠", value: String(format: "%.1f小时", Double(snapshot.totalSleepMinutes) / 60.0), color: DesignToken.easySleep)
        }
    }

    private func statPill(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(title.localized)
                .font(BBBFont.font(size: 12, weight: .semibold))
                .foregroundStyle(DesignToken.textSecondary)
            Text(value.localized)
                .font(BBBFont.font(size: 14, weight: .bold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(DesignToken.surface)
        )
    }

    // MARK: - Description

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("当前节奏解读")
                .font(BBBFont.font(size: 16, weight: .bold))
                .foregroundStyle(DesignToken.textPrimary)
            Text(snapshot.description.localized)
                .font(BBBFont.font(size: 14, weight: .medium))
                .foregroundStyle(DesignToken.textSecondary)
                .lineSpacing(4)
            Text(audioParamSummary)
                .font(BBBFont.font(size: 12, weight: .medium))
                .foregroundStyle(DesignToken.textSecondary.opacity(0.7))
                .lineSpacing(3)
                .padding(.top, 4)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(DesignToken.surfaceRaised.opacity(0.94))
        )
    }

    private var audioParamSummary: String {
        """
        BPM: \(rhythmParams.bpm) · 旋律复杂度: \(String(format: "%.0f%%", rhythmParams.melodyComplexity * 100)) · 高频率减: \(String(format: "%.0f%%", rhythmParams.highFreqAttenuation * 100))
        段结构: 引入\(Int(rhythmParams.introSec))秒 → 过渡\(Int(rhythmParams.settlingSec))秒 → 维持\(Int(rhythmParams.sustainSec))秒（循环）
        安全上限: 最多连续播放 \(Int(rhythmParams.maxContinuousPlaySec / 60)) 分钟后自动暂停
        """
    }

    // MARK: - Safety Tip

    private var safetyTipSection: some View {
        SafetyTipFooter()
    }

}
