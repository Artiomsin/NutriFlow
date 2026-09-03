import Observation
import Foundation
import UIKit


@Observable
@MainActor
final class ActivityViewModel{
    
    var state: ActivityState = .idle
    
    @ObservationIgnored private let healthKit: HealthKitService
    @ObservationIgnored private let activityService: ActivityServiceProtocol
    @ObservationIgnored private var backgroundSyncer: ActivityBackgroundSyncer?
    
    private var hasRequestedAuth: Bool {
        get { UserDefaults.standard.bool(forKey: "hasRequestedHealthAuth") }
        set { UserDefaults.standard.set(newValue, forKey: "hasRequestedHealthAuth") }
    }
    
    
    init(healthKit: HealthKitService, activityService: ActivityServiceProtocol, backgroundSyncer: ActivityBackgroundSyncer? = nil) {
            self.healthKit = healthKit
            self.activityService = activityService
            self.backgroundSyncer = backgroundSyncer
        }

    
    func onAppear() {
            if !hasRequestedAuth {
                state = .needsAccess
            } else {
                Task {
                    await load()
                    setUpBackground()
                }
            }
        }

    private func setUpBackground() {
        backgroundSyncer?.onActivityUpdate = { [weak self] activity in
            Task { @MainActor in
                self?.state = .loaded(activity)
                print("[ActivityCard] background update → \(activity)")
            }
        }
        backgroundSyncer?.start()
    }
    
    func connectTapped() async {
            print("[HealthKit] connectTapped → requesting auth")
            hasRequestedAuth = true
            state = .loading
            do {
                try await healthKit.requestAuthorization()
                print("[HealthKit] after auth → loading")
                await load()
                setUpBackground()
            } catch {
                print("[HealthKit] connectTapped error: \(error)")
                state = .error(error)
            }
        }

    
    func openSettings() {
            print("[HealthKit] openSettings")
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        }

        private func load() async {
            print("[HealthKit] load → state=loading")
            state = .loading
            let activity = await healthKit.fetchToday()
            print("[HealthKit] load got activity: \(activity) → state=loaded")
            state = .loaded(activity)
            print("[HealthKit] load → syncing to backend")
            try? await activityService.sync(entries: [activity])
            print("[HealthKit] load → sync done")
        }
}
