
import Foundation

final class WaterTrackingService: WaterTrackingServiceProtocol {
    
    private let client: HTTPClient
    
    init(client: HTTPClient) {
        self.client = client
    }
    
    func createWaterEntry(token: String, amountMl: Int) async throws -> WaterEntry {
        let request = APIRequest(
            path: WaterTrackingEndpoints.createWaterTracking,
            method: .POST,
            body: CreateWaterRequest(amountMl: amountMl), headers: ["Authorization": "Bearer \(token)"]
        )
        return try await client.send(request)
    }
    
    func getTodayWater(token: String) async throws -> [WaterEntry] {
        let request = APIRequest(
            path: WaterTrackingEndpoints.getTodayWater,
            method: .GET,
            body: nil as EmptyBody?,
            headers: ["Authorization": "Bearer \(token)"]
        )
        return try await client.send(request)
    }
    
    func deleteWaterEntry(token: String, id: String) async throws -> EmptyResponse {
        let request = APIRequest(
            path: WaterTrackingEndpoints.deleteWaterTracking(id: id),
            method: .DELETE,
            body: nil as EmptyBody?,
            headers: ["Authorization": "Bearer \(token)"]
        )
        return try await client.send(request)
    }
    
}
