import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: HydrationStore
    @EnvironmentObject private var weather: WeatherClient
    @EnvironmentObject private var healthKit: HealthKitManager
    @EnvironmentObject private var locationManager: LocationManager

    @StateObject private var aiService = HydrationAIService()

    @State private var entryToEdit: HydrationEntry?
    @State private var isRefreshing = false
    @State private var showLogs = false

    private var goal: GoalBreakdown { store.dailyGoal }
    private var progress: Double { min(1, store.todayTotalML / max(1, goal.totalML)) }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(nil)
            
    }

    var body: some View {
        GeometryReader { proxy in
            let topSafeAreaInset = proxy.safeAreaInsets.top
            List {
                summarySection(topSafeAreaInset: topSafeAreaInset)

                Section(header: sectionHeader("Hydration Coach")) {
                    if let tip = aiService.currentTip {
                        tipSection(tip)
                    } else {
                        coachLoadingSection
                    }
                }

                Section(header: sectionHeader("Activity")) {
                    if store.gameState.quests.isEmpty {
                        AdaptiveSignalCard(
                            icon: "flag.slash.fill",
                            title: "No quests right now",
                            subtitle: "New hydration missions will appear as your day progresses.",
                            accent: Theme.lagoon
                        ) {
                            EmptyView()
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    } else {
                        ForEach(store.gameState.quests) { quest in
                            QuestCard(
                                quest: quest,
                                progress: min(1, quest.progressML / max(1, quest.targetML))
                            )
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                    }
                }

                Section(header: sectionHeader("Recent Logs")) {
                    if visibleTodayEntries.isEmpty {
                        LiquidGlassCard(cornerRadius: 18, tintColor: Theme.lagoon.opacity(0.4), isInteractive: false) {
                            HStack(spacing: 12) {
                                Image(systemName: "drop.circle")
                                    .font(.title3)
                                    .foregroundStyle(Theme.lagoon)
                                    .frame(width: 32, height: 32)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("No water logged yet")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Theme.textPrimary)
                                    Text("Your latest entries will appear here.")
                                        .font(.caption)
                                        .foregroundStyle(Theme.textSecondary)
                                }

                                Spacer()
                            }
                            .padding(14)
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    } else {
                        Group {
                            ForEach(visibleTodayEntries) { entry in
                                Button {
                                    Haptics.selection()
                                    entryToEdit = entry
                                } label: {
                                    LogRow(entry: entry, unitSystem: store.profile.unitSystem)
                                }
                                .buttonStyle(.plain)
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .transition(.move(edge: .top).combined(with: .opacity))
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        deleteEntry(entry)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }

                            if hiddenEntryCount > 0 {
                                Button {
                                    Haptics.selection()
                                    showLogs = true
                                } label: {
                                    LiquidGlassCard(cornerRadius: 18, tintColor: Theme.mint.opacity(0.35), isInteractive: true) {
                                        HStack(spacing: 12) {
                                            Image(systemName: "clock.arrow.circlepath")
                                                .font(.title3)
                                                .foregroundStyle(Theme.mint)
                                                .frame(width: 32, height: 32)

                                            VStack(alignment: .leading, spacing: 6) {
                                                HStack(spacing: 8) {
                                                    Text("View all logs")
                                                        .font(.subheadline.weight(.semibold))
                                                        .foregroundStyle(Theme.textPrimary)

                                                }

                                                Text("\\(hiddenEntryCount) more entries today")
                                                    .font(.caption)
                                                    .foregroundStyle(Theme.textSecondary)
                                            }

                                            Spacer()

                                            Image(systemName: "chevron.right")
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(Theme.textSecondary)
                                        }
                                        .padding(14)
                                    }
                                }
                                .buttonStyle(.plain)
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .transition(.opacity)
                            }
                        }
                        .animation(Theme.gentleSpring, value: visibleTodayEntries)
                    }
                }
            }
            .listStyle(.plain)
            .contentMargins(.top, 0, for: .scrollContent)
            .scrollContentBackground(.hidden)
            .background(AppWaterBackground().ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .refreshable {
                await refreshSignals()
            }
            .task {
                await refreshSignals()
                await generateAITip()
            }
            .task(id: store.canUseWorkoutAdjustment) {
                guard store.canUseWorkoutAdjustment else { return }
                await healthKit.refreshAuthorizationStatus()
                let summary = await healthKit.fetchTodayWorkoutSummary()
                store.updateWorkout(summary)
            }
            .task(id: store.canUseWeatherAdjustment) {
                guard store.canUseWeatherAdjustment else { return }
                await refreshWeather()
            }
            .task(id: locationManager.lastLocation?.timestamp) {
                guard store.canUseWeatherAdjustment else { return }
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
            .navigationDestination(isPresented: $showLogs) {
                LogsView()
            }
        }
    }

    private func summarySection(topSafeAreaInset: CGFloat) -> some View {
        let wChip: (icon: String, label: String)? = {
            guard store.canUseWeatherAdjustment, let snapshot = activeWeather else { return nil }
            let temp: String
            if store.profile.unitSystem == .imperial {
                temp = "\(Int(((snapshot.temperatureC * 9 / 5) + 32).rounded()))°F"
            } else {
                temp = "\(Int(snapshot.temperatureC.rounded()))°C"
            }
            let humidity = "\(Int(snapshot.humidityPercent.rounded()))%"
            return (icon: weatherIcon(snapshot), label: "\(temp), \(humidity) humidity")
        }()

        let aChip: (icon: String, label: String)? = {
            guard store.canUseWorkoutAdjustment else { return nil }
            let workout = store.lastWorkout
            let minutes = Int(workout.exerciseMinutes.rounded())
            guard minutes > 0 else { return nil }
            let hours = minutes / 60
            let remainingMins = minutes % 60
            let timeStr = hours > 0 ? "\(hours)h \(remainingMins)m" : "\(minutes)m"
            return (icon: "figure.run.circle.fill", label: timeStr + " active")
        }()

        return HydrationSummaryCard(
            topSafeAreaInset: topSafeAreaInset,
            greeting: greeting,
            progress: progress,
            todayTotalML: store.todayTotalML,
            goalTotalML: goal.totalML,
            unitSystem: store.profile.unitSystem,
            streakDays: store.gameState.streakDays,
            weatherChip: wChip,
            activityChip: aChip,
            showWeatherAttribution: wChip != nil
        )
        .listRowInsets(EdgeInsets(top: -topSafeAreaInset, leading: 0, bottom: 6, trailing: 0))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private func tipSection(_ tip: HydrationTip) -> some View {
        Button {
            Task {
                Haptics.selection()
                await generateAITip()
            }
        } label: {
            HydrationCoachCardBackground {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Coach Insight", systemImage: "sparkles")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.92))

                        Text(tip.message)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.leading)
                            .lineSpacing(2)

                        HStack(spacing: 8) {
                            Text(
                                tip.category == .celebration
                                    ? "Celebration"
                                    : tip.category == .encouragement
                                        ? "Encouragement"
                                        : tip.category == .reminder
                                            ? "Reminder"
                                            : "Tip"
                            )
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(tip.category.color.opacity(0.32))
                            )
                        }
                    }

                    Spacer(minLength: 10)

                    if aiService.isGenerating {
                        ProgressView()
                            .tint(.white)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private var coachLoadingSection: some View {
        HydrationCoachCardBackground {
            HStack(spacing: 12) {
                ProgressView()
                    .tint(.white)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Preparing your hydration coach")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("Generating an insight tuned to your progress and time of day.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.82))
                }
                Spacer(minLength: 8)
            }
        }
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
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

    private var visibleTodayEntries: [HydrationEntry] {
        return Array(todayEntries.prefix(5))
    }

    private var hiddenEntryCount: Int {
        max(0, todayEntries.count - visibleTodayEntries.count)
    }

    private func weatherIcon(_ snapshot: WeatherSnapshot) -> String {
        if snapshot.conditionKey.isEmpty {
            return "cloud.sun"
        }
        return WeatherSnapshot.sfSymbol(for: snapshot.conditionKey)
    }

    private var weatherAdjustmentLabel: String {
        let delta = goal.weatherAdjustmentML
        if delta > 0 {
            return "+\(Formatters.shortVolume(ml: delta, unit: store.profile.unitSystem)) \(store.profile.unitSystem.volumeUnit)"
        }
        if delta < 0 {
            return "-\(Formatters.shortVolume(ml: abs(delta), unit: store.profile.unitSystem)) \(store.profile.unitSystem.volumeUnit)"
        }
        return "Base"
    }

    private var workoutAdjustmentLabel: String {
        guard store.canUseWorkoutAdjustment else { return "Off" }
        let delta = goal.workoutAdjustmentML
        if delta > 0 {
            return "+\(Formatters.shortVolume(ml: delta, unit: store.profile.unitSystem)) \(store.profile.unitSystem.volumeUnit)"
        }
        return "Base"
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

        if store.canUseWorkoutAdjustment {
            await healthKit.refreshAuthorizationStatus()
            let summary = await healthKit.fetchTodayWorkoutSummary()
            store.updateWorkout(summary)
            if let entries = await healthKit.fetchRecentWaterEntries(days: 7) {
                store.syncHealthKitEntriesRange(entries, days: 7)
            }
        }

        if store.canUseWeatherAdjustment {
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
            weatherHumidity: activeWeather?.humidityPercent,
            exerciseMinutes: Int(store.lastWorkout.exerciseMinutes),
            timeOfDay: TimeOfDay.current
        )
    }

}

private struct HydrationCoachCardBackground<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack {
                    Image("HydrationCoachBackground")
                        .resizable()
                        .scaledToFill()

                    LinearGradient(
                        colors: colorScheme == .dark
                            ? [
                                Color.black.opacity(0.20),
                                Color.black.opacity(0.44),
                                Color.black.opacity(0.70)
                            ]
                            : [
                                Color.black.opacity(0.10),
                                Color.black.opacity(0.28),
                                Color.black.opacity(0.54)
                            ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(colorScheme == .dark ? 0.16 : 0.24), lineWidth: 0.9)
            )
            .shadow(color: Theme.shadowColor.opacity(0.62), radius: 10, x: 0, y: 5)
    }
}

private struct HydrationSummaryCard: View {
    let topSafeAreaInset: CGFloat
    let greeting: String
    let progress: Double
    let todayTotalML: Double
    let goalTotalML: Double
    let unitSystem: UnitSystem
    let streakDays: Int
    let weatherChip: (icon: String, label: String)?
    let activityChip: (icon: String, label: String)?
    let showWeatherAttribution: Bool

    private var heroHeight: CGFloat {
        280 + topSafeAreaInset
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            HydrationSummaryAnimatedBackground()
                .frame(maxWidth: .infinity)
                .frame(height: heroHeight)
                .clipped()

            LinearGradient(
                colors: [
                    Color.black.opacity(0.06),
                    Color.black.opacity(0.20),
                    Color.black.opacity(0.52),
                    Color.black.opacity(0.84)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(maxWidth: .infinity)
            .frame(height: heroHeight)

            HStack(alignment: .bottom, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(greeting)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.72), radius: 3, x: 0, y: 1)
                    Text("\(Formatters.volumeString(ml: todayTotalML, unit: unitSystem)) of \(Formatters.volumeString(ml: goalTotalML, unit: unitSystem))")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.94))
                        .shadow(color: .black.opacity(0.68), radius: 3, x: 0, y: 1)

                    Rectangle()
                        .fill(.white.opacity(0.15))
                        .frame(height: 1)
                        .padding(.trailing, 8)

                    VStack(alignment: .leading, spacing: 5) {
                        signalRow(icon: "flame.fill", text: "\(streakDays) day streak")

                        if let wc = weatherChip {
                            signalRow(icon: wc.icon, text: wc.label)
                        }

                        if let ac = activityChip {
                            signalRow(icon: ac.icon, text: ac.label)
                        }

                        if showWeatherAttribution {
                            HStack(spacing: 4) {
                                Text("\u{f8ff} Weather")
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.white.opacity(0.40))
                                if let legalURL = URL(string: "https://weatherkit.apple.com/legal-attribution.html") {
                                    Link("Legal", destination: legalURL)
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.30))
                                }
                            }
                        }
                    }
                }

                Spacer(minLength: 8)

                MascotProgressView(progress: progress, size: 112)
                    .frame(width: 132, height: 132)
            }
            .frame(maxWidth: .infinity, alignment: .bottomLeading)
            .padding(.horizontal, 28)
            .padding(.bottom, 24)
            .offset(y: -12)
        }
        .frame(height: heroHeight)
        .clipped()
    }

    private func signalRow(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.82))
            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
    }
}

private struct HydrationSummaryAnimatedBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    private var baseTop: Color {
        colorScheme == .dark
            ? Color(red: 0.04, green: 0.11, blue: 0.18)
            : Color(red: 0.77, green: 0.92, blue: 0.99)
    }

    private var baseMid: Color {
        colorScheme == .dark
            ? Color(red: 0.07, green: 0.22, blue: 0.34)
            : Color(red: 0.55, green: 0.82, blue: 0.95)
    }

    private var baseBottom: Color {
        colorScheme == .dark
            ? Color(red: 0.04, green: 0.16, blue: 0.26)
            : Color(red: 0.27, green: 0.63, blue: 0.84)
    }

    private var glowOne: Color {
        colorScheme == .dark
            ? Color(red: 0.28, green: 0.72, blue: 0.98).opacity(0.24)
            : Color.white.opacity(0.34)
    }

    private var glowTwo: Color {
        colorScheme == .dark
            ? Color(red: 0.20, green: 0.52, blue: 0.85).opacity(0.20)
            : Color(red: 0.76, green: 0.93, blue: 1.0).opacity(0.35)
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate

            ZStack {
                LinearGradient(
                    colors: [baseTop, baseMid, baseBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(glowOne)
                    .frame(width: 440, height: 440)
                    .blur(radius: 48)
                    .offset(
                        x: CGFloat(sin(time * 0.24)) * 92,
                        y: -200 + CGFloat(cos(time * 0.20)) * 38
                    )

                Circle()
                    .fill(glowTwo)
                    .frame(width: 380, height: 380)
                    .blur(radius: 42)
                    .offset(
                        x: 170 + CGFloat(cos(time * 0.17)) * 64,
                        y: -90 + CGFloat(sin(time * 0.22)) * 34
                    )

                VStack(spacing: 30) {
                    ForEach(0..<6, id: \.self) { index in
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(colorScheme == .dark ? 0.06 : 0.10))
                            .frame(height: index.isMultiple(of: 2) ? 2 : 1)
                            .scaleEffect(
                                x: 1.2 + CGFloat(sin(time * 0.19 + Double(index) * 0.8)) * 0.08,
                                y: 1,
                                anchor: .center
                            )
                            .offset(x: CGFloat(cos(time * 0.23 + Double(index))) * 20)
                    }
                }
                .padding(.top, 72)
                .frame(maxHeight: .infinity, alignment: .top)
            }
        }
    }
}

private struct AnimatedProgressLoader: View {
    let progress: Double
    var isOnDarkBackground = false

    private var baseFill: Color {
        isOnDarkBackground ? Color.white.opacity(0.16) : Theme.lagoon.opacity(0.08)
    }

    private var trackColor: Color {
        isOnDarkBackground ? Color.white.opacity(0.28) : Theme.glassBorder
    }

    private var progressGradient: [Color] {
        isOnDarkBackground
            ? [Color.white.opacity(0.98), Theme.mint.opacity(0.92), Color.white.opacity(0.98)]
            : [Theme.lagoon, Theme.mint, Theme.lagoon]
    }

    private var pulseColor: Color {
        isOnDarkBackground ? Color.white.opacity(0.22) : Theme.lagoon.opacity(0.16)
    }

    private var goalLabelColor: Color {
        isOnDarkBackground ? Color.white.opacity(0.82) : .secondary
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let clamped = min(1, max(0, progress))
            let pulse = 1 + (sin(time * 2.4) * 0.04)

            ZStack {
                Circle()
                    .fill(baseFill)

                Circle()
                    .stroke(trackColor, lineWidth: 10)

                Circle()
                    .trim(from: 0, to: max(0.03, clamped))
                    .stroke(
                        AngularGradient(
                            colors: progressGradient,
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.45, dampingFraction: 0.84), value: clamped)

                Circle()
                    .stroke(pulseColor, lineWidth: 3)
                    .scaleEffect(pulse)
                    .opacity(0.8 - (pulse - 1) * 9)

                VStack(spacing: 1) {
                    Text(Formatters.percentString(clamped))
                        .font(.callout.weight(.bold))
                        .foregroundStyle(.white)
                    Text("Goal")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(goalLabelColor)
                }
            }
        }
    }
}

private struct AdaptiveSignalCard<Content: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    let accent: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.18))
                    Circle()
                        .strokeBorder(accent.opacity(0.30), lineWidth: 0.9)
                    Image(systemName: icon)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(accent)
                }
                .frame(width: 30, height: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            content
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.cardSurface.opacity(0.96))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [accent.opacity(0.14), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Theme.glassBorder, lineWidth: 1)
        )
        .shadow(color: Theme.shadowColor.opacity(0.55), radius: 8, x: 0, y: 4)
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
        LiquidGlassCard(cornerRadius: 18, tintColor: entryTint.opacity(0.35), isInteractive: false) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(entryTint.opacity(0.18))
                            .frame(width: 34, height: 34)
                        Image(systemName: entryIcon)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(entryTint)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(Formatters.volumeString(ml: entry.volumeML, unit: unitSystem))
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Theme.textPrimary)

                        HStack(spacing: 6) {
                            Label(entrySourceLabel, systemImage: entryIcon)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }

                    Spacer()

                    Text(Self.formatter.string(from: entry.date))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Theme.glassLight.opacity(0.9))
                                .overlay(
                                    Capsule(style: .continuous)
                                        .stroke(Theme.glassBorder.opacity(0.8), lineWidth: 0.8)
                                )
                        )
                }

                if let note = entry.note, !note.isEmpty {
                    Text(note)
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(2)
                }
            }
            .padding(14)
        }
    }

    private var entryIcon: String {
        entry.source == .healthKit ? "heart.fill" : "drop.fill"
    }

    private var entryTint: Color {
        entry.source == .healthKit ? Theme.coral : Theme.lagoon
    }

    private var entrySourceLabel: String {
        entry.source == .healthKit ? "Health" : "Manual"
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

#if DEBUG
#Preview("Dashboard") {
    PreviewEnvironment {
        DashboardView()
    }
}
#endif
