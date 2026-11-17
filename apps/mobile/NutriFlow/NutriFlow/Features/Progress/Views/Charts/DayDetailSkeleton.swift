import SwiftUI

struct DayDetailSkeleton: View {
    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 24) {
                ForEach(0..<3, id: \.self) { _ in
                    VStack(spacing: 8) {
                        Circle().fill(AppColors.textSecondary.opacity(0.12)).frame(width: 28, height: 28)
                        SkeletonBlock(width: 40, height: 18)
                        SkeletonBlock(width: 30, height: 10)
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            ForEach(0..<3, id: \.self) { index in
                VStack(alignment: .leading, spacing: 16) {
                    SkeletonBlock(width: index == 0 ? 104 : 82, height: 16)
                    ForEach(0..<2, id: \.self) { _ in
                        VStack(alignment: .leading, spacing: 7) {
                            SkeletonBlock(width: 78, height: 12)
                            SkeletonBlock(height: 10, cornerRadius: 5)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .appGlassSurface()
            }
        }
        .padding(.top, 8)
        .skeletonShimmer()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading day details")
    }
}
