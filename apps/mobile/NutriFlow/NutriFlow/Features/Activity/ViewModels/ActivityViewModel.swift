import Observation
import Foundation
import UIKit


@Observable
@MainActor
final class ActivityViewModel{
    
    var state: ActivityState = .idle
    
    @ObservationIgnored private let healthKit: ActivityHealthKitServiceProtocol
    @ObservationIgnored private let activitySync: ActivitySyncProtocol?
    
    private var hasRequestedAuth: Bool {
        get { UserDefaults.standard.bool(forKey: "hasRequestedHealthAuth") }
        set { UserDefaults.standard.set(newValue, forKey: "hasRequestedHealthAuth") }
    }
    
    
    init(healthKit: ActivityHealthKitServiceProtocol, activitySync: ActivitySyncProtocol? = nil) {
            self.healthKit = healthKit
            self.activitySync = activitySync
        }

    
    func onAppear() {
            if !hasRequestedAuth {
                state = .needsAccess
            } else {
                setUpBackground()
                Task {
                    await activitySync?.refresh()
                }
            }
        }

    private func setUpBackground() {
        activitySync?.onActivityUpdate = { [weak self] activity in
            Task { @MainActor in
                self?.state = .loaded(activity)
                print("[ActivityCard] background update → \(activity)")
            }
        }
        activitySync?.start()
    }
    
    func connectTapped() async {
            print("[HealthKit] connectTapped → requesting auth")
            hasRequestedAuth = true
            state = .loading
            do {
                try await healthKit.requestAuthorization()
                print("[HealthKit] after auth → loading")
                setUpBackground()
                await activitySync?.refresh()
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
}
