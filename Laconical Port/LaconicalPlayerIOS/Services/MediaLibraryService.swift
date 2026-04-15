import Foundation
import MediaPlayer

enum MediaLibraryAuthorizationState {
    case notDetermined
    case denied
    case restricted
    case authorized
}

final class MediaLibraryService {
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
                let items = MPMediaQuery.songs().items ?? []
                let mapped = items.map(Track.init)
                    .sorted {
                        ($0.dateAdded ?? .distantPast) > ($1.dateAdded ?? .distantPast)
                    }
                continuation.resume(returning: mapped)
            }
        }
    }
}
