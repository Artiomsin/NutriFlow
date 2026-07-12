import Foundation

final class DailySummaryService: DailySummaryServiceProtocol, Sendable {

    private let client: HTTPClient

    init(client: HTTPClient) {
        self.client = client
    }

    func getTodayDailySummary() async throws -> DailySummary {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let date = df.string(from: Date())
        let request = APIRequest<NeverBody>(
            path: "\(DailySummaryEndpoints.getDailySummaryToday)?date=\(date)",
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
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let date = df.string(from: Date())
        let request = APIRequest<NeverBody>(
            path: "\(DailySummaryEndpoints.getDashboardToday)?date=\(date)",
            method: .GET
        )

        return try await client.send(request)
    }
}
