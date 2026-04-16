import SwiftUI

struct FullPlayerView: View {
    let track: Track
    let isPlaying: Bool
    let dominantColor: Color?
    let expandedFraction: CGFloat

    let waveform: [Float]
    let progress: CGFloat
    let currentTime: TimeInterval
    let duration: TimeInterval

    let isShuffleEnabled: Bool
    let repeatMode: RepeatMode

    let onCollapse: () -> Void
    let onSeek: (CGFloat) -> Void
    let onToggleShuffle: () -> Void
    let onCycleRepeat: () -> Void
    let onShowQueue: () -> Void

    private var themeColor: Color {
        dominantColor ?? Color(red: 0.12, green: 0.12, blue: 0.12)
    }

    private var activeSeekColor: Color {
        guard let hsl = themeColor.toHSL() else {
            return themeColor
        }

        return Color(
            hue: Double(hsl.hue),
            saturation: Double(min(max(hsl.saturation, 0.2), 0.5)),
            brightness: 0.62
        )
    }

    private var backgroundColor: Color {
        themeColor.mixed(with: Color(red: 0.04, green: 0.04, blue: 0.05), amount: 0.92)
    }

    private let expandedMediaLiftOffset: CGFloat = 40
    private let waveformDropOffset: CGFloat = 19
    private let artistRowLiftOffset: CGFloat = 28
    private let artistExtraLiftOffset: CGFloat = 14
    private let heartExtraLiftOffset: CGFloat = 8
    private let artistDropOffset: CGFloat = 28
    private let artistRightOffset: CGFloat = -5
    private let heartDropOffset: CGFloat = 40

    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea(.container, edges: .horizontal)

            ParticlesEffectView(
                color: activeSeekColor,
                isPlaybackActive: isPlaying,
                particleCount: 25
            )

            VStack(spacing: 0) {
                HStack {
                    Button(action: onCollapse) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 30, weight: .regular))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)

                    Text(track.album.uppercased())
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.gray)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)

                    Button(action: {}) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 19, weight: .regular))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                }
                .frame(height: 48)

                Spacer().frame(height: 64)

                // Album art spacer (morphing overlay renders the actual image)
                Color.clear
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .padding(.horizontal, 6)

                Spacer().frame(height: 54)

                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 3) {
                        // Invisible ghost title for layout matching with morph overlay
                        Text(track.title)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.clear)
                            .lineLimit(1)

                        Text(track.artist)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.gray)
                            .lineLimit(1)
                    }
                            .offset(x: artistRightOffset, y: -artistExtraLiftOffset + artistDropOffset)

                    Spacer()

                    Button(action: {}) {
                        Image(systemName: "heart")
                            .font(.system(size: 27, weight: .regular))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .offset(y: -heartExtraLiftOffset + heartDropOffset)
                }
                .padding(.horizontal, 24)
                .offset(y: -artistRowLiftOffset)

                VStack(spacing: 0) {
                    Spacer().frame(height: 10)

                    VisualizerSeekBarView(
                        waveform: waveform,
                        progress: progress,
                        duration: duration,
                        activeColor: activeSeekColor,
                        isPlaying: isPlaying,
                        onSeek: onSeek
                    )
                    .padding(.horizontal, 24)

                    HStack {
                        Text(currentTime.mmss)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(.gray)
                        Spacer()
                        Text(duration.mmss)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(.gray)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                }
                .offset(y: -expandedMediaLiftOffset + waveformDropOffset)

                // Ghost controls for spacing; morphing overlay provides actual controls.
                HStack {
                    Image(systemName: "backward.fill")
                    Spacer()
                    Circle().frame(width: 72, height: 72)
                    Spacer()
                    Image(systemName: "forward.fill")
                }
                .font(.system(size: 48, weight: .regular))
                .foregroundStyle(.clear)
                .padding(.horizontal, 32)
                .padding(.top, 4)

                Spacer().frame(height: 24)

                Divider()
                    .overlay(.white.opacity(0.15))
                    .padding(.horizontal, 48)

                HStack {
                    Button(action: onToggleShuffle) {
                        Image(systemName: "shuffle")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(isShuffleEnabled ? .white : .gray)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button(action: onShowQueue) {
                        Text("UP NEXT")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.gray)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button(action: {}) {
                        Text("LYRICS")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.gray)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button(action: onCycleRepeat) {
                        Image(systemName: repeatMode.iconName)
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(repeatMode.isActive ? .white : .gray)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .opacity(expandedFraction)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
