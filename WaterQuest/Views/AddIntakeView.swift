import SwiftUI

struct AddIntakeView: View {
    @EnvironmentObject private var store: HydrationStore
    @EnvironmentObject private var healthKit: HealthKitManager

    @State private var amount: Double = 250
    @State private var note: String = ""
    @State private var showingSuccess = false
    @State private var selectedPreset: Int? = nil
    @State private var dropletOffset: CGFloat = -100
    @State private var wavePhase: CGFloat = 0
    @State private var glowIntensity: CGFloat = 0
    @State private var appearAnimation = false

    var body: some View {
        ZStack(alignment: .top) {
            // Animated background
            AnimatedWaterBackground()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Header with animated droplet
                    headerSection
                        .offset(y: appearAnimation ? 0 : -30)
                        .opacity(appearAnimation ? 1 : 0)

                    // Main amount display card
                    amountCard
                        .offset(y: appearAnimation ? 0 : 30)
                        .opacity(appearAnimation ? 1 : 0)

                    // Preset buttons
                    presetButtons
                        .offset(y: appearAnimation ? 0 : 30)
                        .opacity(appearAnimation ? 1 : 0)

                    // Note field
                    noteSection
                        .offset(y: appearAnimation ? 0 : 30)
                        .opacity(appearAnimation ? 1 : 0)

                    // Add button
                    addButton
                        .offset(y: appearAnimation ? 0 : 40)
                        .opacity(appearAnimation ? 1 : 0)

                    Spacer(minLength: 40)
                }
                .padding(.top, 20)
                .padding(.horizontal, 20)
            }

            // Success overlay
            if showingSuccess {
                successOverlay
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            withAnimation(Theme.fluidSpring.delay(0.1)) {
                appearAnimation = true
            }
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                wavePhase = .pi * 2
            }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                glowIntensity = 1
            }
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Animated water droplet
            ZStack {
                // Glow effect
                Circle()
                    .fill(Theme.lagoon.opacity(0.2 * glowIntensity))
                    .frame(width: 100, height: 100)
                    .blur(radius: 20)

                // Droplet icon
                Image(systemName: "drop.fill")
                    .font(.system(size: 50, weight: .regular))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Theme.lagoon, Theme.mint],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Theme.lagoon.opacity(0.5), radius: 10, x: 0, y: 5)
            }

            Text("Log a Drink")
                .font(Theme.titleFont(size: 28))
                .foregroundColor(Theme.textPrimary)

            Text("Stay hydrated, stay healthy")
                .font(Theme.bodyFont(size: 14))
                .foregroundColor(Theme.textSecondary)
        }
    }

    // MARK: - Amount Card
    private var amountCard: some View {
        LiquidGlassCard(cornerRadius: 28, tintColor: Theme.lagoon, isInteractive: false) {
            VStack(spacing: 20) {
                // Amount label
                Text("Amount (\(store.profile.unitSystem.volumeUnit))")
                    .font(Theme.bodyFont(size: 14))
                    .foregroundColor(Theme.textSecondary)

                // Large amount display
                ZStack {
                    // Background wave effect
                    WaveShape(phase: wavePhase, strength: 8)
                        .fill(Theme.lagoon.opacity(0.15))
                        .frame(height: 60)
                        .offset(y: 20)
                        .mask(
                            RoundedRectangle(cornerRadius: 16)
                                .frame(width: 180, height: 80)
                        )

                    Text(String(format: "%.0f", amount))
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Theme.textPrimary, Theme.lagoon],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: amount)
                }

                // Slider with custom styling
                VStack(spacing: 8) {
                    Slider(value: $amount, in: amountRange, step: amountStep) { editing in
                        if editing {
                            Haptics.selection()
                        } else {
                            Haptics.impact(.light)
                        }
                    }
                    .tint(Theme.lagoon)

                    // Range labels
                    HStack {
                        Text(String(format: "%.0f", amountRange.lowerBound))
                            .font(Theme.bodyFont(size: 11))
                            .foregroundColor(Theme.textTertiary)
                        Spacer()
                        Text(String(format: "%.0f", amountRange.upperBound))
                            .font(Theme.bodyFont(size: 11))
                            .foregroundColor(Theme.textTertiary)
                    }
                }
            }
            .padding(24)
        }
    }

    // MARK: - Preset Buttons
    private var presetButtons: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Select")
                .font(Theme.bodyFont(size: 13))
                .foregroundColor(Theme.textSecondary)
                .padding(.leading, 4)

            HStack(spacing: 10) {
                ForEach(Array(presetAmounts.enumerated()), id: \.element) { index, preset in
                    PresetAmountButton(
                        amount: preset,
                        unit: store.profile.unitSystem.volumeUnit,
                        isSelected: selectedPreset == index
                    ) {
                        withAnimation(Theme.quickSpring) {
                            selectedPreset = index
                            amount = Double(preset)
                        }
                        Haptics.waterDrop()
                    }
                }
            }
        }
    }

    // MARK: - Note Section
    private var noteSection: some View {
        LiquidGlassCard(cornerRadius: 20, isInteractive: false) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Add a note (optional)")
                    .font(Theme.bodyFont(size: 13))
                    .foregroundColor(Theme.textSecondary)

                TextField("e.g., Morning coffee, Post-workout...", text: $note)
                    .font(Theme.bodyFont(size: 15))
                    .foregroundColor(Theme.textPrimary)
                    .tint(Theme.lagoon)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Theme.glassLight)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Theme.glassBorder.opacity(0.4), lineWidth: 1)
                    )
            }
            .padding(18)
        }
    }

    // MARK: - Add Button
    private var addButton: some View {
        LiquidGlassButton(
            "Add to Quest Log",
            icon: "plus.circle.fill",
            style: .primary,
            size: .large
        ) {
            addIntake()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Success Overlay
    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                // Animated checkmark
                ZStack {
                    Circle()
                        .fill(Theme.mint.opacity(0.2))
                        .frame(width: 100, height: 100)
                        .scaleEffect(showingSuccess ? 1.2 : 0.8)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Theme.mint, Theme.lagoon],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(showingSuccess ? 1 : 0)
                }

                Text("Logged!")
                    .font(Theme.titleFont(size: 24))
                    .foregroundColor(Theme.textPrimary)

                Text("+\(String(format: "%.0f", amount)) \(store.profile.unitSystem.volumeUnit)")
                    .font(Theme.bodyFont(size: 16))
                    .foregroundColor(Theme.textSecondary)
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 30)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 30)
                            .fill(Theme.liquidGlassGradient)
                    )
            )
            .scaleEffect(showingSuccess ? 1 : 0.8)
            .opacity(showingSuccess ? 1 : 0)
        }
        .animation(Theme.fluidSpring, value: showingSuccess)
    }

    // MARK: - Helpers
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

        withAnimation(Theme.fluidSpring) {
            showingSuccess = true
        }

        let entry = withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
            store.addIntake(amount: amount, source: .manual)
        }

        Task {
            await healthKit.saveWaterIntake(ml: entry.volumeML, date: entry.date, entryID: entry.id)
        }

        // Reset after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(Theme.fluidSpring) {
                showingSuccess = false
            }
            note = ""
            selectedPreset = nil
        }
    }
}

// MARK: - Preset Amount Button
private struct PresetAmountButton: View {
    let amount: Int
    let unit: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isPressed = false
    @State private var rippleScale: CGFloat = 0
    @State private var rippleOpacity: CGFloat = 0

    var body: some View {
        Button(action: {
            triggerRipple()
            action()
        }) {
            ZStack {
                // Ripple effect
                Circle()
                    .fill(Theme.lagoon.opacity(rippleOpacity))
                    .scaleEffect(rippleScale)

                // Content
                VStack(spacing: 4) {
                    Text("\(amount)")
                        .font(Theme.titleFont(size: 18))
                        .foregroundColor(Theme.textPrimary)

                    Text(unit)
                        .font(Theme.bodyFont(size: 11))
                        .foregroundColor(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(isSelected ? Theme.lagoon.opacity(0.35) : Theme.lagoon.opacity(0.15))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(
                                    isSelected ? Theme.lagoon.opacity(0.6) : Theme.glassBorder,
                                    lineWidth: isSelected ? 2 : 1
                                )
                        )
                )
                .shadow(color: isSelected ? Theme.lagoon.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.92 : (isSelected ? 1.02 : 1.0))
        .animation(Theme.quickSpring, value: isPressed)
        .animation(Theme.quickSpring, value: isSelected)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }

    private func triggerRipple() {
        rippleScale = 0.5
        rippleOpacity = 0.4
        withAnimation(.easeOut(duration: 0.5)) {
            rippleScale = 2.5
            rippleOpacity = 0
        }
    }
}

// MARK: - Animated Water Background
private struct AnimatedWaterBackground: View {
    @State private var phase1: CGFloat = 0
    @State private var phase2: CGFloat = 0

    var body: some View {
        ZStack {
            Theme.background

            // Multiple wave layers for depth
            VStack {
                Spacer()

                ZStack {
                    WaveShape(phase: phase1, strength: 15)
                        .fill(Theme.lagoon.opacity(0.08))
                        .frame(height: 200)

                    WaveShape(phase: phase2, strength: 10)
                        .fill(Theme.mint.opacity(0.05))
                        .frame(height: 180)
                        .offset(y: 20)
                }
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
                phase1 = .pi * 2
            }
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                phase2 = .pi * 2
            }
        }
    }
}

#Preview("Add Intake") {
    PreviewEnvironment {
        AddIntakeView()
    }
}
