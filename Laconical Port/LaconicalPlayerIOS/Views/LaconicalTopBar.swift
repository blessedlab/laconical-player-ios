import SwiftUI

struct LaconicalTopBar: View {
    @Binding var searchQuery: String
    @Binding var isSearchExpanded: Bool

    var onSettingsTap: () -> Void = {}

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if isSearchExpanded {
                    TextField("Search tracks...", text: $searchQuery)
                        .textFieldStyle(.plain)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .frame(height: 53)
                        .background(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                        )
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                } else {
                    Text("Laconical Library")
                        .font(.system(size: 28, weight: .regular, design: .serif))
                        .foregroundStyle(.white)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }
            }

            Spacer(minLength: 4)

            Group {
                if isSearchExpanded {
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isSearchExpanded = false
                            searchQuery = ""
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 38, height: 38)
                    }
                } else {
                    HStack(spacing: 8) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isSearchExpanded = true
                            }
                        } label: {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 38, height: 38)
                        }

                        Button(action: onSettingsTap) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 38, height: 38)
                        }
                    }
                    .transition(.opacity)
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 58)
        .animation(.easeInOut(duration: 0.3), value: isSearchExpanded)
    }
}
