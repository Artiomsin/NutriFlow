import SwiftUI

struct FocusModifier: ViewModifier {
    var focus: FocusState<Bool>.Binding?

    func body(content: Content) -> some View {
        if let focus {
            content.focused(focus)
        } else {
            content
        }
    }
}

struct TextContentTypeModifier: ViewModifier {
    var contentType: UITextContentType?

    func body(content: Content) -> some View {
        if let contentType {
            content.textContentType(contentType)
        } else {
            content
        }
    }
}

struct AppTextField: View {
    
    let title: String
    
    @Binding var text: String
    
    var keyboardType: UIKeyboardType = .default
    
    var textContentType: UITextContentType? = nil
    
    var submitLabel: SubmitLabel = .return
    
    var focus: FocusState<Bool>.Binding? = nil
    
    var onSubmit: (() -> Void)? = nil
    
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
                .modifier(FocusModifier(focus: focus))
                .modifier(TextContentTypeModifier(contentType: textContentType))
                .submitLabel(submitLabel)
                .onSubmit { onSubmit?() }
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