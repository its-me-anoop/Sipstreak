import Foundation

enum GamificationEngine {
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
        if state.achievements.isEmpty {
            state.achievements = [
                Achievement(id: "first-sip", title: "First Sip", detail: "Log your first drink.", isUnlocked: false, unlockedAt: nil),
                Achievement(id: "streak-3", title: "3-Day Flow", detail: "Keep a 3-day streak.", isUnlocked: false, unlockedAt: nil),
                Achievement(id: "streak-7", title: "7-Day River", detail: "Keep a 7-day streak.", isUnlocked: false, unlockedAt: nil),
                Achievement(id: "goal-day", title: "Goal Day", detail: "Reach your daily goal once.", isUnlocked: false, unlockedAt: nil),
                Achievement(id: "goal-10", title: "Tenfold", detail: "Hit your goal 10 times.", isUnlocked: false, unlockedAt: nil)
            ]
        }
    }

    static func applyIntake(
        state: inout GameState,
        entry: HydrationEntry,
        todayTotalML: Double,
        goalML: Double,
        allEntries: [HydrationEntry]
    ) {
        let xpGain = max(5, Int(entry.volumeML / 30))
        state.xp += xpGain
        state.coins += max(1, Int(entry.volumeML / 200))

        let hour = Calendar.current.component(.hour, from: entry.date)
        for index in state.quests.indices {
            if state.quests[index].isCompleted { continue }
            if let deadline = state.quests[index].deadlineHour, hour > deadline { continue }
            state.quests[index].progressML = min(goalML, todayTotalML)
            if state.quests[index].progressML >= state.quests[index].targetML {
                state.quests[index].isCompleted = true
                state.xp += state.quests[index].rewardXP
                state.coins += 5
            }
        }

        updateStreak(state: &state, entries: allEntries)
        updateAchievements(state: &state, entries: allEntries, goalML: goalML, todayTotalML: todayTotalML)
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
        unlock("first-sip", state: &state, condition: !entries.isEmpty)
        unlock("streak-3", state: &state, condition: state.streakDays >= 3)
        unlock("streak-7", state: &state, condition: state.streakDays >= 7)
        unlock("goal-day", state: &state, condition: todayTotalML >= goalML)

        let goalDays = countGoalDays(entries: entries, goalML: goalML)
        unlock("goal-10", state: &state, condition: goalDays >= 10)
    }

    private static func countGoalDays(entries: [HydrationEntry], goalML: Double) -> Int {
        let grouped = Dictionary(grouping: entries) { $0.date.startOfDay }
        return grouped.values.filter { dayEntries in
            dayEntries.reduce(0.0) { $0 + $1.volumeML } >= goalML
        }.count
    }

    private static func unlock(_ id: String, state: inout GameState, condition: Bool) {
        guard condition else { return }
        guard let index = state.achievements.firstIndex(where: { $0.id == id }) else { return }
        if !state.achievements[index].isUnlocked {
            state.achievements[index].isUnlocked = true
            state.achievements[index].unlockedAt = Date()
            state.xp += 80
            state.coins += 10
        }
    }
}
