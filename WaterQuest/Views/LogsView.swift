import SwiftUI

struct LogsView: View {
    @EnvironmentObject private var store: HydrationStore

    private let heatMapDaysCount = 28
    private let heatMapColumns = Array(repeating: GridItem(.flexible(minimum: 12), spacing: 6), count: 7)

    private var sortedEntries: [HydrationEntry] {
        store.entries.sorted { $0.date > $1.date }
    }

    private var entriesByDay: [LogDay] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: sortedEntries) { calendar.startOfDay(for: $0.date) }
        return grouped.keys.sorted(by: >).map { date in
            LogDay(date: date, entries: grouped[date, default: []].sorted { $0.date > $1.date })
        }
    }

    private var heatMapCells: [HeatMapCell] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let start = calendar.date(byAdding: .day, value: -(heatMapDaysCount - 1), to: today) else {
            return []
        }

        let dailyTotals = Dictionary(grouping: store.entries) { calendar.startOfDay(for: $0.date) }
            .mapValues { $0.reduce(0) { $0 + $1.volumeML } }

        let totalDays = heatMapDaysCount
        let days = (0..<totalDays).compactMap { offset -> HeatMapCell? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            let total = dailyTotals[calendar.startOfDay(for: day), default: 0]
            return HeatMapCell(date: day, totalML: total)
        }

        let weekday = calendar.component(.weekday, from: start)
        let leadingBlanks = (weekday - calendar.firstWeekday + 7) % 7
        let blanks = Array(repeating: HeatMapCell(date: nil, totalML: 0), count: leadingBlanks)
        return blanks + days
    }

    private var last30DaysEntries: [HydrationEntry] {
        let calendar = Calendar.current
        guard let start = calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: Date())) else {
            return []
        }
        return store.entries.filter { $0.date >= start }
    }

    private var totalLast30DaysML: Double {
        last30DaysEntries.reduce(0) { $0 + $1.volumeML }
    }

    private var averageLast30DaysML: Double {
        totalLast30DaysML / 30
    }

    private var bestDay: LogDaySummary? {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: last30DaysEntries) { calendar.startOfDay(for: $0.date) }
        let summaries = grouped.map { date, entries in
            LogDaySummary(date: date, totalML: entries.reduce(0) { $0 + $1.volumeML })
        }
        return summaries.max { $0.totalML < $1.totalML }
    }

    private var peakHourLabel: String {
        let calendar = Calendar.current
        let hourTotals = Dictionary(grouping: last30DaysEntries) { calendar.component(.hour, from: $0.date) }
            .mapValues { $0.reduce(0) { $0 + $1.volumeML } }

        guard let (hour, _) = hourTotals.max(by: { $0.value < $1.value }) else {
            return "--"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        if let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) {
            return formatter.string(from: date)
        }
        return "--"
    }

    var body: some View {
        List {
            Section {
                summarySection
            }

            Section("Heat Map") {
                heatMapSection
            }

            Section("Logs by Date") {
                if entriesByDay.isEmpty {
                    Text("No logs yet. Add your first hydration entry.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(entriesByDay) { day in
                        LogDayCard(day: day, unitSystem: store.profile.unitSystem)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppWaterBackground().ignoresSafeArea())
        .navigationTitle("Logs")
    }

    private var proContent: some View {
        List {
            Section {
                summarySection
            }

            Section("Heat Map") {
                heatMapSection
            }

            Section("Logs by Date") {
                if entriesByDay.isEmpty {
                    Text("No logs yet. Add your first hydration entry.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(entriesByDay) { day in
                        LogDayCard(day: day, unitSystem: store.profile.unitSystem)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppWaterBackground().ignoresSafeArea())
        .navigationTitle("Logs")
    }


    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Detailed insights")
                .font(.title3.weight(.semibold))

            HStack(spacing: 12) {
                InsightTile(
                    title: "Entries",
                    value: "\(last30DaysEntries.count)",
                    icon: "drop.fill",
                    color: Theme.lagoon
                )
                InsightTile(
                    title: "Avg / day",
                    value: Formatters.volumeString(ml: averageLast30DaysML, unit: store.profile.unitSystem),
                    icon: "chart.bar.fill",
                    color: Theme.mint
                )
                InsightTile(
                    title: "Peak hour",
                    value: peakHourLabel,
                    icon: "clock.fill",
                    color: Theme.sun
                )
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Top day")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let bestDay {
                        Text(bestDay.date, format: .dateTime.weekday(.abbreviated).month().day())
                            .font(.subheadline.weight(.semibold))
                    } else {
                        Text("--")
                            .font(.subheadline.weight(.semibold))
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Total (30d)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(Formatters.volumeString(ml: totalLast30DaysML, unit: store.profile.unitSystem))
                        .font(.subheadline.weight(.semibold))
                }
            }
        }
        .padding(.vertical, 6)
    }

    private var heatMapSection: some View {
        let daySymbols = weekdaySymbols
        let goal = max(1, store.dailyGoal.totalML)

        return VStack(alignment: .leading, spacing: 12) {
            Text("Last 4 weeks")
                .font(.subheadline.weight(.semibold))

            HStack(spacing: 6) {
                ForEach(daySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: heatMapColumns, spacing: 6) {
                ForEach(heatMapCells) { cell in
                    HeatMapSquare(cell: cell, goalML: goal)
                }
            }

            HStack(spacing: 8) {
                Text("Less")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HeatMapLegendSquare(intensity: 0.1)
                HeatMapLegendSquare(intensity: 0.4)
                HeatMapLegendSquare(intensity: 0.8)
                Text("More")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    private var weekdaySymbols: [String] {
        let calendar = Calendar.current
        let symbols = calendar.shortWeekdaySymbols
        let shift = calendar.firstWeekday - 1
        let reordered = Array(symbols[shift...]) + Array(symbols[..<shift])
        return reordered.map { String($0.prefix(1)) }
    }
}

private struct LogDay: Identifiable {
    let id = UUID()
    let date: Date
    let entries: [HydrationEntry]

    var totalML: Double {
        entries.reduce(0) { $0 + $1.volumeML }
    }
}

private struct LogDaySummary {
    let date: Date
    let totalML: Double
}

private struct HeatMapCell: Identifiable {
    let id = UUID()
    let date: Date?
    let totalML: Double
}

private struct InsightTile: View {
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

private struct HeatMapSquare: View {
    let cell: HeatMapCell
    let goalML: Double

    var body: some View {
        if let date = cell.date {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(heatColor(for: cell.totalML, goalML: goalML))
                .frame(height: 16)
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(Theme.glassBorder.opacity(0.8), lineWidth: 0.6)
                )
                .accessibilityLabel(Text(date, format: .dateTime.month().day()))
        } else {
            Color.clear
                .frame(height: 16)
        }
    }

    private func heatColor(for totalML: Double, goalML: Double) -> Color {
        let ratio = min(1, totalML / max(1, goalML))
        let base = Theme.lagoon.opacity(0.18 + 0.6 * ratio)
        let highlight = Theme.mint.opacity(0.2 + 0.7 * ratio)
        return ratio > 0.6 ? highlight : base
    }
}

private struct HeatMapLegendSquare: View {
    let intensity: Double

    var body: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(Theme.lagoon.opacity(0.15 + intensity))
            .frame(width: 14, height: 14)
            .overlay(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(Theme.glassBorder.opacity(0.6), lineWidth: 0.6)
            )
    }
}

private struct LogDayCard: View {
    let day: LogDay
    let unitSystem: UnitSystem


    var body: some View {
        LiquidGlassCard(cornerRadius: 18, tintColor: Theme.lagoon.opacity(0.18), isInteractive: false) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(day.date, format: .dateTime.weekday(.wide).month().day())
                            .font(.subheadline.weight(.semibold))
                        Text("\(day.entries.count) entries")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(Formatters.volumeString(ml: day.totalML, unit: unitSystem))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                }

                ForEach(day.entries) { entry in
                    LogEntryRow(entry: entry, unitSystem: unitSystem)
                }
            }
            .padding(14)
        }
    }
}

private struct LogEntryRow: View {
    let entry: HydrationEntry
    let unitSystem: UnitSystem

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(entryTint.opacity(0.2))
                    .frame(width: 30, height: 30)
                Image(systemName: entryIcon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(entryTint)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(Formatters.volumeString(ml: entry.volumeML, unit: unitSystem))
                    .font(.subheadline.weight(.semibold))
                if let note = entry.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text(entry.source == .healthKit ? "Health import" : "Manual log")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(entry.date, format: .dateTime.hour().minute())
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private var entryIcon: String {
        entry.source == .healthKit ? "heart.fill" : "drop.fill"
    }

    private var entryTint: Color {
        entry.source == .healthKit ? Theme.coral : Theme.lagoon
    }
}

#if DEBUG
#Preview("Logs") {
    PreviewEnvironment {
        LogsView()
    }
}
#endif
