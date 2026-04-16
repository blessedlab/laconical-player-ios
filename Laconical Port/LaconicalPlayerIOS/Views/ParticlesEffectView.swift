import SwiftUI

struct ParticlesEffectView: View {
    let color: Color
    let isPlaybackActive: Bool
    let particleCount: Int
    let speedMultiplier: Double
    let spreadMultiplier: CGFloat

    init(
        color: Color,
        isPlaybackActive: Bool,
        particleCount: Int = 36,
        speedMultiplier: Double = 0.28,
        spreadMultiplier: CGFloat = 1.0
    ) {
        self.color = color
        self.isPlaybackActive = isPlaybackActive
        self.particleCount = particleCount
        self.speedMultiplier = speedMultiplier
        self.spreadMultiplier = spreadMultiplier
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 45.0, paused: !isPlaybackActive)) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate * speedMultiplier
                let width = max(size.width, 1)
                let height = max(size.height, 1)
                let count = max(particleCount, 0)

                for index in 0..<count {
                    let xSeed = seededValue(index: index, salt: 0.31)
                    let ySeed = seededValue(index: index, salt: 1.73)
                    let sizeSeed = seededValue(index: index, salt: 2.19)
                    let alphaSeed = seededValue(index: index, salt: 5.17)
                    let phase = seededValue(index: index, salt: 3.97) * (Double.pi * 2)
                    let speed = 0.25 + seededValue(index: index, salt: 4.61) * 0.55

                    let radius = CGFloat(1.2 + sizeSeed * 2.8)
                    let alpha = CGFloat(0.08 + alphaSeed * 0.2)

                    let driftX = sin((time * speed) + phase) * (width * 0.11 * spreadMultiplier)
                    let driftY = cos((time * speed * 0.82) + (phase * 1.2)) * (height * 0.09 * spreadMultiplier)

                    let x = wrappedPosition((CGFloat(xSeed) * width) + driftX, limit: width + 24) - 12
                    let y = wrappedPosition((CGFloat(ySeed) * height) + driftY, limit: height + 24) - 12

                    let particleRect = CGRect(x: x, y: y, width: radius, height: radius)

                    context.fill(
                        Path(ellipseIn: particleRect),
                        with: .color(color.opacity(alpha * (isPlaybackActive ? 1 : 0.2)))
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func seededValue(index: Int, salt: Double) -> Double {
        let raw = sin((Double(index) + 1) * 12.9898 + salt * 78.233) * 43758.5453
        return raw - floor(raw)
    }

    private func wrappedPosition(_ value: CGFloat, limit: CGFloat) -> CGFloat {
        guard limit > 0 else { return value }
        let remainder = value.truncatingRemainder(dividingBy: limit)
        return remainder < 0 ? remainder + limit : remainder
    }
}
