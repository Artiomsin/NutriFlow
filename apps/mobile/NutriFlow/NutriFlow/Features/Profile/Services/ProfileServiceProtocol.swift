protocol ProfileServiceProtocol {
    func getMyProfile(token: String) async throws -> UserProfile
    func createProfile(token: String, weight: Double?, height: Int?, age: Int?, goal: Goal?, activityLevel: ActivityLevel?) async throws -> UserProfile
    func updateMyProfile(token: String, weight: Double?, height: Int?, age: Int?, goal: Goal?, activityLevel: ActivityLevel?) async throws -> UserProfile
    func deleteMyProfile(token: String) async throws -> EmptyResponse
}
