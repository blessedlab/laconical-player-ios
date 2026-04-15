import Foundation

enum LibraryCategory: String, CaseIterable, Identifiable {
    case tracks
    case albums
    case artists
    case playlists

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tracks:
            return "Tracks"
        case .albums:
            return "Albums"
        case .artists:
            return "Artists"
        case .playlists:
            return "Playlists"
        }
    }

    var systemImage: String {
        switch self {
        case .tracks:
            return "music.note"
        case .albums:
            return "square.stack"
        case .artists:
            return "person"
        case .playlists:
            return "text.badge.plus"
        }
    }
}
