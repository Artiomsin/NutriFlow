import Foundation

struct WeightLog: Codable, Sendable, Identifiable {
    let id: String
    let weightKg: Double
    let entryDate: String
    let source: String?

    var weightValue: Double { weightKg }
}
