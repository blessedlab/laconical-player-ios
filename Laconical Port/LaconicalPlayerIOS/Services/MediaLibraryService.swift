import Foundation
import AVFoundation
import MediaPlayer

enum MediaLibraryAuthorizationState {
    case notDetermined
    case denied
    case restricted
    case authorized
}

final class MediaLibraryService {
    private let importsFolderName = "Imports"
    private let importsGuideFileName = "Drop mp3 files here.txt"
    private let documentsGuideFileName = "Laconical Port Files.txt"
    private let supportedAudioExtensions: Set<String> = [
        "mp3", "m4a", "aac", "wav", "aif", "aiff", "caf", "flac", "alac"
    ]

    func ensureImportsFolderExists() {
        let importsURL = importsFolderURL(createIfNeeded: true)
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        seedGuideFileIfNeeded(
            at: documentsURL.appendingPathComponent(documentsGuideFileName),
            content: "This folder is visible in Files app. Put audio files in the Imports folder to add them to Laconical Player."
        )
        seedGuideFileIfNeeded(
            at: importsURL.appendingPathComponent(importsGuideFileName),
            content: "Place mp3, m4a, wav, flac and other supported audio files here. Then reopen Laconical Player."
        )
    }

    @discardableResult
    func importAudioFiles(from sourceURLs: [URL]) -> Int {
        ensureImportsFolderExists()

        let fileManager = FileManager.default
        let destinationFolder = importsFolderURL(createIfNeeded: true)
        var importedCount = 0

        for sourceURL in sourceURLs {
            let hasScopedAccess = sourceURL.startAccessingSecurityScopedResource()
            defer {
                if hasScopedAccess {
                    sourceURL.stopAccessingSecurityScopedResource()
                }
            }

            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: sourceURL.path, isDirectory: &isDirectory), !isDirectory.boolValue else {
                continue
            }

            let ext = sourceURL.pathExtension.lowercased()
            guard supportedAudioExtensions.contains(ext) else { continue }

            let destinationURL = uniqueDestinationURL(for: sourceURL, in: destinationFolder)
            if destinationURL.path == sourceURL.path {
                continue
            }

            do {
                try fileManager.copyItem(at: sourceURL, to: destinationURL)
                importedCount += 1
            } catch {
                // Best-effort import; skip problematic files and continue with the rest.
            }
        }

        return importedCount
    }

    func authorizationStatus() -> MediaLibraryAuthorizationState {
        switch MPMediaLibrary.authorizationStatus() {
        case .authorized:
            return .authorized
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .denied
        }
    }

    func requestAuthorization() async -> MediaLibraryAuthorizationState {
        await withCheckedContinuation { continuation in
            MPMediaLibrary.requestAuthorization { status in
                let mapped: MediaLibraryAuthorizationState
                switch status {
                case .authorized:
                    mapped = .authorized
                case .denied:
                    mapped = .denied
                case .restricted:
                    mapped = .restricted
                case .notDetermined:
                    mapped = .notDetermined
                @unknown default:
                    mapped = .denied
                }
                continuation.resume(returning: mapped)
            }
        }
    }

    func fetchTracks() async -> [Track] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let systemTracks = self.fetchSystemMediaTracks()
                let importedTracks = self.fetchImportedFileTracks()

                var mergedByID: [UInt64: Track] = [:]
                for track in systemTracks + importedTracks {
                    mergedByID[track.id] = track
                }

                let sorted = mergedByID.values.sorted {
                    ($0.dateAdded ?? .distantPast) > ($1.dateAdded ?? .distantPast)
                }
                continuation.resume(returning: sorted)
            }
        }
    }

    private func fetchSystemMediaTracks() -> [Track] {
        let items = MPMediaQuery.songs().items ?? []
        return items.map(Track.init)
    }

    private func fetchImportedFileTracks() -> [Track] {
        let folderURL = importsFolderURL(createIfNeeded: true)
        let keys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .creationDateKey,
            .contentModificationDateKey,
            .nameKey
        ]

        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return urls.compactMap { buildImportedTrack(from: $0) }
    }

    private func buildImportedTrack(from fileURL: URL) -> Track? {
        let ext = fileURL.pathExtension.lowercased()
        guard supportedAudioExtensions.contains(ext) else { return nil }

        let values = try? fileURL.resourceValues(forKeys: [
            .isRegularFileKey,
            .creationDateKey,
            .contentModificationDateKey,
            .nameKey
        ])
        guard values?.isRegularFile == true else { return nil }

        let asset = AVURLAsset(url: fileURL)
        let durationSeconds = asset.duration.seconds
        let duration = durationSeconds.isFinite ? durationSeconds : 0

        let metadata = asset.commonMetadata
        let metadataTitle = AVMetadataItem
            .metadataItems(from: metadata, filteredByIdentifier: .commonIdentifierTitle)
            .first?.stringValue
        let metadataArtist = AVMetadataItem
            .metadataItems(from: metadata, filteredByIdentifier: .commonIdentifierArtist)
            .first?.stringValue
        let metadataAlbum = AVMetadataItem
            .metadataItems(from: metadata, filteredByIdentifier: .commonIdentifierAlbumName)
            .first?.stringValue

        let title = (metadataTitle?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap {
            $0.isEmpty ? nil : $0
        } ?? fileURL.deletingPathExtension().lastPathComponent
        let artist = (metadataArtist?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap {
            $0.isEmpty ? nil : $0
        } ?? "Unknown Artist"
        let album = (metadataAlbum?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap {
            $0.isEmpty ? nil : $0
        } ?? "Imported"

        let modifiedDate = values?.contentModificationDate
        let createdDate = values?.creationDate
        let dateAdded = modifiedDate ?? createdDate

        return Track(
            id: stableID(forPath: fileURL.path),
            title: title,
            artist: artist,
            album: album,
            duration: duration,
            mediaURL: fileURL,
            artworkImage: nil,
            dateAdded: dateAdded,
            albumPersistentID: stableID(forText: "album:\(album)"),
            artistPersistentID: stableID(forText: "artist:\(artist)")
        )
    }

    private func importsFolderURL(createIfNeeded: Bool) -> URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let folderURL = documentsURL.appendingPathComponent(importsFolderName, isDirectory: true)

        if createIfNeeded, !FileManager.default.fileExists(atPath: folderURL.path) {
            try? FileManager.default.createDirectory(
                at: folderURL,
                withIntermediateDirectories: true
            )
        }

        return folderURL
    }

    private func uniqueDestinationURL(for sourceURL: URL, in folderURL: URL) -> URL {
        let fileManager = FileManager.default
        let ext = sourceURL.pathExtension
        let baseName = sourceURL.deletingPathExtension().lastPathComponent

        var candidateURL = folderURL.appendingPathComponent(sourceURL.lastPathComponent)
        var suffix = 1

        while fileManager.fileExists(atPath: candidateURL.path) {
            let candidateName = "\(baseName)-\(suffix)"
            candidateURL = folderURL.appendingPathComponent(candidateName).appendingPathExtension(ext)
            suffix += 1
        }

        return candidateURL
    }

    private func stableID(forPath path: String) -> UInt64 {
        stableID(forText: "file:\(path)") | (1 << 63)
    }

    private func stableID(forText text: String) -> UInt64 {
        var hash: UInt64 = 1_469_598_103_934_665_603
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1_099_511_628_211
        }
        return hash
    }

    private func seedGuideFileIfNeeded(at url: URL, content: String) {
        guard !FileManager.default.fileExists(atPath: url.path) else { return }
        try? content.write(to: url, atomically: true, encoding: .utf8)
    }
}
