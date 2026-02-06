import Foundation

enum HydrationStorePersistSource: String {
    case local
    case remote
}

extension Notification.Name {
    static let hydrationStoreDidPersist = Notification.Name("HydrationStoreDidPersist")
}

@MainActor
final class HydrationStore: ObservableObject {
    @Published var entries: [HydrationEntry]
    @Published var profile: UserProfile
    @Published var gameState: GameState
    @Published var lastWeather: WeatherSnapshot?
    @Published var lastWorkout: WorkoutSummary
    @Published var activeAchievement: Achievement?
    @Published private(set) var hasPremiumAccess: Bool = false

    private let persistence = PersistenceService.shared
    private var pendingAchievements: [Achievement] = []
    private var stateUpdatedAt: Date

    /// Set by the app after both objects are created so the store can notify
    /// the scheduler when new intake is logged.
    weak var notificationScheduler: NotificationScheduler?

    init() {
        let state = persistence.load(PersistedState.self, fallback: .default)
        self.entries = state.entries
        self.profile = state.profile
        self.gameState = state.gameState
        self.lastWeather = state.lastWeather
        self.lastWorkout = state.lastWorkout
        self.activeAchievement = nil
        self.stateUpdatedAt = state.lastUpdatedAt
        GamificationEngine.ensureAchievements(state: &self.gameState)
        GamificationEngine.refreshDailyQuests(state: &self.gameState, goalML: dailyGoal.totalML)
    }

    var dailyGoal: GoalBreakdown {
        GoalCalculator.dailyGoal(
            profile: profile,
            weather: canUseWeatherAdjustment ? lastWeather : nil,
            workout: canUseWorkoutAdjustment ? lastWorkout : nil
        )
    }

    var activeWeather: WeatherSnapshot? {
        canUseWeatherAdjustment ? lastWeather : nil
    }

    var canUseWeatherAdjustment: Bool {
        hasPremiumAccess && profile.prefersWeatherGoal
    }

    var canUseWorkoutAdjustment: Bool {
        hasPremiumAccess && profile.prefersHealthKit
    }

    var todayEntries: [HydrationEntry] {
        entries.filter { $0.date.isSameDay(as: Date()) }
    }

    var todayTotalML: Double {
        todayEntries.reduce(0) { $0 + $1.volumeML }
    }

    var persistedStateSnapshot: PersistedState {
        makePersistedState(updatedAt: stateUpdatedAt)
    }

    @discardableResult
    func addIntake(amount: Double, unitSystem: UnitSystem? = nil, source: HydrationSource = .manual, note: String? = nil) -> HydrationEntry {
        let previouslyUnlocked = Set(gameState.achievements.filter { $0.isUnlocked }.map { $0.id })
        let units = unitSystem ?? profile.unitSystem
        let ml = units.ml(from: amount)
        let entry = HydrationEntry(date: Date(), volumeML: ml, source: source, note: note)
        entries.append(entry)
        GamificationEngine.refreshDailyQuests(state: &gameState, goalML: dailyGoal.totalML)
        GamificationEngine.applyIntake(state: &gameState, entry: entry, todayTotalML: todayTotalML, goalML: dailyGoal.totalML, allEntries: entries)
        notificationScheduler?.onIntakeLogged(entry: entry)
        persist()
        let newlyUnlocked = gameState.achievements.filter { $0.isUnlocked && !previouslyUnlocked.contains($0.id) }
        enqueueAchievements(newlyUnlocked)
        return entry
    }

    func deleteEntry(_ entry: HydrationEntry) {
        entries.removeAll { $0.id == entry.id }
        GamificationEngine.refreshDailyQuests(state: &gameState, goalML: dailyGoal.totalML)
        GamificationEngine.refreshMilestones(
            state: &gameState,
            entries: entries,
            goalML: dailyGoal.totalML,
            todayTotalML: todayTotalML
        )
        persist()
    }

    func updateEntry(id: UUID, volumeML: Double, note: String?) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].volumeML = volumeML
        entries[index].note = note
        GamificationEngine.refreshDailyQuests(state: &gameState, goalML: dailyGoal.totalML)
        GamificationEngine.refreshMilestones(
            state: &gameState,
            entries: entries,
            goalML: dailyGoal.totalML,
            todayTotalML: todayTotalML
        )
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

    func updateWorkout(_ summary: WorkoutSummary) {
        lastWorkout = summary
        persist()
    }

    func syncHealthKitEntries(_ healthKitEntries: [HydrationEntry], for date: Date = Date()) {
        entries.removeAll { $0.source == .healthKit && $0.date.isSameDay(as: date) }
        entries.append(contentsOf: healthKitEntries)
        entries.sort { $0.date < $1.date }
        GamificationEngine.refreshDailyQuests(state: &gameState, goalML: dailyGoal.totalML)
        GamificationEngine.refreshMilestones(
            state: &gameState,
            entries: entries,
            goalML: dailyGoal.totalML,
            todayTotalML: todayTotalML
        )
        persist()
    }

    func syncHealthKitEntriesRange(_ healthKitEntries: [HydrationEntry], days: Int) {
        let cappedDays = max(1, min(30, days))
        guard let start = Calendar.current.date(byAdding: .day, value: -cappedDays + 1, to: Calendar.current.startOfDay(for: Date())) else { return }
        entries.removeAll { $0.source == .healthKit && $0.date >= start }
        entries.append(contentsOf: healthKitEntries)
        entries.sort { $0.date < $1.date }
        GamificationEngine.refreshDailyQuests(state: &gameState, goalML: dailyGoal.totalML)
        GamificationEngine.refreshMilestones(
            state: &gameState,
            entries: entries,
            goalML: dailyGoal.totalML,
            todayTotalML: todayTotalML
        )
        persist()
    }

    func refreshQuests() {
        GamificationEngine.refreshDailyQuests(state: &gameState, goalML: dailyGoal.totalML)
        persist()
    }

    func setPremiumAccess(_ hasAccess: Bool) {
        guard hasPremiumAccess != hasAccess else { return }
        hasPremiumAccess = hasAccess
        GamificationEngine.refreshDailyQuests(state: &gameState, goalML: dailyGoal.totalML)
        notificationScheduler?.scheduleReminders(profile: profile, entries: entries, goalML: dailyGoal.totalML)
    }

    func resetToday() {
        entries.removeAll { $0.date.isSameDay(as: Date()) }
        persist()
    }

    func touchForSync() {
        persist()
    }

    func dismissActiveAchievement() {
        if pendingAchievements.isEmpty {
            activeAchievement = nil
        } else {
            activeAchievement = pendingAchievements.removeFirst()
        }
    }

    func applySyncedState(_ state: PersistedState) {
        entries = state.entries.sorted { $0.date < $1.date }
        profile = state.profile
        gameState = state.gameState
        lastWeather = state.lastWeather
        lastWorkout = state.lastWorkout
        pendingAchievements.removeAll()
        activeAchievement = nil
        GamificationEngine.ensureAchievements(state: &gameState)
        GamificationEngine.refreshDailyQuests(state: &gameState, goalML: dailyGoal.totalML)
        persist(source: .remote, updatedAt: state.lastUpdatedAt)
    }

    private func makePersistedState(updatedAt: Date) -> PersistedState {
        PersistedState(
            entries: entries,
            profile: profile,
            gameState: gameState,
            lastWeather: lastWeather,
            lastWorkout: lastWorkout,
            lastUpdatedAt: updatedAt
        )
    }

    private func persist(source: HydrationStorePersistSource = .local, updatedAt: Date? = nil) {
        switch source {
        case .local:
            stateUpdatedAt = updatedAt ?? Date()
        case .remote:
            stateUpdatedAt = updatedAt ?? stateUpdatedAt
        }

        let state = makePersistedState(updatedAt: stateUpdatedAt)
        persistence.save(state)
        NotificationCenter.default.post(
            name: .hydrationStoreDidPersist,
            object: state,
            userInfo: ["source": source.rawValue]
        )
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
    var lastWeather: WeatherSnapshot?
    var lastWorkout: WorkoutSummary
    var lastUpdatedAt: Date

    // manualWeather removed; kept as ignored key so old persisted JSON decodes without error
    private enum CodingKeys: String, CodingKey {
        case entries, profile, gameState, lastWeather, lastWorkout, lastUpdatedAt, manualWeather
    }

    init(entries: [HydrationEntry], profile: UserProfile, gameState: GameState, lastWeather: WeatherSnapshot?, lastWorkout: WorkoutSummary, lastUpdatedAt: Date) {
        self.entries = entries
        self.profile = profile
        self.gameState = gameState
        self.lastWeather = lastWeather
        self.lastWorkout = lastWorkout
        self.lastUpdatedAt = lastUpdatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        entries      = try c.decode([HydrationEntry].self, forKey: .entries)
        profile      = try c.decode(UserProfile.self,       forKey: .profile)
        gameState    = try c.decode(GameState.self,         forKey: .gameState)
        lastWeather  = try c.decodeIfPresent(WeatherSnapshot.self, forKey: .lastWeather)
        lastWorkout  = try c.decode(WorkoutSummary.self,    forKey: .lastWorkout)
        lastUpdatedAt = try c.decodeIfPresent(Date.self, forKey: .lastUpdatedAt) ?? .distantPast
        // .manualWeather silently ignored if present in old JSON
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(entries,     forKey: .entries)
        try c.encode(profile,     forKey: .profile)
        try c.encode(gameState,   forKey: .gameState)
        try c.encode(lastWeather, forKey: .lastWeather)
        try c.encode(lastWorkout, forKey: .lastWorkout)
        try c.encode(lastUpdatedAt, forKey: .lastUpdatedAt)
    }

    static let `default` = PersistedState(
        entries: [],
        profile: .default,
        gameState: .default,
        lastWeather: nil,
        lastWorkout: .empty,
        lastUpdatedAt: .distantPast
    )
}
