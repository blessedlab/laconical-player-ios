import Foundation

struct AlbumGroup: Identifiable {
    let albumID: UInt64
    let title: String
    let artist: String
    let tracks: [Track]

    var id: UInt64 { albumID }
}

struct ArtistGroup: Identifiable {
    let artistID: UInt64
    let name: String
    let tracks: [Track]

    var id: UInt64 { artistID }
}
