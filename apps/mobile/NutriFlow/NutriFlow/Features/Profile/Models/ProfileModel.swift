import Foundation

enum Gender: String, Codable, CaseIterable {
    case male
    case female

    var displayName: String {
        switch self {
        case .male: "Male"
        case .female: "Female"
        }
    }
}

struct UserProfile: Codable, Identifiable {
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
    let createdAt: String?
    let updatedAt: String?
}

enum Goal: String, Codable, CaseIterable {
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

enum ActivityLevel: String, Codable, CaseIterable {
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

struct CreateProfileRequest: Codable {
    let weight: Double?
    let height: Int?
    let age: Int?
    let gender: Gender?
    let goal: Goal?
    let activityLevel: ActivityLevel?
}

struct UpdateProfileRequest: Codable {
    let weight: Double?
    let height: Int?
    let age: Int?
    let gender: Gender?
    let goal: Goal?
    let activityLevel: ActivityLevel?
}

struct CreateUserRequest: Codable {
    let email: String
    let password: String
    let firstName: String?
    let lastName: String?
}

struct UpdateUserRequest: Codable {
    let email: String?
    let password: String?
    let firstName: String?
    let lastName: String?
}
