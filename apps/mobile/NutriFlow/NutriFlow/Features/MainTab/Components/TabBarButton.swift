import SwiftUI

struct TabBarButton: View {

    let icon: String
    let title: String
    let isSelected: Bool
    let isHighlighted: Bool

    var body: some View {

        VStack(spacing: 3) {

            Image(systemName: icon)
                .font(
                    .system(
                        size: AppTheme.tabBarIconSize,
                        weight: isSelected || isHighlighted
                            ? .semibold
                            : .regular
                    )
                )
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(
                    isSelected || isHighlighted
                        ? AppTheme.accent
                        : AppTheme.textSecondary
                )
                .scaleEffect(
                    isHighlighted ? 1.12 : 1
                )
                .animation(
                    .spring(
                        response: 0.22,
                        dampingFraction: 0.72
                    ),
                    value: isHighlighted
                )

            Text(title)
                .font(.caption2.weight(
                    isSelected || isHighlighted
                        ? .medium
                        : .regular
                ))
                .foregroundStyle(
                    isSelected || isHighlighted
                        ? AppTheme.accent
                        : AppTheme.textSecondary
                )
                .opacity(
                    isHighlighted
                        ? 1
                        : isSelected
                            ? 1
                            : 0.82
                )
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .allowsHitTesting(false)
    }
}
