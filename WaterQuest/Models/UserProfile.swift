import Foundation

enum ActivityLevel: String, Codable, CaseIterable {
    case chill
    case steady
    case intense

    var label: String {
        switch self {
        case .chill: return "Chill"
        case .steady: return "Steady"
        case .intense: return "Intense"
        }
    }

    var multiplier: Double {
        switch self {
        case .chill: return 32.0
        case .steady: return 35.0
        case .intense: return 38.0
        }
    }
}

struct UserProfile: Codable {
    var name: String
    var unitSystem: UnitSystem
    var weightKg: Double
    var activityLevel: ActivityLevel
    var customGoalML: Double?
    var remindersEnabled: Bool
    var wakeMinutes: Int
    var sleepMinutes: Int
    var dailyReminderCount: Int
    var prefersWeatherGoal: Bool
    var prefersHealthKit: Bool
    var smartRemindersEnabled: Bool

    static let `default` = UserProfile(
        name: "",
        unitSystem: .metric,
        weightKg: 70,
        activityLevel: .steady,
        customGoalML: nil,
        remindersEnabled: true,
        wakeMinutes: 7 * 60,
        sleepMinutes: 22 * 60,
        dailyReminderCount: 7,
        prefersWeatherGoal: false,
        prefersHealthKit: false,
        smartRemindersEnabled: true
    )
}
