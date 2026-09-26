import SwiftUI
import Observation

@MainActor
@Observable
final class SleepViewModel {

    private let coordinator: SleepSyncProtocol
    @ObservationIgnored private let analyticsTracker: AnalyticsTracking?

    var state: SleepState = .idle
    var historyError: AppError?
    var detailError: AppError?

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

    init(coordinator: SleepSyncProtocol, analyticsTracker: AnalyticsTracking? = nil) {
        self.coordinator = coordinator
        self.analyticsTracker = analyticsTracker
    }

    func trackScreenView() {
        analyticsTracker?.track(.screenView(screen: "sleep_history"))
    }

   

    func checkPermission() async {
        guard coordinator.isAvailable else {
            state = .unavailable
            return
        }

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
        case .unknown:
            break
        }
    }

 

    func connectTapped() async {
        guard coordinator.isAvailable else {
            state = .unavailable
            return
        }

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

    /// HealthKit unavailability is a device/permission condition, not a request
    /// failure, so it must not surface through ErrorPresentation as a network error.
    private func isHealthKitUnavailable(_ error: Error) -> Bool {
        if case .healthKitUnavailable = error as? SleepHealthKitError { return true }
        return false
    }

    func reloadLastNight() async {
        await refresh()
    }

    private func refresh() async {
        do {
            guard let night = try await coordinator.loadLastNight() else {
                state = .empty
                return
            }

            setLastNight(night)

        } catch {
            if isHealthKitUnavailable(error) {
                state = .unavailable
                return
            }
            let mapped = ErrorMapper.map(error)
            if mapped == .cancelled { return }
            state = .error(mapped)
        }
    }

   

    func loadHistoryIfNeeded() async {
        guard coordinator.isAvailable else {
            state = .unavailable
            history = []
            historyError = nil
            return
        }

        switch await coordinator.permissionState() {
        case .authorized:
            break

        case .notDetermined:
            state = .needsAccess
            history = []
            historyError = nil
            return

        case .denied:
            state = .denied
            history = []
            historyError = nil
            return

        case .unknown:
            break
        }

        isHistoryLoading = true
        defer { isHistoryLoading = false }

        // Without this the view stays in .idle and spins forever when the
        // request fails: .idle and .loading both render a bare ProgressView.
        if history.isEmpty {
            state = .loading
        }

        historyError = nil
        do {
            let nights = try await coordinator.loadHistoryIfNeeded()
            setHistory(nights)
        } catch {
            if isHealthKitUnavailable(error) {
                state = .unavailable
                history = []
                return
            }
            let mapped = ErrorMapper.map(error)
            historyError = mapped == .cancelled ? nil : mapped
        }
    }

    func refreshHistory() async {
        // Pull-to-refresh must not blank already loaded history, so state is
        // left untouched here on purpose: only historyError changes.
        guard coordinator.isAvailable else {
            state = .unavailable
            history = []
            historyError = nil
            return
        }

        switch await coordinator.permissionState() {
        case .authorized:
            break

        case .notDetermined:
            state = .needsAccess
            history = []
            historyError = nil
            return

        case .denied:
            state = .denied
            history = []
            historyError = nil
            return

        case .unknown:
            break
        }

        historyError = nil
        do {
            let nights = try await coordinator.refreshHistory()
            setHistory(nights)
        } catch {
            if isHealthKitUnavailable(error) {
                state = .unavailable
                history = []
                return
            }
            let mapped = ErrorMapper.map(error)
            historyError = mapped == .cancelled ? nil : mapped
        }
    }



    func loadNightDetail(_ night: HealthKitSleep) async {
        selectedNight = night
        timeline = night.segments
        detailError = nil

        do {
            let result = try await coordinator.loadNightDetail(night)

            selectedNight = result.sleep
            timeline = result.sleep.segments
            sleepHeartRatePoints = result.heartRate

            updateHistory(with: result.sleep)

        } catch {
            // A failed detail request must not touch state, otherwise the history
            // list and the Home card both collapse while history[] is still intact.
            let mapped = ErrorMapper.map(error)
            detailError = mapped == .cancelled ? nil : mapped
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
        detailError = nil
    }

 

    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
