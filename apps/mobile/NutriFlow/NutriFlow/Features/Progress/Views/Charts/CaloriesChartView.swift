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
                Image(systemName: "flame.fill").foregroundColor(.orange)
                Text("Calories").font(.headline).foregroundColor(AppTheme.textPrimary)
                Spacer()
                Text("\(UnitConversion.formatEnergyValue(kcal: totalCalories, preferred: prefsStore.preferredUnits)) \(UnitConversion.formatEnergyUnit(preferred: prefsStore.preferredUnits))").font(.subheadline).foregroundColor(AppTheme.textSecondary)
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
                    AxisGridLine().foregroundStyle(AppTheme.textTertiary.opacity(0.3))
                    AxisValueLabel().foregroundStyle(AppTheme.textTertiary)
                }
            }
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
        .padding()
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.cornerRadiusMedium)
    }

    private var totalCalories: Int {
        data.reduce(0) { $0 + $1.calories }
    }

    /// Show only points that actually have calories, so deleted-food hours
    /// don't leave ghost bars/labels on the x-axis. Display-only.
    private var filteredData: [ChartDataPoint] {
        data.filter { $0.calories > 0 }
    }
    
    
    private var maxYValue: Int {
        let max = data.map { $0.calories }.max() ?? 0
        if max == 0 { return 1000 }
        return max + (max * 45 / 100)
    }
}
