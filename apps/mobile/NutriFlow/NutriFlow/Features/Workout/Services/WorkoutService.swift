//
//  WorkoutService.swift
//  Nutriflow
//
//  Created by Artem on 05.09.2026.
//

import Foundation

final class WorkoutService: WorkoutServiceProtocol, Sendable {

    private static let syncBatchSize = 100

    private let client: HTTPClient

    init(client: HTTPClient) {
        self.client = client
    }

    func sync(entries: [WorkoutSyncEntry]) async throws {
        let batches = stride(
            from: 0,
            to: entries.count,
            by: Self.syncBatchSize
        ).map {
            Array(entries[$0..<min($0 + Self.syncBatchSize, entries.count)])
        }

        for batch in batches {
            let request = APIRequest(
                path: WorkoutEndpoints.sync,
                method: .POST,
                body: WorkoutSyncRequest(workouts: batch)
            )
            try await client.sendVoid(request)
        }
    }

    func getHistory(
        from: String? = nil,
        to: String? = nil,
        limit: Int? = nil,
        offset: Int? = nil
    ) async throws -> WorkoutHistoryResponse {
        let endpoint = WorkoutEndpoints.history(
            from: from,
            to: to,
            limit: limit,
            offset: offset
        )
        let request = APIRequest<NeverBody>(
            path: endpoint.path,
            method: .GET,
            queryItems: endpoint.query
        )
        return try await client.send(request)
    }

    func deleteMissing(
        from startDate: String,
        healthKitWorkoutIds: [String]
    ) async throws {
        struct DeleteMissingRequest: Encodable, Sendable {
            let startDate: String
            let healthKitWorkoutIds: [String]
        }

        let request = APIRequest(
            path: WorkoutEndpoints.deleteMissing,
            method: .DELETE,
            body: DeleteMissingRequest(
                startDate: startDate,
                healthKitWorkoutIds: healthKitWorkoutIds
            )
        )
        try await client.sendVoid(request)
    }
}