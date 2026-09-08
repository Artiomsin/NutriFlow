import Foundation

protocol WorkoutHealthKitServiceProtocol: AnyObject {
    var isAvailable: Bool { get }
    func requestAuthorization() async throws
    func workoutPermissionState() -> WorkoutPermissionState
    func fetchWorkouts(
        from startDate: Date,
        to endDate: Date
    ) async -> [HealthKitWorkout]
    func fetchLatestWorkout() async -> HealthKitWorkout?

    var onLiveMetrics: ((LiveWorkoutMetrics) -> Void)? { get set }
    var onSessionFailed: ((String) -> Void)? { get set }
    func startLiveWorkout(kind: TrackableWorkout.Kind) async throws
    func pauseLiveWorkout()
    func resumeLiveWorkout()
    func cancelLiveWorkout()
    func endLiveWorkout() async throws -> HealthKitWorkout
    func fetchHeartRateWorkout(from startDate: Date, to endDate: Date) async -> [HeartRatePoint]
}

enum WorkoutPermissionState {
    case authorized
    case notDetermined
    case denied
}
