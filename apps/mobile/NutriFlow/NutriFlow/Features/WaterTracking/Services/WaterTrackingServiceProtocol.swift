import Foundation

protocol WaterTrackingServiceProtocol: Sendable {

    @discardableResult
    func createWaterEntry(
        amountMl: Int
    ) async throws -> WaterEntry

    func getTodayWater() async throws -> [WaterEntry]

    func getWaterByDate(date: String) async throws -> [WaterEntry]

    func deleteWaterEntry(
        id: String
    ) async throws
}
