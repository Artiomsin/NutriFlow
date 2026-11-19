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
    /// Last payload the backend accepted. HealthKit fires an initial observer
    /// delivery right after startObserving(), which would otherwise produce a
    /// second identical POST three seconds after the startup sync.
    private var lastSyncedActivity: DailyActivity?

    var onActivityUpdate: ((DailyActivity) -> Void)? {
        didSet {
            guard let latestActivity else { return }
            emit(latestActivity)
        }
    }

    /// The coordinator can start before the Home view installs its callbacks,
    /// so the first failure is cached and replayed when the handler appears.
    private var latestError: AppError?

    var onActivityError: ((AppError) -> Void)? {
        didSet {
            guard let latestError else { return }
            onActivityError?(latestError)
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
        lastSyncedActivity = nil
        latestError = nil

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

        let activity: DailyActivity
        do {
            activity = try await healthKitService.fetchToday()
        } catch {
            print("[ActivitySyncCoordinator] refresh failed — HealthKit read error: \(error)")
            notifyActivityLoadError(error)
            return
        }

        guard isActive else {
            print("[ActivitySyncCoordinator] session ended during refresh")
            return
        }

        await syncToBackend(activity)

        guard isActive else {
            return
        }

        notifyActivityUpdate(activity)
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

            let activity: DailyActivity
            do {
                activity = try await self.healthKitService.fetchToday()
            } catch {
                print("[ActivitySyncCoordinator] authorization change sync failed — HealthKit read error: \(error)")
                self.notifyActivityLoadError(error)
                return
            }

            guard self.isActive, !Task.isCancelled else { return }

            await self.syncToBackend(activity)

            guard self.isActive, !Task.isCancelled else { return }

            self.notifyActivityUpdate(activity)

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
        if !PreferencesStore.shared.hasCompletedActivityBackfill {
            print("[ActivitySyncCoordinator] starting 30-day backfill")

            let calendar = AppDate.calendar

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

                // Mark the backfill done only after the backend accepted it.
                // syncToBackend swallows the error, so its result must be checked
                // here or an offline first launch would never retry 30 days.
                if await syncToBackend(entries) {
                    // An empty result can mean no data or denied HealthKit read
                    // access. HealthKit does not reveal which, so do not record
                    // this backfill as complete.
                    if entries.isEmpty {
                        print(
                            "[ActivitySyncCoordinator] backfill deferred — no readable HealthKit data"
                        )
                    } else if await healthKitService.hasLimitedHistory() {
                        print(
                            "[ActivitySyncCoordinator] backfill deferred — HealthKit history is limited"
                        )
                    } else {
                        PreferencesStore.shared.hasCompletedActivityBackfill = true
                        print(
                            "[ActivitySyncCoordinator] backfill completed: \(entries.count) days"
                        )
                    }
                } else {
                    print(
                        "[ActivitySyncCoordinator] backfill sync failed — will retry next launch"
                    )
                }
            } catch {
                print(
                    "[ActivitySyncCoordinator] backfill failed: \(error)"
                )
            }
        }

        let activity: DailyActivity
        do {
            activity = try await healthKitService.fetchToday()
        } catch {
            print("[ActivitySyncCoordinator] initial sync failed — HealthKit read error: \(error)")
            notifyActivityLoadError(error)
            return
        }

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
                // A cancelled debounce must still acknowledge any deliveries
                // already received, or HealthKit may stop sending updates.
                self?.healthKitService.completePendingObservations()
                return
            }

            guard let self else { return }
            guard self.isActive, !Task.isCancelled else {
                print("[ActivitySyncCoordinator] change sync skipped — inactive")
                self.healthKitService.completePendingObservations()
                return
            }

            guard await self.isAuthorized() else {
                print("[ActivitySyncCoordinator] change sync skipped — not authorized")
                self.healthKitService.completePendingObservations()
                return
            }

            let activity: DailyActivity
            do {
                activity = try await self.healthKitService.fetchToday()
            } catch {
                // The read is finished either way, so acknowledge the delivery
                // before reporting the error.
                self.healthKitService.completePendingObservations()
                print("[ActivitySyncCoordinator] change sync failed — HealthKit read error: \(error)")
                self.notifyActivityLoadError(error)
                return
            }

            // Acknowledge the delivery now that the HealthKit read is done.
            // There is no local queue, so a slow or killed network sync must
            // never keep the observer completion handler pending.
            self.healthKitService.completePendingObservations()

            guard self.isActive, !Task.isCancelled else {
                return
            }

            await self.syncToBackend(activity)

            guard self.isActive, !Task.isCancelled else {
                return
            }

            self.notifyActivityUpdate(activity)

            print("[ActivitySyncCoordinator] HealthKit change synced")
        }
    }

    

    @discardableResult
    private func syncToBackend(_ activity: DailyActivity) async -> Bool {
        guard isActive else {
            print("[ActivitySyncCoordinator] backend sync skipped — inactive")
            return false
        }

        // The startup observer delivery repeats the same reading three seconds
        // after the initial sync. It is already in the backend, so only skip
        // the network call - the observer completion is still acknowledged.
        if lastSyncedActivity == activity {
            print("[ActivitySyncCoordinator] backend sync skipped — unchanged since last successful sync")
            return true
        }

        // Partial days are still synced: fields whose HealthKit query failed
        // are encoded as `nil` and omitted from the JSON payload.
        if !activity.isComplete {
            print("[ActivitySyncCoordinator] syncing partial day — missing fields omitted")
        }

        do {
            try await activityService.sync(entries: [activity])

            lastSyncedActivity = activity
            print("[ActivitySyncCoordinator] backend sync success: \(activity)")
            return true
        } catch {
            print("[ActivitySyncCoordinator] backend sync failed: \(error)")
            return false
        }
    }

    @discardableResult
    private func syncToBackend(_ entries: [DailyActivity]) async -> Bool {
        guard isActive else {
            print("[ActivitySyncCoordinator] backend sync skipped — inactive")
            return false
        }

        do {
            try await activityService.sync(entries: entries)

            print(
                "[ActivitySyncCoordinator] backend sync success: \(entries.count) entries"
            )
            return true
        } catch {
            print("[ActivitySyncCoordinator] backend sync failed: \(error)")
            return false
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
        latestError = nil
        emit(activity)
        checkActivityAchievements(activity)
    }

    /// A failed HealthKit read leaves the card in `.loading` forever unless the
    /// view model is told to show an error with a retry action.
    private func notifyActivityLoadError(_ error: Error) {
        let appError = ErrorMapper.map(error)
        latestError = appError
        print("[ActivitySyncCoordinator] notifying activity load error: \(appError)")
        onActivityError?(appError)
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
            if let steps = activity.steps, let stepGoal = goals.dailyStepsGoal {
                items += achievementService.checkSteps(steps, goal: stepGoal)
            }
            if let calories = activity.activeCalories,
               let activeGoal = goals.dailyActiveCaloriesGoal {
                items += achievementService.checkActiveCalories(
                    calories,
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
