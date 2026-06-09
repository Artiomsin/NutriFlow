import Foundation

final class AnalyticsService: AnalyticsServiceProtocol, Sendable {

    private let client: HTTPClient

    init(client: HTTPClient) {
        self.client = client
    }

    func getWeekAnalytics() async throws -> AnalyticsResponse {
        let request = APIRequest<NeverBody>(path: AnalyticsEndpoints.getWeek, method: .GET)
        return try await client.send(request)
    }

    func getMonthAnalytics() async throws -> AnalyticsResponse {
        let request = APIRequest<NeverBody>(path: AnalyticsEndpoints.getMonth, method: .GET)
        return try await client.send(request)
    }

    func getCustomRange(from: String, to: String) async throws -> AnalyticsResponse {
        let path = AnalyticsEndpoints.getCustomRange(from: from, to: to)
        let request = APIRequest<NeverBody>(path: path, method: .GET)
        return try await client.send(request)
    }
}
