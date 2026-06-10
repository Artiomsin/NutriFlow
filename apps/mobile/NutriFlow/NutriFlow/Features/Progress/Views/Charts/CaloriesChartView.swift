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
    let onBarTap: ((String) -> Void)?
    @State private var selection: String?

    init(data: [ChartDataPoint], canTap: Bool = false, onBarTap: ((String) -> Void)? = nil) {
        self.data = data
        self.canTap = canTap
        self.onBarTap = onBarTap
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "flame.fill").foregroundColor(.orange)
                Text("Calories").font(.headline).foregroundColor(AppTheme.textPrimary)
                Spacer()
                Text("\(totalCalories) kcal").font(.subheadline).foregroundColor(AppTheme.textSecondary)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                Chart(data) { point in
                    BarMark(x: .value("Date", point.label), y: .value("Calories", point.calories), width: .fixed(16))
                        .foregroundStyle(LinearGradient(colors: [.orange, .red], startPoint: .top, endPoint: .bottom))
                        .cornerRadius(4)
                }
                .frame(width: chartWidth, height: 180)
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
                .onChange(of: selection) { _, newVal in
                    if canTap, let label = newVal {
                        onBarTap?(label)
                        DispatchQueue.main.async { selection = nil }
                    }
                }
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.cornerRadiusMedium)
    }

    private var chartWidth: CGFloat {
        let perBar: CGFloat = data.count <= 10 ? 80 : 100
        return max(360, CGFloat(data.count) * perBar)
    }

    private var totalCalories: Int {
        data.reduce(0) { $0 + $1.calories }
    }
    
    
    private var maxYValue: Int {
        let max = data.map { $0.calories }.max() ?? 0
        if max == 0 { return 1000 }
        return max + (max * 45 / 100)
    }
}
