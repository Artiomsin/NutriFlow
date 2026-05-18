import SwiftUI

struct EditProfileView: View {

    @ObservedObject var viewModel: ProfileViewModel
    @Environment(\.dismiss) private var dismiss
    var onDismiss: (() -> Void)?

    var body: some View {

        ZStack {

            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {

                HStack {

                    Button {
                        onDismiss?()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(AppTheme.textPrimary)
                            .font(.system(size: 18, weight: .semibold))
                    }

                    Spacer()

                    Text("Edit Profile")
                        .foregroundColor(AppTheme.textPrimary)
                        .font(.headline)

                    Spacer()

                    Spacer()
                        .frame(width: 24)
                }
                .padding()
                .background(AppTheme.headerBackground)

                ScrollView {

                    VStack(spacing: 20) {
                        AppTextField(title: "Email", text: $viewModel.email)
                        AppTextField(title: "First Name", text: $viewModel.firstName)
                        AppTextField(title: "Last Name", text: $viewModel.lastName)
                        AppTextField(title: "Weight", text: $viewModel.weight)
                        AppTextField(title: "Height", text: $viewModel.height)
                        AppTextField(title: "Age", text: $viewModel.age)
                        PrimaryButton(title: "Save") {

                            Task {
                                await viewModel.updateUser()
                                await viewModel.updateProfile()
                                onDismiss?()
                                dismiss()
                            }
                        }
                        .padding(.top, 10)
                    }
                    .padding(20)
                }
            }
        }
    }
}
