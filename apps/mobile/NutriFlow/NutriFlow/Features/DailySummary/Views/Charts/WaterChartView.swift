//
//  WaterChartView.swift
//  Nutriflow
//
//  Created by Artem on 20.05.26.
//

import SwiftUI
import Charts
struct WaterChartView: View {
    let data: [ChartDataPoint]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "drop.fill").foregroundColor(.blue)
                Text("Water Intake").font(.headline).foregroundColor(AppTheme.textPrimary)
                Spacer()
                Text("\(totalWater) ml").font(.subheadline).foregroundColor(AppTheme.textSecondary)
            }
            Chart(data) { point in
                LineMark(x: .value("Date", point.date), y: .value("Water", point.waterMl))
                    .foregroundStyle(.blue).interpolationMethod(.catmullRom)
                AreaMark(x: .value("Date", point.date), y: .value("Water", point.waterMl))
                    .foregroundStyle(LinearGradient(colors: [.blue.opacity(0.3), .blue.opacity(0.05)], startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.catmullRom)
                PointMark(x: .value("Date", point.date), y: .value("Water", point.waterMl))
                    .foregroundStyle(.blue).symbolSize(30)
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
    
    private var totalWater: Int { data.reduce(0) { $0 + $1.waterMl } }
}
