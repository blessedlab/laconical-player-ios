import SwiftUI

struct MiniPlayerView: View {
    let track: Track
    let isPlaying: Bool
    let progress: CGFloat
    let vibeColor: Color?
    let hideArtwork: Bool
    let hideControls: Bool

    var onTap: () -> Void
    var onPrevious: () -> Void
    var onTogglePlay: () -> Void
    var onNext: () -> Void

    private var baseColor: Color {
        guard let vibeColor else {
            return Color(red: 0.12, green: 0.12, blue: 0.12)
        }
        return vibeColor.mixed(with: .black, amount: 0.4)
    }

    private var outlineColor: Color {
        guard let vibeColor else {
            return Color.white.opacity(0.2)
        }
        return vibeColor.mixed(with: .white, amount: 0.45).opacity(0.78)
    }

    private let miniPlayerCornerRadius: CGFloat = 18

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Rectangle()
                .fill(Color(red: 0.05, green: 0.05, blue: 0.06))
                .overlay(
                    LinearGradient(
                        colors: [
                            baseColor.opacity(0.5),
                            baseColor.opacity(0.15),
                            Color(red: 0.05, green: 0.05, blue: 0.06)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Button(action: onTap) {
                        artworkView
                    }
                    .buttonStyle(.plain)
                    .allowsHitTesting(!hideArtwork)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(track.title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white.opacity(hideArtwork ? 0 : 1))
                            .lineLimit(1)

                        Text(track.artist)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(Color(red: 0.73, green: 0.73, blue: 0.73))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 4)

                    HStack(spacing: 0) {
                        IconControlButton(systemName: "backward.fill", size: 24, action: onPrevious)
                        IconControlButton(systemName: isPlaying ? "pause.fill" : "play.fill", size: 33, action: onTogglePlay)
                        IconControlButton(systemName: "forward.fill", size: 24, action: onNext)
                    }
                    .opacity(hideControls ? 0 : 1)
                    .allowsHitTesting(!hideControls)
                }
                .padding(.horizontal, 12)
                .frame(height: 72)

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(.white.opacity(0.08))
                            .frame(height: 3)

                        Rectangle()
                            .fill(baseColor.opacity(0.9))
                            .frame(
                                width: proxy.size.width * min(max(progress, 0), 1),
                                height: 3
                            )
                    }
                }
                .frame(height: 3)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 75)
        .clipShape(RoundedRectangle(cornerRadius: miniPlayerCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: miniPlayerCornerRadius, style: .continuous)
                .stroke(outlineColor, lineWidth: 1.2)
        )
        .shadow(color: outlineColor.opacity(0.2), radius: 12, y: 4)
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private var artworkView: some View {
        ZStack {
            if hideArtwork {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.clear)
            } else if let artwork = track.artworkImage {
                Image(uiImage: artwork)
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(red: 0.12, green: 0.12, blue: 0.12))
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(Color(red: 0.35, green: 0.35, blue: 0.35))
                    )
            }
        }
        .frame(width: 52, height: 52)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct IconControlButton: View {
    let systemName: String
    let size: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
    }
}
