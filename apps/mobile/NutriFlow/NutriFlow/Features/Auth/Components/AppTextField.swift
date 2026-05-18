import SwiftUI

struct AppTextField: View {
    
    let title: String
    
    @Binding var text: String
    
    var keyboardType: UIKeyboardType = .default
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            
            Text(title)
                .font(.caption)
                .foregroundColor(AppTheme.textSecondary)
            
            TextField("", text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(keyboardType)
                .foregroundColor(AppTheme.textPrimary)
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