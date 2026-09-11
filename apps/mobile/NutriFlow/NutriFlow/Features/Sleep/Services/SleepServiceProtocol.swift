import Foundation

protocol SleepServiceProtocol {
    func sync(entries: [SleepSyncEntry]) async throws
    func getHistory(
        from: String?,
        to: String?,
        limit: Int?,
        offset: Int?
    ) async throws -> SleepHistoryResponse
    func deleteMissing(
        from startDate: String,
        startDates: [String]
    ) async throws
}