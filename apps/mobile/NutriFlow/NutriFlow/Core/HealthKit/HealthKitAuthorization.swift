import Foundation
import HealthKit

enum HealthKitPermissionState: Equatable, Sendable {
    case notDetermined
    case authorized
    case denied
}

enum HealthFeature {
    case activity
    case sleep
    case workout
}

final class HealthKitAuthorization {

    static let shared = HealthKitAuthorization()

    private let store: HKHealthStore

    private static let hasRequestedAuthorizationKey = "healthkit_authorization_requested"

    private static var hasRequestedAuthorization: Bool {
        UserDefaults.standard.bool(forKey: hasRequestedAuthorizationKey)
    }

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

    var sharedStore: HKHealthStore {
        store
    }

    func requestAuthorization() async throws {
        guard isAvailable else { return }

        try await store.requestAuthorization(
            toShare: [],
            read: readTypes
        )

        UserDefaults.standard.set(
            true,
            forKey: Self.hasRequestedAuthorizationKey
        )
    }

    func permissionState(for feature: HealthFeature) async -> HealthKitPermissionState {
        guard isAvailable else { return .denied }

        let type: HKObjectType?
        switch feature {
        case .activity:
            type = HKQuantityType(.stepCount)
        case .sleep:
            type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)
        case .workout:
            type = HKQuantityType(.heartRate)
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
            // The system would show its permission sheet again: the user has
            // not granted everything. If we already asked once, access is off.
            return Self.hasRequestedAuthorization ? .denied : .notDetermined

        case .unnecessary:
            guard Self.hasRequestedAuthorization else {
                return .notDetermined
            }

            // Decision already made. Read grant and read revocation look the
            // same, so probe for real samples: revoked access returns nothing,
            // while granted access keeps returning the user's data.
            if await probeHasData(for: feature) {
                Self.markObservedData(for: feature)
                return .authorized
            }

            // No data right now. If we have seen data before, it was revoked.
            return Self.hasObservedData(for: feature) ? .denied : .authorized

        default:
            return .notDetermined
        }
    }

    private func probeHasData(for feature: HealthFeature) async -> Bool {
        guard isAvailable else { return false }

        let now = Date()
        let calendar = Calendar.current

        switch feature {
        case .activity:
            let start = calendar.date(byAdding: .day, value: -7, to: now) ?? now
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
            let start = calendar.date(byAdding: .day, value: -7, to: now) ?? now
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
            let start = calendar.date(byAdding: .day, value: -30, to: now) ?? now
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
