import Foundation
import HealthKit


enum SleepHealthKitError: LocalizedError {

    case healthKitUnavailable

    var errorDescription: String? {
        switch self {
        case .healthKitUnavailable:
            return "HealthKit is not available on this device."
        }
    }
}

final class SleepHealthKitService: SleepHealthKitServiceProtocol {

    private let healthStore: HKHealthStore
    private let sleepType: HKCategoryType?
    private let heartRateType: HKQuantityType


    init(healthStore: HKHealthStore = HealthKitAuthorization.shared.sharedStore) {
        self.healthStore = healthStore
        self.heartRateType = HKQuantityType(.heartRate)
        self.sleepType = HKObjectType.categoryType(
            forIdentifier: .sleepAnalysis
        )
    }

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func permissionState() async -> HealthKitPermissionState {
        await HealthKitAuthorization.shared.permissionState(for: .sleep)
    }

    func requestAuthorization() async throws {
        guard isAvailable else {
            throw SleepHealthKitError.healthKitUnavailable
        }

        try await HealthKitAuthorization.shared.requestAuthorization()
    }

    func fetchHeartRateDuringSleep(
        from startDate: Date,
        to endDate: Date
    ) async throws -> [SleepHeartRatePoint] {

        guard isAvailable else {
            throw SleepHealthKitError.healthKitUnavailable
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        return try await withCheckedThrowingContinuation { continuation in

            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [
                    NSSortDescriptor(
                        key: HKSampleSortIdentifierStartDate,
                        ascending: true
                    )
                ]
            ) { _, samples, error in

                if let error {
                    continuation.resume(
                        throwing: error
                    )
                    return
                }

                let unit = HKUnit.count()
                    .unitDivided(by: .minute())

                let points = (samples ?? []).compactMap {
                    sample -> SleepHeartRatePoint? in

                    guard let quantitySample = sample as? HKQuantitySample else {
                        return nil
                    }

                    let bpm = quantitySample.quantity.doubleValue(
                        for: unit
                    )

                    guard bpm > 0 else {
                        return nil
                    }

                    return SleepHeartRatePoint(
                        date: quantitySample.startDate,
                        bpm: bpm
                    )
                }

                continuation.resume(
                    returning: points
                )
            }

            healthStore.execute(query)
        }
    }
    
    func fetchSleep(from startDate: Date, to endDate: Date) async throws -> HealthKitSleep? {
        guard isAvailable else{
            throw SleepHealthKitError.healthKitUnavailable
        }
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: []
        )

        let samples = try await fetchSamples(predicate: predicate)

        guard var sleep = aggregate(samples) else {
            return nil
        }

        sleep.heartRateAvg = try await fetchAverageHeartRate(
            from: sleep.startDate,
            to: sleep.endDate
        )

        return sleep
    }

    func fetchNights(from startDate: Date,
                     to endDate: Date) async throws -> [HealthKitSleep] {
        guard isAvailable else {
            throw SleepHealthKitError.healthKitUnavailable
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: []
        )
        let samples = try await fetchSamples(predicate: predicate)
        let grouped = Self.groupSamplesByNight(samples)

        var nights: [HealthKitSleep] = []
        for nightStart in grouped.keys.sorted() {
            guard let samples = grouped[nightStart],
                  var night = aggregate(samples)
            else { continue }

            night.heartRateAvg = try await fetchAverageHeartRate(
                from: night.startDate,
                to: night.endDate
            )
            nights.append(night)
        }
        return nights
    }

    func fetchSamples(predicate: NSPredicate) async throws -> [HKCategorySample]{
        guard let sleepType else {
            throw SleepHealthKitError.healthKitUnavailable
        }

        return try await withCheckedThrowingContinuation { continuation in

            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [
                    NSSortDescriptor(
                        key: HKSampleSortIdentifierStartDate,
                        ascending: true
                    )
                ]
            ) { _, samples, error in

                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let sleepSamples = samples as? [HKCategorySample] ?? []

                continuation.resume(
                    returning: sleepSamples
                )
            }

            healthStore.execute(query)
        }

    }

    private func aggregate(
        _ samples: [HKCategorySample]
    ) -> HealthKitSleep? {

        guard
            let startDate = samples.map(\.startDate).min(),
            let endDate = samples.map(\.endDate).max()
        else {
            return nil
        }

        let validSamples = samples.filter {
            $0.endDate.timeIntervalSince($0.startDate) > 0
        }

        let inBedSamples = Self.samples(matching: .inBed, in: validSamples)
        let awakeSamples = Self.samples(matching: .awake, in: validSamples)
        let coreSamples = Self.samples(matching: .asleepCore, in: validSamples)
        let deepSamples = Self.samples(matching: .asleepDeep, in: validSamples)
        let remSamples = Self.samples(matching: .asleepREM, in: validSamples)
        let unspecifiedSamples = Self.samples(matching: .asleepUnspecified, in: validSamples)

        let asleepSamples = coreSamples + deepSamples + remSamples + unspecifiedSamples

        let timeInBedSeconds = Self.mergedDuration(inBedSamples)
        let asleepSeconds = Self.mergedDuration(asleepSamples)
        let awakeSeconds = Self.mergedDuration(awakeSamples)
        let coreSeconds = Self.mergedDuration(coreSamples)
        let deepSeconds = Self.mergedDuration(deepSamples)
        let remSeconds = Self.mergedDuration(remSamples)
        let unspecifiedSeconds = Self.mergedDuration(unspecifiedSamples)

        guard timeInBedSeconds > 0 || asleepSeconds > 0 else {
            return nil
        }

        let awakenings = Self.countAwakenings(awakeSamples)

        let segments: [SleepStageSegment] = Self.mergedSegments(validSamples)

        let onsetLatency: TimeInterval?
        if let firstInBed = inBedSamples.map(\.startDate).min(),
           let firstAsleep = asleepSamples.map(\.startDate).min() {
            let latency = firstAsleep.timeIntervalSince(firstInBed)
            onsetLatency = latency > 0 ? latency : nil
        } else {
            onsetLatency = nil
        }

        let efficiency: Double?
        if timeInBedSeconds > 0 {
            efficiency = (asleepSeconds / timeInBedSeconds) * 100
        } else {
            let nightInterval = endDate.timeIntervalSince(startDate)
            efficiency = nightInterval > 0
                ? (asleepSeconds / nightInterval) * 100
                : nil
        }

        return HealthKitSleep(
            id: Self.nightID(start: startDate, end: endDate),
            startDate: startDate,
            endDate: endDate,
            timeInBedSeconds: timeInBedSeconds,
            asleepSeconds: asleepSeconds,
            awakeSeconds: awakeSeconds,
            coreSeconds: coreSeconds,
            deepSeconds: deepSeconds,
            remSeconds: remSeconds,
            unspecifiedSeconds: unspecifiedSeconds,
            awakenings: awakenings,
            segmentCount: segments.count,
            onsetLatencySeconds: onsetLatency,
            efficiency: efficiency,
            segments: segments
        )
    }

    private static func mergedSegments(
        _ samples: [HKCategorySample]
    ) -> [SleepStageSegment] {
        let sorted = samples.sorted { $0.startDate < $1.startDate }
        var result: [SleepStageSegment] = []

        for sample in sorted {
            let start = sample.startDate
            let end = sample.endDate
            let stage = Self.stage(for: sample)

            if let last = result.last,
               last.stage == stage,
               start <= last.endDate.addingTimeInterval(300) {
                result[result.count - 1] = SleepStageSegment(
                    id: last.id,
                    startDate: last.startDate,
                    endDate: max(last.endDate, end),
                    stage: stage
                )
            } else {
                result.append(SleepStageSegment(
                    id: UUID(),
                    startDate: start,
                    endDate: end,
                    stage: stage
                ))
            }
        }

        return result
    }

    private static func samples(
        matching value: HKCategoryValueSleepAnalysis,
        in samples: [HKCategorySample]
    ) -> [HKCategorySample] {
        samples.filter { $0.value == value.rawValue }
    }

    private static func mergedDuration(
        _ samples: [HKCategorySample]
    ) -> TimeInterval {
        let sorted = samples
            .map { ($0.startDate, $0.endDate) }
            .sorted { $0.0 < $1.0 }

        guard let first = sorted.first else { return 0 }

        var total: TimeInterval = 0
        var mergedStart = first.0
        var mergedEnd = first.1

        for (start, end) in sorted.dropFirst() {
            if start > mergedEnd {
                total += mergedEnd.timeIntervalSince(mergedStart)
                mergedStart = start
                mergedEnd = end
            } else {
                mergedEnd = max(mergedEnd, end)
            }
        }
        total += mergedEnd.timeIntervalSince(mergedStart)

        return max(total, 0)
    }

    private static func nightID(start: Date, end: Date) -> UUID {
        let t1 = UInt64(start.timeIntervalSinceReferenceDate * 1000)
        let t2 = UInt64(end.timeIntervalSinceReferenceDate * 1000)

        var bytes = [UInt8](repeating: 0, count: 16)
        for i in 0..<8 {
            bytes[i] = UInt8((t1 >> (8 * (7 - i))) & 0xFF)
        }
        for i in 0..<8 {
            bytes[8 + i] = UInt8((t2 >> (8 * (7 - i))) & 0xFF)
        }

        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80

        return UUID(
            uuid: (
                bytes[0], bytes[1], bytes[2], bytes[3],
                bytes[4], bytes[5], bytes[6], bytes[7],
                bytes[8], bytes[9], bytes[10], bytes[11],
                bytes[12], bytes[13], bytes[14], bytes[15]
            )
        )
    }

    func fetchAverageHeartRate(
        from startDate: Date,
        to endDate: Date
    ) async throws -> Double? {
        guard isAvailable else {
            throw SleepHealthKitError.healthKitUnavailable
        }

        let type = heartRateType
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )
        let unit = HKUnit.count().unitDivided(by: .minute())

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: [.discreteAverage]
            ) { _, stats, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(
                    returning: stats?.averageQuantity()?.doubleValue(for: unit)
                )
            }

            healthStore.execute(query)
        }
    }
    
    

    private static func groupSamplesByNight(
        _ samples: [HKCategorySample]
    ) -> [Date: [HKCategorySample]] {
        let calendar = Calendar.current
        var groups: [Date: [HKCategorySample]] = [:]

        for sample in samples {
            guard let noon = calendar.date(
                bySettingHour: 12, minute: 0, second: 0, of: sample.startDate
            ) else { continue }

            let windowStart = calendar.component(.hour, from: sample.startDate) < 12
                ? (calendar.date(byAdding: .day, value: -1, to: noon) ?? noon)
                : noon

            groups[windowStart, default: []].append(sample)
        }

        return groups
    }

    private static func countAwakenings(
        _ awakeSamples: [HKCategorySample]
    ) -> Int {
        let awake = awakeSamples.sorted { $0.startDate < $1.startDate }

        guard let first = awake.first else { return 0 }

        var count = 1
        var clusterEnd = first.endDate

        for sample in awake.dropFirst() {
            if sample.startDate > clusterEnd.addingTimeInterval(120) {
                count += 1
            }
            clusterEnd = max(clusterEnd, sample.endDate)
        }
        return count
    }

    private static func stage(
        for sample: HKCategorySample
    ) -> SleepStage {
        guard let value = HKCategoryValueSleepAnalysis(
            rawValue: sample.value
        ) else {
            return .unspecified
        }
        switch value {
        case .inBed:
            return .inBed
        case .awake:
            return .awake
        case .asleepCore:
            return .core
        case .asleepDeep:
            return .deep
        case .asleepREM:
            return .rem
        case .asleepUnspecified:
            return .unspecified
        default:
            return .unspecified
        }
    }
}
