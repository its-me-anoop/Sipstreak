import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss

    let isDismissible: Bool

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isEligibleForIntroOffer = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        MascotView(size: 64, animated: false, style: .ripple)
                            .frame(height: 90)

                        Text("Thirsty.ai")
                            .font(.title2.weight(.bold))

                        Text("Your all-in-one hydration companion")
                            .font(.headline)

                        Text(paywallSubtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 12)

                    VStack(alignment: .leading, spacing: 10) {
                        featureRow(icon: "drop.fill", text: "Quick daily water logging")
                        featureRow(icon: "target", text: "Personalized hydration goal")
                        featureRow(icon: "bell.badge.fill", text: "Smart reminders for your routine")
                        featureRow(icon: "cloud.sun.fill", text: "Weather and workout-aware adjustments")
                        featureRow(icon: "chart.line.uptrend.xyaxis", text: "Daily, weekly, and monthly insights")
                        featureRow(icon: "clock.arrow.circlepath", text: "Complete hydration history and logs")
                        featureRow(icon: "heart.fill", text: "HealthKit sync and wellness context")
                        featureRow(icon: "trophy.fill", text: "Quests, streaks, achievements, and mascot rewards")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Theme.cardSurface)
                    )

                    // MARK: - Pricing block (billed amount is most prominent)
                    VStack(spacing: 6) {
                        if let priceText = monthlyPriceText {
                            Text("\(priceText)/month")
                                .font(.title.weight(.bold))
                                .foregroundStyle(.primary)
                        } else {
                            Text("Loading pricing…")
                                .font(.title3.weight(.medium))
                                .foregroundStyle(.secondary)
                        }

                        if let trialDays = introductoryTrialDays, isEligibleForIntroOffer {
                            Text("Try free for \(trialDays) days, then \(monthlyPriceText ?? "")/month")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)

                    // MARK: - Visual trial timeline
                    if let trialDays = introductoryTrialDays, isEligibleForIntroOffer, let priceText = monthlyPriceText {
                        VStack(spacing: 0) {
                            trialTimelineRow(
                                icon: "checkmark.circle.fill",
                                iconColor: Theme.mint,
                                title: "Today",
                                subtitle: "Get full access instantly",
                                showConnector: true
                            )
                            trialTimelineRow(
                                icon: "bell.circle.fill",
                                iconColor: Theme.sun,
                                title: "Day \(trialDays - 1)",
                                subtitle: "We'll remind you before the trial ends",
                                showConnector: true
                            )
                            trialTimelineRow(
                                icon: "creditcard.circle.fill",
                                iconColor: Theme.lagoon,
                                title: "Day \(trialDays)",
                                subtitle: "You're charged \(priceText)/month",
                                showConnector: false
                            )
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Theme.cardSurface)
                        )
                    }

                    Button {
                        Task {
                            isLoading = true
                            defer { isLoading = false }
                            let success = await subscriptionManager.purchaseMonthly()
                            if success {
                                dismiss()
                            } else {
                                errorMessage = "Purchase was not completed."
                            }
                        }
                    } label: {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text(primaryActionTitle)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isLoading || !isPurchaseReady)

                    Button("Restore Purchases") {
                        Task {
                            isLoading = true
                            defer { isLoading = false }
                            let success = await subscriptionManager.restore()
                            if success {
                                dismiss()
                            } else {
                                errorMessage = "No active subscription was found to restore."
                            }
                        }
                    }
                    .disabled(isLoading)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(20)
            }
            .toolbar {
                if isDismissible {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Close") { dismiss() }
                    }
                }
            }
            .interactiveDismissDisabled(!isDismissible)
            .task {
                await subscriptionManager.ensureProductsLoaded()
                await refreshIntroOfferEligibility()
            }
        }
    }

    private var monthlyPriceText: String? {
        subscriptionManager.monthlyPriceText
    }

    private var isPurchaseReady: Bool {
        subscriptionManager.monthlyProduct != nil
    }

    private var primaryActionTitle: String {
        guard let monthlyPriceText else {
            return "Loading App Store pricing…"
        }
        return "Subscribe for \(monthlyPriceText)/month"
    }

    private var paywallSubtitle: String {
        return "Cancel anytime. Subscription auto-renews monthly."
    }

    private var introductoryTrialLengthText: String? {
        guard
            let introOffer = subscriptionManager.monthlyProduct?.subscription?.introductoryOffer,
            introOffer.paymentMode == .freeTrial
        else {
            return nil
        }
        return format(period: introOffer.period)
    }

    /// Total trial length expressed in days for the timeline UI.
    private var introductoryTrialDays: Int? {
        guard
            let introOffer = subscriptionManager.monthlyProduct?.subscription?.introductoryOffer,
            introOffer.paymentMode == .freeTrial
        else {
            return nil
        }
        let period = introOffer.period
        switch period.unit {
        case .day:   return period.value
        case .week:  return period.value * 7
        case .month: return period.value * 30
        case .year:  return period.value * 365
        @unknown default: return period.value
        }
    }

    private func refreshIntroOfferEligibility() async {
        guard
            let subscriptionInfo = subscriptionManager.monthlyProduct?.subscription,
            subscriptionInfo.introductoryOffer?.paymentMode == .freeTrial
        else {
            isEligibleForIntroOffer = false
            return
        }
        isEligibleForIntroOffer = await subscriptionInfo.isEligibleForIntroOffer
    }

    private func format(period: Product.SubscriptionPeriod) -> String {
        // Convert to days for clearer display (e.g. "7-day" instead of "1-week")
        let totalDays: Int
        switch period.unit {
        case .day:   totalDays = period.value
        case .week:  totalDays = period.value * 7
        case .month: totalDays = period.value * 30
        case .year:  totalDays = period.value * 365
        @unknown default: totalDays = period.value
        }
        return "\(totalDays)-day"
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(Theme.lagoon)
                .frame(width: 18)
            Text(text)
                .font(.subheadline)
            Spacer()
        }
    }

    private func trialTimelineRow(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        showConnector: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(iconColor)

                if showConnector {
                    Rectangle()
                        .fill(Theme.glassBorder)
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, showConnector ? 16 : 0)

            Spacer()
        }
    }
}

#if DEBUG
#Preview("Paywall") {
    PreviewEnvironment {
        PaywallView(isDismissible: true)
    }
}
#endif
