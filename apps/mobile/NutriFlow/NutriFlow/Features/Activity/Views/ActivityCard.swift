import SwiftUI


struct ActivityCard: View {
    
    @Bindable var vm: ActivityViewModel
    @State private var prefsStore = PreferencesStore.shared
    @Environment(\.colorScheme) private var colorScheme
    
    var stepGoal: Int?
    var activeCaloriesGoal: Int?
    
    var body: some View {
        let _ = print("[ActivityCard] rendering state")
        switch vm.state {
        case .idle:
            EmptyView()
        case .needsAccess:
            accessPrompt
        case .denied:
            deniedPrompt
        case .loading:
            HStack {
                ProgressView().tint(AppColors.accent)
                Text("Loading activity...")
                    .foregroundColor(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(AppColors.surface)
            .cornerRadius(AppRadius.medium)
        case .loaded(let activity):
            activityContent(activity)
        case .error:
            loadingPlaceholder("Couldn't load activity")
        }
    }
    
    private var accessPrompt: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.walk")
                .font(AppTypography.displayNumber)
                .foregroundColor(AppColors.accent)
            Text("Track your activity")
                .font(.headline)
                .foregroundColor(AppColors.textPrimary)
            Text("Connect Apple Health to see your steps and calories burned.")
                .font(.footnote)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
            Button {
                Task { await vm.connectTapped() }
            } label: {
                    Text("Connect Health")
                        .font(.headline)
                        .foregroundColor(AppColors.accentOnPrimary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppColors.accent)
                    .cornerRadius(AppRadius.medium)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(AppColors.surface)
        .cornerRadius(AppRadius.medium)
    }
    
    private var deniedPrompt: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart.slash")
                .font(AppTypography.displayNumber)
                .foregroundColor(AppColors.textSecondary)
            Text("Health access is off")
                .font(.headline)
                .foregroundColor(AppColors.textPrimary)
            Text("Enable it in Settings to see your activity.")
                .font(.footnote)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
            Button {
                vm.openSettings()
            } label: {
                Text("Open Settings")
                    .font(.headline)
                    .foregroundColor(AppColors.accent)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppColors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.medium)
                            .stroke(AppColors.accent, lineWidth: 1.5)
                    )
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(AppColors.surface)
        .cornerRadius(AppRadius.medium)
    }
    
    private func activityContent(_ activity: DailyActivity) -> some View {
        VStack(spacing: 14){
            HStack(spacing: 16) {
                ActivityMetric(icon: "figure.walk", value: "\(activity.steps)", unit: "steps")
                ActivityMetric(
                    icon: "flame.fill",
                    value: "\(UnitConversion.formatEnergyValue(kcal: activity.activeCalories, preferred: prefsStore.preferredUnits))",
                    unit: UnitConversion.formatEnergyUnit(preferred: prefsStore.preferredUnits)
                )
                ActivityMetric(
                    icon: "location.fill",
                    value: String(format: "%.1f", activity.distanceMeters / 1000),
                    unit: "km"
                )
            }
            
            if let goal = stepGoal, goal > 0 {
                ActivityGoalRow(
                    icon: "figure.walk",
                    label: "Steps",
                    current: activity.steps,
                    goal: goal,
                    color: .green,
                    unit: "steps",
                    hasGlass: false

                    
                )
            }
            if let goal = activeCaloriesGoal, goal > 0 {
                ActivityGoalRow(
                    icon: "flame.fill",
                    label: "Active kcal",
                    current: activity.activeCalories,
                    goal: goal,
                    color: .orange,
                    unit: UnitConversion.formatEnergyUnit(preferred: prefsStore.preferredUnits),
                    hasGlass: false
                )
            }
            
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(AppColors.surface)
        .cornerRadius(AppRadius.medium)
        .shadow(
            color: colorScheme == .dark ? .black.opacity(0.45) : .black.opacity(0.06),
            radius: colorScheme == .dark ? 14 : 5,
            y: colorScheme == .dark ? 8 : 2
        )
    }
    
    private func loadingPlaceholder(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundColor(AppColors.textSecondary)
            .frame(maxWidth: .infinity)
            .padding()
            .background(AppColors.surface)
            .cornerRadius(AppRadius.medium)
    }
}

private struct ActivityMetric: View {
    let icon: String
    let value: String
    let unit: String
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(AppColors.accent)
            Text(value)
                .font(.headline)
                .foregroundColor(AppColors.textPrimary)
            Text(unit)
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}


#Preview("Loaded") {
    let vm = ActivityViewModel(healthKit: MockHealthKit())
    vm.state = .loaded(DailyActivity(date: "2026-09-04", steps: 8543, activeCalories: 412, basalCalories: 1500, distanceMeters: 5200))
    return ActivityCard(vm: vm, stepGoal: 3444, activeCaloriesGoal: 455)
        .padding()
        .background(AppColors.background)
        
}

#Preview("Needs Access") {
    let vm = ActivityViewModel(healthKit: MockHealthKit())
    vm.state = .needsAccess
    return ActivityCard(vm: vm)
        .padding()
        .background(AppColors.background)
        
}

#Preview("Denied") {
    let vm = ActivityViewModel(healthKit: MockHealthKit())
    vm.state = .denied
    return ActivityCard(vm: vm)
        .padding()
        .background(AppColors.background)
        
}
