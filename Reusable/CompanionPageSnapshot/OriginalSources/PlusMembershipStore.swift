import Foundation
import StoreKit

enum PlusMembershipPlan: String, CaseIterable, Identifiable {
    case monthly = "v.babybuddy.plus.monthly"
    case yearly = "v.babybuddy.plus.yearly"
    case lifetime = "v.babybuddy.plus.lifetime"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .monthly: return "月付"
        case .yearly: return "年付"
        case .lifetime: return "终身"
        }
    }

    var subtitle: String {
        switch self {
        case .monthly: return "灵活按月，自动续费"
        case .yearly: return "年度方案，长期陪伴更划算"
        case .lifetime: return "一次购买，永久使用"
        }
    }

    var isRecommended: Bool {
        self == .yearly
    }

    static func plan(for productID: String) -> PlusMembershipPlan? {
        PlusMembershipPlan(rawValue: productID)
    }
}

enum PlusPurchaseState: Equatable {
    case idle
    case loadingProducts
    case purchasing(String)
    case refreshing
}

enum PlusProductLoadState: Equatable {
    case idle
    case loading
    case loaded
    case failed
}

enum SharePlusCampaign {
    static let rewardDurationDays = 30
    static let claimedKey = "bb.plus.share-reward.claimed.v1"
    static let expirationKey = "bb.plus.share-reward.expiration.v1"

    static var rewardDuration: TimeInterval {
        TimeInterval(rewardDurationDays * 24 * 60 * 60)
    }
}

enum SharePlusRewardClaimResult: Equatable {
    case activated(Date)
    case paidPlusActive
    case alreadyClaimed(Date?)
}

private enum PlusMembershipError: Error {
    case failedVerification
}

@MainActor
final class PlusMembershipStore: ObservableObject {
    static let shared = PlusMembershipStore()

    @Published private(set) var products: [Product] = []
    @Published private(set) var isPlusActive = false
    @Published private(set) var activePlan: PlusMembershipPlan?
    @Published private(set) var purchaseState: PlusPurchaseState = .idle
    @Published private(set) var productLoadState: PlusProductLoadState = .idle
    @Published private(set) var freeTrialEligibleProductIDs: Set<String> = []
    @Published private(set) var productLoadMessage: String?
    @Published private(set) var shareRewardExpirationDate: Date?
    @Published var errorMessage: String?

    private var updatesTask: Task<Void, Never>?
    private let productIDs = PlusMembershipPlan.allCases.map(\.rawValue)
    private let defaults: UserDefaults
    private let now: () -> Date

    var hasClaimedShareReward: Bool {
        defaults.bool(forKey: SharePlusCampaign.claimedKey)
    }

    var isShareRewardActive: Bool {
        guard let shareRewardExpirationDate else { return false }
        return shareRewardExpirationDate > now()
    }

    var statusTitle: String {
        if activePlan == .lifetime {
            return "终身会员"
        }
        if activePlan == nil, isShareRewardActive {
            return "Plus 体验"
        }
        return isPlusActive ? "Plus 会员" : "免费版"
    }

    var profileSubtitle: String {
        isPlusActive ? "每日 +3 · 专属场景" : "陪伴加速 · Plus 专属体验"
    }

    init(
        defaults: UserDefaults = .standard,
        now: @escaping () -> Date = Date.init
    ) {
        self.defaults = defaults
        self.now = now
        let storedExpiration = defaults.object(forKey: SharePlusCampaign.expirationKey) as? Date
        shareRewardExpirationDate = storedExpiration
        isPlusActive = storedExpiration.map { $0 > now() } ?? false
        updatesTask = listenForTransactionUpdates()
    }

    deinit {
        updatesTask?.cancel()
    }

    func configure() async {
        await refreshEntitlements()
        await loadProductsIfNeeded()
    }

    func loadProductsIfNeeded(force: Bool = false) async {
        guard (force || products.isEmpty), purchaseState == .idle else { return }
        purchaseState = .loadingProducts
        productLoadState = .loading
        do {
            let loadedProducts = try await Product.products(for: productIDs)
            products = loadedProducts.sorted { lhs, rhs in
                productSortIndex(lhs.id) < productSortIndex(rhs.id)
            }
            let missingCount = productIDs.filter { productID in
                !loadedProducts.contains(where: { $0.id == productID })
            }.count
            if loadedProducts.isEmpty {
                #if DEBUG
                productLoadMessage = "未找到 Plus 商品。请检查当前开发运行方案的 StoreKit 配置。"
                #else
                productLoadMessage = "暂时没有可用的 Plus 商品，请稍后重试。"
                #endif
            } else {
                productLoadMessage = missingCount == 0
                    ? nil
                    : "部分 Plus 商品暂不可用，请检查 App Store Connect 商品状态。"
            }
            productLoadState = loadedProducts.isEmpty ? .failed : .loaded
            await refreshFreeTrialEligibility()
        } catch {
            productLoadState = .failed
            productLoadMessage = "无法连接 App Store，请检查网络后重试。"
        }
        purchaseState = .idle
    }

    func reloadProducts() async {
        guard purchaseState == .idle else { return }
        freeTrialEligibleProductIDs = []
        productLoadMessage = nil
        await loadProductsIfNeeded(force: true)
    }

    func product(for plan: PlusMembershipPlan) -> Product? {
        products.first { $0.id == plan.rawValue }
    }

    func freeTrialOffer(for plan: PlusMembershipPlan) -> Product.SubscriptionOffer? {
        guard freeTrialEligibleProductIDs.contains(plan.rawValue),
              let offer = product(for: plan)?.subscription?.introductoryOffer,
              offer.paymentMode == .freeTrial else {
            return nil
        }
        return offer
    }

    func purchase(_ product: Product) async {
        guard purchaseState == .idle else { return }
        purchaseState = .purchasing(product.id)
        errorMessage = nil
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try verifiedTransaction(from: verification)
                await transaction.finish()
                await refreshEntitlements()
                await refreshFreeTrialEligibility()
            case .pending:
                errorMessage = "购买请求正在等待批准，批准后会自动开通。"
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch PlusMembershipError.failedVerification {
            errorMessage = "无法验证 App Store 交易，请稍后重试。"
        } catch {
            errorMessage = "开通失败，请稍后再试。"
        }
        purchaseState = .idle
    }

    func restorePurchases() async {
        guard purchaseState == .idle else { return }
        purchaseState = .refreshing
        errorMessage = nil
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            await refreshFreeTrialEligibility()
        } catch {
            errorMessage = "恢复购买失败，请确认网络和 Apple ID 后重试。"
        }
        purchaseState = .idle
    }

    func claimShareReward() -> SharePlusRewardClaimResult {
        guard activePlan == nil else {
            return .paidPlusActive
        }
        guard !hasClaimedShareReward else {
            return .alreadyClaimed(shareRewardExpirationDate)
        }

        let expirationDate = now().addingTimeInterval(SharePlusCampaign.rewardDuration)
        defaults.set(true, forKey: SharePlusCampaign.claimedKey)
        defaults.set(expirationDate, forKey: SharePlusCampaign.expirationKey)
        shareRewardExpirationDate = expirationDate
        isPlusActive = true
        return .activated(expirationDate)
    }

    func refreshShareRewardState() {
        shareRewardExpirationDate = defaults.object(forKey: SharePlusCampaign.expirationKey) as? Date
        isPlusActive = activePlan != nil || isShareRewardActive
    }

    func refreshEntitlements() async {
        var resolvedPlan: PlusMembershipPlan?
        var encounteredVerificationFailure = false

        for await result in Transaction.currentEntitlements {
            let transaction: Transaction
            do {
                transaction = try verifiedTransaction(from: result)
            } catch {
                encounteredVerificationFailure = true
                continue
            }

            guard let plan = PlusMembershipPlan.plan(for: transaction.productID),
                  transaction.revocationDate == nil else {
                continue
            }

            if plan == .lifetime {
                resolvedPlan = .lifetime
                break
            }

            if resolvedPlan == nil || plan == .yearly {
                resolvedPlan = plan
            }
        }

        // A transient local JWS verification failure must not immediately
        // revoke access that was already verified earlier. A later foreground
        // refresh or Transaction.updates event will reconcile the entitlement.
        if encounteredVerificationFailure, resolvedPlan == nil, activePlan != nil {
            return
        }

        activePlan = resolvedPlan
        refreshShareRewardState()
    }

    private func listenForTransactionUpdates() -> Task<Void, Never> {
        Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                do {
                    let transaction = try self.verifiedTransaction(from: result)
                    await transaction.finish()
                    await self.refreshEntitlements()
                    await self.refreshFreeTrialEligibility()
                } catch {
                    self.errorMessage = "无法验证 App Store 交易，请稍后重试。"
                }
            }
        }
    }

    private func verifiedTransaction<T>(from result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let transaction):
            return transaction
        case .unverified:
            throw PlusMembershipError.failedVerification
        }
    }

    private func refreshFreeTrialEligibility() async {
        var eligibilityByGroup: [String: Bool] = [:]
        var eligibleProductIDs: Set<String> = []

        for product in products {
            guard let subscription = product.subscription,
                  let offer = subscription.introductoryOffer,
                  offer.paymentMode == .freeTrial else {
                continue
            }

            let groupID = subscription.subscriptionGroupID
            let isEligible: Bool
            if let cachedEligibility = eligibilityByGroup[groupID] {
                isEligible = cachedEligibility
            } else {
                isEligible = await subscription.isEligibleForIntroOffer
                eligibilityByGroup[groupID] = isEligible
            }

            if isEligible {
                eligibleProductIDs.insert(product.id)
            }
        }

        freeTrialEligibleProductIDs = eligibleProductIDs
    }

    private func productSortIndex(_ productID: String) -> Int {
        productIDs.firstIndex(of: productID) ?? productIDs.count
    }
}
