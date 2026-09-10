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
    case error(String)
}
