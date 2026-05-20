//
//   CaloriesChartView.swift
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
            Chart(data) { point in
                BarMark(x: .value("Date", point.date), y: .value("Calories", point.calories))
                    .foregroundStyle(LinearGradient(colors: [.orange, .red], startPoint: .top, endPoint: .bottom))
                    .cornerRadius(4)
            }
            .frame(height: 180)
            .chartPlotStyle { $0.padding(.leading, 8) }
            .chartYAxis { AxisMarks(position: .leading) { _ in AxisGridLine().foregroundStyle(AppTheme.textTertiary.opacity(0.3)); AxisValueLabel().foregroundStyle(AppTheme.textTertiary) } }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: labelStride)) { _ in
                    AxisGridLine().foregroundStyle(AppTheme.textTertiary.opacity(0.15))
                    AxisValueLabel(format: .dateTime.day().month())
                        .foregroundStyle(AppTheme.textTertiary)
                        .font(.caption2)
                }
            }
        }
        .padding().background(AppTheme.cardBackground).cornerRadius(AppTheme.cornerRadiusMedium)
    }
    
    private var labelStride: Int {
        max(1, data.count / 7)
    }
    
    private var totalCalories: Int { data.reduce(0) { $0 + $1.calories } }
}
