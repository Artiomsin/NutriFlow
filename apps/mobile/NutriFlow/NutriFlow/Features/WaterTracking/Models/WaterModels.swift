
import Foundation

struct CreateWaterRequest: Codable, Sendable {
    let amountMl: Int
}

struct WaterEntry: Codable, Identifiable, Sendable {

    let id: String
    let userId: String
    let amountMl: Int

    let createdAt: String
    let updatedAt: String?
}
