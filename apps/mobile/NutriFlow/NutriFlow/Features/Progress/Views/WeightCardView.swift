import SwiftUI
import Charts

struct WeightCardView: View {
    let points: [WeightPoint]
    let latestKg: Double?
    let deltaKg: Double?
    let weeklyRateKg: Double?
    let periodLabel: String
    let isLoading: Bool
    let error: AppError?
    let isToday: Bool
    let onRetry: () -> Void
    let onRecordWeight: () -> Void
    let onManageWeights: () -> Void

    @State private var preferencesStore = PreferencesStore.shared

    private var targetUnit: String {
        UnitConversion.bodyWeightUnitLabel(preferred: preferencesStore.preferredUnits)
    }

    private var latestText: String {
        guard let kg = latestKg else { return "—" }
        return UnitConversion.formatBodyWeight(kg: kg, preferred: preferencesStore.preferredUnits)
    }

    private var deltaText: String? {
        guard let delta = deltaKg else { return nil }
        let formatted = UnitConversion.formatBodyWeight(kg: abs(delta), preferred: preferencesStore.preferredUnits)
        if delta > 0 { return "+\(formatted)" }
        if delta < 0 { return "−\(formatted)" }
        return "±0.0"
    }

    private var rateText: String? {
        guard let rate = weeklyRateKg else { return nil }
        let formatted = UnitConversion.formatBodyWeight(kg: abs(rate), preferred: preferencesStore.preferredUnits)
        if rate > 0 { return "+\(formatted)" }
        if rate < 0 { return "−\(formatted)" }
        return "±0.0"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if let error, points.isEmpty {
                ErrorView(error: error, onRetry: onRetry)
            }

            content
                .opacity(isLoading ? 0.55 : 1)
                .animation(.easeInOut(duration: 0.15), value: isLoading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: WeightCardLayout.stableMinimumHeight, alignment: .topLeading)
        .appGlassSurface()
    }

    @ViewBuilder
    private var content: some View {
        if !points.isEmpty {
            summary
            trendRegion
        } else if isLoading {
            loadingPlaceholder
        } else {
            emptyState
        }
    }

    @ViewBuilder
    private var trendRegion: some View {
        if points.count >= 2 {
            chart
        } else {
            singleRecordState
        }
    }

    /// Keeps the card's height stable when Today has only the profile's current
    /// weight. A single point has no trend, so present a meaningful state in
    /// the same space as the chart rather than showing a misleading graph.
    private var singleRecordState: some View {
        HStack(spacing: 12) {
            Image(systemName: "scalemass")
                .font(.title3)
                .foregroundStyle(AppColors.accent)
                .frame(width: 40, height: 40)
                .background(AppColors.accent.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(isToday ? "Current weight" : "First record in this period")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
                Text("Add another record on a different day to see your trend.")
                    .font(.footnote)
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
        .padding(.horizontal, 4)
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
                HStack(spacing: 5) {
                    Text(periodLabel.isEmpty && isLoading ? "Loading…" : periodLabel)
                    if isLoading {
                        SkeletonBlock(width: 28, height: 9, cornerRadius: 4.5)
                            .skeletonShimmer()
                            .accessibilityLabel("Updating weight")
                    }
                }
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

            if error != nil, !points.isEmpty {
                Button(action: onRetry) {
                    Image(systemName: "arrow.clockwise")
                        .font(.footnote.weight(.semibold))
                        .frame(width: 32, height: 32)
                }
                .foregroundColor(AppColors.warning)
                .accessibilityLabel("Retry loading weight")
            }

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

    private var loadingPlaceholder: some View {
        VStack(alignment: .leading, spacing: 12) {
            SkeletonBlock(width: 92, height: 12)
            SkeletonBlock(width: 150, height: 30)
            SkeletonBlock(height: 96, cornerRadius: AppRadius.medium)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .skeletonShimmer()
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
                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("Weight", point.kg)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            AppColors.accent.opacity(0.28),
                            AppColors.accent.opacity(0.02)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Weight", point.kg)
                )
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                .foregroundStyle(AppColors.accent)

                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Weight", point.kg)
                )
                .foregroundStyle(AppColors.accent)
                .symbolSize(30)
            }
        }
        .chartYScale(domain: yDomain())
        .chartXScale(range: .plotDimension(startPadding: 16, endPadding: 16))
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartPlotStyle { plot in
            plot.background(Color.clear)
        }
        .frame(height: 112)
        .clipped()
    }

    private func yDomain() -> ClosedRange<Double> {
        guard let min = points.map({ $0.kg }).min(),
              let max = points.map({ $0.kg }).max() else { return 0...100 }
        return (min - 0.5)...(max + 0.5)
    }
}
