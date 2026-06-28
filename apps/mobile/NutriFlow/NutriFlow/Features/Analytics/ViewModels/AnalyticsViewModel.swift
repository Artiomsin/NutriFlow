import Foundation
import Observation

@Observable
@MainActor
final class AnalyticsViewModel {

    var state: AnalyticsState = .idle

    private let periodState: PeriodState

    @ObservationIgnored private weak var coordinator: AppCoordinator?
    @ObservationIgnored private let service: AnalyticsServiceProtocol
    @ObservationIgnored private let cacheService: CacheService?
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var loadTaskID = 0
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone.current
        return f
    }()

    init(coordinator: AppCoordinator, service: AnalyticsServiceProtocol, periodState: PeriodState = PeriodState(), cacheService: CacheService? = nil) {
        print("AnalyticsViewModel init")
        self.coordinator = coordinator
        self.service = service
        self.periodState = periodState
        self.cacheService = cacheService
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

        let cacheKey: String = {
            switch periodState.type {
            case .week: return "analytics_week"
            case .month: return "analytics_month"
            case .custom: return "analytics_custom_\(formatDate(periodState.fromDate))_\(formatDate(periodState.toDate))"
            default: return ""
            }
        }()

        if let cached: AnalyticsResponse = try? await cacheService?.get(cacheKey) {
            state = .loaded(cached)
            return
        }
        if (try? await cacheService?.get(cacheKey + "_empty") as Bool?) == true {
            state = .empty
            return
        }

        do {
            try Task.checkCancellation()
            guard currentID == loadTaskID else { return }
            state = .loading

            let result: AnalyticsResponse
            let cacheKey: String
            switch periodState.type {
            case .week:
                #if DEBUG
                print("[Network] AnalyticsVM getWeekAnalytics")
                #endif
                result = try await service.getWeekAnalytics()
                cacheKey = "analytics_week"
            case .month:
                #if DEBUG
                print("[Network] AnalyticsVM getMonthAnalytics")
                #endif
                result = try await service.getMonthAnalytics()
                cacheKey = "analytics_month"
            case .custom:
                let days = Calendar.current.dateComponents([.day], from: periodState.fromDate, to: periodState.toDate).day ?? 0
                if days < 6 {
                    state = .idle
                    return
                }
                let from = formatDate(periodState.fromDate)
                let to = formatDate(periodState.toDate)
                #if DEBUG
                print("[Network] AnalyticsVM getCustomRange")
                #endif
                result = try await service.getCustomRange(from: from, to: to)
                cacheKey = "analytics_custom_\(from)_\(to)"
            default:
                state = .idle
                return
            }

            try Task.checkCancellation()
            guard currentID == loadTaskID else { return }

            let hasData = result.daysTracked > 0
                && result.daily.contains { $0.calories > 0 || $0.water > 0 }

            if hasData {
                try? await cacheService?.set(cacheKey, result, ttl: 900)
            }

            if !hasData {
                try? await cacheService?.set(cacheKey + "_empty", true, ttl: 900)
                state = .empty
            } else {
                state = .loaded(result)
            }
        } catch let error as APIError {
            if case .unauthorized = error {
                coordinator?.goToAuth()
            }
            guard currentID == loadTaskID else { return }
            let key = cacheKey
            if let cached: AnalyticsResponse = try? await cacheService?.get(key, ignoreTTL: true) {
                state = .loaded(cached)
            } else {
                let isEmpty: Bool? = try? await cacheService?.get(key + "_empty", ignoreTTL: true)
                if isEmpty == true {
                    state = .empty
                } else {
                    state = .error(error)
                }
            }
        } catch {
            if error is CancellationError { return }
            guard currentID == loadTaskID else { return }
            let key = cacheKey
            if let cached: AnalyticsResponse = try? await cacheService?.get(key, ignoreTTL: true) {
                state = .loaded(cached)
            } else {
                let isEmpty: Bool? = try? await cacheService?.get(key + "_empty", ignoreTTL: true)
                if isEmpty == true {
                    state = .empty
                } else {
                    state = .error(error)
                }
            }
        }
    }

    func refreshData() async {
        let key: String
        switch periodState.type {
        case .week: key = "analytics_week"
        case .month: key = "analytics_month"
        case .custom: key = "analytics_custom_\(formatDate(periodState.fromDate))_\(formatDate(periodState.toDate))"
        default: key = ""
        }
        await cacheService?.remove(key)
        await cacheService?.remove(key + "_empty")
        loadTask?.cancel()
        loadTaskID &+= 1
        await loadAnalytics()
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
