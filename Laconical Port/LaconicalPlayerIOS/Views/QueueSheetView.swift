import SwiftUI

struct QueueSheetView: View {
    let queue: [Track]
    let currentIndex: Int
    let onPlayTrack: (Track) -> Void
    let onRemoveTrack: (Track) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if queue.isEmpty {
                    Text("Queue is empty")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(queue.enumerated()), id: \.element.id) { index, track in
                        HStack(spacing: 12) {
                            if index == currentIndex {
                                Image(systemName: "speaker.wave.2.fill")
                                    .foregroundStyle(.white)
                            } else {
                                Image(systemName: "music.note")
                                    .foregroundStyle(.gray)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(track.title)
                                    .font(.system(size: 16, weight: .semibold))
                                Text(track.artist)
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button(role: .destructive) {
                                onRemoveTrack(track)
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.plain)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onPlayTrack(track)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Up Next")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
