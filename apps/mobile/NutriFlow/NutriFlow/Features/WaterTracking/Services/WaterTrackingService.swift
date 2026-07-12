import Foundation

final class WaterTrackingService: WaterTrackingServiceProtocol, Sendable {

    private let client: HTTPClient

    init(client: HTTPClient) {
        self.client = client
    }

    func createWaterEntry(amountMl: Int, date: String? = nil) async throws -> WaterEntry {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let entryDate = date ?? df.string(from: Date())
        let request = APIRequest(
            path: WaterTrackingEndpoints.createWaterTracking,
            method: .POST,
            body: CreateWaterRequest(amountMl: amountMl, date: entryDate)
        )
        return try await client.send(request)
    }

    func getTodayWater() async throws -> [WaterEntry] {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let date = df.string(from: Date())
        let request = APIRequest<NeverBody>(
            path: "\(WaterTrackingEndpoints.getTodayWater)?date=\(date)",
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

    func deleteWaterEntry(id: String, date: String? = nil) async throws {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let deleteDate = date ?? df.string(from: Date())
        let path = "\(WaterTrackingEndpoints.deleteWaterTracking(id: id))?date=\(deleteDate)"
        let request = APIRequest<NeverBody>(
            path: path,
            method: .DELETE
        )
        try await client.sendVoid(request)
    }
}
