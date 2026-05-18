import Foundation

struct UserProfile: Codable, Identifiable {
    let id: String
    let userId: String
    let email: String?
    let firstName: String?
    let lastName: String?
    let weight: Double?
    let height: Int?
    let age: Int?
    let goal: Goal?
    let activityLevel: ActivityLevel?
    let createdAt: String?
    let updatedAt: String?
}

enum Goal: String, Codable {
    case lose
    case gain
    case maintain
}

enum ActivityLevel: String, Codable {
    case low
    case medium
    case high
}

struct CreateProfileRequest: Codable {
    let weight: Double?
    let height: Int?
    let age: Int?
    let goal: Goal?
    let activityLevel: ActivityLevel?
}

struct UpdateProfileRequest: Codable {
    let weight: Double?
    let height: Int?
    let age: Int?
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