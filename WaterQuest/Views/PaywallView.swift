import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss

    var isDismissible: Bool = true

    @State private var selectedPlan: ProductID = .annual
    @State private var isPurchasing = false
    @State private var purchaseError: String?
    @State private var restoreSuccess = false

    private let privacyURL = URL(string: "https://example.com/privacy")!
    private let termsURL = URL(string: "https://example.com/terms")!

    var body: some View {
        NavigationStack {
            ZStack {
                AppWaterBackground().ignoresSafeArea()

                List {
                    Section {
                        header
                    }

                    Section("What you unlock") {
                        featureRow(icon: "chart.line.uptrend.xyaxis", text: "Detailed hydration trends")
                        featureRow(icon: "clock.fill", text: "Extended intake history")
                        featureRow(icon: "trophy.fill", text: "Full quests and milestones")
                        featureRow(icon: "sparkles", text: "Personalized hydration coaching")
                        featureRow(icon: "sun.max.fill", text: "Weather + workout goal tuning")
                    }

                    Section("Choose a plan") {
                        plansContent
                    }

                    Section {
                        Button {
                            doPurchase()
                        } label: {
                            if isPurchasing {
                                HStack {
                                    ProgressView()
                                        .tint(.white)
                                    Text("Processing…")
                                }
                                .frame(maxWidth: .infinity)
                            } else {
                                Text("Start \(SubscriptionManager.trialLengthLabel) free trial")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isPurchasing || resolvedProduct == nil)

                        Text("Then \(selectedPlanPrice)/\(selectedPlanUnit). Cancel anytime.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if let purchaseError {
                        Section {
                            Text(purchaseError)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    }

                    Section {
                        Button(restoreSuccess ? "Restored" : "Restore Purchase") {
                            doRestore()
                        }
                        .disabled(isPurchasing)
                    }

                    Section {
                        Text("Payment is charged to your Apple ID after the \(SubscriptionManager.trialLengthLabel) trial unless canceled. Subscription renews automatically unless canceled at least 24 hours before renewal.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        HStack {
                            Link("Privacy Policy", destination: privacyURL)
                            Spacer()
                            Link("Terms of Use", destination: termsURL)
                        }
                        .font(.footnote)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
            .navigationTitle("WaterQuest Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if isDismissible {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Close") {
                            dismiss()
                        }
                    }
                }
            }
            .task {
                selectedPlan = subscriptionManager.annualProduct != nil ? .annual : .monthly
            }
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "drop.fill")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(Theme.lagoon)
                .frame(width: 96, height: 96)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                )

            Text("Upgrade for deeper hydration guidance")
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)

            Text("\(SubscriptionManager.trialLengthLabel) free trial, then \(SubscriptionManager.monthlyPriceText)/month or \(SubscriptionManager.annualPriceText)/year.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var plansContent: some View {
        PlanRow(
            title: "Yearly",
            subtitle: "\(annualPerMonthText)/month, billed yearly",
            price: SubscriptionManager.annualPriceText,
            isSelected: selectedPlan == .annual,
            isBestValue: true
        ) {
            selectedPlan = .annual
        }

        PlanRow(
            title: "Monthly",
            subtitle: "Flexible monthly billing",
            price: SubscriptionManager.monthlyPriceText,
            isSelected: selectedPlan == .monthly,
            isBestValue: false
        ) {
            selectedPlan = .monthly
        }

        if subscriptionManager.products.isEmpty {
            Text("Loading App Store products...")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var resolvedProduct: Product? {
        switch selectedPlan {
        case .monthly:
            return subscriptionManager.monthlyProduct
        case .annual:
            return subscriptionManager.annualProduct
        }
    }

    private var selectedPlanPrice: String {
        selectedPlan == .annual ? SubscriptionManager.annualPriceText : SubscriptionManager.monthlyPriceText
    }

    private var selectedPlanUnit: String {
        selectedPlan == .annual ? "year" : "month"
    }

    private var annualPerMonthText: String {
        let annual = Decimal(string: "29.99") ?? Decimal(29.99)
        let monthly = annual / Decimal(12)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "GBP"
        formatter.locale = Locale(identifier: "en_GB")
        return formatter.string(from: NSDecimalNumber(decimal: monthly)) ?? "£2.50"
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(Theme.lagoon)
                .frame(width: 22)
            Text(text)
            Spacer()
        }
    }

    private func doPurchase() {
        guard let product = resolvedProduct else {
            purchaseError = "Products are not available right now. Please try again."
            return
        }

        isPurchasing = true
        purchaseError = nil

        Task {
            let success = await subscriptionManager.purchase(product)
            await MainActor.run {
                isPurchasing = false
                if success {
                    Haptics.success()
                    dismiss()
                } else {
                    Haptics.error()
                    purchaseError = "Purchase did not complete. Please try again."
                }
            }
        }
    }

    private func doRestore() {
        isPurchasing = true
        purchaseError = nil

        Task {
            let success = await subscriptionManager.restore()
            await MainActor.run {
                isPurchasing = false
                if success {
                    restoreSuccess = true
                    Haptics.success()
                    dismiss()
                } else {
                    Haptics.warning()
                    purchaseError = "No previous purchase found."
                }
            }
        }
    }
}

private struct PlanRow: View {
    let title: String
    let subtitle: String
    let price: String
    let isSelected: Bool
    let isBestValue: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: {
            Haptics.selection()
            onSelect()
        }) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                        if isBestValue {
                            Text("Best Value")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Theme.sun.opacity(0.2)))
                        }
                    }
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(price)
                    .font(.headline)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Theme.lagoon : .secondary)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.cardSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? Theme.lagoon : Theme.glassBorder, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#if DEBUG
#Preview("Paywall") {
    PreviewEnvironment {
        PaywallView(isDismissible: true)
    }
    .environmentObject(SubscriptionManager())
}
#endif
