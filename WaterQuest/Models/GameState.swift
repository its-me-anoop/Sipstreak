import Foundation

struct GameState: Codable {
    var xp: Int
    var coins: Int
    var streakDays: Int
    var lastStreakDate: Date?
    var lastQuestRefresh: Date?
    var achievements: [Achievement]
    var quests: [Quest]

    static let `default` = GameState(
        xp: 0,
        coins: 0,
        streakDays: 0,
        lastStreakDate: nil,
        lastQuestRefresh: nil,
        achievements: [],
        quests: []
    )

    var level: Int {
        max(1, Int(sqrt(Double(xp) / 50.0)) + 1)
    }

    var xpToNextLevel: Int {
        let nextLevel = level + 1
        return Int(pow(Double(nextLevel - 1), 2) * 50) - xp
    }
}
