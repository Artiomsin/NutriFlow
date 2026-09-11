import Foundation

protocol WorkoutHealthKitServiceProtocol: AnyObject {
    var isAvailable: Bool { get }
    func requestAuthorization() async throws
    func permissionState() async -> HealthKitPermissionState
    func fetchWorkouts(
        from startDate: Date,
        to endDate: Date
    ) async -> [HealthKitWorkout]
    func fetchLatestWorkout() async -> HealthKitWorkout?
    func fetchHeartRateWorkout(for workout: HealthKitWorkout) async -> [HeartRatePoint]
    func fetchWorkoutSeries(
        kind: WorkoutSeriesKind,
        workout: HealthKitWorkout
    ) async -> [WorkoutSeriesPoint]
}