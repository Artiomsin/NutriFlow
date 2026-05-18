import SwiftUI

struct TabBarButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: AppTheme.tabBarIconSize))
                    .foregroundColor(isSelected ? AppTheme.accent : AppTheme.textSecondary)
                
                Text(title)
                    .font(.caption2)
                    .foregroundColor(isSelected ? AppTheme.accent : AppTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
