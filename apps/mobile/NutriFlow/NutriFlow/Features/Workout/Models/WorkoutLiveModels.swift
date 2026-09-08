//
//  WorkoutLiveModels.swift
//  Nutriflow
//
//  Created by Artem on 07.09.2026.
//

import Foundation

struct TrackableWorkout: Identifiable, Hashable, Sendable {
    enum Kind: String, CaseIterable, Sendable {
        case run, walk, cycle, swim, functional

        var title: String {
            switch self {
            case .run: return "Run"
            case .walk: return "Walk"
            case .cycle: return "Cycle"
            case .swim: return "Swim"
            case .functional: return "Functional"
            }
        }
    }

    let kind: Kind

    var id: String { kind.rawValue }

    static let allCases: [TrackableWorkout] = {
        Kind.allCases.map { TrackableWorkout(kind: $0) }
    }()

    var title: String {
        kind.title
    }

    var iconName: String {
        switch kind {
        case .run: return "figure.run"
        case .walk: return "figure.walk"
        case .cycle: return "figure.outdoor.cycle"
        case .swim: return "figure.pool.swim"
        case .functional: return "dumbbell.fill"
        }
    }
}

struct LiveWorkoutMetrics: Equatable, Sendable {
    var elapsedSeconds: TimeInterval = 0
    var activeCalories: Double = 0
    var distanceMeters: Double = 0
    var heartRateBPM: Double?

    static let empty = LiveWorkoutMetrics()
}

struct HeartRatePoint: Equatable, Sendable, Identifiable {
    let startDate: Date
    let bpm: Double

    var id: Date { startDate }
}


