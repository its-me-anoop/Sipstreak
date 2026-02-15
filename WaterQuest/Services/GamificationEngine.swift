import Foundation

enum GamificationEngine {
    private static let milestoneCatalog: [Achievement] = [
        Achievement(id: "first-sip", title: "First Sip", detail: "Log your first drink.", isUnlocked: false, unlockedAt: nil),
        Achievement(id: "early-bird", title: "Early Bird", detail: "Log water before 8 AM.", isUnlocked: false, unlockedAt: nil),
        Achievement(id: "night-owl", title: "Night Owl", detail: "Log water after 10 PM.", isUnlocked: false, unlockedAt: nil),

        Achievement(id: "streak-3", title: "3-Day Flow", detail: "Keep a 3-day streak.", isUnlocked: false, unlockedAt: nil),
        Achievement(id: "streak-7", title: "7-Day River", detail: "Keep a 7-day streak.", isUnlocked: false, unlockedAt: nil),
        Achievement(id: "streak-14", title: "14-Day Current", detail: "Keep a 14-day streak.", isUnlocked: false, unlockedAt: nil),
        Achievement(id: "streak-30", title: "30-Day Tide", detail: "Keep a 30-day streak.", isUnlocked: false, unlockedAt: nil),
        Achievement(id: "days-30", title: "Consistency Champ", detail: "Log water on 30 different days.", isUnlocked: false, unlockedAt: nil),

        Achievement(id: "goal-day", title: "Goal Day", detail: "Reach your daily goal once.", isUnlocked: false, unlockedAt: nil),
        Achievement(id: "goal-10", title: "Tenfold", detail: "Hit your goal 10 times.", isUnlocked: false, unlockedAt: nil),
        Achievement(id: "goal-25", title: "Quarter Century", detail: "Hit your goal 25 times.", isUnlocked: false, unlockedAt: nil),

        Achievement(id: "entries-25", title: "Steady Sipper", detail: "Log 25 water entries.", isUnlocked: false, unlockedAt: nil),
        Achievement(id: "entries-100", title: "Hydration Habit", detail: "Log 100 water entries.", isUnlocked: false, unlockedAt: nil),
        Achievement(id: "total-10k", title: "Deep Reservoir", detail: "Log 10,000 mL total.", isUnlocked: false, unlockedAt: nil),
        Achievement(id: "total-50k", title: "Lake Maker", detail: "Log 50,000 mL total.", isUnlocked: false, unlockedAt: nil)
    ]

    static func refreshDailyQuests(state: inout GameState, goalML: Double) {
        let now = Date()
        if let lastRefresh = state.lastQuestRefresh, lastRefresh.isSameDay(as: now) {
            return
        }
        state.lastQuestRefresh = now
        state.quests = [
            Quest(
                id: "morning-splash",
                title: "Morning Splash",
                detail: "Hit 20% before 11 AM",
                targetML: goalML * 0.2,
                deadlineHour: 11,
                progressML: 0,
                isCompleted: false,
                rewardXP: 40
            ),
            Quest(
                id: "steady-sips",
                title: "Steady Sips",
                detail: "Reach 50% before 4 PM",
                targetML: goalML * 0.5,
                deadlineHour: 16,
                progressML: 0,
                isCompleted: false,
                rewardXP: 70
            ),
            Quest(
                id: "finish-line",
                title: "Finish Line",
                detail: "Complete your full goal",
                targetML: goalML,
                deadlineHour: nil,
                progressML: 0,
                isCompleted: false,
                rewardXP: 120
            )
        ]
    }

    static func ensureAchievements(state: inout GameState) {
        let catalogIDs = Set(milestoneCatalog.map(\.id))
        let existingByID = Dictionary(uniqueKeysWithValues: state.achievements.map { ($0.id, $0) })

        var mergedCatalog: [Achievement] = []
        mergedCatalog.reserveCapacity(milestoneCatalog.count)

        for milestone in milestoneCatalog {
            if let existing = existingByID[milestone.id] {
                mergedCatalog.append(
                    Achievement(
                        id: milestone.id,
                        title: milestone.title,
                        detail: milestone.detail,
                        isUnlocked: existing.isUnlocked,
                        unlockedAt: existing.unlockedAt
                    )
                )
            } else {
                mergedCatalog.append(milestone)
            }
        }

        // Preserve unknown/legacy milestones if any were persisted from older builds.
        let legacyMilestones = state.achievements.filter { !catalogIDs.contains($0.id) }
        state.achievements = mergedCatalog + legacyMilestones
    }

    static func applyIntake(
        state: inout GameState,
        entry: HydrationEntry,
        todayTotalML: Double,
        goalML: Double,
        allEntries: [HydrationEntry]
    ) {
        let hour = Calendar.current.component(.hour, from: entry.date)
        for index in state.quests.indices {
            if state.quests[index].isCompleted { continue }
            if let deadline = state.quests[index].deadlineHour, hour > deadline { continue }
            state.quests[index].progressML = min(goalML, todayTotalML)
            if state.quests[index].progressML >= state.quests[index].targetML {
                state.quests[index].isCompleted = true
            }
        }

        updateStreak(state: &state, entries: allEntries)
        refreshMilestones(state: &state, entries: allEntries, goalML: goalML, todayTotalML: todayTotalML)
    }

    static func refreshMilestones(
        state: inout GameState,
        entries: [HydrationEntry],
        goalML: Double,
        todayTotalML: Double
    ) {
        ensureAchievements(state: &state)
        updateAchievements(state: &state, entries: entries, goalML: goalML, todayTotalML: todayTotalML)
    }

    private static func updateStreak(state: inout GameState, entries: [HydrationEntry]) {
        let sorted = entries.sorted { $0.date < $1.date }
        guard let lastEntry = sorted.last else { return }
        if let lastStreakDate = state.lastStreakDate {
            if lastEntry.date.isSameDay(as: lastStreakDate) {
                return
            }
            if lastStreakDate.isYesterday(of: lastEntry.date) {
                state.streakDays += 1
                state.lastStreakDate = lastEntry.date
            } else {
                state.streakDays = 1
                state.lastStreakDate = lastEntry.date
            }
        } else {
            state.streakDays = 1
            state.lastStreakDate = lastEntry.date
        }
    }

    private static func updateAchievements(
        state: inout GameState,
        entries: [HydrationEntry],
        goalML: Double,
        todayTotalML: Double
    ) {
        let totalLoggedML = entries.reduce(0.0) { $0 + $1.volumeML }
        let goalDays = countGoalDays(entries: entries, goalML: goalML)
        let loggedDays = countLoggedDays(entries: entries)

        unlock("first-sip", state: &state, condition: !entries.isEmpty)
        unlock("early-bird", state: &state, condition: hasEntry(beforeHour: 8, in: entries))
        unlock("night-owl", state: &state, condition: hasEntry(atOrAfterHour: 22, in: entries))

        unlock("streak-3", state: &state, condition: state.streakDays >= 3)
        unlock("streak-7", state: &state, condition: state.streakDays >= 7)
        unlock("streak-14", state: &state, condition: state.streakDays >= 14)
        unlock("streak-30", state: &state, condition: state.streakDays >= 30)
        unlock("days-30", state: &state, condition: loggedDays >= 30)

        unlock("goal-day", state: &state, condition: todayTotalML >= goalML)
        unlock("goal-10", state: &state, condition: goalDays >= 10)
        unlock("goal-25", state: &state, condition: goalDays >= 25)

        unlock("entries-25", state: &state, condition: entries.count >= 25)
        unlock("entries-100", state: &state, condition: entries.count >= 100)
        unlock("total-10k", state: &state, condition: totalLoggedML >= 10_000)
        unlock("total-50k", state: &state, condition: totalLoggedML >= 50_000)
    }

    private static func countGoalDays(entries: [HydrationEntry], goalML: Double) -> Int {
        let grouped = Dictionary(grouping: entries) { $0.date.startOfDay }
        return grouped.values.filter { dayEntries in
            dayEntries.reduce(0.0) { $0 + $1.volumeML } >= goalML
        }.count
    }

    private static func countLoggedDays(entries: [HydrationEntry]) -> Int {
        Set(entries.map(\.date.startOfDay)).count
    }

    private static func hasEntry(beforeHour hour: Int, in entries: [HydrationEntry]) -> Bool {
        entries.contains { entry in
            Calendar.current.component(.hour, from: entry.date) < hour
        }
    }

    private static func hasEntry(atOrAfterHour hour: Int, in entries: [HydrationEntry]) -> Bool {
        entries.contains { entry in
            Calendar.current.component(.hour, from: entry.date) >= hour
        }
    }

    private static func unlock(_ id: String, state: inout GameState, condition: Bool) {
        guard condition else { return }
        guard let index = state.achievements.firstIndex(where: { $0.id == id }) else { return }
        if !state.achievements[index].isUnlocked {
            state.achievements[index].isUnlocked = true
            state.achievements[index].unlockedAt = Date()
        }
    }
}
