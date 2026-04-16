import SwiftUI
import UIKit

struct LibraryScreen: View {
    @StateObject private var viewModel = MainViewModel()

    @State private var didBootstrap = false
    @State private var sheetProgress: CGFloat = 0
    @GestureState private var dragTranslationY: CGFloat = 0
    @State private var cachedSafeBottomInset: CGFloat = 0

    private var playerSheetAnimation: Animation {
        .interactiveSpring(response: 0.32, dampingFraction: 0.92, blendDuration: 0.08)
    }

    private let quickSwipeDistance: CGFloat = 64
    private let expandedPlayerLift: CGFloat = 36

    var body: some View {
        GeometryReader { proxy in
            let rawSafeBottom = proxy.safeAreaInsets.bottom
            let safeBottom = rawSafeBottom > 0 ? rawSafeBottom : cachedSafeBottomInset

            let miniPlayerHeight: CGFloat = 87
            let bottomNavHeight: CGFloat = 64
            let peekHeight = miniPlayerHeight + bottomNavHeight
            let collapsedTop = proxy.size.height + safeBottom - peekHeight
            let travel = max(collapsedTop, 1)
            let contentBottomPadding = viewModel.currentTrack == nil
                ? (bottomNavHeight + safeBottom)
                : (peekHeight + safeBottom)

            let baseProgress = viewModel.currentTrack == nil ? 0 : sheetProgress
            let dragProgress = clamp(-dragTranslationY / max(travel, 1), lower: -1, upper: 1)
            let interactiveProgress = clamp(baseProgress + dragProgress, lower: 0, upper: 1)
            let mediaExpandedFraction = interactiveProgress
            let sheetTop = collapsedTop - (travel * interactiveProgress)
            let collapsedMiniArtTop = collapsedTop + 11.5
            let collapsedMiniControlsY = collapsedTop + 37.5
            let miniAlpha = clamp(1 - interactiveProgress * 2, lower: 0, upper: 1)

            let targetBackground = (viewModel.playingTrackDominantColor ?? Color(red: 0.04, green: 0.04, blue: 0.05))
                .mixed(with: Color(red: 0.04, green: 0.04, blue: 0.05), amount: 0.92)

            ZStack(alignment: .topLeading) {
                targetBackground
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 1.0), value: targetBackground)

                mainContent(bottomPadding: contentBottomPadding)

                if let currentTrack = viewModel.currentTrack {
                    ZStack(alignment: .topLeading) {
                        sheetLayer(
                            track: currentTrack,
                            proxy: proxy,
                            sheetTop: sheetTop,
                            miniAlpha: miniAlpha,
                            expandedFraction: interactiveProgress,
                            safeBottom: safeBottom
                        )

                        morphingOverlay(
                            track: currentTrack,
                            proxy: proxy,
                            expandedFraction: interactiveProgress,
                            mediaExpandedFraction: mediaExpandedFraction,
                            collapsedMiniArtTop: collapsedMiniArtTop,
                            collapsedMiniControlsY: collapsedMiniControlsY
                        )

                        if miniAlpha > 0.01 {
                            // Reliable tap zone for expanding from mini-player body.
                            // Keep the right control area free so play/prev/next remain tappable.
                            Color.clear
                                .frame(width: max(proxy.size.width - 140, 0), height: 75)
                                .contentShape(Rectangle())
                                .offset(y: sheetTop)
                                .onTapGesture {
                                    expandSheet()
                                }
                        }
                    }
                    .offset(y: -expandedPlayerLift * interactiveProgress)
                    .simultaneousGesture(sheetDragGesture(travel: travel))
                }

                let navOpacity = viewModel.currentTrack == nil ? 1 : miniAlpha
                LaconicalBottomNav(
                    selectedCategory: Binding(
                        get: { viewModel.selectedCategory },
                        set: { viewModel.setSelectedCategory($0) }
                    ),
                    dynamicColor: viewModel.playingTrackDominantColor
                )
                .opacity(navOpacity)
                .allowsHitTesting(navOpacity > 0.02)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .ignoresSafeArea(.container, edges: .bottom)
            }
            .onAppear {
                if rawSafeBottom > 0 {
                    cachedSafeBottomInset = rawSafeBottom
                }
            }
            .onChange(of: rawSafeBottom) { newValue in
                if newValue > 0 {
                    cachedSafeBottomInset = newValue
                }
            }
            .task {
                guard !didBootstrap else { return }
                didBootstrap = true
                await viewModel.bootstrap()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                snapSheetToNearestAnchor(animated: false)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                snapSheetToNearestAnchor(animated: false)
                Task { await viewModel.loadLibrary() }
            }
            .onChange(of: viewModel.currentTrack?.id) { newValue in
                if newValue == nil {
                    withAnimation(playerSheetAnimation) {
                        sheetProgress = 0
                    }
                }
            }
            .onChange(of: interactiveProgress) { newValue in
                viewModel.expandedFraction = newValue
                viewModel.isPlayerExpanded = newValue > 0.99
            }
            .fullScreenCover(isPresented: $viewModel.showFileImporter) {
                AudioDocumentPickerView(
                    onPicked: { urls in
                        Task { await viewModel.importAudioFiles(from: urls) }
                        viewModel.showFileImporter = false
                    },
                    onCancelled: {
                        viewModel.showFileImporter = false
                    }
                )
                .ignoresSafeArea()
            }
            .alert("Import", isPresented: $viewModel.showImportStatus) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.importStatusMessage)
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
    private func mainContent(bottomPadding: CGFloat) -> some View {
        switch viewModel.permissionState {
        case .authorized:
            VStack(spacing: 0) {
                LaconicalTopBar(
                    searchQuery: $viewModel.searchQuery,
                    isSearchExpanded: $viewModel.isSearchExpanded,
                    onSettingsTap: {
                        viewModel.showFileImporter = true
                    }
                )

                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: []) {
                        categoryContent
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, bottomPadding)
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

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
            if viewModel.allTracks.isEmpty {
                permissionStateView(
                    title: "Laconical",
                    subtitle: "Enable media library access in Settings, or add mp3 files to Files > On My iPhone > Laconical Port > Imports.",
                    buttonTitle: "Open Settings",
                    secondaryButtonTitle: "Import Audio Files",
                    action: {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        UIApplication.shared.open(url)
                    },
                    secondaryAction: {
                        viewModel.showFileImporter = true
                    }
                )
            } else {
                VStack(spacing: 0) {
                    LaconicalTopBar(
                        searchQuery: $viewModel.searchQuery,
                        isSearchExpanded: $viewModel.isSearchExpanded,
                        onSettingsTap: {
                            viewModel.showFileImporter = true
                        }
                    )

                    ScrollView {
                        LazyVStack(spacing: 0, pinnedViews: []) {
                            categoryContent
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, bottomPadding)
                    }
                    .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
    }

    @ViewBuilder
    private var categoryContent: some View {
        switch viewModel.selectedCategory {
        case .tracks:
            if viewModel.filteredTracks.isEmpty {
                VStack(spacing: 12) {
                    emptyState(
                        text: "No tracks found. Add mp3 or m4a files to Files > On My iPhone > Laconical Port > Imports, then reopen the app."
                    )

                    Button("Import Audio Files") {
                        viewModel.showFileImporter = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.top, 24)
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
            },
            onDeleteTrack: {
                Task {
                    await viewModel.deleteTrack(track)
                }
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
        safeBottom: CGFloat
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
            .frame(width: proxy.size.width, height: proxy.size.height + safeBottom)

            if miniAlpha > 0.01 {
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
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .offset(y: sheetTop)
    }

    @ViewBuilder
    private func morphingOverlay(
        track: Track,
        proxy: GeometryProxy,
        expandedFraction: CGFloat,
        mediaExpandedFraction: CGFloat,
        collapsedMiniArtTop: CGFloat,
        collapsedMiniControlsY: CGFloat
    ) -> some View {
        let width = proxy.size.width
        let safeTop = proxy.safeAreaInsets.top

        let miniArtSize: CGFloat = 52
        let miniArtLeft: CGFloat = 24
        let miniArtTop = collapsedMiniArtTop
        let expandedMediaLiftOffset: CGFloat = 40

        let fullArtSize = (width - 48) * 0.95
        let fullArtLeft = (width - fullArtSize) / 2
        let fullArtTop = safeTop + 16 + 48 + 64 - expandedMediaLiftOffset

        let morphSize = lerp(miniArtSize, fullArtSize, mediaExpandedFraction)
        let morphLeft = lerp(miniArtLeft, fullArtLeft, mediaExpandedFraction)
        let morphTop = lerp(miniArtTop, fullArtTop, mediaExpandedFraction)
        let cornerRadius = lerp(10, 24, mediaExpandedFraction)

        let themeColor = viewModel.playingTrackDominantColor ?? Color(red: 0.12, green: 0.12, blue: 0.12)
        let amplitude = viewModel.currentNormalizedAmplitude
        let shapedAmplitude = amplitude * amplitude
        let pulseIntensity = viewModel.isPlaying ? lerp(0.45, 1, mediaExpandedFraction) : 0
        let baseShrink = lerp(1, 0.992, mediaExpandedFraction)
        let rawPulseScale = baseShrink - (0.012 * pulseIntensity) + (shapedAmplitude * 0.1 * pulseIntensity)
        let pulseScale = clamp(rawPulseScale, lower: 0.96, upper: 1.13)
        let beatLift = viewModel.isPlaying
            ? -(2 + (6 * shapedAmplitude)) * mediaExpandedFraction
            : -mediaExpandedFraction
        let expandedDropOffset: CGFloat = 40
        let titleExtraLiftOffset: CGFloat = 8
        let expandedTitleRaiseOffset: CGFloat = 142
        let fullControlsLiftOffset: CGFloat = 9

        let miniTitleLeft = miniArtLeft + miniArtSize + 12
        let miniTitleTop = miniArtTop + 2
        let fullTitleLeft: CGFloat = 48
        let fullTitleTop = fullArtTop + fullArtSize + 70 + expandedDropOffset + expandedMediaLiftOffset - titleExtraLiftOffset - expandedTitleRaiseOffset

        let titleLeft = lerp(miniTitleLeft, fullTitleLeft, mediaExpandedFraction)
        let titleTop = lerp(miniTitleTop, fullTitleTop, mediaExpandedFraction)
        let titleSize = lerp(15, 20, mediaExpandedFraction)
        let titleHorizontalAdjust = lerp(0, -20, mediaExpandedFraction)
        let titleVerticalAdjust = lerp(0, 31, mediaExpandedFraction)
        let titleMaxWidth = lerp(
            width - miniTitleLeft - 170,
            width - fullTitleLeft - 86,
            mediaExpandedFraction
        )

        let miniCenterY = collapsedMiniControlsY
        let miniPrevX = width - 144
        let miniPlayX = width - 96
        let miniNextX = width - 48

        let fullCenterY = proxy.size.height - 110 + expandedDropOffset - fullControlsLiftOffset
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
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
            .scaleEffect(pulseScale)
            .offset(x: morphLeft, y: morphTop + beatLift)

            Text(track.title)
                .font(.custom("AvenirNext-DemiBold", size: titleSize))
                .foregroundStyle(.white)
                .lineLimit(1)
                .frame(maxWidth: titleMaxWidth, alignment: .leading)
                .offset(x: titleLeft + titleHorizontalAdjust, y: titleTop + titleVerticalAdjust)

            Button {
                viewModel.skipToPrevious()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: prevNextSize, weight: .regular))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .frame(width: prevNextSize, height: prevNextSize)
            .contentShape(Rectangle())
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
            .contentShape(Circle())
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
            .contentShape(Rectangle())
            .offset(x: nextX - prevNextSize / 2, y: controlsY - prevNextSize / 2)
        }
    }

    @ViewBuilder
    private func permissionStateView(
        title: String,
        subtitle: String,
        buttonTitle: String,
        secondaryButtonTitle: String? = nil,
        action: @escaping () -> Void,
        secondaryAction: (() -> Void)? = nil
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

            if let secondaryButtonTitle, let secondaryAction {
                Button(secondaryButtonTitle, action: secondaryAction)
                    .buttonStyle(.bordered)
            }
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
        withAnimation(playerSheetAnimation) {
            sheetProgress = 1
        }
    }

    private func collapseSheet() {
        withAnimation(playerSheetAnimation) {
            sheetProgress = 0
        }
    }

    private func sheetDragGesture(travel: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 3)
            .updating($dragTranslationY) { value, state, _ in
                guard abs(value.translation.height) >= abs(value.translation.width) * 0.65 else { return }
                state = value.translation.height
            }
            .onEnded { value in
                guard abs(value.translation.height) >= abs(value.translation.width) * 0.65 else {
                    return
                }

                let translationProgress = clamp(-value.translation.height / max(travel, 1), lower: -1, upper: 1)
                let committedProgress = clamp(sheetProgress + translationProgress, lower: 0, upper: 1)

                // Commit to the finger-driven position before the final snap animation.
                var noAnimation = Transaction()
                noAnimation.disablesAnimations = true
                withTransaction(noAnimation) {
                    sheetProgress = committedProgress
                }

                let predictedBlend = (value.translation.height * 0.65) + (value.predictedEndTranslation.height * 0.35)
                let residualTranslation = value.predictedEndTranslation.height - value.translation.height
                let residualProgress = -residualTranslation / max(travel, 1)
                let projectedProgress = clamp(committedProgress + (residualProgress * 0.25), lower: 0, upper: 1)

                if predictedBlend <= -quickSwipeDistance {
                    expandSheet()
                } else if predictedBlend >= quickSwipeDistance {
                    collapseSheet()
                } else {
                    withAnimation(playerSheetAnimation) {
                        sheetProgress = projectedProgress >= 0.5 ? 1 : 0
                    }
                }
            }
    }

    private func snapSheetToNearestAnchor(animated: Bool) {
        let target: CGFloat = sheetProgress >= 0.5 ? 1 : 0

        if animated {
            withAnimation(playerSheetAnimation) {
                sheetProgress = target
            }
        } else {
            sheetProgress = target
        }
    }

    private func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        min(max(value, lower), upper)
    }

    private func lerp(_ from: CGFloat, _ to: CGFloat, _ t: CGFloat) -> CGFloat {
        from + (to - from) * clamp(t, lower: 0, upper: 1)
    }
}
