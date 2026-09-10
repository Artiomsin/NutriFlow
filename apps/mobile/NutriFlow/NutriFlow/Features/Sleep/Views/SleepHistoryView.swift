import SwiftUI
import Charts

@MainActor
struct SleepHistoryView: View {

    @Bindable var vm: SleepViewModel

    var body: some View {
        Group {
            switch vm.state {
            case .idle, .loading:
                ProgressView().tint(AppTheme.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .needsAccess:
                Text("Connect Apple Health to see sleep history")
                    .foregroundColor(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .empty:
                VStack(spacing: 12) {
                    Image(systemName: "moon")
                        .font(.title2)
                        .foregroundColor(AppTheme.textSecondary)
                    Text("No sleep data yet")
                        .foregroundColor(AppTheme.textSecondary)
                    Button {
                        Task { await vm.refreshHistory() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.accent)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .error(let message):
                Text("Failed to load sleep: \(message)")
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .loaded(let nights):
                historyContent(nights)
            }
        }
        .background(AppTheme.background)
        .navigationTitle("Sleep")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await vm.refreshHistory() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .task { await vm.loadHistoryIfNeeded() }
        .navigationDestination(item: $vm.selectedNight) { night in
            NightDetailView(vm: vm, night: night)
                .task { await vm.loadNightDetail(night) }
        }
    }

    private func historyContent(_ nights: [HealthKitSleep]) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                trendChart(nights)
                VStack(alignment: .leading, spacing: 10) {
                    Text("Nights")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(AppTheme.textSecondary)
                    VStack(spacing: 8) {
                        ForEach(nights) { night in
                            Button { vm.selectedNight = night } label: {
                                nightRow(night)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, AppTheme.paddingHorizontal)
            .padding(.vertical)
        }
        .refreshable { await vm.refreshHistory() }
    }

    private func trendChart(_ nights: [HealthKitSleep]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Last 7 nights", systemImage: "chart.bar.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(AppTheme.textSecondary)
            Chart(nights.sorted { $0.startDate < $1.startDate }) { night in
                BarMark(
                    x: .value("Date", night.startDate, unit: .day),
                    y: .value("Hours", night.asleepSeconds / 3600)
                )
                .foregroundStyle(AppTheme.accent.opacity(0.8))
                .cornerRadius(4)
            }
            .chartXAxis { AxisMarks(values: .stride(by: .day)) }
            .frame(height: 140)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.cornerRadiusMedium)
    }

    private func nightRow(_ night: HealthKitSleep) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(night.startDate, format: .dateTime.weekday().month().day())
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppTheme.textPrimary)
                if let efficiency = night.efficiency {
                    Text("\(Int(efficiency))% efficiency")
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
            Spacer()
            HStack(spacing: 8) {
                if let hr = night.heartRateAvg {
                    Label(String(format: "%.0f bpm", hr), systemImage: "heart.fill")
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                }
                Text(String(format: "%.1fh", night.asleepSeconds / 3600))
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.cornerRadiusMedium)
    }
}

private struct NightDetailView: View {
    @Bindable var vm: SleepViewModel
    let night: HealthKitSleep

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                metricsCard
                if !vm.timeline.isEmpty {
                    timelineChart
                }
                heartRateChart
                stageProportions
                comparisonChart
            }
            .padding(.horizontal, AppTheme.paddingHorizontal)
            .padding(.vertical)
        }
        .background(AppTheme.background)
        .navigationTitle(
            Text(night.startDate, format: .dateTime.weekday().month().day())
        )
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { vm.clearSelection() }
    }

    private var metricsCard: some View {
        HStack(spacing: 12) {
            metric("bed.double.fill", String(format: "%.1fh", night.asleepSeconds / 3600), "asleep")
            metric("moon", String(format: "%.1fh", night.timeInBedSeconds / 3600), "in bed")
            metric("heart.fill", night.heartRateAvg.map { String(format: "%.0f", $0) } ?? "–", "bpm")
            metric("gauge.with.dots.needle.50percent", night.efficiency.map { "\(Int($0))%" } ?? "–", "efficiency")
        }
        .padding()
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.cornerRadiusMedium)
    }

    private var timelineChart: some View {
        chartCard("Sleep stages", "chart.bar.xaxis") {
            Chart(Array(vm.timeline.enumerated()), id: \.element.id) { index, segment in
                BarMark(
                    xStart: .value("Start", segment.startDate),
                    xEnd: .value("End", segment.endDate),
                    y: .value("Row", index)
                )
                .foregroundStyle(color(for: segment.stage))
            }
            .chartYScale(domain: [-1, vm.timeline.count])
            .frame(height: max(80, CGFloat(vm.timeline.count) * 14))
        }
    }

    private var heartRateChart: some View {
        chartCard(
            "Heart rate during sleep",
            "heart.fill"
        ) {
            if vm.sleepHeartRatePoints.isEmpty {

                ContentUnavailableView(
                    "No heart rate data",
                    systemImage: "heart.slash"
                )
                .frame(height: 180)

            } else {

                Chart(vm.sleepHeartRatePoints) { point in

                    LineMark(
                        x: .value(
                            "Time",
                            point.date
                        ),
                        y: .value(
                            "BPM",
                            point.bpm
                        )
                    )
                }
                .chartXAxis {
                    AxisMarks(
                        values: .stride(by: .hour)
                    ) {
                        AxisGridLine()

                        AxisValueLabel(
                            format: .dateTime.hour()
                        )
                    }
                }
                .frame(height: 180)
            }
        }
    }
    
    private var stageProportions: some View {
        let items = [
            (SleepStage.core, night.coreSeconds),
            (SleepStage.deep, night.deepSeconds),
            (SleepStage.rem, night.remSeconds),
            (SleepStage.unspecified, night.unspecifiedSeconds),
            (SleepStage.awake, night.awakeSeconds)
        ].filter { $0.1 > 0 }

        return chartCard("Stage proportions", "chart.pie.fill") {
            Chart(items, id: \.0) { stage, seconds in
                SectorMark(
                    angle: .value("Seconds", seconds),
                    innerRadius: .ratio(0.62),
                    angularInset: 2
                )
                .foregroundStyle(color(for: stage))
                .cornerRadius(4)
            }
            .frame(height: 180)
        }
    }

    @ViewBuilder
    private var comparisonChart: some View {
        if let bars = comparisonBars() {
            chartCard("This night vs average", "chart.bar.doc.horizontal", showStagesLegend: false) {
                Chart(bars) { bar in
                    BarMark(
                        x: .value("Metric", bar.label),
                        y: .value("Hours", bar.hours)
                    )
                    .foregroundStyle(seriesColor(for: bar.series))
                    .position(by: .value("Series", bar.series))
                }
                .frame(height: 160)
                HStack(spacing: 8) {
                    legendItem("This night", AppTheme.accent)
                    legendItem("avg (\(avgNightCount))", AppTheme.textSecondary.opacity(0.6))
                }
            }
        } else {
            chartCard("This night vs average", "chart.bar.doc.horizontal", showStagesLegend: false) {
                Text("Need at least 2 other nights to compare")
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
            }
        }
    }

    private var avgNightCount: Int {
        max(0, vm.history.filter { $0.id != night.id }.count)
    }

    private func seriesColor(for series: String) -> Color {
        series == "This night" ? AppTheme.accent : AppTheme.textSecondary.opacity(0.6)
    }

    private func comparisonBars() -> [ComparisonBar]? {
        let others = vm.history.filter { $0.id != night.id }
        guard others.count >= 2 else { return nil }

        let avgSeries = "avg (\(others.count))"
        let avg: [String: Double] = ["asleep", "deep", "rem", "awake"].reduce(into: [:]) { dict, key in
            dict[key] = others.reduce(0.0) { $0 + Self.seconds(for: key, in: $1) } / Double(others.count)
        }

        return [
            ComparisonBar(label: "Asleep", series: "This night", hours: night.asleepSeconds / 3600),
            ComparisonBar(label: "Asleep", series: avgSeries, hours: (avg["asleep"] ?? 0) / 3600),
            ComparisonBar(label: "Deep", series: "This night", hours: night.deepSeconds / 3600),
            ComparisonBar(label: "Deep", series: avgSeries, hours: (avg["deep"] ?? 0) / 3600),
            ComparisonBar(label: "REM", series: "This night", hours: night.remSeconds / 3600),
            ComparisonBar(label: "REM", series: avgSeries, hours: (avg["rem"] ?? 0) / 3600),
            ComparisonBar(label: "Awake", series: "This night", hours: night.awakeSeconds / 3600),
            ComparisonBar(label: "Awake", series: avgSeries, hours: (avg["awake"] ?? 0) / 3600)
        ]
    }

    private static func seconds(for key: String, in sleep: HealthKitSleep) -> Double {
        switch key {
        case "asleep": return sleep.asleepSeconds
        case "deep": return sleep.deepSeconds
        case "rem": return sleep.remSeconds
        case "awake": return sleep.awakeSeconds
        default: return 0
        }
    }

    private func chartCard(
        _ title: String,
        _ icon: String,
        showStagesLegend: Bool = true,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(AppTheme.textSecondary)
            content()
            if showStagesLegend {
                HStack(spacing: 8) {
                    legendItem("Core", color(for: .core))
                    legendItem("Deep", color(for: .deep))
                    legendItem("REM", color(for: .rem))
                    legendItem("Awake", color(for: .awake))
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.cornerRadiusMedium)
    }

    private func legendItem(_ text: String, _ color: Color) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(text)
                .font(.caption2)
                .foregroundColor(AppTheme.textSecondary)
        }
    }
}

private func metric(_ icon: String, _ value: String, _ unit: String) -> some View {
    VStack(spacing: 6) {
        Image(systemName: icon).foregroundColor(AppTheme.accent)
        Text(value).font(.subheadline.bold()).foregroundColor(AppTheme.textPrimary)
        Text(unit).font(.caption2).foregroundColor(AppTheme.textSecondary)
    }
    .frame(maxWidth: .infinity)
}

private func color(for stage: SleepStage) -> Color {
    switch stage {
    case .inBed: return AppTheme.textSecondary.opacity(0.4)
    case .awake: return .orange.opacity(0.7)
    case .core: return AppTheme.accent.opacity(0.45)
    case .deep: return AppTheme.accent.opacity(0.8)
    case .rem: return AppTheme.accent
    case .unspecified: return AppTheme.textSecondary.opacity(0.5)
    }
}

struct ComparisonBar: Identifiable {
    let label: String
    let series: String
    let hours: Double
    var id: String { label + series }
}


#Preview {
    let vm = SleepViewModel(
        healthKitService: MockSleepHealthKit(),
        sleepService: MockSleepService()
    )
    Task { @MainActor in await vm.loadHistoryIfNeeded() }
    return NavigationStack {
        SleepHistoryView(vm: vm)
    }
    .preferredColorScheme(.dark)
}
