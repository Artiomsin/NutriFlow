import SwiftUI
import Charts

struct WeightCardView: View {
    let points: [WeightPoint]
    let latestKg: Double?
    let deltaKg: Double?
    let weeklyRateKg: Double?
    let periodLabel: String

    @State private var units = PreferencesStore.shared.preferredUnits

    private var targetUnit: String {
        units.weight == .imperial ? "lb" : "kg"
    }

    private var latestText: String {
        guard let kg = latestKg else { return "—" }
        let value = UnitConversion.bodyWeightToDisplay(kg: kg, preferred: units)
        if units.weight == .imperial {
            return String(format: "%.1f", value)
        }
        return String(Int(value.rounded()))
    }

    private var deltaText: String? {
        guard let delta = deltaKg else { return nil }
        let value = UnitConversion.bodyWeightToDisplay(kg: abs(delta), preferred: units)
        let formatted = String(format: "%.1f", value)
        if delta > 0 { return "+\(formatted)" }
        if delta < 0 { return "−\(formatted)" }
        return "±0.0"
    }

    private var rateText: String? {
        guard let rate = weeklyRateKg else { return nil }
        let value = UnitConversion.bodyWeightToDisplay(kg: abs(rate), preferred: units)
        let formatted = String(format: "%.1f", value)
        if rate > 0 { return "+\(formatted)" }
        if rate < 0 { return "−\(formatted)" }
        return "±0.0"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Weight")
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                Text(periodLabel)
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            if points.count > 1 {
                chart

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(latestText)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                    Text(targetUnit)
                        .font(.footnote)
                        .foregroundColor(AppColors.textSecondary)
                    Spacer()
                    if let deltaText {
                        Text("\(deltaText) \(targetUnit)")
                            .font(.footnote)
                            .foregroundColor(AppColors.textPrimary)
                    }
                    if let rateText {
                        Text("· \(rateText) \(targetUnit)/week")
                            .font(.footnote)
                            .foregroundColor(AppColors.textTertiary )
                    }
                }
            } else {
                Text(points.isEmpty
                     ? "Enter your weight in Profile — trend will appear here"
                     : "Track your weight for a few days to see the trend")
                    .font(.footnote)
                    .foregroundColor(AppColors.textTertiary )
            }
        }
        .padding(14)
        .appGlassSurface()
    }

    private var chart: some View {
        Chart {
            ForEach(points) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Weight", point.kg)
                )
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                .foregroundStyle(AppColors.accent)
                .symbol {
                    Circle()
                        .fill(AppColors.accent)
                        .frame(width: 6, height: 6)
                }
                .symbolSize(20)
            }
        }
        .chartYScale(domain: yDomain())
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartPlotStyle { plot in
            plot.background(Color.clear)
        }
        .frame(height: 100)
    }

    private func yDomain() -> ClosedRange<Double> {
        guard let min = points.map({ $0.kg }).min(),
              let max = points.map({ $0.kg }).max() else { return 0...100 }
        return (min - 0.5)...(max + 0.5)
    }
}
