
import SwiftUI

struct AuthHeaderView: View {
    
    let isLogin: Bool
    
    var body: some View {
        VStack(spacing: 6) {
            
            Text(isLogin ? "Welcome back" : "Create account")
                .font(AppTypography.heading1)
                .foregroundColor(AppColors.textPrimary)
            
            Text(
                isLogin
                ? "Sign in to continue"
                : "Register to get started"
            )
            .font(.footnote)
            .foregroundColor(AppColors.textSecondary)
        }
        .padding(.bottom, 10)
    }
}
