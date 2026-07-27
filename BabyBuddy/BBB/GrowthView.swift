import SwiftUI

struct MyPageView: View {
    @Environment(BabyProfileStore.self) private var profileStore
    @EnvironmentObject private var stickerStore: AchievementStickerStore
    @EnvironmentObject private var growthMetricStore: GrowthMetricStore
    @EnvironmentObject private var recruitmentStore: CompanionRecruitmentStore
    @State private var isBBBucksHistoryPresented = false

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

                VStack(spacing: DesignToken.contentSpacing) {
                    growthTopBar
                        .padding(.top, 10)

                    BabyAchievementsView(showsHeader: false, isEmbedded: true)
                        .environmentObject(stickerStore)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(.horizontal, DesignToken.compactHorizontalPadding)
                .padding(.bottom, 0)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $isBBBucksHistoryPresented) {
            BBBucksHistoryView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private var profile: BabyProfileData {
        profileStore.currentProfile
    }

    private var growthTopBar: some View {
        HStack(spacing: 0) {
            NavigationLink {
                ProfileView()
            } label: {
                BabyProfileAvatarView(
                    profile: profile,
                    size: 34,
                    emojiSize: 16,
                    lineWidth: 1.5,
                    motionScale: 0.65
                )
                .frame(width: 40, height: DesignToken.minimumTapSize)
                .contentShape(Circle())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel("设置与账号")

            Spacer(minLength: 18)

            metricChip(kind: .height, value: heightText)
            Spacer(minLength: 18)
            metricChip(kind: .weight, value: weightText)
            Spacer(minLength: 18)
            bucksChip
        }
        .padding(.horizontal, 6)
        .frame(height: DesignToken.minimumTapSize)
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
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(DesignToken.onPrimary)
                .frame(width: 24, height: 24)
                .background(Circle().fill(tint))
                .overlay(Circle().stroke(DesignToken.onPrimary.opacity(0.72), lineWidth: 1))
                .shadow(color: tint.opacity(0.20), radius: 3, y: 1)
            Text(value.replacingOccurrences(of: " ", with: ""))
                .font(BBBFont.font(size: 13, weight: .heavy))
                .foregroundStyle(DesignToken.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
        }
        .frame(minHeight: DesignToken.minimumTapSize)
        .contentShape(Rectangle())
    }

    private var bucksChip: some View {
        Button {
            isBBBucksHistoryPresented = true
        } label: {
            HStack(spacing: 6) {
                Image("bbbucks_coin")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .shadow(color: DesignToken.reward.opacity(0.18), radius: 3, y: 1)
                Text("\(recruitmentStore.bbBucks)")
                    .font(BBBFont.font(size: 13, weight: .heavy))
                    .foregroundStyle(DesignToken.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.70)
            }
            .frame(minHeight: DesignToken.minimumTapSize)
            .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("BB Bucks \(recruitmentStore.bbBucks)")
        .accessibilityHint("查看获取记录")
    }

    private var heightText: String {
        guard let value = growthMetricStore.latest(kind: .height)?.value ?? profile.heightCm,
              value.isFinite else { return "-- \(AppMeasurementFormat.heightUnit)" }
        return AppMeasurementFormat.height(value)
    }

    private var weightText: String {
        guard let value = growthMetricStore.latest(kind: .weight)?.value ?? profile.weightKg,
              value.isFinite else { return "-- \(AppMeasurementFormat.weightPrimaryUnit)" }
        return AppMeasurementFormat.weight(value)
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
