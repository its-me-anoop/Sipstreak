import SwiftUI

struct InsightsView: View {
    @EnvironmentObject private var store: HydrationStore

    @State private var appearAnimation = false
    @State private var selectedDayIndex: Int? = nil
    @State private var chartAnimationProgress: CGFloat = 0

    var body: some View {
        ZStack(alignment: .top) {
            // Animated background
            InsightsBackground()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    headerSection
                        .offset(y: appearAnimation ? 0 : -20)
                        .opacity(appearAnimation ? 1 : 0)

                    // Weekly chart card
                    weeklyChartCard
                        .offset(y: appearAnimation ? 0 : 20)
                        .opacity(appearAnimation ? 1 : 0)

                    // Goal breakdown card
                    goalBreakdownCard
                        .offset(y: appearAnimation ? 0 : 30)
                        .opacity(appearAnimation ? 1 : 0)

                    // Recent logs card
                    recentLogsCard
                        .offset(y: appearAnimation ? 0 : 40)
                        .opacity(appearAnimation ? 1 : 0)

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            withAnimation(Theme.fluidSpring.delay(0.1)) {
                appearAnimation = true
            }
            withAnimation(.easeOut(duration: 1.2).delay(0.3)) {
                chartAnimationProgress = 1
            }
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Insights")
                    .font(Theme.titleFont(size: 28))
                    .foregroundColor(Theme.textPrimary)

                Text("Track your hydration journey")
                    .font(Theme.bodyFont(size: 14))
                    .foregroundColor(Theme.textSecondary)
            }

            Spacer()

            // Stats icon
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Circle()
                            .fill(Theme.mint.opacity(0.2))
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(Theme.glassBorder, lineWidth: 1)
                    )

                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Theme.mint)
            }
            .frame(width: 44, height: 44)
            .shadow(color: Theme.mint.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }

    // MARK: - Weekly Chart Card
    private var weeklyChartCard: some View {
        LiquidGlassCard(cornerRadius: 24, tintColor: Theme.lagoon.opacity(0.5), isInteractive: false) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "calendar")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.lagoon)

                    Text("Last 7 Days")
                        .font(Theme.titleFont(size: 18))
                        .foregroundColor(Theme.textPrimary)

                    Spacer()

                    // Average indicator
                    let avgML = lastSevenDays.map { $0.totalML }.reduce(0, +) / 7
                    Text("Avg: \(Formatters.shortVolume(ml: avgML, unit: store.profile.unitSystem)) \(store.profile.unitSystem.volumeUnit)")
                        .font(Theme.bodyFont(size: 12))
                        .foregroundColor(Theme.textSecondary)
                }

                // Bar chart
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(Array(lastSevenDays.enumerated()), id: \.element.date) { index, day in
                        DayBarView(
                            day: day,
                            goalML: store.dailyGoal.totalML,
                            unitSystem: store.profile.unitSystem,
                            isSelected: selectedDayIndex == index,
                            animationProgress: chartAnimationProgress
                        ) {
                            withAnimation(Theme.quickSpring) {
                                if selectedDayIndex == index {
                                    selectedDayIndex = nil
                                } else {
                                    selectedDayIndex = index
                                    Haptics.selection()
                                }
                            }
                        }
                    }
                }
                .frame(height: 140)

                // Selected day detail
                if let index = selectedDayIndex, index < lastSevenDays.count {
                    let day = lastSevenDays[index]
                    HStack {
                        Image(systemName: "drop.fill")
                            .foregroundColor(Theme.lagoon)
                        Text(fullDateFormatter.string(from: day.date))
                            .font(Theme.bodyFont(size: 13))
                            .foregroundColor(Theme.textSecondary)
                        Spacer()
                        Text(Formatters.volumeString(ml: day.totalML, unit: store.profile.unitSystem))
                            .font(Theme.titleFont(size: 16))
                            .foregroundColor(Theme.textPrimary)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Theme.glassLight)
                    )
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95)),
                        removal: .opacity
                    ))
                }
            }
            .padding(20)
        }
    }

    // MARK: - Goal Breakdown Card
    private var goalBreakdownCard: some View {
        LiquidGlassCard(cornerRadius: 24, tintColor: Theme.sun.opacity(0.5), isInteractive: false) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "target")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.sun)

                    Text("Goal Breakdown")
                        .font(Theme.titleFont(size: 18))
                        .foregroundColor(Theme.textPrimary)

                    Spacer()
                }

                let goal = store.dailyGoal

                // Visual breakdown
                VStack(spacing: 10) {
                    GoalBreakdownRow(
                        icon: "figure.stand",
                        label: "Base (body weight)",
                        value: goal.baseML,
                        color: Theme.lagoon,
                        unitSystem: store.profile.unitSystem
                    )

                    GoalBreakdownRow(
                        icon: "sun.max.fill",
                        label: "Weather adjustment",
                        value: goal.weatherAdjustmentML,
                        color: Theme.coral,
                        unitSystem: store.profile.unitSystem
                    )

                    GoalBreakdownRow(
                        icon: "figure.run",
                        label: "Workout adjustment",
                        value: goal.workoutAdjustmentML,
                        color: Theme.mint,
                        unitSystem: store.profile.unitSystem
                    )

                    // Divider
                    WaveDivider()
                        .frame(height: 16)

                    // Total
                    HStack {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Theme.sun)

                        Text("Daily Target")
                            .font(Theme.bodyFont(size: 15))
                            .fontWeight(.medium)
                            .foregroundColor(Theme.textPrimary)

                        Spacer()

                        Text(Formatters.volumeString(ml: goal.totalML, unit: store.profile.unitSystem))
                            .font(Theme.titleFont(size: 20))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Theme.sun, Theme.coral],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.35, dampingFraction: 0.82), value: goal.totalML)
                    }
                    .padding(.top, 4)
                }
            }
            .padding(20)
        }
    }

    // MARK: - Recent Logs Card
    private var recentLogsCard: some View {
        LiquidGlassCard(cornerRadius: 24, tintColor: Theme.mint.opacity(0.5), isInteractive: false) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.mint)

                    Text("Recent Logs")
                        .font(Theme.titleFont(size: 18))
                        .foregroundColor(Theme.textPrimary)

                    Spacer()

                    Text("\(recentEntries.count) entries")
                        .font(Theme.bodyFont(size: 12))
                        .foregroundColor(Theme.textTertiary)
                }

                if recentEntries.isEmpty {
                    // Empty state
                    VStack(spacing: 12) {
                        Image(systemName: "drop.triangle")
                            .font(.system(size: 32))
                            .foregroundColor(Theme.textTertiary)

                        Text("No entries yet")
                            .font(Theme.bodyFont(size: 14))
                            .foregroundColor(Theme.textTertiary)

                        Text("Log your first drink to see it here")
                            .font(Theme.bodyFont(size: 12))
                            .foregroundColor(Theme.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else {
                    ForEach(Array(recentEntries.enumerated()), id: \.element.id) { index, entry in
                        RecentLogRow(entry: entry, unitSystem: store.profile.unitSystem)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .trailing)),
                                removal: .opacity
                            ))

                        if index < recentEntries.count - 1 {
                            Rectangle()
                                .fill(Theme.glassBorder.opacity(0.4))
                                .frame(height: 1)
                        }
                    }
                }
            }
            .padding(20)
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.82), value: recentEntries.count)
    }

    // MARK: - Data
    private var lastSevenDays: [(date: Date, label: String, totalML: Double)] {
        let calendar = Calendar.current
        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: Date()) else { return nil }
            let total = store.entries.filter { $0.date.isSameDay(as: date) }.reduce(0) { $0 + $1.volumeML }
            let label = DateFormatter.shortWeekday.string(from: date)
            return (date, label, total)
        }.reversed()
    }

    private var recentEntries: [HydrationEntry] {
        store.entries.sorted { $0.date > $1.date }.prefix(8).map { $0 }
    }

    private var fullDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter
    }
}

// MARK: - Day Bar View
private struct DayBarView: View {
    let day: (date: Date, label: String, totalML: Double)
    let goalML: Double
    let unitSystem: UnitSystem
    let isSelected: Bool
    let animationProgress: CGFloat
    let onTap: () -> Void

    @State private var isPressed = false

    private var progress: CGFloat {
        min(1, CGFloat(day.totalML / max(1, goalML)))
    }

    private var barColor: Color {
        if progress >= 1 {
            return Theme.mint
        } else if progress >= 0.5 {
            return Theme.lagoon
        } else {
            return Theme.coral.opacity(0.7)
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack(alignment: .bottom) {
                    // Background bar
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Theme.glassLight)
                        .frame(height: 100)

                    // Progress bar
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [barColor.opacity(0.6), barColor],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(height: max(4, 100 * progress * animationProgress))

                    // Goal line
                    Rectangle()
                        .fill(Theme.sun.opacity(0.6))
                        .frame(height: 2)
                        .offset(y: -100 + 4)
                }
                .frame(maxWidth: .infinity)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(isSelected ? Theme.lagoon : Color.clear, lineWidth: 2)
                )

                Text(day.label)
                    .font(Theme.bodyFont(size: 11))
                    .foregroundColor(isSelected ? Theme.textPrimary : Theme.textSecondary)
            }
            .scaleEffect(isPressed ? 0.95 : 1)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(Theme.quickSpring) { isPressed = true }
                }
                .onEnded { _ in
                    withAnimation(Theme.quickSpring) { isPressed = false }
                }
        )
    }
}

// MARK: - Goal Breakdown Row
private struct GoalBreakdownRow: View {
    let icon: String
    let label: String
    let value: Double
    let color: Color
    let unitSystem: UnitSystem

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 32, height: 32)

                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(color)
            }

            Text(label)
                .font(Theme.bodyFont(size: 14))
                .foregroundColor(Theme.textSecondary)

            Spacer()

            Text(value >= 0 ? "+" : "")
                .font(Theme.bodyFont(size: 14))
                .foregroundColor(value >= 0 ? Theme.mint : Theme.coral) +
            Text(Formatters.shortVolume(ml: abs(value), unit: unitSystem))
                .font(Theme.bodyFont(size: 14))
                .foregroundColor(value >= 0 ? Theme.mint : Theme.coral) +
            Text(" \(unitSystem.volumeUnit)")
                .font(Theme.bodyFont(size: 12))
                .foregroundColor(Theme.textTertiary)
        }
    }
}

// MARK: - Recent Log Row
private struct RecentLogRow: View {
    let entry: HydrationEntry
    let unitSystem: UnitSystem

    @State private var isPressed = false

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        return formatter
    }

    private var sourceIcon: String {
        switch entry.source {
        case .manual:
            return "hand.tap.fill"
        case .healthKit:
            return "heart.fill"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Source icon
            ZStack {
                Circle()
                    .fill(Theme.lagoon.opacity(0.2))
                    .frame(width: 36, height: 36)

                Image(systemName: sourceIcon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Theme.lagoon)
            }

            // Time and source
            VStack(alignment: .leading, spacing: 2) {
                Text(timeFormatter.string(from: entry.date))
                    .font(Theme.bodyFont(size: 13))
                    .foregroundColor(Theme.textPrimary)

                Text(entry.source.rawValue.capitalized)
                    .font(Theme.bodyFont(size: 11))
                    .foregroundColor(Theme.textTertiary)
            }

            Spacer()

            // Volume
            Text(Formatters.volumeString(ml: entry.volumeML, unit: unitSystem))
                .font(Theme.titleFont(size: 16))
                .foregroundColor(Theme.mint)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Insights Background
private struct InsightsBackground: View {
    @State private var wavePhase: CGFloat = 0

    var body: some View {
        ZStack {
            Theme.background

            // Subtle gradient overlay
            LinearGradient(
                colors: [
                    Theme.mint.opacity(0.05),
                    Color.clear,
                    Theme.lagoon.opacity(0.03)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Animated wave at bottom
            VStack {
                Spacer()
                WaveShape(phase: wavePhase, strength: 12)
                    .fill(Theme.lagoon.opacity(0.06))
                    .frame(height: 120)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                wavePhase = .pi * 2
            }
        }
    }
}

private extension DateFormatter {
    static let shortWeekday: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }()
}

#Preview("Insights") {
    PreviewEnvironment {
        InsightsView()
    }
}
