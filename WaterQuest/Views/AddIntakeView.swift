import SwiftUI

struct AddIntakeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: HydrationStore
    @EnvironmentObject private var healthKit: HealthKitManager
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    @State private var amount: Double = 250
    @State private var note = ""
    @State private var selectedPreset: Int?
    @State private var showSavedBanner = false

    var body: some View {
        GeometryReader { proxy in
            let topInset = proxy.safeAreaInsets.top

            ScrollView {
                VStack(spacing: 20) {
                    StretchyHeader(height: 220 + topInset) {
                        HeroHeader(topInset: topInset)
                    }
                    .padding(.top, -topInset)

                    HStack(alignment: .center, spacing: 16) {
                        MascotView(size: 64, animated: true)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Log Water")
                                .font(Theme.titleFont(size: 22))
                                .foregroundStyle(Theme.textPrimary)
                            Text("Fast, accurate intake tracking with Health integration.")
                                .font(Theme.bodyFont(size: 14))
                                .foregroundStyle(Theme.textSecondary)
                        }
                        Spacer()
                    }

                    LiquidGlassCard(cornerRadius: 24, tintColor: Theme.lagoon.opacity(0.6), isInteractive: false) {
                        VStack(alignment: .leading, spacing: 16) {
                            IntakeSectionHeader(title: "Amount", subtitle: "Drag to match your cup or bottle")

                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text("\(Int(amount))")
                                    .font(Theme.displayFont(size: 48))
                                    .foregroundStyle(Theme.textPrimary)
                                    .contentTransition(.numericText())
                                Text(store.profile.unitSystem.volumeUnit)
                                    .font(Theme.titleFont(size: 18))
                                    .foregroundStyle(Theme.textSecondary)
                                Spacer()
                            }

                            Slider(value: $amount, in: amountRange, step: amountStep)
                                .tint(Theme.lagoon)
                                .onChange(of: amount) {
                                    selectedPreset = nil
                                }
                        }
                        .padding(20)
                    }

                    LiquidGlassCard(cornerRadius: 22, tintColor: Theme.mint.opacity(0.45), isInteractive: false) {
                        VStack(alignment: .leading, spacing: 14) {
                            IntakeSectionHeader(title: "Quick Picks", subtitle: "Tap to jump to a favorite size")

                            HStack(spacing: 10) {
                                ForEach(Array(presetAmounts.enumerated()), id: \.offset) { index, preset in
                                    QuickAddPill(amount: preset, unit: store.profile.unitSystem.volumeUnit) {
                                        Haptics.selection()
                                        selectedPreset = index
                                        amount = Double(preset)
                                    }
                                    .overlay(
                                        Capsule(style: .continuous)
                                            .strokeBorder(
                                                selectedPreset == index
                                                    ? Theme.lagoon.opacity(0.9)
                                                    : Theme.glassBorder.opacity(0.5),
                                                lineWidth: selectedPreset == index ? 1.4 : 0.9
                                            )
                                    )
                                }
                            }
                        }
                        .padding(18)
                    }

                    LiquidGlassCard(cornerRadius: 22, tintColor: Theme.lavender.opacity(0.35), isInteractive: false) {
                        VStack(alignment: .leading, spacing: 12) {
                            IntakeSectionHeader(title: "Note", subtitle: "Optional context")

                            TextField("Add a quick note", text: $note, axis: .vertical)
                                .font(Theme.bodyFont(size: 15))
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(2...4)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Theme.cardElevated.opacity(0.8))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(Theme.glassBorder.opacity(0.8), lineWidth: 0.8)
                                )
                        }
                        .padding(18)
                    }

                    LiquidGlassButton("Save Intake", icon: "plus.circle.fill", style: .primary, size: .large) {
                        addIntake()
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 28)
            }
            .coordinateSpace(name: "scroll")
        }
        .navigationTitle("Log Intake")
        .background(AppWaterBackground().ignoresSafeArea())
        .overlay(alignment: .top) {
            if showSavedBanner {
                SavedBanner(amount: Int(amount), unit: store.profile.unitSystem.volumeUnit)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 8)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: showSavedBanner)
        .onAppear {
            if amount < amountRange.lowerBound || amount > amountRange.upperBound {
                amount = min(max(amount, amountRange.lowerBound), amountRange.upperBound)
            }
        }
        .dismissKeyboardOnTap()
    }

    private var amountRange: ClosedRange<Double> {
        store.profile.unitSystem == .metric ? 100...1200 : 4...40
    }

    private var amountStep: Double {
        store.profile.unitSystem == .metric ? 25 : 1
    }

    private var presetAmounts: [Int] {
        store.profile.unitSystem == .metric ? [200, 350, 500, 750] : [8, 12, 16, 24]
    }

    private func addIntake() {
        Haptics.splash()

        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let entry = store.addIntake(amount: amount, source: .manual, note: trimmed.isEmpty ? nil : trimmed)

        Task {
            if subscriptionManager.hasActiveSubscription {
                await healthKit.saveWaterIntake(ml: entry.volumeML, date: entry.date, entryID: entry.id)
            }
        }

        withAnimation {
            showSavedBanner = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation {
                showSavedBanner = false
            }
        }

        note = ""
        selectedPreset = nil
        dismiss()
    }
}

private struct StretchyHeader<Content: View>: View {
    let height: CGFloat
    let content: Content

    init(height: CGFloat, @ViewBuilder content: () -> Content) {
        self.height = height
        self.content = content()
    }

    var body: some View {
        GeometryReader { proxy in
            let minY = proxy.frame(in: .named("scroll")).minY
            let extraHeight = minY > 0 ? minY : 0

            content
                .frame(height: height + extraHeight)
                .frame(maxWidth: .infinity)
                .offset(y: extraHeight > 0 ? -extraHeight : 0)
        }
        .frame(height: height)
    }
}

private struct HeroHeader: View {
    let topInset: CGFloat

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [Theme.lagoon.opacity(0.65), Theme.mint.opacity(0.45), Color.clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay(
                WaveView()
                    .opacity(0.25)
                    .offset(y: 18)
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("Hydration Boost")
                    .font(.title.weight(.bold))
                    .foregroundStyle(.primary)
                Text("Top off your day with a quick log.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
            .padding(.top, topInset + 12)
        }
        .background(Theme.lagoon.opacity(0.2))
    }
}

private struct IntakeSectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(Theme.titleFont(size: 16))
                .foregroundStyle(Theme.textPrimary)
            Text(subtitle)
                .font(Theme.captionFont(size: 12))
                .foregroundStyle(Theme.textTertiary)
        }
    }
}

private struct SavedBanner: View {
    let amount: Int
    let unit: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Theme.mint)
            Text("Logged \(amount) \(unit)")
                .font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule(style: .continuous)
                .fill(.thinMaterial)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Theme.glassBorder, lineWidth: 1)
        )
        .shadow(color: Theme.shadowColor, radius: 8, x: 0, y: 4)
    }
}

#Preview("Add Intake") {
    PreviewEnvironment {
        AddIntakeView()
    }
}
