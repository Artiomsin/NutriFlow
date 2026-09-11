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
    let canTap: Bool
    let onBarTap: ((ChartDataPoint) -> Void)?
    let initialScrollX: String
    @State private var prefsStore = PreferencesStore.shared
    @State private var selection: String?

    init(data: [ChartDataPoint], canTap: Bool = false, onBarTap: ((ChartDataPoint) -> Void)? = nil, initialScrollX: String = "") {
        self.data = data
        self.canTap = canTap
        self.onBarTap = onBarTap
        self.initialScrollX = initialScrollX
    }

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
            Chart(filteredData) { point in
                BarMark(x: .value("Date", point.label), y: .value("Protein", point.protein), width: .fixed(14)).foregroundStyle(.blue)
                BarMark(x: .value("Date", point.label), y: .value("Fat", point.fat), width: .fixed(14)).foregroundStyle(.yellow)
                BarMark(x: .value("Date", point.label), y: .value("Carbs", point.carbs), width: .fixed(14)).foregroundStyle(.green)
            }
            .frame(height: 180)
            .chartYScale(domain: 0 ... Double(maxMacroValue))
            .chartLegend(position: .bottom) { HStack(spacing: 20) { LegendItem(color: .blue, label: "Protein"); LegendItem(color: .yellow, label: "Fat"); LegendItem(color: .green, label: "Carbs") } }
            .chartYAxis { AxisMarks(position: .leading) { _ in AxisGridLine().foregroundStyle(AppTheme.textTertiary.opacity(0.3)); AxisValueLabel().foregroundStyle(AppTheme.textTertiary) } }
            .chartXAxis {
                AxisMarks { _ in
                    AxisGridLine().foregroundStyle(AppTheme.textTertiary.opacity(0.15))
                    AxisValueLabel().foregroundStyle(AppTheme.textTertiary)
                }
            }
            .chartXSelection(value: $selection)
            .chartScrollableAxes(.horizontal)
            .chartScrollPosition(initialX: initialScrollX)
            .onChange(of: selection) { _, newVal in
                if canTap, let label = newVal, let point = data.first(where: { $0.label == label }) {
                    onBarTap?(point)
                    DispatchQueue.main.async { selection = nil }
                }
            }
        }
        .padding().background(AppTheme.cardBackground).cornerRadius(AppTheme.cornerRadiusMedium)
    }

    private var avgProtein: Int { guard !data.isEmpty else { return 0 }; return Int(data.reduce(0) { $0 + $1.protein } / Double(data.count)) }
    private var avgFat: Int { guard !data.isEmpty else { return 0 }; return Int(data.reduce(0) { $0 + $1.fat } / Double(data.count)) }
    private var avgCarbs: Int { guard !data.isEmpty else { return 0 }; return Int(data.reduce(0) { $0 + $1.carbs } / Double(data.count)) }

    /// Show only points that actually have macro data, so deleted-food hours
    /// don't leave ghost bars on the x-axis. Display-only.
    private var filteredData: [ChartDataPoint] {
        data.filter { $0.protein > 0 || $0.fat > 0 || $0.carbs > 0 }
    }

    private var maxMacroValue: Int {
        let maxVal = data.map { Swift.max($0.protein, Swift.max($0.fat, $0.carbs)) }.max() ?? 0.0
        if maxVal == 0 { return 100 }
        return Int(maxVal + (maxVal * 20 / 100))
    }
}
struct MacroSummaryItem: View {
    let title: String; let value: Int; let color: Color
    @State private var prefsStore = PreferencesStore.shared
    var body: some View {
        VStack(spacing: 4) {
            Circle().fill(color).frame(width: 12, height: 12)
            Text(UnitConversion.formatMacro(grams: value, preferred: prefsStore.preferredUnits)).font(.subheadline.bold()).foregroundColor(AppTheme.textPrimary)
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
