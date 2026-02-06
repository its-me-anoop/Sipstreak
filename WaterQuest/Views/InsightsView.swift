import SwiftUI
import Charts

struct InsightsView: View {
    @EnvironmentObject private var store: HydrationStore
    @State private var selectedDate: Date?

    private var weeklyData: [WeeklyDay] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -(6 - offset), to: today) else {
                return nil
            }

            let total = store.entries
                .filter { calendar.isDate($0.date, inSameDayAs: day) }
                .reduce(0) { $0 + $1.volumeML }

            return WeeklyDay(date: day, totalML: total)
        }
    }

    private var weeklyAverageML: Double {
        let totals = weeklyData.map(\.totalML)
        guard !totals.isEmpty else { return 0 }
        return totals.reduce(0, +) / Double(totals.count)
    }

    private var daysGoalMet: Int {
        let target = max(1, store.dailyGoal.totalML)
        return weeklyData.filter { $0.totalML >= target }.count
    }

    private var selectedDay: WeeklyDay? {
        guard let selectedDate else { return nil }
        return weeklyData.first(where: { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) })
    }

    var body: some View {
        List {
            Section {
                headerSummary
            }

            Section("Weekly Intake") {
                chartSection
            }

            Section("Goal Breakdown") {
                breakdownSection
            }

            Section("Recent Entries") {
                recentEntriesSection
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppWaterBackground().ignoresSafeArea())
        .navigationTitle("Insights")
    }

    private var headerSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your hydration trend")
                .font(.title3.weight(.semibold))

            HStack(spacing: 14) {
                MetricTile(title: "Today", value: Formatters.percentString(min(1, store.todayTotalML / max(1, store.dailyGoal.totalML))), icon: "drop.fill", color: Theme.lagoon)
                MetricTile(title: "7-day avg", value: Formatters.volumeString(ml: weeklyAverageML, unit: store.profile.unitSystem), icon: "chart.bar.fill", color: Theme.mint)
                MetricTile(title: "Goal days", value: "\(daysGoalMet)/7", icon: "checkmark.circle.fill", color: Theme.sun)
            }
        }
        .padding(.vertical, 8)
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Chart(weeklyData) { day in
                BarMark(
                    x: .value("Day", day.date, unit: .day),
                    y: .value("Intake", day.totalML)
                )
                .foregroundStyle(day.totalML >= store.dailyGoal.totalML ? Theme.mint : Theme.lagoon)
                .cornerRadius(4)
            }
            .frame(height: 190)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartXSelection(value: $selectedDate)

            if let selectedDay {
                HStack {
                    Text(selectedDay.date, format: .dateTime.weekday(.wide).month().day())
                        .font(.subheadline)
                    Spacer()
                    Text(Formatters.volumeString(ml: selectedDay.totalML, unit: store.profile.unitSystem))
                        .font(.subheadline.weight(.semibold))
                }
            } else {
                Text("Select a bar to view details")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    private var breakdownSection: some View {
        let goal = store.dailyGoal

        return VStack(spacing: 10) {
            BreakdownRow(title: "Base goal", value: goal.baseML, unitSystem: store.profile.unitSystem, icon: "figure.stand", tint: Theme.lagoon)
            BreakdownRow(title: "Weather adjustment", value: goal.weatherAdjustmentML, unitSystem: store.profile.unitSystem, icon: "cloud.sun", tint: Theme.sun)
            BreakdownRow(title: "Workout adjustment", value: goal.workoutAdjustmentML, unitSystem: store.profile.unitSystem, icon: "figure.run", tint: Theme.coral)

            Divider()

            HStack {
                Label("Daily target", systemImage: "target")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(Formatters.volumeString(ml: goal.totalML, unit: store.profile.unitSystem))
                    .font(.headline)
            }
        }
        .padding(.vertical, 6)
    }

    private var recentEntriesSection: some View {
        let recent = store.entries.sorted { $0.date > $1.date }.prefix(8)

        return Group {
            if recent.isEmpty {
                Text("No entries yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(recent)) { entry in
                    HStack(spacing: 12) {
                        Image(systemName: entry.source == .healthKit ? "heart.fill" : "drop.fill")
                            .foregroundStyle(entry.source == .healthKit ? Theme.coral : Theme.lagoon)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(Formatters.volumeString(ml: entry.volumeML, unit: store.profile.unitSystem))
                            Text(entry.date, style: .time)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(entry.date, format: .dateTime.month(.abbreviated).day())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

private struct WeeklyDay: Identifiable {
    let id = UUID()
    let date: Date
    let totalML: Double
}

private struct MetricTile: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.cardSurface)
        )
    }
}

private struct BreakdownRow: View {
    let title: String
    let value: Double
    let unitSystem: UnitSystem
    let icon: String
    let tint: Color

    var body: some View {
        HStack {
            Label(title, systemImage: icon)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer()
            Text("\(value >= 0 ? "+" : "-")\(Formatters.shortVolume(ml: abs(value), unit: unitSystem)) \(unitSystem.volumeUnit)")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(tint)
        }
    }
}

#Preview("Insights") {
    PreviewEnvironment {
        InsightsView()
    }
}
