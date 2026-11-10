import SwiftUI

struct DayDetailSheet: View {
    let dateStr: String
    let food: [FoodEntry]
    let water: [WaterEntry]
    let goals: UserGoals?
    let goalVersions: [GoalVersionEntry]
    let state: DayDetailState
    let activity: ActivityDayPoint?
    let workouts: [HealthKitWorkout]
    var warning: AppError? = nil
    var onRetry: (() -> Void)? = nil
    @State private var prefsStore = PreferencesStore.shared

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    header
                    switch state {
                    case .idle, .loading:
                        ProgressView()
                            .tint(AppColors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 60)
                    case .error(let error):
                        errorView(error)
                    case .loaded:
                        loadedContent
                    }
                }
                .padding(.horizontal, AppSpacing.paddingHorizontal)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(AppColors.background)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(formattedHeaderDate)
                        .font(.headline)
                        .foregroundColor(AppColors.textPrimary)
                }
            }
        }
       // .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var loadedContent: some View {
        VStack(spacing: 20) {
            if let warning, warning != .cancelled {
                ErrorView(error: warning, onRetry: onRetry)
            }
            if let goals { goalSection(goals) }
            if !goalVersions.isEmpty { goalChangesSection }
            activitySection(activity, goals: goals)
            workoutSection
            foodSection
            waterSection
        }
    }

    private func errorView(_ error: AppError) -> some View {
        ErrorView(error: error, onRetry: onRetry)
            .padding(.vertical, 40)
    }

    private var formattedHeaderDate: String {
        let fmt = AppDate.dateOnlyFormatter()
        guard let d = fmt.date(from: dateStr) else { return dateStr }
        return AppDate.displayFormatter("d MMM yyyy").string(from: d)
    }

    private var header: some View {
        let totals = foodTotals
        let totalWater = water.reduce(0) { $0 + $1.amountMl }
        return HStack(spacing: 24) {
            DetailStatCard(icon: "flame.fill", color: .orange, value: UnitConversion.formatEnergyValueText(kcal: totals.cal, preferred: prefsStore.preferredUnits), unit: UnitConversion.formatEnergyUnit(preferred: prefsStore.preferredUnits))
            DetailStatCard(icon: "drop.fill", color: .cyan, value: UnitConversion.formatAmount(grams: totalWater, unit: "ml", preferred: prefsStore.preferredUnits), unit: "")
            DetailStatCard(icon: "fork.knife", color: .green, value: "\(food.count)", unit: "meals")
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private func goalSection(_ goals: UserGoals) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionLabel("Daily Goals", icon: "target")

            VStack(spacing: 14) {
                GoalBar(title: "Calories", current: foodTotals.cal, goal: goals.dailyCaloriesGoal ?? 0, unit: UnitConversion.formatEnergyUnit(preferred: prefsStore.preferredUnits), color: .orange, icon: "flame.fill") { value in
                    UnitConversion.formatEnergyValueText(kcal: value, preferred: prefsStore.preferredUnits)
                }
                GoalBar(title: "Protein", current: foodTotals.protein, goal: goals.dailyProteinGoal ?? 0, unit: "", color: .indigo, icon: "bolt.fill") { value in
                    UnitConversion.formatMacro(grams: value, preferred: prefsStore.preferredUnits)
                }
                GoalBar(title: "Fat", current: foodTotals.fat, goal: goals.dailyFatGoal ?? 0, unit: "", color: .green, icon: "drop.degreesign.fill") { value in
                    UnitConversion.formatMacro(grams: value, preferred: prefsStore.preferredUnits)
                }
                GoalBar(title: "Carbs", current: foodTotals.carbs, goal: goals.dailyCarbsGoal ?? 0, unit: "", color: .purple, icon: "leaf.arrow.circlepath") { value in
                    UnitConversion.formatMacro(grams: value, preferred: prefsStore.preferredUnits)
                }
                GoalBar(title: "Water", current: Double(water.reduce(0) { $0 + $1.amountMl }), goal: Double(goals.dailyWaterGoal ?? 0), unit: "", color: .cyan, icon: "drop.fill") { value in
                    UnitConversion.formatAmount(grams: value, unit: "ml", preferred: prefsStore.preferredUnits)
                }
            }
        }
        .padding()
        .appGlassSurface()
    }

    private var goalChangesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Goal Changes", icon: "clock.arrow.circlepath")

            GoalHistoryTimeline(
                entries: goalVersions,
                dayStart: dayStart,
                chronological: true,
                showsDayHeaders: false
            )

            Text("Rings use the goal in effect at the end of the day.")
                .font(.caption2)
                .foregroundColor(AppColors.textTertiary)
        }
    }

    private var dayStart: Date? {
        AppDate.dateOnlyFormatter().date(from: dateStr)
    }

    private func activitySection(_ activity: ActivityDayPoint?, goals: UserGoals?) -> some View {
        let stepsGoal = goals?.dailyStepsGoal ?? 0
        let activeGoal = goals?.dailyActiveCaloriesGoal ?? 0
        return VStack(alignment: .leading, spacing: 16) {
            sectionLabel("Daily Activity", icon: "figure.walk")

            if let activity {
                VStack(spacing: 14) {
                    GoalBar(
                        title: "Steps",
                        current: Double(activity.steps),
                        goal: Double(stepsGoal),
                        unit: "",
                        color: .blue,
                        icon: "figure.walk"
                    ) { $0.formatted(.number) }
                    GoalBar(
                        title: "Active kcal",
                        current: Double(activity.activeCalories),
                        goal: Double(activeGoal),
                        unit: "",
                        color: .pink,
                        icon: "flame.fill"
                    ) { $0.formatted(.number) }
                }
            } else {
                emptyRow("No activity data synced")
            }
        }
        .padding()
        .appGlassSurface()
    }

    private var workoutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Workouts (\(workouts.count))", icon: "dumbbell.fill")

            if workouts.isEmpty {
                emptyRow("No workouts this day")
            } else {
                ForEach(workouts) { workout in
                    WorkoutDayRow(workout: workout)
                    if workout.id != workouts.last?.id {
                        Divider().background(AppColors.textTertiary .opacity(0.15))
                    }
                }
            }
        }
        .padding()
        .appGlassSurface()
    }

    private var foodSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Food", icon: "fork.knife")

            if food.isEmpty {
                emptyRow("No food entries")
            } else {
                ForEach(food) { entry in
                    FoodRow(entry: entry)
                    if entry.id != food.last?.id {
                        Divider().background(AppColors.textTertiary .opacity(0.15))
                    }
                }
            }
        }
        .padding()
        .appGlassSurface()
    }

    private var waterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Water", icon: "drop.fill")

            if water.isEmpty {
                emptyRow("No water entries")
            } else {
                ForEach(water) { entry in
                    WaterRow(entry: entry)
                    if entry.id != water.last?.id {
                        Divider().background(AppColors.textTertiary .opacity(0.15))
                    }
                }
            }
        }
        .padding()
        .appGlassSurface()
    }

    private func sectionLabel(_ text: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(AppColors.accent)
            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(AppColors.textPrimary)
        }
    }

    private func emptyRow(_ text: String) -> some View {
        HStack {
            Spacer()
            VStack(spacing: 6) {
                Image(systemName: "tray")
                    .font(.title3)
                    .foregroundColor(AppColors.textTertiary )
                Text(text)
                    .font(.subheadline)
                    .foregroundColor(AppColors.textTertiary )
            }
            .padding(.vertical, 20)
            Spacer()
        }
    }

    private var foodTotals: (cal: Double, protein: Double, fat: Double, carbs: Double) {
        food.reduce((cal: 0.0, protein: 0.0, fat: 0.0, carbs: 0.0)) { totals, entry in
            (
                cal: totals.cal + entry.calories,
                protein: totals.protein + (entry.protein ?? 0),
                fat: totals.fat + (entry.fat ?? 0),
                carbs: totals.carbs + (entry.carbs ?? 0)
            )
        }
    }
}

struct DetailStatCard: View {
    let icon: String
    let color: Color
    let value: String
    let unit: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundColor(AppColors.textPrimary)
            Text(unit)
                .font(.caption2)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .appGlassSurface(cornerRadius: AppRadius.small, level: .inset)
    }
}

struct GoalBar: View {
    let title: String
    let current: Double
    let goal: Double
    let unit: String
    let color: Color
    let icon: String
    let valueFormatter: (Double) -> String

    private var pct: Double {
        guard goal > 0 else { return 0 }
        return min(current / goal, 1.0)
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
                Text("\(valueFormatter(current))/\(valueFormatter(goal)) \(unit)")
                    .font(.caption.weight(.medium))
                    .foregroundColor(AppColors.textPrimary)
            }
            HStack(spacing: 8) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(AppColors.textTertiary .opacity(0.15)).frame(height: 10)
                        Capsule().fill(color).frame(width: geo.size.width * pct, height: 10)
                    }
                }
                .frame(height: 10)
                Text(pct, format: .percent.precision(.fractionLength(0)))
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(color)
                    .frame(width: 36, alignment: .trailing)
            }
        }
    }
}

struct FoodRow: View {
    let entry: FoodEntry
    @State private var prefsStore = PreferencesStore.shared

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.orange.opacity(0.15))
                .frame(width: 36, height: 36)
                .overlay(Image(systemName: "fork.knife").font(.caption2).foregroundColor(.orange))

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.name)
                    .font(.body.weight(.medium))
                    .foregroundColor(AppColors.textPrimary)

                if let categoryName = entry.categoryName, !categoryName.isEmpty {
                    Label {
                        Text(categoryName)
                    } icon: {
                        Image(systemName: entry.categoryIcon ?? "tag.fill")
                    }
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(1)
                }

                Text("Added \(formatTime(entry.createdAt))")
                    .font(.caption)
                    .foregroundColor(AppColors.textTertiary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(UnitConversion.formatEnergyValueText(kcal: entry.calories, preferred: prefsStore.preferredUnits))
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.orange)
                Text(UnitConversion.formatEnergyUnit(preferred: prefsStore.preferredUnits))
                    .font(.caption2)
                    .foregroundColor(AppColors.textTertiary )
            }
        }
        .padding(.vertical, 4)
    }
}

struct WaterRow: View {
    let entry: WaterEntry
    @State private var prefsStore = PreferencesStore.shared

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.cyan.opacity(0.15))
                .frame(width: 36, height: 36)
                .overlay(Image(systemName: "drop.fill").font(.caption2).foregroundColor(.cyan))

            Text("Added \(formatTime(entry.createdAt))")
                .font(.subheadline)
                .foregroundColor(AppColors.textPrimary)

            Spacer()

            Text(UnitConversion.formatAmount(grams: entry.amountMl, unit: "ml", preferred: prefsStore.preferredUnits))
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.cyan)
        }
        .padding(.vertical, 4)
    }
}

struct WorkoutDayRow: View {
    let workout: HealthKitWorkout

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.green.opacity(0.15))
                .frame(width: 36, height: 36)
                .overlay(Image(systemName: WorkoutFormatter.icon(for: workout.workoutType)).font(.caption2).foregroundColor(.green))

            VStack(alignment: .leading, spacing: 2) {
                Text(workout.workoutType)
                    .font(.body.weight(.medium))
                    .foregroundColor(AppColors.textPrimary)
                HStack(spacing: 6) {
                    Text(formatTime(WorkoutMapper.isoString(from: workout.startDate)))
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary )
                    Text("· \(WorkoutFormatter.formattedDuration(workout.durationSeconds))")
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary )
                }
            }

            Spacer()

            if let kcal = workout.caloriesBurned {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(UnitConversion.formatEnergyValue(kcal: Int(kcal), preferred: PreferencesStore.shared.preferredUnits))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.green)
                    Text(UnitConversion.formatEnergyUnit(preferred: PreferencesStore.shared.preferredUnits))
                        .font(.caption2)
                        .foregroundColor(AppColors.textTertiary )
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private func previewDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
    var comps = DateComponents()
    comps.year = year
    comps.month = month
    comps.day = day
    comps.hour = hour
    comps.minute = minute
    return AppDate.calendar.date(from: comps) ?? Date()
}

func formatTime(_ iso: String) -> String {
    let fmt = ISO8601DateFormatter()
    fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let d = fmt.date(from: iso) {
        return AppDate.displayFormatter("HH:mm").string(from: d)
    }
    fmt.formatOptions = [.withInternetDateTime]
    if let d = fmt.date(from: iso) {
        return AppDate.displayFormatter("HH:mm").string(from: d)
    }
    return String(iso.suffix(8).prefix(5))
}

#Preview("Day Detail") {
    DayDetailSheet(
        dateStr: "2026-09-09",
        food: [
            FoodEntry(id: "1", userId: "1", name: "Oatmeal", calories: 320, protein: 12, fat: 6, carbs: 56, foodId: nil, grams: nil, unit: "g", categoryName: "Breakfast",categoryIcon: "sunrise.fill", imageUrl: nil, createdAt: "2026-09-09T08:00:00Z", updatedAt: nil),
            FoodEntry(id: "2", userId: "1", name: "Chicken Breast", calories: 450, protein: 40, fat: 10, carbs: 0, foodId: nil, grams: nil, unit: "g", categoryName: nil,categoryIcon: nil, imageUrl: nil, createdAt: "2026-09-09T13:00:00Z", updatedAt: nil),
        ],
        water: [
            WaterEntry(id: "1", userId: "1", amountMl: 500, createdAt: "2026-09-09T10:00:00Z", updatedAt: nil),
            WaterEntry(id: "2", userId: "1", amountMl: 300, createdAt: "2026-09-09T15:00:00Z", updatedAt: nil),
        ],
        goals: UserGoals(id: "1", userId: "1", dailyCaloriesGoal: 2200, dailyProteinGoal: 150, dailyFatGoal: 65, dailyCarbsGoal: 250, dailyWaterGoal: 3000, dailyStepsGoal: 5000, dailyActiveCaloriesGoal: 450, weeklyWorkoutsGoal: 33, weeklyWorkoutMinutesGoal: 44, nightlySleepMinMinutes: 456, nightlySleepMaxMinutes: 600,  source: "auto", createdAt: nil, updatedAt: nil),
        goalVersions: [],
        state: .loaded,
        activity: ActivityDayPoint(date: "2026-09-09", steps: 8400, activeCalories: 380, basalCalories: 1700, distanceMeters: 6200, caloriesConsumed: 1950, netCalories: 1570),
        workouts: [
            HealthKitWorkout(
                id: UUID(),
                workoutType: "Running",
                startDate: previewDate(2026, 9, 9, 8, 30),
                endDate: previewDate(2026, 9, 9, 9, 15),
                durationSeconds: 2700,
                caloriesBurned: 340,
                distanceMeters: 5200
            ),
            HealthKitWorkout(
                id: UUID(),
                workoutType: "Strength Training",
                startDate: previewDate(2026, 9, 9, 18, 0),
                endDate: previewDate(2026, 9, 9, 18, 30),
                durationSeconds: 1800,
                caloriesBurned: 240,
                distanceMeters: nil
            )
        ]
    )
}
