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

    private var isCardio: Bool {
        WorkoutFormatter.icon(for: workout.workoutType) != "dumbbell.fill"
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                summaryCard
                heartRateCard
            }
            .padding(AppTheme.paddingHorizontal)
            .padding(.vertical)
        }
        .background(AppTheme.background)
        .navigationTitle(workout.workoutType)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(WorkoutFormatter.formattedDate(workout.startDate), systemImage: "calendar")
                .font(.subheadline)
                .foregroundColor(AppTheme.textSecondary)

            HStack {
                stat(value: WorkoutFormatter.formattedDuration(workout.durationSeconds), label: "Duration")
                stat(value: formattedDistance, label: "Distance")
                stat(value: "\(Int(workout.caloriesBurned ?? 0))", label: "kcal")
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.cornerRadiusMedium)
    }

    private func stat(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)
            Text(label)
                .font(.caption)
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var formattedDistance: String {
        guard let meters = workout.distanceMeters else { return "--" }
        return String(format: "%.2f km", meters / 1000)
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
                .font(.headline)
                .monospacedDigit()
                .foregroundColor(AppTheme.textPrimary)
            Text(label)
                .font(.caption)
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
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
}

#Preview {
    let workout = HealthKitWorkout(
        id: UUID(),
        workoutType: "Running",
        startDate: Date().addingTimeInterval(-2520),
        endDate: Date(),
        durationSeconds: 2520,
        caloriesBurned: 386,
        distanceMeters: 5200,
        heartRateAvg: 142,
        heartRateMax: 168,
        heartRateMin: 115
    )

    let points: [HeartRatePoint] = {
        var result: [HeartRatePoint] = []
        for minute in 0...(2520 / 60) {
            let bpmAtMinute = 115.0 + Double((minute * 7) % 40)
            let bpm = bpmAtMinute + Double.random(in: -3...3)
            result.append(
                HeartRatePoint(
                    startDate: Date().addingTimeInterval(-2520 + Double(minute * 60)),
                    bpm: bpm
                )
            )
        }
        return result
    }()

    return NavigationStack {
        WorkoutDetailView(workout: workout, heartRatePoints: points)
    }
    .preferredColorScheme(.dark)
}
