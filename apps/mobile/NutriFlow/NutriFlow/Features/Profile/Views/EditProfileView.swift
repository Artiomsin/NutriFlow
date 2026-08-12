import SwiftUI

struct EditProfileView: View {

    @Bindable var viewModel: ProfileViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var emailFocused: Bool
    @FocusState private var firstNameFocused: Bool
    @FocusState private var lastNameFocused: Bool
    @FocusState private var weightFocused: Bool
    @FocusState private var heightFocused: Bool
    @FocusState private var ageFocused: Bool

    var body: some View {

        ZStack {

            AppTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    AppTextField(title: "Email", text: $viewModel.email, focus: $emailFocused)
                    AppTextField(title: "First Name", text: $viewModel.firstName, focus: $firstNameFocused)
                    AppTextField(title: "Last Name", text: $viewModel.lastName, focus: $lastNameFocused)
                    AppTextField(title: "Weight (\(UnitConversion.bodyWeightUnitLabel(preferred: viewModel.preferredUnits)))", text: $viewModel.weight, keyboardType: .decimalPad, focus: $weightFocused)
                    AppTextField(title: "Height (\(UnitConversion.heightUnitLabel(preferred: viewModel.preferredUnits)))", text: $viewModel.height, keyboardType: .decimalPad, focus: $heightFocused)
                    AppTextField(title: "Age", text: $viewModel.age, keyboardType: .numberPad, focus: $ageFocused)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Gender")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.textTertiary)

                        HStack(spacing: 12) {
                            ForEach(Gender.allCases, id: \.self) { gender in
                                SelectableChip(
                                    title: gender.displayName,
                                    isSelected: viewModel.gender == gender
                                ) {
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
                .contentShape(Rectangle())
                .onTapGesture { dismissKeyboard() }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                if weightFocused || heightFocused || ageFocused {
                    Spacer()
                    Button("Done") { dismissKeyboard() }
                }
            }
        }
        .onAppear { AnalyticsManager.shared.track(.screenView(screen: "edit_profile")) }
    }

    private func dismissKeyboard() {
        emailFocused = false
        firstNameFocused = false
        lastNameFocused = false
        weightFocused = false
        heightFocused = false
        ageFocused = false
    }
}

#Preview("Edit Profile") {
    let container = AppDependencyContainer()
    let coordinator = AppCoordinator(container: container)
    let viewModel = ProfileViewModel(
        coordinator: coordinator,
        authService: MockAuthService(),
        profileService: MockProfileService(),
        userService: MockUserService()
    )
    NavigationStack {
        EditProfileView(viewModel: viewModel)
            .task { await viewModel.loadData() }
    }
    .preferredColorScheme(.dark)
}
