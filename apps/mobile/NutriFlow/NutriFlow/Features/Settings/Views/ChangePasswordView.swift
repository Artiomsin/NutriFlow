import SwiftUI
import UIKit

struct ChangePasswordView: View {

    @Bindable var viewModel: ChangePasswordViewModel

    @State private var step: ChangePasswordStep = .verifyCurrentPassword

    @FocusState private var focusedField: PasswordField?

    private enum ChangePasswordStep {
        case verifyCurrentPassword
        case setNewPassword
    }

    private enum PasswordField: Hashable {
        case current
        case new
        case confirm
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header

                VStack(spacing: 18) {
                    switch step {
                    case .verifyCurrentPassword:
                        currentPasswordField

                    case .setNewPassword:
                        newPasswordField
                        confirmPasswordField
                    }
                }

                if case .error(let error) = viewModel.state {
                    ErrorView(error: error)
                }

                if case .success = viewModel.state {
                    Text("Password successfully changed.")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.accent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                actionButton
            }
            .padding(20)
            .frame(maxWidth: 440)
            .frame(maxWidth: .infinity)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Change password")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(
                step == .verifyCurrentPassword
                    ? "Verify your password"
                    : "Create a new password"
            )
            .font(.title2.bold())
            .foregroundStyle(AppColors.textPrimary)

            Text(
                step == .verifyCurrentPassword
                    ? "Enter your current password to continue."
                    : "Enter your new password and confirm it."
            )
            .font(.subheadline)
            .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var currentPasswordField: some View {
        AuthPasswordField(
            password: $viewModel.currentPassword,
            title: "Current password",
            textContentType: .password,
            focus: $focusedField,
            focusValue: .current,
            errorMessage: viewModel.fieldErrors["currentPassword"]
        )
        .onChange(of: viewModel.currentPassword) { _, _ in
            viewModel.clearFieldError("currentPassword")
        }
    }

    private var newPasswordField: some View {
        AuthPasswordField(
            password: $viewModel.newPassword,
            title: "New password",
            textContentType: .newPassword,
            focus: $focusedField,
            focusValue: .new,
            errorMessage: viewModel.fieldErrors["newPassword"]
        )
        .onChange(of: viewModel.newPassword) { _, _ in
            viewModel.clearFieldError("newPassword")
        }
    }

    private var confirmPasswordField: some View {
        AuthPasswordField(
            password: $viewModel.confirmPassword,
            title: "Confirm new password",
            textContentType: .newPassword,
            focus: $focusedField,
            focusValue: .confirm,
            errorMessage: viewModel.fieldErrors["confirmPassword"]
        )
        .onChange(of: viewModel.confirmPassword) { _, _ in
            viewModel.clearFieldError("confirmPassword")
        }
    }

    private var actionButton: some View {
        Button {
            Task {
                switch step {
                case .verifyCurrentPassword:
                    guard !viewModel.currentPassword.isEmpty else {
                        viewModel.validateCurrentPassword()
                        return
                    }

                    step = .setNewPassword

                case .setNewPassword:
                    await viewModel.changePassword()
                }
            }
        } label: {
            HStack {
                Spacer()

                if viewModel.isLoading {
                    ProgressView()
                        .tint(AppColors.accentOnPrimary)
                } else {
                    Text(
                        step == .verifyCurrentPassword
                            ? "Continue"
                            : "Save Password"
                    )
                    .fontWeight(.semibold)
                    .foregroundStyle(AppColors.accentOnPrimary)
                }

                Spacer()
            }
            .padding(.vertical, 15)
            .background(AppColors.accent)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isLoading)
        .opacity(viewModel.isLoading ? 0.7 : 1)
    }
}
