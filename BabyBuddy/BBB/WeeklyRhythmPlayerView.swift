import SwiftUI

struct WeeklyRhythmPlayerView: View {
    @EnvironmentObject private var feedingStore: FeedingStore
    @EnvironmentObject private var activityStore: ActivityStore
    @StateObject private var player = WeeklyRhythmPlayer()

    private var snapshot: WeeklyRhythmSnapshot {
        WeeklyRhythmAnalyzer.snapshot(
            referenceDate: Date(),
            sessions: feedingStore.sessions,
            careRecords: activityStore.exportCareRecords()
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(snapshot.title)
                        .font(BBBFont.font(size: 22, weight: .heavy))
                        .foregroundStyle(DesignToken.textPrimary)
                    Text("基于上一个自然周的喂养、尿布和睡眠节奏生成")
                        .font(BBBFont.font(size: 13, weight: .semibold))
                        .foregroundStyle(DesignToken.textSecondary)
                }

                Button {
                    player.togglePlay(snapshot: snapshot)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 18, weight: .bold))
                        Text(player.isPlaying ? "暂停本周节奏曲" : "播放本周节奏曲")
                            .font(BBBFont.font(size: 16, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(DesignToken.primaryGradient))
                }
                .buttonStyle(ScaleButtonStyle())

                rhythmStats

                VStack(alignment: .leading, spacing: 10) {
                    Text("曲子介绍")
                        .font(BBBFont.font(size: 16, weight: .bold))
                        .foregroundStyle(DesignToken.textPrimary)
                    Text(snapshot.description)
                        .font(BBBFont.font(size: 14, weight: .medium))
                        .foregroundStyle(DesignToken.textSecondary)
                        .lineSpacing(4)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.white.opacity(0.94))
                )
            }
            .padding(16)
        }
        .background(DesignToken.background.ignoresSafeArea())
        .navigationTitle("本周节奏曲")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { player.stop() }
    }

    private var rhythmStats: some View {
        HStack(spacing: 10) {
            statPill(title: "喂养", value: "\(snapshot.feedingCount)次", color: Color(hex: "#BDA6F2"))
            statPill(title: "尿布", value: "\(snapshot.diaperCount)次", color: Color(hex: "#D6A95C"))
            statPill(title: "睡眠", value: "\(snapshot.sleepRecordCount)段", color: Color(hex: "#A5C8FF"))
        }
    }

    private func statPill(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(BBBFont.font(size: 12, weight: .semibold))
                .foregroundStyle(DesignToken.textSecondary)
            Text(value)
                .font(BBBFont.font(size: 14, weight: .bold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white)
        )
    }
}
