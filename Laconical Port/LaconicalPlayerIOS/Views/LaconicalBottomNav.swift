import SwiftUI

struct LaconicalBottomNav: View {
    @Binding var selectedCategory: LibraryCategory
    var dynamicColor: Color?

    var body: some View {
        let navColor = dynamicColor?.mixed(with: .black, amount: 0.65) ?? Color(red: 0.05, green: 0.05, blue: 0.08)

        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(LibraryCategory.allCases) { category in
                    let isSelected = selectedCategory == category
                    let iconTint = isSelected
                        ? (dynamicColor?.mixed(with: .white, amount: 0.7) ?? .white)
                        : Color(red: 0.4, green: 0.4, blue: 0.4)

                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedCategory = category
                        }
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: category.systemImage)
                                .font(.system(size: 19, weight: .medium))
                                .offset(y: isSelected ? -4 : 0)
                                .scaleEffect(isSelected ? 1.06 : 1)

                            Text(category.title)
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(iconTint)
                        .frame(maxWidth: .infinity)
                        .frame(height: 64)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                Color.black
                RadialGradient(
                    colors: [
                        navColor.opacity(0.35),
                        .black
                    ],
                    center: .init(x: 0.12, y: -0.2),
                    startRadius: 20,
                    endRadius: 900
                )
            }
        )
    }
}
