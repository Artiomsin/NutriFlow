//
//  GoalProgressRow.swift
//  Nutriflow
//
//  Created by Artem on 8.06.26.
//

import SwiftUI

struct GoalProgressRow: View {
    let current: Double
    let goal: Double?
    let label: String
    let color: Color
    let unit: String
    var displayCurrent: String? = nil
    var displayGoal: String? = nil

    var body: some View {
        if let goal = goal, goal > 0 {
            let pct = min(current / goal, 1.0)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(label)
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)

                    Spacer()

                    HStack(spacing: 4) {
                        Text("\(displayCurrent ?? "\(current)")/\(displayGoal ?? "\(goal)") \(unit)")
                        Text(pct, format: .percent.precision(.fractionLength(0)))
                    }
                    .font(.caption)
                    .foregroundColor(AppColors.textPrimary)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppColors.surfaceSecondary)
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(color)
                            .frame(width: geo.size.width * pct, height: 8)
                    }
                }
                .frame(height: 8)
            }
        }
    }
}
