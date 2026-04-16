import Combine
import Foundation
import SwiftUI

@MainActor
final class MainViewModel: ObservableObject {
    @Published var permissionState: MediaLibraryAuthorizationState = .notDetermined
    @Published var allTracks: [Track] = []
    @Published var searchQuery = ""
    @Published var selectedCategory: LibraryCategory = .tracks

    @Published var playlists: [Playlist] = []
    @Published var selectedPlaylistID: UUID?
    @Published var newPlaylistName = ""

    @Published var currentTrack: Track?
    @Published var isPlaying = false
    @Published var currentPosition: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var playbackWaveform: [Float] = Array(repeating: 0.5, count: 64)
    @Published var queue: [Track] = []
    @Published var queueIndex = 0

    @Published var isShuffleEnabled = false
    @Published var repeatMode: RepeatMode = .off

    @Published var playingTrackDominantColor: Color?
    @Published var waveformData: [Float] = []
    @Published var currentNormalizedAmplitude: CGFloat = 0

    @Published var isPlayerExpanded = false
    @Published var expandedFraction: CGFloat = 0
    @Published var isSearchExpanded = false
    @Published var showQueueSheet = false
    @Published var showFileImporter = false
    @Published var importStatusMessage = ""
    @Published var showImportStatus = false

    private let mediaLibraryService: MediaLibraryService
    private let artworkColorService: ArtworkColorService
    private let waveformExtractorService: WaveformExtractorService
    private let playbackService: AudioPlaybackService
    private let playlistStore: PlaylistStore

    private var cancellables = Set<AnyCancellable>()
    private var waveformTask: Task<Void, Never>?
    private var amplitudeTask: Task<Void, Never>?

    init(
        mediaLibraryService: MediaLibraryService = MediaLibraryService(),
        artworkColorService: ArtworkColorService = ArtworkColorService(),
        waveformExtractorService: WaveformExtractorService = WaveformExtractorService(),
        playbackService: AudioPlaybackService? = nil,
        playlistStore: PlaylistStore = PlaylistStore()
    ) {
        self.mediaLibraryService = mediaLibraryService
        self.artworkColorService = artworkColorService
        self.waveformExtractorService = waveformExtractorService
        self.playbackService = playbackService ?? AudioPlaybackService()
        self.playlistStore = playlistStore

        bindPlayback()
        playlists = playlistStore.load()
        startAmplitudeTicker()
    }

    deinit {
        waveformTask?.cancel()
        amplitudeTask?.cancel()
    }

    var filteredTracks: [Track] {
        let base = allTracks.filter { $0.isPlayable }
        guard !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return base
        }

        return base.filter {
            $0.title.localizedCaseInsensitiveContains(searchQuery)
                || $0.artist.localizedCaseInsensitiveContains(searchQuery)
                || $0.album.localizedCaseInsensitiveContains(searchQuery)
        }
    }

    var albumGroups: [AlbumGroup] {
        let grouped = Dictionary(grouping: filteredTracks, by: { $0.albumPersistentID })
        return grouped
            .map { albumID, tracks in
                let sorted = tracks.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
                let representative = sorted.first
                return AlbumGroup(
                    albumID: albumID,
                    title: representative?.album ?? "Unknown Album",
                    artist: representative?.artist ?? "Unknown Artist",
                    tracks: sorted
                )
            }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    var artistGroups: [ArtistGroup] {
        let grouped = Dictionary(grouping: filteredTracks, by: { $0.artistPersistentID })
        return grouped
            .map { artistID, tracks in
                let sorted = tracks.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
                return ArtistGroup(
                    artistID: artistID,
                    name: sorted.first?.artist ?? "Unknown Artist",
                    tracks: sorted
                )
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var selectedPlaylistTracks: [Track] {
        guard let selectedPlaylistID,
              let playlist = playlists.first(where: { $0.id == selectedPlaylistID }) else {
            return []
        }

        let idSet = Set(playlist.trackIDs)
        return filteredTracks.filter { idSet.contains($0.id) }
    }

    var displayTracks: [Track] {
        switch selectedCategory {
        case .tracks:
            return filteredTracks
        case .albums:
            return albumGroups.flatMap(\.tracks)
        case .artists:
            return artistGroups.flatMap(\.tracks)
        case .playlists:
            return selectedPlaylistTracks
        }
    }

    var progress: CGFloat {
        guard duration > 0 else { return 0 }
        return CGFloat(min(max(currentPosition / duration, 0), 1))
    }

    func bootstrap() async {
        mediaLibraryService.ensureImportsFolderExists()
        permissionState = mediaLibraryService.authorizationStatus()

        switch permissionState {
        case .authorized:
            await loadLibrary()
        case .notDetermined:
            permissionState = await mediaLibraryService.requestAuthorization()
            await loadLibrary()
        case .denied, .restricted:
            await loadLibrary()
        }
    }

    func requestPermission() async {
        permissionState = await mediaLibraryService.requestAuthorization()
        await loadLibrary()
    }

    func importAudioFiles(from urls: [URL]) async {
        guard !urls.isEmpty else { return }

        let result = mediaLibraryService.importAudioFiles(from: urls)
        await loadLibrary()

        if result.imported > 0, result.duplicatesSkipped > 0 {
            importStatusMessage = "Imported \(result.imported) file\(result.imported == 1 ? "" : "s"). Skipped \(result.duplicatesSkipped) duplicate\(result.duplicatesSkipped == 1 ? "" : "s")."
        } else if result.imported > 0 {
            importStatusMessage = "Imported \(result.imported) file\(result.imported == 1 ? "" : "s") to Imports."
        } else if result.duplicatesSkipped > 0 {
            importStatusMessage = "Skipped \(result.duplicatesSkipped) duplicate file\(result.duplicatesSkipped == 1 ? "" : "s")."
        } else {
            importStatusMessage = "No files were imported."
        }
        showImportStatus = true
    }

    func loadLibrary() async {
        allTracks = await mediaLibraryService.fetchTracks()

        if selectedCategory == .playlists,
           selectedPlaylistID == nil {
            selectedPlaylistID = playlists.first?.id
        }
    }

    func updateSearchQuery(_ query: String) {
        searchQuery = query
    }

    func setSelectedCategory(_ category: LibraryCategory) {
        selectedCategory = category
        if category != .playlists {
            selectedPlaylistID = nil
        } else if selectedPlaylistID == nil {
            selectedPlaylistID = playlists.first?.id
        }
    }

    func playTrack(_ track: Track) {
        let sourceTracks = queueSourceTracks(for: track)
        playbackService.setQueue(sourceTracks, startAt: track.id, autoplay: true)
    }

    func togglePlayPause() {
        playbackService.togglePlayPause()
    }

    func skipToNext() {
        playbackService.skipToNext()
    }

    func skipToPrevious() {
        playbackService.skipToPrevious()
    }

    func seek(to progress: CGFloat) {
        playbackService.seek(toProgress: min(max(Double(progress), 0), 1))
    }

    func toggleShuffle() {
        playbackService.setShuffleEnabled(!isShuffleEnabled)
    }

    func cycleRepeatMode() {
        playbackService.cycleRepeatMode()
    }

    func addCurrentTrackToQueue() {
        guard let currentTrack else { return }
        playbackService.enqueue(track: currentTrack)
    }

    func removeTrackFromQueue(_ track: Track) {
        playbackService.removeFromQueue(trackID: track.id)
    }

    func createPlaylist() {
        let trimmed = newPlaylistName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        playlists = playlistStore.createPlaylist(named: trimmed, in: playlists)
        selectedPlaylistID = playlists.last?.id
        newPlaylistName = ""
    }

    func deletePlaylist(_ playlist: Playlist) {
        playlists = playlistStore.deletePlaylist(playlist.id, in: playlists)
        if selectedPlaylistID == playlist.id {
            selectedPlaylistID = playlists.first?.id
        }
    }

    func addTrack(_ track: Track, to playlistID: UUID) {
        playlists = playlistStore.add(trackID: track.id, to: playlistID, in: playlists)
    }

    func removeTrack(_ track: Track, from playlistID: UUID) {
        playlists = playlistStore.remove(trackID: track.id, from: playlistID, in: playlists)
    }

    func deleteTrack(_ track: Track) async {
        guard track.isImportedFile else {
            importStatusMessage = "Only imported tracks can be deleted."
            showImportStatus = true
            return
        }

        let deleted = mediaLibraryService.deleteImportedTrack(track)
        guard deleted else {
            importStatusMessage = "Couldn't delete \"\(track.title)\"."
            showImportStatus = true
            return
        }

        playbackService.removeFromQueue(trackID: track.id)
        if currentTrack?.id == track.id {
            playbackService.stop()
        }

        playlists = playlistStore.remove(trackID: track.id, fromAll: playlists)
        await loadLibrary()

        importStatusMessage = "Deleted \"\(track.title)\"."
        showImportStatus = true
    }

    func playlistContains(_ track: Track, playlistID: UUID) -> Bool {
        playlists.first(where: { $0.id == playlistID })?.trackIDs.contains(track.id) == true
    }

    func tracks(for playlist: Playlist) -> [Track] {
        let idSet = Set(playlist.trackIDs)
        return allTracks.filter { idSet.contains($0.id) }
    }

    private func bindPlayback() {
        playbackService.$currentTrack
            .sink { [weak self] track in
                guard let self else { return }
                currentTrack = track
                updateTrackVisuals(for: track)
            }
            .store(in: &cancellables)

        playbackService.$isPlaying
            .assign(to: &$isPlaying)

        playbackService.$currentTime
            .assign(to: &$currentPosition)

        playbackService.$duration
            .assign(to: &$duration)

        playbackService.$realtimeWaveform
            .assign(to: &$playbackWaveform)

        playbackService.$queueState
            .sink { [weak self] queueState in
                self?.queue = queueState.tracks
                self?.queueIndex = queueState.currentIndex
            }
            .store(in: &cancellables)

        playbackService.$isShuffleEnabled
            .assign(to: &$isShuffleEnabled)

        playbackService.$repeatMode
            .assign(to: &$repeatMode)
    }

    private func updateTrackVisuals(for track: Track?) {
        waveformTask?.cancel()

        guard let track else {
            playingTrackDominantColor = nil
            waveformData = []
            currentNormalizedAmplitude = 0
            return
        }

        playingTrackDominantColor = artworkColorService.dominantColor(for: track.artworkImage)

        waveformTask = Task { [weak self] in
            guard let self else { return }
            let waveform = await waveformExtractorService.extractWaveform(for: track.mediaURL)
            guard !Task.isCancelled else { return }
            waveformData = waveform
        }
    }

    private func queueSourceTracks(for track: Track) -> [Track] {
        let source: [Track]

        switch selectedCategory {
        case .tracks:
            source = filteredTracks
        case .albums:
            if let group = albumGroups.first(where: { $0.tracks.contains(track) }) {
                source = group.tracks
            } else {
                source = filteredTracks
            }
        case .artists:
            if let group = artistGroups.first(where: { $0.tracks.contains(track) }) {
                source = group.tracks
            } else {
                source = filteredTracks
            }
        case .playlists:
            source = selectedPlaylistTracks.isEmpty ? filteredTracks : selectedPlaylistTracks
        }

        return source.filter(\.isPlayable)
    }

    private func startAmplitudeTicker() {
        amplitudeTask?.cancel()
        amplitudeTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                if isPlaying {
                    let target: CGFloat

                    if duration > 0, !waveformData.isEmpty {
                        let ratio = currentPosition / duration
                        let clampedRatio = min(max(ratio, 0), 1)
                        let index = Int(Double(waveformData.count - 1) * clampedRatio)
                        target = CGFloat(waveformData[safe: index] ?? 0)
                    } else if !playbackWaveform.isEmpty {
                        let average = playbackWaveform.reduce(0, +) / Float(playbackWaveform.count)
                        target = CGFloat(min(max((average - 0.5) * 2.4, 0), 1))
                    } else {
                        target = 0
                    }

                    let clampedTarget = min(max(target, 0), 1)
                    let boostedTarget = CGFloat(pow(Double(clampedTarget), 0.72))
                    let response: CGFloat = boostedTarget > currentNormalizedAmplitude ? 0.42 : 0.2

                    currentNormalizedAmplitude = (currentNormalizedAmplitude * (1 - response)) + (boostedTarget * response)
                } else {
                    currentNormalizedAmplitude = max(0, currentNormalizedAmplitude * 0.92)
                    if currentNormalizedAmplitude < 0.005 {
                        currentNormalizedAmplitude = 0
                    }
                }

                try? await Task.sleep(for: .milliseconds(16))
            }
        }
    }
}
