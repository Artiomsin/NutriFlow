import Foundation

final class SleepSyncCoordinator: SleepSyncProtocol {

    private let healthKitService: SleepHealthKitServiceProtocol
    private let sleepService: SleepServiceProtocol
    private let cacheService: CacheService

    private var lastHistorySyncedAt: Date? {
        get { UserDefaults.standard.object(forKey: Self.lastHistorySyncedKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: Self.lastHistorySyncedKey) }
    }

    private var lastNightFetchedAt: Date? {
        UserDefaults.standard.object(forKey: Self.lastNightFetchedKey) as? Date
    }

    private static let lastHistorySyncedKey = "sleep_last_history_synced_at"
    private static let lastNightCacheKey = "sleep_last_night"
    private static let historyCacheKey = "sleep_history_7d"
    private static let lastNightFetchedKey = "sleep_last_night_fetched_at"

    private static let lastNightCacheTTL: TimeInterval = 6 * 3600
    private static let historyCacheTTL: TimeInterval = 3600
    private static let lastNightFreshness: TimeInterval = 15 * 60

    init(
        healthKitService: SleepHealthKitServiceProtocol,
        sleepService: SleepServiceProtocol,
        cacheService: CacheService
    ) {
        self.healthKitService = healthKitService
        self.sleepService = sleepService
        self.cacheService = cacheService
    }

    func permissionState() async -> HealthKitPermissionState {
        await healthKitService.permissionState()
    }


    func connect() async -> SleepConnectionResult {
        do {
            try await healthKitService.requestAuthorization()
        } catch {
            return .needsAccess
        }

        switch await healthKitService.permissionState() {
        case .authorized:
            return .authorized
        case .denied:
            return .denied
        case .notDetermined:
            return .needsAccess
        }
    }



    func loadLastNight() async throws -> HealthKitSleep? {
        let calendar = Calendar.current

        let todayNoon = calendar.date(
            bySettingHour: 12,
            minute: 0,
            second: 0,
            of: Date()
        ) ?? Date()

        let yesterdayNoon = calendar.date(
            byAdding: .day,
            value: -1,
            to: todayNoon
        ) ?? todayNoon

        if let cached: HealthKitSleep = try? await cacheService.get(Self.lastNightCacheKey),
           cached.startDate >= yesterdayNoon,
           let fetchedAt = lastNightFetchedAt,
           Date().timeIntervalSince(fetchedAt) < Self.lastNightFreshness {
            return cached
        }

        guard let sleep = try await healthKitService.fetchSleep(
            from: yesterdayNoon,
            to: todayNoon
        ) else {
            return nil
        }

        let changed: Bool

        if let cached: HealthKitSleep = try? await cacheService.get(Self.lastNightCacheKey) {
            changed = fingerprint(cached) != fingerprint(sleep)
        } else {
            changed = true
        }

        UserDefaults.standard.set(
            Date(),
            forKey: Self.lastNightFetchedKey
        )

        // Fresh HealthKit data always refreshes cache + TTL.
        try? await cacheService.set(
            Self.lastNightCacheKey,
            sleep,
            ttl: Self.lastNightCacheTTL
        )

        // Backend only when data actually changed/new.
        if changed {
            await syncEntries([
                SleepMapper.toEntry(sleep)
            ])
        }

        return sleep
    }

   

    func loadHistoryIfNeeded() async throws -> [HealthKitSleep] {
        if let last = lastHistorySyncedAt,
           Date().timeIntervalSince(last) < Self.historyCacheTTL {
            return try await cachedHistory() ?? []
        }

        let history = try await loadHistory(
            useCache: true,
            reconcile: false
        )

        lastHistorySyncedAt = Date()

        return history
    }

    func refreshHistory() async throws -> [HealthKitSleep] {
        let history = try await loadHistory(
            useCache: false,
            reconcile: true
        )

        lastHistorySyncedAt = Date()

        return history
    }

    private func cachedHistory() async throws -> [HealthKitSleep]? {
        try? await cacheService.get(Self.historyCacheKey)
    }

    private func loadHistory(
        useCache: Bool,
        reconcile: Bool
    ) async throws -> [HealthKitSleep] {
        let calendar = Calendar.current

        let todayNoon = calendar.date(
            bySettingHour: 12,
            minute: 0,
            second: 0,
            of: Date()
        ) ?? Date()

        let sevenDaysAgo = calendar.date(
            byAdding: .day,
            value: -7,
            to: todayNoon
        ) ?? todayNoon

        var cached: [HealthKitSleep] = []

        // Cache-first UI.
        if useCache,
           let cachedHistory: [HealthKitSleep] = try? await cacheService.get(Self.historyCacheKey) {
            cached = cachedHistory
        }

        let fetched = try await healthKitService.fetchNights(
            from: sevenDaysAgo,
            to: todayNoon
        )

        let sorted = fetched.sorted {
            $0.startDate > $1.startDate
        }

        // Detect only new/changed nights.
        let changed = changedNights(
            cached: cached,
            fresh: sorted
        )

        // Fresh HealthKit data always refreshes history cache + TTL.
        try? await cacheService.set(
            Self.historyCacheKey,
            sorted,
            ttl: Self.historyCacheTTL
        )

        // Backend only receives changed/new nights.
        if !changed.isEmpty {
            await syncNow(changed)
        }

        if reconcile {
            await reconcileBackend(
                kept: sorted,
                windowStart: sevenDaysAgo,
                windowEnd: todayNoon
            )
        }

        return sorted
    }

    

    func loadNightDetail(
        _ night: HealthKitSleep
    ) async throws -> SleepNightDetailResult {

        // Sleep detail and HR are independent HealthKit queries.
        // Run them in parallel.
        async let sleepTask =
            healthKitService.fetchSleep(
                from: night.startDate,
                to: night.endDate
            )

        async let heartRateTask =
            healthKitService.fetchHeartRateDuringSleep(
                from: night.startDate,
                to: night.endDate
            )

        let result = try await (
            sleep: sleepTask,
            heartRate: heartRateTask
        )

        return SleepNightDetailResult(
            sleep: result.sleep ?? night,
            heartRate: result.heartRate
        )
    }

    

    private func syncNow(
        _ nights: [HealthKitSleep]
    ) async {
        await syncEntries(
            nights.map {
                SleepMapper.toEntry($0)
            }
        )
    }

    private func syncEntries(
        _ entries: [SleepSyncEntry]
    ) async {
        guard !entries.isEmpty else {
            return
        }

        do {
            try await sleepService.sync(
                entries: entries
            )

            print(
                "[SleepSync] synced \(entries.count) nights"
            )

        } catch {
            print(
                "[SleepSync] backend sync failed: \(error)"
            )
        }
    }

    private func reconcileBackend(
        kept: [HealthKitSleep],
        windowStart: Date,
        windowEnd: Date
    ) async {
        do {
            let response = try await sleepService.getHistory(
                from: SleepKey.dayKey(windowStart),
                to: SleepKey.dayKey(windowEnd),
                limit: 1000,
                offset: nil
            )

            let keptStarts = kept.map(\.startDate)

            let stale = response.nights.filter { entry in
                guard let backendDate = SleepKey.parseISODate(entry.startDate) else {
                    return false
                }

                return !keptStarts.contains { nightDate in
                    abs(nightDate.timeIntervalSince(backendDate)) < 300
                }
            }

            let staleStartDates = stale.map(\.startDate)

            guard !staleStartDates.isEmpty else {
                return
            }

            // Delete the nights that actually exist on backend
            // but are missing from HealthKit.
            try await sleepService.deleteMissing(
                from: SleepMapper.isoString(from: windowStart),
                startDates: staleStartDates
            )

            print(
                "[SleepSync] reconciled: deleted \(staleStartDates.count) nights missing in HealthKit"
            )

        } catch {
            print(
                "[SleepSync] backend reconcile failed: \(error)"
            )
        }
    }


    private struct SleepFingerprint: Equatable {
        let startDate: Date
        let endDate: Date

        let timeInBedSeconds: Double
        let asleepSeconds: Double
        let awakeSeconds: Double

        let coreSeconds: Double
        let deepSeconds: Double
        let remSeconds: Double
        let unspecifiedSeconds: Double

        let awakenings: Int

        let onsetLatencySeconds: Double?
        let efficiency: Double?

        let segmentCount: Int
        let heartRateAvg: Double?
    }

    private func fingerprint(
        _ sleep: HealthKitSleep
    ) -> SleepFingerprint {
        SleepFingerprint(
            startDate: sleep.startDate,
            endDate: sleep.endDate,
            timeInBedSeconds: sleep.timeInBedSeconds,
            asleepSeconds: sleep.asleepSeconds,
            awakeSeconds: sleep.awakeSeconds,
            coreSeconds: sleep.coreSeconds,
            deepSeconds: sleep.deepSeconds,
            remSeconds: sleep.remSeconds,
            unspecifiedSeconds: sleep.unspecifiedSeconds,
            awakenings: sleep.awakenings,
            onsetLatencySeconds: sleep.onsetLatencySeconds,
            efficiency: sleep.efficiency,
            segmentCount: sleep.segmentCount,
            heartRateAvg: sleep.heartRateAvg
        )
    }

    private func changedNights(
        cached: [HealthKitSleep],
        fresh: [HealthKitSleep]
    ) -> [HealthKitSleep] {

        let cachedByKey = Dictionary(
            uniqueKeysWithValues: cached.map {
                (SleepKey.nightKey($0), $0)
            }
        )

        return fresh.filter { freshNight in
            guard let cachedNight = cachedByKey[SleepKey.nightKey(freshNight)] else {
                // New night.
                return true
            }

            // Existing night — sync only if data changed.
            return fingerprint(cachedNight) != fingerprint(freshNight)
        }
    }
}
