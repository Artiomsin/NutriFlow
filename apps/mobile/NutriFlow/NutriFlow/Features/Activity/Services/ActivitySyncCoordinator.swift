import Foundation

@MainActor
final class ActivitySyncCoordinator: ActivitySyncProtocol {

    private let healthKitService: ActivityHealthKitServiceProtocol
    private let activityService: ActivityServiceProtocol

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

    init(
        healthKitService: ActivityHealthKitServiceProtocol,
        activityService: ActivityServiceProtocol
    ) {
        self.healthKitService = healthKitService
        self.activityService = activityService
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
    }

    private func emit(_ activity: DailyActivity) {
        onActivityUpdate?(activity)
    }

    

    private func isAuthorized() async -> Bool {
        await healthKitService.permissionState() == .authorized
    }
}
