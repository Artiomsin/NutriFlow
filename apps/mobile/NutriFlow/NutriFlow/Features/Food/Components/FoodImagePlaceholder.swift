import SwiftUI

struct FoodImagePlaceholder: View {
    var cornerRadius: CGFloat = 12
    var iconSize: CGFloat = 24

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(AppColors.surfaceSecondary)
            .overlay {
                Image(systemName: "fork.knife")
                    .font(.system(size: iconSize, weight: .medium))
                    .foregroundStyle(AppColors.success)
            }
            .accessibilityHidden(true)
    }
}
