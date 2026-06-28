
import SwiftUI

struct AuthHeaderView: View {
    
    let isLogin: Bool
    
    var body: some View {
        VStack(spacing: 6) {
            
            Text(isLogin ? "Welcome back" : "Create account")
                .font(Font.h1)
                .foregroundColor(AppTheme.textPrimary)
            
            Text(
                isLogin
                ? "Sign in to continue"
                : "Register to get started"
            )
            .font(.footnote)
            .foregroundColor(AppTheme.textSecondary)
        }
        .padding(.bottom, 10)
    }
}
