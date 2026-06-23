import SwiftUI

struct AuthView: View {
    @Bindable var viewModel: AuthViewModel
    @State private var isLogin = true
    
    @FocusState private var isFocused: Bool
    @State private var keyboardHeight: CGFloat = 0

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

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
                .padding(.bottom, keyboardHeight)
                .animation(.easeOut(duration: 0.3), value: keyboardHeight)
            }
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture {
                isFocused = false
                keyboardHeight = 0
            }
        }
        .onAppear {
            AnalyticsManager.shared.track(.screenView(screen: "auth"))
        }
        .onDisappear {
            #if DEBUG
            print("AuthView скрылся с экрана")
            #endif
        }
        .onReceive(
            NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
        ) { notification in
            guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
            let height = keyboardFrame.cgRectValue.height
            let safeAreaBottom = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first?
                .windows
                .first?
                .safeAreaInsets
                .bottom ?? 0
            
            withAnimation(.easeOut(duration: 0.3)) {
                keyboardHeight = max(0, height - safeAreaBottom)
                isFocused = true
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
        ) { _ in
            withAnimation(.easeOut(duration: 0.3)) {
                keyboardHeight = 0
                isFocused = false
            }
        }
    }
}

#Preview("AuthView") {
    let viewModel = AuthViewModel(
        authService: MockAuthService(),
        profileService: MockProfileService(),
        coordinator: AppCoordinator(container: AppDependencyContainer())
    )
    
    AuthView(viewModel: viewModel)
}
