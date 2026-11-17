import SwiftUI
import Observation

@MainActor
@Observable
final class SleepViewModel {

    private let coordinator: SleepSyncProtocol
    @ObservationIgnored private let analyticsTracker: AnalyticsTracking?
    @ObservationIgnored private let goalsService: GoalsServiceProtocol?
    @ObservationIgnored private let goalsProvider: (() -> UserGoals?)?
    @ObservationIgnored private let achievementService: AchievementService?
    @ObservationIgnored private let achievementNotificationService: AchievementNotificationService?

    /// State of the Sleep History screen.
    var state: SleepState = .idle
    /// State of the Home card. Kept separate from `state` so loading history
    /// never changes which night the card displays.
    var lastNightState: LastNightState = .idle
    var lastNight: HealthKitSleep?
    /// `lastNight` can fall back to the most recent older night when there was
    /// no sleep yesterday. The card must say so instead of presenting it as
    /// last night's data.
    var showsOlderNight = false
    var historyError: AppError?
    var detailError: AppError?

    var history: [HealthKitSleep] = []

    var isHistoryLoading = false

    var selectedNight: HealthKitSleep?

    var timeline: [SleepStageSegment] = []

    var sleepHeartRatePoints: [SleepHeartRatePoint] = []



    var needsHealthConnect: Bool {
        switch lastNightState {
        case .needsAccess:
            return true

        default:
            return false
        }
    }

    init(
        coordinator: SleepSyncProtocol,
        analyticsTracker: AnalyticsTracking? = nil,
        goalsService: GoalsServiceProtocol? = nil,
        goalsProvider: (() -> UserGoals?)? = nil,
        achievementService: AchievementService? = nil,
        achievementNotificationService: AchievementNotificationService? = nil
    ) {
        self.coordinator = coordinator
        self.analyticsTracker = analyticsTracker
        self.goalsService = goalsService
        self.goalsProvider = goalsProvider
        self.achievementService = achievementService
        self.achievementNotificationService = achievementNotificationService
    }

    func trackScreenView() {
        analyticsTracker?.track(.screenView(screen: "sleep_history"))
    }

   

    func checkPermission() async {
        guard coordinator.isAvailable else {
            lastNightState = .unavailable
            return
        }

        switch await coordinator.permissionState() {
        case .notDetermined:
            if case .idle = lastNightState {
                lastNightState = .needsAccess
            }
        case .denied:
            lastNightState = .denied
        case .authorized:
            if case .idle = lastNightState, lastNight == nil {
                lastNightState = .loading
            }
            await refresh()
        case .unknown:
            break
        }
    }

    func connectTapped() async {
        guard coordinator.isAvailable else {
            lastNightState = .unavailable
            return
        }

        lastNightState = .loading

        do {
            let result = try await coordinator.connect()

            switch result {
            case .authorized:
                await refresh()

            case .denied:
                lastNightState = .denied

            case .needsAccess:
                lastNightState = .needsAccess
            }
        } catch {
            if isHealthKitUnavailable(error) {
                lastNightState = .unavailable
                return
            }
            let mapped = ErrorMapper.map(error)
            if mapped != .cancelled {
                lastNightState = .error(mapped)
            }
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
                // No sleep yesterday does not mean no sleep at all. Look through
                // the 7-day window before declaring the card empty, so an older
                // recorded night is still shown (and History stays reachable).
                let nights = (try? await coordinator.loadHistoryIfNeeded()) ?? []
                if let recent = nights.max(by: { $0.endDate < $1.endDate }) {
                    showsOlderNight = true
                    setLastNight(recent)
                } else {
                    lastNight = nil
                    showsOlderNight = false
                    lastNightState = .empty
                }
                return
            }

            showsOlderNight = false
            setLastNight(night)
            checkSleepAchievements(night: night)

        } catch {
            if isHealthKitUnavailable(error) {
                lastNightState = .unavailable
                return
            }
            let mapped = ErrorMapper.map(error)
            if mapped == .cancelled { return }
            lastNightState = .error(mapped)
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
        lastNight = night
        lastNightState = .loaded(night)
    }

    private func checkSleepAchievements(night: HealthKitSleep) {
        guard
            let achievementService,
            let achievementNotificationService
        else { return }

        let minutes = Int(night.asleepSeconds / 60)
        guard minutes > 0 else { return }

        Task { @MainActor in
            let goals: UserGoals?
            if let live = goalsProvider?() {
                goals = live
            } else {
                goals = try? await goalsService?.getGoals()
            }
            guard let goals,
                  let minGoal = goals.nightlySleepMinMinutes
            else { return }

            let items = achievementService.checkSleep(
                minutes: minutes,
                minGoal: minGoal,
                maxGoal: goals.nightlySleepMaxMinutes ?? 0
            )
            guard !items.isEmpty else { return }
            await achievementNotificationService.notifyIfNeeded(achievements: items)
        }
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
}
