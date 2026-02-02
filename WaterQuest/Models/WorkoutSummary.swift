import Foundation

struct WorkoutSummary: Codable {
    var exerciseMinutes: Double
    var activeEnergyKcal: Double

    static let empty = WorkoutSummary(exerciseMinutes: 0, activeEnergyKcal: 0)
}
