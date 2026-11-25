import SwiftUI

struct ProfileFormView: View {
    @Bindable var viewModel: ProfileViewModel

    @State private var step: ProfileStep = .about

    private enum ProfileStep: Int, CaseIterable {
        case about
        case goal
        case plan

        var title: String {
            switch self {
            case .about: "About you"
            case .goal: "Your direction"
            case .plan: "Your plan"
            }
        }

        var subtitle: String {
            switch self {
            case .about: "A few details help us calculate a useful starting point."
            case .goal: "Choose what you want your weight to do."
            case .plan: "Set a pace that feels realistic for you."
            }
        }
    }

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                progressHeader

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 28) {
                        Text(step.title)
                            .font(.system(.largeTitle, design: .rounded).weight(.bold))
                            .foregroundStyle(AppColors.textPrimary)

                        Text(step.subtitle)
                            .font(.body)
                            .foregroundStyle(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        stepContent

                        if case .error(let error) = viewModel.state,
                           viewModel.fieldErrors.isEmpty {
                            ErrorView(error: error, onRetry: nil)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 28)
                    .padding(.bottom, 24)
                }

                actionBar
            }
        }
        .tint(AppColors.accent)
        .onAppear { viewModel.trackScreen("profile_personalization") }
        .onChange(of: viewModel.weight) { _, _ in viewModel.clearFieldError("weight") }
        .onChange(of: viewModel.height) { _, _ in viewModel.clearFieldError("height") }
        .onChange(of: viewModel.age) { _, _ in viewModel.clearFieldError("age") }
        .onChange(of: viewModel.gender) { _, _ in viewModel.clearFieldError("gender") }
        .onChange(of: viewModel.goal) { _, _ in viewModel.clearFieldError("goal") }
        .onChange(of: viewModel.activityLevel) { _, _ in viewModel.clearFieldError("activityLevel") }
        .onChange(of: viewModel.targetWeight) { _, _ in viewModel.clearFieldError("targetWeightKg") }
        .onChange(of: viewModel.maintainWeightMin) { _, _ in viewModel.clearFieldError("targetWeightMinKg") }
        .onChange(of: viewModel.maintainWeightMax) { _, _ in viewModel.clearFieldError("targetWeightMaxKg") }
        .onChange(of: viewModel.weeklyRateKg) { _, _ in viewModel.clearFieldError("weeklyRateKg") }
        .onChange(of: viewModel.targetDate) { _, _ in viewModel.clearFieldError("targetDate") }
    }

    private var progressHeader: some View {
        VStack(spacing: 14) {
            HStack {
                Text("STEP \(step.rawValue + 1) OF \(ProfileStep.allCases.count)")
                    .font(.caption.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(AppColors.textSecondary)

                Spacer()

                Text("NutriFlow")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColors.textSecondary)
            }

            HStack(spacing: 6) {
                ForEach(ProfileStep.allCases, id: \.rawValue) { item in
                    Capsule()
                        .fill(item.rawValue <= step.rawValue ? AppColors.accent : AppColors.border)
                        .frame(height: 6)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .about:
            aboutContent
        case .goal:
            goalContent
        case .plan:
            planContent
        }
    }

    private var aboutContent: some View {
        VStack(spacing: 20) {
            ProfileInput(
                title: "Current weight",
                placeholder: "0",
                unit: UnitConversion.bodyWeightUnitLabel(preferred: viewModel.preferredUnits),
                text: $viewModel.weight,
                error: viewModel.fieldErrors["weight"],
                keyboard: .decimalPad
            )

            ProfileInput(
                title: "Height",
                placeholder: "0",
                unit: UnitConversion.heightUnitLabel(preferred: viewModel.preferredUnits),
                text: $viewModel.height,
                error: viewModel.fieldErrors["height"],
                keyboard: .decimalPad
            )

            ProfileInput(
                title: "Age",
                placeholder: "0",
                unit: "years",
                text: $viewModel.age,
                error: viewModel.fieldErrors["age"],
                keyboard: .numberPad
            )

            SelectionSection(title: "Gender", error: viewModel.fieldErrors["gender"]) {
                ForEach(Gender.allCases, id: \.self) { gender in
                    ChoiceChip(
                        title: gender.displayName,
                        isSelected: viewModel.gender == gender
                    ) {
                        viewModel.gender = gender
                    }
                }
            }

            SelectionSection(title: "Activity level", error: viewModel.fieldErrors["activityLevel"]) {
                ForEach(ActivityLevel.allCases, id: \.self) { level in
                    ChoiceChip(
                        title: level.displayName,
                        isSelected: viewModel.activityLevel == level
                    ) {
                        viewModel.activityLevel = level
                    }
                }
            }
        }
    }

    private var goalContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Goal.allCases, id: \.self) { goal in
                GoalChoice(
                    goal: goal,
                    isSelected: viewModel.goal == goal
                ) {
                    viewModel.goal = goal
                }
            }

            if let error = viewModel.fieldErrors["goal"] {
                ErrorMessageView(text: error)
            }
        }
    }

    @ViewBuilder
    private var planContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            switch viewModel.goal {
            case .lose, .gain:
                ProfileInput(
                    title: "Target weight",
                    placeholder: "0",
                    unit: UnitConversion.bodyWeightUnitLabel(preferred: viewModel.preferredUnits),
                    text: $viewModel.targetWeight,
                    error: viewModel.fieldErrors["targetWeightKg"],
                    keyboard: .decimalPad
                )

                rateSection

                ProfileInput(
                    title: "Target date",
                    placeholder: "YYYY-MM-DD",
                    unit: "optional",
                    text: $viewModel.targetDate,
                    error: viewModel.fieldErrors["targetDate"],
                    keyboard: .numbersAndPunctuation
                )

                planHint("You can leave the date empty and adjust the plan later.")

            case .maintain:
                Text("Comfort range")
                    .font(.headline)
                    .foregroundStyle(AppColors.textPrimary)

                HStack(alignment: .top, spacing: 12) {
                    ProfileInput(
                        title: "From",
                        placeholder: "0",
                        unit: UnitConversion.bodyWeightUnitLabel(preferred: viewModel.preferredUnits),
                        text: $viewModel.maintainWeightMin,
                        error: viewModel.fieldErrors["targetWeightMinKg"],
                        keyboard: .decimalPad
                    )
                    ProfileInput(
                        title: "To",
                        placeholder: "0",
                        unit: UnitConversion.bodyWeightUnitLabel(preferred: viewModel.preferredUnits),
                        text: $viewModel.maintainWeightMax,
                        error: viewModel.fieldErrors["targetWeightMaxKg"],
                        keyboard: .decimalPad
                    )
                }

                planHint("Choose a range where you feel comfortable. Both values are required together.")

            case nil:
                ContentUnavailableView(
                    "Choose a direction first",
                    systemImage: "arrow.left.circle",
                    description: Text("Go back and choose lose, maintain, or gain.")
                )
            }
        }
    }

    private var rateSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Weekly pace")
                .font(.headline)
                .foregroundStyle(AppColors.textPrimary)

            HStack(spacing: 10) {
                ForEach(["0.25", "0.5", "0.75"], id: \.self) { rate in
                    ChoiceChip(
                        title: "\(rate) kg",
                        isSelected: viewModel.weeklyRateKg == rate
                    ) {
                        viewModel.weeklyRateKg = rate
                    }
                }
            }

            ProfileInput(
                title: "Custom pace",
                placeholder: "0.5",
                unit: "kg / week",
                text: $viewModel.weeklyRateKg,
                error: viewModel.fieldErrors["weeklyRateKg"],
                keyboard: .decimalPad
            )
        }
    }

    private func planHint(_ text: String) -> some View {
        Label(text, systemImage: "info.circle.fill")
            .font(.subheadline)
            .foregroundStyle(AppColors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.surfaceSecondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var actionBar: some View {
        VStack(spacing: 12) {
            if step != .about {
                Button("Back") {
                    step = ProfileStep(rawValue: step.rawValue - 1) ?? .about
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColors.textSecondary)
            }

            Button(action: advance) {
                HStack(spacing: 10) {
                    if viewModel.state.isSaving {
                        ProgressView()
                            .tint(AppColors.accentOnPrimary)
                    }
                    Text(step == .plan ? "Create my plan" : "Continue")
                    Image(systemName: step == .plan ? "checkmark" : "arrow.right")
                }
                .font(.headline)
                .foregroundStyle(AppColors.accentOnPrimary)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 56)
                .background(AppColors.accent, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(viewModel.state.isSaving)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(AppColors.background)
    }

    private func advance() {
        guard step == .plan else {
            step = ProfileStep(rawValue: step.rawValue + 1) ?? .plan
            return
        }

        Task {
            let created = await viewModel.createProfile()
            guard !created else { return }
            moveToFirstInvalidStep()
        }
    }

    private func moveToFirstInvalidStep() {
        let errors = viewModel.fieldErrors
        if ["weight", "height", "age", "gender", "activityLevel"].contains(where: { errors[$0] != nil }) {
            step = .about
        } else if errors["goal"] != nil {
            step = .goal
        }
    }
}

private struct ProfileInput: View {
    let title: String
    let placeholder: String
    let unit: String
    @Binding var text: String
    let error: String?
    let keyboard: UIKeyboardType

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppColors.textPrimary)

            HStack(spacing: 10) {
                TextField(placeholder, text: $text)
                    .keyboardType(keyboard)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)

                Text(unit)
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 56)
            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(error == nil ? AppColors.border : AppColors.error, lineWidth: 1)
            }

            if let error {
                ErrorMessageView(text: error)
            }
        }
    }
}

private struct SelectionSection<Content: View>: View {
    let title: String
    let error: String?
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppColors.textPrimary)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10, content: content)
                VStack(alignment: .leading, spacing: 10, content: content)
            }

            if let error {
                ErrorMessageView(text: error)
            }
        }
    }
}

private struct ChoiceChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? AppColors.accentOnPrimary : AppColors.textPrimary)
                .padding(.horizontal, 16)
                .frame(minHeight: 44)
                .background(isSelected ? AppColors.accent : AppColors.surfaceSecondary, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct GoalChoice: View {
    let goal: Goal
    let isSelected: Bool
    let action: () -> Void

    private var detail: String {
        switch goal {
        case .lose: "Set a lower target weight and a sustainable pace."
        case .maintain: "Stay within a weight range that feels right."
        case .gain: "Set a higher target weight and build gradually."
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? AppColors.accent : AppColors.textSecondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.displayName)
                        .font(.headline)
                        .foregroundStyle(AppColors.textPrimary)
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isSelected ? AppColors.accent.opacity(0.12) : AppColors.surface,
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(isSelected ? AppColors.accent : AppColors.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview("Profile personalization") {
    let container = AppDependencyContainer()
    let coordinator = AppCoordinator(container: container)
    let viewModel = ProfileViewModel(
        coordinator: coordinator,
        authService: MockAuthService(),
        profileService: MockProfileService(),
        userService: MockUserService()
    )

    ProfileFormView(viewModel: viewModel)
}
