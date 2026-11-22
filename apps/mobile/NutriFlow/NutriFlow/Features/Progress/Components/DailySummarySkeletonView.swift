
import SwiftUI

struct DailySummarySkeletonView: View {

    private let skeletonColor = AppColors.textSecondary.opacity(0.12)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            // Title
            placeholder(width: 125, height: 17)

            // Calories
            placeholder(width: 150, height: 38)

            // Goal progress rows
            ForEach(0..<5, id: \.self) { _ in
                goalProgressSkeleton
            }

            // Macro badges
            HStack(spacing: 12) {
                macroBadgeSkeleton
                macroBadgeSkeleton
                macroBadgeSkeleton
                Spacer()
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .appGlassSurface(level: .prominent)
        .skeletonShimmer()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading daily summary")
    }


    private var goalProgressSkeleton: some View {
        VStack(alignment: .leading, spacing: 8) {

            HStack {
                placeholder(width: 75, height: 13)
                Spacer()
                placeholder(width: 85, height: 13)
            }

            Capsule()
                .fill(skeletonColor)
                .frame(height: 8)
        }
    }


    private var macroBadgeSkeleton: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(skeletonColor)
            .frame(width: 58, height: 30)
    }


    private func placeholder(
        width: CGFloat,
        height: CGFloat
    ) -> some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(skeletonColor)
            .frame(width: width, height: height)
    }

}

