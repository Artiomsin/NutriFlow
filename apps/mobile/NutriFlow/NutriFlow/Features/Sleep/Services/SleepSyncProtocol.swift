import Foundation

enum SleepConnectionResult: Sendable {
    case authorized
    case denied
    case needsAccess
}

struct SleepNightDetailResult: Sendable {
    let sleep: HealthKitSleep
    let heartRate: [SleepHeartRatePoint]
}

protocol SleepSyncProtocol: AnyObject {
    func permissionState() async -> HealthKitPermissionState
    func connect() async -> SleepConnectionResult
    func loadLastNight() async throws -> HealthKitSleep?
    func loadHistoryIfNeeded() async throws -> [HealthKitSleep]
    func refreshHistory() async throws -> [HealthKitSleep]
    func loadNightDetail(_ night: HealthKitSleep) async throws -> SleepNightDetailResult
}