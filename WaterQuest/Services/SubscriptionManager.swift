import Foundation
import StoreKit

// MARK: - Product IDs
// Replace these with your actual App Store Connect product identifiers before shipping.
enum ProductID: String, CaseIterable {
    case monthly = "com.waterquest.pro.monthly"
    case annual  = "com.waterquest.pro.annual"
}

// MARK: - SubscriptionManager
/// Manages the 7-day free trial and StoreKit 2 auto-renewable subscription.
/// Trial start date is persisted in UserDefaults so it survives app re-launches.
@MainActor
final class SubscriptionManager: ObservableObject {
    static let trialLengthDays = 7

    private enum Pricing {
        static let currencyCode = "GBP"
        static let monthly = Decimal(string: "2.99") ?? Decimal(2.99)
        static let annual = Decimal(string: "29.99") ?? Decimal(29.99)
    }

    /// `true` while the user is within the 7-day trial window OR has an active subscription.
    @Published private(set) var isPro: Bool = false
    /// `true` when an active paid entitlement is found in StoreKit.
    @Published private(set) var hasActiveSubscription: Bool = false
    /// `true` once initial products and status have been loaded.
    @Published private(set) var isInitialized: Bool = false

    /// The fetched StoreKit products (monthly & annual).
    @Published private(set) var products: [Product] = []

    /// `true` if the trial is still active (within 7 days of first launch).
    var isTrialActive: Bool {
        guard let start = trialStartDate else { return false }
        return Date().timeIntervalSince(start) < trialDuration
    }

    /// The date the trial expires, or `nil` if no trial has started.
    var trialExpirationDate: Date? {
        guard let start = trialStartDate else { return nil }
        return start.addingTimeInterval(trialDuration)
    }

    /// Number of whole/partial days remaining in trial (rounded up), 0 if expired.
    var trialDaysRemaining: Int {
        guard let expiration = trialExpirationDate else { return 0 }
        let remaining = expiration.timeIntervalSinceNow
        guard remaining > 0 else { return 0 }
        return Int(ceil(remaining / (24 * 60 * 60)))
    }

    static var monthlyPriceText: String {
        formatPrice(Pricing.monthly)
    }

    static var annualPriceText: String {
        formatPrice(Pricing.annual)
    }

    static var trialLengthLabel: String {
        "\(trialLengthDays)-day"
    }

    // MARK: - Private
    private static let trialStartKey = "WaterQuest.trialStartDate"
    private let trialDuration: TimeInterval = TimeInterval(SubscriptionManager.trialLengthDays * 24 * 60 * 60)

    private var trialStartDate: Date? {
        get {
            guard let interval = UserDefaults.standard.object(forKey: Self.trialStartKey) as? Double else { return nil }
            return Date(timeIntervalSince1970: interval)
        }
        set {
            UserDefaults.standard.set(newValue?.timeIntervalSince1970, forKey: Self.trialStartKey)
        }
    }

    // MARK: - Initialisation
    init() {
        // Seed the trial start date on first launch.
        if trialStartDate == nil {
            trialStartDate = Date()
        }
        isPro = isTrialActive
    }

    // MARK: - Lifecycle
    /// Call once early in the app lifecycle (e.g. in a `.task` on the root view).
    /// Fetches products and checks for an active subscription.
    func initialise() async {
        await fetchProducts()
        await refreshSubscriptionStatus()
        isInitialized = true
    }

    // MARK: - Products
    private func fetchProducts() async {
        do {
            let ids = Set(ProductID.allCases.map { $0.rawValue })
            products = try await Product.products(for: ids)
        } catch {
            print("SubscriptionManager: failed to fetch products – \(error)")
        }
    }

    /// Returns the monthly product, if loaded.
    var monthlyProduct: Product? {
        products.first { $0.id == ProductID.monthly.rawValue }
    }

    /// Returns the annual product, if loaded.
    var annualProduct: Product? {
        products.first { $0.id == ProductID.annual.rawValue }
    }

    // MARK: - Purchase
    /// Initiates a purchase for the given product.  Returns `true` on success.
    func purchase(_ product: Product) async -> Bool {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified:
                    await refreshSubscriptionStatus()
                    return true
                case .unverified:
                    return false
                }
            case .pending, .userCancelled:
                return false
            @unknown default:
                return false
            }
        } catch {
            print("SubscriptionManager: purchase failed – \(error)")
            return false
        }
    }

    // MARK: - Restore
    /// Restores previous purchases.  Returns `true` if an active entitlement was found.
    func restore() async -> Bool {
        do {
            try await AppStore.sync()
            await refreshSubscriptionStatus()
            return isPro
        } catch {
            print("SubscriptionManager: restore failed – \(error)")
            return false
        }
    }

    // MARK: - Status
    /// Checks `Transaction.currentEntitlements` for an active subscription
    /// and updates `isPro` accordingly.
    private func refreshSubscriptionStatus() async {
        var hasActive = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if ProductID(rawValue: transaction.productID) != nil {
                    // Subscription is in currentEntitlements → it is active or in a grace period.
                    hasActive = true
                    break
                }
            }
        }
        hasActiveSubscription = hasActive
        isPro = hasActive || isTrialActive
    }

    /// Public wrapper to re-check the current entitlement state.
    func refreshStatus() async {
        await refreshSubscriptionStatus()
    }

    // MARK: - Transaction listener
    /// Starts a background task that listens for new transactions (e.g. renewals
    /// or purchases made outside the app).  Call once and keep the returned task alive.
    func startTransactionListener() -> Task<Void, Never> {
        Task {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    if ProductID(rawValue: transaction.productID) != nil {
                        await refreshSubscriptionStatus()
                    }
                }
            }
        }
    }

    private static func formatPrice(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = Pricing.currencyCode
        formatter.locale = Locale(identifier: "en_GB")
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "£0.00"
    }
}
