import SwiftUI

struct FoodImagePlaceholder: View {
    var cornerRadius: CGFloat = 12
    var iconSize: CGFloat = 24
    var usesTintedBackground = false

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(backgroundStyle)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(borderColor, lineWidth: 0.8)
            }
            .overlay {
                Image(systemName: "fork.knife")
                    .font(.system(size: iconSize, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(AppColors.success)
            }
            .accessibilityHidden(true)
    }

    private var backgroundStyle: AnyShapeStyle {
        if usesTintedBackground {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        AppColors.success.opacity(colorScheme == .dark ? 0.28 : 0.18),
                        AppColors.accent.opacity(colorScheme == .dark ? 0.22 : 0.12)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }

        return AnyShapeStyle(
            colorScheme == .light
                ? AppColors.surfaceSecondary
                : Color.white.opacity(0.09)
        )
    }

    private var borderColor: Color {
        if usesTintedBackground {
            return AppColors.success.opacity(colorScheme == .light ? 0.32 : 0.42)
        }

        return colorScheme == .light
            ? AppColors.border.opacity(0.80)
            : Color.white.opacity(0.14)
    }
}
