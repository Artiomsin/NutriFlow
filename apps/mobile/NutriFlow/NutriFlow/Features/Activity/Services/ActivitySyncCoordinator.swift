import Foundation

final class ActivitySyncCoordinator: ActivitySyncProtocol {

    private let healthKitService: HealthKitServiceProtocol
    private let activityService: ActivityServiceProtocol

    private var isActive = false
    private var coalesceTask: Task<Void, Never>?
    private var didConfigureBackgroundDelivery = false

    var onActivityUpdate: ((DailyActivity) -> Void)?

    init(healthKitService: HealthKitServiceProtocol, activityService: ActivityServiceProtocol) {
        self.healthKitService = healthKitService
        self.activityService = activityService
    }

    var isSessionActive: Bool { isActive }

    func start() {
        guard !isActive else {
            print("[SyncCoordinator] already active — skipping start")
            return
        }
        isActive = true
        healthKitService.onActivityChanged = { [weak self] in
            self?.handleHealthKitChange()
        }
        Task {
            await configureBackgroundDeliveryOnce()
        }
        healthKitService.startObserving()
        print("[SyncCoordinator] started")
    }

    func stop() {
        guard isActive else {
            print("[SyncCoordinator] already stopped — skipping stop")
            return
        }
        isActive = false
        coalesceTask?.cancel()
        coalesceTask = nil
        healthKitService.stopObserving()
        print("[SyncCoordinator] stopped")
    }

    func refresh() async {
        guard isActive else {
            print("[SyncCoordinator] skipped refresh — session inactive")
            return
        }
        await configureBackgroundDeliveryOnce()
        let activity = await healthKitService.fetchToday()
        await syncToBackend(activity)
        onActivityUpdate?(activity)
    }

    /// Debounce/coalesce: many rapid observer signals → a single fetch + sync.
    private func handleHealthKitChange() {
        coalesceTask?.cancel()
        coalesceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard let self else { return }
            guard self.isActive, !Task.isCancelled else {
                print("[SyncCoordinator] skipped sync — session inactive or cancelled")
                return
            }
            let fresh = await self.healthKitService.fetchToday()
            await self.syncToBackend(fresh)
            self.onActivityUpdate?(fresh)
        }
    }

    private func syncToBackend(_ activity: DailyActivity) async {
        guard isActive else {
            print("[SyncCoordinator] skipped sync — session inactive (before backend call)")
            return
        }
        do {
            try await activityService.sync(entries: [activity])
        } catch {
            print("[SyncCoordinator] backend sync failed: \(error)")
        }
        guard isActive else {
            print("[SyncCoordinator] session ended during backend sync — no UI update")
            return
        }
        print("[SyncCoordinator] synced to backend: \(activity)")
    }

    private func configureBackgroundDeliveryOnce() async {
        guard !didConfigureBackgroundDelivery else { return }
        do {
            try await healthKitService.enableBackgroundDelivery()
            didConfigureBackgroundDelivery = true
            print("[SyncCoordinator] background delivery configured once")
        } catch {
            print("[SyncCoordinator] failed to configure background delivery: \(error)")
        }
    }
}
