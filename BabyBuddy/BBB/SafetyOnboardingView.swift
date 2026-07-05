import SwiftUI

// MARK: - Safety Onboarding View

struct SafetyOnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("safety_onboarding_completed") private var onboardingCompleted = false

    @State private var currentPage = 0
    private let totalPages = 4

    var body: some View {
        ZStack {
            DesignToken.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Page indicator
                pageDots
                    .padding(.top, 24)

                // Content
                TabView(selection: $currentPage) {
                    page0.tag(0)
                    page1.tag(1)
                    page2.tag(2)
                    page3.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Action
                bottomButton
                    .padding(.horizontal, 20)
                    .padding(.bottom, 34)
            }
        }
    }

    // MARK: - Page Dots

    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalPages, id: \.self) { i in
                Capsule()
                    .fill(currentPage == i ? DesignToken.primary : DesignToken.grayNeutral)
                    .frame(width: currentPage == i ? 20 : 6, height: 6)
                    .animation(.spring(response: 0.3), value: currentPage)
            }
        }
        .padding(.bottom, 32)
    }

    // MARK: - Pages

    private var page0: some View {
        onboardCard(
            icon: "ear.and.waveform",
            title: "声音安全",
            subtitle: "为宝宝打造的音频空间",
            body: "本功能定位为「睡眠环境与安抚辅助」，不是医疗器械，不宣称治疗效果。\n\n每次播放都经过自动安全限制，确保音量和频率在宝宝安全范围内。",
            color: Color(hex: "#BDA6F2")
        )
    }

    private var page1: some View {
        onboardCard(
            icon: "speaker.wave.1",
            title: "低音量 · 远距离",
            subtitle: "两个关键安全准则",
            body: "• 请将设备音量控制在较低水平\n• 设备应放置在距宝宝床至少 2 米处\n• 播放器已内置振幅上限，无需担心突发高音\n\n2014年《Pediatrics》研究指出：宝宝睡眠机在近距离高音量下可能达到危险声压水平。",
            color: Color(hex: "#A5C8FF")
        )
    }

    private var page2: some View {
        onboardCard(
            icon: "timer",
            title: "适度使用",
            subtitle: "不是整晚播放",
            body: "• 夜间最长连续播放 60 分钟\n• 白天小睡最长 45 分钟\n• 达到上限后自动暂停\n• 如需继续，手动再次播放即可\n\nWHO 建议卧室夜间保持低噪环境。连续播放时间过长并不利于宝宝建立自主入睡能力。",
            color: Color(hex: "#FFD4A8")
        )
    }

    private var page3: some View {
        onboardCard(
            icon: "heart.text.square",
            title: "家长须知",
            subtitle: "音乐辅助 ≠ 替代监护",
            body: "• 播放期间仍需保持对宝宝的关注\n• 若宝宝异常哭闹不止，请暂停播放并及时就医\n• 白噪音安抚效果因人而异，请观察宝宝反应\n• 如出现不适，立刻停止使用\n\n让音乐成为睡眠环境的一部分，而不是唯一的安抚工具。",
            color: Color(hex: "#F4C7D9")
        )
    }

    private func onboardCard(icon: String, title: String, subtitle: String, body: String, color: Color) -> some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(color)
                .padding(.bottom, 20)

            Text(title)
                .font(BBBFont.font(size: 26, weight: .heavy))
                .foregroundStyle(DesignToken.textPrimary)
                .padding(.bottom, 6)

            Text(subtitle)
                .font(BBBFont.font(size: 15, weight: .semibold))
                .foregroundStyle(color)

            Text(body)
                .font(BBBFont.font(size: 14, weight: .medium))
                .foregroundStyle(DesignToken.textSecondary)
                .multilineTextAlignment(.leading)
                .lineSpacing(5)
                .padding(.horizontal, 28)
                .padding(.top, 24)

            Spacer()
            Spacer()
        }
    }

    // MARK: - Bottom Button

    private var bottomButton: some View {
        Button {
            if currentPage < totalPages - 1 {
                withAnimation { currentPage += 1 }
            } else {
                onboardingCompleted = true
                dismiss()
            }
        } label: {
            Text(currentPage < totalPages - 1 ? "继续" : "我知道了")
                .font(BBBFont.font(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Capsule().fill(DesignToken.primaryGradient))
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Safety Status Bar (used in player view)

struct SafetyStatusBar: View {
    let elapsedSec: TimeInterval
    let maxSec: TimeInterval
    let presetName: String
    let noiseRatios: (white: Double, pink: Double, brown: Double)

    private var remainingPercent: Double {
        guard maxSec > 0 else { return 1 }
        return max(0, 1 - elapsedSec / maxSec)
    }

    private var remainingText: String {
        let left = max(0, Int((maxSec - elapsedSec) / 60))
        if left >= 60 { return "超1小时" }
        return "剩\(left)分钟"
    }

    var body: some View {
        VStack(spacing: 10) {
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(DesignToken.grayNeutral)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: remainingPercent > 0.3
                                    ? [Color(hex: "#BDA6F2"), Color(hex: "#A5C8FF")]
                                    : [Color(hex: "#FFB5A0"), Color(hex: "#F4C7D9")],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * remainingPercent)
                }
            }
            .frame(height: 5)

            HStack {
                // Preset name
                Label(presetName, systemImage: "music.note")
                    .font(BBBFont.font(size: 11, weight: .semibold))
                    .foregroundStyle(DesignToken.textSecondary)

                Spacer()

                // Noise ratio indicators
                HStack(spacing: 4) {
                    noiseDot(color: Color(hex: "#E8E8F0"), ratio: noiseRatios.white, label: "白")
                    noiseDot(color: Color(hex: "#F0D0D0"), ratio: noiseRatios.pink, label: "粉")
                    noiseDot(color: Color(hex: "#D0C8B8"), ratio: noiseRatios.brown, label: "棕")
                }

                Spacer()

                // Remaining time
                Text(remainingText)
                    .font(BBBFont.font(size: 11, weight: .bold))
                    .foregroundStyle(remainingPercent > 0.3 ? DesignToken.textSecondary : Color(hex: "#E07060"))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.white.opacity(0.85))
        )
    }

    private func noiseDot(color: Color, ratio: Double, label: String) -> some View {
        HStack(spacing: 2) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
                .opacity(ratio > 0.15 ? 1 : 0.3)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(DesignToken.textSecondary.opacity(ratio > 0.15 ? 1 : 0.4))
        }
    }
}

// MARK: - Safety Tip Footer

struct SafetyTipFooter: View {
    let distanceText: String
    let safetyNote: String

    init(distanceCm: Double = 200) {
        distanceText = "请保持设备距宝宝床至少 \(Int(distanceCm / 100)) 米"
        safetyNote = SafetyConfig.medicalDisclaimer
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 11))
                Text(distanceText)
                    .font(BBBFont.font(size: 11, weight: .semibold))
            }
            .foregroundStyle(Color(hex: "#D6A95C"))

            Text(safetyNote)
                .font(BBBFont.font(size: 10, weight: .medium))
                .foregroundStyle(DesignToken.textSecondary.opacity(0.7))
                .lineSpacing(3)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: "#FFF8E8").opacity(0.6))
        )
    }
}

// MARK: - Preview

#Preview {
    SafetyOnboardingView()
}
