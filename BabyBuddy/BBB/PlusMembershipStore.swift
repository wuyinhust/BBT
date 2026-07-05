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
        case .monthly: return "7 天免费试用"
        case .yearly: return "推荐 · 7 天免费试用"
        case .lifetime: return "一次开通，长期使用"
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

@MainActor
final class PlusMembershipStore: ObservableObject {
    static let shared = PlusMembershipStore()

    @Published private(set) var products: [Product] = []
    @Published private(set) var isPlusActive = false
    @Published private(set) var activePlan: PlusMembershipPlan?
    @Published private(set) var purchaseState: PlusPurchaseState = .idle
    @Published var errorMessage: String?

    private var updatesTask: Task<Void, Never>?
    private let productIDs = PlusMembershipPlan.allCases.map(\.rawValue)

    var statusTitle: String {
        if activePlan == .lifetime {
            return "终身会员"
        }
        return isPlusActive ? "Plus 会员" : "免费版"
    }

    var profileSubtitle: String {
        isPlusActive ? "已开通 · 查看权益" : "家庭协作 · 成长回顾 · 纪念创作"
    }

    init() {
        updatesTask = listenForTransactionUpdates()
    }

    deinit {
        updatesTask?.cancel()
    }

    func configure() async {
        await refreshEntitlements()
        await loadProductsIfNeeded()
    }

    func loadProductsIfNeeded() async {
        guard products.isEmpty else { return }
        purchaseState = .loadingProducts
        do {
            let loadedProducts = try await Product.products(for: productIDs)
            products = loadedProducts.sorted { lhs, rhs in
                productSortIndex(lhs.id) < productSortIndex(rhs.id)
            }
        } catch {
            errorMessage = "暂时无法加载会员商品，请稍后再试。"
        }
        purchaseState = .idle
    }

    func product(for plan: PlusMembershipPlan) -> Product? {
        products.first { $0.id == plan.rawValue }
    }

    func purchase(_ product: Product) async {
        purchaseState = .purchasing(product.id)
        errorMessage = nil
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try verifiedTransaction(from: verification)
                await transaction.finish()
                await refreshEntitlements()
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = "开通失败，请稍后再试。"
        }
        purchaseState = .idle
    }

    func restorePurchases() async {
        purchaseState = .refreshing
        errorMessage = nil
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            errorMessage = "恢复购买失败，请确认网络和 Apple ID 后重试。"
        }
        purchaseState = .idle
    }

    func refreshEntitlements() async {
        var resolvedPlan: PlusMembershipPlan?

        for await result in Transaction.currentEntitlements {
            guard let transaction = try? verifiedTransaction(from: result),
                  let plan = PlusMembershipPlan.plan(for: transaction.productID),
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

        activePlan = resolvedPlan
        isPlusActive = resolvedPlan != nil
    }

    private func listenForTransactionUpdates() -> Task<Void, Never> {
        Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if let transaction = try? self.verifiedTransaction(from: result) {
                    await transaction.finish()
                    await self.refreshEntitlements()
                }
            }
        }
    }

    private func verifiedTransaction<T>(from result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let transaction):
            return transaction
        case .unverified:
            throw StoreKitError.userCancelled
        }
    }

    private func productSortIndex(_ productID: String) -> Int {
        productIDs.firstIndex(of: productID) ?? productIDs.count
    }
}
