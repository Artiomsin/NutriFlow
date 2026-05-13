import SwiftUI

struct AuthView: View {

    @ObservedObject var viewModel: AuthViewModel
    @State private var isLogin = true

    var body: some View {
        ZStack {

            Color(red: 0.03, green: 0.04, blue: 0.06)
                .ignoresSafeArea()

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
                        .foregroundColor(.white.opacity(0.5))
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
    }
}
