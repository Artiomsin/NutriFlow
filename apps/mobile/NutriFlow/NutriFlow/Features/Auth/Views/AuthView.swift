import SwiftUI

struct AuthView: View {
    
    @StateObject private var vm: AuthViewModel
    @State private var isLogin = true
    
    init(session: SessionManager) {
        _vm = StateObject(wrappedValue: AuthViewModel(session: session))
    }
    
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
                    
                    PrimaryButton(
                        title: isLogin ? "Sign in" : "Create account"
                    ) {
                        Task {
                            if isLogin {
                                await vm.login()
                            } else {
                                await vm.register()
                            }
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
                    
                    // MARK: - STATE ERROR UI
                    if case .error(let error) = vm.state {
                        ErrorMessageView(text: error.localizedDescription)
                    }
                    
                    // MARK: - LOADING UI
                    if case .loading = vm.state {
                        ProgressView()
                            .tint(.white)
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
