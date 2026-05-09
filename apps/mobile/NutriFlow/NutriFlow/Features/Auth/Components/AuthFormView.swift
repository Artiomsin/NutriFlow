
import SwiftUI

struct AuthFormView: View {
    
    @ObservedObject var vm: AuthViewModel
    
    let isLogin: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            
            AppTextField(
                title: "Email",
                text: $vm.email
            )
            
            AuthPasswordField(
                password: $vm.password
            )
            
            if !isLogin {
                
                AppTextField(
                    title: "First name",
                    text: $vm.firstName
                )
                
                AppTextField(
                    title: "Last name",
                    text: $vm.lastName
                )
            }
        }
    }
}
