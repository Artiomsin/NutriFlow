import SwiftUI

struct DayDetailSheet: View {
    let dateStr: String
    let food: [FoodEntry]
    let water: [WaterEntry]
    let goals: UserGoals?
    let state: DayDetailState
    let activity: ActivityDayPoint?
    let workouts: [HealthKitWorkout]
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
            if let goals { goalSection(goals) }
            if let activity { activitySection(activity, goals: goals) }
            workoutSection
            foodSection
            waterSection
        }
    }

    private func errorView(_ error: Error) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(AppColors.error)
            Text("Couldn't load day details")
                .font(.headline)
                .foregroundColor(AppColors.textPrimary)
            Text(error.localizedDescription)
                .font(.footnote)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
    }

    private var formattedHeaderDate: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        guard let d = fmt.date(from: dateStr) else { return dateStr }
        let out = DateFormatter()
        out.dateFormat = "d MMM yyyy"
        return out.string(from: d)
    }

    private var header: some View {
        let totals = foodTotals
        let totalWater = water.reduce(0) { $0 + $1.amountMl }
        return HStack(spacing: 24) {
            DetailStatCard(icon: "flame.fill", color: .orange, value: "\(UnitConversion.formatEnergyValue(kcal: totals.cal, preferred: prefsStore.preferredUnits))", unit: UnitConversion.formatEnergyUnit(preferred: prefsStore.preferredUnits))
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
                GoalBar(title: "Calories", current: String(UnitConversion.formatEnergyValue(kcal: foodTotals.cal, preferred: prefsStore.preferredUnits)), goal: String(UnitConversion.formatEnergyValue(kcal: goals.dailyCaloriesGoal ?? 0, preferred: prefsStore.preferredUnits)), unit: UnitConversion.formatEnergyUnit(preferred: prefsStore.preferredUnits), color: .orange, icon: "flame.fill")
                GoalBar(title: "Protein", current: UnitConversion.formatMacro(grams: foodTotals.protein, preferred: prefsStore.preferredUnits), goal: UnitConversion.formatMacro(grams: goals.dailyProteinGoal ?? 0, preferred: prefsStore.preferredUnits), unit: "", color: .indigo, icon: "bolt.fill")
                GoalBar(title: "Fat", current: UnitConversion.formatMacro(grams: foodTotals.fat, preferred: prefsStore.preferredUnits), goal: UnitConversion.formatMacro(grams: goals.dailyFatGoal ?? 0, preferred: prefsStore.preferredUnits), unit: "", color: .green, icon: "drop.degreesign.fill")
                GoalBar(title: "Carbs", current: UnitConversion.formatMacro(grams: foodTotals.carbs, preferred: prefsStore.preferredUnits), goal: UnitConversion.formatMacro(grams: goals.dailyCarbsGoal ?? 0, preferred: prefsStore.preferredUnits), unit: "", color: .purple, icon: "leaf.arrow.circlepath")
                GoalBar(title: "Water", current: UnitConversion.formatAmount(grams: water.reduce(0) { $0 + $1.amountMl }, unit: "ml", preferred: prefsStore.preferredUnits), goal: UnitConversion.formatAmount(grams: goals.dailyWaterGoal ?? 0, unit: "ml", preferred: prefsStore.preferredUnits), unit: "", color: .cyan, icon: "drop.fill")
            }
        }
        .padding()
        .background(AppColors.surface)
        .cornerRadius(AppRadius.medium)
    }

    private func activitySection(_ activity: ActivityDayPoint, goals: UserGoals?) -> some View {
        let stepsGoal = goals?.dailyStepsGoal ?? 0
        let activeGoal = goals?.dailyActiveCaloriesGoal ?? 0
        return VStack(alignment: .leading, spacing: 16) {
            sectionLabel("Daily Activity", icon: "figure.walk")

            VStack(spacing: 14) {
                GoalBar(
                    title: "Steps",
                    current: "\(activity.steps)",
                    goal: "\(stepsGoal)",
                    unit: "",
                    color: .blue,
                    icon: "figure.walk"
                )
                GoalBar(
                    title: "Active kcal",
                    current: "\(activity.activeCalories)",
                    goal: "\(activeGoal)",
                    unit: "",
                    color: .pink,
                    icon: "flame.fill"
                )
            }
        }
        .padding()
        .background(AppColors.surface)
        .cornerRadius(AppRadius.medium)
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
        .background(AppColors.surface)
        .cornerRadius(AppRadius.medium)
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
        .background(AppColors.surface)
        .cornerRadius(AppRadius.medium)
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
        .background(AppColors.surface)
        .cornerRadius(AppRadius.medium)
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

    private var foodTotals: (cal: Int, protein: Int, fat: Int, carbs: Int) {
        food.reduce((0, 0, 0, 0)) { acc, entry in
            (acc.0 + entry.calories, acc.1 + (entry.protein ?? 0), acc.2 + (entry.fat ?? 0), acc.3 + (entry.carbs ?? 0))
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
        .background(AppColors.surface)
        .cornerRadius(AppRadius.small)
    }
}

struct GoalBar: View {
    let title: String
    let current: String
    let goal: String
    let unit: String
    let color: Color
    let icon: String

    private var rawCurrent: Double {
        Double(current.split(separator: " ").first ?? "") ?? 0
    }

    private var rawGoal: Double {
        Double(goal.split(separator: " ").first ?? "") ?? 0
    }

    private var pct: Double {
        guard rawGoal > 0 else { return 0 }
        return min(rawCurrent / rawGoal, 1.0)
    }

    private var pctText: String {
        let p = Int(pct * 100)
        return "\(p)%"
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
                Text("\(current)/\(goal) \(unit)")
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
                Text(pctText)
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

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.body.weight(.medium))
                    .foregroundColor(AppColors.textPrimary)
                Text(formatTime(entry.createdAt))
                    .font(.caption)
                    .foregroundColor(AppColors.textTertiary )
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(UnitConversion.formatEnergyValue(kcal: entry.calories, preferred: prefsStore.preferredUnits))")
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

            Text(formatTime(entry.createdAt))
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
    return Calendar.current.date(from: comps) ?? Date()
}

func formatTime(_ iso: String) -> String {
    let fmt = ISO8601DateFormatter()
    fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let d = fmt.date(from: iso) {
        let tf = DateFormatter()
        tf.dateFormat = "HH:mm"
        return tf.string(from: d)
    }
    fmt.formatOptions = [.withInternetDateTime]
    if let d = fmt.date(from: iso) {
        let tf = DateFormatter()
        tf.dateFormat = "HH:mm"
        return tf.string(from: d)
    }
    return String(iso.suffix(8).prefix(5))
}

#Preview("Day Detail") {
    DayDetailSheet(
        dateStr: "2026-09-09",
        food: [
            FoodEntry(id: "1", userId: "1", name: "Oatmeal", calories: 320, protein: 12, fat: 6, carbs: 56, foodId: nil, grams: nil, unit: "g", categoryName: nil, imageUrl: nil, createdAt: "2026-09-09T08:00:00Z", updatedAt: nil),
            FoodEntry(id: "2", userId: "1", name: "Chicken Breast", calories: 450, protein: 40, fat: 10, carbs: 0, foodId: nil, grams: nil, unit: "g", categoryName: nil, imageUrl: nil, createdAt: "2026-09-09T13:00:00Z", updatedAt: nil),
        ],
        water: [
            WaterEntry(id: "1", userId: "1", amountMl: 500, createdAt: "2026-09-09T10:00:00Z", updatedAt: nil),
            WaterEntry(id: "2", userId: "1", amountMl: 300, createdAt: "2026-09-09T15:00:00Z", updatedAt: nil),
        ],
        goals: UserGoals(id: "1", userId: "1", dailyCaloriesGoal: 2200, dailyProteinGoal: 150, dailyFatGoal: 65, dailyCarbsGoal: 250, dailyWaterGoal: 3000, dailyStepsGoal: 5000, dailyActiveCaloriesGoal: 450, weeklyWorkoutsGoal: 33, weeklyWorkoutMinutesGoal: 44, nightlySleepMinMinutes: 456, nightlySleepMaxMinutes: 600,  source: "auto", createdAt: nil, updatedAt: nil),
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
