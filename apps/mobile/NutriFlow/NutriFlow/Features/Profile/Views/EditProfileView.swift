import SwiftUI

struct EditProfileView: View {

    @Bindable var viewModel: ProfileViewModel
    var onDismiss: (() -> Void)?

    var body: some View {

        ZStack {

            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {

                HStack {
                    Text("Edit Profile")
                        .font(.title2.bold())
                        .foregroundColor(AppTheme.textPrimary)

                    Spacer()

                    Button {
                        onDismiss?()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }

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
                            }
                        }
                        .padding(.top, 10)
                    }
                    .padding(20)
                }
            }
        }
        .onAppear { AnalyticsService.shared.track(.screenView(screen: "edit_profile")) }
    }
}