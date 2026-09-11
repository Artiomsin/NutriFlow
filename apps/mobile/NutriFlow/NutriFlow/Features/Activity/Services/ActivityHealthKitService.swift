import Foundation
import HealthKit

final class ActivityHealthKitService: NSObject, ActivityHealthKitServiceProtocol {

    private let store = HealthKitAuthorization.shared.sharedStore

    private let activityTypesToRead: Set<HKQuantityType> = [
            HKQuantityType(.stepCount),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.basalEnergyBurned),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.distanceCycling),
            HKQuantityType(.distanceSwimming)
        ]


    private var observers: [HKObserverQuery] = []

    var onActivityChanged: (() -> Void)?


    private static var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone.current
        return f
    }


    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }


    func permissionState() async -> HealthKitPermissionState {
        await HealthKitAuthorization.shared.permissionState(for: .activity)
    }

    func requestAuthorization() async throws {
        guard isAvailable else {
            return
        }

        try await HealthKitAuthorization.shared.requestAuthorization()
    }


    func fetchToday() async -> DailyActivity {
        let now = Date()
        let start = Calendar.current.startOfDay(for: now)

        print(
            "[HealthKit] fetchToday: " +
            "start=\(start) end=\(now)"
        )

        async let steps = sum(
            .stepCount,
            start: start,
            end: now,
            unit: .count()
        )

        async let active = sum(
            .activeEnergyBurned,
            start: start,
            end: now,
            unit: .kilocalorie()
        )

        async let basal = sum(
            .basalEnergyBurned,
            start: start,
            end: now,
            unit: .kilocalorie()
        )

        async let distance = sum(
            .distanceWalkingRunning,
            start: start,
            end: now,
            unit: .meter()
        )

        let result = DailyActivity(
            date: Self.dateFormatter.string(from: now),
            steps: Int(await steps),
            activeCalories: Int(await active),
            basalCalories: Int(await basal),
            distanceMeters: await distance
        )

        print("[HealthKit] fetchToday result: \(result)")

        return result
    }


    func enableBackgroundDelivery() async throws {
        guard isAvailable else {
            return
        }

        for type in activityTypesToRead {
            try await store.enableBackgroundDelivery(
                for: type,
                frequency: .hourly
            )
        }
    }


    func startObserving() {
        guard isAvailable else {
            return
        }

        // first stop old queries
        stopObserving()

        for type in activityTypesToRead {

            let query = HKObserverQuery(
                sampleType: type,
                predicate: nil
            ) { [weak self] _, completionHandler, error in

                if let error {
                    print(
                        "[HealthKit] observer error: \(error)"
                    )

                    completionHandler()
                    return
                }

                self?.onActivityChanged?()

                completionHandler()
            }

            store.execute(query)
            observers.append(query)
        }
    }

    func stopObserving() {
        for query in observers {
            store.stop(query)
        }

        observers.removeAll()

        onActivityChanged = nil
    }


    private func sum(
        _ identifier: HKQuantityTypeIdentifier,
        start: Date,
        end: Date,
        unit: HKUnit
    ) async -> Double {

        let type = HKQuantityType(identifier)

        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: end,
            options: .strictStartDate
        )

        return await withCheckedContinuation(isolation: MainActor.shared) { continuation in

            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, _ in

                let value =
                    result?
                        .sumQuantity()?
                        .doubleValue(for: unit)
                    ?? 0

                continuation.resume(
                    returning: value
                )
            }

            store.execute(query)
        }
    }
}