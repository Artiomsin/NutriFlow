//
//  DailySummaryCard.swift
//  Nutriflow
//
//  Created by Artem on 20.05.26.
//

import SwiftUI

struct DailySummaryCard: View {

    let summary: DailySummary
    let goals: UserGoals?

    @State private var prefsStore = PreferencesStore.shared

    var body: some View {

        VStack(alignment: .leading, spacing: 14) {

            Text("Today Summary")
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)

            Text("\(UnitConversion.formatEnergyValue(kcal: summary.totalCalories, preferred: prefsStore.preferredUnits)) \(UnitConversion.formatEnergyUnit(preferred: prefsStore.preferredUnits))")
                .font(Font.title1)
                .foregroundColor(AppTheme.accent)

            if let goals = goals {
                GoalProgressRow(
                    current: UnitConversion.formatEnergyValue(kcal: summary.totalCalories, preferred: prefsStore.preferredUnits),
                    goal: goals.dailyCaloriesGoal.flatMap { UnitConversion.formatEnergyValue(kcal: $0, preferred: prefsStore.preferredUnits) },
                    label: "Calories",
                    color: .orange,
                    unit: UnitConversion.formatEnergyUnit(preferred: prefsStore.preferredUnits)
                )
                GoalProgressRow(
                    current: summary.totalProtein,
                    goal: goals.dailyProteinGoal,
                    label: "Protein",
                    color: .blue,
                    unit: "",
                    displayCurrent: UnitConversion.formatMacro(grams: summary.totalProtein, preferred: prefsStore.preferredUnits),
                    displayGoal: goals.dailyProteinGoal.map { UnitConversion.formatMacro(grams: $0, preferred: prefsStore.preferredUnits) }
                )
                GoalProgressRow(
                    current: summary.totalFat,
                    goal: goals.dailyFatGoal,
                    label: "Fat",
                    color: .green,
                    unit: "",
                    displayCurrent: UnitConversion.formatMacro(grams: summary.totalFat, preferred: prefsStore.preferredUnits),
                    displayGoal: goals.dailyFatGoal.map { UnitConversion.formatMacro(grams: $0, preferred: prefsStore.preferredUnits) }
                )
                GoalProgressRow(
                    current: summary.totalCarbs,
                    goal: goals.dailyCarbsGoal,
                    label: "Carbs",
                    color: .purple,
                    unit: "",
                    displayCurrent: UnitConversion.formatMacro(grams: summary.totalCarbs, preferred: prefsStore.preferredUnits),
                    displayGoal: goals.dailyCarbsGoal.map { UnitConversion.formatMacro(grams: $0, preferred: prefsStore.preferredUnits) }
                )
                GoalProgressRow(
                    current: summary.totalWaterMl,
                    goal: goals.dailyWaterGoal,
                    label: "Water",
                    color: .cyan,
                    unit: "",
                    displayCurrent: UnitConversion.formatAmount(grams: summary.totalWaterMl, unit: "ml", preferred: prefsStore.preferredUnits),
                    displayGoal: goals.dailyWaterGoal.map { UnitConversion.formatAmount(grams: $0, unit: "ml", preferred: prefsStore.preferredUnits) }
                )
            } else {
                Text("Water: \(UnitConversion.formatAmount(grams: summary.totalWaterMl, unit: "ml", preferred: prefsStore.preferredUnits))")
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
            }

            HStack(spacing: 12) {

                MacroBadge(title: "P", value: UnitConversion.formatMacro(grams: summary.totalProtein, preferred: prefsStore.preferredUnits))
                MacroBadge(title: "F", value: UnitConversion.formatMacro(grams: summary.totalFat, preferred: prefsStore.preferredUnits))
                MacroBadge(title: "C", value: UnitConversion.formatMacro(grams: summary.totalCarbs, preferred: prefsStore.preferredUnits))

                Spacer()
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.cornerRadiusMedium)
    }
}
