import AVFoundation
import Combine
import Foundation
import UIKit

@MainActor
final class AudioPlaybackService: ObservableObject {
    @Published private(set) var queueState = PlaybackQueue()
    @Published private(set) var currentTrack: Track?
    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var realtimeWaveform: [Float] = Array(repeating: 0.5, count: 64)
    @Published private(set) var repeatMode: RepeatMode = .off
    @Published private(set) var isShuffleEnabled = false

    private let player = AVPlayer()
    private let nowPlayingService: NowPlayingService

    private var originalQueue: [Track] = []
    private var timeObserverToken: Any?

    init(nowPlayingService: NowPlayingService = NowPlayingService()) {
        self.nowPlayingService = nowPlayingService

        configureAudioSession()
        addTimeObserver()
        observePlaybackEnd()
        observeAudioInterruptions()
        observeApplicationLifecycle()

        UIApplication.shared.beginReceivingRemoteControlEvents()

        nowPlayingService.configureRemoteCommands(
            onPlay: { [weak self] in
                Task { @MainActor in self?.play() }
            },
            onPause: { [weak self] in
                Task { @MainActor in self?.pause() }
            },
            onNext: { [weak self] in
                Task { @MainActor in self?.skipToNext() }
            },
            onPrevious: { [weak self] in
                Task { @MainActor in self?.skipToPrevious() }
            },
            onSeek: { [weak self] target in
                Task { @MainActor in self?.seek(to: target) }
            }
        )
    }

    deinit {
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
        }
        NotificationCenter.default.removeObserver(self)
        nowPlayingService.clear()
    }

    var queue: [Track] {
        queueState.tracks
    }

    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(max(currentTime / duration, 0), 1)
    }

    func setQueue(_ tracks: [Track], startAt trackID: UInt64, autoplay: Bool = true) {
        originalQueue = tracks
        guard !tracks.isEmpty else {
            queueState = PlaybackQueue()
            currentTrack = nil
            pause()
            return
        }

        if isShuffleEnabled {
            var shuffled = tracks.filter { $0.id != trackID }.shuffled()
            if let startTrack = tracks.first(where: { $0.id == trackID }) {
                shuffled.insert(startTrack, at: 0)
            }
            queueState = PlaybackQueue(tracks: shuffled, currentIndex: 0)
        } else {
            queueState.setTracks(tracks, startAt: trackID)
        }

        loadCurrentTrack(autoplay: autoplay)
    }

    func enqueue(track: Track) {
        originalQueue.append(track)
        queueState.tracks.append(track)
    }

    func removeFromQueue(trackID: UInt64) {
        originalQueue.removeAll { $0.id == trackID }

        let previousCurrentID = queueState.currentTrack?.id
        queueState.tracks.removeAll { $0.id == trackID }

        if queueState.tracks.isEmpty {
            queueState.currentIndex = 0
            currentTrack = nil
            pause()
            return
        }

        if let previousCurrentID,
           let newIndex = queueState.tracks.firstIndex(where: { $0.id == previousCurrentID }) {
            queueState.currentIndex = newIndex
        } else {
            queueState.currentIndex = min(queueState.currentIndex, queueState.tracks.count - 1)
            loadCurrentTrack(autoplay: false)
        }
    }

    func play() {
        guard player.currentItem != nil else {
            loadCurrentTrack(autoplay: true)
            return
        }

        activateAudioSession()
        player.play()
        isPlaying = true
        refreshNowPlaying()
    }

    func pause() {
        player.pause()
        isPlaying = false
        refreshNowPlaying()
    }

    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        isPlaying = false
        currentTime = 0
        duration = 0
        realtimeWaveform = Array(repeating: 0.5, count: 64)
        nowPlayingService.clear()
    }

    func togglePlayPause() {
        let currentlyPlaying = player.timeControlStatus == .playing || player.rate > 0
        currentlyPlaying ? pause() : play()
    }

    func skipToNext() {
        if repeatMode == .one {
            repeatMode = .all
        }

        if advanceToNextIndex() {
            loadCurrentTrack(autoplay: true)
        } else {
            pause()
            seek(to: 0)
        }
    }

    func skipToPrevious() {
        if currentTime > 3 {
            seek(to: 0)
            return
        }

        let previousIndex = queueState.currentIndex - 1
        if queueState.tracks.indices.contains(previousIndex) {
            queueState.currentIndex = previousIndex
            loadCurrentTrack(autoplay: true)
            return
        }

        if repeatMode == .all, !queueState.tracks.isEmpty {
            queueState.currentIndex = queueState.tracks.count - 1
            loadCurrentTrack(autoplay: true)
        } else {
            seek(to: 0)
        }
    }

    func seek(toProgress progress: Double) {
        guard duration > 0 else { return }
        seek(to: duration * min(max(progress, 0), 1))
    }

    func seek(to seconds: TimeInterval) {
        let clamped = max(seconds, 0)
        player.seek(to: CMTime(seconds: clamped, preferredTimescale: 600))
        currentTime = clamped
        refreshNowPlaying()
    }

    func cycleRepeatMode() {
        var mode = repeatMode
        mode.cycle()
        repeatMode = mode
    }

    func setShuffleEnabled(_ enabled: Bool) {
        guard enabled != isShuffleEnabled else { return }
        isShuffleEnabled = enabled
        rebuildQueueKeepingCurrentTrack()
    }

    private func rebuildQueueKeepingCurrentTrack() {
        guard !originalQueue.isEmpty else { return }

        let currentID = queueState.currentTrack?.id

        if isShuffleEnabled {
            if let currentID,
               let currentTrack = originalQueue.first(where: { $0.id == currentID }) {
                var shuffled = originalQueue.filter { $0.id != currentID }.shuffled()
                shuffled.insert(currentTrack, at: 0)
                queueState = PlaybackQueue(tracks: shuffled, currentIndex: 0)
            } else {
                queueState = PlaybackQueue(tracks: originalQueue.shuffled(), currentIndex: 0)
            }
        } else {
            queueState = PlaybackQueue(tracks: originalQueue, currentIndex: 0)
            if let currentID,
               let index = queueState.tracks.firstIndex(where: { $0.id == currentID }) {
                queueState.currentIndex = index
            }
        }
    }

    private func loadCurrentTrack(autoplay: Bool) {
        guard let track = queueState.currentTrack else {
            currentTrack = nil
            return
        }

        guard let url = track.mediaURL else {
            if advanceToNextIndex() {
                loadCurrentTrack(autoplay: autoplay)
            }
            return
        }

        currentTrack = track
        currentTime = 0
        duration = track.duration

        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)

        if autoplay {
            activateAudioSession()
            player.play()
            isPlaying = true
        } else {
            player.pause()
            isPlaying = false
        }

        refreshNowPlaying()
    }

    private func advanceToNextIndex() -> Bool {
        guard !queueState.tracks.isEmpty else { return false }

        let nextIndex = queueState.currentIndex + 1
        if queueState.tracks.indices.contains(nextIndex) {
            queueState.currentIndex = nextIndex
            return true
        }

        if repeatMode == .all {
            queueState.currentIndex = 0
            return true
        }

        return false
    }

    private func handleTrackEnded() {
        if repeatMode == .one {
            seek(to: 0)
            play()
            return
        }

        if advanceToNextIndex() {
            loadCurrentTrack(autoplay: true)
        } else {
            pause()
            seek(to: 0)
        }
    }

    private func addTimeObserver() {
        let interval = CMTime(seconds: 0.05, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }

            let seconds = time.seconds
            if seconds.isFinite {
                self.currentTime = max(seconds, 0)
            }

            if let itemDuration = self.player.currentItem?.duration.seconds,
               itemDuration.isFinite,
               itemDuration > 0 {
                self.duration = itemDuration
            }

            self.isPlaying = self.player.timeControlStatus == .playing
            self.updateRealtimeWaveform(at: self.currentTime)
            self.refreshNowPlaying()
        }
    }

    private func refreshNowPlaying() {
        guard let currentTrack else { return }
        nowPlayingService.updateNowPlaying(
            track: currentTrack,
            elapsed: currentTime,
            duration: duration,
            isPlaying: isPlaying
        )
    }

    private func updateRealtimeWaveform(at currentTime: TimeInterval) {
        guard !realtimeWaveform.isEmpty else { return }

        if isPlaying {
            let t = Float(currentTime)
            var values = realtimeWaveform
            for index in values.indices {
                let phase = t * 4.8 + Float(index) * 0.19
                let sine = sin(phase)
                let cosine = cos(t * 2.7 + Float(index) * 0.41)
                let value = 0.5 + 0.32 * sine + 0.12 * cosine
                values[index] = min(max(value, 0), 1)
            }
            realtimeWaveform = values
        } else {
            realtimeWaveform = realtimeWaveform.map { 0.5 + ($0 - 0.5) * 0.85 }
        }
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.allowAirPlay, .allowBluetoothA2DP])
            try session.setActive(true)
        } catch {
            // Keep app usable even if audio session setup fails.
        }
    }

    private func activateAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setActive(true)
        } catch {
            // Keep playback flow running even if activation fails intermittently.
        }
    }

    private func observePlaybackEnd() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePlaybackEndedNotification(_:)),
            name: .AVPlayerItemDidPlayToEndTime,
            object: nil
        )
    }

    private func observeAudioInterruptions() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }

    private func observeApplicationLifecycle() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    @objc
    private func handlePlaybackEndedNotification(_ notification: Notification) {
        guard let item = notification.object as? AVPlayerItem,
              item == player.currentItem else {
            return
        }
        handleTrackEnded()
    }

    @objc
    private func handleAudioInterruption(_ notification: Notification) {
        guard let rawValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: rawValue) else {
            return
        }

        switch type {
        case .began:
            pause()
        case .ended:
            guard let optionsRaw = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt else {
                return
            }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsRaw)
            if options.contains(.shouldResume) {
                play()
            }
        @unknown default:
            break
        }
    }

    @objc
    private func handleDidEnterBackground() {
        guard isPlaying else { return }
        activateAudioSession()
        refreshNowPlaying()
    }

    @objc
    private func handleWillEnterForeground() {
        activateAudioSession()
    }
}
