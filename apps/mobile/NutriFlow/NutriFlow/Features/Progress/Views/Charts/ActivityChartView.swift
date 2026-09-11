//
//  ActivityChartView.swift
//  Nutriflow
//
//  Created by Artem on 04.09.2026.
//

import SwiftUI
import Charts

struct ActivityChartView: View {
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

    private struct FlattenedPoint: Identifiable {
        let id = UUID()
        let label: String
        let series: String
        let color: Color
        let value: Int
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "flame.fill").foregroundColor(.orange)
                Text("Energy").font(.headline).foregroundColor(AppTheme.textPrimary)
                Spacer()
            }

            HStack(spacing: 16) {
                legendDot(color: .orange, text: "Eaten")
                legendDot(color: .green, text: "Burned")
                legendDot(color: .blue, text: "Rest")
            }

            Chart(flattenedPoints) { point in
                LineMark(
                    x: .value("Date", point.label),
                    y: .value("Calories", point.value),
                    series: .value("Series", point.series)
                )
                .foregroundStyle(point.color)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                .symbol {
                    Circle()
                        .fill(point.color)
                        .frame(width: 6, height: 6)
                }
                .symbolSize(30)
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

    private func legendDot(color: Color, text: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text).font(.caption).foregroundColor(AppTheme.textSecondary)
        }
    }

    private var filteredData: [ChartDataPoint] {
        data.filter { $0.calories != 0 || $0.activeCalories != 0 || $0.basalCalories != 0 }
    }

    private var flattenedPoints: [FlattenedPoint] {
        filteredData.flatMap { pt in
            [
                FlattenedPoint(label: pt.label, series: "Eaten", color: .orange, value: pt.calories),
                FlattenedPoint(label: pt.label, series: "Burned", color: .green, value: pt.activeCalories),
                FlattenedPoint(label: pt.label, series: "Rest", color: .blue, value: pt.basalCalories)
            ]
        }
    }

    private var maxYValue: Int {
        let max = filteredData.flatMap { [$0.calories, $0.activeCalories, $0.basalCalories] }.max() ?? 0
        if max == 0 { return 1000 }
        return max + (max * 25 / 100)
    }
}


#Preview {
    let data: [ChartDataPoint] = (0..<14).map { offset in
        let day = Calendar.current.date(byAdding: .day, value: offset - 7, to: Date())!
        let base = Int.random(in: 1600...2400)
        let burned = Int.random(in: 300...800)
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return ChartDataPoint(
            date: day,
            label: formatter.string(from: day),
            calories: base,
            protein: 0,
            fat: 0,
            carbs: 0,
            waterMl: 0,
            steps: Int.random(in: 3000...12000),
            activeCalories: burned,
            basalCalories: Int.random(in: 1300...1900),
            distanceMeters: Double(Int.random(in: 2000...9000)),
            netCalories: base - burned
        )
    }
    return ActivityChartView(data: data)
        .padding()
        .background(AppTheme.background)
        .preferredColorScheme(.dark)
}
