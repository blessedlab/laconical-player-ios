import SwiftUI

struct ParticlesEffectView: View {
    let color: Color
    let isPlaybackActive: Bool
    let particleCount: Int

    private let seeds: [Double]

    init(color: Color, isPlaybackActive: Bool, particleCount: Int = 24) {
        self.color = color
        self.isPlaybackActive = isPlaybackActive
        self.particleCount = particleCount
        self.seeds = (0..<particleCount).map { _ in Double.random(in: 0...1) }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isPlaybackActive)) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate

                for index in seeds.indices {
                    let seed = seeds[index]
                    let speed = 0.15 + seed * 0.85
                    let radius = 1.5 + seed * 3.6
                    let alpha = max(0.06, 0.35 - seed * 0.22)

                    let x = CGFloat(
                        (seed * Double(size.width))
                            + sin(time * speed * 1.3 + seed * 10) * 38
                    ).truncatingRemainder(dividingBy: size.width + 20) - 10

                    let y = CGFloat(
                        (seed * Double(size.height))
                            + cos(time * speed + seed * 8) * 26
                    ).truncatingRemainder(dividingBy: size.height + 20) - 10

                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: radius, height: radius)),
                        with: .color(color.opacity(alpha * (isPlaybackActive ? 1 : 0.2)))
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}
