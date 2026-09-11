import Foundation

protocol ActivityHealthKitServiceProtocol: AnyObject {
    var isAvailable: Bool { get }
    func permissionState() async -> HealthKitPermissionState
    var onActivityChanged: (() -> Void)? { get set }
    func requestAuthorization() async throws
    func fetchToday() async -> DailyActivity
    func enableBackgroundDelivery() async throws
    func startObserving()
    func stopObserving()
}