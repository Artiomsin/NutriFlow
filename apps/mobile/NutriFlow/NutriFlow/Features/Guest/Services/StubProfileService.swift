import Foundation

final class StubProfileService: ProfileServiceProtocol {
    func getMyProfile() async throws -> UserProfile {
        throw GuestError.registrationRequired
    }

    func createProfile(weight: Double?, height: Int?, age: Int?, gender: Gender?, goal: Goal?, activityLevel: ActivityLevel?) async throws -> UserProfile {
        throw GuestError.registrationRequired
    }

    func updateMyProfile(weight: Double?, height: Int?, age: Int?, gender: Gender?, goal: Goal?, activityLevel: ActivityLevel?) async throws -> UserProfile {
        throw GuestError.registrationRequired
    }

    func deleteMyProfile() async throws {
        throw GuestError.registrationRequired
    }
}
