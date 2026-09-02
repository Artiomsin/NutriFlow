import SwiftUI

struct AuthFormView: View {

    @Bindable var viewModel: AuthViewModel

    let isLogin: Bool

    enum Field: Hashable {
        case email
        case password
        case firstName
        case lastName
    }

    var focusedField: FocusState<Field?>.Binding

    private func nextField(_ field: Field) {
        focusedField.wrappedValue = field
    }

    var body: some View {
        VStack(spacing: 12) {

            AppTextField(
                title: "Email",
                text: $viewModel.email,
                keyboardType: .emailAddress,
                textContentType: .emailAddress,
                submitLabel: .return,
                focus: focusedField,
                focusValue: .email,
                onSubmit: {
                    nextField(.password)
                }
            )

            AuthPasswordField(
                password: $viewModel.password,
                textContentType: isLogin
                    ? .password
                    : .newPassword,
                submitLabel: .return,
                focus: focusedField,
                focusValue: .password,
                onSubmit: {
                    if isLogin {
                        focusedField.wrappedValue = nil

                        Task {
                            await viewModel.login()
                        }
                    } else {
                        nextField(.firstName)
                    }
                }
            )

            if !isLogin {

                AppTextField(
                    title: "First name",
                    text: $viewModel.firstName,
                    textContentType: .givenName,
                    submitLabel: .return,
                    focus: focusedField,
                    focusValue: .firstName,
                    onSubmit: {
                        nextField(.lastName)
                    }
                )

                AppTextField(
                    title: "Last name",
                    text: $viewModel.lastName,
                    textContentType: .familyName,
                    submitLabel: .return,
                    focus: focusedField,
                    focusValue: .lastName,
                    onSubmit: {
                        focusedField.wrappedValue = nil

                        Task {
                            await viewModel.register()
                        }
                    }
                )
            }
        }
        .tint(AppTheme.accent)
    }
}
