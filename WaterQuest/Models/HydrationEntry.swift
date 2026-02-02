import Foundation

enum HydrationSource: String, Codable {
    case manual
    case healthKit
}

struct HydrationEntry: Identifiable, Codable, Hashable {
    let id: UUID
    var date: Date
    var volumeML: Double
    var source: HydrationSource
    var note: String?

    init(id: UUID = UUID(), date: Date, volumeML: Double, source: HydrationSource, note: String? = nil) {
        self.id = id
        self.date = date
        self.volumeML = volumeML
        self.source = source
        self.note = note
    }
}
