import Foundation

protocol WorkoutHealthKitServiceProtocol: AnyObject {
    var isAvailable: Bool { get }
    func requestAuthorization() async throws
    func permissionState() async -> HealthKitAuthorization
    func fetchWorkouts(
        from startDate: Date,
        to endDate: Date
    ) async throws -> [HealthKitWorkout]
    func fetchLatestWorkout() async throws -> HealthKitWorkout?
    func fetchHeartRateWorkout(for workout: HealthKitWorkout) async throws -> [HeartRatePoint]
    func fetchWorkoutSeries(
        kind: WorkoutSeriesKind,
        workout: HealthKitWorkout
    ) async throws -> [WorkoutSeriesPoint]
}