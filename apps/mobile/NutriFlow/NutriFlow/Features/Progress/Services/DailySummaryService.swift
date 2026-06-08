import Foundation

final class DailySummaryService: DailySummaryServiceProtocol, Sendable {

    private let client: HTTPClient

    init(client: HTTPClient) {
        self.client = client
    }

    func getTodayDailySummary() async throws -> DailySummary {
        let request = APIRequest<NeverBody>(
            path: DailySummaryEndpoints.getDailySummaryToday,
            method: .GET
        )

        return try await client.send(request)
    }

    func getDailySummaryByDate(date: String) async throws -> DailySummary {
        let endpoint = DailySummaryEndpoints.getDailySummaryByDate(date: date)
        let request = APIRequest<NeverBody>(
            path: endpoint.path,
            method: .GET,
            queryItems: endpoint.query
        )

        return try await client.send(request)
    }

    func getDailySummaryRange(from: String, to: String) async throws -> [DailySummary] {
        let endpoint = DailySummaryEndpoints.getDailySummaryRange(from: from, to: to)
        let request = APIRequest<NeverBody>(
            path: endpoint.path,
            method: .GET,
            queryItems: endpoint.query
        )

        return try await client.send(request)
    }

    func getDashboardToday() async throws -> DashboardTodayResponse {
        let request = APIRequest<NeverBody>(
            path: DailySummaryEndpoints.getDashboardToday,
            method: .GET
        )

        return try await client.send(request)
    }
}
