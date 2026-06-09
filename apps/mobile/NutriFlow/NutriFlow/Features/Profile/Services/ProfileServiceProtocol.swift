protocol ProfileServiceProtocol: Sendable {
    func getMyProfile() async throws -> UserProfile
    func createProfile(weight: Double?, height: Int?, age: Int?, gender: Gender?, goal: Goal?, activityLevel: ActivityLevel?) async throws -> UserProfile
    func updateMyProfile(weight: Double?, height: Int?, age: Int?, gender: Gender?, goal: Goal?, activityLevel: ActivityLevel?) async throws -> UserProfile
    func deleteMyProfile() async throws
}
