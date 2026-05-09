import SwiftUI

struct AuthView: View {
    
    @EnvironmentObject var vm: AuthViewModel
    
    @State private var isLogin = true
    
    var body: some View {
        ZStack {
            
            Color(red: 0.03, green: 0.04, blue: 0.06)
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                
                VStack(spacing: 20) {
                    
                    AuthHeaderView(isLogin: isLogin)
                    
                    AuthFormView(
                        vm: vm,
                        isLogin: isLogin
                    )
                    
                    if let error = vm.errorMessage {
                        ErrorMessageView(text: error)
                    }
                    
                    PrimaryButton(
                        title: isLogin ? "Sign in" : "Create account"
                    ) {
                        Task {
                            isLogin ? await vm.login() : await vm.register()
                        }
                    }
                    
                    Button {
                        isLogin.toggle()
                    } label: {
                        Text(
                            isLogin
                            ? "No account? Register"
                            : "Already have account? Sign in"
                        )
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.5))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 80)
                .frame(maxWidth: 360)
                .frame(maxWidth: .infinity)
            }
        }
    }
}
