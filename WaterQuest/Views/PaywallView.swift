import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    /// When `true` the sheet can be dismissed without purchasing (post-trial launch paywall).
    var isDismissible: Bool = true

    @State private var isPurchasing = false
    @State private var purchaseError: String?
    @State private var restoreSuccess = false
    @State private var appearAnimation = false
    @State private var wavePhase: CGFloat = 0

    var body: some View {
        ZStack {
            PaywallBackground(wavePhase: wavePhase)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    dismissButton
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.top, 8)

                    iconAndTitle
                        .opacity(appearAnimation ? 1 : 0)
                        .offset(y: appearAnimation ? 0 : -16)

                    featureList
                        .opacity(appearAnimation ? 1 : 0)
                        .offset(y: appearAnimation ? 0 : 12)

                    pricingCards
                        .opacity(appearAnimation ? 1 : 0)
                        .offset(y: appearAnimation ? 0 : 20)

                    purchaseButton
                        .opacity(appearAnimation ? 1 : 0)

                    if let error = purchaseError {
                        Text(error)
                            .font(Theme.bodyFont(size: 13))
                            .foregroundColor(Theme.coral)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .transition(.opacity)
                    }

                    restoreButton

                    Spacer(minLength: 32)
                }
                .padding(.horizontal, 24)
            }
        }
        .onAppear {
            withAnimation(Theme.fluidSpring.delay(0.15)) {
                appearAnimation = true
            }
            withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
                wavePhase = .pi * 2
            }
        }
    }

    // MARK: - Dismiss Button
    @ViewBuilder
    private var dismissButton: some View {
        if isDismissible {
            Button(action: { dismissPaywall() }) {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                }
                .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Icon & Title
    private var iconAndTitle: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Theme.lagoon.opacity(0.3), Theme.mint.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: "drop.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Theme.lagoon, Theme.mint],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: Theme.lagoon.opacity(0.4), radius: 12, x: 0, y: 6)
            }

            Text("WaterQuest Pro")
                .font(Theme.titleFont(size: 28))
                .foregroundColor(Theme.textPrimary)

            Text("Unlock your full hydration journey")
                .font(Theme.bodyFont(size: 15))
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Feature List
    private var featureList: some View {
        LiquidGlassCard(cornerRadius: 22, tintColor: Theme.mint.opacity(0.3), isInteractive: false) {
            VStack(alignment: .leading, spacing: 14) {
                featureRow(icon: "chart.line.uptrend.xyaxis", text: "7-day weekly chart & goal breakdown")
                featureRow(icon: "clock.fill",                 text: "Full hydration log history")
                featureRow(icon: "trophy.fill",                text: "Quests, achievements & streak rewards")
                featureRow(icon: "sparkles",                   text: "AI-powered hydration tips")
                featureRow(icon: "sun.max.fill",               text: "Weather & workout goal adjustments")
                featureRow(icon: "bell.fill",                  text: "Smart reminder scheduling")
            }
            .padding(20)
        }
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.mint.opacity(0.18))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.mint)
            }
            Text(text)
                .font(Theme.bodyFont(size: 14))
                .foregroundColor(Theme.textPrimary)
            Spacer()
        }
    }

    // MARK: - Pricing Cards
    private var pricingCards: some View {
        VStack(spacing: 12) {
            // Annual (Best Value) first
            if let annual = subscriptionManager.annualProduct {
                PricingCard(
                    product: annual,
                    isAnnual: true,
                    isBestValue: true,
                    isSelected: selectedProduct?.id == annual.id,
                    onSelect: { selectedProduct = annual }
                )
            }

            // Monthly
            if let monthly = subscriptionManager.monthlyProduct {
                PricingCard(
                    product: monthly,
                    isAnnual: false,
                    isBestValue: false,
                    isSelected: selectedProduct?.id == monthly.id,
                    onSelect: { selectedProduct = monthly }
                )
            }

            // Fallback while products are loading
            if subscriptionManager.products.isEmpty {
                ProgressView()
                    .tint(Theme.mint)
                    .padding(.vertical, 24)
            }
        }
    }

    // MARK: - Selected Product State
    @State private var selectedProduct: Product? = nil

    private func resolveSelected() -> Product? {
        // Default to annual if nothing explicitly selected
        selectedProduct ?? subscriptionManager.annualProduct ?? subscriptionManager.monthlyProduct
    }

    // MARK: - Purchase Button
    @ViewBuilder
    private var purchaseButton: some View {
        if let product = resolveSelected() {
            Button(action: { doPurchase(product) }) {
                HStack(spacing: 8) {
                    if isPurchasing {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.85)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    Text(isPurchasing ? "Processing…" : "Subscribe – \(product.displayPrice)")
                        .font(Theme.titleFont(size: 17))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Theme.lagoon, Theme.mint],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .shadow(color: Theme.lagoon.opacity(0.4), radius: 12, x: 0, y: 6)
            }
            .buttonStyle(.plain)
            .disabled(isPurchasing)
            .scaleEffect(isPurchasing ? 0.97 : 1)
            .animation(Theme.quickSpring, value: isPurchasing)
        }
    }

    // MARK: - Restore Button
    private var restoreButton: some View {
        Button(action: doRestore) {
            Text(restoreSuccess ? "Restored!" : "Restore Previous Purchase")
                .font(Theme.bodyFont(size: 13))
                .foregroundColor(restoreSuccess ? Theme.mint : Theme.textTertiary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions
    private func doPurchase(_ product: Product) {
        isPurchasing = true
        purchaseError = nil
        Haptics.impact(.medium)

        Task {
            let success = await subscriptionManager.purchase(product)
            isPurchasing = false
            if success {
                Haptics.success()
                dismissPaywall()
            } else {
                purchaseError = "Purchase was not completed. Please try again."
                Haptics.error()
            }
        }
    }

    private func doRestore() {
        isPurchasing = true
        purchaseError = nil
        Haptics.selection()

        Task {
            let success = await subscriptionManager.restore()
            isPurchasing = false
            if success {
                restoreSuccess = true
                Haptics.success()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    dismissPaywall()
                }
            } else {
                purchaseError = "No previous purchase found to restore."
                Haptics.warning()
            }
        }
    }

    private func dismissPaywall() {
        // Uses the environment dismiss action; works both as a sheet and full-screen cover.
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        // Programmatic dismiss via presentation callback set by the caller.
        PaywallDismissAction.shared.dismiss?()
    }
}

// MARK: - PricingCard
private struct PricingCard: View {
    let product: Product
    let isAnnual: Bool
    let isBestValue: Bool
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isPressed = false

    /// Per-month price string derived from the annual product's display price.
    /// We show it only on the annual card and derive it from the raw Decimal price.
    private var perMonthText: String? {
        guard isAnnual else { return nil }
        let monthly = product.price / 12
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        // System locale already reflects the user's preferred currency formatting.
        return formatter.string(from: NSDecimalNumber(decimal: monthly))
    }

    var body: some View {
        Button(action: {
            onSelect()
            Haptics.selection()
        }) {
            VStack(spacing: 0) {
                // "Best Value" badge
                if isBestValue {
                    bestValueBadge
                }

                HStack(alignment: .center, spacing: 12) {
                    // Period icon
                    ZStack {
                        Circle()
                            .fill(isSelected ? Theme.lagoon.opacity(0.3) : Color.white.opacity(0.08))
                            .frame(width: 44, height: 44)
                        Image(systemName: isAnnual ? "calendar" : "clock")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(isSelected ? Theme.lagoon : Theme.textSecondary)
                    }

                    // Labels
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isAnnual ? "Yearly" : "Monthly")
                            .font(Theme.titleFont(size: 16))
                            .foregroundColor(Theme.textPrimary)

                        if let perMonth = perMonthText {
                            Text("\(perMonth) / month")
                                .font(Theme.bodyFont(size: 12))
                                .foregroundColor(Theme.textTertiary)
                        }
                    }

                    Spacer()

                    // Price
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(product.displayPrice)
                            .font(Theme.titleFont(size: 20))
                            .foregroundColor(Theme.textPrimary)
                        Text(isAnnual ? "/ year" : "/ month")
                            .font(Theme.bodyFont(size: 11))
                            .foregroundColor(Theme.textTertiary)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
            }
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(isSelected ? Theme.lagoon.opacity(0.15) : Color.white.opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .strokeBorder(
                                isSelected ? Theme.lagoon.opacity(0.6) : Color.white.opacity(0.12),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
            .shadow(color: isSelected ? Theme.lagoon.opacity(0.25) : .clear, radius: 8, x: 0, y: 4)
            .scaleEffect(isPressed ? 0.97 : 1)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded   { _ in isPressed = false }
        )
        .animation(Theme.quickSpring, value: isPressed)
        .animation(Theme.quickSpring, value: isSelected)
    }

    private var bestValueBadge: some View {
        HStack {
            Spacer()
            Text("Best Value")
                .font(Theme.bodyFont(size: 11))
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.vertical, 4)
                .padding(.horizontal, 14)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Theme.sun, Theme.coral],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
            Spacer()
        }
        .padding(.top, 10)
        .padding(.bottom, 4)
    }
}

// MARK: - PaywallDismissAction
/// Simple singleton that lets PaywallView dismiss itself regardless of how it was presented.
final class PaywallDismissAction {
    static let shared = PaywallDismissAction()
    var dismiss: (() -> Void)?
    private init() {}
}

// MARK: - Paywall Background
private struct PaywallBackground: View {
    let wavePhase: CGFloat

    var body: some View {
        ZStack {
            Theme.background

            // Soft gradient orbs
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Theme.lagoon.opacity(0.18), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 180
                    )
                )
                .frame(width: 360, height: 360)
                .offset(x: -80, y: -60)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Theme.mint.opacity(0.12), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 140
                    )
                )
                .frame(width: 280, height: 280)
                .offset(x: 120, y: 300)

            // Animated wave at the bottom
            VStack {
                Spacer()
                WaveShape(phase: wavePhase, strength: 14)
                    .fill(Theme.lagoon.opacity(0.07))
                    .frame(height: 140)
            }
        }
    }
}

// MARK: - Preview
#if DEBUG
#Preview("Paywall") {
    PreviewEnvironment {
        PaywallView(isDismissible: true)
    }
    .environmentObject(SubscriptionManager())
}
#endif
