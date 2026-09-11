import Foundation
import HealthKit

final class WorkoutHealthKitService: NSObject, WorkoutHealthKitServiceProtocol {

    private let store = HealthKitAuthorization.shared.sharedStore
    private var rawWorkouts: [UUID: HKWorkout] = [:]

    private let workoutType = HKObjectType.workoutType()
    private let heartRateType = HKQuantityType(.heartRate)


    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }


    func permissionState() async -> HealthKitPermissionState {
        await HealthKitAuthorization.shared.permissionState(for: .workout)
    }

    func requestAuthorization() async throws {
        guard isAvailable else {
            return
        }

        try await HealthKitAuthorization.shared.requestAuthorization()
    }


    func fetchWorkouts(
        from startDate: Date,
        to endDate: Date
    ) async -> [HealthKitWorkout] {

        guard isAvailable else {
            return []
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierStartDate,
            ascending: false
        )

        let workouts: [HKWorkout] = await withCheckedContinuation(isolation: MainActor.shared) { continuation in

            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in

                if let error {
                    print("[WorkoutHealthKit] workouts query error: \(error)")
                    continuation.resume(returning: [])
                    return
                }

                continuation.resume(returning: (samples as? [HKWorkout]) ?? [])
            }

            store.execute(query)
        }

        for workout in workouts {
            rawWorkouts[workout.uuid] = workout
        }
        return workouts.map { Self.healthKitWorkout(from: $0) }
    }

    func fetchLatestWorkout() async -> HealthKitWorkout? {
        guard isAvailable else { return nil }

        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierStartDate,
            ascending: false
        )

        let fetched: HKWorkout? = await withCheckedContinuation(isolation: MainActor.shared) { continuation in
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                guard
                    error == nil,
                    let workout = (samples as? [HKWorkout])?.first
                else {
                    print("[WorkoutHealthKit] fetchLatestWorkout: error=\(String(describing: error)) samplesCount=\((samples as? [HKWorkout])?.count ?? -1)")
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: workout)
            }

            store.execute(query)
        }

        guard let workout = fetched else { return nil }
        rawWorkouts[workout.uuid] = workout
        return Self.healthKitWorkout(from: workout)
    }


    func fetchHeartRateWorkout(for workout: HealthKitWorkout) async -> [HeartRatePoint] {
        guard isAvailable else { return [] }

        let type = HKQuantityType(.heartRate)
        let predicate = samplePredicate(for: workout)
        let unit = HKUnit.count().unitDivided(by: .minute())

        let samples = await fetchSamples(type: type, predicate: predicate)
        let points = samples.map { sample in
            HeartRatePoint(
                startDate: sample.startDate,
                bpm: sample.quantity.doubleValue(for: unit)
            )
        }
        return Self.downsized(points, maxPoints: 300)
    }

    func fetchWorkoutSeries(
        kind: WorkoutSeriesKind,
        workout: HealthKitWorkout
    ) async -> [WorkoutSeriesPoint] {
        guard isAvailable else { return [] }

        let activityType = rawWorkouts[workout.id]?.workoutActivityType ?? .running
        let identifiers: [HKQuantityTypeIdentifier]
        let unit: HKUnit
        switch kind {
        case .speed:
            identifiers = Self.speedIds(for: activityType)
            unit = Self.speedUnit
        case .cadence:
            identifiers = Self.cadenceIdentifiers
            unit = Self.cadenceUnit
        case .power:
            identifiers = Self.powerIds(for: activityType)
            unit = .watt()
        }

        guard !identifiers.isEmpty else { return [] }

        let predicate = samplePredicate(for: workout)
        var combined: [WorkoutSeriesPoint] = []
        for identifier in identifiers {
            let samples = await fetchSamples(type: HKQuantityType(identifier), predicate: predicate)
            combined.append(contentsOf: samples.map { sample in
                WorkoutSeriesPoint(
                    date: sample.startDate,
                    value: sample.quantity.doubleValue(for: unit)
                )
            })
        }
        if combined.isEmpty { return [] }
        combined.sort { $0.date < $1.date }
        return Self.downsized(combined, maxPoints: 300)
    }

    private func samplePredicate(for workout: HealthKitWorkout) -> NSPredicate {
        if let raw = rawWorkouts[workout.id] {
            return HKQuery.predicateForObjects(from: raw)
        }
        return HKQuery.predicateForSamples(
            withStart: workout.startDate,
            end: workout.endDate,
            options: .strictStartDate
        )
    }

    private func fetchSamples(
        type: HKQuantityType,
        predicate: NSPredicate
    ) async -> [HKQuantitySample] {
        await withCheckedContinuation(isolation: MainActor.shared) { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [
                    NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
                ]
            ) { _, samples, _ in
                continuation.resume(returning: (samples as? [HKQuantitySample]) ?? [])
            }
            store.execute(query)
        }
    }

    private static func downsized<T>(_ points: [T], maxPoints: Int) -> [T] {
        guard points.count > maxPoints else { return points }
        let step = Double(points.count - 1) / Double(maxPoints - 1)
        var result: [T] = []
        result.reserveCapacity(maxPoints)
        for i in 0..<maxPoints {
            let index = Int((Double(i) * step).rounded())
            result.append(points[min(index, points.count - 1)])
        }
        return result
    }


    private enum HRMetadataKey {
        static let avg = "NutriFlow.HR.avg"
        static let max = "NutriFlow.HR.max"
        static let min = "NutriFlow.HR.min"
    }

    private enum AppleHRMetadataKey {
        static let avg = "HKAverageHeartRate"
        static let max = "HKMaximumHeartRate"
        static let min = "HKMinimumHeartRate"
    }

    private static func healthKitWorkout(from workout: HKWorkout) -> HealthKitWorkout {
        let result = HealthKitWorkout(
            id: workout.uuid,
            workoutType: Self.workoutName(workout.workoutActivityType),
            startDate: workout.startDate,
            endDate: workout.endDate,
            durationSeconds: workout.duration,
            caloriesBurned: Self.caloriesBurned(for: workout),
            distanceMeters: Self.distanceMeters(for: workout),
            heartRateAvg: Self.heartRateAvg(for: workout),
            heartRateMax: Self.heartRateMax(for: workout),
            heartRateMin: Self.heartRateMin(for: workout),
            avgSpeedMps: Self.averageStat(workout, identifiers: Self.speedIds(for: workout.workoutActivityType), unit: Self.speedUnit) ?? Self.mpsMetadata(workout, key: HKMetadataKeyAverageSpeed),
            maxSpeedMps: Self.maxStat(workout, identifiers: Self.speedIds(for: workout.workoutActivityType), unit: Self.speedUnit) ?? Self.mpsMetadata(workout, key: HKMetadataKeyMaximumSpeed),
            avgCadence: Self.averageStat(workout, identifiers: Self.cadenceIdentifiers, unit: Self.cadenceUnit),
            maxCadence: Self.maxStat(workout, identifiers: Self.cadenceIdentifiers, unit: Self.cadenceUnit),
            avgPowerWatts: Self.averageStat(workout, identifiers: Self.powerIds(for: workout.workoutActivityType), unit: .watt()),
            maxPowerWatts: Self.maxStat(workout, identifiers: Self.powerIds(for: workout.workoutActivityType), unit: .watt()),
            elevationGainMeters: Self.positiveDouble(workout, key: HKMetadataKeyElevationAscended),
            steps: Self.steps(for: workout),
            indoor: Self.indoor(for: workout),
            details: Self.workoutDetails(from: workout)
        )

        print(
            "[WorkoutHK] metrics for \(result.workoutType): " +
            "calories=\(result.caloriesBurned.map { "\($0)" } ?? "nil") " +
            "distance=\(result.distanceMeters.map { "\($0)" } ?? "nil") " +
            "hrAvg=\(result.heartRateAvg.map { "\($0)" } ?? "nil") " +
            "avgSpeed=\(result.avgSpeedMps.map { "\($0)" } ?? "nil") " +
            "maxSpeed=\(result.maxSpeedMps.map { "\($0)" } ?? "nil") " +
            "avgCadence=\(result.avgCadence.map { "\($0)" } ?? "nil") " +
            "avgPower=\(result.avgPowerWatts.map { "\($0)" } ?? "nil") " +
            "elevation=\(result.elevationGainMeters.map { "\($0)" } ?? "nil") " +
            "steps=\(result.steps.map { "\($0)" } ?? "nil") " +
            "indoor=\(result.indoor.map { "\($0)" } ?? "nil") " +
            "details=\(String(describing: result.details))"
        )

        return result
    }

    private static func workoutDetails(from workout: HKWorkout) -> WorkoutDetails? {
        let metadata = workout.metadata
        var details = WorkoutDetails()

        if let raw = metadata?[HKMetadataKeySwimmingStrokeStyle] as? NSNumber {
            details.stroke = Self.swimmingStrokeName(raw.intValue)
        }
        if let raw = metadata?[HKMetadataKeySwimmingLocationType] as? NSNumber {
            details.water = raw.intValue == 2 ? "openWater" : raw.intValue == 1 ? "pool" : "unknown"
        }
        if let lap = metadata?[HKMetadataKeyLapLength] as? NSNumber {
            details.lapLengthMeters = lap.doubleValue
        }
        if let swolf = metadata?[HKMetadataKeySWOLFScore] as? NSNumber {
            details.swolf = swolf.doubleValue
        }
        if let ascended = metadata?[HKMetadataKeyElevationAscended] as? NSNumber, ascended.doubleValue != 0 {
            details.elevationAscended = ascended.doubleValue
        }
        if let descended = metadata?[HKMetadataKeyElevationDescended] as? NSNumber, descended.doubleValue != 0 {
            details.elevationDescended = descended.doubleValue
        }
        if let mets = metadata?[HKMetadataKeyAverageMETs] as? NSNumber {
            details.avgMETs = mets.doubleValue
        }

        return details.isEmpty ? nil : details
    }

    private static func swimmingStrokeName(_ raw: Int) -> String {
        switch raw {
        case 2: return "Freestyle"
        case 3: return "Backstroke"
        case 4: return "Breaststroke"
        case 5: return "Butterfly"
        case 1: return "Mixed"
        default: return "Unknown"
        }
    }

    private static func heartRateAvg(for workout: HKWorkout) -> Double? {
        let stats = workout.statistics(for: HKQuantityType(.heartRate))
        if let value = stats?.averageQuantity()?.doubleValue(for: Self.heartRateUnit), value > 0 {
            return value
        }
        return metadataDouble(workout, key: AppleHRMetadataKey.avg) ?? metadataDouble(workout, key: HRMetadataKey.avg)
    }

    private static func heartRateMax(for workout: HKWorkout) -> Double? {
        let stats = workout.statistics(for: HKQuantityType(.heartRate))
        if let value = stats?.maximumQuantity()?.doubleValue(for: Self.heartRateUnit), value > 0 {
            return value
        }
        return metadataDouble(workout, key: AppleHRMetadataKey.max) ?? metadataDouble(workout, key: HRMetadataKey.max)
    }

    private static func heartRateMin(for workout: HKWorkout) -> Double? {
        let stats = workout.statistics(for: HKQuantityType(.heartRate))
        if let value = stats?.minimumQuantity()?.doubleValue(for: Self.heartRateUnit), value > 0 {
            return value
        }
        return metadataDouble(workout, key: AppleHRMetadataKey.min) ?? metadataDouble(workout, key: HRMetadataKey.min)
    }

    private static let heartRateUnit = HKUnit.count().unitDivided(by: .minute())

    private static func steps(for workout: HKWorkout) -> Int? {
        guard let value = workout.statistics(for: HKQuantityType(.stepCount))?
            .sumQuantity()?.doubleValue(for: .count()),
            value > 0
        else { return nil }
        return Int(value)
    }

    private static func indoor(for workout: HKWorkout) -> Bool? {
        guard let raw = workout.metadata?[HKMetadataKeyIndoorWorkout] as? NSNumber else { return nil }
        return raw.boolValue
    }

    private static func metadataDouble(_ workout: HKWorkout, key: String) -> Double? {
        guard let value = workout.metadata?[key] else { return nil }
        if let number = value as? NSNumber {
            return number.doubleValue
        }
        if let quantity = value as? HKQuantity {
            return quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        }
        return nil
    }

    private static func mpsMetadata(_ workout: HKWorkout, key: String) -> Double? {
        guard let value = workout.metadata?[key] as? NSNumber else { return nil }
        let mps = value.doubleValue
        return mps > 0 ? mps : nil
    }

    private static var speedUnit: HKUnit {
        .meter().unitDivided(by: .second())
    }

    private static var cadenceUnit: HKUnit {
        .count().unitDivided(by: .minute())
    }

    private static let distanceIdentifiers: [HKQuantityTypeIdentifier] = [
        .distanceWalkingRunning,
        .distanceCycling,
        .distanceSwimming,
        .distanceCrossCountrySkiing,
        .distanceDownhillSnowSports,
        .distanceWheelchair,
        .distancePaddleSports
    ]

    private static let cadenceIdentifiers: [HKQuantityTypeIdentifier] = [
        .cyclingCadence
    ]

    private static func speedIds(for activityType: HKWorkoutActivityType) -> [HKQuantityTypeIdentifier] {
        switch activityType {
        case .cycling: return [.cyclingSpeed]
        case .walking: return [.walkingSpeed]
        case .crossCountrySkiing: return [.crossCountrySkiingSpeed]
        default: return [.runningSpeed]
        }
    }

    private static func powerIds(for activityType: HKWorkoutActivityType) -> [HKQuantityTypeIdentifier] {
        if activityType == .cycling {
            return [.cyclingPower]
        }
        return [.runningPower]
    }

    private static func averageStat(
        _ workout: HKWorkout,
        identifiers: [HKQuantityTypeIdentifier],
        unit: HKUnit
    ) -> Double? {
        for identifier in identifiers {
            let type = HKQuantityType(identifier)
            if let value = workout.statistics(for: type)?.averageQuantity()?.doubleValue(for: unit),
               value > 0 {
                return value
            }
        }
        return nil
    }

    private static func maxStat(
        _ workout: HKWorkout,
        identifiers: [HKQuantityTypeIdentifier],
        unit: HKUnit
    ) -> Double? {
        for identifier in identifiers {
            let type = HKQuantityType(identifier)
            if let value = workout.statistics(for: type)?.maximumQuantity()?.doubleValue(for: unit),
               value > 0 {
                return value
            }
        }
        return nil
    }

    private static func positiveDouble(_ workout: HKWorkout, key: String) -> Double? {
        guard let value = workout.metadata?[key] as? NSNumber else { return nil }
        let result = value.doubleValue
        return result >= 0 ? result : nil
    }

    private static func caloriesBurned(for workout: HKWorkout) -> Double? {
        workout.statistics(for: HKQuantityType(.activeEnergyBurned))?
            .sumQuantity()?
            .doubleValue(for: .kilocalorie())
    }

    private static func distanceMeters(for workout: HKWorkout) -> Double? {
        for identifier in Self.distanceIdentifiers {
            let type = HKQuantityType(identifier)
            if let value = workout.statistics(for: type)?.sumQuantity()?.doubleValue(for: .meter()),
               value > 0 {
                return value
            }
        }
        if let total = workout.totalDistance {
            let value = total.doubleValue(for: .meter())
            if value > 0 {
                return value
            }
        }
        return nil
    }

    private static func workoutName(
        _ type: HKWorkoutActivityType
    ) -> String {

        switch type {
        case .running:
            return "Running"
        case .walking:
            return "Walking"
        case .cycling:
            return "Cycling"
        case .traditionalStrengthTraining:
            return "Strength Training"
        case .functionalStrengthTraining:
            return "Functional Strength Training"
        case .yoga:
            return "Yoga"
        case .swimming:
            return "Swimming"
        case .hiking:
            return "Hiking"
        case .elliptical:
            return "Elliptical"
        case .rowing:
            return "Rowing"
        case .stairClimbing:
            return "Stair Climbing"
        case .highIntensityIntervalTraining:
            return "HIIT"
        case .coreTraining:
            return "Core Training"
        case .flexibility:
            return "Flexibility"
        case .mixedCardio:
            return "Mixed Cardio"
        case .cooldown:
            return "Cooldown"
        case .jumpRope:
            return "Jump Rope"
        default:
            return "Workout"
        }
    }
}
