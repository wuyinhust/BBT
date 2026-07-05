import StoreKit
import SwiftUI
import UIKit

struct PlusMembershipView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var membershipStore: PlusMembershipStore
    @State private var selectedPlan: PlusMembershipPlan = .yearly

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    heroCard
                    productsCard
                    benefitsCard
                    restoreCard
                }
                .padding(20)
                .padding(.bottom, 26)
            }
            .background(ProfileSoftBackground().ignoresSafeArea())
            .navigationTitle("BabyBuddy Plus")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .task {
                await membershipStore.configure()
            }
            .alert("BabyBuddy Plus", isPresented: Binding(
                get: { membershipStore.errorMessage != nil },
                set: { if !$0 { membershipStore.errorMessage = nil } }
            )) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text(membershipStore.errorMessage ?? "")
            }
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("BabyBuddy Plus")
                        .font(BBBFont.font(size: 25, weight: .heavy))
                        .foregroundStyle(DesignToken.textPrimary)
                    Text("和家人一起记录宝宝日常，把成长变成可以回看的纪念。")
                        .font(BBBFont.font(size: 13, weight: .medium))
                        .foregroundStyle(DesignToken.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                Image(systemName: "sparkles")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(DesignToken.primaryGradient))
            }

            HStack(spacing: 8) {
                statusPill(title: membershipStore.statusTitle, isActive: membershipStore.isPlusActive)
                if let activePlan = membershipStore.activePlan {
                    statusPill(title: activePlan.title, isActive: true)
                }
            }
        }
        .padding(18)
        .softProfileCard(cornerRadius: 22)
    }

    private var productsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("选择会员")
                    .font(BBBFont.font(size: 17, weight: .heavy))
                    .foregroundStyle(DesignToken.textPrimary)
                Spacer()
                if membershipStore.purchaseState == .loadingProducts {
                    ProgressView()
                        .scaleEffect(0.82)
                }
            }

            ForEach(PlusMembershipPlan.allCases) { plan in
                productRow(plan)
            }

            Button {
                Task {
                    if membershipStore.products.isEmpty {
                        await membershipStore.loadProductsIfNeeded()
                    }

                    guard let product = membershipStore.product(for: selectedPlan) else {
                        membershipStore.errorMessage = "会员商品暂未准备好，请稍后重试。"
                        return
                    }
                    await membershipStore.purchase(product)
                }
            } label: {
                HStack {
                    if case .purchasing = membershipStore.purchaseState {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text(primaryButtonTitle)
                }
                .font(BBBFont.font(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Capsule().fill(DesignToken.primaryGradient))
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(isPrimaryButtonDisabled)

            Text("月付和年付的 7 天免费试用需在 App Store Connect 配置后生效。")
                .font(BBBFont.font(size: 11, weight: .medium))
                .foregroundStyle(DesignToken.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .softProfileCard(cornerRadius: 22)
    }

    private var benefitsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Plus 权益")
                .font(BBBFont.font(size: 17, weight: .heavy))
                .foregroundStyle(DesignToken.textPrimary)

            benefitSection(
                title: "一起照顾",
                items: [
                    .init(title: "家庭共享同步", badge: "Plus")
                ]
            )
            benefitSection(
                title: "留下纪念",
                items: [
                    .init(title: "成长记忆扩展", badge: "Plus"),
                    .init(title: "无限制成就徽章", badge: "Plus"),
                    .init(title: "稀有 Buddy", badge: "规划中")
                ]
            )
            benefitSection(
                title: "看见成长",
                items: [
                    .init(title: "周/月成长回顾", badge: "规划中"),
                    .init(title: "完整历史导出", badge: "规划中")
                ]
            )
            benefitSection(
                title: "完整体验",
                items: [
                    .init(title: "全部小组件", badge: "规划中"),
                    .init(title: "全部 App 桌面图标", badge: "规划中"),
                    .init(title: "持续解锁 Plus 新功能", badge: "Plus")
                ]
            )
        }
        .padding(16)
        .softProfileCard(cornerRadius: 22)
    }

    private var restoreCard: some View {
        VStack(spacing: 10) {
            Button {
                Task { await membershipStore.restorePurchases() }
            } label: {
                HStack {
                    if membershipStore.purchaseState == .refreshing {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                    Text("恢复购买")
                }
                .font(BBBFont.font(size: 14, weight: .bold))
                .foregroundStyle(DesignToken.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
            }
            .buttonStyle(.plain)

            Button {
                Task { await openManageSubscriptions() }
            } label: {
                Text("管理订阅")
                    .font(BBBFont.font(size: 13, weight: .semibold))
                    .foregroundStyle(DesignToken.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .softProfileCard(cornerRadius: 18, shadowOpacity: 0.04)
    }

    private var primaryButtonTitle: String {
        if membershipStore.isPlusActive {
            return "继续使用 Plus"
        }
        return "开通 \(selectedPlan.title) Plus"
    }

    private var isPrimaryButtonDisabled: Bool {
        switch membershipStore.purchaseState {
        case .purchasing, .loadingProducts, .refreshing:
            return true
        case .idle:
            return membershipStore.isPlusActive
        }
    }

    private func productRow(_ plan: PlusMembershipPlan) -> some View {
        let product = membershipStore.product(for: plan)
        let isSelected = selectedPlan == plan

        return Button {
            selectedPlan = plan
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(isSelected ? DesignToken.primary : Color(hex: "#C9C3D7"))

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(plan.title)
                            .font(BBBFont.font(size: 15, weight: .heavy))
                            .foregroundStyle(DesignToken.textPrimary)
                        if plan.isRecommended {
                            Text("推荐")
                                .font(BBBFont.font(size: 10, weight: .heavy))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(DesignToken.primary))
                        }
                    }
                    Text(plan.subtitle)
                        .font(BBBFont.font(size: 11, weight: .semibold))
                        .foregroundStyle(DesignToken.textSecondary)
                }

                Spacer()

                Text(product?.displayPrice ?? "待配置")
                    .font(BBBFont.font(size: 14, weight: .heavy))
                    .foregroundStyle(product == nil ? DesignToken.textSecondary : DesignToken.textPrimary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? DesignToken.primary.opacity(0.11) : DesignToken.iconSoftBG.opacity(0.54))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(isSelected ? DesignToken.primary.opacity(0.42) : .clear, lineWidth: 1.2)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func benefitSection(title: String, items: [PlusBenefit]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(BBBFont.font(size: 13, weight: .heavy))
                .foregroundStyle(DesignToken.textPrimary)

            ForEach(items) { item in
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(DesignToken.primary)
                    Text(item.title)
                        .font(BBBFont.font(size: 13, weight: .semibold))
                        .foregroundStyle(DesignToken.textPrimary)
                    Spacer()
                    Text(item.badge)
                        .font(BBBFont.font(size: 10, weight: .heavy))
                        .foregroundStyle(item.badge == "规划中" ? DesignToken.textSecondary : DesignToken.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(item.badge == "规划中" ? DesignToken.iconSoftBG : DesignToken.primary.opacity(0.12)))
                }
            }
        }
    }

    private func statusPill(title: String, isActive: Bool) -> some View {
        Text(title)
            .font(BBBFont.font(size: 12, weight: .heavy))
            .foregroundStyle(isActive ? DesignToken.primary : DesignToken.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(isActive ? DesignToken.primary.opacity(0.12) : DesignToken.iconSoftBG))
    }

    private func openManageSubscriptions() async {
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else {
            membershipStore.errorMessage = "暂时无法打开订阅管理，请到系统设置中查看 Apple ID 订阅。"
            return
        }

        do {
            try await AppStore.showManageSubscriptions(in: scene)
        } catch {
            membershipStore.errorMessage = "暂时无法打开订阅管理，请到系统设置中查看 Apple ID 订阅。"
        }
    }
}

private struct PlusBenefit: Identifiable {
    let id = UUID()
    let title: String
    let badge: String
}
