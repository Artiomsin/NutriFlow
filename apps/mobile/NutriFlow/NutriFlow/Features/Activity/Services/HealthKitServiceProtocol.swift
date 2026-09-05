import Foundation

protocol HealthKitServiceProtocol: AnyObject {
    var isAvailable: Bool { get }
    var onActivityChanged: (() -> Void)? { get set }
    func requestAuthorization() async throws
    func fetchToday() async -> DailyActivity
    func enableBackgroundDelivery() async throws
    func startObserving()
    func stopObserving()
}
