import SwiftUI

struct AuthPasswordField: View {
    
    @Binding var password: String
    
    @State private var showPassword = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            
            Text("Password")
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
            
            HStack {
                
                if showPassword {
                    TextField("", text: $password)
                } else {
                    SecureField("", text: $password)
                }
                
                Button {
                    showPassword.toggle()
                } label: {
                    Image(
                        systemName:
                            showPassword
                        ? "eye.slash"
                        : "eye"
                    )
                    .foregroundColor(.white.opacity(0.5))
                }
            }
            .foregroundColor(.white)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .padding()
            .background(fieldBackground)
        }
    }
    
    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.white.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        Color.white.opacity(0.06),
                        lineWidth: 1
                    )
            )
    }
}
