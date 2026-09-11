//
//  WorkoutDetailView.swift
//  Nutriflow
//
//  Created by Artem on 07.09.2026.
//

import SwiftUI
import Charts

struct WorkoutDetailView: View {
    let workout: HealthKitWorkout
    let heartRatePoints: [HeartRatePoint]
    var series: [WorkoutSeries] = []

    private var isCardio: Bool {
        WorkoutFormatter.icon(for: workout.workoutType) != "dumbbell.fill"
    }

    private var isRunLike: Bool {
        ["Running", "Walking", "Hiking"].contains(workout.workoutType)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                summaryCard
                heartRateCard
                metricsCard
                chartsCard
            }
            .padding(AppTheme.paddingHorizontal)
            .padding(.vertical)
        }
        .background(AppTheme.background)
        .navigationTitle(workout.workoutType)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var metricsCard: some View {
        let tiles = metricTiles

        if !tiles.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                Label("Metrics", systemImage: "gauge")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppTheme.textSecondary)
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ],
                    spacing: 12
                ) {
                    ForEach(tiles, id: \.label) { tile in
                        metricTile(value: tile.value, label: tile.label)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.cardBackground)
            .cornerRadius(AppTheme.cornerRadiusMedium)
        }
    }

    private var metricTiles: [(value: String, label: String)] {
        var raw: [(value: String?, label: String)] = []
        if isRunLike {
            raw.append((paceString, "Pace"))
        } else {
            raw.append((speedKmh, "Avg Speed"))
        }
        raw.append((maxSpeedKmh, "Max Speed"))
        raw.append((cadenceString, "Cadence"))
        raw.append((avgPowerString, "Avg Power"))
        raw.append((maxPowerString, "Max Power"))
        raw.append((elevationString, "Elevation"))
        raw.append((stepsString, "Steps"))
        raw.append((detailsStroke, "Stroke"))
        raw.append((detailsWater, "Water"))
        raw.append((detailsLapLength, "Pool Length"))
        raw.append((indoorString, "Indoor"))
        raw.append((detailsSwolf, "SWOLF"))
        raw.append((detailsAscended, "Elev. Up"))
        raw.append((detailsDescended, "Elev. Down"))
        raw.append((detailsMETs, "Avg METs"))

        return raw.compactMap { entry -> (value: String, label: String)? in
            guard let value = entry.value else { return nil }
            return (value, entry.label)
        }
    }

    private var paceString: String? {
        guard let mps = workout.avgSpeedMps, mps > 0 else { return nil }
        let minutesPerKm = 1000.0 / mps / 60.0
        let minutes = Int(minutesPerKm)
        let seconds = Int((minutesPerKm - Double(minutes)) * 60)
        return String(format: "%d:%02d /km", minutes, seconds)
    }

    private var speedKmh: String? {
        workout.avgSpeedMps.map { String(format: "%.1f km/h", $0 * 3.6) }
    }

    private var maxSpeedKmh: String? {
        workout.maxSpeedMps.map { String(format: "%.1f km/h", $0 * 3.6) }
    }

    private var cadenceString: String? {
        workout.avgCadence.map { "\(Int($0))/min" }
    }

    private var avgPowerString: String? {
        workout.avgPowerWatts.map { "\(Int($0)) W" }
    }

    private var maxPowerString: String? {
        workout.maxPowerWatts.map { "\(Int($0)) W" }
    }

    private var elevationString: String? {
        workout.elevationGainMeters.map { "\(Int($0)) m" }
    }

    private var stepsString: String? {
        workout.steps.map { "\($0)" }
    }

    private var detailsStroke: String? {
        workout.details?.stroke
    }

    private var detailsWater: String? {
        switch workout.details?.water {
        case "pool": return "Pool"
        case "openWater": return "Open Water"
        case .some(let value): return value
        case .none: return nil
        }
    }

    private var detailsLapLength: String? {
        workout.details?.lapLengthMeters.map { "\(Int($0)) m" }
    }

    private var indoorString: String? {
        guard let indoor = workout.indoor else { return nil }
        return indoor ? "Yes" : "No"
    }

    private var detailsSwolf: String? {
        workout.details?.swolf.map { "\(Int($0))" }
    }

    private var detailsAscended: String? {
        workout.details?.elevationAscended.map { "\(Int($0)) m" }
    }

    private var detailsDescended: String? {
        workout.details?.elevationDescended.map { "\(Int($0)) m" }
    }

    private var detailsMETs: String? {
        workout.details?.avgMETs.map { String(format: "%.1f", $0) }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(WorkoutFormatter.formattedDate(workout.startDate), systemImage: "calendar")
                .font(.subheadline)
                .foregroundColor(AppTheme.textSecondary)

            HStack {
                stat(value: WorkoutFormatter.formattedDuration(workout.durationSeconds), label: "Duration")
                if let meters = workout.distanceMeters {
                    stat(value: String(format: "%.2f km", meters / 1000), label: "Distance")
                }
                if let kcal = workout.caloriesBurned, kcal > 0 {
                    stat(value: "\(Int(kcal))", label: "kcal")
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.cornerRadiusMedium)
    }

    private func stat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.title3.bold())
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundColor(AppTheme.textPrimary)
            Text(label.uppercased())
                .font(.caption2.weight(.medium))
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var derivedHR: (min: Double, avg: Double, max: Double)? {
        let values = heartRatePoints.map(\.bpm)
        guard let min = values.min(), let max = values.max(), !values.isEmpty else { return nil }
        let avg = values.reduce(0, +) / Double(values.count)
        return (min, avg, max)
    }

    private var effectiveMin: Double? { workout.heartRateMin ?? derivedHR?.min }
    private var effectiveAvg: Double? { workout.heartRateAvg ?? derivedHR?.avg }
    private var effectiveMax: Double? { workout.heartRateMax ?? derivedHR?.max }

    @ViewBuilder
    private var heartRateCard: some View {
        let min = effectiveMin
        let avg = effectiveAvg
        let max = effectiveMax

        if !heartRatePoints.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                hslCard(min: min, avg: avg, max: max)
                chart
                if avg != nil {
                    zones
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.cardBackground)
            .cornerRadius(AppTheme.cornerRadiusMedium)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("Heart Rate")
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)
                Text("No heart rate data for this workout.")
                    .font(.footnote)
                    .foregroundColor(AppTheme.textSecondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.cardBackground)
            .cornerRadius(AppTheme.cornerRadiusMedium)
        }
    }

    private func hslCard(min: Double?, avg: Double?, max: Double?) -> some View {
        HStack {
            miniStat(value: min.map { "\(Int($0))" } ?? "--", label: "Min")
            miniStat(value: avg.map { "\(Int($0))" } ?? "--", label: "Avg")
            miniStat(value: max.map { "\(Int($0))" } ?? "--", label: "Max")
        }
    }

    private func miniStat(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.bold())
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundColor(AppTheme.textPrimary)
            Text(label.uppercased())
                .font(.caption2.weight(.medium))
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metricTile(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(.headline)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundColor(AppTheme.textPrimary)
            Text(label.uppercased())
                .font(.caption2.weight(.medium))
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppTheme.accent.opacity(0.07))
        .cornerRadius(AppTheme.cornerRadiusSmall)
    }

    private var chart: some View {
        Chart(heartRatePoints) { point in
            LineMark(
                x: .value("Time", point.startDate),
                y: .value("BPM", point.bpm)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(AppTheme.accent.opacity(0.35))
            .lineStyle(StrokeStyle(lineWidth: 1.5))

            PointMark(
                x: .value("Time", point.startDate),
                y: .value("BPM", point.bpm)
            )
            .foregroundStyle(AppTheme.accent)
            .symbolSize(26)
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .frame(height: 160)
    }

    private var zones: some View {
        let avg = effectiveAvg ?? 100
        let maxZone = (effectiveMax ?? avg) * 0.9

        return HStack {
            zoneChip(label: "BASE", ok: avg < maxZone * 0.76)
            zoneChip(label: "BURN", ok: avg >= maxZone * 0.76 && avg < maxZone)
            zoneChip(label: "PEAK", ok: avg >= maxZone)
        }
    }

    private func zoneChip(label: String, ok: Bool) -> some View {
        Text(label)
            .font(.caption.bold())
            .foregroundColor(ok ? AppTheme.accent : AppTheme.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(ok ? AppTheme.accent.opacity(0.12) : AppTheme.cardBackground)
            .cornerRadius(8)
    }

    @ViewBuilder
    private var chartsCard: some View {
        let available = series.filter { !$0.points.isEmpty }

        if !available.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                Label("Charts", systemImage: "chart.xyaxis.line")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppTheme.textSecondary)
                ForEach(available, id: \.kind) { item in
                    seriesChart(item)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.cardBackground)
            .cornerRadius(AppTheme.cornerRadiusMedium)
        }
    }

    private func seriesChart(_ item: WorkoutSeries) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(seriesTitle(item.kind))
                .font(.caption.weight(.semibold))
                .foregroundColor(AppTheme.textPrimary)
            Chart(item.points) { point in
                LineMark(
                    x: .value("Time", point.date),
                    y: .value("Value", displayValue(point.value, kind: item.kind))
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(AppTheme.accent.opacity(0.6))
                .lineStyle(StrokeStyle(lineWidth: 1.5))
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .frame(height: 120)
        }
    }

    private func seriesTitle(_ kind: WorkoutSeriesKind) -> String {
        switch kind {
        case .speed: return "Speed (km/h)"
        case .cadence: return "Cadence (/min)"
        case .power: return "Power (W)"
        }
    }

    private func displayValue(_ value: Double, kind: WorkoutSeriesKind) -> Double {
        switch kind {
        case .speed: return value * 3.6
        case .cadence, .power: return value
        }
    }
}

private func previewHRPoints(from startDate: Date, to endDate: Date) -> [HeartRatePoint] {
    var result: [HeartRatePoint] = []
    var minute = 0
    for date in stride(from: startDate, through: endDate, by: 60) {
        let bpm = 115.0 + Double((minute * 7) % 40) + Double.random(in: -3...3)
        result.append(HeartRatePoint(startDate: date, bpm: bpm))
        minute += 1
    }
    return result
}

private func previewSeries(from startDate: Date, spec: [(WorkoutSeriesKind, Double, Double)], by: TimeInterval = 60) -> [WorkoutSeries] {
    spec.map { kind, base, amplitude in
        let items = stride(from: startDate, through: Date(), by: by).enumerated().map { index, date in
            WorkoutSeriesPoint(
                date: date,
                value: base + sin(Double(index) * 0.35) * amplitude
            )
        }
        return WorkoutSeries(kind: kind, points: items)
    }
}

private func previewWorkout(
    type: String,
    startOffset: TimeInterval = -2520,
    duration: TimeInterval = 2520,
    calories: Double = 386,
    distance: Double? = 5200,
    hrMin: Double? = 115,
    hrAvg: Double? = 142,
    hrMax: Double? = 168,
    avgSpeed: Double? = nil,
    maxSpeed: Double? = nil,
    avgCadence: Double? = nil,
    maxCadence: Double? = nil,
    avgPower: Double? = nil,
    maxPower: Double? = nil,
    elevation: Double? = nil,
    steps: Int? = nil,
    indoor: Bool? = nil,
    details: WorkoutDetails? = nil
) -> HealthKitWorkout {
    HealthKitWorkout(
        id: UUID(),
        workoutType: type,
        startDate: Date().addingTimeInterval(startOffset),
        endDate: Date(),
        durationSeconds: duration,
        caloriesBurned: calories,
        distanceMeters: distance,
        heartRateAvg: hrAvg,
        heartRateMax: hrMax,
        heartRateMin: hrMin,
        avgSpeedMps: avgSpeed,
        maxSpeedMps: maxSpeed,
        avgCadence: avgCadence,
        maxCadence: maxCadence,
        avgPowerWatts: avgPower,
        maxPowerWatts: maxPower,
        elevationGainMeters: elevation,
        steps: steps,
        indoor: indoor,
        details: details
    )
}

#Preview("Running") {
    let workout = previewWorkout(
        type: "Running",
        avgSpeed: 2.06, maxSpeed: 3.1,
        avgCadence: 172, maxCadence: 188,
        avgPower: 205, maxPower: 260,
        elevation: 85,
        steps: 8400,
        indoor: false,
        details: WorkoutDetails(elevationAscended: 85, elevationDescended: 80, avgMETs: 9)
    )
    let series = previewSeries(from: workout.startDate, spec: [
        (.speed, 2.0, 0.35),
        (.cadence, 170, 6),
        (.power, 200, 22)
    ])

    return NavigationStack {
        WorkoutDetailView(workout: workout, heartRatePoints: previewHRPoints(from: workout.startDate, to: workout.endDate), series: series)
    }
    .preferredColorScheme(.dark)
}

#Preview("All Types") {
    TabView {
        let running = previewWorkout(
            type: "Running",
            avgSpeed: 2.06, maxSpeed: 3.1,
            avgCadence: 172, maxCadence: 188,
            avgPower: 205, maxPower: 260,
            elevation: 85,
            steps: 8400,
            indoor: false,
            details: WorkoutDetails(elevationAscended: 85, elevationDescended: 80, avgMETs: 9)
        )
        NavigationStack {
            WorkoutDetailView(
                workout: running,
                heartRatePoints: previewHRPoints(from: running.startDate, to: running.endDate),
                series: previewSeries(from: running.startDate, spec: [
                    (.speed, 2.0, 0.35), (.cadence, 170, 6), (.power, 200, 22)
                ])
            )
        }
        .tabItem { Label("Running", systemImage: "figure.run") }

        let cycling = previewWorkout(
            type: "Cycling",
            startOffset: -7200, duration: 7200,
            calories: 640, distance: 26000,
            avgSpeed: 8.3, maxSpeed: 12.5,
            avgCadence: 88, maxCadence: 96,
            avgPower: 190, maxPower: 320,
            elevation: 320,
            steps: 4200,
            indoor: false,
            details: WorkoutDetails(elevationAscended: 320, elevationDescended: 290, avgMETs: 8.5)
        )
        NavigationStack {
            WorkoutDetailView(
                workout: cycling,
                heartRatePoints: previewHRPoints(from: cycling.startDate, to: cycling.endDate),
                series: previewSeries(from: cycling.startDate, spec: [
                    (.speed, 8.2, 1.2), (.cadence, 88, 4), (.power, 190, 45)
                ])
            )
        }
        .tabItem { Label("Cycling", systemImage: "figure.outdoor.cycle") }

        let swimming = previewWorkout(
            type: "Swimming",
            startOffset: -3600, duration: 3600,
            calories: 520, distance: 1500,
            avgSpeed: 0.85, maxSpeed: 1.1,
            indoor: false,
            details: WorkoutDetails(
                stroke: "Freestyle",
                water: "pool",
                lapLengthMeters: 25,
                swolf: 42,
                avgMETs: 8
            )
        )
        NavigationStack {
            WorkoutDetailView(
                workout: swimming,
                heartRatePoints: previewHRPoints(from: swimming.startDate, to: swimming.endDate),
                series: previewSeries(from: swimming.startDate, spec: [(.speed, 0.85, 0.08)])
            )
        }
        .tabItem { Label("Swimming", systemImage: "figure.pool.swim") }

        let strength = previewWorkout(
            type: "Strength Training",
            startOffset: -1800, duration: 1800,
            calories: 220, distance: nil,
            hrMin: 120, hrAvg: 135, hrMax: 148
        )
        NavigationStack {
            WorkoutDetailView(
                workout: strength,
                heartRatePoints: previewHRPoints(from: strength.startDate, to: strength.endDate),
                series: []
            )
        }
        .tabItem { Label("Strength", systemImage: "dumbbell.fill") }
    }
    .preferredColorScheme(.dark)
}
