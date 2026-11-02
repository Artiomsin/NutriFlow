import SwiftUI

struct EditProfileView: View {

    @Bindable var viewModel: ProfileViewModel

    @Environment(\.dismiss) private var dismiss

    private enum Field: Hashable {
        case email
        case firstName
        case lastName
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

            AppColors.background
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
                        errorMessage: viewModel.fieldErrors["email"],
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
                        errorMessage: viewModel.fieldErrors["firstName"],
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
                        errorMessage: viewModel.fieldErrors["lastName"],
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
                        errorMessage: viewModel.fieldErrors["height"],
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
                        errorMessage: viewModel.fieldErrors["age"],
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
                            .foregroundColor(AppColors.textTertiary )

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
                                    viewModel.clearFieldError("gender")
                                }
                            }
                        }

                        if let genderError = viewModel.fieldErrors["gender"] {
                            Text(genderError)
                                .font(.caption)
                                .foregroundColor(AppColors.error)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    if let saveError = viewModel.saveError,
                       viewModel.fieldErrors.isEmpty {
                        ErrorView(
                            error: saveError,
                            onRetry: { Task { await viewModel.saveAll() } }
                        )
                    }

                    PrimaryButton(title: "Save") {

                        dismissKeyboard()

                        Task {
                            await viewModel.saveAll()
                            if viewModel.saveError == nil,
                               viewModel.fieldErrors.isEmpty {
                                dismiss()
                            }
                        }
                    }
                    .disabled(viewModel.state.isSaving)
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
        .onChange(of: viewModel.email) { _, _ in
            viewModel.clearFieldError("email")
        }
        .onChange(of: viewModel.firstName) { _, _ in
            viewModel.clearFieldError("firstName")
        }
        .onChange(of: viewModel.lastName) { _, _ in
            viewModel.clearFieldError("lastName")
        }
        .onChange(of: viewModel.height) { _, _ in
            viewModel.clearFieldError("height")
        }
        .onChange(of: viewModel.age) { _, _ in
            viewModel.clearFieldError("age")
        }
        .onAppear { viewModel.trackScreen("edit_profile") }
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
   // .preferredColorScheme(.dark)
}
