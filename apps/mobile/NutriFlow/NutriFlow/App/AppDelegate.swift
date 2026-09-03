import UIKit
import BackgroundTasks

final class AppDelegate: NSObject, UIApplicationDelegate {

    var backgroundSyncer: ActivityBackgroundSyncer?
    var healthKitService: HealthKitService?
    var activityService: ActivityServiceProtocol?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: ActivityBackgroundSyncer.taskIdentifier,
            using: nil
        ) { [weak self] task in
            self?.handleBackgroundRefresh(task: task as! BGAppRefreshTask)
        }
        print("[AppDelegate] registered BGTask \(ActivityBackgroundSyncer.taskIdentifier)")
        return true
    }

    private func handleBackgroundRefresh(task: BGAppRefreshTask) {
        print("[AppDelegate] background refresh started")

        Task { [weak self] in
            guard let self, let syncer = self.backgroundSyncer else {
                task.setTaskCompleted(success: false)
                return
            }

            guard syncer.isSessionActive else {
                print("[AppDelegate] skipped — session inactive")
                task.setTaskCompleted(success: true)
                return
            }

            guard let healthKit = self.healthKitService else {
                task.setTaskCompleted(success: false)
                return
            }

            let activity = await healthKit.fetchToday()
            try? await self.activityService?.sync(entries: [activity])
            task.setTaskCompleted(success: true)
            self.backgroundSyncer?.scheduleNextRefresh()
            print("[AppDelegate] background refresh completed")
        }
    }
}
