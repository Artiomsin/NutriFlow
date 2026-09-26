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

    static func resetSessionSyncState() {
        UserDefaults.standard.removeObject(forKey: lastWorkoutSyncedAtKey)
        UserDefaults.standard.removeObject(forKey: lastFullSyncDateKey)
    }
    
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
    var lastWorkoutState: LastWorkoutState = .idle
    
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
    var loadMoreError: AppError?
    var heartRateError: AppError?
    var seriesError: AppError?
    
    var selectedWorkout: HealthKitWorkout?
    
    var heartRatePoints: [HeartRatePoint] = []
    var sparklineHR: [UUID: [HeartRatePoint]] = [:]
    
    var detailSeries: [WorkoutSeries] = []
    
    @ObservationIgnored
    private var historyGeneration = 0
    @ObservationIgnored
    private var latestGeneration = 0
    @ObservationIgnored
    private var loadMoreGeneration = 0
    @ObservationIgnored
    private var topUpGeneration = 0
    
    @ObservationIgnored
    private var isRefreshing = false
    var isConnecting = false
    @ObservationIgnored
    private var topUpTask: Task<Void, Never>?
    
    
    /// true when the user explicitly denied workout access.
    var healthAccessDenied: Bool = false
    
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
    private let analyticsTracker: AnalyticsTracking?
    
    @ObservationIgnored
    private var total: Int = 0
    
    @ObservationIgnored
    private var loadMoreTask: Task<Void, Never>?
    
    @ObservationIgnored
    private var loadingSparkline = Set<UUID>()
    
    @ObservationIgnored
    private var seriesCache: [UUID: [WorkoutSeries]] = [:]
    @ObservationIgnored
    private var heartRateGeneration = 0
    @ObservationIgnored
    private var seriesGeneration = 0
    
    init(
        healthKit: WorkoutHealthKitServiceProtocol,
        workoutService: WorkoutServiceProtocol,
        cacheService: CacheService? = nil,
        analyticsTracker: AnalyticsTracking? = nil
    ) {
        self.healthKit = healthKit
        self.workoutService = workoutService
        self.cacheService = cacheService
        self.analyticsTracker = analyticsTracker
    }
    
    func trackScreenView(_ screen: String) {
        analyticsTracker?.track(.screenView(screen: screen))
    }
    
    deinit {
        loadMoreTask?.cancel()
        topUpTask?.cancel()
    }

    func loadLatest() async {
        
        latestGeneration &+= 1
        let generation = latestGeneration
        if lastWorkout == nil {
            lastWorkoutState = .loading
        }
        
        // 1. Cache-first.
        //
        // We intentionally load cache BEFORE checking HealthKit permission.
        // Existing data must remain visible even when HealthKit is disabled.
        
        if let cachedWorkout: HealthKitWorkout =
            try? await cacheService?.get(Self.lastWorkoutCacheKey) {
            
            guard latestGeneration == generation else {
                return
            }
            
            lastWorkout = cachedWorkout
            lastWorkoutState = .loaded
            
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
            
            switch await latestWorkoutFromBackend() {
            case .success(let backendWorkout?):
                
                guard latestGeneration == generation else {
                    return
                }
                
                lastWorkout = backendWorkout
                lastWorkoutState = .loaded
                
                try? await cacheService?.set(
                    Self.lastWorkoutCacheKey,
                    backendWorkout,
                    ttl: Self.lastWorkoutTTL
                )
                
                print(
                    "[WorkoutVM] loadLatest -> backend fallback: \(backendWorkout.workoutType)"
                )
            case .success(nil):
                if lastWorkout == nil { lastWorkoutState = .empty }
            case .failure(let error):
                if lastWorkout == nil { lastWorkoutState = .error(error) }
            }
            
            return
        }
        
        // 4. HealthKit is authorized.
        //
        // Fetch the newest workout from HealthKit.

        let fetchedWorkout: HealthKitWorkout?
        var latestHealthKitError: AppError?
        do {
            fetchedWorkout = try await healthKit.fetchLatestWorkout()
        } catch {
            print(
                "[WorkoutVM] fetchLatestWorkout failed: \(error)"
            )
            fetchedWorkout = nil
            latestHealthKitError = ErrorMapper.map(error)
        }

        guard let workout = fetchedWorkout else {
            
            // HealthKit is authorized but currently contains no workout.
            // Backend is still a valid fallback.
            
            print(
                "[WorkoutVM] loadLatest -> HealthKit has no workout, using backend"
            )
            
            switch await latestWorkoutFromBackend() {
            case .success(let backendWorkout?):
                
                guard latestGeneration == generation else {
                    return
                }
                
                lastWorkout = backendWorkout
                lastWorkoutState = .loaded
                
                try? await cacheService?.set(
                    Self.lastWorkoutCacheKey,
                    backendWorkout,
                    ttl: Self.lastWorkoutTTL
                )
            case .success(nil):
                if lastWorkout == nil {
                    lastWorkoutState = latestHealthKitError.map(LastWorkoutState.error) ?? .empty
                }
            case .failure(let error):
                if lastWorkout == nil { lastWorkoutState = .error(error) }
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
        
        guard latestGeneration == generation else {
            return
        }
        
        lastWorkout = workout
        lastWorkoutState = .loaded
        
        print(
            "[WorkoutVM] loadLatest -> \(workout.workoutType)"
        )
    }
    
    private func latestWorkoutFromBackend() async -> Result<HealthKitWorkout?, AppError> {
        
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
            
            return .success(workout)
            
        } catch {
            
            print(
                "[WorkoutVM] backend latest failed: \(error)"
            )
            
            return .failure(ErrorMapper.map(error))
        }
    }
    
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
        
        guard !isRefreshing else {
            return
        }
        isRefreshing = true
        defer { isRefreshing = false }
        
        loadMoreTask?.cancel()
        loadMoreTask = nil
        topUpTask?.cancel()
        topUpTask = nil
        loadMoreGeneration &+= 1
        topUpGeneration &+= 1
        historyGeneration &+= 1
        latestGeneration &+= 1
        
        isLoadMore = false
        loadMoreError = nil
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
    
    func loadMore() {
        
        guard hasMore, !isLoadMore else {
            return
        }
        
        guard case .loaded(let current) = state,
              !current.isEmpty else {
            return
        }
        
        isLoadMore = true
        loadMoreError = nil
        
        loadMoreGeneration &+= 1
        let generation = loadMoreGeneration
        
        let nextOffset = current.count
        
        loadMoreTask = Task { @MainActor in
            
            
            // Unconditional: a cancelled task must still release the flag.
            // Conditional cleanup was what pinned isLoadMore = true forever
            // after any cancellation that did not go through refresh().
            defer {
                if self.loadMoreGeneration == generation {
                    self.isLoadMore = false
                }
            }
            
            guard !Task.isCancelled else {
                return
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
                
                guard self.loadMoreGeneration == generation else {
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
                
                // Pagination keeps the already loaded page visible, so the
                // failure is reported next to it instead of replacing state.
                let mapped = ErrorMapper.map(error)
                self.loadMoreError =
                mapped == .cancelled ? nil : mapped
                
                print(
                    "[WorkoutVM] loadMore failed: \(error)"
                )
            }
        }
    }
    
    func loadHeartRate(
        for workout: HealthKitWorkout
    ) async {
        heartRateGeneration &+= 1
        let generation = heartRateGeneration
        
        if let cached = sparklineHR[workout.id] {
            guard generation == heartRateGeneration, selectedWorkout?.id == workout.id else { return }
            heartRatePoints = cached
            heartRateError = nil
            return
        }

        do {
            let points = try await healthKit.fetchHeartRateWorkout(
                for: workout
            )
            guard generation == heartRateGeneration, selectedWorkout?.id == workout.id else { return }
            heartRatePoints = points
            heartRateError = nil
        } catch {
            guard generation == heartRateGeneration, selectedWorkout?.id == workout.id else { return }
            let mapped = ErrorMapper.map(error)
            heartRatePoints = []
            heartRateError = mapped == .cancelled ? nil : mapped
            print(
                "[WorkoutVM] heart rate failed: \(error)"
            )
        }
        
        if !heartRatePoints.isEmpty {
            sparklineHR[workout.id] =
            heartRatePoints
        }
        
        print(
            "[WorkoutVM] heart rate points: \(heartRatePoints.count)"
        )
    }
    
    func loadSeries(
        for workout: HealthKitWorkout
    ) async {
        seriesGeneration &+= 1
        let generation = seriesGeneration
        
        if let cached = seriesCache[workout.id] {
            guard generation == seriesGeneration, selectedWorkout?.id == workout.id else { return }
            detailSeries = cached
            seriesError = nil
            return
        }
        
        var result: [WorkoutSeries] = []
        var failure: AppError?
        
        let kinds: [WorkoutSeriesKind] = [
            .speed,
            .cadence,
            .power
        ]
        
        for kind in kinds {
            
            let points: [WorkoutSeriesPoint]
            do {
                points =
                try await healthKit.fetchWorkoutSeries(
                    kind: kind,
                    workout: workout
                )
            } catch {
                let mapped = ErrorMapper.map(error)
                if mapped != .cancelled, failure == nil {
                    failure = mapped
                }
                print(
                    "[WorkoutVM] series \(kind.rawValue) failed: \(error)"
                )
                continue
            }
            
            if !points.isEmpty {
                
                result.append(
                    WorkoutSeries(
                        kind: kind,
                        points: points
                    )
                )
            }
        }
        
        guard generation == seriesGeneration, selectedWorkout?.id == workout.id else { return }
        if failure == nil {
            seriesCache[workout.id] = result
        }
        detailSeries = result
        seriesError = failure
        
        print(
            "[WorkoutVM] series for \(workout.workoutType): " +
            "\(result.map { "\($0.kind.rawValue)=\($0.points.count)" }.joined(separator: ", "))"
        )
    }
    
    func clearSeries() {
        seriesGeneration &+= 1
        detailSeries = []
        seriesError = nil
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
        
        defer {
            loadingSparkline.remove(workout.id)
        }
        
        let points: [HeartRatePoint]
        do {
            points =
            try await healthKit.fetchHeartRateWorkout(
                for: workout
            )
        } catch {
            print(
                "[WorkoutVM] sparkline failed for \(workout.workoutType): \(error)"
            )
            return
        }
        
        if !points.isEmpty {
            
            sparklineHR[workout.id] = points
            
            print(
                "[WorkoutVM] sparkline loaded for \(workout.workoutType): \(points.count) points"
            )
        }
    }
    
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
        
        let local: [HealthKitWorkout]
        do {
            local =
            try await healthKit.fetchWorkouts(
                from: start,
                to: end
            )
        } catch {
            print(
                "[WorkoutVM] sync fetch failed: \(error)"
            )
            return
        }
        
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
            
            return
        }
        
        // Ghost prune runs best-effort, separately from the sync.
        // A failure here must not roll back the sync timestamps above:
        // otherwise every failed prune would keep lastWorkoutSyncedAt
        // nil and re-trigger a full 365d sync on the next run.
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
            
            do {
                try await workoutService.deleteMissing(
                    from: WorkoutMapper.isoString(
                        from: pruneStart
                    ),
                    to: WorkoutMapper.isoString(from: end),
                    healthKitWorkoutIds: pruneIds
                )
                
                print(
                    "[WorkoutVM] pruned ghosts within \(Self.pruneWindowDays)d"
                )
            } catch {
                print(
                    "[WorkoutVM] prune failed: \(error) " +
                    "(ghosts retried at next reconciliation)"
                )
            }
            
        } else {
            
            print(
                "[WorkoutVM] prune skipped"
            )
        }
    }
    
    private func loadHistory() async {
        
        // onAppear() and refresh() both call this. Whoever entered last owns
        // the state; the earlier one must not write after it.
        historyGeneration &+= 1
        let generation = historyGeneration
        
        // When access is denied, never leak stale backend/cache workouts.
        let access = await updateHealthAccessState()
        
        if access == .denied {
            print(
                "[WorkoutVM] loadHistory -> denied, history hidden"
            )
            
            guard historyGeneration == generation else {
                return
            }
            
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
            
            guard historyGeneration == generation else {
                return
            }
            
            total = cached.total
            hasMore = cached.total > cached.items.count
            
            state = .loaded(cached.items)
            
            // Track this task. It writes state/total/hasMore and the cache,
            // so refresh() must be able to cancel it — otherwise a top-up
            // started before the refresh lands after it and overwrites
            // fresher data with its older response.
            topUpGeneration &+= 1
            let topUpGen = topUpGeneration
            
            topUpTask?.cancel()
            topUpTask = Task { @MainActor in
                
                await self.topUpAfterCacheHit(
                    generation: topUpGen
                )
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
            
            guard historyGeneration == generation else {
                return
            }
            
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
                    await loadFromHealthKitFallback(
                        historyGeneration: generation
                    )
                } else {
                    
                    guard historyGeneration == generation else {
                        return
                    }
                    
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
            
            guard historyGeneration == generation else {
                return
            }
            
            total = response.total
            hasMore = total > mapped.count
            
            state = .loaded(mapped)
            
        } catch {
            
            let mapped = ErrorMapper.map(error)
            
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
                
                guard historyGeneration == generation else {
                    return
                }
                
                total = stale.total
                hasMore = stale.total > stale.items.count
                
                state = .loaded(stale.items)
                
                return
            }
            
            // 5. Last fallback: HealthKit.
            
            let access =
            await updateHealthAccessState()
            
            if access == .authorized {
                await loadFromHealthKitFallback(
                    error: mapped,
                    historyGeneration: generation
                )
            } else {
                
                guard historyGeneration == generation else {
                    return
                }
                
                // No HealthKit and no cache.
                // The backend failed, so expose the error.
                
                if mapped != .cancelled {
                    state = .error(mapped)
                }
            }
        }
    }
    
    private func topUpAfterCacheHit(
        generation: Int
    ) async {
        
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
            
            guard topUpGeneration == generation else {
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
    
    private func loadFromHealthKitFallback(
        error: AppError? = nil,
        historyGeneration generation: Int
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
            
            guard historyGeneration == generation else {
                return
            }
            
            state = .loaded([])
            
            return
        }
        
        let local: [HealthKitWorkout]
        do {
            local =
            try await healthKit.fetchWorkouts(
                from: start,
                to: end
            )
        } catch {
            let mapped = ErrorMapper.map(error)
            print(
                "[WorkoutVM] fallback HealthKit failed: \(error)"
            )
            guard historyGeneration == generation else {
                return
            }
            if mapped != .cancelled {
                state = .error(mapped)
            }
            return
        }
        
        print(
            "[WorkoutVM] fallback HealthKit(\(Self.displayWindowDays)d) = \(local.count)"
        )
        
        guard historyGeneration == generation else {
            return
        }
        
        total = local.count
        hasMore = false
        
        if local.isEmpty, let error {
            
            print(
                "[WorkoutVM] fallback empty AND backend failed -> error state"
            )
            
            if error != .cancelled {
                state = .error(error)
            }
            
            return
        }
        
        state = .loaded(local)
    }
    
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
            
            healthAccessDenied = false
            
            print(
                "[WorkoutVM] HealthKit unavailable"
            )
            
            return .unavailable
        }
        
        switch await healthKit.permissionState() {
            
        case .authorized:
            
            healthAccessDenied = false
            
            print(
                "[WorkoutVM] HealthKit authorized"
            )
            
            return .authorized
            
        case .notDetermined:
            
            healthAccessDenied = false
            
            print(
                "[WorkoutVM] HealthKit notDetermined"
            )
            
            return .notDetermined
            
        case .unknown:
            
            healthAccessDenied = false
            
            print(
                "[WorkoutVM] HealthKit state unknown"
            )
            
            return .notDetermined
            
        case .denied:
            
            healthAccessDenied = true
            
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
                .denied,
                .unknown:
            return false
        }
    }
    
    func connectTapped() async {
        
        guard !isConnecting else {
            return
        }
        isConnecting = true
        defer { isConnecting = false }
        
        historyGeneration &+= 1
        let generation = historyGeneration
        
        print(
            "[WorkoutVM] connectTapped"
        )
        
        do {
            
            try await healthKit.requestAuthorization()
            
            print(
                "[WorkoutVM] requestAuthorization returned"
            )
            
        } catch {
            
            let mapped = ErrorMapper.map(error)
            
            print(
                "[WorkoutVM] requestAuthorization failed: \(error)"
            )
            
            if mapped != .cancelled, historyGeneration == generation {
                state = .error(mapped)
            }
            
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
