import Foundation

@MainActor
final class HydrationStore: ObservableObject {
    @Published var entries: [HydrationEntry]
    @Published var profile: UserProfile
    @Published var gameState: GameState
    @Published var manualWeather: WeatherSnapshot?
    @Published var lastWeather: WeatherSnapshot?
    @Published var lastWorkout: WorkoutSummary
    @Published var activeAchievement: Achievement?

    private let persistence = PersistenceService.shared
    private var pendingAchievements: [Achievement] = []

    /// Set by the app after both objects are created so the store can notify
    /// the scheduler when new intake is logged.
    weak var notificationScheduler: NotificationScheduler?

    init() {
        let state = persistence.load(PersistedState.self, fallback: .default)
        self.entries = state.entries
        self.profile = state.profile
        self.gameState = state.gameState
        self.manualWeather = state.manualWeather
        self.lastWeather = state.lastWeather
        self.lastWorkout = state.lastWorkout
        self.activeAchievement = nil
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
        let previouslyUnlocked = Set(gameState.achievements.filter { $0.isUnlocked }.map { $0.id })
        let units = unitSystem ?? profile.unitSystem
        let ml = units.ml(from: amount)
        let entry = HydrationEntry(date: Date(), volumeML: ml, source: source)
        entries.append(entry)
        GamificationEngine.refreshDailyQuests(state: &gameState, goalML: dailyGoal.totalML)
        GamificationEngine.applyIntake(state: &gameState, entry: entry, todayTotalML: todayTotalML, goalML: dailyGoal.totalML, allEntries: entries)
        notificationScheduler?.onIntakeLogged(entry: entry)
        persist()
        let newlyUnlocked = gameState.achievements.filter { $0.isUnlocked && !previouslyUnlocked.contains($0.id) }
        enqueueAchievements(newlyUnlocked)
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

    func dismissActiveAchievement() {
        if pendingAchievements.isEmpty {
            activeAchievement = nil
        } else {
            activeAchievement = pendingAchievements.removeFirst()
        }
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

    private func enqueueAchievements(_ achievements: [Achievement]) {
        guard !achievements.isEmpty else { return }
        pendingAchievements.append(contentsOf: achievements)
        if activeAchievement == nil {
            activeAchievement = pendingAchievements.removeFirst()
        }
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
