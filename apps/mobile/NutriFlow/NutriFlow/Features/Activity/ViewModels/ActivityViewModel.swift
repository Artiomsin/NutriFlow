import Observation
import Foundation
import UIKit

@Observable
@MainActor
final class ActivityViewModel {

    var state: ActivityState = .idle

    var needsHealthConnect: Bool {
        switch state {
        case .needsAccess:
            return true

        default:
            return false
        }
    }

    @ObservationIgnored
    private let healthKit: ActivityHealthKitServiceProtocol

    init(healthKit: ActivityHealthKitServiceProtocol) {
        self.healthKit = healthKit
    }


    func checkPermission() async {
        switch await healthKit.permissionState() {
        case .notDetermined:
            state = .needsAccess

        case .denied:
            state = .denied

        case .authorized:
            if case .idle = state {
                state = .loading
            }
        }
    }

    func connectTapped() async {
        print("[HealthKit] connectTapped → requesting auth")

        state = .loading

        do {
            try await healthKit.requestAuthorization()
        } catch {
            print("[HealthKit] connectTapped error: \(error)")
            state = .error(error)
            return
        }

        switch await healthKit.permissionState() {
        case .authorized:
            print("[HealthKit] HealthKit authorization granted")

        case .denied:
            state = .denied

        case .notDetermined:
            state = .needsAccess
        }
    }


    func setActivity(_ activity: DailyActivity) {
        state = .loaded(activity)
    }

    func setLoading() {
        state = .loading
    }

    func setError(_ error: Error) {
        state = .error(error)
    }


    func openSettings() {
        print("[HealthKit] openSettings")

        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            return
        }

        UIApplication.shared.open(url)
    }
}
