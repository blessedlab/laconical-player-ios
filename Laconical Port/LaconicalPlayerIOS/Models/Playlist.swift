import Foundation

struct Playlist: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var trackIDs: [UInt64]
    let createdAt: Date

    init(id: UUID = UUID(), name: String, trackIDs: [UInt64] = [], createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.trackIDs = trackIDs
        self.createdAt = createdAt
    }
}
