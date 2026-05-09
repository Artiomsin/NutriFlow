
import SwiftUI

struct AuthHeaderView: View {
    
    let isLogin: Bool
    
    var body: some View {
        VStack(spacing: 6) {
            
            Text(isLogin ? "Welcome back" : "Create account")
                .font(.system(size: 30, weight: .semibold))
                .foregroundColor(.white)
            
            Text(
                isLogin
                ? "Sign in to continue"
                : "Register to get started"
            )
            .font(.footnote)
            .foregroundColor(.white.opacity(0.5))
        }
        .padding(.bottom, 10)
    }
}
