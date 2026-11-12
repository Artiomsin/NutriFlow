import SwiftUI

/// Matches the geometry of `CategoryFoodCard` to prevent the list from moving
/// when loaded foods replace placeholders.
struct CategoryFoodSkeletonRow: View {
    let showsSelection: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isShimmering = false

    var body: some View {
        HStack(spacing: 12) {
            if showsSelection {
                Circle()
                    .fill(AppColors.surfaceSecondary)
                    .frame(width: 20, height: 20)
            }

            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.surfaceSecondary)
                .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 4) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(AppColors.surfaceSecondary)
                    .frame(width: 148, height: 17)

                HStack(spacing: 6) {
                    Capsule()
                        .fill(AppColors.surfaceSecondary)
                        .frame(width: 58, height: 18)
                    Capsule()
                        .fill(AppColors.surfaceSecondary)
                        .frame(width: 96, height: 16)
                }

                HStack(spacing: 5) {
                    ForEach(0..<3, id: \.self) { _ in
                        Capsule()
                            .fill(AppColors.surfaceSecondary)
                            .frame(width: 48, height: 18)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.surface, in: .rect(cornerRadius: AppRadius.medium))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .stroke(AppColors.border.opacity(0.70), lineWidth: 1)
        }
        .overlay {
            GeometryReader { geometry in
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.10), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * 0.5)
                    .offset(x: isShimmering ? geometry.size.width : -geometry.size.width)
            }
            .clipShape(.rect(cornerRadius: AppRadius.medium))
            .allowsHitTesting(false)
        }
        .task(id: reduceMotion) {
            isShimmering = false
            guard !reduceMotion else { return }

            withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                isShimmering = true
            }
        }
        .accessibilityHidden(true)
    }
}
