import SwiftUI

struct AuthPasswordField<Field: Hashable>: View {

    @Binding var password: String

    var textContentType: UITextContentType? = .password
    var submitLabel: SubmitLabel = .return

    var focus: FocusState<Field?>.Binding
    var focusValue: Field

    var onSubmit: (() -> Void)? = nil

    @State private var isSecure = true

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Password")
                .font(.caption)
                .foregroundColor(AppTheme.textSecondary)
                .frame(height: 16, alignment: .leading)

            HStack(spacing: 8) {
                ZStack(alignment: .leading) {
                    SecureField("", text: $password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.default)
                        .textContentType(textContentType)
                        .foregroundColor(AppTheme.textPrimary)
                        .submitLabel(submitLabel)
                        .onSubmit { onSubmit?() }
                        .focusedIf(isSecure, focus, equals: focusValue)
                        .opacity(isSecure ? 1 : 0)
                        .allowsHitTesting(isSecure)

                    TextField("", text: $password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.default)
                        .textContentType(textContentType)
                        .foregroundColor(AppTheme.textPrimary)
                        .submitLabel(submitLabel)
                        .onSubmit { onSubmit?() }
                        .focusedIf(!isSecure, focus, equals: focusValue)
                        .opacity(isSecure ? 0 : 1)
                        .allowsHitTesting(!isSecure)
                }
                .frame(maxWidth: .infinity)

                Button {
                    isSecure.toggle()
                } label: {
                    Image(
                        systemName: isSecure
                            ? "eye.slash"
                            : "eye"
                    )
                    .foregroundColor(AppTheme.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .frame(height: 52)
            .background(fieldBackground)
        }
        .frame(maxWidth: .infinity)
    }

    private var fieldBackground: some View {
        RoundedRectangle(
            cornerRadius: AppTheme.cornerRadiusMedium
        )
        .fill(AppTheme.fieldBackground)
        .overlay(
            RoundedRectangle(
                cornerRadius: AppTheme.cornerRadiusMedium
            )
            .stroke(
                AppTheme.fieldBorder,
                lineWidth: 1
            )
        )
    }
}

private extension View {
    @ViewBuilder
    func focusedIf<F: Hashable>(
        _ active: Bool,
        _ focus: FocusState<F?>.Binding,
        equals value: F
    ) -> some View {
        if active {
            focused(focus, equals: value)
        } else {
            self
        }
    }
}