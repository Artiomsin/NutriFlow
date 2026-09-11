//
//  WorkoutHistoryView.swift
//  Nutriflow
//
//  Created by Artem on 05.09.2026.
//

import SwiftUI
import UIKit
import Charts

struct WorkoutHistoryView: View {
    @Bindable var vm: WorkoutViewModel

    var body: some View {
        VStack(spacing: 0) {
            switch vm.state {
            case .idle:
                ProgressView()
                    .tint(AppTheme.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .loading:
                ProgressView()
                    .tint(AppTheme.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .error:
                errorView
            case .loaded(let workouts):
                if workouts.isEmpty {
                    emptyView
                } else {
                    workoutsList(workouts)
                }
            case .needsAccess:
                needsAccessView
            case .denied:
                deniedView
            }
        }
        .navigationTitle("Workouts")
        .navigationBarTitleDisplayMode(.inline)
        .background(AppTheme.background)
        .task {
            print("[WorkoutView] view appeared")
            await vm.onAppear()
        }
        .refreshable { await vm.refresh() }
        .navigationDestination(item: $vm.selectedWorkout) { workout in
            WorkoutDetailView(
                workout: workout,
                heartRatePoints: vm.heartRatePoints,
                series: vm.currentSeries()
            )
            .task {
                await vm.loadHeartRate(for: workout)
                await vm.loadSeries(for: workout)
                print(
                    "[WorkoutDetail] passed in: " +
                    "hrPoints=\(vm.heartRatePoints.count) " +
                    "series=\(vm.currentSeries().count)"
                )
            }
        }
        .onChange(of: vm.selectedWorkout) { _, newValue in
            if newValue != nil {
                vm.heartRatePoints = []
                vm.clearSeries()
            }
        }
    }

    private var errorView: some View {
        VStack(spacing: 12) {
            Image(systemName: "wrench.and.screwdriver")
                .font(Font.largeNumber)
                .foregroundColor(AppTheme.textSecondary)
            Text("Couldn't load workouts")
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)
            Button("Try Again") {
                Task { await vm.refresh() }
            }
            .font(.headline)
            .foregroundColor(AppTheme.accent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var needsAccessView: some View {
            VStack(spacing: 12) {
                Image(systemName: "figure.run")
                    .font(Font.largeNumber)
                    .foregroundColor(AppTheme.accent)
                Text("Track your workouts")
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)
                Text("Connect Apple Health to see your training history.")
                    .font(.footnote)
                    .foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                Button {
                    Task { await vm.connectTapped() }
                } label: {
                    Text("Connect Health")
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppTheme.accent)
                        .cornerRadius(AppTheme.cornerRadiusMedium)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        }

    private var deniedView: some View {
            VStack(spacing: 12) {
                Image(systemName: "heart.slash")
                    .font(Font.largeNumber)
                    .foregroundColor(AppTheme.textSecondary)
                Text("Workouts access is off")
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)
                Text("Enable Workouts in Settings to see your training history.")
                    .font(.footnote)
                    .foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                Button {
                    openSettings()
                } label: {
                    Text("Open Settings")
                        .font(.headline)
                        .foregroundColor(AppTheme.accent)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppTheme.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                                .stroke(AppTheme.accent, lineWidth: 1.5)
                        )
                }
                Button {
                    Task { await vm.onAppear() }
                } label: {
                    Text("Try Again")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        }
    
    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.run")
                .font(Font.largeNumber)
                .foregroundColor(AppTheme.textSecondary)
            Text("No workouts yet")
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)
            Text("Your workouts from Apple Health will appear here.")
                .font(.footnote)
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func workoutsList(_ workouts: [HealthKitWorkout]) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                ForEach(workouts) { workout in
                    Button {
                        print(
                            "[WorkoutHistory] open detail: id=\(workout.id) " +
                            "type=\(workout.workoutType) start=\(workout.startDate) " +
                            "duration=\(workout.durationSeconds) " +
                            "cal=\(workout.caloriesBurned.map { "\($0)" } ?? "nil") " +
                            "dist=\(workout.distanceMeters.map { "\($0)" } ?? "nil") " +
                            "hrAvg=\(workout.heartRateAvg.map { "\($0)" } ?? "nil") " +
                            "hrMax=\(workout.heartRateMax.map { "\($0)" } ?? "nil") " +
                            "avgSpeed=\(workout.avgSpeedMps.map { "\($0)" } ?? "nil") " +
                            "maxSpeed=\(workout.maxSpeedMps.map { "\($0)" } ?? "nil") " +
                            "avgCadence=\(workout.avgCadence.map { "\($0)" } ?? "nil") " +
                            "maxCadence=\(workout.maxCadence.map { "\($0)" } ?? "nil") " +
                            "avgPower=\(workout.avgPowerWatts.map { "\($0)" } ?? "nil") " +
                            "maxPower=\(workout.maxPowerWatts.map { "\($0)" } ?? "nil") " +
                            "elevation=\(workout.elevationGainMeters.map { "\($0)" } ?? "nil") " +
                            "steps=\(workout.steps.map { "\($0)" } ?? "nil") " +
                            "indoor=\(workout.indoor.map { "\($0)" } ?? "nil") " +
                            "details=\(String(describing: workout.details))"
                        )
                        vm.selectedWorkout = workout
                    } label: {
                        WorkoutRow(
                            workout: workout,
                            heartRatePoints: vm.sparklineHR[workout.id] ?? []
                        )
                    }
                    .buttonStyle(.plain)
                    .task(id: workout.id) {
                        await vm.loadSparkline(for: workout)
                    }
                }

                if vm.loadMoreError {
                    Button {
                        vm.loadMore()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise")
                            Text("Failed to load. Retry")
                        }
                        .font(.subheadline)
                        .foregroundColor(AppTheme.accent)
                        .padding(.vertical, 16)
                    }
                } else if vm.hasMore || vm.isLoadMore {
                    ProgressView()
                        .tint(AppTheme.accent)
                        .padding(.vertical, 20)
                }
            }
            .padding(.horizontal, AppTheme.paddingHorizontal)
            .padding(.vertical)
        }
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentSize.height - geometry.containerSize.height - geometry.contentOffset.y
        } action: { _, remaining in
            if remaining < 200 {
                vm.loadMore()
            }
        }
    }
}


    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

private struct WorkoutRow: View {
    let workout: HealthKitWorkout
    let heartRatePoints: [HeartRatePoint]

    private var bars: [HeartRateBar] {
        WorkoutFormatter.minuteBars(points: heartRatePoints)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: WorkoutFormatter.icon(for: workout.workoutType))
                .font(.title3)
                .foregroundColor(AppTheme.accent)
                .frame(width: 44, height: 44)
                .background(AppTheme.accent.opacity(0.12))
                .cornerRadius(AppTheme.cornerRadiusMedium)

            VStack(alignment: .leading, spacing: 4) {
                Text(workout.workoutType)
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)
                Text(WorkoutFormatter.formattedDate(workout.startDate))
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(WorkoutFormatter.formattedDuration(workout.durationSeconds))
                    .font(.footnote)
                    .foregroundColor(AppTheme.textPrimary)
                if let kcal = workout.caloriesBurned {
                    Text("\(Int(kcal)) kcal")
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                }
            }

            if !bars.isEmpty {
                SparklineChart(bars: bars)
                    .frame(width: 56, height: 24)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.cornerRadiusMedium)
    }
}

private struct SparklineChart: View {
    let bars: [HeartRateBar]

    var body: some View {
        Chart(bars) { bar in
            BarMark(
                x: .value("Time", bar.date, unit: .minute),
                y: .value("BPM", bar.bpm)
            )
            .foregroundStyle(AppTheme.accent.gradient)
            .cornerRadius(1.5)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
    }
}

#Preview {
    let vm = WorkoutViewModel(
        healthKit: MockHealthKit(),
        workoutService: MockWorkoutService()
    )

    func makeWorkout(
        type: String,
        startOffset: TimeInterval,
        duration: TimeInterval,
        calories: Double,
        distance: Double?,
        baseBPM: Double
    ) -> (HealthKitWorkout, [HeartRatePoint]) {
        let start = Date().addingTimeInterval(startOffset)
        let workout = HealthKitWorkout(
            id: UUID(),
            workoutType: type,
            startDate: start,
            endDate: start.addingTimeInterval(duration),
            durationSeconds: duration,
            caloriesBurned: calories,
            distanceMeters: distance,
            heartRateAvg: baseBPM + 12,
            heartRateMax: baseBPM + 32,
            heartRateMin: baseBPM - 12
        )
        return (workout, sampleHeartRate(from: start, to: start.addingTimeInterval(duration), base: baseBPM))
    }

    let entries: [(HealthKitWorkout, [HeartRatePoint])] = [
        makeWorkout(type: "Running", startOffset: -2520, duration: 2520, calories: 386, distance: 5200, baseBPM: 132),
        makeWorkout(type: "Cycling", startOffset: -86400, duration: 3600, calories: 512, distance: 15000, baseBPM: 118),
        makeWorkout(type: "Swimming", startOffset: -79200, duration: 2400, calories: 380, distance: 1500, baseBPM: 124),
        makeWorkout(type: "HIIT", startOffset: -172800, duration: 1200, calories: 290, distance: nil, baseBPM: 148),
        makeWorkout(type: "Strength Training", startOffset: -259200, duration: 2700, calories: 240, distance: nil, baseBPM: 108),
        makeWorkout(type: "Yoga", startOffset: -345600, duration: 1800, calories: 120, distance: nil, baseBPM: 92)
    ]

    vm.state = .loaded(entries.map { $0.0 })
    for (workout, points) in entries {
        vm.sparklineHR[workout.id] = points
    }

    return NavigationStack {
        WorkoutHistoryView(vm: vm)
    }
    .preferredColorScheme(.dark)
}

private func sampleHeartRate(from start: Date, to end: Date, base: Double) -> [HeartRatePoint] {
    var result: [HeartRatePoint] = []
    var index = 0
    var date = start
    while date <= end {
        let bpm = base + Double((index * 7) % 40) + Double.random(in: -3...3)
        result.append(HeartRatePoint(startDate: date, bpm: bpm))
        date = date.addingTimeInterval(60)
        index += 1
    }
    return result
}
