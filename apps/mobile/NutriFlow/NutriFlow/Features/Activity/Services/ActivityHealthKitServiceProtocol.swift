import Foundation

protocol ActivityHealthKitServiceProtocol: AnyObject {
    var isAvailable: Bool { get }
    func permissionState() async -> HealthKitAuthorization
    var onActivityChanged: (() -> Void)? { get set }
    func requestAuthorization() async throws
    func fetchToday() async -> DailyActivity
    func fetchRange(from startDate: Date, to endDate: Date) async throws -> [DailyActivity]
    func enableBackgroundDelivery() async throws
    func startObserving()
    func stopObserving()
    func completePendingObservations()
}