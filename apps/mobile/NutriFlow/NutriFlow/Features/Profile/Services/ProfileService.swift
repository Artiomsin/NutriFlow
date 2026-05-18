
import Foundation

final class ProfileService: ProfileServiceProtocol {

    private let client: HTTPClient

    init(client: HTTPClient = URLSessionHTTPClient()) {
        self.client = client
    }

    func getMyProfile(token: String) async throws -> UserProfile {
        let request = APIRequest(
            path: ProfileEndpoints.getMyProfile,
            method: .GET,
            body: nil as EmptyBody?,
            headers: ["Authorization": "Bearer \(token)"]
        )
        return try await client.send(request)
    }

    func createProfile(
            token: String,
            weight: Double?,
            height: Int?,
            age: Int?,
            goal: Goal?,
            activityLevel: ActivityLevel?
        ) async throws -> UserProfile {
        let request = APIRequest(
            path: ProfileEndpoints.createProfile,
            method: .POST,
            body: CreateProfileRequest(weight: weight, height: height, age: age, goal: goal, activityLevel: activityLevel),
            headers: ["Authorization": "Bearer \(token)"]
        )
        return try await client.send(request)
    }

    func updateMyProfile(
            token: String,
            weight: Double?,
            height: Int?,
            age: Int?,
            goal: Goal?,
            activityLevel: ActivityLevel?
        ) async throws -> UserProfile {
        let request = APIRequest(
            path: ProfileEndpoints.updateMyProfile,
            method: .PUT,
            body: UpdateProfileRequest(weight: weight, height: height, age: age, goal: goal, activityLevel: activityLevel),
            headers: ["Authorization": "Bearer \(token)"]
        )
        return try await client.send(request)
    }

    func deleteMyProfile(token: String) async throws -> EmptyResponse {
        let request = APIRequest(
            path: ProfileEndpoints.deleteMyProfile,
            method: .DELETE,
            body: nil as EmptyBody?,
            headers: ["Authorization": "Bearer \(token)"]
        )
        return try await client.send(request)
    }
}
