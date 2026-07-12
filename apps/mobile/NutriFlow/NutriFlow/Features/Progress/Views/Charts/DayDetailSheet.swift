import SwiftUI

struct DayDetailSheet: View {
    let dateStr: String
    let food: [FoodEntry]
    let water: [WaterEntry]
    let goals: UserGoals?
    @State private var prefsStore = PreferencesStore.shared

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    header
                    if let goals { goalSection(goals) }
                    foodSection
                    waterSection
                }
                .padding(.horizontal, AppTheme.paddingHorizontal)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(AppTheme.background)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(formattedHeaderDate)
                        .font(.headline)
                        .foregroundColor(AppTheme.textPrimary)
                }
            }
        }
        .preferredColorScheme(.dark)
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
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.cornerRadiusMedium)
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
                        Divider().background(AppTheme.textTertiary.opacity(0.15))
                    }
                }
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.cornerRadiusMedium)
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
                        Divider().background(AppTheme.textTertiary.opacity(0.15))
                    }
                }
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.cornerRadiusMedium)
    }

    private func sectionLabel(_ text: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(AppTheme.accent)
            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(AppTheme.textPrimary)
        }
    }

    private func emptyRow(_ text: String) -> some View {
        HStack {
            Spacer()
            VStack(spacing: 6) {
                Image(systemName: "tray")
                    .font(.title3)
                    .foregroundColor(AppTheme.textTertiary)
                Text(text)
                    .font(.subheadline)
                    .foregroundColor(AppTheme.textTertiary)
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
                .foregroundColor(AppTheme.textPrimary)
            Text(unit)
                .font(.caption2)
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.cornerRadiusSmall)
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
                    .foregroundColor(AppTheme.textSecondary)
                Spacer()
                Text("\(current)/\(goal) \(unit)")
                    .font(.caption.weight(.medium))
                    .foregroundColor(AppTheme.textPrimary)
            }
            HStack(spacing: 8) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(AppTheme.textTertiary.opacity(0.15)).frame(height: 10)
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
                    .foregroundColor(AppTheme.textPrimary)
                Text(formatTime(entry.createdAt))
                    .font(.caption)
                    .foregroundColor(AppTheme.textTertiary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(UnitConversion.formatEnergyValue(kcal: entry.calories, preferred: prefsStore.preferredUnits))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.orange)
                Text(UnitConversion.formatEnergyUnit(preferred: prefsStore.preferredUnits))
                    .font(.caption2)
                    .foregroundColor(AppTheme.textTertiary)
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
                .foregroundColor(AppTheme.textPrimary)

            Spacer()

            Text(UnitConversion.formatAmount(grams: entry.amountMl, unit: "ml", preferred: prefsStore.preferredUnits))
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.cyan)
        }
        .padding(.vertical, 4)
    }
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
        dateStr: "2026-05-18",
        food: [
            FoodEntry(id: "1", userId: "1", name: "Oatmeal", calories: 320, protein: 12, fat: 6, carbs: 56, foodId: nil, grams: nil, unit: "g", categoryName: nil, imageUrl: nil, createdAt: "2026-05-18T08:00:00Z", updatedAt: nil),
            FoodEntry(id: "2", userId: "1", name: "Chicken Breast", calories: 450, protein: 40, fat: 10, carbs: 0, foodId: nil, grams: nil, unit: "g", categoryName: nil, imageUrl: nil, createdAt: "2026-05-18T13:00:00Z", updatedAt: nil),
        ],
        water: [
            WaterEntry(id: "1", userId: "1", amountMl: 500, createdAt: "2026-05-18T10:00:00Z", updatedAt: nil),
            WaterEntry(id: "2", userId: "1", amountMl: 300, createdAt: "2026-05-18T15:00:00Z", updatedAt: nil),
        ],
        goals: UserGoals(id: "1", userId: "1", dailyCaloriesGoal: 2200, dailyProteinGoal: 150, dailyFatGoal: 65, dailyCarbsGoal: 250, dailyWaterGoal: 3000, source: "auto", createdAt: nil, updatedAt: nil)
    )
}
