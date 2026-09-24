import SwiftUI
import UIKit

struct AppTextField<Field: Hashable>: View {

    let title: String

    @Binding var text: String

    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil
    var submitLabel: SubmitLabel = .return

    var focus: FocusState<Field?>.Binding
    var focusValue: Field

    var onSubmit: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {

            Text(title)
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
                .frame(height: 16, alignment: .leading)

            TextField("", text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(keyboardType)
                .textContentType(textContentType)
                .submitLabel(submitLabel)
                .focused(
                    focus,
                    equals: focusValue
                )
                .foregroundColor(AppColors.textPrimary)
                .padding(.horizontal, 16)
                .frame(height: 52)
                .background(fieldBackground)
                .onSubmit {
                    onSubmit?()
                }
        }
        .frame(maxWidth: .infinity)
    }

    private var fieldBackground: some View {
        RoundedRectangle(
            cornerRadius: AppRadius.medium
        )
        .fill(AppColors.surfaceSecondary)
        .overlay(
            RoundedRectangle(
                cornerRadius: AppRadius.medium
            )
            .stroke(
                AppColors.border,
                lineWidth: 1
            )
        )
    }
}
