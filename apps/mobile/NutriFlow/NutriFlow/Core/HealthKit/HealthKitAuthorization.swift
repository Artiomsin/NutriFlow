import Foundation
import HealthKit

/// Whether HealthKit itself can be used on this device.
enum HealthKitAvailability: Equatable, Sendable {
    case available
    case unavailable
}

/// The user's permission for the app to read HealthKit data.
///
/// This intentionally holds no data-availability signal: for a read-only
/// app HealthKit cannot distinguish "granted but no data yet" from "denied",
/// so absence of data must never be treated as proof of denial.
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

    private static func observedDataKey(for feature: HealthFeature) -> String {
        switch feature {
        case .activity:
            return "healthkit_observed_data_activity"
        case .sleep:
            return "healthkit_observed_data_sleep"
        case .workout:
            return "healthkit_observed_data_workout"
        }
    }

    private static func hasObservedData(for feature: HealthFeature) -> Bool {
        UserDefaults.standard.bool(forKey: observedDataKey(for: feature))
    }

    private static func markObservedData(for feature: HealthFeature) {
        UserDefaults.standard.set(true, forKey: observedDataKey(for: feature))
    }

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
        for feature: HealthFeature
    ) async -> HealthKitAuthorization {
        guard isAvailable else { return .unknown }

        let type: HKObjectType?
        switch feature {
        case .activity:
            type = HKQuantityType(.stepCount)
        case .sleep:
            type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)
        case .workout:
            // Probe the workout type itself. HR samples are optional; a user
            // with workouts but no heart rate data must not look unauthorized.
            type = HKObjectType.workoutType()
        }
        guard let type else { return .notDetermined }

        let authorizationStatus = store.authorizationStatus(for: type)

        // HealthKit never reports read denial for privacy reasons. For a
        // read-only app authorizationStatus can stay .sharingDenied even when
        // read access was granted, so it is only trusted when it explicitly
        // says .sharingAuthorized.
        if authorizationStatus == .sharingAuthorized {
            Self.markObservedData(for: feature)
            return .authorized
        }

        let requestStatus = try? await requestStatusForAuthorization()

        switch requestStatus {
        case .shouldRequest:
            // The system is still willing to show its sheet. This is a request
            // state, never a denial — asking again is the correct next step.
            return .notDetermined

        case .unnecessary:
            // A decision was already made, but read access cannot be reported
            // by HealthKit. Probe a long window for real samples: revoked
            // access returns nothing, granted access keeps returning data.
            if await probeHasData(for: feature) {
                Self.markObservedData(for: feature)
                return .authorized
            }

            // No samples in the window. Only treat access as revoked when we
            // have actually seen data before; a granted-but-empty account must
            // stay authorized instead of dead-ending on an empty screen.
            return Self.hasObservedData(for: feature) ? .denied : .authorized

        default:
            return .unknown
        }
    }

    private func probeHasData(for feature: HealthFeature) async -> Bool {
        guard isAvailable else { return false }

        let now = Date()
        let calendar = AppDate.calendar

        switch feature {
        case .activity:
            let start = calendar.date(byAdding: .day, value: -30, to: now) ?? now
            let type = HKQuantityType(.stepCount)
            let predicate = HKQuery.predicateForSamples(
                withStart: start,
                end: now,
                options: .strictStartDate
            )

            return await withCheckedContinuation { continuation in
                let query = HKStatisticsQuery(
                    quantityType: type,
                    quantitySamplePredicate: predicate,
                    options: .cumulativeSum
                ) { _, result, _ in
                    let sum = result?
                        .sumQuantity()?
                        .doubleValue(for: .count()) ?? 0
                    continuation.resume(returning: sum > 0)
                }
                store.execute(query)
            }

        case .sleep:
            let start = calendar.date(byAdding: .day, value: -30, to: now) ?? now
            guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
                return false
            }
            let predicate = HKQuery.predicateForSamples(
                withStart: start,
                end: now,
                options: .strictStartDate
            )

            return await withCheckedContinuation { continuation in
                let query = HKSampleQuery(
                    sampleType: type,
                    predicate: predicate,
                    limit: 1,
                    sortDescriptors: nil
                ) { _, samples, _ in
                    continuation.resume(returning: !(samples ?? []).isEmpty)
                }
                store.execute(query)
            }

        case .workout:
            let start = calendar.date(byAdding: .day, value: -60, to: now) ?? now
            let type = HKObjectType.workoutType()
            let predicate = HKQuery.predicateForSamples(
                withStart: start,
                end: now,
                options: .strictStartDate
            )

            return await withCheckedContinuation { continuation in
                let query = HKSampleQuery(
                    sampleType: type,
                    predicate: predicate,
                    limit: 1,
                    sortDescriptors: nil
                ) { _, samples, _ in
                    continuation.resume(returning: !(samples ?? []).isEmpty)
                }
                store.execute(query)
            }
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
