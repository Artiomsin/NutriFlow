//
//  WorkoutViewModel.swift
//  Nutriflow
//
//  Created by Artem on 05.09.2026.
//

import Foundation
import Observation
import UIKit

private struct WorkoutHistoryCache: Codable, Sendable {
    let items: [HealthKitWorkout]
    let total: Int
}

@Observable
@MainActor
final class WorkoutViewModel {

    private static let syncWindowDays = 365
    private static let pruneWindowDays = 30
    private static let displayWindowDays = 90
    private static let pageSize = 100

    private static let lastWorkoutTTL: TimeInterval = 300
    private static let syncInterval: TimeInterval = 3 * 60 * 60
    private static let reconciliationInterval: TimeInterval = 24 * 60 * 60

    private static let historyCacheKey = "workout_history"
    private static let lastWorkoutCacheKey = "workout_last"
    private static let lastWorkoutSyncedAtKey = "lastWorkoutSyncedAt"
    private static let lastFullSyncDateKey = "lastFullSyncDate"

    // MARK: - State

    var state: WorkoutHistoryState = .idle {
        didSet {
            switch state {
            case .loaded(let items):
                print("[WorkoutVM] state -> loaded(\(items.count))")

            default:
                print("[WorkoutVM] state -> \(state)")
            }
        }
    }

    var lastWorkout: HealthKitWorkout?

    var weekWorkoutsCount: Int {
        guard case .loaded(let items) = state,
              let start = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start else { return 0 }
        return items.filter { $0.startDate >= start }.count
    }

    var weekWorkoutMinutes: Int {
        guard case .loaded(let items) = state,
              let start = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start else { return 0 }
        return items.filter { $0.startDate >= start }
            .reduce(0) { $0 + Int($1.durationSeconds) / 60 }
    }

    var isLoadMore: Bool = false
    var hasMore: Bool = false
    var loadMoreError: Bool = false

    var selectedWorkout: HealthKitWorkout?

    var heartRatePoints: [HeartRatePoint] = []
    var sparklineHR: [UUID: [HeartRatePoint]] = [:]

    var detailSeries: [WorkoutSeries] = []

    // MARK: - HealthKit access state

    /// true when HealthKit is unavailable or workout permission
    /// has not been granted.
    var needsHealthConnect: Bool = false

    /// true when the user explicitly denied workout access.
    var healthAccessDenied: Bool = false

    /// Used by UI if it needs to distinguish unavailable HealthKit
    /// from a permission problem.
    var healthKitUnavailable: Bool = false

    // MARK: - Private state

    private var lastWorkoutSyncedAt: Date? {
        get {
            UserDefaults.standard.object(
                forKey: Self.lastWorkoutSyncedAtKey
            ) as? Date
        }
        set {
            UserDefaults.standard.set(
                newValue,
                forKey: Self.lastWorkoutSyncedAtKey
            )
        }
    }

    private var lastFullSyncAt: Date? {
        get {
            UserDefaults.standard.object(
                forKey: Self.lastFullSyncDateKey
            ) as? Date
        }
        set {
            UserDefaults.standard.set(
                newValue,
                forKey: Self.lastFullSyncDateKey
            )
        }
    }

    @ObservationIgnored
    private let healthKit: WorkoutHealthKitServiceProtocol

    @ObservationIgnored
    private let workoutService: WorkoutServiceProtocol

    @ObservationIgnored
    private let cacheService: CacheService?

    @ObservationIgnored
    private var total: Int = 0

    @ObservationIgnored
    private var loadMoreTask: Task<Void, Never>?

    @ObservationIgnored
    private var loadingSparkline = Set<UUID>()

    @ObservationIgnored
    private var seriesCache: [UUID: [WorkoutSeries]] = [:]

    // MARK: - Init

    init(
        healthKit: WorkoutHealthKitServiceProtocol,
        workoutService: WorkoutServiceProtocol,
        cacheService: CacheService? = nil
    ) {
        self.healthKit = healthKit
        self.workoutService = workoutService
        self.cacheService = cacheService
    }

    deinit {
        loadMoreTask?.cancel()
    }

    // MARK: - Latest workout

    func loadLatest() async {

        // 1. Cache-first.
        //
        // We intentionally load cache BEFORE checking HealthKit permission.
        // Existing data must remain visible even when HealthKit is disabled.

        if let cachedWorkout: HealthKitWorkout =
            try? await cacheService?.get(Self.lastWorkoutCacheKey) {

            lastWorkout = cachedWorkout

            print(
                "[WorkoutVM] loadLatest -> cache HIT: \(cachedWorkout.workoutType)"
            )
        }

        // 2. Check current HealthKit permission.
        let access = await updateHealthAccessState()

        // 3. No HealthKit access:
        //
        // Do NOT clear lastWorkout.
        // Try backend because backend contains previously synced workouts.

        guard access == .authorized else {

            print(
                "[WorkoutVM] loadLatest -> HealthKit unavailable/denied, using backend"
            )

            if let backendWorkout = await latestWorkoutFromBackend() {
                lastWorkout = backendWorkout

                try? await cacheService?.set(
                    Self.lastWorkoutCacheKey,
                    backendWorkout,
                    ttl: Self.lastWorkoutTTL
                )

                print(
                    "[WorkoutVM] loadLatest -> backend fallback: \(backendWorkout.workoutType)"
                )
            }

            return
        }

        // 4. HealthKit is authorized.
        //
        // Fetch the newest workout from HealthKit.

        guard let workout = await healthKit.fetchLatestWorkout() else {

            // HealthKit is authorized but currently contains no workout.
            // Backend is still a valid fallback.

            print(
                "[WorkoutVM] loadLatest -> HealthKit has no workout, using backend"
            )

            if let backendWorkout = await latestWorkoutFromBackend() {
                lastWorkout = backendWorkout

                try? await cacheService?.set(
                    Self.lastWorkoutCacheKey,
                    backendWorkout,
                    ttl: Self.lastWorkoutTTL
                )
            }

            return
        }

        // 5. Compare with cache.
        //
        // Only synchronize when the workout is new/changed.

        let cachedWorkout: HealthKitWorkout? =
            try? await cacheService?.get(Self.lastWorkoutCacheKey)

        if cachedWorkout == nil || cachedWorkout != workout {

            do {
                try await workoutService.sync(
                    entries: [
                        WorkoutMapper.toEntry(workout)
                    ]
                )

                print(
                    "[WorkoutVM] loadLatest -> synced \(workout.workoutType)"
                )

            } catch {
                print(
                    "[WorkoutVM] loadLatest -> backend sync failed: \(error)"
                )
            }
        }

        // 6. Update cache and UI.

        try? await cacheService?.set(
            Self.lastWorkoutCacheKey,
            workout,
            ttl: Self.lastWorkoutTTL
        )

        lastWorkout = workout

        print(
            "[WorkoutVM] loadLatest -> \(workout.workoutType)"
        )
    }

    // MARK: - Backend latest

    private func latestWorkoutFromBackend() async -> HealthKitWorkout? {

        do {

            let response = try await workoutService.getHistory(
                from: nil,
                to: nil,
                limit: 1,
                offset: 0
            )

            let workout = response.workouts
                .compactMap { WorkoutMapper.toWorkout($0) }
                .first

            print(
                "[WorkoutVM] backend latest: total=\(response.total) first=\(workout?.workoutType ?? "nil")"
            )

            return workout

        } catch {

            print(
                "[WorkoutVM] backend latest failed: \(error)"
            )

            return nil
        }
    }

    // MARK: - Lifecycle

    func onAppear() async {

        print("[WorkoutVM] onAppear")

        // Important:
        // Do not stop the entire VM when HealthKit is unavailable.
        // The backend/cache must continue working.

        await loadLatest()

        // Refresh permission state.
        let access = await updateHealthAccessState()

        if access == .authorized {

            if shouldReSync() {
                await syncRecentWorkouts()
            } else {
                print(
                    "[WorkoutVM] sync skipped (within interval)"
                )
            }
        }

        // History always loads.
        //
        // If HealthKit is unavailable, loadHistory() will use backend/cache.
        await loadHistory()

        print(
            "[WorkoutVM] onAppear done"
        )
    }

    func refresh() async {

        print("[WorkoutVM] refresh")

        loadMoreTask?.cancel()
        loadMoreTask = nil

        isLoadMore = false
        loadMoreError = false
        total = 0

        await cacheService?.remove(Self.historyCacheKey)

        // Do NOT abort here because HealthKit is unavailable.
        //
        // Backend history still needs to be loaded.

        let access = await updateHealthAccessState()

        if access == .authorized {
            await syncRecentWorkouts(force: true)
        }

        await loadHistory()

        await loadLatest()

        print(
            "[WorkoutVM] refresh done"
        )
    }

    // MARK: - Load more

    func loadMore() {

        guard hasMore, !isLoadMore else {
            return
        }

        guard case .loaded(let current) = state,
              !current.isEmpty else {
            return
        }

        isLoadMore = true
        loadMoreError = false

        let nextOffset = current.count

        loadMoreTask = Task { @MainActor [weak self] in

            guard let self else {
                return
            }

            defer {
                if !Task.isCancelled {
                    self.isLoadMore = false
                }
            }

            do {

                let response = try await workoutService.getHistory(
                    from: nil,
                    to: nil,
                    limit: Self.pageSize,
                    offset: nextOffset
                )

                guard !Task.isCancelled else {
                    return
                }

                if case .loaded(let existing) = self.state {

                    let known = Set(
                        existing.map(\.id)
                    )

                    let merged = response.workouts
                        .compactMap {
                            WorkoutMapper.toWorkout($0)
                        }
                        .filter {
                            !known.contains($0.id)
                        }

                    self.state = .loaded(
                        existing + merged
                    )
                }

                self.total = response.total

                self.hasMore =
                    self.total >
                    nextOffset + response.workouts.count

            } catch {

                guard !Task.isCancelled else {
                    return
                }

                self.loadMoreError = true

                print(
                    "[WorkoutVM] loadMore failed: \(error)"
                )
            }
        }
    }

    // MARK: - Heart rate

    func loadHeartRate(
        for workout: HealthKitWorkout
    ) async {

        if let cached = sparklineHR[workout.id] {
            heartRatePoints = cached
            return
        }

        heartRatePoints =
            await healthKit.fetchHeartRateWorkout(
                for: workout
            )

        if !heartRatePoints.isEmpty {
            sparklineHR[workout.id] =
                heartRatePoints
        }

        print(
            "[WorkoutVM] heart rate points: \(heartRatePoints.count)"
        )
    }

    // MARK: - Series

    func loadSeries(
        for workout: HealthKitWorkout
    ) async {

        if let cached = seriesCache[workout.id] {
            detailSeries = cached
            return
        }

        var result: [WorkoutSeries] = []

        let kinds: [WorkoutSeriesKind] = [
            .speed,
            .cadence,
            .power
        ]

        for kind in kinds {

            let points =
                await healthKit.fetchWorkoutSeries(
                    kind: kind,
                    workout: workout
                )

            if !points.isEmpty {

                result.append(
                    WorkoutSeries(
                        kind: kind,
                        points: points
                    )
                )
            }
        }

        seriesCache[workout.id] = result
        detailSeries = result

        print(
            "[WorkoutVM] series for \(workout.workoutType): " +
            "\(result.map { "\($0.kind.rawValue)=\($0.points.count)" }.joined(separator: ", "))"
        )
    }

    func clearSeries() {
        detailSeries = []
    }

    func currentSeries() -> [WorkoutSeries] {
        detailSeries
    }

    func loadSparkline(
        for workout: HealthKitWorkout
    ) async {

        guard
            sparklineHR[workout.id] == nil,
            !loadingSparkline.contains(workout.id)
        else {
            return
        }

        loadingSparkline.insert(workout.id)

        let points =
            await healthKit.fetchHeartRateWorkout(
                for: workout
            )

        loadingSparkline.remove(workout.id)

        if !points.isEmpty {

            sparklineHR[workout.id] = points

            print(
                "[WorkoutVM] sparkline loaded for \(workout.workoutType): \(points.count) points"
            )
        }
    }

    // MARK: - Sync

    private func shouldReSync() -> Bool {

        guard let last = lastWorkoutSyncedAt else {
            return true
        }

        return Date().timeIntervalSince(last)
            >= Self.syncInterval
    }

    private func syncRecentWorkouts(
        force: Bool = false
    ) async {

        // Safety guard.
        //
        // This method should only execute when HealthKit is authorized.

        guard await hasAuthorizedWorkoutAccess() else {

            print(
                "[WorkoutVM] syncRecentWorkouts -> no HealthKit access"
            )

            return
        }

        let end = Date()

        let firstEver =
            lastWorkoutSyncedAt == nil

        let needsFull =
            force ||
            firstEver ||
            (
                lastFullSyncAt.map {
                    Date().timeIntervalSince($0)
                        >= Self.reconciliationInterval
                } ?? true
            )

        let fullDays =
            firstEver
            ? Self.syncWindowDays
            : Self.pruneWindowDays

        let start: Date
        let isFull: Bool

        if needsFull {

            start =
                Calendar.current.date(
                    byAdding: .day,
                    value: -fullDays,
                    to: end
                ) ?? end

            isFull = true

        } else if
            let lastSync = lastWorkoutSyncedAt,
            let minStart =
                Calendar.current.date(
                    byAdding: .day,
                    value: -Self.syncWindowDays,
                    to: end
                )
        {

            start = max(lastSync, minStart)
            isFull = false

        } else {

            return
        }

        guard start < end else {

            print(
                "[WorkoutVM] sync window empty -> skip"
            )

            return
        }

        print(
            "[WorkoutVM] sync \(isFull ? (firstEver ? "first full 365d" : "reconciliation 30d") : "incremental delta") window: \(start) -> \(end)"
        )

        let local =
            await healthKit.fetchWorkouts(
                from: start,
                to: end
            )

        print(
            "[WorkoutVM] HealthKit returned \(local.count) workouts"
        )

        guard !local.isEmpty else {

            print(
                "[WorkoutVM] HealthKit empty in window -> nothing to sync"
            )

            return
        }

        let entries =
            local.map {
                WorkoutMapper.toEntry($0)
            }

        do {

            try await workoutService.sync(
                entries: entries
            )

            if
                isFull,
                let pruneStart =
                    Calendar.current.date(
                        byAdding: .day,
                        value: -Self.pruneWindowDays,
                        to: end
                    ),
                pruneStart >= start
            {

                let pruneIds =
                    local
                        .filter {
                            $0.startDate >= pruneStart
                        }
                        .map {
                            $0.id.uuidString
                        }

                try await workoutService.deleteMissing(
                    from: WorkoutMapper.isoString(
                        from: pruneStart
                    ),
                    healthKitWorkoutIds: pruneIds
                )

                print(
                    "[WorkoutVM] pruned ghosts within \(Self.pruneWindowDays)d"
                )

            } else {

                print(
                    "[WorkoutVM] prune skipped"
                )
            }

            lastWorkoutSyncedAt = Date()

            if isFull {
                lastFullSyncAt = Date()
            }

            print(
                "[WorkoutVM] synced \(entries.count) workouts"
            )

        } catch {

            print(
                "[WorkoutVM] sync failed: \(error)"
            )
        }
    }

    // MARK: - History

    private func loadHistory() async {

        // When access is denied, never leak stale backend/cache workouts.
        let access = await updateHealthAccessState()

        if access == .denied {
            print(
                "[WorkoutVM] loadHistory -> denied, history hidden"
            )

            state = .denied

            return
        }

        // 1. Cache first.

        if
            let cached: WorkoutHistoryCache =
                try? await cacheService?.get(
                    Self.historyCacheKey
                ),
            !cached.items.isEmpty
        {

            print(
                "[WorkoutVM] history cache HIT (\(cached.items.count)/\(cached.total))"
            )

            total = cached.total
            hasMore = cached.total > cached.items.count

            state = .loaded(cached.items)

            Task { @MainActor [weak self] in

                guard let self else {
                    return
                }

                await self.topUpAfterCacheHit()
            }

            return
        }

        // 2. Legacy cache.

        if
            let legacy: [HealthKitWorkout] =
                try? await cacheService?.get(
                    Self.historyCacheKey
                ),
            !legacy.isEmpty
        {

            print(
                "[WorkoutVM] legacy history cache HIT (\(legacy.count))"
            )

            total = legacy.count
            hasMore = false

            state = .loaded(legacy)

            return
        }

        // 3. Backend is the primary persistent source.

        do {

            print(
                "[WorkoutVM] loadHistory -> backend"
            )

            let response =
                try await workoutService.getHistory(
                    from: nil,
                    to: nil,
                    limit: Self.pageSize,
                    offset: 0
                )

            print(
                "[WorkoutVM] getHistory OK: total=\(response.total) returned=\(response.workouts.count)"
            )

            if response.workouts.isEmpty {

                // Backend has no workouts.
                //
                // Only now try HealthKit.

                print(
                    "[WorkoutVM] backend history empty -> HealthKit fallback"
                )

                let access =
                    await updateHealthAccessState()

                if access == .authorized {
                    await loadFromHealthKitFallback()
                } else {
                    total = 0
                    hasMore = false
                    state = .loaded([])
                }

                return
            }

            let mapped =
                response.workouts
                    .compactMap {
                        WorkoutMapper.toWorkout($0)
                    }

            try? await cacheService?.set(
                Self.historyCacheKey,
                WorkoutHistoryCache(
                    items: mapped,
                    total: response.total
                ),
                ttl: Self.lastWorkoutTTL
            )

            total = response.total
            hasMore = total > mapped.count

            state = .loaded(mapped)

        } catch {

            print(
                "[WorkoutVM] getHistory error: \(error)"
            )

            // 4. Stale cache.

            if
                let stale: WorkoutHistoryCache =
                    try? await cacheService?.get(
                        Self.historyCacheKey,
                        ignoreTTL: true
                    ),
                !stale.items.isEmpty
            {

                print(
                    "[WorkoutVM] stale history cache (\(stale.items.count)/\(stale.total))"
                )

                total = stale.total
                hasMore = stale.total > stale.items.count

                state = .loaded(stale.items)

                return
            }

            // 5. Last fallback: HealthKit.

            let access =
                await updateHealthAccessState()

            if access == .authorized {
                await loadFromHealthKitFallback(error: error)
            } else {

                // No HealthKit and no cache.
                // The backend failed, so expose the error.

                state = .error(error)
            }
        }
    }

    // MARK: - Cache top-up

    private func topUpAfterCacheHit() async {

        print(
            "[WorkoutVM] cache hit -> background network top-up"
        )

        do {

            let response =
                try await workoutService.getHistory(
                    from: nil,
                    to: nil,
                    limit: Self.pageSize,
                    offset: 0
                )

            guard !Task.isCancelled else {
                return
            }

            guard case .loaded(let current) = state else {
                return
            }

            let known =
                Set(current.map(\.id))

            let fresh =
                response.workouts
                    .compactMap {
                        WorkoutMapper.toWorkout($0)
                    }
                    .filter {
                        !known.contains($0.id)
                    }

            let merged = current + fresh

            total = response.total
            hasMore = total > merged.count

            state = .loaded(merged)

            try? await cacheService?.set(
                Self.historyCacheKey,
                WorkoutHistoryCache(
                    items: merged,
                    total: total
                ),
                ttl: Self.lastWorkoutTTL
            )

            if hasMore {
                loadMore()
            }

        } catch {

            print(
                "[WorkoutVM] cache top-up failed: \(error)"
            )
        }
    }

    // MARK: - HealthKit fallback

    private func loadFromHealthKitFallback(
        error: Error? = nil
    ) async {

        let end = Date()

        guard
            let start =
                Calendar.current.date(
                    byAdding: .day,
                    value: -Self.displayWindowDays,
                    to: end
                )
        else {

            print(
                "[WorkoutVM] fallback: bad dates -> empty"
            )

            state = .loaded([])

            return
        }

        let local =
            await healthKit.fetchWorkouts(
                from: start,
                to: end
            )

        print(
            "[WorkoutVM] fallback HealthKit(\(Self.displayWindowDays)d) = \(local.count)"
        )

        total = local.count
        hasMore = false

        if local.isEmpty, let error {

            print(
                "[WorkoutVM] fallback empty AND backend failed -> error state"
            )

            state = .error(error)

            return
        }

        state = .loaded(local)
    }

    // MARK: - HealthKit permission

    private enum WorkoutAccessResult {
        case authorized
        case notDetermined
        case denied
        case unavailable
    }

    /// Updates UI permission flags without destroying existing history state.
    ///
    /// Important:
    /// This method does NOT set `state = .needsAccess` or `.denied`.
    /// Otherwise a permission check on Home could replace an already loaded
    /// workout history with an access state.
    private func updateHealthAccessState()
        async -> WorkoutAccessResult
    {

        guard healthKit.isAvailable else {

            needsHealthConnect = true
            healthAccessDenied = false
            healthKitUnavailable = true

            print(
                "[WorkoutVM] HealthKit unavailable"
            )

            return .unavailable
        }

        switch await healthKit.permissionState() {

        case .authorized:

            needsHealthConnect = false
            healthAccessDenied = false
            healthKitUnavailable = false

            print(
                "[WorkoutVM] HealthKit authorized"
            )

            return .authorized

        case .notDetermined:

            needsHealthConnect = true
            healthAccessDenied = false
            healthKitUnavailable = false

            print(
                "[WorkoutVM] HealthKit notDetermined"
            )

            return .notDetermined

        case .denied:

            needsHealthConnect = true
            healthAccessDenied = true
            healthKitUnavailable = false

            print(
                "[WorkoutVM] HealthKit denied"
            )

            return .denied
        }
    }

    private func hasAuthorizedWorkoutAccess() async -> Bool {

        guard healthKit.isAvailable else {
            return false
        }

        switch await healthKit.permissionState() {

        case .authorized:
            return true

        case .notDetermined,
             .denied:
            return false
        }
    }

    // MARK: - Connect Health

    func connectTapped() async {

        print(
            "[WorkoutVM] connectTapped"
        )

        do {

            try await healthKit.requestAuthorization()

            print(
                "[WorkoutVM] requestAuthorization returned"
            )

        } catch {

            print(
                "[WorkoutVM] requestAuthorization failed: \(error)"
            )

            state = .error(error)

            return
        }

        let access =
            await updateHealthAccessState()

        switch access {

        case .authorized:

            // HealthKit became available.
            // Now synchronize and reload.

            if shouldReSync() {
                await syncRecentWorkouts()
            } else {
                print(
                    "[WorkoutVM] sync skipped (within interval)"
                )
            }

            await loadLatest()
            await loadHistory()

        case .denied,
             .notDetermined,
             .unavailable:

            // Keep existing cache/backend data visible.
            // Only permission flags change.

            print(
                "[WorkoutVM] connectTapped -> HealthKit still unavailable"
            )

            await loadLatest()
        }
    }


    /// Call this when the app returns from Settings.
    func refreshPermissionState() async {
        print(
            "[WorkoutVM] refreshPermissionState"
        )

        let access = await updateHealthAccessState()

        // If user enabled HealthKit in Settings,
        // immediately synchronize the latest workout.
        if access == .authorized {
            if shouldReSync() {
                await syncRecentWorkouts()
            }

            await loadLatest()
            await loadHistory()
        } else {
            // If still disabled/unavailable, keep backend/cache data.
            await loadLatest()
        }
    }

    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            return
        }

        UIApplication.shared.open(url)
    }
}
