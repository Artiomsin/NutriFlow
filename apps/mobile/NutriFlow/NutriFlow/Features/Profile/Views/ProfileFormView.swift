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
            AppTheme.background
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {

                    Text("Create Profile")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(AppTheme.textPrimary)
                        .padding(.top, AppTheme.headerPaddingTop)

                    Text("Tell us about yourself")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.textTertiary)

                    VStack(spacing: 16) {

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
                                focusedField = nil
                            }
                        )

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
                                        focusedField = nil
                                        viewModel.gender = gender
                                    }
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Goal")
                                .font(.subheadline)
                                .foregroundColor(AppTheme.textTertiary)

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
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Activity Level")
                                .font(.subheadline)
                                .foregroundColor(AppTheme.textTertiary)

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
                        }
                    }
                    .padding(.horizontal, AppTheme.paddingHorizontal)

                    if case .error(let error) = viewModel.state {
                        ErrorMessageView(
                            text: error.localizedDescription
                        )
                        .padding(.horizontal, AppTheme.paddingHorizontal)
                    }

                    PrimaryButton(title: "Save") {
                        focusedField = nil

                        Task {
                            await viewModel.createProfile()
                        }
                    }
                    .padding(.horizontal, AppTheme.paddingHorizontal)

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
        .tint(AppTheme.accent)
        .onTapGesture {
            focusedField = nil
        }
        .onAppear {
            AnalyticsManager.shared.track(
                .screenView(screen: "profile_form")
            )
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
                        ? AppTheme.primaryButtonText
                        : AppTheme.textPrimary
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    isSelected
                        ? AppTheme.accent
                        : AppTheme.fieldBackground
                )
                .cornerRadius(AppTheme.chipCornerRadius)
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
    .preferredColorScheme(.dark)
}
