import Foundation
import StoreKit

enum ProductID: String, CaseIterable {
    case monthly = "com.waterquest.pro.monthly"
}

@MainActor
final class SubscriptionManager: ObservableObject {
    static let trialLengthDays = 7

    private enum Pricing {
        static let currencyCode = "GBP"
        static let monthly = Decimal(string: "5.99") ?? Decimal(5.99)
    }

    @Published private(set) var isPro: Bool = false
    @Published private(set) var hasActiveSubscription: Bool = false
    @Published private(set) var isInitialized: Bool = false
    @Published private(set) var products: [Product] = []

    var isTrialActive: Bool {
        guard let start = trialStartDate else { return false }
        return Date().timeIntervalSince(start) < trialDuration
    }

    var trialExpirationDate: Date? {
        guard let start = trialStartDate else { return nil }
        return start.addingTimeInterval(trialDuration)
    }

    var trialDaysRemaining: Int {
        guard let expiration = trialExpirationDate else { return 0 }
        let remaining = expiration.timeIntervalSinceNow
        guard remaining > 0 else { return 0 }
        return Int(ceil(remaining / (24 * 60 * 60)))
    }

    static var trialLengthLabel: String {
        "\(trialLengthDays)-day"
    }

    static var monthlyPriceText: String {
        formatPrice(Pricing.monthly)
    }

    var monthlyProduct: Product? {
        products.first { $0.id == ProductID.monthly.rawValue }
    }

    var monthlyPriceText: String {
        monthlyProduct?.displayPrice ?? Self.monthlyPriceText
    }

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

    init() {
        if trialStartDate == nil {
            trialStartDate = Date()
        }
        isPro = isTrialActive
    }

    func initialise() async {
        await ensureProductsLoaded()
        await refreshSubscriptionStatus()
        isInitialized = true
    }

    func ensureProductsLoaded() async {
        guard products.isEmpty else { return }
        do {
            let ids = Set(ProductID.allCases.map(\.rawValue))
            products = try await Product.products(for: ids).sorted { $0.id < $1.id }
        } catch {
            print("SubscriptionManager: failed to fetch products - \(error)")
        }
    }

    func purchaseMonthly() async -> Bool {
        await ensureProductsLoaded()
        guard let monthlyProduct else { return false }
        return await purchase(monthlyProduct)
    }

    func purchase(_ product: Product) async -> Bool {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    let purchasedKnownProduct = ProductID(rawValue: transaction.productID) != nil
                    await transaction.finish()
                    if purchasedKnownProduct {
                        hasActiveSubscription = true
                        isPro = true
                    }
                    await refreshSubscriptionStatus()
                    return purchasedKnownProduct || hasActiveSubscription
                case .unverified:
                    return false
                }
            case .pending, .userCancelled:
                return false
            @unknown default:
                return false
            }
        } catch {
            print("SubscriptionManager: purchase failed - \(error)")
            return false
        }
    }

    func restore() async -> Bool {
        do {
            try await AppStore.sync()
            await refreshSubscriptionStatus()
            return hasActiveSubscription
        } catch {
            print("SubscriptionManager: restore failed - \(error)")
            return false
        }
    }

    func refreshStatus() async {
        await refreshSubscriptionStatus()
    }

    func startTransactionListener() -> Task<Void, Never> {
        Task {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result,
                   ProductID(rawValue: transaction.productID) != nil {
                    await transaction.finish()
                    await refreshSubscriptionStatus()
                }
            }
        }
    }

    private func refreshSubscriptionStatus() async {
        var hasActive = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               ProductID(rawValue: transaction.productID) != nil {
                hasActive = true
                break
            }
        }
        hasActiveSubscription = hasActive
        isPro = hasActive || isTrialActive
    }

    private static func formatPrice(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = Pricing.currencyCode
        formatter.locale = Locale(identifier: "en_GB")
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "£0.00"
    }
}
