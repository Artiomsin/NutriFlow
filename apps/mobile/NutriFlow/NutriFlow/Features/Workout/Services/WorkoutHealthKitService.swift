import Foundation
import HealthKit

final class WorkoutHealthKitService: NSObject, WorkoutHealthKitServiceProtocol {

    private let store = HKHealthStore()

    private let workoutType = HKObjectType.workoutType()
    private let heartRateType = HKQuantityType(.heartRate)

    // MARK: - Availability

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    // MARK: - Authorization

    func requestAuthorization() async throws {
        guard isAvailable else {
            return
        }

        workoutAuthRequested = true
        UserDefaults.standard.set(true, forKey: "hasRequestedHealthAuth")

        try await store.requestAuthorization(
            toShare: [workoutType],
            read: [workoutType, heartRateType]
        )
    }

    // MARK: - History

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

        return await withCheckedContinuation(isolation: MainActor.shared) { continuation in

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

                let workouts = (samples as? [HKWorkout]) ?? []
                let result = workouts.map { workout in
                    Self.healthKitWorkout(from: workout)
                }
                continuation.resume(returning: result)
            }

            store.execute(query)
        }
    }

    func fetchLatestWorkout() async -> HealthKitWorkout? {
        guard isAvailable else { return nil }

        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierStartDate,
            ascending: false
        )

        return await withCheckedContinuation(isolation: MainActor.shared) { continuation in
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
                continuation.resume(returning: Self.healthKitWorkout(from: workout))
            }

            store.execute(query)
        }
    }

    // MARK: - Heart Rate Series

    func fetchHeartRateWorkout(
        from startDate: Date,
        to endDate: Date
    ) async -> [HeartRatePoint] {
        guard isAvailable else { return [] }

        let type = HKQuantityType(.heartRate)
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        return await withCheckedContinuation(isolation: MainActor.shared) { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [
                    NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
                ]
            ) { _, samples, _ in
                let unit = HKUnit.count().unitDivided(by: .minute())
                let points = (samples as? [HKQuantitySample] ?? []).compactMap { sample in
                    HeartRatePoint(
                        startDate: sample.startDate,
                        bpm: sample.quantity.doubleValue(for: unit)
                    )
                }
                continuation.resume(returning: points)
            }
            store.execute(query)
        }
    }

    // MARK: - Live Workout

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

    private var liveSession: HKWorkoutSession?
    private var liveBuilder: HKLiveWorkoutBuilder?

    var onLiveMetrics: ((LiveWorkoutMetrics) -> Void)?
    var onSessionFailed: ((String) -> Void)?

    @MainActor
    func startLiveWorkout(kind: TrackableWorkout.Kind) async throws {
        guard isAvailable else {
            throw WorkoutHealthKitLiveError.unavailable
        }
        guard liveSession == nil else {
            throw WorkoutHealthKitLiveError.alreadyStarted
        }

        if store.authorizationStatus(for: workoutType) != .sharingAuthorized {
            try await requestAuthorization()
        }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = Self.activityType(for: kind)
        configuration.locationType = .indoor

        let session = try HKWorkoutSession(
            healthStore: store,
            configuration: configuration
        )
        let builder = session.associatedWorkoutBuilder()

        session.delegate = self
        builder.delegate = self

        liveSession = session
        liveBuilder = builder

        do {
            guard liveSession === session, liveBuilder === builder else {
                session.end()
                throw WorkoutHealthKitLiveError.notStarted
            }
            session.startActivity(with: Date())
            try await builder.beginCollection(at: Date())
        } catch {
            session.end()
            liveSession = nil
            liveBuilder = nil
            throw error
        }
    }

 
    func pauseLiveWorkout() {
        liveSession?.pause()
    }


    func resumeLiveWorkout() {
        liveSession?.resume()
    }

  
    func cancelLiveWorkout() {
        guard let session = liveSession, let builder = liveBuilder else { return }
        session.end()
        builder.discardWorkout()
        liveSession = nil
        liveBuilder = nil
    }

   
    func endLiveWorkout() async throws -> HealthKitWorkout {
        guard let session = liveSession, let builder = liveBuilder else {
            throw WorkoutHealthKitLiveError.notStarted
        }

        session.end()
        try await builder.endCollection(at: Date())
        try await attachHeartRateMetadata(to: builder)

        guard let workout = try await builder.finishWorkout() else {
            throw WorkoutHealthKitLiveError.noWorkout
        }

        liveSession = nil
        liveBuilder = nil

        return Self.healthKitWorkout(from: workout)
    }

    private func attachHeartRateMetadata(to builder: HKLiveWorkoutBuilder) async throws {
        var metadata: [String: Any] = [:]
        let unit = HKUnit.count().unitDivided(by: .minute())

        if let statistics = builder.statistics(for: HKQuantityType(.heartRate)) {
            if let avg = statistics.averageQuantity()?.doubleValue(for: unit) {
                metadata[HRMetadataKey.avg] = avg
            }
            if let max = statistics.maximumQuantity()?.doubleValue(for: unit) {
                metadata[HRMetadataKey.max] = max
            }
            if let min = statistics.minimumQuantity()?.doubleValue(for: unit) {
                metadata[HRMetadataKey.min] = min
            }
        }

        guard !metadata.isEmpty else { return }
        try await builder.addMetadata(metadata)
    }

    // MARK: - Permission

    private static let workoutAuthRequestedKey = "hasRequestedWorkoutAuth"

    private var workoutAuthRequested: Bool {
        get { UserDefaults.standard.bool(forKey: Self.workoutAuthRequestedKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.workoutAuthRequestedKey) }
    }

    func workoutPermissionState() -> WorkoutPermissionState {
        guard isAvailable else { return .denied }

        switch store.authorizationStatus(for: workoutType) {
        case .sharingAuthorized:
            return .authorized
        case .notDetermined:
            return workoutAuthRequested ? .authorized : .notDetermined
        default:
            return workoutAuthRequested ? .authorized : .denied
        }
    }

    // MARK: - Mappers

    private static func healthKitWorkout(from workout: HKWorkout) -> HealthKitWorkout {
        HealthKitWorkout(
            id: workout.uuid,
            workoutType: Self.workoutName(workout.workoutActivityType),
            startDate: workout.startDate,
            endDate: workout.endDate,
            durationSeconds: workout.duration,
            caloriesBurned: Self.caloriesBurned(for: workout),
            distanceMeters: Self.distanceMeters(for: workout),
            heartRateAvg: Self.heartRateStat(workout, key: HRMetadataKey.avg, appleKey: AppleHRMetadataKey.avg),
            heartRateMax: Self.heartRateStat(workout, key: HRMetadataKey.max, appleKey: AppleHRMetadataKey.max),
            heartRateMin: Self.heartRateStat(workout, key: HRMetadataKey.min, appleKey: AppleHRMetadataKey.min)
        )
    }

    private static func heartRateStat(
        _ workout: HKWorkout,
        key: String,
        appleKey: String
    ) -> Double? {
        metadataDouble(workout, key: key) ?? metadataDouble(workout, key: appleKey)
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

    private static func activityType(for kind: TrackableWorkout.Kind) -> HKWorkoutActivityType {
        switch kind {
        case .run: return .running
        case .walk: return .walking
        case .cycle: return .cycling
        case .swim: return .swimming
        case .functional: return .functionalStrengthTraining
        }
    }


    private func publishLiveMetrics(from builder: HKLiveWorkoutBuilder?) {
        guard let builder, let session = liveSession else {
            onLiveMetrics?(.empty)
            return
        }

        let unit = HKUnit.count().unitDivided(by: .minute())
        let metrics = LiveWorkoutMetrics(
            elapsedSeconds: Date().timeIntervalSince(session.startDate ?? Date()),
            activeCalories:
                builder.statistics(for: HKQuantityType(.activeEnergyBurned))?
                    .sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0,
            distanceMeters: Self.liveDistance(builder) ?? 0,
            heartRateBPM:
                builder.statistics(for: HKQuantityType(.heartRate))?
                    .mostRecentQuantity()?.doubleValue(for: unit)
        )
        onLiveMetrics?(metrics)
    }

    private static func liveDistance(_ builder: HKLiveWorkoutBuilder) -> Double? {
        let identifiers: [HKQuantityTypeIdentifier] = [
            .distanceWalkingRunning,
            .distanceCycling,
            .distanceSwimming
        ]
        for identifier in identifiers {
            let type = HKQuantityType(identifier)
            if let value = builder.statistics(for: type)?.sumQuantity()?.doubleValue(for: .meter()),
               value > 0 {
                return value
            }
        }
        return nil
    }

    private static func caloriesBurned(for workout: HKWorkout) -> Double? {
        workout.statistics(
            for: HKQuantityType(.activeEnergyBurned)
        )?
            .sumQuantity()?
            .doubleValue(for: .kilocalorie())
    }

    private static func distanceMeters(for workout: HKWorkout) -> Double? {
        let identifiers: [HKQuantityTypeIdentifier] = [
            .distanceWalkingRunning,
            .distanceCycling,
            .distanceSwimming
        ]
        for identifier in identifiers {
            let type = HKQuantityType(identifier)
            if let value = workout.statistics(for: type)?.sumQuantity()?.doubleValue(for: .meter()),
               value > 0 {
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

extension WorkoutHealthKitService: HKLiveWorkoutBuilderDelegate, HKWorkoutSessionDelegate {

    func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        Task { @MainActor [weak self] in
            self?.publishLiveMetrics(from: workoutBuilder)
        }
    }

    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        Task { @MainActor [weak self] in
            self?.publishLiveMetrics(from: workoutBuilder)
        }
    }

    func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        Task { @MainActor [weak self] in
            self?.publishLiveMetrics(from: self?.liveBuilder)
        }
    }

    func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didFailWithError error: Error
    ) {
        print("[WorkoutHealthKit] live session error: \(error)")
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.liveSession = nil
            self.liveBuilder = nil
            self.onSessionFailed?(error.localizedDescription)
        }
    }
}

enum WorkoutHealthKitLiveError: Error {
    case unavailable
    case alreadyStarted
    case notStarted
    case noWorkout
}
