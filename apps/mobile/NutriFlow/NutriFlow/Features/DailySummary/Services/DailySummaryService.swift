//
//  DailySummaryService.swift
//  Nutriflow
//
//  Created by Artem on 20.05.26.
//

import Foundation

struct DailySummaryService: DailySummaryServiceProtocol {

    private let client: HTTPClient

    init(client: HTTPClient = URLSessionHTTPClient()) {
        self.client = client
    }

    func getTodayDailySummary(
        token: String
    ) async throws -> DailySummary {

        let request = APIRequest(
            path: DailySummaryEndpoints.getDailySummaryToday,
            method: .GET,
            body: nil as EmptyBody?,
            headers: [
                "Authorization": "Bearer \(token)"
            ]
        )

        return try await client.send(request)
    }

    func getDailySummaryByDate(
        token: String,
        date: String
    ) async throws -> DailySummary {

        let request = APIRequest(
            path: DailySummaryEndpoints.getDailySummaryByDate(date: date),
            method: .GET,
            body: nil as EmptyBody?,
            headers: [
                "Authorization": "Bearer \(token)"
            ]
        )

        return try await client.send(request)
    }

    func getDailySummaryRange(
        token: String,
        from: String,
        to: String
    ) async throws -> [DailySummary] {

        let request = APIRequest(
            path: DailySummaryEndpoints.getDailySummaryRange(from: from, to: to),
            method: .GET,
            body: nil as EmptyBody?,
            headers: [
                "Authorization": "Bearer \(token)"
            ]
        )

        return try await client.send(request)
    }
}
