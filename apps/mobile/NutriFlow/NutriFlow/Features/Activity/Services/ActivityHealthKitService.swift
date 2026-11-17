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

    /// Completion handlers from HKObserverQuery. They are acknowledged as soon
    /// as the HealthKit read finishes, before any network sync, so killing the
    /// process during a slow request cannot lose them.
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

    /// `permissionState(for: .activity)` is decided mostly by `stepCount`, so a
    /// revoked Write permission for one of the other five types can leave the
    /// overall state `.authorized` while its query fails. Log every type to
    /// make that case visible in the debugger.
    private func logActivityAuthorizationStatuses() {
        guard isAvailable else {
            print("[HealthKit] authorization statuses: HealthKit unavailable")
            return
        }

        let statuses = activityTypesToRead
            .map { "\($0.identifier)=\(store.authorizationStatus(for: $0).rawValue)" }
            .sorted()
            .joined(separator: ", ")
        print("[HealthKit] authorization statuses: \(statuses)")
    }

    func requestAuthorization() async throws {
        guard isAvailable else {
            return
        }

        try await HealthKitAccess.shared.requestAuthorization()
    }


    /// Failed queries become `nil` fields; the record is still returned so the
    /// card can show the metrics that were read. `nil` means no metric at all
    /// could be read.
    func fetchToday() async -> DailyActivity? {
        let now = Date()
        let calendar = AppDate.calendar
        let timeZone = AppDate.timeZone
        let start = calendar.startOfDay(for: now)

        print(
            "[HealthKit] fetchToday: " +
            "start=\(start) end=\(now) timeZone=\(timeZone.identifier)"
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

        let results = await (
            steps: steps,
            active: active,
            basal: basal,
            walking: walkingRunningDistance,
            cycling: cyclingDistance,
            swimming: swimmingDistance
        )

        var failed: [String] = []
        if case .failure = results.steps { failed.append("steps") }
        if case .failure = results.active { failed.append("activeEnergy") }
        if case .failure = results.basal { failed.append("basalEnergy") }
        if case .failure = results.walking { failed.append("walkingRunningDistance") }
        if case .failure = results.cycling { failed.append("cyclingDistance") }
        if case .failure = results.swimming { failed.append("swimmingDistance") }

        if !failed.isEmpty {
            print(
                "[HealthKit] fetchToday partial — failed metrics: " +
                failed.joined(separator: ", ")
            )
            logActivityAuthorizationStatuses()
        }

        // The card shows whatever could be read. `distanceMeters` stays `nil`
        // if any of its three sources failed: a partial sum would be misleading.
        let result = Self.makeActivity(
            date: dateFormatter.string(from: now),
            results: results
        )

        guard result.hasDisplayableMetric else {
            print("[HealthKit] fetchToday skipped — no metric could be read")
            return nil
        }

        print("[HealthKit] fetchToday result: \(result)")

        return result
    }

    private static func value(_ result: Result<Double, Error>) -> Double? {
        if case .success(let value) = result { return value }
        return nil
    }

    /// Distance is the sum of three queries. A failed source makes the total
    /// incomplete, so it is hidden instead of being shown as a real value.
    private static func totalDistance(
        walking: Result<Double, Error>,
        cycling: Result<Double, Error>,
        swimming: Result<Double, Error>
    ) -> Double? {
        guard
            case .success(let walking) = walking,
            case .success(let cycling) = cycling,
            case .success(let swimming) = swimming
        else { return nil }
        return walking + cycling + swimming
    }

    private static func makeActivity(
        date: String,
        results: (
            steps: Result<Double, Error>,
            active: Result<Double, Error>,
            basal: Result<Double, Error>,
            walking: Result<Double, Error>,
            cycling: Result<Double, Error>,
            swimming: Result<Double, Error>
        )
    ) -> DailyActivity {
        DailyActivity(
            date: date,
            steps: value(results.steps).map(Int.init),
            activeCalories: value(results.active),
            basalCalories: value(results.basal),
            distanceMeters: totalDistance(
                walking: results.walking,
                cycling: results.cycling,
                swimming: results.swimming
            )
        )
    }

    func fetchRange(from startDate: Date, to endDate: Date) async throws -> [DailyActivity] {
        let calendar = AppDate.calendar
        let timeZone = AppDate.timeZone

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
                "start=\(dayStart) end=\(dayEnd) timeZone=\(timeZone.identifier)"
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

            let fetched = await (
                steps: steps,
                active: active,
                basal: basal,
                walking: walkingRunningDistance,
                cycling: cyclingDistance,
                swimming: swimmingDistance
            )
            let entry = Self.makeActivity(
                date: dateFormatter.string(from: dayStart),
                results: fetched
            )
            if entry.hasDisplayableMetric {
                results.append(entry)
            } else {
                print("[HealthKit] fetchRange skipped day \(entry.date) — no metric could be read")
            }

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

                // The coordinator acknowledges this right after reading the
                // data. Network sync must not hold the completion handler.
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

    /// Acknowledges stored HealthKit observer deliveries. Call right after the
    /// HealthKit read, before starting the network sync.
    func completePendingObservations() {
        completionLock.lock()
        let completions = pendingCompletions
        pendingCompletions.removeAll()
        completionLock.unlock()

        for completion in completions {
            completion()
        }
    }


    /// A missing `sumQuantity` means "no samples in this window" and is a real
    /// zero. A query error is different: it must never be written to the backend
    /// as zero, because that would erase the user's actual activity.
    private func sum(
        _ identifier: HKQuantityTypeIdentifier,
        start: Date,
        end: Date,
        unit: HKUnit
    ) async -> Result<Double, Error> {

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
            ) { _, result, error in

                if let error {
                    // HKStatisticsQuery reports an empty window as error 11
                    // ("No data available"), not as a successful zero. That
                    // is a real zero, not a failed read: treating it as a
                    // failure makes perfectly healthy metrics disappear.
                    let nsError = error as NSError
                    if nsError.domain == HKError.errorDomain,
                       nsError.code == HKError.Code.errorNoData.rawValue {
                        print("[HealthKit] sum: no samples for \(identifier.rawValue) — using 0")
                        continuation.resume(returning: .success(0))
                        return
                    }

                    print(
                        "[HealthKit] sum failed: " +
                        "identifier=\(identifier.rawValue) error=\(error)"
                    )
                    continuation.resume(returning: .failure(error))
                    return
                }

                let value = result?
                    .sumQuantity()?
                    .doubleValue(for: unit)
                    ?? 0

                continuation.resume(returning: .success(value))
            }

            store.execute(query)
        }
    }
}
