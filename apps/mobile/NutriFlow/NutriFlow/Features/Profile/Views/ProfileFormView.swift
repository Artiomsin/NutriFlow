import SwiftUI

struct ProfileFormView: View {
    @Bindable var viewModel: ProfileViewModel
    @FocusState private var weightFocused: Bool
    @FocusState private var heightFocused: Bool
    @FocusState private var ageFocused: Bool
    
    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            
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
                            focus: $weightFocused
                        )
                        
                        AppTextField(
                            title: "Height (\(UnitConversion.heightUnitLabel(preferred: viewModel.preferredUnits)))",
                            text: $viewModel.height,
                            keyboardType: .decimalPad,
                            focus: $heightFocused
                        )
                        
                        AppTextField(
                            title: "Age",
                            text: $viewModel.age,
                            keyboardType: .numberPad,
                            focus: $ageFocused
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
                                        viewModel.activityLevel = level
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, AppTheme.paddingHorizontal)
                    
                    if case .error(let error) = viewModel.state {
                        ErrorMessageView(text: error.localizedDescription)
                            .padding(.horizontal, AppTheme.paddingHorizontal)
                    }
                    
                    PrimaryButton(title: "Save") {
                        dismissKeyboard()
                        Task {
                            await viewModel.createProfile()
                        }
                    }
                    .padding(.horizontal, AppTheme.paddingHorizontal)
                    
                    if case .saving = viewModel.state {
                        ProgressView()
                            .tint(.white)
                    }
                    
                    Spacer()
                }
                .contentShape(Rectangle())
                .onTapGesture { dismissKeyboard() }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .tint(AppTheme.accent)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                if weightFocused || heightFocused || ageFocused {
                    Spacer()
                    Button("Done") { dismissKeyboard() }
                }
            }
        }
        .onAppear { AnalyticsManager.shared.track(.screenView(screen: "profile_form")) }
    }

    private func dismissKeyboard() {
        weightFocused = false
        heightFocused = false
        ageFocused = false
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
                .foregroundColor(isSelected ? AppTheme.primaryButtonText : AppTheme.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(isSelected ? AppTheme.accent : AppTheme.fieldBackground)
                .cornerRadius(AppTheme.chipCornerRadius)
        }
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
