import Foundation

struct Quest: Identifiable, Codable, Hashable {
    let id: String
    var title: String
    var detail: String
    var targetML: Double
    var deadlineHour: Int?
    var progressML: Double
    var isCompleted: Bool
    var rewardXP: Int
}
