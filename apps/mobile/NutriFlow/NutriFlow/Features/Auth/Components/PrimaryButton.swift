
import SwiftUI

struct PrimaryButton: View {
    
    let title: String
    
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundColor(AppTheme.primaryButtonText)
                .frame(maxWidth: .infinity)
                .frame(height: AppTheme.buttonHeight)
                .background(AppTheme.accent)
                .cornerRadius(AppTheme.cornerRadiusMedium)
        }
    }
}
