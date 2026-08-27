import StoreKit
import SwiftUI
import UIKit

struct PlusMembershipView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var membershipStore: PlusMembershipStore
    @State private var selectedPlan: PlusMembershipPlan = .yearly

    private let benefits: [PlusBenefit] = [
        .init(
            icon: "sparkles",
            title: "每天多得 3 BB Bucks",
            detail: "前三轮完整 EASY 每轮额外 +1，每日任务奖励上限从 12 提升至 15。",
            badge: "陪伴加速"
        ),
        .init(
            icon: "sun.max.fill",
            title: "3 款 Plus 专属场景光效",
            detail: "花间暖光、薄荷光与竹影月光，让宝宝的成长空间更有氛围。",
            badge: "专属外观"
        )
    ]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: DesignToken.sectionSpacing) {
                    heroCard
                    benefitsCard
                    productsCard
                    accountActionsCard
                }
                .padding(DesignToken.screenHorizontalPadding)
                .padding(.top, 8)
                .padding(.bottom, 18)
            }
            .background(ProfileSoftBackground().ignoresSafeArea())
            .safeAreaInset(edge: .bottom, spacing: 0) {
                purchaseBar
            }
            .navigationTitle("BBBuddy Plus")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    AppPageCloseButton { dismiss() }
                }
            }
            .task {
                await membershipStore.configure()
                if membershipStore.product(for: selectedPlan) == nil,
                   let availablePlan = displayPlans.first(where: { membershipStore.product(for: $0) != nil }) {
                    selectedPlan = availablePlan
                }
            }
            .alert("BBBuddy Plus", isPresented: Binding(
                get: { membershipStore.errorMessage != nil },
                set: { if !$0 { membershipStore.errorMessage = nil } }
            )) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text((membershipStore.errorMessage ?? "").localized)
            }
        }
    }

    private var heroCard: some View {
        ZStack(alignment: .topTrailing) {
            Circle()
                .fill(DesignToken.primary.opacity(0.17))
                .frame(width: 150, height: 150)
                .blur(radius: 8)
                .offset(x: 50, y: -68)

            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 23, weight: .heavy))
                        .foregroundStyle(DesignToken.onPrimary)
                        .frame(width: 52, height: 52)
                        .background(Circle().fill(DesignToken.primaryGradient))

                    VStack(alignment: .leading, spacing: 3) {
                        Text("BBBuddy Plus")
                            .font(BBBFont.font(size: 22, weight: .heavy))
                            .foregroundStyle(DesignToken.textPrimary)
                        Text("为更完整的陪伴体验而设计")
                            .font(BBBFont.font(size: 12, weight: .semibold))
                            .foregroundStyle(DesignToken.primary)
                    }
                }

                VStack(alignment: .leading, spacing: 7) {
                    Text("把宝宝的每一天，和家人一起珍藏")
                        .font(BBBFont.font(size: 20, weight: .heavy))
                        .foregroundStyle(DesignToken.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("专属场景与每日陪伴加速，让成长留下更多温暖的细节。")
                        .font(BBBFont.font(size: 13, weight: .medium))
                        .foregroundStyle(DesignToken.textSecondary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 8) {
                    statusPill(title: membershipStore.statusTitle, isActive: membershipStore.isPlusActive)
                    if let activePlan = membershipStore.activePlan {
                        statusPill(title: activePlan.title, isActive: true)
                    } else if hasEligibleFreeTrial, let period = selectedTrialPeriodText {
                        statusPill(title: AppLocalization.format("%@ 免费试用", period), isActive: true)
                    }
                }
            }
            .padding(18)
        }
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(DesignToken.surfaceRaised.opacity(0.94))
                .overlay(
                    LinearGradient(
                        colors: [DesignToken.primary.opacity(0.14), .clear, DesignToken.rewardSoft.opacity(0.18)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(DesignToken.primary.opacity(0.20), lineWidth: 1)
        )
        .shadow(color: DesignToken.softShadow, radius: 16, y: 8)
    }

    private var benefitsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("升级后，你会得到")
                    .font(BBBFont.font(size: 18, weight: .heavy))
                    .foregroundStyle(DesignToken.textPrimary)
                Text("核心记录功能始终免费，Plus 增加每日奖励与专属场景。")
                    .font(BBBFont.font(size: 12, weight: .medium))
                    .foregroundStyle(DesignToken.textSecondary)
            }

            ForEach(benefits) { benefit in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: benefit.icon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(DesignToken.primary)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(DesignToken.primary.opacity(0.11)))

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 7) {
                            Text(benefit.title.localized)
                                .font(BBBFont.font(size: 14, weight: .heavy))
                                .foregroundStyle(DesignToken.textPrimary)
                            Spacer(minLength: 4)
                            Text(benefit.badge.localized)
                                .font(BBBFont.font(size: 9.5, weight: .heavy))
                                .foregroundStyle(DesignToken.primary)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(DesignToken.primary.opacity(0.10)))
                        }
                        Text(benefit.detail.localized)
                            .font(BBBFont.font(size: 11.5, weight: .medium))
                            .foregroundStyle(DesignToken.textSecondary)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Label("已获得的 BB Bucks、友情值和 Buddy 永久保留", systemImage: "checkmark.shield.fill")
                .font(BBBFont.font(size: 11, weight: .semibold))
                .foregroundStyle(DesignToken.textSecondary)
        }
        .padding(16)
        .softProfileCard(cornerRadius: DesignToken.largeCardRadius)
    }

    private var productsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("选择适合你的方式")
                        .font(BBBFont.font(size: 18, weight: .heavy))
                        .foregroundStyle(DesignToken.textPrimary)
                    Text(planSectionSubtitle.localized)
                        .font(BBBFont.font(size: 12, weight: .medium))
                        .foregroundStyle(DesignToken.textSecondary)
                }
                Spacer(minLength: 8)
                if membershipStore.purchaseState == .loadingProducts {
                    ProgressView()
                        .scaleEffect(0.82)
                }
            }

            ForEach(displayPlans) { plan in
                productRow(plan)
            }

            if let message = membershipStore.productLoadMessage {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(message.localized)
                        .font(BBBFont.font(size: 11, weight: .medium))
                        .foregroundStyle(DesignToken.textSecondary)
                    Spacer()
                    Button("重试") {
                        Task { await membershipStore.reloadProducts() }
                    }
                    .font(BBBFont.font(size: 11, weight: .heavy))
                    .foregroundStyle(DesignToken.primary)
                }
            }

            if let trialPeriod = selectedTrialPeriodText,
               let product = membershipStore.product(for: selectedPlan) {
                trialTimeline(period: trialPeriod, product: product)
            }
        }
        .padding(16)
        .softProfileCard(cornerRadius: DesignToken.largeCardRadius)
    }

    private var accountActionsCard: some View {
        VStack(spacing: 10) {
            HStack(spacing: 0) {
                Button {
                    Task { await membershipStore.restorePurchases() }
                } label: {
                    Label("恢复购买", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity, minHeight: DesignToken.minimumTapSize)
                }

                Divider()
                    .frame(height: 24)

                Button {
                    Task { await openManageSubscriptions() }
                } label: {
                    Label("管理订阅", systemImage: "gearshape")
                        .frame(maxWidth: .infinity, minHeight: DesignToken.minimumTapSize)
                }
            }
            .font(BBBFont.font(size: 12, weight: .bold))
            .foregroundStyle(DesignToken.primary)
            .buttonStyle(.plain)

            HStack(spacing: 18) {
                NavigationLink("隐私政策") {
                    BBBuddyPrivacyPolicyView()
                }
                NavigationLink("使用条款") {
                    BBBuddyTermsOfUseView()
                }
            }
            .font(BBBFont.font(size: 11, weight: .semibold))
            .foregroundStyle(DesignToken.textSecondary)
        }
        .padding(10)
        .softProfileCard(cornerRadius: 18, shadowOpacity: 0.035)
    }

    private var purchaseBar: some View {
        VStack(spacing: 8) {
            Text(billingSummary)
                .font(BBBFont.font(size: 11.5, weight: .semibold))
                .foregroundStyle(DesignToken.textPrimary)
                .multilineTextAlignment(.center)

            Button {
                Task { await performPrimaryAction() }
            } label: {
                HStack(spacing: 8) {
                    if membershipStore.purchaseState != .idle {
                        ProgressView()
                            .tint(DesignToken.onPrimary)
                    } else {
                        Image(systemName: selectedTrialPeriodText == nil ? "sparkles" : "gift.fill")
                    }
                    Text(primaryButtonTitle)
                }
                .font(BBBFont.font(size: 15, weight: .heavy))
                .foregroundStyle(DesignToken.onPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Capsule().fill(DesignToken.primaryGradient))
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(isPrimaryButtonDisabled)
            .accessibilityIdentifier("plus.primaryPurchase")

            Text("订阅由 App Store 安全处理，可随时取消；最终价格和续费周期以购买确认页为准。")
                .font(BBBFont.font(size: 9.5, weight: .medium))
                .foregroundStyle(DesignToken.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, DesignToken.screenHorizontalPadding)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(DesignToken.borderSubtle.opacity(0.65))
                .frame(height: 0.5)
        }
    }

    private var primaryButtonTitle: String {
        if membershipStore.activePlan == .lifetime {
            return "已开通终身 Plus".localized
        }
        if membershipStore.activePlan == selectedPlan {
            return "当前方案".localized
        }
        if membershipStore.product(for: selectedPlan) == nil {
            return (membershipStore.purchaseState == .loadingProducts ? "正在加载会员商品…" : "重试加载商品").localized
        }
        if let trialPeriod = selectedTrialPeriodText {
            return AppLocalization.format("开始 %@ 免费试用", trialPeriod)
        }
        if membershipStore.isPlusActive {
            return AppLocalization.format("切换为 %@ Plus", selectedPlan.title.localized)
        }
        if selectedPlan == .lifetime {
            return "永久解锁 Plus".localized
        }
        return AppLocalization.format("开通 %@ Plus", selectedPlan.title.localized)
    }

    private var isPrimaryButtonDisabled: Bool {
        switch membershipStore.purchaseState {
        case .purchasing, .loadingProducts, .refreshing:
            return true
        case .idle:
            return membershipStore.activePlan == .lifetime
                || membershipStore.activePlan == selectedPlan
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
                    .foregroundStyle(isSelected ? DesignToken.primary : DesignToken.textFaint)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(plan.title.localized)
                            .font(BBBFont.font(size: 15, weight: .heavy))
                            .foregroundStyle(DesignToken.textPrimary)
                        if plan.isRecommended {
                            Text(annualBadgeText)
                                .font(BBBFont.font(size: 10, weight: .heavy))
                                .foregroundStyle(DesignToken.onPrimary)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                            .background(Capsule().fill(DesignToken.primary))
                        }
                    }
                    Text(planSupportingText(plan))
                        .font(BBBFont.font(size: 11, weight: .semibold))
                        .foregroundStyle(membershipStore.freeTrialOffer(for: plan) == nil ? DesignToken.textSecondary : DesignToken.primary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    if product == nil, membershipStore.productLoadState == .loading {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(DesignToken.textFaint.opacity(0.24))
                            .frame(width: 54, height: 16)
                            .redacted(reason: .placeholder)
                            .accessibilityLabel("正在加载价格")
                    } else {
                        Text(product?.displayPrice ?? "—")
                            .font(BBBFont.font(size: 15, weight: .heavy))
                            .foregroundStyle(product == nil ? DesignToken.textSecondary : DesignToken.textPrimary)
                    }
                    Text(priceCaption(for: plan, product: product))
                        .font(BBBFont.font(size: 9.5, weight: .semibold))
                        .foregroundStyle(DesignToken.textSecondary)
                }
            }
            .padding(13)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? DesignToken.primary.opacity(0.12) : DesignToken.iconSoftBG.opacity(0.42))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(isSelected ? DesignToken.primary.opacity(0.62) : DesignToken.borderSubtle.opacity(0.36), lineWidth: isSelected ? 1.4 : 0.7)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("plus.plan.\(plan.title)")
    }

    private func statusPill(title: String, isActive: Bool) -> some View {
        Text(title.localized)
            .font(BBBFont.font(size: 12, weight: .heavy))
            .foregroundStyle(isActive ? DesignToken.primary : DesignToken.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(isActive ? DesignToken.primary.opacity(0.12) : DesignToken.iconSoftBG))
    }

    private var displayPlans: [PlusMembershipPlan] {
        [.yearly, .monthly, .lifetime]
    }

    private var hasEligibleFreeTrial: Bool {
        displayPlans.contains { membershipStore.freeTrialOffer(for: $0) != nil }
    }

    private var planSectionSubtitle: String {
        if membershipStore.isPlusActive {
            return "你可以在 App Store 管理或切换方案"
        }
        return hasEligibleFreeTrial ? "订阅方案可先免费试用，再决定是否继续" : "年付最划算，终身方案不会自动续费"
    }

    private var selectedTrialPeriodText: String? {
        membershipStore.freeTrialOffer(for: selectedPlan).map(trialPeriodText)
    }

    private var annualBadgeText: String {
        if let savings = annualSavingsPercent {
            return AppLocalization.format("省 %d%%", savings)
        }
        return "最划算".localized
    }

    private var annualSavingsPercent: Int? {
        guard let monthly = membershipStore.product(for: .monthly),
              let yearly = membershipStore.product(for: .yearly) else {
            return nil
        }

        let annualizedMonthly = NSDecimalNumber(decimal: monthly.price).multiplying(by: 12)
        let annualPrice = NSDecimalNumber(decimal: yearly.price)
        guard annualizedMonthly.compare(annualPrice) == .orderedDescending,
              annualizedMonthly.doubleValue > 0 else {
            return nil
        }

        let savingRate = 1 - annualPrice.doubleValue / annualizedMonthly.doubleValue
        return Int((savingRate * 100).rounded())
    }

    private var billingSummary: String {
        guard let product = membershipStore.product(for: selectedPlan) else {
            return (membershipStore.productLoadMessage ?? "正在连接 App Store…").localized
        }

        if selectedPlan == .lifetime {
            return AppLocalization.format("一次购买 %@，永久使用", product.displayPrice)
        }
        if let trialPeriod = selectedTrialPeriodText {
            return AppLocalization.format(
                "%@ 免费，之后按 %@/%@ 自动续订",
                trialPeriod,
                product.displayPrice,
                renewalUnit(for: selectedPlan)
            )
        }
        return AppLocalization.format(
            "%@/%@ 自动续订，可随时取消",
            product.displayPrice,
            renewalUnit(for: selectedPlan)
        )
    }

    private func performPrimaryAction() async {
        if let product = membershipStore.product(for: selectedPlan) {
            await membershipStore.purchase(product)
            return
        }

        await membershipStore.reloadProducts()
        guard let product = membershipStore.product(for: selectedPlan) else {
            membershipStore.errorMessage = "会员商品暂未准备好，请稍后重试。"
            return
        }
        await membershipStore.purchase(product)
    }

    private func planSupportingText(_ plan: PlusMembershipPlan) -> String {
        if let offer = membershipStore.freeTrialOffer(for: plan) {
            return AppLocalization.format("先免费试用 %@", trialPeriodText(offer))
        }
        return plan.subtitle.localized
    }

    private func priceCaption(for plan: PlusMembershipPlan, product: Product?) -> String {
        guard let product else { return "连接 App Store 中".localized }
        switch plan {
        case .monthly:
            return "/月".localized
        case .yearly:
            let monthlyEquivalent = NSDecimalNumber(decimal: product.price)
                .dividing(by: 12)
                .decimalValue
                .formatted(product.priceFormatStyle)
            return AppLocalization.format("平均 %@/月", monthlyEquivalent)
        case .lifetime:
            return "一次购买".localized
        }
    }

    private func trialPeriodText(_ offer: Product.SubscriptionOffer) -> String {
        let value = offer.period.value * offer.periodCount
        switch offer.period.unit {
        case .day:
            return AppLocalization.format("%d 天", value)
        case .week:
            return AppLocalization.format("%d 周", value)
        case .month:
            return AppLocalization.format("%d 个月", value)
        case .year:
            return AppLocalization.format("%d 年", value)
        @unknown default:
            return AppLocalization.format("%d 个周期", value)
        }
    }

    private func renewalUnit(for plan: PlusMembershipPlan) -> String {
        switch plan {
        case .monthly: return "月".localized
        case .yearly: return "年".localized
        case .lifetime: return "永久".localized
        }
    }

    private func trialTimeline(period: String, product: Product) -> some View {
        HStack(spacing: 10) {
            trialStep(icon: "gift.fill", title: "今天", detail: "免费开始")

            Image(systemName: "arrow.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(DesignToken.textFaint)

            trialStep(
                icon: "calendar",
                title: AppLocalization.format("%@ 后", period),
                detail: AppLocalization.format("%@/%@ 续订", product.displayPrice, renewalUnit(for: selectedPlan))
            )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(DesignToken.primary.opacity(0.08))
        )
        .accessibilityElement(children: .combine)
    }

    private func trialStep(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(DesignToken.primary)
                .frame(width: 28, height: 28)
                .background(Circle().fill(DesignToken.primary.opacity(0.12)))
            VStack(alignment: .leading, spacing: 1) {
                Text(title.localized)
                    .font(BBBFont.font(size: 11, weight: .heavy))
                    .foregroundStyle(DesignToken.textPrimary)
                Text(detail.localized)
                    .font(BBBFont.font(size: 9.5, weight: .medium))
                    .foregroundStyle(DesignToken.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
    var id: String { title }
    let icon: String
    let title: String
    let detail: String
    let badge: String
}
