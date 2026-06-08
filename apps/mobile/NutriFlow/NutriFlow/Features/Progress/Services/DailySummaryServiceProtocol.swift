import Foundation

protocol DailySummaryServiceProtocol: Sendable {

    func getTodayDailySummary() async throws -> DailySummary

    func getDailySummaryByDate(date: String) async throws -> DailySummary

    func getDailySummaryRange(from: String, to: String) async throws -> [DailySummary]

    func getDashboardToday() async throws -> DashboardTodayResponse
}
