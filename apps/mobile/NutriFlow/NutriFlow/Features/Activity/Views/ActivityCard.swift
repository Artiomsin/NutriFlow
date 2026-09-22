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
        case .unavailable:
            unavailablePrompt
        case .loading:
            HStack {
                ProgressView().tint(AppColors.accent)
                Text("Loading activity...")
                    .foregroundColor(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .appGlassSurface()
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
        .appGlassSurface()
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
                    .appGlassSurface(level: .inset)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.medium)
                            .stroke(AppColors.accent, lineWidth: 1.5)
                    )
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .appGlassSurface()
    }
    
    private var unavailablePrompt: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart.slash")
                .font(AppTypography.displayNumber)
                .foregroundColor(AppColors.textSecondary)
            Text("Health data unavailable")
                .font(.headline)
                .foregroundColor(AppColors.textPrimary)
            Text("Apple Health isn't available on this device, so activity can't be tracked.")
                .font(.footnote)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .appGlassSurface()
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
                    isEmbedded: true
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
                    isEmbedded: true
                )
            }
            
        }
        .padding()
        .frame(maxWidth: .infinity)
        .appGlassSurface()
    }
    
    private func loadingPlaceholder(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundColor(AppColors.textSecondary)
            .frame(maxWidth: .infinity)
            .padding()
            .appGlassSurface()
    }
}

private struct ActivityCardSurface: ViewModifier {
    let glassEffectsMode: GlassEffectsMode

    @Environment(\.colorScheme) private var colorScheme

    @ViewBuilder
    func body(content: Content) -> some View {
        if glassEffectsMode == .subtle {
            content
                .background {
                    ZStack {
                        RoundedRectangle(
                            cornerRadius: AppRadius.medium,
                            style: .continuous
                        )
                        .fill(
                            ActivityGlassPalette.cardBase(for: colorScheme)
                                .opacity(colorScheme == .light ? 0.66 : 0.72)
                        )

                        LinearGradient(
                            colors: [
                                Color.black
                                    .opacity(colorScheme == .light ? 0.025 : 0.18),
                                Color(
                                    red: 0.20,
                                    green: 0.08,
                                    blue: 0.34
                                )
                                .opacity(colorScheme == .light ? 0.03 : 0.16),
                                Color(
                                    red: 0.07,
                                    green: 0.11,
                                    blue: 0.30
                                )
                                .opacity(colorScheme == .light ? 0.02 : 0.12),
                                Color.black
                                    .opacity(colorScheme == .light ? 0.06 : 0.30)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )

                        RadialGradient(
                            colors: [
                                Color.black
                                    .opacity(colorScheme == .light ? 0.04 : 0.24),
                                .clear
                            ],
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: 240
                        )

                        RadialGradient(
                            colors: [
                                Color.black
                                    .opacity(colorScheme == .light ? 0.07 : 0.34),
                                .clear
                            ],
                            center: .bottomTrailing,
                            startRadius: 0,
                            endRadius: 260
                        )

                        RadialGradient(
                            colors: [
                                Color(
                                    red: 0.43,
                                    green: 0.16,
                                    blue: 0.68
                                )
                                .opacity(colorScheme == .light ? 0.025 : 0.16),
                                .clear
                            ],
                            center: .bottomLeading,
                            startRadius: 0,
                            endRadius: 180
                        )

                        RadialGradient(
                            colors: [
                                Color(
                                    red: 0.14,
                                    green: 0.18,
                                    blue: 0.48
                                )
                                .opacity(colorScheme == .light ? 0.02 : 0.12),
                                .clear
                            ],
                            center: .topTrailing,
                            startRadius: 0,
                            endRadius: 170
                        )
                    }
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: AppRadius.medium,
                            style: .continuous
                        )
                    )
                }
                .glassEffect(
                    .regular,
                    in: .rect(cornerRadius: AppRadius.medium)
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius: AppRadius.medium,
                        style: .continuous
                    )
                    .stroke(
                        ActivityGlassPalette.border(
                            for: colorScheme,
                            isInset: false
                        ),
                        lineWidth: 0.8
                    )
                }
                .shadow(
                    color: .black.opacity(colorScheme == .light ? 0.10 : 0.20),
                    radius: colorScheme == .light ? 12 : 14,
                    y: colorScheme == .light ? 5 : 7
                )
        } else {
            content
                .background(
                    AppColors.surface,
                    in: RoundedRectangle(
                        cornerRadius: AppRadius.medium,
                        style: .continuous
                    )
                )
        }
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
        .environment(\.glassEffectsMode, .subtle)
        
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
