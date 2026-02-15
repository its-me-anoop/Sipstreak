import Foundation
import StoreKit

enum ProductID: String, CaseIterable {
    case monthly = "com.waterquest.monthly"
}

@MainActor
final class SubscriptionManager: ObservableObject {
    @Published private(set) var isPro: Bool = false
    @Published private(set) var hasActiveSubscription: Bool = false
    @Published private(set) var isInitialized: Bool = false
    @Published private(set) var products: [Product] = []

    /// Set by the app root so we can schedule trial-end reminders after purchase.
    weak var notificationScheduler: NotificationScheduler?

    var monthlyProduct: Product? {
        products.first { $0.id == ProductID.monthly.rawValue }
    }

    var monthlyPriceText: String? {
        monthlyProduct?.displayPrice
    }

    init() {
        isPro = false
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
                        scheduleTrialReminderIfApplicable(for: product)
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
        isPro = hasActive
    }

    /// If the product has a free trial, schedule a reminder one day before it ends.
    private func scheduleTrialReminderIfApplicable(for product: Product) {
        guard
            let introOffer = product.subscription?.introductoryOffer,
            introOffer.paymentMode == .freeTrial
        else { return }

        let period = introOffer.period
        let trialDays: Int
        switch period.unit {
        case .day:   trialDays = period.value
        case .week:  trialDays = period.value * 7
        case .month: trialDays = period.value * 30
        case .year:  trialDays = period.value * 365
        @unknown default: trialDays = period.value
        }

        notificationScheduler?.scheduleTrialEndReminder(trialDays: trialDays)
    }

}
