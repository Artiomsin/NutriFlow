//
//  NutritionChartView.swift
//  Nutriflow
//
//  Created by Artem on 20.05.26.
//

import SwiftUI
import Charts
struct NutritionChartView: View {
    let data: [ChartDataPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill").foregroundColor(.green)
                Text("Macros (Avg)").font(.headline).foregroundColor(AppTheme.textPrimary)
                Spacer()
            }
            HStack(spacing: 20) {
                MacroSummaryItem(title: "Protein", value: avgProtein, color: .blue)
                MacroSummaryItem(title: "Fat", value: avgFat, color: .yellow)
                MacroSummaryItem(title: "Carbs", value: avgCarbs, color: .green)
            }
            .padding(.vertical, 8)
            ScrollView(.horizontal, showsIndicators: false) {
                Chart(data) { point in
                    BarMark(x: .value("Date", point.label), y: .value("Protein", point.protein), width: .fixed(14)).foregroundStyle(.blue)
                    BarMark(x: .value("Date", point.label), y: .value("Fat", point.fat), width: .fixed(14)).foregroundStyle(.yellow)
                    BarMark(x: .value("Date", point.label), y: .value("Carbs", point.carbs), width: .fixed(14)).foregroundStyle(.green)
                }
                .frame(width: chartWidth, height: 180)
                .chartLegend(position: .bottom) { HStack(spacing: 20) { LegendItem(color: .blue, label: "Protein"); LegendItem(color: .yellow, label: "Fat"); LegendItem(color: .green, label: "Carbs") } }
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

    private var avgProtein: Int { guard !data.isEmpty else { return 0 }; return Int(data.reduce(0) { $0 + $1.protein } / Double(data.count)) }
    private var avgFat: Int { guard !data.isEmpty else { return 0 }; return Int(data.reduce(0) { $0 + $1.fat } / Double(data.count)) }
    private var avgCarbs: Int { guard !data.isEmpty else { return 0 }; return Int(data.reduce(0) { $0 + $1.carbs } / Double(data.count)) }
}
struct MacroSummaryItem: View {
    let title: String; let value: Int; let color: Color
    var body: some View {
        VStack(spacing: 4) {
            Circle().fill(color).frame(width: 12, height: 12)
            Text("\(value)g").font(.subheadline.bold()).foregroundColor(AppTheme.textPrimary)
            Text(title).font(.caption2).foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}
struct LegendItem: View {
    let color: Color; let label: String
    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.caption).foregroundColor(AppTheme.textSecondary)
        }
    }
}
