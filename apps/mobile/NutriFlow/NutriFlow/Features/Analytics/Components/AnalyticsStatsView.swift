import SwiftUI

struct AnalyticsStatsView: View {
    let avgCalories: Int
    let avgProtein: Int
    let avgFat: Int
    let avgCarbs: Int
    let avgWater: Int
    let daysTracked: Int
    let totalDays: Int

    @State private var prefsStore = PreferencesStore.shared

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2),
            spacing: 12
        ) {
            StatCard(
                icon: "flame.fill",
                iconColor: .orange,
                title: "Avg Calories",
                value: "\(UnitConversion.formatEnergyValue(kcal: avgCalories, preferred: prefsStore.preferredUnits))",
                unit: UnitConversion.formatEnergyUnit(preferred: prefsStore.preferredUnits)
            )
            StatCard(
                icon: "drop.fill",
                iconColor: .blue,
                title: "Avg Water",
                value: UnitConversion.formatAmount(grams: avgWater, unit: "ml", preferred: prefsStore.preferredUnits),
                unit: ""
            )
            StatCard(
                icon: "bolt.fill",
                iconColor: .indigo,
                title: "Avg Protein",
                value: UnitConversion.formatMacro(grams: avgProtein, preferred: prefsStore.preferredUnits),
                unit: ""
            )
            StatCard(
                icon: "drop.degreesign.fill",
                iconColor: .green,
                title: "Avg Fat",
                value: UnitConversion.formatMacro(grams: avgFat, preferred: prefsStore.preferredUnits),
                unit: ""
            )
            StatCard(
                icon: "leaf.arrow.circlepath",
                iconColor: .mint,
                title: "Avg Carbs",
                value: UnitConversion.formatMacro(grams: avgCarbs, preferred: prefsStore.preferredUnits),
                unit: ""
            )
            StatCard(
                icon: "calendar",
                iconColor: .yellow,
                title: "Tracked",
                value: "\(daysTracked)/\(totalDays)",
                unit: "days"
            )
        }
    }
}

private struct StatCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    let unit: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(iconColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(AppTheme.textSecondary)
                HStack(spacing: 4) {
                    Text(value)
                        .font(.subheadline.bold())
                        .foregroundColor(AppTheme.textPrimary)
                    Text(unit)
                        .font(.caption2)
                        .foregroundColor(AppTheme.textTertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.cornerRadiusMedium)
    }
}
