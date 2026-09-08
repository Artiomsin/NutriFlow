//
//  WorkoutServiceProtocol.swift
//  Nutriflow
//
//  Created by Artem on 05.09.2026.
//

import Foundation

protocol WorkoutServiceProtocol {
    func sync(entries: [WorkoutSyncEntry]) async throws
    func getHistory(
        from: String?,
        to: String?,
        limit: Int?,
        offset: Int?
    ) async throws -> WorkoutHistoryResponse
    func deleteMissing(
        from startDate: String,
        healthKitWorkoutIds: [String]
    ) async throws
}