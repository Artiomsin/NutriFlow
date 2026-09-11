import Foundation

final class SleepService: SleepServiceProtocol, Sendable {

    private static let syncBatchSize = 50

    private let client: HTTPClient

    init(client: HTTPClient) {
        self.client = client
    }

    func sync(entries: [SleepSyncEntry]) async throws {
        let batches = stride(
            from: 0,
            to: entries.count,
            by: Self.syncBatchSize
        ).map {
            Array(entries[$0..<min($0 + Self.syncBatchSize, entries.count)])
        }

        for batch in batches {
            let request = APIRequest(
                path: SleepEndpoints.sync,
                method: .POST,
                body: SleepSyncRequest(nights: batch)
            )
            try await client.sendVoid(request)
        }
    }

    func getHistory(
        from: String? = nil,
        to: String? = nil,
        limit: Int? = nil,
        offset: Int? = nil
    ) async throws -> SleepHistoryResponse {
        let endpoint = SleepEndpoints.history(
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
        startDates: [String]
    ) async throws {
        let request = APIRequest(
            path: SleepEndpoints.deleteMissing,
            method: .DELETE,
            body: DeleteMissingRequest(
                startDate: startDate,
                startDates: startDates
            )
        )
        try await client.sendVoid(request)
    }
}

private struct SleepSyncRequest: Encodable, Sendable {
    let nights: [SleepSyncEntry]
}

private struct DeleteMissingRequest: Encodable, Sendable {
    let startDate: String
    let startDates: [String]
}