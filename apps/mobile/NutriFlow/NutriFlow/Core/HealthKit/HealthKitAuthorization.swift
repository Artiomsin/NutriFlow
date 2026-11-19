import Foundation
import HealthKit

/// Whether HealthKit itself can be used on this device.
enum HealthKitAvailability: Equatable, Sendable {
    case available
    case unavailable
}

/// The state of the HealthKit authorization request for a read-only feature.
///
/// HealthKit deliberately doesn't reveal whether a person granted read access.
/// Therefore `.authorized` only means that the permission request was completed;
/// the result of a data query remains the source of truth for what can be shown.
enum HealthKitAuthorization: Equatable, Sendable {
    case notDetermined
    case authorized
    case denied
    case unknown
}

enum HealthFeature: Hashable {
    case activity
    case sleep
    case workout
}

final class HealthKitAccess {

    static let shared = HealthKitAccess()

    /// iOS has no public URL for the Health app's per-app permission screen.
    /// Show the exact manual path instead of claiming that "Open Settings"
    /// reaches the HealthKit switches.
    static let permissionPath = "Health → Sharing & Access → Apps and Services → NutriFlow"

    private let store: HKHealthStore

    private struct CachedPermission {
        let value: HealthKitAuthorization
        let fetchedAt: Date
    }

    private let permissionCacheLock = NSLock()
    private var permissionCache: [HealthFeature: CachedPermission] = [:]
    private static let permissionCacheTTL: TimeInterval = 5 * 60

    private init() {
        self.store = HKHealthStore()
    }

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    var availability: HealthKitAvailability {
        isAvailable ? .available : .unavailable
    }

    var sharedStore: HKHealthStore {
        store
    }

    func requestAuthorization() async throws {
        guard isAvailable else { return }

        try await store.requestAuthorization(
            toShare: [],
            read: readTypes
        )

        // The user may have changed any feature's decision in the sheet.
        invalidatePermissionCache()
    }

    /// Permission probes hit HealthKit several times per feature. Home checks
    /// them on every foreground, so cache the result briefly and invalidate it
    /// when the user leaves for Settings or a request completes.
    func permissionState(for feature: HealthFeature) async -> HealthKitAuthorization {
        // NSLock may not be used directly inside an async function in Swift 6.
        // The helpers below keep the lock in synchronous scopes and hold it
        // only for a dictionary read/write.
        if let cached = cachedPermission(for: feature) {
            return cached
        }

        let value = await computePermissionState(for: feature)
        storePermission(value, for: feature)
        return value
    }

    private func cachedPermission(for feature: HealthFeature) -> HealthKitAuthorization? {
        permissionCacheLock.lock()
        defer { permissionCacheLock.unlock() }

        guard let cached = permissionCache[feature],
              Date().timeIntervalSince(cached.fetchedAt) < Self.permissionCacheTTL
        else { return nil }

        return cached.value
    }

    private func storePermission(
        _ value: HealthKitAuthorization,
        for feature: HealthFeature
    ) {
        permissionCacheLock.lock()
        defer { permissionCacheLock.unlock() }

        permissionCache[feature] = CachedPermission(
            value: value,
            fetchedAt: Date()
        )
    }

    func invalidatePermissionCache(for feature: HealthFeature? = nil) {
        permissionCacheLock.lock()
        defer { permissionCacheLock.unlock() }

        if let feature {
            permissionCache[feature] = nil
        } else {
            permissionCache.removeAll()
        }
    }

    private func computePermissionState(
        for _: HealthFeature
    ) async -> HealthKitAuthorization {
        guard isAvailable else { return .unknown }

        do {
            switch try await requestStatusForAuthorization() {
            case .shouldRequest:
                return .notDetermined
            case .unnecessary:
                // HealthKit doesn't reveal read permission. A completed request
                // is the only state we can report truthfully; empty query
                // results may mean either no samples or denied read access.
                return .authorized
            default:
                return .unknown
            }
        } catch {
            return .unknown
        }
    }

    private func requestStatusForAuthorization() async throws -> HKAuthorizationRequestStatus {
        try await withCheckedThrowingContinuation { continuation in
store.getRequestStatusForAuthorization(
                toShare: [],
                read: readTypes
            ) { status, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: status)
                }
            }
        }
    }

    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [
            HKQuantityType(.stepCount),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.basalEnergyBurned),
            HKQuantityType(.heartRate),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.distanceCycling),
            HKQuantityType(.distanceSwimming),
            HKQuantityType(.runningSpeed),
            HKQuantityType(.cyclingSpeed),
            HKQuantityType(.walkingSpeed),
            HKQuantityType(.crossCountrySkiingSpeed),
            HKQuantityType(.cyclingCadence),
            HKQuantityType(.cyclingPower),
            HKQuantityType(.runningPower),
            HKQuantityType(.distanceCrossCountrySkiing),
            HKQuantityType(.distanceDownhillSnowSports),
            HKQuantityType(.distanceWheelchair),
            HKQuantityType(.distancePaddleSports),
            HKObjectType.workoutType(),
        ]

        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleep)
        }

        return types
    }
}
