import Foundation

struct GoalBreakdown: Codable {
    var baseML: Double
    var weatherAdjustmentML: Double
    var workoutAdjustmentML: Double
    var totalML: Double
}
