import Foundation

protocol AnalyticsServiceProtocol: Sendable {
    func getWeekAnalytics() async throws -> AnalyticsResponse
    func getMonthAnalytics() async throws -> AnalyticsResponse
    func getCustomRange(from: String, to: String) async throws -> AnalyticsResponse
}
