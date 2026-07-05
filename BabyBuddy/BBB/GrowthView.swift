import SwiftUI

struct MyPageView: View {
    @Environment(BabyProfileStore.self) private var profileStore
    @EnvironmentObject private var stickerStore: AchievementStickerStore
    @EnvironmentObject private var growthMetricStore: GrowthMetricStore
    @EnvironmentObject private var recruitmentStore: CompanionRecruitmentStore

    private let openMetricSheet: ((GrowthMetricKind) -> Void)?

    init(
        initialTab: MyPageTab = .badge,
        showsProfileHeader: Bool = true,
        visibleTabs: [MyPageTab] = [.badge],
        openMetricSheet: ((GrowthMetricKind) -> Void)? = nil
    ) {
        self.openMetricSheet = openMetricSheet
    }

    var body: some View {
        GeometryReader { _ in
            ZStack {
                HomeSoftBackground()

                VStack(spacing: 14) {
                    growthTopBar
                        .padding(.top, 8)

                    BabyAchievementsView(showsHeader: false, isEmbedded: true)
                        .environmentObject(stickerStore)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 0)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var profile: BabyProfileData {
        profileStore.currentProfile
    }

    private var growthTopBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                BabyProfileAvatarView(
                    profile: profile,
                    size: 40,
                    emojiSize: 19,
                    lineWidth: 2,
                    motionScale: 0.65
                )

                Text(profile.name)
                    .font(BBBFont.font(size: 17, weight: .heavy))
                    .foregroundStyle(DesignToken.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.70)
            }
            .frame(minWidth: 84, maxWidth: .infinity, alignment: .leading)

            metricChip(kind: .height, value: heightText)
            metricChip(kind: .weight, value: weightText)
            bucksChip
            settingsEntry
        }
        .padding(.horizontal, 10)
        .frame(height: 58)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white.opacity(0.88))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(.white.opacity(0.9), lineWidth: 1)
                )
                .shadow(color: Color(hex: "#4D4B70").opacity(0.06), radius: 14, y: 6)
        )
    }

    @ViewBuilder
    private func metricChip(kind: GrowthMetricKind, value: String) -> some View {
        if let openMetricSheet {
            Button {
                openMetricSheet(kind)
            } label: {
                metricChipContent(icon: kind.icon, value: value, tint: kind.accent)
            }
            .buttonStyle(ScaleButtonStyle())
        } else {
            metricChipContent(icon: kind.icon, value: value, tint: kind.accent)
        }
    }

    private func metricChipContent(icon: String, value: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(tint)
            Text(value.replacingOccurrences(of: " ", with: ""))
                .font(BBBFont.font(size: 11, weight: .heavy))
                .foregroundStyle(DesignToken.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
        }
        .padding(.horizontal, 8)
        .frame(height: 34)
        .background(Capsule(style: .continuous).fill(Color(hex: "#F4F1FA")))
    }

    private var bucksChip: some View {
        HStack(spacing: 4) {
            Image(systemName: "hexagon.fill")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(Color(hex: "#42C8F5"))
            Text("\(recruitmentStore.bbBucks)")
                .font(BBBFont.font(size: 12, weight: .heavy))
                .foregroundStyle(Color(hex: "#26AEE8"))
                .lineLimit(1)
                .minimumScaleFactor(0.70)
        }
        .padding(.horizontal, 8)
        .frame(height: 34)
        .background(Capsule(style: .continuous).fill(Color(hex: "#EDF8FF")))
        .accessibilityLabel("BBBUCKS \(recruitmentStore.bbBucks)")
    }

    private var settingsEntry: some View {
        NavigationLink {
            ProfileView(showBabyInfo: .constant(false))
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(DesignToken.primary)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color(hex: "#F3EEFF")))
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("设置与账号")
    }

    private var heightText: String {
        metricText(growthMetricStore.latest(kind: .height)?.value ?? profile.heightCm, unit: "cm")
    }

    private var weightText: String {
        metricText(growthMetricStore.latest(kind: .weight)?.value ?? profile.weightKg, unit: "kg")
    }

    private func metricText(_ value: Double?, unit: String) -> String {
        guard let value else {
            return "-- \(unit)"
        }
        let numberText = value.rounded() == value ? String(Int(value)) : String(format: "%.1f", value)
        return "\(numberText) \(unit)"
    }
}

enum MyPageTab: String, CaseIterable, Identifiable {
    case calendar
    case badge

    var id: String { rawValue }

    var title: String {
        switch self {
        case .calendar: return "日历"
        case .badge: return "徽章"
        }
    }
}
