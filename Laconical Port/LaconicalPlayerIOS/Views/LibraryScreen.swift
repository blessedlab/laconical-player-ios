import SwiftUI
import UIKit

struct LibraryScreen: View {
    @StateObject private var viewModel = MainViewModel()

    @State private var didBootstrap = false
    @State private var sheetProgress: CGFloat = 0
    @State private var dragOffsetProgress: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let safeTop = proxy.safeAreaInsets.top
            let safeBottom = proxy.safeAreaInsets.bottom

            let miniPlayerHeight: CGFloat = 87
            let bottomNavHeight: CGFloat = 64
            let peekHeight = miniPlayerHeight + bottomNavHeight + safeBottom
            let collapsedTop = proxy.size.height - peekHeight
            let travel = max(collapsedTop, 1)

            let baseProgress = viewModel.currentTrack == nil ? 0 : sheetProgress
            let interactiveProgress = clamp(baseProgress + dragOffsetProgress, lower: 0, upper: 1)
            let sheetTop = collapsedTop - (travel * interactiveProgress)
            let miniAlpha = clamp(1 - interactiveProgress * 2, lower: 0, upper: 1)

            let targetBackground = (viewModel.playingTrackDominantColor ?? Color(red: 0.04, green: 0.04, blue: 0.05))
                .mixed(with: Color(red: 0.04, green: 0.04, blue: 0.05), amount: 0.92)

            ZStack(alignment: .topLeading) {
                targetBackground
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 1.0), value: targetBackground)

                mainContent(safeTop: safeTop, bottomPadding: peekHeight)

                if let currentTrack = viewModel.currentTrack {
                    sheetLayer(
                        track: currentTrack,
                        proxy: proxy,
                        sheetTop: sheetTop,
                        miniAlpha: miniAlpha,
                        expandedFraction: interactiveProgress,
                        travel: travel
                    )

                    morphingOverlay(
                        track: currentTrack,
                        proxy: proxy,
                        sheetTop: sheetTop,
                        expandedFraction: interactiveProgress
                    )
                }
            }
            .task {
                guard !didBootstrap else { return }
                didBootstrap = true
                await viewModel.bootstrap()
            }
            .onChange(of: viewModel.currentTrack?.id) { newValue in
                if newValue == nil {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        sheetProgress = 0
                        dragOffsetProgress = 0
                    }
                }
            }
            .onChange(of: interactiveProgress) { newValue in
                viewModel.expandedFraction = newValue
                viewModel.isPlayerExpanded = newValue > 0.99
            }
            .sheet(isPresented: $viewModel.showQueueSheet) {
                QueueSheetView(
                    queue: viewModel.queue,
                    currentIndex: viewModel.queueIndex,
                    onPlayTrack: { track in
                        viewModel.playTrack(track)
                    },
                    onRemoveTrack: { track in
                        viewModel.removeTrackFromQueue(track)
                    }
                )
            }
        }
    }

    @ViewBuilder
    private func mainContent(safeTop: CGFloat, bottomPadding: CGFloat) -> some View {
        switch viewModel.permissionState {
        case .authorized:
            VStack(spacing: 0) {
                Spacer().frame(height: safeTop)

                LaconicalTopBar(
                    searchQuery: $viewModel.searchQuery,
                    isSearchExpanded: $viewModel.isSearchExpanded
                )

                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: []) {
                        categoryContent
                    }
                    .padding(.bottom, bottomPadding)
                }
            }

        case .notDetermined:
            permissionStateView(
                title: "Laconical",
                subtitle: "Permission required to access audio files",
                buttonTitle: "Grant Permission",
                action: {
                    Task { await viewModel.requestPermission() }
                }
            )

        case .denied, .restricted:
            permissionStateView(
                title: "Laconical",
                subtitle: "Enable media library access in Settings to browse songs",
                buttonTitle: "Open Settings",
                action: {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }
            )
        }
    }

    @ViewBuilder
    private var categoryContent: some View {
        switch viewModel.selectedCategory {
        case .tracks:
            if viewModel.filteredTracks.isEmpty {
                emptyState(text: "No tracks found")
            } else {
                ForEach(viewModel.filteredTracks) { track in
                    trackRow(track)
                }
            }

        case .albums:
            if viewModel.albumGroups.isEmpty {
                emptyState(text: "No albums found")
            } else {
                ForEach(viewModel.albumGroups) { album in
                    sectionHeader(title: album.title, subtitle: album.artist)
                    ForEach(album.tracks) { track in
                        trackRow(track)
                    }
                }
            }

        case .artists:
            if viewModel.artistGroups.isEmpty {
                emptyState(text: "No artists found")
            } else {
                ForEach(viewModel.artistGroups) { artist in
                    sectionHeader(title: artist.name, subtitle: "\(artist.tracks.count) tracks")
                    ForEach(artist.tracks) { track in
                        trackRow(track)
                    }
                }
            }

        case .playlists:
            playlistsContent
        }
    }

    @ViewBuilder
    private var playlistsContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                TextField("New playlist", text: $viewModel.newPlaylistName)
                    .textFieldStyle(.roundedBorder)

                Button("Add") {
                    viewModel.createPlaylist()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)

            if viewModel.playlists.isEmpty {
                emptyState(text: "No playlists yet")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.playlists) { playlist in
                            let isSelected = playlist.id == viewModel.selectedPlaylistID

                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    viewModel.selectedPlaylistID = playlist.id
                                }
                            } label: {
                                Text(playlist.name)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(isSelected ? .black : .white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(isSelected ? .white : Color.white.opacity(0.12))
                                    )
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    viewModel.deletePlaylist(playlist)
                                } label: {
                                    Text("Delete")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }

                let tracks = viewModel.selectedPlaylistTracks
                if tracks.isEmpty {
                    emptyState(text: "No tracks in selected playlist")
                } else {
                    ForEach(tracks) { track in
                        trackRow(track)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func trackRow(_ track: Track) -> some View {
        let isActiveTrack = viewModel.currentTrack?.id == track.id
        let activeColor = viewModel.playingTrackDominantColor ?? Color(red: 0.53, green: 0.53, blue: 0.53)

        TrackListItemView(
            track: track,
            isActiveTrack: isActiveTrack,
            isPlaybackActive: viewModel.isPlaying,
            dominantColor: activeColor,
            playlists: viewModel.playlists,
            playlistContains: { playlistID in
                viewModel.playlistContains(track, playlistID: playlistID)
            },
            onTrackTap: {
                viewModel.playTrack(track)
            },
            onAddToPlaylist: { playlistID in
                viewModel.addTrack(track, to: playlistID)
            },
            onRemoveFromPlaylist: { playlistID in
                viewModel.removeTrack(track, from: playlistID)
            }
        )
    }

    @ViewBuilder
    private func sheetLayer(
        track: Track,
        proxy: GeometryProxy,
        sheetTop: CGFloat,
        miniAlpha: CGFloat,
        expandedFraction: CGFloat,
        travel: CGFloat
    ) -> some View {
        ZStack(alignment: .top) {
            FullPlayerView(
                track: track,
                isPlaying: viewModel.isPlaying,
                dominantColor: viewModel.playingTrackDominantColor,
                expandedFraction: expandedFraction,
                waveform: viewModel.playbackWaveform,
                progress: viewModel.progress,
                currentTime: viewModel.currentPosition,
                duration: viewModel.duration,
                isShuffleEnabled: viewModel.isShuffleEnabled,
                repeatMode: viewModel.repeatMode,
                onCollapse: {
                    collapseSheet()
                },
                onSeek: { progress in
                    viewModel.seek(to: progress)
                },
                onToggleShuffle: {
                    viewModel.toggleShuffle()
                },
                onCycleRepeat: {
                    viewModel.cycleRepeatMode()
                },
                onShowQueue: {
                    viewModel.showQueueSheet = true
                }
            )
            .frame(width: proxy.size.width, height: proxy.size.height)

            if miniAlpha > 0.01 {
                VStack(spacing: 0) {
                    MiniPlayerView(
                        track: track,
                        isPlaying: viewModel.isPlaying,
                        progress: viewModel.progress,
                        vibeColor: viewModel.playingTrackDominantColor,
                        hideArtwork: true,
                        hideControls: true,
                        onTap: {
                            expandSheet()
                        },
                        onPrevious: {
                            viewModel.skipToPrevious()
                        },
                        onTogglePlay: {
                            viewModel.togglePlayPause()
                        },
                        onNext: {
                            viewModel.skipToNext()
                        }
                    )
                    .opacity(miniAlpha)

                    LaconicalBottomNav(
                        selectedCategory: Binding(
                            get: { viewModel.selectedCategory },
                            set: { viewModel.setSelectedCategory($0) }
                        ),
                        dynamicColor: viewModel.playingTrackDominantColor
                    )
                    .opacity(miniAlpha)
                }
            }
        }
        .offset(y: sheetTop)
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffsetProgress = -value.translation.height / max(travel, 1)
                }
                .onEnded { value in
                    let projected = sheetProgress + (-value.predictedEndTranslation.height / max(travel, 1))
                    let shouldExpand = projected > 0.5

                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        sheetProgress = shouldExpand ? 1 : 0
                        dragOffsetProgress = 0
                    }
                }
        )
    }

    @ViewBuilder
    private func morphingOverlay(
        track: Track,
        proxy: GeometryProxy,
        sheetTop: CGFloat,
        expandedFraction: CGFloat
    ) -> some View {
        let width = proxy.size.width
        let safeTop = proxy.safeAreaInsets.top
        let safeBottom = proxy.safeAreaInsets.bottom

        let miniArtSize: CGFloat = 52
        let miniArtLeft: CGFloat = 24
        let miniArtTop = sheetTop + 11.5

        let fullArtSize = (width - 48) * 0.95
        let fullArtLeft = (width - fullArtSize) / 2
        let fullArtTop = safeTop + 16 + 48 + 64

        let morphSize = lerp(miniArtSize, fullArtSize, expandedFraction)
        let morphLeft = lerp(miniArtLeft, fullArtLeft, expandedFraction)
        let morphTop = lerp(miniArtTop, fullArtTop, expandedFraction)
        let cornerRadius = lerp(10, 24, expandedFraction)

        let themeColor = viewModel.playingTrackDominantColor ?? Color(red: 0.12, green: 0.12, blue: 0.12)
        let amplitude = viewModel.currentNormalizedAmplitude
        let shapedAmplitude = amplitude * amplitude
        let pulseIntensity = clamp((expandedFraction - 0.7) / 0.3, lower: 0, upper: 1)
        let pulseScale = 1 - (0.02 * pulseIntensity) + (shapedAmplitude * 0.04 * pulseIntensity)

        let miniTitleLeft = miniArtLeft + miniArtSize + 12
        let miniTitleTop = miniArtTop + 2
        let fullTitleLeft: CGFloat = 48
        let fullTitleTop = fullArtTop + fullArtSize + 70

        let titleLeft = lerp(miniTitleLeft, fullTitleLeft, expandedFraction)
        let titleTop = lerp(miniTitleTop, fullTitleTop, expandedFraction)
        let titleSize = lerp(15, 20, expandedFraction)
        let titleMaxWidth = lerp(
            width - miniTitleLeft - 170,
            width - fullTitleLeft - 86,
            expandedFraction
        )

        let miniCenterY = sheetTop + 37.5
        let miniPrevX = width - 144
        let miniPlayX = width - 96
        let miniNextX = width - 48

        let fullCenterY = proxy.size.height - safeBottom - 170
        let fullPrevX = width * 0.22
        let fullPlayX = width * 0.5
        let fullNextX = width * 0.78

        let prevX = lerp(miniPrevX, fullPrevX, expandedFraction)
        let playX = lerp(miniPlayX, fullPlayX, expandedFraction)
        let nextX = lerp(miniNextX, fullNextX, expandedFraction)
        let controlsY = lerp(miniCenterY, fullCenterY, expandedFraction)

        let prevNextSize = lerp(24, 48, expandedFraction)
        let playContainerSize = lerp(48, 72, expandedFraction)
        let playIconSize = lerp(36, 42, expandedFraction)
        let circleAlpha = expandedFraction

        ZStack(alignment: .topLeading) {
            ZStack {
                if expandedFraction > 0.4 {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(themeColor.opacity(0.18 + shapedAmplitude * 0.2))
                        .blur(radius: 36 + shapedAmplitude * 32)
                }

                Group {
                    if let artwork = track.artworkImage {
                        Image(uiImage: artwork)
                            .resizable()
                            .scaledToFill()
                    } else {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(Color(red: 0.12, green: 0.12, blue: 0.12))
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.system(size: 30, weight: .medium))
                                    .foregroundStyle(Color(red: 0.35, green: 0.35, blue: 0.35))
                            )
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color.white.opacity(lerp(0.02, 0.08, expandedFraction)), lineWidth: 0.5)
                )
            }
            .frame(width: morphSize, height: morphSize)
            .scaleEffect(pulseScale)
            .offset(x: morphLeft, y: morphTop)

            Text(track.title)
                .font(.system(size: titleSize, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .frame(maxWidth: titleMaxWidth, alignment: .leading)
                .offset(x: titleLeft, y: titleTop)

            Button {
                viewModel.skipToPrevious()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: prevNextSize, weight: .regular))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .frame(width: prevNextSize, height: prevNextSize)
            .offset(x: prevX - prevNextSize / 2, y: controlsY - prevNextSize / 2)

            Button {
                viewModel.togglePlayPause()
            } label: {
                ZStack {
                    Circle()
                        .fill(themeColor.opacity(circleAlpha))
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: playIconSize, weight: .medium))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
            .frame(width: playContainerSize, height: playContainerSize)
            .offset(x: playX - playContainerSize / 2, y: controlsY - playContainerSize / 2)

            Button {
                viewModel.skipToNext()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: prevNextSize, weight: .regular))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .frame(width: prevNextSize, height: prevNextSize)
            .offset(x: nextX - prevNextSize / 2, y: controlsY - prevNextSize / 2)
        }
    }

    @ViewBuilder
    private func permissionStateView(
        title: String,
        subtitle: String,
        buttonTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.system(size: 48, weight: .regular, design: .serif))
                .foregroundStyle(.white)

            Text(subtitle)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(.white)

            Button(buttonTitle, action: action)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(.gray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private func emptyState(text: String) -> some View {
        Text(text)
            .font(.system(size: 15, weight: .regular))
            .foregroundStyle(.white.opacity(0.85))
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 28)
    }

    private func expandSheet() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            sheetProgress = 1
            dragOffsetProgress = 0
        }
    }

    private func collapseSheet() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            sheetProgress = 0
            dragOffsetProgress = 0
        }
    }

    private func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        min(max(value, lower), upper)
    }

    private func lerp(_ from: CGFloat, _ to: CGFloat, _ t: CGFloat) -> CGFloat {
        from + (to - from) * clamp(t, lower: 0, upper: 1)
    }
}
