import Foundation

struct WeightLog: Codable, Sendable, Identifiable {
    let id: String
    let weightKg: String
    let entryDate: String
    let source: String?

    var weightValue: Double? {
        Double(weightKg)
    }
}