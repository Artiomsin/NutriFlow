protocol ProfileServiceProtocol: Sendable {
    func getMyProfile() async throws -> UserProfile
    func createProfile(weight: Double, height: Int, age: Int, gender: Gender, goal: Goal, activityLevel: ActivityLevel, preferredUnits: PreferredUnits?) async throws -> UserProfile
    func updateMyProfile(height: Int?, age: Int?, gender: Gender?, goal: Goal?, activityLevel: ActivityLevel?, preferredUnits: PreferredUnits?) async throws -> UserProfile
    func updateTimeZone(_ timeZone: String) async throws
    func deleteMyProfile() async throws
    func getWeightLogs(from: String?, to: String?) async throws -> [WeightLog]
    func recordWeight(weightKg: Double) async throws -> WeightLog
    func deleteWeightLog(date: String) async throws
}
