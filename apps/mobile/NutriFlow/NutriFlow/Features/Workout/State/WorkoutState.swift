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
    case error(Error)
    case needsAccess
    case denied
}
