import SwiftUI

struct ProgressAnalyticsSkeleton: View {
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 14) {
                SkeletonBlock(width: 88, height: 16)
                SkeletonBlock(width: 168, height: 36)
                SkeletonBlock(width: 112, height: 14)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .appGlassSurface(level: .prominent)

            HStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { _ in
                    VStack(spacing: 10) {
                        Circle()
                            .stroke(AppColors.textSecondary.opacity(0.12), lineWidth: 12)
                            .frame(width: 74, height: 74)
                        SkeletonBlock(width: 46, height: 12)
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            HStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 8) {
                        SkeletonBlock(width: 48, height: 12)
                        SkeletonBlock(width: 62, height: 20)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .appGlassSurface()
                }
            }
        }
        .skeletonShimmer()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading nutrition trends")
    }
}

struct ProgressChartsSkeleton: View {
    var body: some View {
        VStack(spacing: 20) {
            ForEach(0..<2, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 16) {
                    SkeletonBlock(width: 118, height: 16)
                    HStack(alignment: .bottom, spacing: 9) {
                        ForEach([62, 108, 78, 128, 94, 116, 72], id: \.self) { height in
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
            }
        }
        .skeletonShimmer()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading charts")
    }
}
