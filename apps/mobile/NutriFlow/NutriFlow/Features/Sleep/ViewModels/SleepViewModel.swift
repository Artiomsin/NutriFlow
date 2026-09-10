import SwiftUI
import Observation

@MainActor
@Observable
final class SleepViewModel {

    @ObservationIgnored private let healthKitService: SleepHealthKitServiceProtocol
    @ObservationIgnored private let sleepService: SleepServiceProtocol
    @ObservationIgnored private let cacheService: CacheService?

    private static let lastNightCacheKey = "sleep_last_night"
    private static let historyCacheKey = "sleep_history_7d"

    private static let lastNightCacheTTL: TimeInterval = 6 * 3600
    private static let historyCacheTTL: TimeInterval = 3600

    var state: SleepState = .idle
    var history: [HealthKitSleep] = []
    var selectedNight: HealthKitSleep?
    var timeline: [SleepStageSegment] = []
    var sleepHeartRatePoints: [SleepHeartRatePoint] = []

    private var hasRequestedAuth: Bool {
        get {
            UserDefaults.standard.bool(forKey: "hasRequestedSleepAuth")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "hasRequestedSleepAuth")
        }
    }

    private var hasLoadedHistory = false

  

    init(
        healthKitService: SleepHealthKitServiceProtocol,
        sleepService: SleepServiceProtocol,
        cacheService: CacheService? = nil
    ) {
        self.healthKitService = healthKitService
        self.sleepService = sleepService
        self.cacheService = cacheService
    }

    // MARK: - Home

    func onAppear() async {
        guard hasRequestedAuth else {
            state = .needsAccess
            return
        }

        guard !isLoaded else {
            return
        }

        await refreshLastNight(showCacheFirst: true)
    }

    private var isLoaded: Bool {
        if case .loaded = state {
            return true
        }

        return false
    }

    func connectTapped() async {
        do {
            try await healthKitService.requestAuthorization()
            hasRequestedAuth = true

            await refreshLastNight(showCacheFirst: false)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func refreshLastNight(showCacheFirst: Bool) async {
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

        var cached: HealthKitSleep?

        // Cache-first UI
        if showCacheFirst {
            cached = await cachedLastNight()

            if let cached {
                state = .loaded([cached])
            }
        }

        if !isLoaded {
            state = .loading
        }

        do {
            guard let sleep = try await healthKitService.fetchSleep(
                from: yesterdayNoon,
                to: todayNoon
            ) else {
                if isLoaded {
                    return
                }

                state = .empty
                return
            }

            let changed: Bool

            if let cached {
                changed = fingerprint(cached) != fingerprint(sleep)
            } else {
                changed = true
            }

            // Fresh HealthKit data always refreshes cache + TTL.
            try? await cacheService?.set(
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

            state = .loaded([sleep])

        } catch {
            // If cache is already visible, keep it.
            if isLoaded {
                return
            }

            state = .error(error.localizedDescription)
        }
    }

    private func cachedLastNight() async -> HealthKitSleep? {
        guard let cache = cacheService else {
            return nil
        }

        return (try? await cache.get(Self.lastNightCacheKey)) ?? nil
    }

    // MARK: - History

    func loadHistoryIfNeeded() async {
        guard !hasLoadedHistory else {
            return
        }

        hasLoadedHistory = true

        await loadHistory(
            useCache: true,
            reconcile: false
        )
    }

    func refreshHistory() async {
        hasLoadedHistory = true

        await loadHistory(
            useCache: false,
            reconcile: true
        )
    }

    private func cachedHistory() async -> [HealthKitSleep]? {
        guard let cache = cacheService else {
            return nil
        }

        return (try? await cache.get(Self.historyCacheKey)) ?? nil
    }

    private func loadHistory(
        useCache: Bool,
        reconcile: Bool
    ) async {
        state = .loading

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
           let cachedHistory = await cachedHistory() {

            cached = cachedHistory
            history = cachedHistory

            state = cachedHistory.isEmpty
                ? .empty
                : .loaded(cachedHistory)
        }

        do {
            let fetched = try await healthKitService.fetchNights(
                from: sevenDaysAgo,
                to: todayNoon
            )

            let sorted = fetched.sorted {
                $0.startDate > $1.startDate
            }

            history = sorted

            // Detect only new/changed nights.
            let changed = changedNights(
                cached: cached,
                fresh: sorted
            )

            // Fresh HealthKit data always refreshes history cache + TTL.
            try? await cacheService?.set(
                Self.historyCacheKey,
                sorted,
                ttl: Self.historyCacheTTL
            )

            // Backend only receives changed/new nights.
            if !changed.isEmpty {
                await syncNow(changed)
            }

            // Backend reconciliation only for explicit refresh.
            if reconcile {
                await reconcileBackend(
                    kept: sorted,
                    windowStart: sevenDaysAgo,
                    windowEnd: todayNoon
                )
            }

            state = sorted.isEmpty
                ? .empty
                : .loaded(sorted)

        } catch {
            hasLoadedHistory = false

            // If cache/history exists, keep showing it.
            if history.isEmpty {
                state = .error(error.localizedDescription)
            }
        }
    }

    // MARK: - Night Detail

    func loadNightDetail(
        _ night: HealthKitSleep
    ) async {

        // Immediately show already available timeline.
        timeline = night.segments

        // Remove HR from previously selected night.
        sleepHeartRatePoints = []

        do {

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

            let (fetched, heartRatePoints) = try await (
                sleepTask,
                heartRateTask
            )

            // Update HR graph.
            sleepHeartRatePoints = heartRatePoints

            guard let fetched else {
                return
            }

            // Update sleep timeline.
            timeline = fetched.segments

            let changed =
                fingerprint(night) != fingerprint(fetched)

            // Update history using logical night identity.
            if let index = history.firstIndex(
                where: {
                    nightKey($0) == nightKey(night)
                }
            ) {
                history[index] = fetched
            }

            // Refresh history cache.
            try? await cacheService?.set(
                Self.historyCacheKey,
                history,
                ttl: Self.historyCacheTTL
            )

            // Refresh last-night cache if this is latest night.
            if history.first?.startDate == fetched.startDate {

                try? await cacheService?.set(
                    Self.lastNightCacheKey,
                    fetched,
                    ttl: Self.lastNightCacheTTL
                )
            }

            // Backend only if sleep data changed.
            if changed {
                await syncEntries([
                    SleepMapper.toEntry(fetched)
                ])
            }

        } catch {

            print(
                "[SleepVM] detail fetch failed: \(error)"
            )
        }
    }

    func clearSelection() {
        selectedNight = nil
        timeline = []
        sleepHeartRatePoints = []
    }

    // MARK: - Backend Reconciliation

    private func reconcileBackend(
        kept: [HealthKitSleep],
        windowStart: Date,
        windowEnd: Date
    ) async {
        do {
            let response = try await sleepService.getHistory(
                from: dayKey(windowStart),
                to: dayKey(windowEnd),
                limit: 1000,
                offset: nil
            )

            let keptStarts = kept.map(\.startDate)

            let stale = response.nights.filter { entry in
                guard let backendDate = parseISODate(entry.startDate) else {
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
                "[SleepVM] reconciled: deleted \(staleStartDates.count) nights missing in HealthKit"
            )

        } catch {
            print(
                "[SleepVM] backend reconcile failed: \(error)"
            )
        }
    }

    // MARK: - Date Helpers

    private func parseISODate(_ string: String) -> Date? {
        if let date = SleepMapper.isoFormatter.date(from: string) {
            return date
        }

        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds
        ]

        return fractional.date(from: string)
    }

    private func dayKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        return formatter.string(from: date)
    }

    private func nightKey(_ night: HealthKitSleep) -> String {
        dayKey(night.startDate)
    }

    // MARK: - Fingerprint

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

    // MARK: - Changed Nights

    private func changedNights(
        cached: [HealthKitSleep],
        fresh: [HealthKitSleep]
    ) -> [HealthKitSleep] {

        let cachedByKey = Dictionary(
            uniqueKeysWithValues: cached.map {
                (nightKey($0), $0)
            }
        )

        return fresh.filter { freshNight in
            guard let cachedNight = cachedByKey[nightKey(freshNight)] else {
                // New night.
                return true
            }

            // Existing night — sync only if data changed.
            return fingerprint(cachedNight) != fingerprint(freshNight)
        }
    }

    // MARK: - Sync

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
                "[SleepVM] synced \(entries.count) nights"
            )

        } catch {
            print(
                "[SleepVM] backend sync failed: \(error)"
            )
        }
    }
}


