import SwiftUI

struct AuthPasswordField: View {
    
    @Binding var password: String
    
    @State private var showPassword = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            
            Text("Password")
                .font(.caption)
                .foregroundColor(AppTheme.textSecondary)
            
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
                    .foregroundColor(AppTheme.textSecondary)
                }
            }
            .foregroundColor(AppTheme.textPrimary)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .padding()
            .background(fieldBackground)
        }
    }
    
    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
            .fill(AppTheme.fieldBackground)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                    .stroke(AppTheme.fieldBorder, lineWidth: 1)
            )
    }
}
