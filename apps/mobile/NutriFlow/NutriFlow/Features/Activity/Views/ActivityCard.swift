import SwiftUI


struct ActivityCard: View {
    
    @Bindable var vm: ActivityViewModel
    @State private var prefsStore = PreferencesStore.shared
    
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
                ProgressView().tint(AppTheme.accent)
                Text("Loading activity...")
                    .foregroundColor(AppTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(AppTheme.cardBackground)
            .cornerRadius(AppTheme.cornerRadiusMedium)
        case .loaded(let activity):
            activityContent(activity)
        case .error:
            loadingPlaceholder("Couldn't load activity")
        }
    }
    
    private var accessPrompt: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.walk")
                .font(Font.largeNumber)
                .foregroundColor(AppTheme.accent)
            Text("Track your activity")
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)
            Text("Connect Apple Health to see your steps and calories burned.")
                .font(.footnote)
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
            Button {
                Task { await vm.connectTapped() }
            } label: {
                Text("Connect Health")
                    .font(.headline)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppTheme.accent)
                    .cornerRadius(AppTheme.cornerRadiusMedium)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.cornerRadiusMedium)
    }
    
    private var deniedPrompt: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart.slash")
                .font(Font.largeNumber)
                .foregroundColor(AppTheme.textSecondary)
            Text("Health access is off")
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)
            Text("Enable it in Settings to see your activity.")
                .font(.footnote)
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
            Button {
                vm.openSettings()
            } label: {
                Text("Open Settings")
                    .font(.headline)
                    .foregroundColor(AppTheme.accent)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppTheme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                            .stroke(AppTheme.accent, lineWidth: 1.5)
                    )
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.cornerRadiusMedium)
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
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.cornerRadiusMedium)
    }
    
    private func loadingPlaceholder(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundColor(AppTheme.textSecondary)
            .frame(maxWidth: .infinity)
            .padding()
            .background(AppTheme.cardBackground)
            .cornerRadius(AppTheme.cornerRadiusMedium)
    }
}

private struct ActivityMetric: View {
    let icon: String
    let value: String
    let unit: String
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(AppTheme.accent)
            Text(value)
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)
            Text(unit)
                .font(.caption)
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}


#Preview("Loaded") {
    let vm = ActivityViewModel(healthKit: MockHealthKit())
    vm.state = .loaded(DailyActivity(date: "2026-09-04", steps: 8543, activeCalories: 412, basalCalories: 1500, distanceMeters: 5200))
    return ActivityCard(vm: vm, stepGoal: 3444, activeCaloriesGoal: 455)
        .padding()
        .background(AppTheme.background)
        .preferredColorScheme(.dark)
}

#Preview("Needs Access") {
    let vm = ActivityViewModel(healthKit: MockHealthKit())
    vm.state = .needsAccess
    return ActivityCard(vm: vm)
        .padding()
        .background(AppTheme.background)
        .preferredColorScheme(.dark)
}

#Preview("Denied") {
    let vm = ActivityViewModel(healthKit: MockHealthKit())
    vm.state = .denied
    return ActivityCard(vm: vm)
        .padding()
        .background(AppTheme.background)
        .preferredColorScheme(.dark)
}
