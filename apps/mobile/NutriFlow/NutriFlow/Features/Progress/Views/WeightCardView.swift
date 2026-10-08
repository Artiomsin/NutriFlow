import SwiftUI
import Charts

struct WeightCardView: View {
    let points: [WeightPoint]
    let latestKg: Double?
    let deltaKg: Double?
    let weeklyRateKg: Double?
    let periodLabel: String
    let onRecordWeight: () -> Void
    let onManageWeights: () -> Void

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
        VStack(alignment: .leading, spacing: 14) {
            header

            if !points.isEmpty {
                summary

                chart
                if points.count == 1 {
                    Text("Record another day to see your change over time.")
                        .font(.footnote)
                        .foregroundColor(AppColors.textTertiary)
                }
            } else {
                emptyState
            }
        }
        .padding(14)
        .appGlassSurface()
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "scalemass.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColors.accent)
                .frame(width: 32, height: 32)
                .background(AppColors.accent.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("Weight")
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary)
                Text(periodLabel)
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            Button(action: onManageWeights) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.footnote.weight(.semibold))
                    .frame(width: 32, height: 32)
            }
            .foregroundColor(AppColors.textSecondary)
            .accessibilityLabel("Manage weight records")

            Button(action: onRecordWeight) {
                Label("Record", systemImage: "plus")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .frame(height: 32)
            }
            .foregroundColor(AppColors.accentOnPrimary)
            .background(AppColors.accent)
            .clipShape(Capsule())
        }
    }

    private var summary: some View {
        HStack(alignment: .bottom, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("LATEST")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(AppColors.textTertiary)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(latestText)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(AppColors.textPrimary)
                    Text(targetUnit)
                        .font(.footnote.weight(.medium))
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            Spacer()

            if let deltaText {
                metric(value: "\(deltaText) \(targetUnit)", label: "CHANGE")
            }
            if let rateText {
                metric(value: "\(rateText) \(targetUnit)", label: "PER WEEK")
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No weight records for this period")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(AppColors.textPrimary)

            Text("Record your weight to start tracking your trend.")
                .font(.footnote)
                .foregroundColor(AppColors.textSecondary)

            Button(action: onRecordWeight) {
                Label("Record weight", systemImage: "plus")
                    .font(.footnote.weight(.semibold))
            }
            .foregroundColor(AppColors.accent)
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
        .padding(.horizontal, 2)
    }

    private func metric(value: String, label: String) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(value)
                .font(.footnote.weight(.semibold))
                .monospacedDigit()
                .foregroundColor(AppColors.textPrimary)
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundColor(AppColors.textTertiary)
        }
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

                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Weight", point.kg)
                )
                .foregroundStyle(AppColors.accent)
                .symbolSize(30)
            }
        }
        .chartYScale(domain: yDomain())
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartPlotStyle { plot in
            plot.background(Color.clear)
        }
        .frame(height: 112)
    }

    private func yDomain() -> ClosedRange<Double> {
        guard let min = points.map({ $0.kg }).min(),
              let max = points.map({ $0.kg }).max() else { return 0...100 }
        return (min - 0.5)...(max + 0.5)
    }
}
