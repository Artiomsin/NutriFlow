import SwiftUI

struct PrimaryButton: View {
    let title: String
    let isLoading: Bool
    let action: () -> Void

    init(
        title: String,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isLoading = isLoading
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ProgressView()
                        .tint(AppColors.accentOnPrimary)
                } else {
                    Text(title)
                        .font(.headline)
                }
            }
            .foregroundColor(AppColors.accentOnPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: AppSpacing.buttonHeight)
            .background(AppColors.accent)
            .cornerRadius(AppRadius.medium)
        }
        .disabled(isLoading)
    }
}