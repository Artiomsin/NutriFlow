import SwiftUI

struct ProfileInfoCard: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: AppTheme.iconSize))
                .foregroundColor(AppTheme.accent)
                .frame(width: 30)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(AppTheme.textSecondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline.bold())
                .foregroundColor(AppTheme.textPrimary)
        }
        .padding()
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.cornerRadiusMedium)
    }
}
