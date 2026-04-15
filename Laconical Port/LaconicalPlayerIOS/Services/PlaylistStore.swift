import Foundation

final class PlaylistStore {
    private let key = "io.laconical.player.playlists"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> [Playlist] {
        guard let data = defaults.data(forKey: key) else { return [] }
        do {
            return try JSONDecoder().decode([Playlist].self, from: data)
        } catch {
            return []
        }
    }

    func save(_ playlists: [Playlist]) {
        guard let data = try? JSONEncoder().encode(playlists) else { return }
        defaults.set(data, forKey: key)
    }

    func createPlaylist(named name: String, in playlists: [Playlist]) -> [Playlist] {
        var updated = playlists
        updated.append(Playlist(name: name.trimmingCharacters(in: .whitespacesAndNewlines)))
        save(updated)
        return updated
    }

    func deletePlaylist(_ playlistID: UUID, in playlists: [Playlist]) -> [Playlist] {
        let updated = playlists.filter { $0.id != playlistID }
        save(updated)
        return updated
    }

    func add(trackID: UInt64, to playlistID: UUID, in playlists: [Playlist]) -> [Playlist] {
        var updated = playlists
        guard let index = updated.firstIndex(where: { $0.id == playlistID }) else {
            return playlists
        }

        if !updated[index].trackIDs.contains(trackID) {
            updated[index].trackIDs.append(trackID)
            save(updated)
        }

        return updated
    }

    func remove(trackID: UInt64, from playlistID: UUID, in playlists: [Playlist]) -> [Playlist] {
        var updated = playlists
        guard let index = updated.firstIndex(where: { $0.id == playlistID }) else {
            return playlists
        }

        updated[index].trackIDs.removeAll { $0 == trackID }
        save(updated)
        return updated
    }
}
