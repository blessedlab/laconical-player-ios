import AVFoundation
import Foundation

final class WaveformExtractorService {
    private let queue = DispatchQueue(label: "io.laconical.waveform", qos: .userInitiated)

    func extractWaveform(for url: URL?, samples: Int = 160) async -> [Float] {
        guard let url else { return [] }

        return await withCheckedContinuation { continuation in
            queue.async {
                let waveform = self.extractSynchronously(from: url, samples: samples)
                continuation.resume(returning: waveform)
            }
        }
    }

    private func extractSynchronously(from url: URL, samples: Int) -> [Float] {
        let bucketCount = max(samples, 32)

        do {
            let file = try AVAudioFile(forReading: url)
            let totalFrames = Int(file.length)
            guard totalFrames > 0 else { return [] }

            let framesPerBucket = max(totalFrames / bucketCount, 1)
            var buckets = Array(repeating: Float.zero, count: bucketCount)

            guard let buffer = AVAudioPCMBuffer(
                pcmFormat: file.processingFormat,
                frameCapacity: 4096
            ) else {
                return []
            }

            var globalFrameIndex = 0
            while true {
                try file.read(into: buffer)
                let frameCount = Int(buffer.frameLength)
                if frameCount == 0 { break }

                guard let channel = buffer.floatChannelData?[0] else {
                    globalFrameIndex += frameCount
                    continue
                }

                for index in 0..<frameCount {
                    let absolute = abs(channel[index])
                    let bucketIndex = min(globalFrameIndex / framesPerBucket, bucketCount - 1)
                    if absolute > buckets[bucketIndex] {
                        buckets[bucketIndex] = absolute
                    }
                    globalFrameIndex += 1
                }
            }

            let maxValue = buckets.max() ?? 0
            guard maxValue > 0 else { return [] }
            return buckets.map { min($0 / maxValue, 1.0) }
        } catch {
            return []
        }
    }
}
