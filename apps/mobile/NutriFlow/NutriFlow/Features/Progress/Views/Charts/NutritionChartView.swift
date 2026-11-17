//
//  NutritionChartView.swift
//  Nutriflow
//
//  Created by Artem on 20.05.26.
//

import SwiftUI
import Charts
struct NutritionChartView: View {
    private struct MacroBarPoint: Identifiable {
        let dateLabel: String
        let macro: String
        let grams: Double

        var id: String { "\(dateLabel)-\(macro)" }
    }

    let data: [ChartDataPoint]
    let canTap: Bool
    let onBarTap: ((ChartDataPoint) -> Void)?
    let initialScrollX: String
    /// Period totals (today) or averages per tracked day. Computed once in
    /// `ProgressChartViewModel` from the daily data; the chart must not
    /// re-average already aggregated bars.
    let protein: Double
    let fat: Double
    let carbs: Double
    let title: String
    @State private var selection: String?

    init(
        data: [ChartDataPoint],
        protein: Double,
        fat: Double,
        carbs: Double,
        title: String,
        canTap: Bool = false,
        onBarTap: ((ChartDataPoint) -> Void)? = nil,
        initialScrollX: String = ""
    ) {
        self.data = data
        self.protein = protein
        self.fat = fat
        self.carbs = carbs
        self.title = title
        self.canTap = canTap
        self.onBarTap = onBarTap
        self.initialScrollX = initialScrollX
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill").foregroundColor(.green)
                Text(title).font(.headline).foregroundColor(AppColors.textPrimary)
                Spacer()
            }
            HStack(spacing: 20) {
                MacroSummaryItem(title: "Protein", value: protein, color: .blue)
                MacroSummaryItem(title: "Fat", value: fat, color: .yellow)
                MacroSummaryItem(title: "Carbs", value: carbs, color: .green)
            }
            .padding(.vertical, 8)
            Chart(macroBarPoints) { point in
                // Values with the same date share one x position. Standard
                // stacking makes one compact bar per date instead of three
                // bars competing for width or overflowing into neighbours.
                BarMark(
                    x: .value("Date", point.dateLabel),
                    y: .value("Grams", point.grams),
                    width: .fixed(16),
                    stacking: .standard
                )
                .foregroundStyle(by: .value("Macro", point.macro))
            }
            .frame(height: 180)
            .chartYScale(domain: 0 ... Double(maxMacroValue))
            .chartForegroundStyleScale([
                "Protein": .blue,
                "Fat": .yellow,
                "Carbs": .green
            ])
            .chartLegend(position: .bottom) { HStack(spacing: 20) { LegendItem(color: .blue, label: "Protein"); LegendItem(color: .yellow, label: "Fat"); LegendItem(color: .green, label: "Carbs") } }
            .chartYAxis { AxisMarks(position: .leading) { _ in AxisGridLine().foregroundStyle(AppColors.textTertiary .opacity(0.3)); AxisValueLabel().foregroundStyle(AppColors.textTertiary ) } }
            .chartXAxis {
                AxisMarks { _ in
                    AxisGridLine().foregroundStyle(AppColors.textTertiary .opacity(0.15))
                    AxisValueLabel().foregroundStyle(AppColors.textTertiary )
                }
            }
            .chartXSelection(value: $selection)
            .chartScrollableAxes(.horizontal)
            .chartScrollPosition(initialX: initialScrollX)
            .onChange(of: selection) { _, newVal in
                if canTap, let label = newVal, let point = data.first(where: { $0.label == label }) {
                    onBarTap?(point)
                    selection = nil
                }
            }
        }
        .padding().appGlassSurface()
    }

    /// Show only points that actually have macro data, so deleted-food hours
    /// don't leave ghost bars on the x-axis. Display-only.
    private var filteredData: [ChartDataPoint] {
        data.filter { $0.protein > 0 || $0.fat > 0 || $0.carbs > 0 }
    }

    private var macroBarPoints: [MacroBarPoint] {
        filteredData.flatMap { point in
            [
                MacroBarPoint(dateLabel: point.label, macro: "Protein", grams: point.protein),
                MacroBarPoint(dateLabel: point.label, macro: "Fat", grams: point.fat),
                MacroBarPoint(dateLabel: point.label, macro: "Carbs", grams: point.carbs)
            ]
        }
    }

    private var maxMacroValue: Double {
        // A stacked bar's height is the sum of its segments, not the maximum
        // individual macro. Scaling by an individual value would clip the bar.
        let maxValue = data.map { $0.protein + $0.fat + $0.carbs }.max() ?? 0
        return maxValue == 0 ? 100 : maxValue * 1.2
    }
}
struct MacroSummaryItem: View {
    let title: String; let value: Double; let color: Color
    @State private var prefsStore = PreferencesStore.shared
    var body: some View {
        VStack(spacing: 4) {
            Circle().fill(color).frame(width: 12, height: 12)
            Text(UnitConversion.formatMacro(grams: value, preferred: prefsStore.preferredUnits)).font(.subheadline.bold()).foregroundColor(AppColors.textPrimary)
            Text(title).font(.caption2).foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}
struct LegendItem: View {
    let color: Color; let label: String
    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.caption).foregroundColor(AppColors.textSecondary)
        }
    }
}
