import SwiftUI

struct ProfileInfoCard: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: AppSpacing.iconSize))
                .foregroundColor(AppColors.accent)
                .frame(width: 30)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline.bold())
                .foregroundColor(AppColors.textPrimary)
        }
        .padding()
        .background(AppColors.surface)
        .cornerRadius(AppRadius.medium)
    }
}
