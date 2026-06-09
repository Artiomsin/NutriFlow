import Foundation

final class ProfileService: ProfileServiceProtocol, Sendable {

    private let client: HTTPClient

    init(client: HTTPClient) {
        self.client = client
    }

    func getMyProfile() async throws -> UserProfile {
        let request = APIRequest<NeverBody>(
            path: ProfileEndpoints.getMyProfile,
            method: .GET
        )
        return try await client.send(request)
    }

    func createProfile(weight: Double?, height: Int?, age: Int?, gender: Gender?, goal: Goal?, activityLevel: ActivityLevel?) async throws -> UserProfile {
        let request = APIRequest(
            path: ProfileEndpoints.createProfile,
            method: .POST,
            body: CreateProfileRequest(weight: weight, height: height, age: age, gender: gender, goal: goal, activityLevel: activityLevel)
        )
        return try await client.send(request)
    }

    func updateMyProfile(weight: Double?, height: Int?, age: Int?, gender: Gender?, goal: Goal?, activityLevel: ActivityLevel?) async throws -> UserProfile {
        let request = APIRequest(
            path: ProfileEndpoints.updateMyProfile,
            method: .PUT,
            body: UpdateProfileRequest(weight: weight, height: height, age: age, gender: gender, goal: goal, activityLevel: activityLevel)
        )
        return try await client.send(request)
    }

    func deleteMyProfile() async throws {
        let request = APIRequest<NeverBody>(
            path: ProfileEndpoints.deleteMyProfile,
            method: .DELETE
        )
        try await client.sendVoid(request)
    }
}
