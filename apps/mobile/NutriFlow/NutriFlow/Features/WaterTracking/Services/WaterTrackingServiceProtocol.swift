import Foundation

protocol WaterTrackingServiceProtocol {

    func createWaterEntry(
        token: String,
        amountMl: Int
    ) async throws -> WaterEntry

    func getTodayWater(
        token: String
    ) async throws -> [WaterEntry]

    func deleteWaterEntry(
        token: String,
        id: String
    ) async throws -> EmptyResponse
}
