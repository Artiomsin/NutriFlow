import Foundation

struct PreferredUnits: Codable, Sendable, Equatable {
    var weight: WeightUnit
    var volume: VolumeUnit
    var energy: EnergyUnit

    enum WeightUnit: String, Codable, CaseIterable, Sendable {
        case metric, imperial
        var display: String {
            switch self {
            case .metric: "Metric (g/kg)"
            case .imperial: "Imperial (oz/lb)"
            }
        }
    }

    enum VolumeUnit: String, Codable, CaseIterable, Sendable {
        case metric, imperial
        var display: String {
            switch self {
            case .metric: "Metric (ml/l)"
            case .imperial: "Imperial (fl oz)"
            }
        }
    }

    enum EnergyUnit: String, Codable, CaseIterable, Sendable {
        case kcal, kj
        var display: String {
            switch self {
            case .kcal: "Kilocalories (kcal)"
            case .kj: "Kilojoules (kJ)"
            }
        }
    }

    static let `default` = PreferredUnits(weight: .metric, volume: .metric, energy: .kcal)
}

enum Gender: String, Codable, CaseIterable, Sendable {
    case male
    case female

    var displayName: String {
        switch self {
        case .male: "Male"
        case .female: "Female"
        }
    }
}

struct UserProfile: Codable, Identifiable, Sendable {
    let id: String
    let userId: String
    let email: String?
    let firstName: String?
    let lastName: String?
    let weight: Double?
    let height: Int?
    let age: Int?
    let gender: Gender?
    let goal: Goal?
    let activityLevel: ActivityLevel?
    let preferredUnits: PreferredUnits?
    let createdAt: String?
    let updatedAt: String?
}

enum Goal: String, Codable, CaseIterable, Sendable {
    case lose
    case gain
    case maintain

    var displayName: String {
        switch self {
        case .lose: "Lose"
        case .gain: "Gain"
        case .maintain: "Maintain"
        }
    }
}

enum ActivityLevel: String, Codable, CaseIterable, Sendable {
    case low
    case medium
    case high

    var displayName: String {
        switch self {
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        }
    }
}

struct CreateProfileRequest: Codable, Sendable {
    let weight: Double?
    let height: Int?
    let age: Int?
    let gender: Gender?
    let goal: Goal?
    let activityLevel: ActivityLevel?
    let preferredUnits: PreferredUnits?
}

struct UpdateProfileRequest: Codable, Sendable {
    let weight: Double?
    let height: Int?
    let age: Int?
    let gender: Gender?
    let goal: Goal?
    let activityLevel: ActivityLevel?
    let preferredUnits: PreferredUnits?
}

struct CreateUserRequest: Codable, Sendable {
    let email: String
    let password: String
    let firstName: String?
    let lastName: String?
}

struct UpdateUserRequest: Codable, Sendable {
    let email: String?
    let password: String?
    let firstName: String?
    let lastName: String?
}
