import Foundation

struct PlaybackQueue {
    var tracks: [Track]
    var currentIndex: Int

    init(tracks: [Track] = [], currentIndex: Int = 0) {
        self.tracks = tracks
        self.currentIndex = currentIndex
    }

    var currentTrack: Track? {
        guard tracks.indices.contains(currentIndex) else { return nil }
        return tracks[currentIndex]
    }

    mutating func setTracks(_ tracks: [Track], startAt trackID: UInt64) {
        self.tracks = tracks
        if let index = tracks.firstIndex(where: { $0.id == trackID }) {
            currentIndex = index
        } else {
            currentIndex = 0
        }
    }
}
