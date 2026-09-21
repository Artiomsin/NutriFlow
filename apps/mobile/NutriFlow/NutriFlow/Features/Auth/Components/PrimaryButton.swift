
import SwiftUI

struct PrimaryButton: View {
    
    let title: String
    
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundColor(AppColors.accentOnPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: AppSpacing.buttonHeight)
                .background(AppColors.accent)
                .cornerRadius(AppRadius.medium)
        }
    }
}
