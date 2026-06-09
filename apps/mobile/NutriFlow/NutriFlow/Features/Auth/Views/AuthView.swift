import SwiftUI

struct AuthView: View {

    @Bindable var viewModel: AuthViewModel
    @State private var isLogin = true

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {

                VStack(spacing: 20) {

                    AuthHeaderView(isLogin: isLogin)

                    AuthFormView(
                        viewModel: viewModel,
                        isLogin: isLogin
                    )

                    PrimaryButton(
                        title: isLogin ? "Sign in" : "Create account"
                    ) {
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

                    if case .loading = viewModel.state {
                        ProgressView().tint(.white)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 80)
                .frame(maxWidth: 360)
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear { AmplitudeService.shared.track(.screenView(screen: "auth")) }
    }
}