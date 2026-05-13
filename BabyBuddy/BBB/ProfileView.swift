import SwiftUI

struct ProfileView: View {
    @Binding var showBabyInfo: Bool

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                BabyInfoHeaderView()
                    .onTapGesture { showBabyInfo = true }

                profileSummaryCard
                menuCard
                Spacer(minLength: 112)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 112)
        }
        .background(DesignToken.background.ignoresSafeArea())
    }

    private var profileSummaryCard: some View {
        HStack(spacing: 12) {
            summaryPill(icon: "calendar", title: "成长", value: "持续记录")
            summaryPill(icon: "heart.fill", title: "健康", value: "每日护理")
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(.white))
    }

    private func summaryPill(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(DesignToken.primary)
                .frame(width: 32, height: 32)
                .background(Circle().fill(DesignToken.primary.opacity(0.13)))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DesignToken.textSecondary)
                Text(value)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(DesignToken.textPrimary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    private var menuCard: some View {
        VStack(spacing: 0) {
            menu(icon: "heart.text.square.fill", color: DesignToken.primary, title: "健康记录", subtitle: "喂养 · 尿布 · 睡眠")
            line
            menu(icon: "chart.bar.fill", color: Color(hex: "#9ABAF2"), title: "统计报告", subtitle: "查看成长趋势")
            line
            menu(icon: "gearshape.fill", color: Color(hex: "#7F8098"), title: "设置", subtitle: "通知 · 数据 · 偏好")
            line
            menu(icon: "info.circle.fill", color: Color(hex: "#7F8098"), title: "关于 BabyBuddy", subtitle: "版本与帮助")
        }
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(.white))
    }

    private var line: some View {
        Rectangle().fill(DesignToken.line.opacity(0.65)).frame(height: 1).padding(.leading, 70)
    }

    private func menu(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(color.opacity(0.12))
                .frame(width: 46, height: 46)
                .overlay(Image(systemName: icon).font(.system(size: 20, weight: .semibold)).foregroundStyle(color))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(DesignToken.textPrimary)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(DesignToken.textSecondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color(hex: "#E1DFEA"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}

struct BabyInfoHeaderView: View {
    @Environment(BabyProfileStore.self) private var profileStore

    var body: some View {
        let profile = profileStore.currentProfile

        VStack(spacing: 16) {
            HStack(spacing: 14) {
                Circle()
                    .fill(Color(hex: "#F4ECF7"))
                    .frame(width: 72, height: 72)
                    .overlay(Text(profile.gender.emoji).font(.system(size: 38)))
                    .overlay(Circle().stroke(Color(hex: "#E5BED7"), lineWidth: 2))
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(profile.name)
                            .font(.system(size: 32, weight: .heavy, design: .rounded))
                            .foregroundStyle(DesignToken.textPrimary)
                        Image(systemName: "triangle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(DesignToken.primary)
                    }
                    HStack(spacing: 8) {
                        label(icon: "clock.badge.checkmark", text: profile.ageDisplayText)
                        label(icon: "figure.stand", text: profile.gender.rawValue)
                    }
                }
                Spacer()
            }
            HStack(spacing: 10) {
                filterButton("All")
                filterButton("Today")
                Spacer()
                Circle().fill(.white).frame(width: 44, height: 44)
                    .overlay(Image(systemName: "list.bullet").font(.system(size: 18, weight: .bold)).foregroundStyle(Color(hex: "#E5BED7")))
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(.white))
    }

    private func label(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(DesignToken.textSecondary)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color(hex: "#F6F4FA")))
    }

    private func filterButton(_ title: String) -> some View {
        HStack(spacing: 8) {
            Text(title)
            Image(systemName: "chevron.down")
        }
        .font(.subheadline.weight(.bold))
        .foregroundStyle(DesignToken.textPrimary)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule().fill(Color(hex: "#F0DEEB")))
    }
}
