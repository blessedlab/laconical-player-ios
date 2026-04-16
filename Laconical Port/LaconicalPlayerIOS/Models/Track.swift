import Foundation
import MediaPlayer
import UIKit

struct Track: Identifiable, Equatable, Hashable {
    let id: UInt64
    let title: String
    let artist: String
    let album: String
    let duration: TimeInterval
    let mediaURL: URL?
    let artworkImage: UIImage?
    let dateAdded: Date?
    let albumPersistentID: UInt64
    let artistPersistentID: UInt64
    let isImportedFile: Bool

    var isPlayable: Bool {
        mediaURL != nil
    }

    static func == (lhs: Track, rhs: Track) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension Track {
    init(item: MPMediaItem) {
        id = item.persistentID
        title = item.title ?? "Unknown Title"
        artist = item.artist ?? "Unknown Artist"
        album = item.albumTitle ?? "Unknown Album"
        duration = item.playbackDuration
        mediaURL = item.assetURL
        artworkImage = item.artwork?.image(at: CGSize(width: 300, height: 300))
        dateAdded = item.dateAdded
        albumPersistentID = item.albumPersistentID
        artistPersistentID = item.artistPersistentID
        isImportedFile = false
    }
}
