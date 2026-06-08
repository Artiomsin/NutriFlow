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

    var body: some View {

        VStack(alignment: .leading, spacing: 14) {

            Text("Today Summary")
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)

            Text("\(summary.totalCalories) kcal")
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(AppTheme.accent)

            if let goals = goals {
                GoalProgressRow(
                    current: summary.totalCalories,
                    goal: goals.dailyCaloriesGoal,
                    label: "Calories",
                    color: .orange,
                    unit: "kcal"
                )
                GoalProgressRow(
                    current: Int(summary.totalProtein),
                    goal: goals.dailyProteinGoal,
                    label: "Protein",
                    color: .blue,
                    unit: "g"
                )
                GoalProgressRow(
                    current: Int(summary.totalFat),
                    goal: goals.dailyFatGoal,
                    label: "Fat",
                    color: .green,
                    unit: "g"
                )
                GoalProgressRow(
                    current: Int(summary.totalCarbs),
                    goal: goals.dailyCarbsGoal,
                    label: "Carbs",
                    color: .purple,
                    unit: "g"
                )
                GoalProgressRow(
                    current: summary.totalWaterMl,
                    goal: goals.dailyWaterGoal,
                    label: "Water",
                    color: .cyan,
                    unit: "ml"
                )
            } else {
                Text("Water: \(summary.totalWaterMl) ml")
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
            }

            HStack(spacing: 12) {

                MacroBadge(title: "P", value: Int(summary.totalProtein))
                MacroBadge(title: "F", value: Int(summary.totalFat))
                MacroBadge(title: "C", value: Int(summary.totalCarbs))

                Spacer()
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.cornerRadiusMedium)
    }
}
