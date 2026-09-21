import SwiftUI

struct FoodImagePlaceholder: View {
    var cornerRadius: CGFloat = 12
    var iconSize: CGFloat = 24
    var usesTintedBackground = false

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(backgroundStyle)
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

        return AnyShapeStyle(AppColors.surface)
    }
}
