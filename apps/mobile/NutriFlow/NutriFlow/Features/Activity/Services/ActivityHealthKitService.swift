import Foundation
import HealthKit

final class ActivityHealthKitService: NSObject, ActivityHealthKitServiceProtocol {

    private let store = HealthKitAccess.shared.sharedStore

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

    /// Completion handlers from HKObserverQuery that must be called only after
    /// the full async flow (fetchToday + syncToBackend) has finished.
    /// This prevents HealthKit from considering the delivery "done" before we
    /// have actually persisted the data (either to backend or to local sync queue).
    private var pendingCompletions: [(() -> Void)] = []
    private let completionLock = NSLock()


    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: PreferencesStore.shared.timeZone) ?? .current
        return f
    }


    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }


    func permissionState() async -> HealthKitAuthorization {
        await HealthKitAccess.shared.permissionState(for: .activity)
    }

    func requestAuthorization() async throws {
        guard isAvailable else {
            return
        }

        try await HealthKitAccess.shared.requestAuthorization()
    }


    func fetchToday() async -> DailyActivity {
        let now = Date()
        let tz = TimeZone(identifier: PreferencesStore.shared.timeZone) ?? .current
        var calendar = Calendar.current
        calendar.timeZone = tz
        let start = calendar.startOfDay(for: now)

        print(
            "[HealthKit] fetchToday: " +
            "start=\(start) end=\(now) timeZone=\(tz.identifier)"
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

        async let walkingRunningDistance = sum(
            .distanceWalkingRunning,
            start: start,
            end: now,
            unit: .meter()
        )
        async let cyclingDistance = sum(
            .distanceCycling,
            start: start,
            end: now,
            unit: .meter()
        )
        async let swimmingDistance = sum(
            .distanceSwimming,
            start: start,
            end: now,
            unit: .meter()
        )

        let totalDistance = await walkingRunningDistance
            + cyclingDistance
            + swimmingDistance

        let result = DailyActivity(
            date: dateFormatter.string(from: now),
            steps: Int(await steps),
            activeCalories: await active,
            basalCalories: await basal,
            distanceMeters: totalDistance
        )

        print("[HealthKit] fetchToday result: \(result)")

        return result
    }

    func fetchRange(from startDate: Date, to endDate: Date) async throws -> [DailyActivity] {
        let tz = TimeZone(identifier: PreferencesStore.shared.timeZone) ?? .current
        var calendar = Calendar.current
        calendar.timeZone = tz

        var results: [DailyActivity] = []

        // Iterate day by day in the profile time zone
        var current = calendar.startOfDay(for: startDate)
        let endDay = calendar.startOfDay(for: endDate)

        while current <= endDay {
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: current) else {
                break
            }

            let dayStart = current
            let dayEnd = nextDay

            print(
                "[HealthKit] fetchRange day: " +
                "start=\(dayStart) end=\(dayEnd) timeZone=\(tz.identifier)"
            )

            async let steps = sum(
                .stepCount,
                start: dayStart,
                end: dayEnd,
                unit: .count()
            )

            async let active = sum(
                .activeEnergyBurned,
                start: dayStart,
                end: dayEnd,
                unit: .kilocalorie()
            )

            async let basal = sum(
                .basalEnergyBurned,
                start: dayStart,
                end: dayEnd,
                unit: .kilocalorie()
            )

            async let walkingRunningDistance = sum(
                .distanceWalkingRunning,
                start: dayStart,
                end: dayEnd,
                unit: .meter()
            )
            async let cyclingDistance = sum(
                .distanceCycling,
                start: dayStart,
                end: dayEnd,
                unit: .meter()
            )
            async let swimmingDistance = sum(
                .distanceSwimming,
                start: dayStart,
                end: dayEnd,
                unit: .meter()
            )

            let totalDistance = await walkingRunningDistance
                + cyclingDistance
                + swimmingDistance

            let entry = DailyActivity(
                date: dateFormatter.string(from: dayStart),
                steps: Int(await steps),
                activeCalories: await active,
                basalCalories: await basal,
                distanceMeters: totalDistance
            )

            results.append(entry)
            current = nextDay
        }

        print("[HealthKit] fetchRange result: \(results.count) days")

        return results
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

                // Store the completion handler and call it only after the full
                // async flow (fetchToday + syncToBackend) has finished.
                // This prevents HealthKit from considering the delivery done
                // before we have persisted the data.
                self?.completionLock.lock()
                self?.pendingCompletions.append(completionHandler)
                self?.completionLock.unlock()
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

        // Complete any pending observations on stop to avoid leaking
        // completion handlers that will never be called.
        completePendingObservations()
    }

    /// Call all stored HealthKit observer completion handlers.
    /// Must be called only after the full async flow (fetchToday + syncToBackend)
    /// has finished, so HealthKit knows the data has been persisted.
    func completePendingObservations() {
        completionLock.lock()
        let completions = pendingCompletions
        pendingCompletions.removeAll()
        completionLock.unlock()

        for completion in completions {
            completion()
        }
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

        return await withCheckedContinuation { continuation in

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
