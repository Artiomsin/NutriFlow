import Foundation

final class WaterTrackingService: WaterTrackingServiceProtocol, Sendable {

    private let client: HTTPClient

    init(client: HTTPClient) {
        self.client = client
    }

    func createWaterEntry(amountMl: Int) async throws -> WaterEntry {
        let request = APIRequest(
            path: WaterTrackingEndpoints.createWaterTracking,
            method: .POST,
            body: CreateWaterRequest(amountMl: amountMl)
        )
        return try await client.send(request)
    }

    func getTodayWater() async throws -> [WaterEntry] {
        let request = APIRequest<NeverBody>(
            path: WaterTrackingEndpoints.getTodayWater,
            method: .GET
        )
        return try await client.send(request)
    }

    func getWaterByDate(date: String) async throws -> [WaterEntry] {
        let endpoint = WaterTrackingEndpoints.getWaterByDate(date: date)
        let request = APIRequest<NeverBody>(
            path: endpoint.path,
            method: .GET,
            queryItems: endpoint.query
        )
        return try await client.send(request)
    }

    func deleteWaterEntry(id: String) async throws {
        let request = APIRequest<NeverBody>(
            path: WaterTrackingEndpoints.deleteWaterTracking(id: id),
            method: .DELETE
        )
        try await client.sendVoid(request)
    }
}
