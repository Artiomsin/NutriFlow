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
    @Bindable var vm: WorkoutHistoryViewModel

    var body: some View {
        VStack(spacing: 0) {
            if vm.activeWorkoutVM.phase != .idle {
                activeWorkoutCard
                    .padding(.horizontal, AppTheme.paddingHorizontal)
                    .padding(.vertical, 12)
            }

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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingStart = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingStart) {
            WorkoutStartView(vm: vm.activeWorkoutVM) { trackable in
                showingStart = false
                vm.activeWorkoutVM.start(kind: trackable.kind)
            }
        }
.navigationDestination(item: $vm.selectedWorkout) { workout in
            WorkoutDetailView(
                workout: workout,
                heartRatePoints: vm.heartRatePoints,
                series: vm.currentSeries()
            )
            .task {
                await vm.loadHeartRate(for: workout)
                await vm.loadSeries(for: workout)
            }
        }
        .onChange(of: vm.selectedWorkout) { _, newValue in
            if newValue != nil {
                vm.heartRatePoints = []
                vm.clearSeries()
            }
        }
    }

    @State private var showingStart = false
    @State private var showEndConfirm = false

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
                    vm.markAccessDenied()
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
                    vm.clearAccessDenied()
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

    private var activeWorkoutCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: WorkoutFormatter.icon(for: vm.activeWorkoutVM.kind.title))
                    .font(.title3)
                    .foregroundColor(AppTheme.accent)
                    .frame(width: 44, height: 44)
                    .background(AppTheme.accent.opacity(0.12))
                    .cornerRadius(AppTheme.cornerRadiusMedium)

                VStack(alignment: .leading, spacing: 2) {
                    Text(vm.activeWorkoutVM.kind.title)
                        .font(.headline)
                        .foregroundColor(AppTheme.textPrimary)
                    Text(liveElapsed)
                        .font(.title2.bold())
                        .monospacedDigit()
                        .foregroundColor(AppTheme.textPrimary)
                }

                Spacer()

                Image(systemName: vm.activeWorkoutVM.phase == .running ? "heart.fill" : "pause.fill")
                    .font(.title3)
                    .foregroundColor(AppTheme.accent)
                    .symbolEffect(.pulse, options: .repeating, isActive: vm.activeWorkoutVM.phase == .running)
            }

            HStack(spacing: 24) {
                liveMetric(value: "\(Int(vm.activeWorkoutVM.metrics.activeCalories))", unit: "kcal", icon: "flame.fill")
                liveMetric(
                    value: String(format: "%.2f", vm.activeWorkoutVM.metrics.distanceMeters / 1000),
                    unit: "km",
                    icon: "location.fill"
                )
                liveMetric(value: liveHeartRate, unit: "bpm", icon: "heart.fill")
            }

            HStack(spacing: 16) {
                Button {
                    vm.activeWorkoutVM.togglePause()
                } label: {
                    Image(systemName: vm.activeWorkoutVM.phase == .running ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .foregroundColor(AppTheme.primaryButtonText)
                        .frame(width: AppTheme.buttonHeight, height: AppTheme.buttonHeight)
                        .background(AppTheme.accent)
                        .clipShape(Circle())
                }
                .disabled(vm.activeWorkoutVM.phase == .finishing)

                Button {
                    showEndConfirm = true
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.title2)
                        .foregroundColor(AppTheme.textPrimary)
                        .frame(width: 64, height: 64)
                        .background(AppTheme.errorBackground)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(AppTheme.error, lineWidth: 2))
                }
                .disabled(vm.activeWorkoutVM.phase == .finishing)

                Button {
                    cancelActiveWorkout()
                } label: {
                    Image(systemName: "xmark")
                        .font(.title3)
                        .foregroundColor(AppTheme.textSecondary)
                        .frame(width: 44, height: 44)
                }
                .disabled(vm.activeWorkoutVM.phase == .finishing)
            }

            if let error = vm.activeWorkoutVM.error {
                Text(error)
                    .font(.footnote)
                    .foregroundColor(AppTheme.error)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.cornerRadiusMedium)
        .alert("End Workout?", isPresented: $showEndConfirm) {
            Button("End", role: .destructive) {
                Task {
                    _ = await vm.activeWorkoutVM.finish()
                    vm.activeWorkoutVM.reset()
                    await vm.refresh()
                }
            }
            Button("Keep Going", role: .cancel) {}
        } message: {
            Text("Your workout will be saved to Apple Health.")
        }
    }

    private var liveElapsed: String {
        let t = Int(vm.activeWorkoutVM.elapsedSeconds)
        let h = t / 3600
        let m = (t % 3600) / 60
        let s = t % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    private var liveHeartRate: String {
        guard let bpm = vm.activeWorkoutVM.metrics.heartRateBPM else { return "--" }
        return "\(Int(bpm))"
    }

    private func liveMetric(value: String, unit: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.footnote)
                .foregroundColor(AppTheme.accent)
            Text(value)
                .font(.title3.bold())
                .monospacedDigit()
                .foregroundColor(AppTheme.textPrimary)
            Text(unit)
                .font(.caption)
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func cancelActiveWorkout() {
        guard vm.activeWorkoutVM.phase != .finishing else { return }
        vm.activeWorkoutVM.reset()
    }

    private func workoutsList(_ workouts: [HealthKitWorkout]) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                ForEach(workouts) { workout in
                    Button {
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
    let vm = WorkoutHistoryViewModel(
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
