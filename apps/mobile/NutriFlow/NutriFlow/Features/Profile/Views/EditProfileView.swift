import SwiftUI

struct EditProfileView: View {

    @Bindable var viewModel: ProfileViewModel

    @Environment(\.dismiss) private var dismiss

    private enum Field: Hashable {
        case email
        case firstName
        case lastName
        case weight
        case height
        case age
    }

    @FocusState private var focusedField: Field?

    private func nextField(_ field: Field) {
        Task { @MainActor in
            focusedField = field
        }
    }

    var body: some View {

        ZStack {

            AppTheme.background
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {

                VStack(spacing: 20) {

                    AppTextField(
                        title: "Email",
                        text: $viewModel.email,
                        keyboardType: .emailAddress,
                        textContentType: .emailAddress,
                        submitLabel: .return,
                        focus: $focusedField,
                        focusValue: .email,
                        onSubmit: {
                            nextField(.firstName)
                        }
                    )

                    AppTextField(
                        title: "First Name",
                        text: $viewModel.firstName,
                        textContentType: .givenName,
                        submitLabel: .return,
                        focus: $focusedField,
                        focusValue: .firstName,
                        onSubmit: {
                            nextField(.lastName)
                        }
                    )

                    AppTextField(
                        title: "Last Name",
                        text: $viewModel.lastName,
                        textContentType: .familyName,
                        submitLabel: .return,
                        focus: $focusedField,
                        focusValue: .lastName,
                        onSubmit: {
                            nextField(.weight)
                        }
                    )

                    AppTextField(
                        title: "Weight (\(UnitConversion.bodyWeightUnitLabel(preferred: viewModel.preferredUnits)))",
                        text: $viewModel.weight,
                        keyboardType: .decimalPad,
                        submitLabel: .return,
                        focus: $focusedField,
                        focusValue: .weight,
                        onSubmit: {
                            nextField(.height)
                        }
                    )

                    AppTextField(
                        title: "Height (\(UnitConversion.heightUnitLabel(preferred: viewModel.preferredUnits)))",
                        text: $viewModel.height,
                        keyboardType: .decimalPad,
                        submitLabel: .return,
                        focus: $focusedField,
                        focusValue: .height,
                        onSubmit: {
                            nextField(.age)
                        }
                    )

                    AppTextField(
                        title: "Age",
                        text: $viewModel.age,
                        keyboardType: .numberPad,
                        submitLabel: .return,
                        focus: $focusedField,
                        focusValue: .age,
                        onSubmit: {
                            dismissKeyboard()
                        }
                    )

                    VStack(
                        alignment: .leading,
                        spacing: 8
                    ) {

                        Text("Gender")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.textTertiary)

                        HStack(spacing: 12) {

                            ForEach(
                                Gender.allCases,
                                id: \.self
                            ) { gender in

                                SelectableChip(
                                    title: gender.displayName,
                                    isSelected: viewModel.gender == gender
                                ) {
                                    dismissKeyboard()
                                    viewModel.gender = gender
                                }
                            }
                        }
                    }

                    PrimaryButton(title: "Save") {

                        dismissKeyboard()

                        Task {
                            await viewModel.updateUser()
                            await viewModel.updateProfile()
                            dismiss()
                        }
                    }
                    .padding(.top, 10)
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .onTapGesture {
            dismissKeyboard()
        }
        .onAppear {
            AnalyticsManager.shared.track(
                .screenView(
                    screen: "edit_profile"
                )
            )
        }
    }

    private func dismissKeyboard() {
        focusedField = nil
    }
}

#Preview("Edit Profile") {

    let container = AppDependencyContainer()

    let coordinator = AppCoordinator(
        container: container
    )

    let viewModel = ProfileViewModel(
        coordinator: coordinator,
        authService: MockAuthService(),
        profileService: MockProfileService(),
        userService: MockUserService()
    )

    NavigationStack {

        EditProfileView(
            viewModel: viewModel
        )
        .task {
            await viewModel.loadData()
        }
    }
    .preferredColorScheme(.dark)
}
