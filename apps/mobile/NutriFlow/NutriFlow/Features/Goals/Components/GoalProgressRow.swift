//
//  GoalProgressRow.swift
//  Nutriflow
//
//  Created by Artem on 8.06.26.
//

import SwiftUI

struct GoalProgressRow: View {
    let current: Int
    let goal: Int?
    let label: String
    let color: Color
    let unit: String
    var displayCurrent: String? = nil
    var displayGoal: String? = nil

    var body: some View {
        if let goal = goal, goal > 0 {
            let pct = min(Double(current) / Double(goal), 1.0)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(label)
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                    Spacer()
                    Text("\(displayCurrent ?? "\(current)")/\(displayGoal ?? "\(goal)") \(unit) (\(Int(pct * 100))%)")
                        .font(.caption)
                        .foregroundColor(AppTheme.textPrimary)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.1))
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
