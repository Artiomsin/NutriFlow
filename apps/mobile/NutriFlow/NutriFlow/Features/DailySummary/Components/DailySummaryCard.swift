//
//  DailySummaryCard.swift
//  Nutriflow
//
//  Created by Artem on 20.05.26.
//

import SwiftUI

struct DailySummaryCard: View {

    let summary: DailySummary

    var body: some View {

        VStack(alignment: .leading, spacing: 14) {

            Text("Today Summary")
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)

            Text("\(summary.totalCalories) kcal")
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(AppTheme.accent)

            HStack(spacing: 12) {

                MacroBadge(title: "P", value: Int(summary.totalProtein))
                MacroBadge(title: "F", value: Int(summary.totalFat))
                MacroBadge(title: "C", value: Int(summary.totalCarbs))

                Spacer()
            }

            Text("Water: \(summary.totalWaterMl) ml")
                .font(.caption)
                .foregroundColor(AppTheme.textSecondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.cornerRadiusMedium)
    }
}
