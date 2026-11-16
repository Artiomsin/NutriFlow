import SwiftUI

struct SleepHistorySkeleton: View {
    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 14) {
                SkeletonBlock(width: 118, height: 14)
                HStack(alignment: .bottom, spacing: 10) {
                    ForEach([78, 112, 92, 128, 104, 72, 118], id: \.self) { height in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppColors.textSecondary.opacity(0.12))
                            .frame(maxWidth: .infinity)
                            .frame(height: CGFloat(height))
                    }
                }
                .frame(height: 140, alignment: .bottom)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .appGlassSurface()

            VStack(alignment: .leading, spacing: 10) {
                SkeletonBlock(width: 54, height: 14)
                ForEach(0..<3, id: \.self) { _ in
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            SkeletonBlock(width: 96, height: 15)
                            SkeletonBlock(width: 72, height: 12)
                        }
                        Spacer()
                        SkeletonBlock(width: 42, height: 16)
                    }
                    .padding()
                    .appGlassSurface()
                }
            }
        }
        .padding(.horizontal, AppSpacing.paddingHorizontal)
        .padding(.vertical)
        .skeletonShimmer()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading sleep history")
    }
}
