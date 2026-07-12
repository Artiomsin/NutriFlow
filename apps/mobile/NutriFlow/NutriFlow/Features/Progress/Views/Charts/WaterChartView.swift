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
    let canTap: Bool
    let onBarTap: ((String) -> Void)?
    @State private var prefsStore = PreferencesStore.shared
    @State private var selection: String?

    init(data: [ChartDataPoint], canTap: Bool = false, onBarTap: ((String) -> Void)? = nil) {
        self.data = data
        self.canTap = canTap
        self.onBarTap = onBarTap
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "drop.fill").foregroundColor(.blue)
                Text("Water Intake").font(.headline).foregroundColor(AppTheme.textPrimary)
                Spacer()
                Text(UnitConversion.formatAmount(grams: totalWater, unit: "ml", preferred: prefsStore.preferredUnits)).font(.subheadline).foregroundColor(AppTheme.textSecondary)
            }
            Chart(data) { point in
                LineMark(x: .value("Date", point.label), y: .value("Water", point.waterMl))
                    .foregroundStyle(.blue).interpolationMethod(.catmullRom)
                AreaMark(x: .value("Date", point.label), y: .value("Water", point.waterMl))
                    .foregroundStyle(LinearGradient(colors: [.blue.opacity(0.3), .blue.opacity(0.05)], startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.catmullRom)
                PointMark(x: .value("Date", point.label), y: .value("Water", point.waterMl))
                    .foregroundStyle(.blue).symbolSize(30)
            }
            .frame(height: 180)
            .chartYScale(domain: 0 ... Double(maxWaterValue))
            .chartYAxis { AxisMarks(position: .leading) { _ in AxisGridLine().foregroundStyle(AppTheme.textTertiary.opacity(0.3)); AxisValueLabel().foregroundStyle(AppTheme.textTertiary) } }
            .chartXAxis {
                AxisMarks { _ in
                    AxisGridLine().foregroundStyle(AppTheme.textTertiary.opacity(0.15))
                    AxisValueLabel().foregroundStyle(AppTheme.textTertiary)
                }
            }
            .chartXSelection(value: $selection)
            .chartScrollableAxes(.horizontal)
            .onChange(of: selection) { _, newVal in
                if canTap, let label = newVal {
                    onBarTap?(label)
                    DispatchQueue.main.async { selection = nil }
                }
            }
        }
        .padding().background(AppTheme.cardBackground).cornerRadius(AppTheme.cornerRadiusMedium)
    }

    private var totalWater: Int { data.reduce(0) { $0 + $1.waterMl } }

    private var maxWaterValue: Int {
        let max = data.map { $0.waterMl }.max() ?? 0
        if max == 0 { return 2000 }
        return max + (max * 20 / 100)
    }
}
