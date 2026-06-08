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
            ScrollView(.horizontal, showsIndicators: false) {
                Chart(data) { point in
                    LineMark(x: .value("Date", point.label), y: .value("Water", point.waterMl))
                        .foregroundStyle(.blue).interpolationMethod(.catmullRom)
                    AreaMark(x: .value("Date", point.label), y: .value("Water", point.waterMl))
                        .foregroundStyle(LinearGradient(colors: [.blue.opacity(0.3), .blue.opacity(0.05)], startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.catmullRom)
                    PointMark(x: .value("Date", point.label), y: .value("Water", point.waterMl))
                        .foregroundStyle(.blue).symbolSize(30)
                }
                .frame(width: chartWidth, height: 180)
                .chartYScale(domain: 0 ... Double(maxWaterValue))
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

    private var totalWater: Int { data.reduce(0) { $0 + $1.waterMl } }

    private var maxWaterValue: Int {
        let max = data.map { $0.waterMl }.max() ?? 0
        if max == 0 { return 2000 }
        return max + (max * 20 / 100)
    }
}
