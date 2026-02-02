import Foundation

final class HydrationStore: ObservableObject {
    @Published var entries: [HydrationEntry]
    @Published var profile: UserProfile
    @Published var gameState: GameState
    @Published var manualWeather: WeatherSnapshot?
    @Published var lastWeather: WeatherSnapshot?
    @Published var lastWorkout: WorkoutSummary

    private let persistence = PersistenceService.shared

    init() {
        let state = persistence.load(PersistedState.self, fallback: .default)
        self.entries = state.entries
        self.profile = state.profile
        self.gameState = state.gameState
        self.manualWeather = state.manualWeather
        self.lastWeather = state.lastWeather
        self.lastWorkout = state.lastWorkout
        GamificationEngine.ensureAchievements(state: &self.gameState)
        GamificationEngine.refreshDailyQuests(state: &self.gameState, goalML: dailyGoal.totalML)
    }

    var dailyGoal: GoalBreakdown {
        GoalCalculator.dailyGoal(profile: profile, weather: activeWeather, workout: lastWorkout)
    }

    var activeWeather: WeatherSnapshot? {
        profile.prefersWeatherGoal ? (lastWeather ?? manualWeather) : nil
    }

    var todayEntries: [HydrationEntry] {
        entries.filter { $0.date.isSameDay(as: Date()) }
    }

    var todayTotalML: Double {
        todayEntries.reduce(0) { $0 + $1.volumeML }
    }

    func addIntake(amount: Double, unitSystem: UnitSystem? = nil, source: HydrationSource = .manual) {
        let units = unitSystem ?? profile.unitSystem
        let ml = units.ml(from: amount)
        let entry = HydrationEntry(date: Date(), volumeML: ml, source: source)
        entries.append(entry)
        GamificationEngine.refreshDailyQuests(state: &gameState, goalML: dailyGoal.totalML)
        GamificationEngine.applyIntake(state: &gameState, entry: entry, todayTotalML: todayTotalML, goalML: dailyGoal.totalML, allEntries: entries)
        persist()
    }

    func deleteEntry(_ entry: HydrationEntry) {
        entries.removeAll { $0.id == entry.id }
        persist()
    }

    func updateProfile(_ update: (inout UserProfile) -> Void) {
        var copy = profile
        update(&copy)
        profile = copy
        GamificationEngine.refreshDailyQuests(state: &gameState, goalML: dailyGoal.totalML)
        persist()
    }

    func updateWeather(_ snapshot: WeatherSnapshot) {
        lastWeather = snapshot
        persist()
    }

    func updateManualWeather(_ snapshot: WeatherSnapshot?) {
        manualWeather = snapshot
        persist()
    }

    func updateWorkout(_ summary: WorkoutSummary) {
        lastWorkout = summary
        persist()
    }

    func refreshQuests() {
        GamificationEngine.refreshDailyQuests(state: &gameState, goalML: dailyGoal.totalML)
        persist()
    }

    func resetToday() {
        entries.removeAll { $0.date.isSameDay(as: Date()) }
        persist()
    }

    private func persist() {
        let state = PersistedState(
            entries: entries,
            profile: profile,
            gameState: gameState,
            manualWeather: manualWeather,
            lastWeather: lastWeather,
            lastWorkout: lastWorkout
        )
        persistence.save(state)
    }
}

struct PersistedState: Codable {
    var entries: [HydrationEntry]
    var profile: UserProfile
    var gameState: GameState
    var manualWeather: WeatherSnapshot?
    var lastWeather: WeatherSnapshot?
    var lastWorkout: WorkoutSummary

    static let `default` = PersistedState(
        entries: [],
        profile: .default,
        gameState: .default,
        manualWeather: nil,
        lastWeather: nil,
        lastWorkout: .empty
    )
}
