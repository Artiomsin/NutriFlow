import Foundation
import HealthKit

final class HealthKitService: HealthKitServiceProtocol {

    private let store = HKHealthStore()

    private let typesToRead: Set<HKQuantityType> = [
        HKQuantityType(.stepCount),
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.distanceWalkingRunning),
    ]

    private var observers: [HKObserverQuery] = []

    var onActivityChanged: (() -> Void)?

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone.current
        return f
    }()

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }



    func requestAuthorization() async throws {
        guard isAvailable else { return }
        print("[HealthKit] requesting authorization for read types: \(typesToRead.map { $0.identifier })")
        try await store.requestAuthorization(toShare: [], read: typesToRead)
        print("[HealthKit] requestAuthorization returned")
    }


    func fetchToday() async -> DailyActivity {
        let now = Date()
        let start = Calendar.current.startOfDay(for: now)
        print("[HealthKit] fetchToday: start=\(start) end=\(now)")

        async let steps = sum(.stepCount, start: start, end: now, unit: .count())
        async let active = sum(.activeEnergyBurned, start: start, end: now, unit: .kilocalorie())
        async let distance = sum(.distanceWalkingRunning, start: start, end: now, unit: .meter())

        let result = DailyActivity(
            date: Self.dateFormatter.string(from: now),
            steps: Int(await steps),
            activeCalories: Int(await active),
            distanceMeters: await distance
        )
        print("[HealthKit] fetchToday result: \(result)")
        return result
    }

    

    func enableBackgroundDelivery() async throws {
        guard isAvailable else { return }
        for type in typesToRead {
            try await store.enableBackgroundDelivery(for: type, frequency: .hourly)
        }
        print("[HealthKit] enabled background delivery")
    }



    func startObserving() {
        guard isAvailable else { return }
        observers.removeAll()
        for type in typesToRead {
            let query = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, completionHandler, error in
                if let error {
                    print("[HealthKit] observer error: \(error)")
                    completionHandler()
                    return
                }
                print("[HealthKit] observer fired for \(type.identifier)")
                Task {
                    self?.onActivityChanged?()
                    completionHandler()
                }
            }
            store.execute(query)
            observers.append(query)
        }
        print("[HealthKit] observers registered")
    }

    func stopObserving() {
        for query in observers {
            store.stop(query)
        }
        observers.removeAll()
        onActivityChanged = nil
        print("[HealthKit] observers stopped")
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
            ) { _, result, error in
                if let error {
                    print("[HealthKit] sum error for \(identifier): \(error)")
                }
                let value = result?.sumQuantity()?.doubleValue(for: unit) ?? 0
                print("[HealthKit] sum \(identifier) = \(value) \(unit.unitString)")
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }
}
