import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: HydrationStore
    @EnvironmentObject private var weather: WeatherClient
    @EnvironmentObject private var healthKit: HealthKitManager
    @EnvironmentObject private var locationManager: LocationManager

    @StateObject private var aiService = HydrationAIService()

    @State private var entryToEdit: HydrationEntry?
    @State private var isRefreshing = false

    private var goal: GoalBreakdown { store.dailyGoal }
    private var progress: Double { min(1, store.todayTotalML / max(1, goal.totalML)) }

    var body: some View {
        List {
            Section {
                summarySection
            }

            Section("Quick Add") {
                quickAddSection
            }

            if let tip = aiService.currentTip {
                Section("Hydration Coach") {
                    tipSection(tip)
                }
            }

            if store.profile.prefersWeatherGoal {
                Section("Weather") {
                    weatherSection
                }
            }

            Section("Today\'s Quests") {
                if store.gameState.quests.isEmpty {
                    Text("No quests available right now.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.gameState.quests) { quest in
                        QuestRow(quest: quest)
                    }
                }
            }

            Section("Today\'s Log") {
                if todayEntries.isEmpty {
                    Text("No water logged yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(todayEntries) { entry in
                        Button {
                            Haptics.selection()
                            entryToEdit = entry
                        } label: {
                            LogRow(entry: entry, unitSystem: store.profile.unitSystem)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteEntry(entry)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppWaterBackground().ignoresSafeArea())
        .navigationTitle("Today")
        .refreshable {
            await refreshSignals()
        }
        .task {
            await refreshSignals()
            await generateAITip()
        }
        .task(id: locationManager.lastLocation?.timestamp) {
            guard store.profile.prefersWeatherGoal else { return }
            await refreshWeather()
        }
        .sheet(item: $entryToEdit) { entry in
            EntryEditorSheet(entry: entry, unitSystem: store.profile.unitSystem) { updatedAmount, updatedNote in
                store.updateEntry(
                    id: entry.id,
                    volumeML: store.profile.unitSystem.ml(from: updatedAmount),
                    note: updatedNote
                )
            } onDelete: {
                deleteEntry(entry)
            }
        }
    }

    private var summarySection: some View {
        HydrationSummaryCard(
            greeting: greeting,
            progress: progress,
            todayTotalML: store.todayTotalML,
            goalTotalML: goal.totalML,
            unitSystem: store.profile.unitSystem,
            streakDays: store.gameState.streakDays,
            level: store.gameState.level,
            xp: store.gameState.xp
        )
        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private var quickAddSection: some View {
        let unit = store.profile.unitSystem
        let options = unit == .metric ? [200, 350, 500, 750] : [8, 12, 16, 24]

        return VStack(alignment: .leading, spacing: 12) {
            Text("Tap to log instantly")
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(options, id: \.self) { value in
                    Button {
                        addIntake(Double(value))
                    } label: {
                        VStack(spacing: 2) {
                            Text("\(value)")
                                .font(.headline)
                            Text(unit.volumeUnit)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private func tipSection(_ tip: HydrationTip) -> some View {
        Button {
            Task {
                Haptics.selection()
                await generateAITip()
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: tip.category.icon)
                    .font(.title3)
                    .foregroundStyle(tip.category.color)
                    .frame(width: 34)

                VStack(alignment: .leading, spacing: 3) {
                    Text(tip.message)
                        .font(.body)
                        .multilineTextAlignment(.leading)
                    Text("Tap to refresh")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if aiService.isGenerating {
                    ProgressView()
                }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var weatherSection: some View {
        if let snapshot = activeWeather {
            HStack(spacing: 12) {
                Image(systemName: weatherIcon(snapshot))
                    .font(.title3)
                    .foregroundStyle(Theme.lagoon)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 4) {
                    Text(snapshot.condition.isEmpty ? "Current weather" : snapshot.condition)
                        .font(.body.weight(.medium))
                    Text("\(Int(snapshot.temperatureC))°C • Humidity \(Int(snapshot.humidityPercent))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Adjusted Goal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(Formatters.volumeString(ml: goal.totalML, unit: store.profile.unitSystem))
                        .font(.subheadline.weight(.semibold))
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("Weather data unavailable")
                    .font(.subheadline.weight(.medium))
                Text(weatherMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var weatherMessage: String {
        switch locationManager.authorizationStatus {
        case .denied, .restricted:
            return "Enable Location access in Settings to personalize your hydration goal."
        default:
            return "Trying to load local weather. Your base goal still works without it."
        }
    }

    private var greeting: String {
        let firstName = store.profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let hour = Calendar.current.component(.hour, from: Date())

        let timeGreeting: String
        switch hour {
        case 5..<12:
            timeGreeting = "Good morning"
        case 12..<17:
            timeGreeting = "Good afternoon"
        case 17..<22:
            timeGreeting = "Good evening"
        default:
            timeGreeting = "Welcome back"
        }

        if firstName.isEmpty {
            return timeGreeting
        }
        return "\(timeGreeting), \(firstName)"
    }

    private var activeWeather: WeatherSnapshot? {
        weather.currentWeather ?? store.activeWeather
    }

    private var todayEntries: [HydrationEntry] {
        store.todayEntries.sorted { $0.date > $1.date }
    }

    private func weatherIcon(_ snapshot: WeatherSnapshot) -> String {
        if snapshot.conditionKey.isEmpty {
            return "cloud.sun"
        }
        return WeatherSnapshot.sfSymbol(for: snapshot.conditionKey)
    }

    private func addIntake(_ amount: Double) {
        Haptics.waterDrop()
        let entry = store.addIntake(amount: amount, source: .manual)

        Task {
            await healthKit.saveWaterIntake(ml: entry.volumeML, date: entry.date, entryID: entry.id)
            await generateAITip()
        }
    }

    private func deleteEntry(_ entry: HydrationEntry) {
        Haptics.impact(.medium)
        if entry.source == .manual {
            Task {
                await healthKit.deleteWaterIntake(entryID: entry.id)
            }
        }
        store.deleteEntry(entry)
    }

    private func refreshSignals() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        if store.profile.prefersHealthKit {
            await healthKit.refreshAuthorizationStatus()
            let summary = await healthKit.fetchTodayWorkoutSummary()
            store.updateWorkout(summary)
            if let entries = await healthKit.fetchRecentWaterEntries(days: 7) {
                store.syncHealthKitEntriesRange(entries, days: 7)
            }
        }

        if store.profile.prefersWeatherGoal {
            await refreshWeather()
        }

        store.refreshQuests()
    }

    private func refreshWeather() async {
        await weather.refresh()
        if let snapshot = weather.currentWeather {
            store.updateWeather(snapshot)
        } else if locationManager.authorizationStatus == .authorizedAlways || locationManager.authorizationStatus == .authorizedWhenInUse {
            locationManager.requestLocation()
        }
    }

    private func generateAITip() async {
        await aiService.generateTip(
            currentIntake: store.todayTotalML,
            goalML: goal.totalML,
            streakDays: store.gameState.streakDays,
            weatherTemp: activeWeather?.temperatureC,
            exerciseMinutes: Int(store.lastWorkout.exerciseMinutes),
            timeOfDay: TimeOfDay.current
        )
    }

}

private struct HydrationSummaryCard: View {
    let greeting: String
    let progress: Double
    let todayTotalML: Double
    let goalTotalML: Double
    let unitSystem: UnitSystem
    let streakDays: Int
    let level: Int
    let xp: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(greeting)
                        .font(.title3.weight(.semibold))
                    Text("\(Formatters.volumeString(ml: todayTotalML, unit: unitSystem)) of \(Formatters.volumeString(ml: goalTotalML, unit: unitSystem))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                AnimatedProgressLoader(progress: progress)
                    .frame(width: 84, height: 84)
            }

            VStack(alignment: .leading, spacing: 10) {
                ProgressView(value: progress)
                    .tint(Theme.lagoon)

                HStack(spacing: 8) {
                    statChip(text: "\(streakDays) day streak", icon: "flame.fill", tint: Theme.coral)
                    statChip(text: "Level \(level)", icon: "star.fill", tint: Theme.sun)
                    statChip(text: "\(xp) XP", icon: "sparkles", tint: Theme.lagoon)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Theme.glassBorder, lineWidth: 1)
        )
        .shadow(color: Theme.shadowColor, radius: 12, x: 0, y: 6)
        .padding(.horizontal, 2)
    }

    private func statChip(text: String, icon: String, tint: Color) -> some View {
        Label(text, systemImage: icon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.12))
            )
    }
}

private struct AnimatedProgressLoader: View {
    let progress: Double

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let clamped = min(1, max(0, progress))
            let pulse = 1 + (sin(time * 2.4) * 0.04)

            ZStack {
                Circle()
                    .fill(Theme.lagoon.opacity(0.08))

                Circle()
                    .stroke(Theme.glassBorder, lineWidth: 7)

                Circle()
                    .trim(from: 0, to: max(0.03, clamped))
                    .stroke(
                        AngularGradient(
                            colors: [Theme.lagoon, Theme.mint, Theme.lagoon],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 7, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.45, dampingFraction: 0.84), value: clamped)

                Circle()
                    .stroke(Theme.lagoon.opacity(0.16), lineWidth: 2)
                    .scaleEffect(pulse)
                    .opacity(0.8 - (pulse - 1) * 9)

                VStack(spacing: 1) {
                    Text(Formatters.percentString(clamped))
                        .font(.caption.weight(.bold))
                    Text("Goal")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct QuestRow: View {
    let quest: Quest

    private var progress: Double {
        min(1, quest.progressML / max(1, quest.targetML))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(quest.title)
                        .font(.subheadline.weight(.semibold))
                        .strikethrough(quest.isCompleted)
                    Text(quest.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Label("+\(quest.rewardXP)", systemImage: "star.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.sun)
            }

            ProgressView(value: progress)
                .tint(quest.isCompleted ? Theme.mint : Theme.lagoon)

            if quest.isCompleted {
                Label("Completed", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(Theme.mint)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct LogRow: View {
    let entry: HydrationEntry
    let unitSystem: UnitSystem

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: entry.source == .healthKit ? "heart.fill" : "drop.fill")
                .foregroundStyle(entry.source == .healthKit ? Theme.coral : Theme.lagoon)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(Formatters.volumeString(ml: entry.volumeML, unit: unitSystem))
                    .font(.body)
                if let note = entry.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(Self.formatter.string(from: entry.date))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct EntryEditorSheet: View {
    let entry: HydrationEntry
    let unitSystem: UnitSystem
    let onSave: (_ amount: Double, _ note: String?) -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var amount: Double
    @State private var note: String
    @State private var showDeleteConfirm = false

    init(
        entry: HydrationEntry,
        unitSystem: UnitSystem,
        onSave: @escaping (_ amount: Double, _ note: String?) -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.entry = entry
        self.unitSystem = unitSystem
        self.onSave = onSave
        self.onDelete = onDelete
        _amount = State(initialValue: unitSystem.amount(fromML: entry.volumeML))
        _note = State(initialValue: entry.note ?? "")
    }

    private var amountRange: ClosedRange<Double> {
        unitSystem == .metric ? 100...1200 : 4...40
    }

    private var amountStep: Double {
        unitSystem == .metric ? 25 : 1
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Amount") {
                    HStack {
                        Text("\(Int(amount)) \(unitSystem.volumeUnit)")
                            .font(.headline)
                        Spacer()
                    }
                    Slider(value: $amount, in: amountRange, step: amountStep)
                        .tint(Theme.lagoon)
                }

                Section("Note") {
                    TextField("Optional note", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section {
                    Button("Save") {
                        Haptics.impact(.medium)
                        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(amount, trimmed.isEmpty ? nil : trimmed)
                        dismiss()
                    }
                }

                Section {
                    Button("Delete Entry", role: .destructive) {
                        showDeleteConfirm = true
                    }
                }
            }
            .navigationTitle("Edit Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .confirmationDialog("Delete this entry?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    onDelete()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
}

#Preview("Dashboard") {
    PreviewEnvironment {
        DashboardView()
    }
}
