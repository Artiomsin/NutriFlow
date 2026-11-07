import Foundation

@MainActor
final class ActivitySyncCoordinator: ActivitySyncProtocol {

    private let healthKitService: ActivityHealthKitServiceProtocol
    private let activityService: ActivityServiceProtocol
    private let goalsService: GoalsServiceProtocol?
    private let achievementService: AchievementService?
    private let achievementNotificationService: AchievementNotificationService?

    private var isActive = false
    private var coalesceTask: Task<Void, Never>?
    private var initialSyncTask: Task<Void, Never>?
    private var didConfigureBackgroundDelivery = false
    private var latestActivity: DailyActivity?

    var onActivityUpdate: ((DailyActivity) -> Void)? {
        didSet {
            guard let latestActivity else { return }
            emit(latestActivity)
        }
    }

    var goalsProvider: (() -> UserGoals?)?

    init(
        healthKitService: ActivityHealthKitServiceProtocol,
        activityService: ActivityServiceProtocol,
        goalsService: GoalsServiceProtocol? = nil,
        achievementService: AchievementService? = nil,
        achievementNotificationService: AchievementNotificationService? = nil
    ) {
        self.healthKitService = healthKitService
        self.activityService = activityService
        self.goalsService = goalsService
        self.achievementService = achievementService
        self.achievementNotificationService = achievementNotificationService
    }

    var isSessionActive: Bool {
        isActive
    }



    func start() {
        guard !isActive else {
            print("[ActivitySyncCoordinator] already active")
            return
        }

        isActive = true

        healthKitService.onActivityChanged = { [weak self] in
            Task { @MainActor [weak self] in
                self?.handleHealthKitChange()
            }
        }

        healthKitService.startObserving()

        initialSyncTask = Task { @MainActor [weak self] in
            guard let self else { return }

            await self.configureBackgroundDeliveryOnce()
            await self.performInitialSync()
        }

        print("[ActivitySyncCoordinator] started")
    }

    func stop() {
        guard isActive else {
            print("[ActivitySyncCoordinator] already stopped")
            return
        }

        isActive = false

        coalesceTask?.cancel()
        coalesceTask = nil

        initialSyncTask?.cancel()
        initialSyncTask = nil

        latestActivity = nil

        healthKitService.onActivityChanged = nil
        healthKitService.stopObserving()

        print("[ActivitySyncCoordinator] stopped")
    }

    

    func refresh() async {
        guard isActive else {
            print("[ActivitySyncCoordinator] refresh skipped — inactive")
            return
        }

        guard await isAuthorized() else {
            print("[ActivitySyncCoordinator] refresh skipped — not authorized")
            return
        }

        // M1: background delivery retries in-session if it failed at start().
        await configureBackgroundDeliveryOnce()

        let activity = await healthKitService.fetchToday()

        guard isActive else {
            print("[ActivitySyncCoordinator] session ended during refresh")
            return
        }

        await syncToBackend(activity)

        guard isActive else {
            return
        }

        notifyActivityUpdate(activity)

        // Process any pending queue entries after the refresh sync.
        await processPendingQueue()
    }

    func authorizationDidChange() {
        guard isActive else {
            print("[ActivitySyncCoordinator] authorizationDidChange — inactive, ignored")
            return
        }

        coalesceTask?.cancel()

        coalesceTask = Task { @MainActor [weak self] in
            guard let self, self.isActive, !Task.isCancelled else { return }

            guard await self.isAuthorized() else {
                print("[ActivitySyncCoordinator] authorizationDidChange — not authorized")
                return
            }

            let activity = await self.healthKitService.fetchToday()

            guard self.isActive, !Task.isCancelled else { return }

            await self.syncToBackend(activity)

            guard self.isActive, !Task.isCancelled else { return }

            self.notifyActivityUpdate(activity)

            // Process any pending queue entries after the authorization change sync.
            await processPendingQueue()

            print("[ActivitySyncCoordinator] authorization change synced")
        }
    }

    

    private func performInitialSync() async {
        guard isActive else {
            return
        }

        guard await isAuthorized() else {
            print("[ActivitySyncCoordinator] initial sync skipped — not authorized")
            return
        }

        // M1: Backfill last 30 days on first ever launch after install/reinstall.
        if !PreferencesStore.shared.hasCompletedInitialBackfill {
            print("[ActivitySyncCoordinator] starting 30-day backfill")

            var calendar = Calendar.current
            let tz = TimeZone(identifier: PreferencesStore.shared.timeZone) ?? .current
            calendar.timeZone = tz

            let end = Date()
            guard let start = calendar.date(
                byAdding: .day,
                value: -30,
                to: end
            ) else {
                print("[ActivitySyncCoordinator] backfill: cannot compute start date")
                return
            }

            do {
                let entries = try await healthKitService.fetchRange(from: start, to: end)

                guard isActive else { return }

                await syncToBackend(entries)

                PreferencesStore.shared.hasCompletedInitialBackfill = true
                print(
                    "[ActivitySyncCoordinator] backfill completed: \(entries.count) days"
                )
            } catch {
                print(
                    "[ActivitySyncCoordinator] backfill failed: \(error)"
                )
            }
        }

        let activity = await healthKitService.fetchToday()

        guard isActive else {
            print("[ActivitySyncCoordinator] session ended during initial sync")
            return
        }

        await syncToBackend(activity)

        guard isActive else {
            return
        }

        notifyActivityUpdate(activity)

        print("[ActivitySyncCoordinator] initial sync completed")
    }

 

    private func handleHealthKitChange() {
        guard isActive else {
            return
        }

        coalesceTask?.cancel()

        coalesceTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .seconds(3))
            } catch {
                return
            }

            guard let self else { return }
            guard self.isActive, !Task.isCancelled else {
                print("[ActivitySyncCoordinator] change sync skipped — inactive")
                return
            }

            guard await self.isAuthorized() else {
                print("[ActivitySyncCoordinator] change sync skipped — not authorized")
                return
            }

            let activity = await self.healthKitService.fetchToday()

            guard self.isActive, !Task.isCancelled else {
                return
            }

            await self.syncToBackend(activity)

            // Complete the HealthKit observer callback only after the data has
            // been persisted (synced to backend or queued locally). This
            // prevents HealthKit from considering the delivery done before we
            // have actually saved the data.
            self.healthKitService.completePendingObservations()

            guard self.isActive, !Task.isCancelled else {
                return
            }

            self.notifyActivityUpdate(activity)

            print("[ActivitySyncCoordinator] HealthKit change synced")
        }
    }

    

    private func syncToBackend(_ activity: DailyActivity) async {
        guard isActive else {
            print("[ActivitySyncCoordinator] backend sync skipped — inactive")
            return
        }

        do {
            try await activityService.sync(entries: [activity])

            print("[ActivitySyncCoordinator] backend sync success: \(activity)")
        } catch {
            print("[ActivitySyncCoordinator] backend sync failed: \(error)")
        }
    }

    private func syncToBackend(_ entries: [DailyActivity]) async {
        guard isActive else {
            print("[ActivitySyncCoordinator] backend sync skipped — inactive")
            return
        }

        do {
            // Low-level send without re-enqueueing (entries are already in queue
            // if they came from processPendingQueue).
            try await activityService.send(entries: entries)

            print(
                "[ActivitySyncCoordinator] backend sync success: \(entries.count) entries"
            )
        } catch {
            print("[ActivitySyncCoordinator] backend sync failed: \(error)")
        }
    }


    private let baseRetryDelay: TimeInterval = 1.0
    private let maxRetryDelay: TimeInterval = 300.0

    /// Processes pending entries from the local sync queue with exponential backoff.
    /// Only entries whose nextRetryAt has passed are retried.
    /// Called on app start, refresh, and after successful syncs.
    private func processPendingQueue() async {
        let pending = SyncQueue.shared.readyForRetry
        guard !pending.isEmpty else { return }

        let entries: [DailyActivity] = pending.compactMap { dict in
            guard
                let date = dict["date"] as? String,
                let steps = dict["steps"] as? Int,
                let activeCalories = dict["activeCalories"] as? Double,
                let basalCalories = dict["basalCalories"] as? Double,
                let distanceMeters = dict["distanceMeters"] as? Double
            else {
                return nil
            }
            return DailyActivity(
                date: date,
                steps: steps,
                activeCalories: activeCalories,
                basalCalories: basalCalories,
                distanceMeters: distanceMeters
            )
        }

        guard !entries.isEmpty else {
            SyncQueue.shared.removeAll()
            return
        }

        do {
            try await activityService.send(entries: entries)

            entries.forEach { SyncQueue.shared.remove($0.date) }
            SyncQueue.shared.removeOlderThan(days: 30)
        } catch {
            for entry in entries {
                var updated = SyncQueue.shared.all.first { $0["date"] as? String == entry.date } ?? [:]
                var retryCount = (updated["retryCount"] as? Int) ?? 0
                retryCount += 1
                updated["retryCount"] = retryCount

                let delay = min(
                    pow(2.0, Double(retryCount)) * baseRetryDelay,
                    maxRetryDelay
                )
                let nextRetry = Date().addingTimeInterval(delay)
                updated["nextRetryAt"] = SyncQueue.isoFormatter.string(from: nextRetry)

                SyncQueue.shared.update(updated)
            }
        }
    }

   

    private func configureBackgroundDeliveryOnce() async {
        guard !didConfigureBackgroundDelivery else {
            return
        }

        do {
            try await healthKitService.enableBackgroundDelivery()

            didConfigureBackgroundDelivery = true

            print("[ActivitySyncCoordinator] background delivery configured")
        } catch {
            print("[ActivitySyncCoordinator] background delivery failed: \(error)")
        }
    }



    private func notifyActivityUpdate(_ activity: DailyActivity) {
        latestActivity = activity
        emit(activity)
        checkActivityAchievements(activity)
    }

    private func checkActivityAchievements(_ activity: DailyActivity) {
        guard
            let achievementService,
            let achievementNotificationService,
            let goalsService
        else { return }

        Task { @MainActor in
            let goals: UserGoals?
            if let goalsProvider, let live = goalsProvider() {
                goals = live
            } else {
                goals = try? await goalsService.getGoals()
            }
            guard let goals else { return }

            var items: [Achievement] = []
            if let stepGoal = goals.dailyStepsGoal {
                items += achievementService.checkSteps(activity.steps, goal: stepGoal)
            }
            if let activeGoal = goals.dailyActiveCaloriesGoal {
                items += achievementService.checkActiveCalories(
                    activity.activeCalories,
                    goal: activeGoal
                )
            }

            guard !items.isEmpty else { return }
            await achievementNotificationService.notifyIfNeeded(achievements: items)
        }
    }

    private func emit(_ activity: DailyActivity) {
        onActivityUpdate?(activity)
    }

    

    private func isAuthorized() async -> Bool {
        await healthKitService.permissionState() == .authorized
    }
}
