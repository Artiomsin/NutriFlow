import SwiftUI

struct ProfileSkeletonContent: View {
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Circle()
                    .fill(AppColors.textSecondary.opacity(0.12))
                    .frame(width: AppSpacing.avatarSize, height: AppSpacing.avatarSize)
                SkeletonBlock(width: 150, height: 22)
                SkeletonBlock(width: 190, height: 14)
                SkeletonBlock(width: 112, height: 38, cornerRadius: AppRadius.small)
            }
            .padding(.top, 40)

            VStack(spacing: 16) {
                ForEach(0..<7, id: \.self) { _ in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(AppColors.textSecondary.opacity(0.12))
                            .frame(width: 40, height: 40)
                        VStack(alignment: .leading, spacing: 7) {
                            SkeletonBlock(width: 64, height: 12)
                            SkeletonBlock(width: 128, height: 16)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.surface, in: .rect(cornerRadius: AppRadius.medium))
                }
            }
        }
        .skeletonShimmer()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading profile")
    }
}
