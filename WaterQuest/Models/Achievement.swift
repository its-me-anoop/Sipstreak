import Foundation

struct Achievement: Identifiable, Codable, Hashable {
    let id: String
    var title: String
    var detail: String
    var isUnlocked: Bool
    var unlockedAt: Date?
}
