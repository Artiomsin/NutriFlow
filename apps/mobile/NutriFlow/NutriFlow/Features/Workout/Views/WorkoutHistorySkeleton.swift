import SwiftUI

struct WorkoutHistorySkeleton: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                ForEach(0..<5, id: \.self) { _ in
                    HStack(spacing: 14) {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(AppColors.textSecondary.opacity(0.12))
                            .frame(width: 58, height: 58)
                        VStack(alignment: .leading, spacing: 7) {
                            SkeletonBlock(width: 128, height: 16)
                            SkeletonBlock(width: 92, height: 12)
                            SkeletonBlock(width: 156, height: 12)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .appGlassSurface()
                }
            }
            .padding(.horizontal, AppSpacing.paddingHorizontal)
            .padding(.vertical)
        }
        .skeletonShimmer()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading workouts")
    }
}
