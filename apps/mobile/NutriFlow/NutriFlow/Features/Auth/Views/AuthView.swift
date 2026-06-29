import SwiftUI

struct AuthView: View {
    @Bindable var viewModel: AuthViewModel
    @State private var isLogin = true

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                AuthHeaderView(isLogin: isLogin)
                AuthFormView(viewModel: viewModel, isLogin: isLogin) 

                PrimaryButton(title: isLogin ? "Sign in" : "Create account") {
                    Task {
                        if isLogin {
                            await viewModel.login()
                        } else {
                            await viewModel.register()
                        }
                    }
                }

                if isLogin {
                    Button {
                        Task { await viewModel.signInWithGoogle() }
                    } label: {
                        HStack {
                            Image(systemName: "g.circle.fill")
                                .font(.title2)
                            Text("Sign in with Google")
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.white)
                        .foregroundColor(.black)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    }
                }

                Button {
                    isLogin.toggle()
                } label: {
                    Text(isLogin ? "No account? Register" : "Already have account? Sign in")
                        .font(.footnote)
                        .foregroundColor(AppTheme.textSecondary)
                }

                if isLogin {
                    Button {
                        viewModel.continueAsGuest()
                    } label: {
                        Text("Continue as Guest")
                            .font(.footnote.weight(.medium))
                            .foregroundColor(AppTheme.accent)
                    }
                    .padding(.top, 4)
                }

                if case .error(let message) = viewModel.state {
                    ErrorMessageView(text: message)
                }

                if case .loading = viewModel.state {
                    ProgressView().tint(.white)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 80)
            .frame(maxWidth: 360)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.immediately)
        .background(AppTheme.background.ignoresSafeArea())
        .onAppear {
            AnalyticsManager.shared.track(.screenView(screen: "auth"))
        }
    }
}

#Preview("AuthView") {
    let container = AppDependencyContainer()
    let viewModel = AuthViewModel(
        authService: MockAuthService(),
        profileService: MockProfileService(),
        googleSignInService: container.googleSignInService,
        coordinator: AppCoordinator(container: container)
    )
    
    AuthView(viewModel: viewModel)
}
