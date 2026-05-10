import SwiftUI

struct AppTextField: View {
    
    let title: String
    
    @Binding var text: String
    
    var keyboardType: UIKeyboardType = .default
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
            
            TextField("", text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(keyboardType)
                .foregroundColor(.white)
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