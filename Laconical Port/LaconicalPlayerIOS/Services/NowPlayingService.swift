import Foundation
import MediaPlayer

final class NowPlayingService {
    private var commandTargets: [(command: MPRemoteCommand, token: Any)] = []

    func configureRemoteCommands(
        onPlay: @escaping () -> Void,
        onPause: @escaping () -> Void,
        onNext: @escaping () -> Void,
        onPrevious: @escaping () -> Void,
        onSeek: @escaping (TimeInterval) -> Void
    ) {
        removeExistingCommandTargets()

        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.isEnabled = true

        register(command: commandCenter.playCommand) { _ in
            onPlay()
            return .success
        }

        register(command: commandCenter.pauseCommand) { _ in
            onPause()
            return .success
        }

        register(command: commandCenter.nextTrackCommand) { _ in
            onNext()
            return .success
        }

        register(command: commandCenter.previousTrackCommand) { _ in
            onPrevious()
            return .success
        }

        register(command: commandCenter.changePlaybackPositionCommand) { event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            onSeek(event.positionTime)
            return .success
        }
    }

    func updateNowPlaying(
        track: Track,
        elapsed: TimeInterval,
        duration: TimeInterval,
        isPlaying: Bool
    ) {
        var nowPlaying = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        nowPlaying[MPMediaItemPropertyTitle] = track.title
        nowPlaying[MPMediaItemPropertyArtist] = track.artist
        nowPlaying[MPMediaItemPropertyAlbumTitle] = track.album
        nowPlaying[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsed
        nowPlaying[MPMediaItemPropertyPlaybackDuration] = duration > 0 ? duration : track.duration
        nowPlaying[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0

        if let artworkImage = track.artworkImage {
            let artwork = MPMediaItemArtwork(boundsSize: artworkImage.size) { _ in
                artworkImage
            }
            nowPlaying[MPMediaItemPropertyArtwork] = artwork
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlaying
    }

    func clear() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        removeExistingCommandTargets()
    }

    private func register(
        command: MPRemoteCommand,
        handler: @escaping (MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus
    ) {
        let token = command.addTarget(handler: handler)
        commandTargets.append((command: command, token: token))
    }

    private func removeExistingCommandTargets() {
        commandTargets.forEach { entry in
            entry.command.removeTarget(entry.token)
        }
        commandTargets.removeAll()
    }
}
