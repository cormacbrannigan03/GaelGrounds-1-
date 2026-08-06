import Foundation
import StoreKit
import Supabase

/// Owns the app's single premium subscription: loads the StoreKit product,
/// drives purchase/restore, and keeps `isPremium` in sync with what
/// StoreKit 2 reports (which does real on-device cryptographic
/// verification of each transaction against Apple's certificates).
///
/// Verification here is client-side only, by design: there's no backend
/// receipt-verification step, so `isPremium` is written straight onto the
/// signed-in user's `user_profiles` row. See ios/README.md's "Honest
/// caveats" for the accepted tradeoff this implies — the match-cap,
/// 2019-cutoff, and friend-request rules are still enforced server-side
/// via Postgres RLS regardless, so this is the one deliberately-accepted
/// gap, not the whole paywall.
@MainActor
final class PremiumStore: ObservableObject {
    static let monthlyProductId = "com.gaelgrounds.premium.monthly"

    @Published private(set) var isPremium = false
    @Published private(set) var premiumExpiresAt: Date?
    @Published private(set) var monthlyProduct: Product?
    @Published private(set) var isLoadingProduct = true

    /// Kept current by the app root whenever the signed-in user changes,
    /// e.g. `.task(id: auth.userId) { premium.userId = auth.userId }`.
    /// StoreKit-side status tracking doesn't depend on this being set —
    /// only syncing that status onto `user_profiles` does.
    var userId: UUID? {
        didSet {
            guard userId != oldValue, userId != nil, hasLoadedEntitlementsOnce else { return }
            Task { await syncCurrentStatus() }
        }
    }

    private var hasLoadedEntitlementsOnce = false
    private var transactionListenerTask: Task<Void, Never>?

    /// Call once at app launch. Loads the product, does an initial
    /// entitlement scan, and starts listening for transactions that arrive
    /// asynchronously (renewals, purchases restored from another device,
    /// Ask to Buy approvals) for as long as the app is running.
    func start() async {
        await loadProduct()
        await refreshEntitlements()
        transactionListenerTask?.cancel()
        transactionListenerTask = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(update)
            }
        }
    }

    func loadProduct() async {
        isLoadingProduct = true
        defer { isLoadingProduct = false }
        do {
            let products = try await Product.products(for: [Self.monthlyProductId])
            monthlyProduct = products.first
        } catch {
            print("PremiumStore.loadProduct failed: \(error)")
        }
    }

    func purchase() async throws {
        if monthlyProduct == nil {
            await loadProduct()
        }
        guard let monthlyProduct else { return }
        let result = try await monthlyProduct.purchase()
        switch result {
        case .success(let verification):
            await handle(verification)
        case .userCancelled, .pending:
            break
        @unknown default:
            break
        }
    }

    func restorePurchases() async throws {
        try await AppStore.sync()
        await refreshEntitlements()
    }

    private func refreshEntitlements() async {
        var active = false
        var activeExpiry: Date?
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.productID == Self.monthlyProductId else { continue }
            if let expirationDate = transaction.expirationDate, expirationDate > Date() {
                active = true
                activeExpiry = expirationDate
            }
        }
        isPremium = active
        premiumExpiresAt = activeExpiry
        hasLoadedEntitlementsOnce = true
        await syncCurrentStatus()
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else { return }
        await transaction.finish()
        await refreshEntitlements()
    }

    private func syncCurrentStatus() async {
        guard let userId else { return }
        do {
            try await Supa.client
                .from("user_profiles")
                .update(UserProfilePremiumUpdate(isPremium: isPremium, premiumExpiresAt: premiumExpiresAt))
                .eq("id", value: userId)
                .execute()
        } catch {
            print("PremiumStore.syncCurrentStatus failed: \(error)")
        }
    }
}
