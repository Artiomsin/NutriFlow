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
            Chart(data) { point in
                BarMark(x: .value("Date", point.date), y: .value("Protein", point.protein)).foregroundStyle(.blue)
                BarMark(x: .value("Date", point.date), y: .value("Fat", point.fat)).foregroundStyle(.yellow)
                BarMark(x: .value("Date", point.date), y: .value("Carbs", point.carbs)).foregroundStyle(.green)
            }
            .frame(height: 180)
            .chartLegend(position: .bottom) { HStack(spacing: 20) { LegendItem(color: .blue, label: "Protein"); LegendItem(color: .yellow, label: "Fat"); LegendItem(color: .green, label: "Carbs") } }
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
