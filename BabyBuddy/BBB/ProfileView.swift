import SwiftUI

struct ProfileSoftBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: "#FBF9FF"),
                    Color(hex: "#F7F3FF"),
                    Color(hex: "#FFF7FB")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    DesignToken.primary.opacity(0.16),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 24,
                endRadius: 340
            )

            RadialGradient(
                colors: [
                    Color(hex: "#FFD9A8").opacity(0.14),
                    .clear
                ],
                center: .bottomLeading,
                startRadius: 36,
                endRadius: 380
            )
        }
    }
}

private struct SoftProfileCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    let shadowOpacity: Double

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.white.opacity(0.94))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(.white.opacity(0.86), lineWidth: 1.1)
                    )
                    .shadow(color: Color(hex: "#7E5DE8").opacity(shadowOpacity), radius: 14, y: 6)
            )
    }
}

extension View {
    func softProfileCard(cornerRadius: CGFloat, shadowOpacity: Double = 0.06) -> some View {
        modifier(SoftProfileCardModifier(cornerRadius: cornerRadius, shadowOpacity: shadowOpacity))
    }
}

struct ProfileView: View {
    @Binding var showBabyInfo: Bool
    @State private var showFamilySharing = false
    @State private var showLocalBabyInfo = false
    @State private var showYesterdayReports = false
    @State private var showOnboarding = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                Button {
                    showLocalBabyInfo = true
                } label: {
                    BabyInfoHeaderView()
                }
                .buttonStyle(ScaleButtonStyle())

                profileSummaryCard
                menuCard
                Spacer(minLength: 72)
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 88)
        }
        .background(ProfileSoftBackground().ignoresSafeArea())
        .sheet(isPresented: $showFamilySharing) {
            FamilySharingView()
        }
        .sheet(isPresented: $showLocalBabyInfo) {
            BabyInfoEditView(isPresented: $showLocalBabyInfo)
        }
        .sheet(isPresented: $showYesterdayReports) {
            YesterdayReportsArchiveView()
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView(prefillFromProfile: true) {
                showOnboarding = false
            }
        }
    }

    private var profileSummaryCard: some View {
        HStack(spacing: 12) {
            summaryPill(icon: "calendar", title: "成长", value: "持续记录")
            summaryPill(icon: "heart.fill", title: "健康", value: "每日护理")
        }
        .padding(13)
        .softProfileCard(cornerRadius: 20)
    }

    private func summaryPill(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(DesignToken.primary)
                .frame(width: 30, height: 30)
                .background(Circle().fill(DesignToken.primary.opacity(0.13)))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(BBBFont.font(size: 11, weight: .semibold))
                    .foregroundStyle(DesignToken.textSecondary)
                Text(value)
                    .font(BBBFont.font(size: 13, weight: .bold))
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
            Button {
                showYesterdayReports = true
            } label: {
                menu(icon: "sunrise.fill", color: Color(hex: "#F0A35E"), title: "yesterday's", subtitle: "每日节奏与伙伴来访记录")
            }
            .buttonStyle(.plain)
            line
            Button {
                showFamilySharing = true
            } label: {
                menu(icon: "person.2.fill", color: Color(hex: "#67C587"), title: "家庭共享", subtitle: "邀请另一位家长共同记录")
            }
            .buttonStyle(.plain)
            line
            Button {
                showOnboarding = true
            } label: {
                menu(icon: "wand.and.stars", color: DesignToken.primarySoft, title: "气质测试与 Buddy", subtitle: "重新测试 · 自选伙伴")
            }
            .buttonStyle(.plain)
            line
            menu(icon: "gearshape.fill", color: Color(hex: "#7F8098"), title: "设置", subtitle: "通知 · 数据 · 偏好")
            line
            menu(icon: "info.circle.fill", color: Color(hex: "#7F8098"), title: "关于 BabyBuddy", subtitle: "版本与帮助")
        }
        .padding(.vertical, 5)
        .softProfileCard(cornerRadius: 20)
    }

    private var line: some View {
        Rectangle().fill(DesignToken.line.opacity(0.45)).frame(height: 1).padding(.leading, 64)
    }

    private func menu(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(color.opacity(0.12))
                .frame(width: 38, height: 38)
                .overlay(Image(systemName: icon).font(.system(size: 16, weight: .semibold)).foregroundStyle(color))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(BBBFont.font(size: 15, weight: .bold))
                    .foregroundStyle(DesignToken.textPrimary)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(BBBFont.font(size: 12, weight: .medium))
                        .foregroundStyle(DesignToken.textSecondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color(hex: "#E1DFEA"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

struct FamilySharingView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var familyCloudStore: FamilyCloudStore
    @State private var shareController: FamilyCloudShareSheet?
    @State private var errorMessage: String?
    @State private var isPreparingInvite = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    statusCard
                    inviteCard
                    dataCard
                }
                .padding(20)
            }
            .background(ProfileSoftBackground().ignoresSafeArea())
            .navigationTitle("家庭共享")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .task {
                await familyCloudStore.bootstrapIfNeeded()
            }
            .sheet(item: $shareController) { sheet in
                sheet
            }
            .alert("家庭共享暂不可用", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: statusIcon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(statusColor)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(statusColor.opacity(0.14)))

                VStack(alignment: .leading, spacing: 4) {
                    Text(familyCloudStore.state.title)
                        .font(BBBFont.font(size: 15, weight: .bold))
                        .foregroundStyle(DesignToken.textPrimary)
                    Text(familyCloudStore.state.detail)
                        .font(BBBFont.font(size: 12, weight: .medium))
                        .foregroundStyle(DesignToken.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let lastSyncAt = familyCloudStore.lastSyncAt {
                Label("上次同步 \(lastSyncAt.formatted(date: .omitted, time: .shortened))", systemImage: "clock.arrow.circlepath")
                    .font(BBBFont.font(size: 12, weight: .semibold))
                    .foregroundStyle(DesignToken.textSecondary)
            }
        }
        .padding(15)
        .softProfileCard(cornerRadius: 20)
    }

    private var inviteCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("邀请另一位家长")
                .font(BBBFont.font(size: 16, weight: .heavy))
                .foregroundStyle(DesignToken.textPrimary)

            Text("会打开 Apple 的系统分享面板。对方接受后，就能和你一起查看、添加和编辑这个宝宝的记录。")
                .font(BBBFont.font(size: 12, weight: .medium))
                .foregroundStyle(DesignToken.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                prepareInvite()
            } label: {
                HStack {
                    if isPreparingInvite {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "person.badge.plus.fill")
                    }
                    Text(isPreparingInvite ? "正在准备邀请" : "邀请另一位家长")
                }
                .font(BBBFont.font(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(Capsule().fill(DesignToken.primaryGradient))
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(isPreparingInvite)
        }
        .padding(15)
        .softProfileCard(cornerRadius: 20)
    }

    private var dataCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("会同步的数据")
                .font(BBBFont.font(size: 15, weight: .bold))
                .foregroundStyle(DesignToken.textPrimary)

            syncRow(icon: "person.crop.circle.fill", text: "宝宝资料")
            syncRow(icon: "fork.knife.circle.fill", text: "喂养记录")
            syncRow(icon: "drop.fill", text: "尿布记录")
            syncRow(icon: "moon.fill", text: "睡眠记录")
            syncRow(icon: "trophy.fill", text: "成长成就和贴纸")
            syncRow(icon: "pawprint.fill", text: "当前陪伴动物和未来动物状态")
        }
        .padding(15)
        .softProfileCard(cornerRadius: 20)
    }

    private func syncRow(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .font(BBBFont.font(size: 13, weight: .semibold))
            .foregroundStyle(DesignToken.textPrimary)
            .labelStyle(.titleAndIcon)
    }

    private var statusIcon: String {
        switch familyCloudStore.state {
        case .iCloudUnavailable, .failed: return "exclamationmark.icloud.fill"
        case .syncing, .checkingAccount: return "icloud.and.arrow.up.fill"
        case .ownerShared, .joinedShared: return "person.2.fill"
        case .localOnly: return "iphone"
        }
    }

    private var statusColor: Color {
        switch familyCloudStore.state {
        case .iCloudUnavailable, .failed: return DesignToken.errorRed
        case .syncing, .checkingAccount: return Color(hex: "#6DA5F2")
        case .ownerShared, .joinedShared: return Color(hex: "#67C587")
        case .localOnly: return DesignToken.primary
        }
    }

    private func prepareInvite() {
        isPreparingInvite = true
        Task {
            do {
                let controller = try await familyCloudStore.makeInviteController()
                shareController = FamilyCloudShareSheet(controller: controller)
            } catch {
                errorMessage = error.localizedDescription
            }
            isPreparingInvite = false
        }
    }
}

extension FamilyCloudShareSheet: Identifiable {
    var id: ObjectIdentifier {
        ObjectIdentifier(controller)
    }
}

struct YesterdayReportsArchiveView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var recruitmentStore: CompanionRecruitmentStore
    @State private var selectedReport: YesterdayReport?

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    if recruitmentStore.reports.isEmpty {
                        emptyState
                    } else {
                        ForEach(recruitmentStore.reports) { report in
                            reportRow(report)
                        }
                    }
                }
                .padding(20)
            }
            .background(ProfileSoftBackground().ignoresSafeArea())
            .navigationTitle("yesterday's")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .sheet(item: $selectedReport) { report in
                YesterdayReportOverlay(report: report) {
                    selectedReport = nil
                }
                .environmentObject(recruitmentStore)
                .presentationBackground(.clear)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sunrise.fill")
                .font(.system(size: 28, weight: .heavy))
                .foregroundStyle(DesignToken.primary)
            Text("还没有保存的 yesterday's")
                .font(BBBFont.font(size: 16, weight: .heavy))
                .foregroundStyle(DesignToken.textPrimary)
            Text("每天 8 点后会根据前一天记录生成日报。")
                .font(BBBFont.font(size: 12, weight: .semibold))
                .foregroundStyle(DesignToken.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .softProfileCard(cornerRadius: 22)
    }

    private func reportRow(_ report: YesterdayReport) -> some View {
        let latestReport = recruitmentStore.report(for: report.reportKey) ?? report
        let companions = latestReport.visitorIDs.map { BabyCompanion.companion(for: $0) }
        let companion = companions.first ?? BabyCompanion.companion(for: latestReport.visitorCompanionID)
        let hasFed = latestReport.feedings.contains { $0.servings > 0 }
        return Button {
            selectedReport = latestReport
        } label: {
            HStack(spacing: 12) {
                ZStack(alignment: .bottomTrailing) {
                    Image(companion.portraitAssetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 44, height: 44)
                        .padding(3)
                        .background(Circle().fill(DesignToken.primary.opacity(0.10)))

                    if companions.count > 1 {
                        Text("+\(companions.count - 1)")
                            .font(BBBFont.font(size: 9, weight: .heavy))
                            .foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                            .background(Circle().fill(DesignToken.primary))
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(report.dateText)
                        .font(BBBFont.font(size: 15, weight: .heavy))
                        .foregroundStyle(DesignToken.textPrimary)
                    Text("\(companions.map(\.chineseName).joined(separator: "、")) 来访 · \(CompanionRecruitmentStore.currencyText(latestReport.earnedBBBucks))")
                        .font(BBBFont.font(size: 12, weight: .semibold))
                        .foregroundStyle(DesignToken.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.86)
                }

                Spacer()

                Text(hasFed ? "已喂" : "未喂")
                    .font(BBBFont.font(size: 10, weight: .heavy))
                    .foregroundStyle(hasFed ? Color(hex: "#67C587") : DesignToken.primary)
                    .padding(.horizontal, 9)
                    .frame(height: 24)
                    .background(Capsule().fill((hasFed ? Color(hex: "#67C587") : DesignToken.primary).opacity(0.12)))
            }
            .padding(14)
            .softProfileCard(cornerRadius: 20)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct BabyInfoHeaderView: View {
    @Environment(BabyProfileStore.self) private var profileStore

    var body: some View {
        let profile = profileStore.currentProfile

        VStack(spacing: 12) {
            HStack(spacing: 12) {
                profileAvatar(profile, size: 58, emojiSize: 30)
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(profile.name)
                            .font(BBBFont.font(size: 22, weight: .heavy))
                            .foregroundStyle(DesignToken.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                        Image(systemName: "triangle.fill")
                            .font(.system(size: 10))
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
                infoChip(title: "年龄", value: profile.ageDisplayText)
                infoChip(title: "性别", value: genderTitle(profile.gender))
                Spacer()
            }
        }
        .padding(15)
        .softProfileCard(cornerRadius: 22)
    }

    private func label(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(text)
        }
        .font(BBBFont.font(size: 11, weight: .semibold))
        .foregroundStyle(DesignToken.textSecondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color(hex: "#F6F4FA").opacity(0.82)))
    }

    private func infoChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(BBBFont.font(size: 10, weight: .semibold))
                .foregroundStyle(DesignToken.textSecondary)
            Text(value)
                .font(BBBFont.font(size: 13, weight: .bold))
                .foregroundStyle(DesignToken.textPrimary)
        }
        .frame(minWidth: 78, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(hex: "#F6F4FA").opacity(0.82)))
    }

    private func genderTitle(_ gender: BabyGender) -> String {
        switch gender {
        case .boy: return "男宝"
        case .girl: return "女宝"
        }
    }

    @ViewBuilder
    private func profileAvatar(_ profile: BabyProfileData, size: CGFloat, emojiSize: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Color(hex: "#F4ECF7"))

            if let data = profile.avatarImageData,
               let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Text(profile.displayAvatar)
                    .font(.system(size: emojiSize))
            }
        }
        .frame(width: size, height: size)
        .overlay(Circle().stroke(Color(hex: "#E5BED7"), lineWidth: 2))
    }
}
