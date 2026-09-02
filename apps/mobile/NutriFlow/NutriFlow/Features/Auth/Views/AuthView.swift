import SwiftUI
import AuthenticationServices

struct AuthView: View {
    
    @Bindable var viewModel: AuthViewModel
    
    @State private var isLogin = true
    
    @FocusState private var focusedField: AuthFormView.Field?
    
    @State private var lastEmailChange: Date?
    @State private var lastPasswordChange: Date?
    @State private var autoLoginTriggered = false
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                
                AuthHeaderView(isLogin: isLogin)
                
                AuthFormView(
                    viewModel: viewModel,
                    isLogin: isLogin,
                    focusedField: $focusedField
                )
                
                PrimaryButton(
                    title: isLogin
                    ? "Sign in"
                    : "Create account"
                ) {
                    dismissKeyboard()
                    
                    Task {
                        if isLogin {
                            await viewModel.login()
                        } else {
                            await viewModel.register()
                        }
                    }
                }
                
                if isLogin {
                    GoogleAuthButton {
                        dismissKeyboard()
                        
                        Task {
                            await viewModel.signInWithGoogle()
                        }
                    }
                    
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        switch result {
                        case .success(let authorization):
                            guard
                                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                                let tokenData = credential.identityToken,
                                let identityToken = String(data: tokenData, encoding: .utf8)
                            else {
                                viewModel.state = .error("Failed to get Apple identity token")
                                return
                            }
                            dismissKeyboard()
                            Task {
                                await viewModel.signInWithApple(
                                    identityToken: identityToken,
                                    firstName: credential.fullName?.givenName,
                                    lastName: credential.fullName?.familyName
                                )
                            }
                        case .failure(let error):
                            viewModel.state = .error(error.localizedDescription)
                        }
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: AppTheme.buttonHeight)
                    .cornerRadius(AppTheme.cornerRadiusMedium)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                            .stroke(Color.white, lineWidth: 1)
                    )
                }
                
                Button {
                    switchMode()
                } label: {
                    Text(
                        isLogin
                        ? "No account? Register"
                        : "Already have account? Sign in"
                    )
                    .font(.footnote)
                    .foregroundColor(AppTheme.textSecondary)
                }
                
                if case .error(let message) = viewModel.state {
                    ErrorMessageView(text: message)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                dismissKeyboard()
            }
            .padding(.horizontal, 20)
            .padding(.top, 80)
            .frame(maxWidth: 360)
            .frame(maxWidth: .infinity)
        }
        .background(
            AppTheme.background
                .ignoresSafeArea()
        )
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: viewModel.email) { _, _ in
            lastEmailChange = Date()
            checkAutofillLogin()
        }
        .onChange(of: viewModel.password) { _, _ in
            lastPasswordChange = Date()
            checkAutofillLogin()
        }
        .onAppear {
            AnalyticsManager.shared.track(
                .screenView(screen: "auth")
            )
        }
    }
    
    private func dismissKeyboard() {
        focusedField = nil
    }
    
    private func switchMode() {
        dismissKeyboard()
        
        isLogin.toggle()
        
        lastEmailChange = nil
        lastPasswordChange = nil
        autoLoginTriggered = false
    }
    
    private func checkAutofillLogin() {
        guard
            isLogin,
            !autoLoginTriggered,
            viewModel.state != .loading,
            viewModel.email.contains("@"),
            viewModel.password.count > 1,
            let emailDate = lastEmailChange,
            let passwordDate = lastPasswordChange,
            abs(
                emailDate.timeIntervalSince(passwordDate)
            ) < 0.5
        else {
            return
        }
        
        autoLoginTriggered = true
        
        dismissKeyboard()
        
        Task {
            await viewModel.login()
        }
    }
}

#Preview("AuthView") {
    let container = AppDependencyContainer()
    
    let viewModel = AuthViewModel(
        authService: MockAuthService(),
        profileService: MockProfileService(),
        googleSignInService: container.googleSignInService,
        coordinator: AppCoordinator(
            container: container
        )
    )
    
    AuthView(viewModel: viewModel)
}
