import SwiftUI

struct GoalDirectionChoice: View {
    let goal: Goal
    let isSelected: Bool
    let action: () -> Void

    private var icon: String {
        switch goal {
        case .lose: "arrow.down.right"
        case .maintain: "equal"
        case .gain: "arrow.up.right"
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.bold))
                Text(goal.displayName)
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? AppColors.accentOnPrimary : AppColors.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 72)
            .background {
                RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                    .fill(isSelected ? AppColors.accent : AppColors.surfaceSecondary)
            }
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                    .stroke(
                        isSelected ? AppColors.accent : AppColors.border,
                        lineWidth: isSelected ? 1.5 : 1
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(goal.displayName) direction")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
