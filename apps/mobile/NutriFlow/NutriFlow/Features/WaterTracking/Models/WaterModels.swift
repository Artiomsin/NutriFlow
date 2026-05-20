
import Foundation

struct CreateWaterRequest: Codable {
    let amountMl: Int
}

struct WaterEntry: Codable, Identifiable {

    let id: String
    let userId: String
    let amountMl: Int

    let createdAt: String
    let updatedAt: String?
}
