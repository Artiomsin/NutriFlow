import SwiftUI

struct AuthFormView: View {
    
    @Bindable var viewModel: AuthViewModel
    
    let isLogin: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            
            AppTextField(
                title: "Email",
                text: $viewModel.email
            )
            
            AuthPasswordField(
                password: $viewModel.password
            )
            
            if !isLogin {
                
                AppTextField(
                    title: "First name",
                    text: $viewModel.firstName
                )
                
                AppTextField(
                    title: "Last name",
                    text: $viewModel.lastName
                )
            }
        }.tint(.green)
    }
}
