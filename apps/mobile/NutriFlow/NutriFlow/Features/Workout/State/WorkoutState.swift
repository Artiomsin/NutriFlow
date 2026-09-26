//
//  WorkoutState.swift
//  Nutriflow
//
//  Created by Artem on 10.09.2026.
//

enum WorkoutHistoryState {
    case idle
    case loading
    case loaded([HealthKitWorkout])
    case error(AppError)
    case needsAccess
    case denied
}

enum LastWorkoutState: Equatable {
    case idle
    case loading
    case loaded
    case empty
    case error(AppError)
}
