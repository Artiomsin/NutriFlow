import Foundation
import Observation

@Observable
@MainActor
final class AnalyticsViewModel {

    var state: AnalyticsState = .idle

    private let periodState: PeriodState

    @ObservationIgnored private weak var coordinator: AppCoordinator?
    @ObservationIgnored private let service: AnalyticsServiceProtocol
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var loadTaskID = 0
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(abbreviation: "UTC")
        return f
    }()

    init(coordinator: AppCoordinator, service: AnalyticsServiceProtocol, periodState: PeriodState = PeriodState()) {
        print("AnalyticsViewModel init")
        self.coordinator = coordinator
        self.service = service
        self.periodState = periodState
    }

    func goToAuth() {
        coordinator?.goToAuth()
    }

    deinit {
        loadTask?.cancel()
        print("AnalyticsViewModel deinit")
    }

    func loadAnalytics() async {
        let currentID = loadTaskID

        if periodState.type == .today {
            state = .idle
            return
        }
        do {
            try Task.checkCancellation()
            guard currentID == loadTaskID else { return }
            state = .loading

            let result: AnalyticsResponse
            switch periodState.type {
            case .week:
                result = try await service.getWeekAnalytics()
            case .month:
                result = try await service.getMonthAnalytics()
            case .custom:
                let days = Calendar.current.dateComponents([.day], from: periodState.fromDate, to: periodState.toDate).day ?? 0
                if days < 6 {
                    state = .idle
                    return
                }
                let from = formatDate(periodState.fromDate)
                let to = formatDate(periodState.toDate)
                result = try await service.getCustomRange(from: from, to: to)
            default:
                state = .idle
                return
            }

            try Task.checkCancellation()
            guard currentID == loadTaskID else { return }

            let hasData = result.daysTracked > 0
                && result.daily.contains { $0.calories > 0 || $0.water > 0 }

            if !hasData {
                state = .empty
            } else {
                state = .loaded(result)
            }
        } catch let error as APIError {
            if case .unauthorized = error {
                coordinator?.goToAuth()
            }
            guard currentID == loadTaskID else { return }
            state = .error(error)
        } catch {
            if error is CancellationError { return }
            guard currentID == loadTaskID else { return }
            state = .error(error)
        }
    }

    func setPeriod(_ period: PeriodType) {
        periodState.type = period
        switch period {
        case .today:
            periodState.fromDate = Date()
            periodState.toDate = Date()
            state = .idle
            return
        case .week:
            periodState.fromDate = Calendar.current.date(byAdding: .day, value: -6, to: Date()) ?? Date()
            periodState.toDate = Date()
        case .month:
            periodState.fromDate = Calendar.current.date(byAdding: .day, value: -29, to: Date()) ?? Date()
            periodState.toDate = Date()
        case .custom:
            if periodState.fromDate == periodState.toDate {
                periodState.fromDate = Calendar.current.date(byAdding: .day, value: -6, to: periodState.toDate) ?? periodState.toDate
            }
        }
        loadTask?.cancel()
        loadTaskID &+= 1
        loadTask = Task { await loadAnalytics() }
    }

    func setCustomRange(from: Date, to: Date) {
        periodState.fromDate = from
        periodState.toDate = to
        periodState.type = .custom
        let days = Calendar.current.dateComponents([.day], from: from, to: to).day ?? 0
        if days < 6 {
            state = .idle
            return
        }
        loadTask?.cancel()
        loadTaskID &+= 1
        loadTask = Task { await loadAnalytics() }
    }

    private func formatDate(_ date: Date) -> String {
        Self.formatter.string(from: date)
    }
}
