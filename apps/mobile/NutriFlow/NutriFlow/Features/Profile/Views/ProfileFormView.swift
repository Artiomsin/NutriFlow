import SwiftUI

struct ProfileFormView: View {

    @Bindable var viewModel: ProfileViewModel

    private enum Field: Hashable {
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
            AppColors.background
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {

                    Text("Create Profile")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                        .padding(.top, AppSpacing.headerPaddingTop)

                    Text("Tell us about yourself")
                        .font(.subheadline)
                        .foregroundColor(AppColors.textTertiary )

                    VStack(spacing: 16) {

                        AppTextField(
                            title: "Weight (\(UnitConversion.bodyWeightUnitLabel(preferred: viewModel.preferredUnits)))",
                            text: $viewModel.weight,
                            keyboardType: .decimalPad,
                            submitLabel: .return,
                            focus: $focusedField,
                            focusValue: .weight,
                            errorMessage: viewModel.fieldErrors["weight"],
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
                                focusedField = nil
                            }
                        )

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Gender")
                                .font(.subheadline)
                                .foregroundColor(AppColors.textTertiary )

                            HStack(spacing: 12) {
                                ForEach(Gender.allCases, id: \.self) { gender in
                                    SelectableChip(
                                        title: gender.displayName,
                                        isSelected: viewModel.gender == gender
                                    ) {
                                        focusedField = nil
                                        viewModel.gender = gender
                                    }
                                }
                            }

                            if let message = viewModel.fieldErrors["gender"] {
                                ErrorMessageView(text: message)
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Goal")
                                .font(.subheadline)
                                .foregroundColor(AppColors.textTertiary )

                            HStack(spacing: 12) {
                                ForEach(Goal.allCases, id: \.self) { goal in
                                    SelectableChip(
                                        title: goal.displayName,
                                        isSelected: viewModel.goal == goal
                                    ) {
                                        focusedField = nil
                                        viewModel.goal = goal
                                    }
                                }
                            }

                            if let message = viewModel.fieldErrors["goal"] {
                                ErrorMessageView(text: message)
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Activity Level")
                                .font(.subheadline)
                                .foregroundColor(AppColors.textTertiary )

                            HStack(spacing: 12) {
                                ForEach(ActivityLevel.allCases, id: \.self) { level in
                                    SelectableChip(
                                        title: level.displayName,
                                        isSelected: viewModel.activityLevel == level
                                    ) {
                                        focusedField = nil
                                        viewModel.activityLevel = level
                                    }
                                }
                            }

                            if let message = viewModel.fieldErrors["activityLevel"] {
                                ErrorMessageView(text: message)
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.paddingHorizontal)

                    if case .error(let error) = viewModel.state,
                       viewModel.fieldErrors.isEmpty {
                        ErrorView(error: error, onRetry: nil)
                            .padding(.horizontal, AppSpacing.paddingHorizontal)
                    }

                    PrimaryButton(title: "Save") {
                        focusedField = nil

                        Task {
                            await viewModel.createProfile()
                        }
                    }
                    .disabled(viewModel.state.isSaving)
                    .padding(.horizontal, AppSpacing.paddingHorizontal)

                    if case .saving = viewModel.state {
                        ProgressView()
                            .tint(.white)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .tint(AppColors.accent)
        .onTapGesture {
            focusedField = nil
        }
        .onAppear { viewModel.trackScreen("profile_form") }
        .onChange(of: viewModel.weight) { _, _ in
            viewModel.clearFieldError("weight")
        }
        .onChange(of: viewModel.height) { _, _ in
            viewModel.clearFieldError("height")
        }
        .onChange(of: viewModel.age) { _, _ in
            viewModel.clearFieldError("age")
        }
        .onChange(of: viewModel.gender) { _, _ in
            viewModel.clearFieldError("gender")
        }
        .onChange(of: viewModel.goal) { _, _ in
            viewModel.clearFieldError("goal")
        }
        .onChange(of: viewModel.activityLevel) { _, _ in
            viewModel.clearFieldError("activityLevel")
        }
    }
}

struct SelectableChip: View {

    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(
                    isSelected
                        ? AppColors.accentOnPrimary
                        : AppColors.textPrimary
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    isSelected
                        ? AppColors.accent
                        : AppColors.surfaceSecondary
                )
                .cornerRadius(AppRadius.chip)
        }
        .buttonStyle(.plain)
    }
}

#Preview("Profile Form") {
    let container = AppDependencyContainer()
    let coordinator = AppCoordinator(container: container)

    let viewModel = ProfileViewModel(
        coordinator: coordinator,
        authService: MockAuthService(),
        profileService: MockProfileService(),
        userService: MockUserService()
    )

    NavigationStack {
        ProfileFormView(viewModel: viewModel)
    }
    
}
