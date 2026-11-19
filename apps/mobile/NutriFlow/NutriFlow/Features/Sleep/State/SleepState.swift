//
//  SleepState.swift
//  Nutriflow
//
//  Created by Artem on 09.09.2026.
//

enum SleepState {
    case idle
    case needsAccess
    case loading
    case loaded([HealthKitSleep])
    case empty
    case error(AppError)
    case denied
    case unavailable
}

/// Home shows only the last night. Its state must stay separate from the
/// history screen state, otherwise opening Sleep History replaces the card
/// with `history.first`.
enum LastNightState {
    case idle
    case needsAccess
    case loading
    case loaded(HealthKitSleep)
    case empty
    case error(AppError)
    case denied
    case unavailable
}
