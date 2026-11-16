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
    /// Period total computed from the daily data in `ProgressChartViewModel`.
    /// Summing already aggregated bars showed one week of calories for a month.
    let total: Double
    let valueDescription: String
    let canTap: Bool
    let onBarTap: ((ChartDataPoint) -> Void)?
    let initialScrollX: String
    @State private var prefsStore = PreferencesStore.shared
    @State private var selection: String?

    init(data: [ChartDataPoint], total: Double, valueDescription: String, canTap: Bool = false, onBarTap: ((ChartDataPoint) -> Void)? = nil, initialScrollX: String = "") {
        self.data = data
        self.total = total
        self.valueDescription = valueDescription
        self.canTap = canTap
        self.onBarTap = onBarTap
        self.initialScrollX = initialScrollX
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "flame.fill").foregroundColor(.orange)
                Text("Calories (Total)").font(.headline).foregroundColor(AppColors.textPrimary)
                Spacer()
                Text(UnitConversion.formatEnergy(kcal: total, preferred: prefsStore.preferredUnits)).font(.subheadline).foregroundColor(AppColors.textSecondary)
            }
            
            Chart(filteredData) { point in
                BarMark(x: .value("Date", point.label), y: .value("Calories", point.calories), width: .fixed(16))
                    .foregroundStyle(LinearGradient(colors: [.orange, .red], startPoint: .top, endPoint: .bottom))
                    .cornerRadius(4)
            }
            .frame(height: 180)
            .chartYScale(domain: 0 ... Double(maxYValue))
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { _ in
                    AxisGridLine().foregroundStyle(AppColors.textTertiary .opacity(0.3))
                    AxisValueLabel().foregroundStyle(AppColors.textTertiary )
                }
            }
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
                    DispatchQueue.main.async { selection = nil }
                }
            }
            Text(valueDescription)
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)
        }
        .padding()
        .appGlassSurface()
    }

    /// Show only points that actually have calories, so deleted-food hours
    /// don't leave ghost bars/labels on the x-axis. Display-only.
    private var filteredData: [ChartDataPoint] {
        data.filter { $0.calories > 0 }
    }
    
    
    private var maxYValue: Double {
        let max = data.map(\.calories).max() ?? 0
        if max == 0 { return 1_000 }
        return max * 1.45
    }
}
