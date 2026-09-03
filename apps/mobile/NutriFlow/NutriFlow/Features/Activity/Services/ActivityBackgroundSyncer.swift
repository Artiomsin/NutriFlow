import Foundation
import BackgroundTasks

final class ActivityBackgroundSyncer {

    private let healthKitService: HealthKitService
    private let activityService: ActivityServiceProtocol

    private var isActive = false

    var onActivityUpdate: ((DailyActivity) -> Void)?

    static let taskIdentifier = "com.nutriflow.activity-refresh"

    init(healthKitService: HealthKitService, activityService: ActivityServiceProtocol) {
        self.healthKitService = healthKitService
        self.activityService = activityService
    }

    func start() {
        isActive = true
        healthKitService.onActivityUpdate = { [weak self] activity in
            self?.handleUpdate(activity)
        }
        enableBackgroundDelivery()
        startObserving()
        scheduleNextRefresh()
    }

    func stop() {
        isActive = false
        healthKitService.stopObserving()
        print("[BackgroundSync] stopped")
    }

    private func handleUpdate(_ activity: DailyActivity) {
        onActivityUpdate?(activity)
        syncToBackend(activity)
    }

    var isSessionActive: Bool { isActive }

    private func enableBackgroundDelivery() {
        Task {
            do {
                try await healthKitService.enableBackgroundDelivery()
            } catch {
                print("[BackgroundSync] delivery failed: \(error)")
            }
        }
    }

    private func startObserving() {
        healthKitService.startObserving()
    }

    private func syncToBackend(_ activity: DailyActivity) {
        guard isActive else {
            print("[BackgroundSync] skipped sync — session inactive")
            return
        }
        Task {
            guard isActive else {
                print("[BackgroundSync] skipped sync — session inactive (inside task)")
                return
            }
            try? await activityService.sync(entries: [activity])
            print("[BackgroundSync] synced to backend: \(activity)")
        }
    }

    func scheduleNextRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }
}
