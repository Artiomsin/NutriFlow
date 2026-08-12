import SwiftUI

struct AuthFormView: View {
    
    @Bindable var viewModel: AuthViewModel
    
    let isLogin: Bool
    
    var emailFocused: FocusState<Bool>.Binding
    var passwordFocused: FocusState<Bool>.Binding
    var firstNameFocused: FocusState<Bool>.Binding
    var lastNameFocused: FocusState<Bool>.Binding
    
    var body: some View {
        VStack(spacing: 12) {
            
            AppTextField(
                title: "Email",
                text: $viewModel.email,
                keyboardType: .emailAddress,
                textContentType: .emailAddress,
                focus: emailFocused,
                onSubmit: {
                    passwordFocused.wrappedValue = true
                }
            )
            
            AuthPasswordField(
                password: $viewModel.password,
                textContentType: .password,
                focus: passwordFocused,
                onSubmit: {
                    if isLogin {
                        passwordFocused.wrappedValue = false
                        Task { await viewModel.login() }
                    } else {
                        firstNameFocused.wrappedValue = true
                    }
                }
            )
            
            if !isLogin {
                
                AppTextField(
                    title: "First name",
                    text: $viewModel.firstName,
                    textContentType: .givenName,
                    focus: firstNameFocused,
                    onSubmit: {
                        lastNameFocused.wrappedValue = true
                    }
                )
                
                AppTextField(
                    title: "Last name",
                    text: $viewModel.lastName,
                    textContentType: .familyName,
                    focus: lastNameFocused,
                    onSubmit: {
                        lastNameFocused.wrappedValue = false
                        Task { await viewModel.register() }
                    }
                )
            }
        }.tint(.green)
    }
}
