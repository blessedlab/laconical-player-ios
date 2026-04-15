import SwiftUI

struct VisualizerSeekBarView: View {
    let waveform: [Float]
    let progress: CGFloat
    let duration: TimeInterval
    let activeColor: Color
    let isPlaying: Bool
    let onSeek: (CGFloat) -> Void

    @State private var isDragging = false
    @State private var dragProgress: CGFloat = 0

    private var displayedProgress: CGFloat {
        isDragging ? dragProgress : progress
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let phase = isPlaying ? CGFloat(Date().timeIntervalSinceReferenceDate * 16.0) : 0

            ZStack(alignment: .leading) {
                Canvas { context, size in
                    let path = waveformPath(in: size, phase: phase)

                    context.stroke(
                        path,
                        with: .color(.white.opacity(0.15)),
                        style: .init(lineWidth: 2, lineCap: .round)
                    )

                    context.saveGState()
                    context.clip(to: CGRect(x: 0, y: 0, width: size.width * displayedProgress, height: size.height))
                    context.stroke(
                        path,
                        with: .color(activeColor.opacity(0.9)),
                        style: .init(lineWidth: 2.5, lineCap: .round)
                    )
                    context.restoreGState()

                    if isDragging {
                        let lineX = size.width * dragProgress
                        let markerRect = CGRect(x: lineX - 1.5, y: 0, width: 3, height: size.height)
                        context.fill(Path(roundedRect: markerRect, cornerRadius: 2), with: .color(.white))
                    }
                }

                if isDragging {
                    let x = width * dragProgress
                    Text((duration * dragProgress).mmss)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .fixedSize()
                        .position(x: min(max(26, x), width - 26), y: -8)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let p = min(max(value.location.x / max(width, 1), 0), 1)
                        if !isDragging {
                            isDragging = true
                        }
                        dragProgress = p
                    }
                    .onEnded { value in
                        let p = min(max(value.location.x / max(width, 1), 0), 1)
                        dragProgress = p
                        onSeek(p)
                        isDragging = false
                    }
            )
            .onTapGesture { location in
                let p = min(max(location.x / max(width, 1), 0), 1)
                onSeek(p)
            }
            .frame(height: height)
        }
        .frame(height: 32)
    }

    private func waveformPath(in size: CGSize, phase: CGFloat) -> Path {
        var path = Path()
        let samples = waveform.isEmpty ? Array(repeating: Float(0.5), count: 64) : waveform
        let step = size.width / CGFloat(max(samples.count - 1, 1))
        let middleY = size.height * 0.55
        let amplitude = size.height * 0.4

        for index in samples.indices {
            let shifted = Int((CGFloat(index) + phase).truncatingRemainder(dividingBy: CGFloat(samples.count)))
            let value = CGFloat(samples[shifted])
            let y = middleY + (value - 0.5) * amplitude
            let x = CGFloat(index) * step

            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        return path
    }
}
