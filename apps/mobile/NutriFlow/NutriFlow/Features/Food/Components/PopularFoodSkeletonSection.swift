import SwiftUI

struct PopularFoodSkeletonSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Popular")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(0..<3, id: \.self) { _ in
                        PopularFoodSkeletonCard()
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollDisabled(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading popular foods")
    }
}

private struct PopularFoodSkeletonCard: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            SkeletonBlock(height: 205, cornerRadius: 20)

            VStack(alignment: .leading, spacing: 8) {
                SkeletonBlock(width: 118, height: 15)
                SkeletonBlock(width: 88, height: 12)
                HStack(spacing: 4) {
                    SkeletonBlock(width: 38, height: 18, cornerRadius: 9)
                    SkeletonBlock(width: 38, height: 18, cornerRadius: 9)
                    SkeletonBlock(width: 38, height: 18, cornerRadius: 9)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.surfaceElevated, in: .rect(cornerRadius: 16))
            .padding(10)
        }
        .frame(width: 175, height: 205)
        .clipShape(.rect(cornerRadius: 20))
        .skeletonShimmer()
    }
}
