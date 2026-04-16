import SwiftUI
import UIKit

struct TrackListItemView: View {
    let track: Track
    let isActiveTrack: Bool
    let isPlaybackActive: Bool
    let dominantColor: Color
    let playlists: [Playlist]
    let playlistContains: (UUID) -> Bool
    let onTrackTap: () -> Void
    let onAddToPlaylist: (UUID) -> Void
    let onRemoveFromPlaylist: (UUID) -> Void
    let onDeleteTrack: () -> Void

    private var titleColor: Color {
        guard isActiveTrack else { return .white }

        let uiColor = UIColor(dominantColor)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
        if luminance < 0.2 {
            return dominantColor.mixed(with: .white, amount: 0.38)
        }
        return dominantColor
    }

    var body: some View {
        Button(action: onTrackTap) {
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.white.opacity(0.015))

                if isActiveTrack {
                    LinearGradient(
                        colors: [
                            dominantColor.opacity(0.15),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )

                    ParticlesEffectView(
                        color: dominantColor,
                        isPlaybackActive: isPlaybackActive,
                        particleCount: 18
                    )
                }

                HStack(spacing: 16) {
                    artworkSlot

                    VStack(alignment: .leading, spacing: 3) {
                        Text(track.title)
                            .font(.system(size: 16, weight: isActiveTrack ? .bold : .semibold, design: .rounded))
                            .foregroundStyle(titleColor)
                            .lineLimit(1)

                        Text(track.artist)
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundStyle(Color(red: 0.67, green: 0.67, blue: 0.67))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 6)

                    Menu {
                        if track.isImportedFile {
                            Button(role: .destructive) {
                                onDeleteTrack()
                            } label: {
                                Text("Delete Track")
                            }

                            Divider()
                        }

                        if playlists.isEmpty {
                            Text("Create a playlist first")
                        } else {
                            ForEach(playlists) { playlist in
                                if playlistContains(playlist.id) {
                                    Button("Remove from \(playlist.name)") {
                                        onRemoveFromPlaylist(playlist.id)
                                    }
                                } else {
                                    Button("Add to \(playlist.name)") {
                                        onAddToPlaylist(playlist.id)
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color(red: 0.47, green: 0.47, blue: 0.47))
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .frame(height: 72)

                Rectangle()
                    .fill(Color.white.opacity(0.05))
                    .frame(height: 0.5)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var artworkSlot: some View {
        ZStack {
            if isActiveTrack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(dominantColor.opacity(0.55))
                    .blur(radius: 14)
                    .frame(width: 52, height: 52)
            }

            Group {
                if let artwork = track.artworkImage {
                    Image(uiImage: artwork)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "music.note")
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(Color(red: 0.35, green: 0.35, blue: 0.35))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(red: 0.12, green: 0.12, blue: 0.12))
                }
            }
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .frame(width: 52, height: 52)
    }
}
