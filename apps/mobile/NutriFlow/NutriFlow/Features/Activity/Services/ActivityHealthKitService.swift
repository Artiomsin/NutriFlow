import Foundation
import HealthKit

/// Result of a single HealthKit statistics query.
///
/// `.empty` means the query succeeded but there are no samples for the period
/// yet — normal in the first seconds after midnight. It must not become an
/// error: the day simply has zero steps so far. `.failed` means the read
/// really failed, so the field stays `nil` and is omitted from the sync payload.
private enum MetricRead {
    case value(Double)
    case empty
    case failed(Error)

    var syncedValue: Double? {
        switch self {
        case .value(let number): return number
        case .empty: return 0
        case .failed: return nil
        }
    }

    var isFailed: Bool {
        if case .failed = self { return true }
        return false
    }

    var hasSamples: Bool {
        if case .value = self { return true }
        return false
    }
}

/// Thrown only when not a single activity query could be executed. That is a
/// real read failure (for example revoked access); an empty day is not.
enum ActivityHealthKitReadError: Error {
    case allMetricsFailed
}

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


    /// A successful read always returns a record: metrics without samples yet
    /// (normal right after midnight) are zero, metrics whose query failed are
    /// `nil` and omitted from the payload. Throws when every query fails.
    func fetchToday() async throws -> DailyActivity {
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
        if results.steps.isFailed { failed.append("steps") }
        if results.active.isFailed { failed.append("activeEnergy") }
        if results.basal.isFailed { failed.append("basalEnergy") }
        if results.walking.isFailed { failed.append("walkingRunningDistance") }
        if results.cycling.isFailed { failed.append("cyclingDistance") }
        if results.swimming.isFailed { failed.append("swimmingDistance") }

        if !failed.isEmpty {
            print(
                "[HealthKit] fetchToday partial — failed metrics: " +
                failed.joined(separator: ", ")
            )
            logActivityAuthorizationStatuses()
        }

        let reads = [
            results.steps,
            results.active,
            results.basal,
            results.walking,
            results.cycling,
            results.swimming
        ]

        // Every query failed — this is a real read error. An empty result from
        // all six queries (no samples after midnight) is a valid zero day.
        guard !reads.allSatisfy({ $0.isFailed }) else {
            print("[HealthKit] fetchToday failed — no metric could be read")
            throw ActivityHealthKitReadError.allMetricsFailed
        }

        // Successful queries with no samples become zero; only failed queries
        // stay nil and are omitted from the JSON payload.
        let result = Self.makeActivity(
            date: dateFormatter.string(from: now),
            results: results
        )

        print("[HealthKit] fetchToday result: \(result)")

        return result
    }

    /// Distance is the sum of three queries. A failed source makes the total
    /// incomplete, so it is hidden instead of being shown as a real value.
    /// A successful query without samples contributes zero; requiring samples
    /// from every activity type would hide a person's walking distance whenever
    /// they did not cycle or swim that day.
    private static func totalDistance(
        walking: MetricRead,
        cycling: MetricRead,
        swimming: MetricRead
    ) -> Double? {
        let sources = [walking, cycling, swimming]
        guard !sources.contains(where: { $0.isFailed }) else { return nil }
        return sources.reduce(0) { $0 + ($1.syncedValue ?? 0) }
    }

    private static func makeActivity(
        date: String,
        results: (
            steps: MetricRead,
            active: MetricRead,
            basal: MetricRead,
            walking: MetricRead,
            cycling: MetricRead,
            swimming: MetricRead
        )
    ) -> DailyActivity {
        DailyActivity(
            date: date,
            steps: results.steps.syncedValue.map(Int.init),
            activeCalories: results.active.syncedValue,
            basalCalories: results.basal.syncedValue,
            distanceMeters: totalDistance(
                walking: results.walking,
                cycling: results.cycling,
                swimming: results.swimming
            )
        )
    }

    func hasLimitedHistory() async -> Bool {
        guard isAvailable else { return false }

        // Before iOS 27, HealthKit does not expose whether the authorized
        // history is truncated. Treat it as limited so a partial backfill
        // is never recorded as complete.
        guard #available(iOS 27.0, *) else {
            return true
        }

        let types = Set(activityTypesToRead.map { $0 as HKObjectType })
        do {
            return !(try await store.earliestAuthorizedSampleDate(for: types)).isEmpty
        } catch {
            return true
        }
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
            let date = dateFormatter.string(from: dayStart)
            let reads = [
                fetched.steps,
                fetched.active,
                fetched.basal,
                fetched.walking,
                fetched.cycling,
                fetched.swimming
            ]

            // Backfill skips days with no samples so it never writes zero
            // activity for days the person did not carry the phone. A day with
            // at least one real sample is synced; its empty metrics become zero.
            if reads.contains(where: { $0.hasSamples }) {
                results.append(
                    Self.makeActivity(date: date, results: fetched)
                )
            } else {
                print("[HealthKit] fetchRange skipped day \(date) — no samples")
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

                // Store the completion before scheduling the coordinator. The
                // coordinator can complete its read immediately, so reversing
                // this order could leave this delivery unacknowledged.
                self?.completionLock.lock()
                self?.pendingCompletions.append(completionHandler)
                self?.completionLock.unlock()

                self?.onActivityChanged?()
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


    /// `.empty` means the query ran but had no samples (a zero day).
    /// `.failed` means an actual error, so the field is omitted from the
    /// payload instead of being written as zero. `errorNoData` is an empty
    /// result, not a failure — HealthKit returns it for a day with no samples.
    private func sum(
        _ identifier: HKQuantityTypeIdentifier,
        start: Date,
        end: Date,
        unit: HKUnit
    ) async -> MetricRead {

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
                    let nsError = error as NSError
                    if nsError.domain == HKError.errorDomain,
                       nsError.code == HKError.Code.errorNoData.rawValue {
                        continuation.resume(returning: .empty)
                        return
                    }

                    print(
                        "[HealthKit] sum failed: " +
                        "identifier=\(identifier.rawValue) error=\(error)"
                    )
                    continuation.resume(returning: .failed(error))
                    return
                }

                guard let value = result?
                    .sumQuantity()?
                    .doubleValue(for: unit)
                else {
                    continuation.resume(returning: .empty)
                    return
                }

                continuation.resume(returning: .value(value))
            }

            store.execute(query)
        }
    }
}
