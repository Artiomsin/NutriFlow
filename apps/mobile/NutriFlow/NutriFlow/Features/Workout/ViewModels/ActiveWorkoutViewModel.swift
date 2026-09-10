//
//  ActiveWorkoutViewModel.swift
//  Nutriflow
//
//  Created by Artem on 07.09.2026.
//

import Foundation
import Observation

enum ActiveWorkoutPhase {
    case idle
    case running
    case paused
    case finishing
}

@Observable
@MainActor
final class ActiveWorkoutViewModel {

    private let healthKit: WorkoutHealthKitServiceProtocol

    var phase: ActiveWorkoutPhase = .idle
    var kind: TrackableWorkout.Kind = .run
    var metrics: LiveWorkoutMetrics = .empty
    var error: String?

    @ObservationIgnored private var timerTask: Task<Void, Never>?
    @ObservationIgnored private var startedAt: Date?
    @ObservationIgnored private var isFinished: Bool = false

    init(healthKit: WorkoutHealthKitServiceProtocol) {
        self.healthKit = healthKit
        healthKit.onLiveMetrics = { [weak self] metrics in
            Task { @MainActor in
                self?.metrics = metrics
            }
        }
        healthKit.onSessionFailed = { [weak self] message in
            Task { @MainActor in
                guard let self, self.phase == .running || self.phase == .paused else { return }
                self.timerTask?.cancel()
                self.timerTask = nil
                self.phase = .idle
                self.metrics = .empty
                self.error = message
            }
        }
    }

    deinit {
        timerTask?.cancel()
    }

    var elapsedSeconds: TimeInterval {
        metrics.elapsedSeconds
    }

    func start(kind: TrackableWorkout.Kind) {
        guard phase != .running, phase != .finishing else { return }
        self.kind = kind
        phase = .running
        startedAt = Date()
        metrics = .empty
        isFinished = false
        error = nil
        startTimer()
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await self.healthKit.startLiveWorkout(kind: kind, indoor: true)
                guard self.phase == .running else {
                    self.healthKit.cancelLiveWorkout()
                    return
                }
            } catch {
                guard self.phase == .running else { return }
                self.error = error.localizedDescription
                self.phase = .idle
                self.timerTask?.cancel()
                self.metrics = .empty
            }
        }
    }

    func togglePause() {
        switch phase {
        case .running:
            phase = .paused
            healthKit.pauseLiveWorkout()
            timerTask?.cancel()
        case .paused:
            phase = .running
            healthKit.resumeLiveWorkout()
            startTimer()
        case .idle, .finishing:
            break
        }
    }

    func finish() async -> HealthKitWorkout? {
        guard phase == .running || phase == .paused else { return nil }
        phase = .finishing
        isFinished = true
        timerTask?.cancel()
        do {
            return try await healthKit.endLiveWorkout()
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }

    func reset() {
        timerTask?.cancel()
        timerTask = nil
        healthKit.cancelLiveWorkout()
        phase = .idle
        metrics = .empty
        error = nil
        kind = .run
        startedAt = nil
        isFinished = false
    }

    private func startTimer() {
        timerTask?.cancel()
        timerTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard let self, !self.isFinished, self.phase == .running else { continue }
                self.metrics.elapsedSeconds = Date().timeIntervalSince(self.startedAt ?? Date())
            }
        }
    }
}
