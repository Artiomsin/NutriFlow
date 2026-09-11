import SwiftUI
import Observation

@MainActor
@Observable
final class SleepViewModel {

    private let coordinator: SleepSyncProtocol



    var state: SleepState = .idle

    var history: [HealthKitSleep] = []

    var isHistoryLoading = false

    var selectedNight: HealthKitSleep?

    var timeline: [SleepStageSegment] = []

    var sleepHeartRatePoints: [SleepHeartRatePoint] = []


    var needsHealthConnect: Bool {
        switch state {
        case .needsAccess:
            return true

        default:
            return false
        }
    }

    init(coordinator: SleepSyncProtocol) {
        self.coordinator = coordinator
    }

   

    func checkPermission() async {
        switch await coordinator.permissionState() {
        case .notDetermined:
            if case .idle = state {
                state = .needsAccess
            }
        case .denied:
            state = .denied
        case .authorized:
            if case .idle = state {
                state = .loading
            }
            await refresh()
        }
    }

 

    func connectTapped() async {
        state = .loading

        let result = await coordinator.connect()

        switch result {
        case .authorized:
            await refresh()

        case .denied:
            state = .denied

        case .needsAccess:
            state = .needsAccess
        }
    }

    private func refresh() async {
        do {
            guard let night = try await coordinator.loadLastNight() else {
                state = .empty
                return
            }

            setLastNight(night)

        } catch {
            state = .error(error.localizedDescription)
        }
    }

   

    func loadHistoryIfNeeded() async {
        switch await coordinator.permissionState() {
        case .authorized:
            break

        case .notDetermined:
            state = .needsAccess
            history = []
            return

        case .denied:
            state = .denied
            history = []
            return
        }

        isHistoryLoading = true
        defer { isHistoryLoading = false }

        do {
            let nights = try await coordinator.loadHistoryIfNeeded()
            setHistory(nights)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func refreshHistory() async {
        switch await coordinator.permissionState() {
        case .authorized:
            break

        case .notDetermined:
            state = .needsAccess
            history = []
            return

        case .denied:
            state = .denied
            history = []
            return
        }

        do {
            let nights = try await coordinator.refreshHistory()
            setHistory(nights)
        } catch {
            state = .error(error.localizedDescription)
        }
    }



    func loadNightDetail(_ night: HealthKitSleep) async {
        selectedNight = night
        timeline = night.segments

        do {
            let result = try await coordinator.loadNightDetail(night)

            selectedNight = result.sleep
            timeline = result.sleep.segments
            sleepHeartRatePoints = result.heartRate

            updateHistory(with: result.sleep)

        } catch {
            state = .error(error.localizedDescription)
        }
    }

   

    private func setLastNight(_ night: HealthKitSleep) {
        state = .loaded([night])
    }

    private func setHistory(_ nights: [HealthKitSleep]) {
        history = nights
        state = nights.isEmpty ? .empty : .loaded(nights)
    }

    private func updateHistory(with sleep: HealthKitSleep) {
        guard let index = history.firstIndex(
            where: { SleepKey.nightKey($0) == SleepKey.nightKey(sleep) }
        ) else {
            return
        }

        history[index] = sleep
    }


    func clearSelection() {
        selectedNight = nil
        timeline = []
        sleepHeartRatePoints = []
    }

 

    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
