import Foundation

protocol ActivityHealthKitServiceProtocol: AnyObject {
    var isAvailable: Bool { get }
    func permissionState() async -> HealthKitAuthorization
    var onActivityChanged: (() -> Void)? { get set }
    func requestAuthorization() async throws
    /// Throws only when every HealthKit query fails. An empty day is returned
    /// as a `DailyActivity` with zeros, not as an error.
    func fetchToday() async throws -> DailyActivity
    func fetchRange(from startDate: Date, to endDate: Date) async throws -> [DailyActivity]
    func hasLimitedHistory() async -> Bool
    func enableBackgroundDelivery() async throws
    func startObserving()
    func stopObserving()
    func completePendingObservations()
}