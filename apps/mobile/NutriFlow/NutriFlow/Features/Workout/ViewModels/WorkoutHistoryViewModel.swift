//
//  WorkoutHistoryViewModel.swift
//  Nutriflow
//
//  Created by Artem on 05.09.2026.
//

import Foundation
import Observation

private struct WorkoutHistoryCache: Codable, Sendable {
    let items: [HealthKitWorkout]
    let total: Int
}

@Observable
@MainActor
final class WorkoutHistoryViewModel {

    private static let syncWindowDays = 365
    private static let pruneWindowDays = 30
    private static let displayWindowDays = 90
    private static let pageSize = 100
    private static let lastWorkoutTTL: TimeInterval = 300
    private static let syncInterval: TimeInterval = 3 * 60 * 60
    private static let historyCacheKey = "workout_history"
    private static let lastWorkoutCacheKey = "workout_last"
    private static let userDeniedKey = "hasManuallyDeniedWorkoutAccess"
    private static let lastWorkoutSyncedAtKey = "lastWorkoutSyncedAt"
    private static let lastFullSyncDateKey = "lastFullSyncDate"
    private static let reconciliationInterval: TimeInterval = 24 * 60 * 60

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
    var isLoadMore: Bool = false
    var hasMore: Bool = false
    var loadMoreError: Bool = false
    var activeWorkoutVM: ActiveWorkoutViewModel
    var selectedWorkout: HealthKitWorkout?
    var heartRatePoints: [HeartRatePoint] = []
    var sparklineHR: [UUID: [HeartRatePoint]] = [:]

    var userDeniedAccess: Bool {
        get { UserDefaults.standard.bool(forKey: Self.userDeniedKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.userDeniedKey) }
    }

    private var lastWorkoutSyncedAt: Date? {
        get { UserDefaults.standard.object(forKey: Self.lastWorkoutSyncedAtKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: Self.lastWorkoutSyncedAtKey) }
    }

    private var lastFullSyncAt: Date? {
        get { UserDefaults.standard.object(forKey: Self.lastFullSyncDateKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: Self.lastFullSyncDateKey) }
    }

    @ObservationIgnored private let healthKit: WorkoutHealthKitServiceProtocol
    @ObservationIgnored private let workoutService: WorkoutServiceProtocol
    @ObservationIgnored private let cacheService: CacheService?
    @ObservationIgnored private var total: Int = 0
    @ObservationIgnored private var loadMoreTask: Task<Void, Never>?
    @ObservationIgnored private var lastWorkoutFetchedAt: Date?
    @ObservationIgnored private var loadingSparkline = Set<UUID>()

    init(healthKit: WorkoutHealthKitServiceProtocol, workoutService: WorkoutServiceProtocol, cacheService: CacheService? = nil) {
        self.healthKit = healthKit
        self.workoutService = workoutService
        self.cacheService = cacheService
        self.activeWorkoutVM = ActiveWorkoutViewModel(healthKit: healthKit)
    }

    deinit {
        loadMoreTask?.cancel()
    }

    func loadLatest() async {
        print("[WorkoutVM] loadLatest called (TTL active: \(lastWorkoutFetchedAt != nil))")
        if let fetched = lastWorkoutFetchedAt,
           Date().timeIntervalSince(fetched) < Self.lastWorkoutTTL {
            return
        }

        var workout: HealthKitWorkout?

        let permission = healthKit.workoutPermissionState()
        print("[WorkoutVM] permission = \(permission), isAvailable = \(healthKit.isAvailable)")
        if permission != .denied {
            if permission == .notDetermined {
                print("[WorkoutVM] notDetermined -> requesting authorization for latest workout")
                do {
                    try await healthKit.requestAuthorization()
                    print("[WorkoutVM] requestAuthorization returned")
                } catch {
                    print("[WorkoutVM] authorization failed: \(error)")
                }
            }
            if healthKit.workoutPermissionState() == .authorized {
                let before = Date()
                let w = await healthKit.fetchLatestWorkout()
                print("[WorkoutVM] fetchLatestWorkout took \(Date().timeIntervalSince(before))s -> \(w?.workoutType ?? "nil")")
                workout = w
            }
        }

        if workout == nil {
            print("[WorkoutVM] HealthKit empty -> backend fallback for latest")
            do {
                let response = try await workoutService.getHistory(
                    from: nil,
                    to: nil,
                    limit: 1,
                    offset: 0
                )
                workout = response.workouts.compactMap { WorkoutMapper.toWorkout($0) }.first
                print("[WorkoutVM] backend latest: total=\(response.total) first=\(workout?.workoutType ?? "nil")")
            } catch {
                print("[WorkoutVM] backend fallback failed: \(error)")
            }
        }

        lastWorkout = workout
        if workout != nil {
            lastWorkoutFetchedAt = Date()
            try? await cacheService?.set(Self.lastWorkoutCacheKey, workout, ttl: Self.lastWorkoutTTL)
        } else if let cached: HealthKitWorkout = try? await cacheService?.get(Self.lastWorkoutCacheKey, ignoreTTL: true) {
            lastWorkout = cached
            print("[WorkoutVM] loadLatest -> stale cache \(cached.workoutType)")
        }
        print("[WorkoutVM] loadLatest -> \(lastWorkout?.workoutType ?? "nil")")
    }

    func onAppear() async {
        state = .loading
        guard await hasWorkoutAccess() else { print("[WorkoutVM] onAppear: no access, abort"); return }
        if shouldReSync() {
            await syncRecentWorkouts()
        } else {
            print("[WorkoutVM] sync skipped (within interval)")
        }
        await loadHistory()
        print("[WorkoutVM] onAppear done")
    }

    func refresh() async {
        state = .loading
        loadMoreTask?.cancel()
        loadMoreTask = nil
        isLoadMore = false
        loadMoreError = false
        total = 0
        await cacheService?.remove(Self.historyCacheKey)
        guard await hasWorkoutAccess() else { print("[WorkoutVM] refresh: no access, abort"); return }
        await syncRecentWorkouts(force: true)
        await loadHistory()
        print("[WorkoutVM] refresh done")
    }

    func loadMore() {
        guard hasMore, !isLoadMore else { return }
        guard case .loaded(let current) = state, !current.isEmpty else { return }

        isLoadMore = true
        loadMoreError = false
        let nextOffset = current.count

        loadMoreTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                // Cancellation only comes from refresh(), which already resets isLoadMore
                // in the same synchronous block, so a cancelled task must not touch the flag.
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
                guard !Task.isCancelled else { return }
                if case .loaded(let existing) = self.state {
                    let known = Set(existing.map(\.id))
                    let merged = response.workouts
                        .compactMap { WorkoutMapper.toWorkout($0) }
                        .filter { !known.contains($0.id) }
                    self.state = .loaded(existing + merged)
                }
                self.total = response.total
                self.hasMore = self.total > nextOffset + response.workouts.count
            } catch {
                guard !Task.isCancelled else { return }
                self.loadMoreError = true
            }
        }
    }

    func markAccessDenied() {
        userDeniedAccess = true
        print("[WorkoutVM] user denied workouts access")
    }

    func clearAccessDenied() {
        userDeniedAccess = false
        print("[WorkoutVM] retry from denied")
    }

    func loadHeartRate(for workout: HealthKitWorkout) async {
        if let cached = sparklineHR[workout.id] {
            heartRatePoints = cached
            return
        }
        heartRatePoints = await healthKit.fetchHeartRateWorkout(for: workout)
        if !heartRatePoints.isEmpty {
            sparklineHR[workout.id] = heartRatePoints
        }
        print("[WorkoutVM] heart rate points: \(heartRatePoints.count)")
    }

    var detailSeries: [WorkoutSeries] = []
    private var seriesCache: [UUID: [WorkoutSeries]] = [:]

    func loadSeries(for workout: HealthKitWorkout) async {
        if let cached = seriesCache[workout.id] {
            detailSeries = cached
            return
        }
        var result: [WorkoutSeries] = []
        let kinds: [WorkoutSeriesKind] = [.speed, .cadence, .power]
        for kind in kinds {
            let points = await healthKit.fetchWorkoutSeries(
                kind: kind,
                workout: workout
            )
            if !points.isEmpty {
                result.append(WorkoutSeries(kind: kind, points: points))
            }
        }
        seriesCache[workout.id] = result
        detailSeries = result
        print("[WorkoutVM] series for \(workout.workoutType): \(result.map { "\($0.kind.rawValue)=\($0.points.count)" }.joined(separator: ", "))")
    }

    func clearSeries() {
        detailSeries = []
    }

    func currentSeries() -> [WorkoutSeries] {
        detailSeries
    }

    func loadSparkline(for workout: HealthKitWorkout) async {
        guard sparklineHR[workout.id] == nil, !loadingSparkline.contains(workout.id) else { return }
        loadingSparkline.insert(workout.id)
        let points = await healthKit.fetchHeartRateWorkout(for: workout)
        loadingSparkline.remove(workout.id)
        if !points.isEmpty {
            sparklineHR[workout.id] = points
            print("[WorkoutVM] sparkline loaded for \(workout.workoutType): \(points.count) points")
        }
    }

    private func shouldReSync() -> Bool {
        guard let last = lastWorkoutSyncedAt else { return true }
        return Date().timeIntervalSince(last) >= Self.syncInterval
    }

    private func syncRecentWorkouts(force: Bool = false) async {
        let end = Date()
        let firstEver = lastWorkoutSyncedAt == nil
        let needsFull = force || firstEver
            || (lastFullSyncAt.map { Date().timeIntervalSince($0) >= Self.reconciliationInterval } ?? true)
        let fullDays = firstEver ? Self.syncWindowDays : Self.pruneWindowDays

        let start: Date
        let isFull: Bool
        if needsFull {
            start = Calendar.current.date(byAdding: .day, value: -fullDays, to: end) ?? end
            isFull = true
        } else if let lastSync = lastWorkoutSyncedAt,
                  let minStart = Calendar.current.date(byAdding: .day, value: -Self.syncWindowDays, to: end) {
            start = max(lastSync, minStart)
            isFull = false
        } else {
            return
        }
        guard start < end else {
            print("[WorkoutVM] sync window empty -> skip")
            return
        }

        print("[WorkoutVM] sync \(isFull ? (firstEver ? "first full 365d" : "reconciliation \(Self.pruneWindowDays)d") : "incremental delta") window: \(start) -> \(end)")
        let local = await healthKit.fetchWorkouts(from: start, to: end)
        print("[WorkoutVM] HealthKit returned \(local.count) workouts")
        guard !local.isEmpty else {
            print("[WorkoutVM] HealthKit empty in window -> nothing to sync (not marking success)")
            return
        }

        let entries = local.map { WorkoutMapper.toEntry($0) }
        do {
            try await workoutService.sync(entries: entries)

            if isFull,
               let pruneStart = Calendar.current.date(byAdding: .day, value: -Self.pruneWindowDays, to: end),
               pruneStart >= start {
                let pruneIds = local
                    .filter { $0.startDate >= pruneStart }
                    .map { $0.id.uuidString }
                try await workoutService.deleteMissing(
                    from: WorkoutMapper.isoString(from: pruneStart),
                    healthKitWorkoutIds: pruneIds
                )
                print("[WorkoutVM] pruned ghosts within \(Self.pruneWindowDays)d")
            } else {
                print("[WorkoutVM] prune skipped (incremental or window not covering \(Self.pruneWindowDays)d)")
            }

            lastWorkoutSyncedAt = Date()
            if isFull {
                lastFullSyncAt = Date()
            }
            print("[WorkoutVM] synced \(entries.count) workouts")
        } catch {
            print("[WorkoutVM] sync failed: \(error)")
        }
    }

    private func loadHistory() async {
        if let cached: WorkoutHistoryCache = try? await cacheService?.get(Self.historyCacheKey),
           !cached.items.isEmpty {
            print("[WorkoutVM] history cache HIT (\(cached.items.count)/\(cached.total))")
            total = cached.total
            hasMore = cached.total > cached.items.count
            state = .loaded(cached.items)
            Task { @MainActor [weak self] in
                guard let self else { return }
                await self.topUpAfterCacheHit()
            }
            return
        }

        if let legacy: [HealthKitWorkout] = try? await cacheService?.get(Self.historyCacheKey),
           !legacy.isEmpty {
            print("[WorkoutVM] legacy history cache HIT (\(legacy.count))")
            total = legacy.count
            hasMore = false
            state = .loaded(legacy)
            return
        }

        do {
            print("[WorkoutVM] loadHistory: calling workoutService.getHistory")
            let response = try await workoutService.getHistory(
                from: nil,
                to: nil,
                limit: Self.pageSize,
                offset: 0
            )
            print("[WorkoutVM] getHistory OK: total=\(response.total) returned=\(response.workouts.count)")
            if response.workouts.isEmpty {
                print("[WorkoutVM] getHistory empty -> HealthKit fallback")
                await loadFromHealthKitFallback()
                return
            }
            let mapped = response.workouts.compactMap { WorkoutMapper.toWorkout($0) }
            try? await cacheService?.set(
                Self.historyCacheKey,
                WorkoutHistoryCache(items: mapped, total: response.total),
                ttl: Self.lastWorkoutTTL
            )
            total = response.total
            hasMore = total > mapped.count
            state = .loaded(mapped)
        } catch {
            print("[WorkoutVM] getHistory error: \(error) -> stale cache / fallback")
            if let stale: WorkoutHistoryCache = try? await cacheService?.get(Self.historyCacheKey, ignoreTTL: true),
               !stale.items.isEmpty {
                print("[WorkoutVM] stale history cache (\(stale.items.count)/\(stale.total))")
                total = stale.total
                hasMore = stale.total > stale.items.count
                state = .loaded(stale.items)
                return
            }
            await loadFromHealthKitFallback(error: error)
        }
    }

    private func topUpAfterCacheHit() async {
        print("[WorkoutVM] cache hit -> background network top-up")
        do {
            let response = try await workoutService.getHistory(
                from: nil,
                to: nil,
                limit: Self.pageSize,
                offset: 0
            )
            guard !Task.isCancelled else { return }
            guard case .loaded(let current) = state else { return }
            let known = Set(current.map(\.id))
            let fresh = response.workouts
                .compactMap { WorkoutMapper.toWorkout($0) }
                .filter { !known.contains($0.id) }
            let merged = current + fresh
            total = response.total
            hasMore = total > merged.count
            state = .loaded(merged)
            try? await cacheService?.set(
                Self.historyCacheKey,
                WorkoutHistoryCache(items: merged, total: total),
                ttl: Self.lastWorkoutTTL
            )
            if hasMore {
                loadMore()
            }
        } catch {
            print("[WorkoutVM] cache top-up failed: \(error)")
        }
    }

    private func loadFromHealthKitFallback(error: Error? = nil) async {
        let end = Date()
        guard let start = Calendar.current.date(
            byAdding: .day,
            value: -Self.displayWindowDays,
            to: end
        ) else {
            print("[WorkoutVM] fallback: bad dates -> empty")
            state = .loaded([])
            return
        }
        let local = await healthKit.fetchWorkouts(from: start, to: end)
        print("[WorkoutVM] fallback HealthKit(\(Self.displayWindowDays)d) = \(local.count)")
        total = local.count
        hasMore = false
        if local.isEmpty, let error {
            print("[WorkoutVM] fallback empty AND backend failed -> error state")
            state = .error(error)
            return
        }
        state = .loaded(local)
    }

    private func hasWorkoutAccess() async -> Bool {
        if userDeniedAccess {
            print("[WorkoutVM] user manually denied -> needsAccess")
            state = .needsAccess
            return false
        }

        let permission = healthKit.workoutPermissionState()
        print("[WorkoutVM] permission = \(permission) (isAvailable=\(healthKit.isAvailable))")

        switch permission {
        case .notDetermined:
            print("[WorkoutVM] notDetermined -> requesting authorization")
            do {
                try await healthKit.requestAuthorization()
                print("[WorkoutVM] requestAuthorization returned")
            } catch {
                print("[WorkoutVM] authorization failed: \(error)")
            }
        case .authorized:
            print("[WorkoutVM] permission authorized -> proceed")
        // HealthKit returns .sharingDenied even when read access was granted, so the raw
        // status can't distinguish a real denial from the iOS quirk. Thus we proceed and
        // handle an actual refusal via the userDeniedAccess flag (Open Settings / Try Again).
        // This is the only reliable escape hatch; there is no perfect programmatic answer.
        case .denied:
            print("[WorkoutVM] permission denied (status unreliable for read-only), proceeding like Activity")
        }

        guard healthKit.isAvailable else {
            print("[WorkoutVM] HealthKit unavailable -> needsAccess")
            state = .needsAccess
            return false
        }
        print("[WorkoutVM] HealthKit available -> proceed")
        return true
    }
}
