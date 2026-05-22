//
//  CaloriesChartView.swift
//  Nutriflow
//
//  Created by Artem on 20.05.26.
//

import SwiftUI
import Charts
struct CaloriesChartView: View {
    let data: [ChartDataPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "flame.fill").foregroundColor(.orange)
                Text("Calories").font(.headline).foregroundColor(AppTheme.textPrimary)
                Spacer()
                Text("\(totalCalories) kcal").font(.subheadline).foregroundColor(AppTheme.textSecondary)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                Chart(data) { point in
                    BarMark(x: .value("Date", point.label), y: .value("Calories", point.calories), width: .fixed(16))
                        .foregroundStyle(LinearGradient(colors: [.orange, .red], startPoint: .top, endPoint: .bottom))
                        .cornerRadius(4)
                }
                .frame(width: chartWidth, height: 180)
                .chartYAxis { AxisMarks(position: .leading) { _ in AxisGridLine().foregroundStyle(AppTheme.textTertiary.opacity(0.3)); AxisValueLabel().foregroundStyle(AppTheme.textTertiary) } }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisGridLine().foregroundStyle(AppTheme.textTertiary.opacity(0.15))
                        AxisValueLabel().foregroundStyle(AppTheme.textTertiary)
                    }
                }
            }
        }
        .padding().background(AppTheme.cardBackground).cornerRadius(AppTheme.cornerRadiusMedium)
    }

    private var chartWidth: CGFloat {
        let perBar: CGFloat = data.count <= 10 ? 80 : 100
        return max(360, CGFloat(data.count) * perBar)
    }

    private var totalCalories: Int { data.reduce(0) { $0 + $1.calories } }
}
