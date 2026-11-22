import Foundation
import Observation

struct WeightPoint: Identifiable {
    let id: String
    let date: Date
    let kg: Double
}

@Observable
@MainActor
final class ProgressChartViewModel {

    var chartState: ChartState = .idle
    var chartData: [ChartDataPoint] = []
    var isPeriodLoading = false

    var selectedDate: Date = Date()

    var totalCaloriesSum: Double = 0
    var totalWaterSum: Int = 0
    var avgProtein: Double = 0
    var avgFat: Double = 0
    var avgCarbs: Double = 0
    var daysCount: Int = 0
    var weightLatestKg: Double?
    var weightDeltaKg: Double?
    var weightWeeklyRateKg: Double?
    var weightPeriodLabel: String = ""
    var weightPoints: [WeightPoint] = []
    var weightEntries: [WeightLog] = []
    var weightError: AppError?
    var weightHistoryError: AppError?
    var isWeightLoading = false
    var isWeightHistoryLoading = false
    var hasLoadedWeight = false
    @ObservationIgnored private weak var coordinator: AppCoordinator?
    @ObservationIgnored private let service: DailySummaryServiceProtocol
    @ObservationIgnored private let foodService: FoodServiceProtocol?
    @ObservationIgnored private let waterService: WaterTrackingServiceProtocol?
    @ObservationIgnored private let goalsService: GoalsServiceProtocol?
    @ObservationIgnored private let activityService: ActivityServiceProtocol?
    @ObservationIgnored private let cacheService: CacheService?
    @ObservationIgnored private let profileService: ProfileServiceProtocol?
    @ObservationIgnored private let workoutService: WorkoutServiceProtocol?
    @ObservationIgnored private let progressRefreshState: ProgressRefreshState?
    @ObservationIgnored private let weightReminderScheduler: WeightReminderScheduling?
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var loadTaskID = 0
    @ObservationIgnored private var dayDetailLoadID = 0
    @ObservationIgnored private var fallbackProfileWeightKg: Double?
    @ObservationIgnored private var didLoadFallbackProfileWeight = false
    @ObservationIgnored private let periodState: PeriodState
    // Analytics updates the shared PeriodState before asking this view model to
    // load. Keep our own last requested period so that hand-off still reloads
    // charts and weight for the newly selected period.
    @ObservationIgnored private var lastRequestedPeriod: PeriodType
    @ObservationIgnored private var lastProgressRevision: UInt?
    @ObservationIgnored private var weightLoadTask: Task<Void, Never>?
    @ObservationIgnored private var weightLoadID = 0
    @ObservationIgnored private var weightHistoryLoadID = 0

    var showDaySheet = false
    var dayDetailState: DayDetailState = .idle
    var selectedDateStr: String = ""
    var selectedDateFood: [FoodEntry] = []
    var selectedDateWater: [WaterEntry] = []
    var selectedDateGoals: UserGoals?
    var selectedDateGoalVersions: [GoalVersionEntry] = []
    var selectedDateActivity: ActivityDayPoint?
    var selectedDateWorkouts: [HealthKitWorkout] = []
    var dayDetailWarning: AppError?

    var canTapBars: Bool {
        periodState.type != .today && aggregationLevel() == .day
    }

    // Date strings and day buckets must follow the profile time zone, the same
    // one the API uses to resolve goal versions and group entries.
    private static func dateOnlyFormatter() -> DateFormatter {
        AppDate.dateOnlyFormatter()
    }
    private static func labelFormatter() -> DateFormatter {
        AppDate.displayFormatter("d.M")
    }
    private static func monthFormatter() -> DateFormatter {
        // Month buckets can span multiple years in a custom range. Including
        // the year keeps the categorical chart axis unique (for example,
        // "Jan 2026" and "Jan 2027" must not collapse into one value).
        AppDate.displayFormatter("MMM yyyy")
    }

    init(coordinator: AppCoordinator, service: DailySummaryServiceProtocol, periodState: PeriodState, foodService: FoodServiceProtocol? = nil, waterService: WaterTrackingServiceProtocol? = nil, goalsService: GoalsServiceProtocol? = nil, activityService: ActivityServiceProtocol? = nil, cacheService: CacheService? = nil, profileService: ProfileServiceProtocol? = nil, workoutService: WorkoutServiceProtocol? = nil, progressRefreshState: ProgressRefreshState? = nil, weightReminderScheduler: WeightReminderScheduling? = nil) {
        print("ProgressChartViewModel init")
        self.coordinator = coordinator
        self.service = service
        self.periodState = periodState
        self.lastRequestedPeriod = periodState.type
        self.foodService = foodService
        self.waterService = waterService
        self.goalsService = goalsService
        self.activityService = activityService
        self.cacheService = cacheService
        self.profileService = profileService
        self.workoutService = workoutService
        self.progressRefreshState = progressRefreshState
        self.weightReminderScheduler = weightReminderScheduler
    }

    deinit {
        loadTask?.cancel()
        print("ProgressChartViewModel deinit")
    }

    private func routeAuth(_ appError: AppError) {
        if appError == .unauthorized {
            coordinator?.goToAuth()
        }
    }

    func loadDayDetail(date: String) async {
        dayDetailLoadID &+= 1
        let loadID = dayDetailLoadID
        selectedDateStr = date
        selectedDateFood = []
        selectedDateWater = []
        selectedDateGoals = nil
        selectedDateGoalVersions = []
        selectedDateActivity = nil
        selectedDateWorkouts = []
        dayDetailWarning = nil
        dayDetailState = .loading
        showDaySheet = true

        do {
            async let food = foodService?.getFoodByDate(date: date) ?? []
            async let water = waterService?.getWaterByDate(date: date) ?? []
            async let goals = try? await goalsService?.getGoals(date: date)
            async let versionsResult = loadGoalVersions(date)
            async let activityResult = loadActivityDay(date)
            async let workoutsResult = loadWorkoutsDay(date)

            let (f, w, g, versions, activity, workouts) = try await (food, water, goals, versionsResult, activityResult, workoutsResult)
            try Task.checkCancellation()
            guard loadID == dayDetailLoadID else { return }

            selectedDateFood = f
            selectedDateWater = w
            selectedDateGoals = g
            selectedDateGoalVersions = versions
            selectedDateActivity = activity.value
            selectedDateWorkouts = workouts.value
            dayDetailWarning = activity.error ?? workouts.error
            dayDetailState = .loaded
        } catch is CancellationError {
            return
        } catch {
            guard loadID == dayDetailLoadID else { return }
            dayDetailState = .error(ErrorMapper.map(error))
        }
    }

    private func loadGoalVersions(_ date: String) async -> [GoalVersionEntry] {
        guard let goalsService else { return [] }
        do {
            let page = try await goalsService.getGoalHistory(date: date)
            return page.items
        } catch is CancellationError {
            return []
        } catch {
            // The goal timeline is supplementary; a failure here must not
            // replace the whole day detail with an error.
            return []
        }
    }

    private func loadWorkoutsDay(_ date: String) async -> (value: [HealthKitWorkout], error: AppError?) {
        guard let workoutService else { return ([], nil) }
        do {
            // The API's history filter uses UTC start dates, while `localDate`
            // is the calendar day selected by the person. Query a one-day
            // buffer, then use the persisted local date as the authoritative
            // day to avoid losing workouts around UTC midnight.
            guard let selectedDate = Self.dateOnlyFormatter().date(from: date) else {
                return ([], .unknown)
            }
            let calendar = AppDate.calendar
            let from = calendar.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
            let to = calendar.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
            let response = try await workoutService.getHistory(
                from: Self.dateOnlyFormatter().string(from: from),
                to: Self.dateOnlyFormatter().string(from: to),
                limit: nil,
                offset: nil
            )
            let workouts = response.workouts
                .filter { $0.localDate == date }
                .compactMap { WorkoutMapper.toWorkout($0) }
            return (workouts, nil)
        } catch is CancellationError {
            return ([], .cancelled)
        } catch {
            return ([], ErrorMapper.map(error))
        }
    }

    private func loadActivityDay(_ date: String) async -> (value: ActivityDayPoint?, error: AppError?) {
        guard let activityService else { return (nil, nil) }
        do {
            return (try await activityService.getRange(from: date, to: date).first, nil)
        } catch is CancellationError {
            return (nil, .cancelled)
        } catch {
            return (nil, ErrorMapper.map(error))
        }
    }

    func handleBarTap(point: ChartDataPoint) {
        guard canTapBars else { return }
        let dateStr = Self.dateOnlyFormatter().string(from: point.date)
        Task { [weak self] in await self?.loadDayDetail(date: dateStr) }
    }

    private func aggregateHourly(food: [FoodEntry], water: [WaterEntry]) -> [ChartDataPoint] {
        var calByHour: [Int: Double] = [:]
        var protByHour: [Int: Double] = [:]
        var fatByHour: [Int: Double] = [:]
        var carbsByHour: [Int: Double] = [:]
        var waterByHour: [Int: Int] = [:]

        let cal = AppDate.calendar

        for entry in food {
            guard let date = parseDate(entry.createdAt) else { continue }
            let hour = cal.component(.hour, from: date)
            calByHour[hour, default: 0] += entry.calories
            protByHour[hour, default: 0] += entry.protein ?? 0
            fatByHour[hour, default: 0] += entry.fat ?? 0
            carbsByHour[hour, default: 0] += entry.carbs ?? 0
        }

        for entry in water {
            guard let date = parseDate(entry.createdAt) else { continue }
            let hour = cal.component(.hour, from: date)
            waterByHour[hour, default: 0] += entry.amountMl
        }

        let todayStart = cal.startOfDay(for: Date())

        return (0..<24).map { hour in
            let date = cal.date(byAdding: .hour, value: hour, to: todayStart) ?? todayStart
            return ChartDataPoint(
                date: date,
                label: String(format: "%02d:00", hour),
                calories: calByHour[hour] ?? 0,
                protein: protByHour[hour] ?? 0,
                fat: fatByHour[hour] ?? 0,
                carbs: carbsByHour[hour] ?? 0,
                waterMl: waterByHour[hour] ?? 0
            )
        }
    }

    private func aggregationLevel() -> AggregationLevel {
        switch periodState.type {
        case .today, .week:
            return .day
        case .month:
            return .week
        case .custom:
            let days = (AppDate.calendar.dateComponents([.day], from: periodState.fromDate, to: periodState.toDate).day ?? 0) + 1
            if days <= 7 { return .day }
            if days <= 60 { return .week }
            return .month
        }
    }

    /// Aggregation used for the rendered points, exposed so captions describe
    /// what a point actually is. A rolling week renders raw daily points, not
    /// per-day averages, so it must not be described as an average.
    var chartAggregationLevel: AggregationLevel {
        aggregationLevel()
    }

    var periodDays: Int {
        let range = currentRange()
        guard let from = Self.dateOnlyFormatter().date(from: range.from),
              let to = Self.dateOnlyFormatter().date(from: range.to) else { return 0 }
        return (AppDate.calendar.dateComponents([.day], from: from, to: to).day ?? 0) + 1
    }

    private func currentRange() -> (from: String, to: String) {
        switch periodState.type {
        case .today:
            let today = formatDate(Date())
            return (today, today)
        case .week:
            let from = formatDate(AppDate.calendar.date(byAdding: .day, value: -6, to: Date()) ?? Date())
            return (from, formatDate(Date()))
        case .month:
            let from = formatDate(AppDate.calendar.date(byAdding: .day, value: -29, to: Date()) ?? Date())
            return (from, formatDate(Date()))
        case .custom:
            return (formatDate(periodState.fromDate), formatDate(periodState.toDate))
        }
    }

    private func applyActivity(_ dict: [String: ActivityDayPoint], to points: [ChartDataPoint]) -> [ChartDataPoint] {
        guard !dict.isEmpty else { return points }
        let formatter = Self.dateOnlyFormatter()
        return points.map { pt in
            let dateStr = formatter.string(from: pt.date)
            guard let a = dict[dateStr] else { return pt }
            var updated = pt
            updated.steps = a.steps
            updated.activeCalories = a.activeCalories
            updated.basalCalories = a.basalCalories
            updated.distanceMeters = a.distanceMeters
            updated.netCalories = Double(a.netCalories)
            return updated
        }
    }

    private func loadActivityCachedDict(from: String, to: String) async -> [String: ActivityDayPoint] {
        let key = chartSummariesKey + "_activity"

        if let cached: [String: ActivityDayPoint] = try? await cacheService?.get(key) {
            return cached
        }

        guard let activityService else { return [:] }

        do {
            let points = try await activityService.getRange(from: from, to: to)
            var dict: [String: ActivityDayPoint] = [:]
            for point in points {
                dict[point.date] = point
            }
            try? await cacheService?.set(key, dict, ttl: 600)
            return dict
        } catch is CancellationError {
            return [:]
        } catch {
            if let stale: [String: ActivityDayPoint] = try? await cacheService?.get(key, ignoreTTL: true) {
                return stale
            }
            return [:]
        }
    }

    private func aggregateData(_ data: [ChartDataPoint], level: AggregationLevel) -> [ChartDataPoint] {
        guard !data.isEmpty else { return [] }
        let sorted = data.sorted { $0.date < $1.date }
        let calendar = AppDate.calendar
        let labelFormatter = Self.labelFormatter()
        let monthFormatter = Self.monthFormatter()

        switch level {
        case .day:
            return sorted.map { pt in
                ChartDataPoint(date: pt.date, label: labelFormatter.string(from: pt.date), calories: pt.calories, protein: pt.protein, fat: pt.fat, carbs: pt.carbs, waterMl: pt.waterMl, steps: pt.steps, activeCalories: pt.activeCalories, basalCalories: pt.basalCalories, distanceMeters: pt.distanceMeters, netCalories: pt.netCalories)
            }

        case .week:
            var grouped: [Date: [ChartDataPoint]] = [:]
            for pt in sorted {
                guard let start = calendar.dateInterval(of: .weekOfYear, for: pt.date)?.start else { continue }
                grouped[start, default: []].append(pt)
            }
            return grouped.keys.sorted().map { start in
                let end = calendar.date(byAdding: .day, value: 6, to: start) ?? start
                let displayedRange = clippedDisplayRange(
                    bucketStart: start,
                    bucketEnd: end
                )
                return averagedPoint(
                    start: start,
                    label: "\(labelFormatter.string(from: displayedRange.start))-\(labelFormatter.string(from: displayedRange.end))",
                    points: grouped[start]!
                )
            }

        case .month:
            var grouped: [Date: [ChartDataPoint]] = [:]
            for pt in sorted {
                guard let start = calendar.dateInterval(of: .month, for: pt.date)?.start else { continue }
                grouped[start, default: []].append(pt)
            }
            return grouped.keys.sorted().map { start in
                averagedPoint(
                    start: start,
                    label: monthFormatter.string(from: start).capitalized,
                    points: grouped[start]!
                )
            }
        }
    }

    /// Keeps labels truthful for the first and last partial calendar week of a
    /// rolling month or custom period. The value is still averaged only across
    /// tracked days, but the label must never imply that unselected dates were
    /// included.
    private func clippedDisplayRange(bucketStart: Date, bucketEnd: Date) -> (start: Date, end: Date) {
        let range = currentRange()
        guard let selectedStart = Self.dateOnlyFormatter().date(from: range.from),
              let selectedEnd = Self.dateOnlyFormatter().date(from: range.to) else {
            return (bucketStart, bucketEnd)
        }

        return (
            Swift.max(bucketStart, selectedStart),
            Swift.min(bucketEnd, selectedEnd)
        )
    }

    /// Collapses the daily points of a week/month into one bar.
    ///
    /// Every metric becomes a **daily average**, never a sum. Charts compare
    /// values from different sources — eaten calories against burned/resting
    /// calories, or water against a daily goal — so mixing daily averages with
    /// weekly sums made month/custom charts show a week of `basalCalories`
    /// (≈12 000) next to an average day of calories (≈2 000). Period totals
    /// are reported separately from the unaggregated `chartData`.
    private func averagedPoint(
        start: Date,
        label: String,
        points: [ChartDataPoint]
    ) -> ChartDataPoint {
        let count = Double(max(points.count, 1))

        func average(_ keyPath: KeyPath<ChartDataPoint, Double>) -> Double {
            points.reduce(0.0) { $0 + $1[keyPath: keyPath] } / count
        }

        func averageInt(_ keyPath: KeyPath<ChartDataPoint, Int>) -> Int {
            Int((Double(points.reduce(0) { $0 + $1[keyPath: keyPath] }) / count).rounded())
        }

        return ChartDataPoint(
            date: start,
            label: label,
            calories: average(\.calories),
            protein: average(\.protein),
            fat: average(\.fat),
            carbs: average(\.carbs),
            waterMl: averageInt(\.waterMl),
            steps: averageInt(\.steps),
            activeCalories: average(\.activeCalories),
            basalCalories: average(\.basalCalories),
            distanceMeters: average(\.distanceMeters),
            netCalories: average(\.netCalories)
        )
    }

    func refreshData() async {
        await cacheService?.remove(chartSummariesKey)
        await cacheService?.remove(chartSummariesKey + "_activity")
        if periodState.type == .today {
            await cacheService?.remove("food_today")
            await cacheService?.remove("water_today")
        }
        loadTask?.cancel()
        loadTaskID &+= 1
        await loadChartData(keepLoadedData: true)
    }

    func markRevisionAsCurrent(_ revision: UInt) {
        lastProgressRevision = revision
    }

    func refreshIfNeeded(currentRevision: UInt, reloadWeight: Bool = false) async {
        guard lastProgressRevision != currentRevision else { return }
        await refreshData()
        if reloadWeight {
            await loadWeightSummary(forceRefresh: true)
        }
        if case .loaded = chartState {
            lastProgressRevision = currentRevision
        }
    }

    private func applyCachedSummaries(key: String, currentID: Int) async -> Bool {
        guard let cached: [DailySummary] = try? await cacheService?.get(key, ignoreTTL: true) else { return false }
        let base = cached.compactMap { summary -> ChartDataPoint? in
            guard let date = parseDateOnly(summary.date) else {
                return nil
            }

            return ChartDataPoint(
                date: date,
                label: "",
                calories: summary.totalCalories,
                protein: Double(summary.totalProtein),
                fat: Double(summary.totalFat),
                carbs: Double(summary.totalCarbs),
                waterMl: summary.totalWaterMl
            )
        }
        guard currentID == loadTaskID else { return true }
        let range = currentRange()
        let activityDict = await loadActivityCachedDict(from: range.from, to: range.to)
        guard currentID == loadTaskID else { return true }
        let points = applyActivity(activityDict, to: base)
        chartData = points
        calculateAverages()
        chartState = .loaded(aggregateData(points, level: aggregationLevel()))
        return true
    }

    
    func loadWeightSummary(forceRefresh: Bool = false) async {
        guard profileService != nil else { return }

        weightLoadTask?.cancel()
        weightLoadID &+= 1
        let loadID = weightLoadID

        let task = Task { [weak self] in
            guard let self else { return }
            await self.performWeightSummaryLoad(loadID: loadID, forceRefresh: forceRefresh)
        }
        weightLoadTask = task
        await task.value
    }

    private func performWeightSummaryLoad(loadID: Int, forceRefresh: Bool) async {
        guard let profileService else { return }

        isWeightLoading = true
        defer {
            // A newer request owns the loading flag; an older one must not
            // clear it after it has been superseded.
            if loadID == weightLoadID {
                isWeightLoading = false
            }
        }

        let range = currentRange()
        let cacheKey = weightLogsCacheKey(from: range.from, to: range.to)
        let label = periodLabel()
        let period = periodState.type

        if forceRefresh {
            await cacheService?.remove(cacheKey)
        }

        var points: [WeightPoint]
        do {
            let logs: [WeightLog]
            if !forceRefresh,
               let cached: [WeightLog] = try? await cacheService?.get(cacheKey) {
                logs = cached
            } else {
                logs = try await profileService.getWeightLogs(from: range.from, to: range.to)
                try? await cacheService?.set(cacheKey, logs, ttl: 900)
            }
            guard !Task.isCancelled, loadID == weightLoadID else { return }
            weightError = nil
            points = logs
                .compactMap { log -> WeightPoint? in
                    guard let date = Self.dateOnlyFormatter().date(from: String(log.entryDate.prefix(10))) else { return nil }
                    return WeightPoint(
                        id: String(log.entryDate.prefix(10)),
                        date: date,
                        kg: log.weightValue
                    )
                }
                .sorted { $0.date < $1.date }
        } catch {
            if error is CancellationError { return }
            guard loadID == weightLoadID else { return }
            let appError = ErrorMapper.map(error)
            routeAuth(appError)
            if appError != .cancelled {
                weightError = appError
            }
            // Keep the last good points and label so a failed refresh does not
            // blank the card or swap it back to the empty state.
            return
        }

        // The profile stores the current weight only. It is useful as a first
        // point for Today, but must never be drawn in a past range.
        if points.isEmpty, period == .today {
            await resolveFallbackProfileWeightIfNeeded()
            guard !Task.isCancelled, loadID == weightLoadID else { return }
            if let kg = fallbackProfileWeightKg {
                points = [
                    WeightPoint(
                        id: Self.dateOnlyFormatter().string(from: Date()),
                        date: Date(),
                        kg: kg
                    )
                ]
            }
        }

        guard !Task.isCancelled, loadID == weightLoadID else { return }

        let latest = points.last
        let delta: Double?
        let weeklyRate: Double?
        if let latest, let first = points.first, points.count > 1 {
            delta = latest.kg - first.kg
            let days = max(1, AppDate.calendar.dateComponents([.day], from: first.date, to: latest.date).day ?? 1)
            weeklyRate = (latest.kg - first.kg) / (Double(days) / 7.0)
        } else {
            // A single point has no trend; hide CHANGE/PER WEEK instead of
            // showing a fake ±0.0.
            delta = nil
            weeklyRate = nil
        }

        weightPoints = points
        weightPeriodLabel = label
        weightLatestKg = latest?.kg
        weightDeltaKg = delta
        weightWeeklyRateKg = weeklyRate
        hasLoadedWeight = true
    }

    /// Fetches the profile weight once. It is only a fallback for Today when
    /// there are no weight logs, so it never replaces logged history.
    private func resolveFallbackProfileWeightIfNeeded() async {
        guard !didLoadFallbackProfileWeight, let profileService else { return }
        didLoadFallbackProfileWeight = true
        do {
            let profile = try await profileService.getMyProfile()
            fallbackProfileWeightKg = profile.weight
        } catch {
            if error is CancellationError { return }
            let appError = ErrorMapper.map(error)
            routeAuth(appError)
            if appError != .cancelled {
                weightError = appError
            }
        }
    }

    func recordCurrentWeight(_ weightKg: Double) async throws {
        guard let profileService else { return }
        do {
            _ = try await profileService.recordWeight(weightKg: weightKg)
            await weightReminderScheduler?.rescheduleAfterWeightUpdate()
            fallbackProfileWeightKg = weightKg
            didLoadFallbackProfileWeight = true
            await cacheService?.remove("profile")
            await cacheService?.remove("goals")
            await invalidateWeightLogsCache()
            await loadWeightSummary()
            progressRefreshState?.invalidateGoalsRequiringManualDecision()
        } catch {
            routeAuth(ErrorMapper.map(error))
            throw error
        }
    }

    func deleteWeightEntry(date: String) async throws {
        guard let profileService else { return }
        do {
            try await profileService.deleteWeightLog(date: date)
            await weightReminderScheduler?.rescheduleAfterWeightUpdate()
            fallbackProfileWeightKg = nil
            didLoadFallbackProfileWeight = false
            await cacheService?.remove("profile")
            await cacheService?.remove("goals")
            await invalidateWeightLogsCache()
            await loadWeightSummary()
            await loadWeightHistory()

            if date == AppDate.dateOnlyFormatter().string(from: .now) {
                progressRefreshState?.invalidateGoalsRequiringManualDecision()
            } else {
                progressRefreshState?.invalidateGoals()
            }
        } catch {
            routeAuth(ErrorMapper.map(error))
            throw error
        }
    }

    func loadWeightHistory() async {
        guard let profileService else { return }

        weightHistoryLoadID &+= 1
        let loadID = weightHistoryLoadID
        isWeightHistoryLoading = true
        defer {
            if loadID == weightHistoryLoadID {
                isWeightHistoryLoading = false
            }
        }

        do {
            let entries = try await profileService.getWeightLogs(from: nil, to: nil)
            guard !Task.isCancelled, loadID == weightHistoryLoadID else { return }
            weightEntries = entries
            weightHistoryError = nil
        } catch {
            if error is CancellationError { return }
            guard loadID == weightHistoryLoadID else { return }
            let appError = ErrorMapper.map(error)
            routeAuth(appError)
            if appError != .cancelled {
                weightHistoryError = appError
            }
        }
    }

    private func periodLabel() -> String {
        switch periodState.type {
        case .today:
            return "Today"
        case .week:
            return "7 days"
        case .month:
            return "30 days"
        case .custom:
            let from = Self.labelFormatter().string(from: periodState.fromDate)
            let to = Self.labelFormatter().string(from: periodState.toDate)
            return "\(from) – \(to)"
        }
    }

    private func weightLogsCacheKey(from: String, to: String) -> String {
        "weight_logs_\(from)_\(to)"
    }

    private func invalidateWeightLogsCache() async {
        await cacheService?.removeByPrefix("weight_logs_")
    }

    func loadChartData(keepLoadedData: Bool = false) async {
        let currentID = loadTaskID
        let summariesKey = chartSummariesKey

        if periodState.type != .today, let cached: [DailySummary] = try? await cacheService?.get(summariesKey) {
            var points = cached.compactMap { summary -> ChartDataPoint? in
                guard let date = parseDateOnly(summary.date) else {
                    return nil
                }

                return ChartDataPoint(
                    date: date,
                    label: "",
                    calories: summary.totalCalories,
                    protein: Double(summary.totalProtein),
                    fat: Double(summary.totalFat),
                    carbs: Double(summary.totalCarbs),
                    waterMl: summary.totalWaterMl
                )
            }
            guard currentID == loadTaskID else { return }
            let range = currentRange()
            let activityDict = await loadActivityCachedDict(from: range.from, to: range.to)
            guard currentID == loadTaskID else { return }
            points = applyActivity(activityDict, to: points)
            chartData = points
            calculateAverages()
            chartState = .loaded(aggregateData(points, level: aggregationLevel()))
            return
        }

        if periodState.type == .today,
               let cachedFood: [FoodEntry] = try? await cacheService?.get("food_today"),
               let cachedWater: [WaterEntry] = try? await cacheService?.get("water_today") {
            guard currentID == loadTaskID else { return }
            #if DEBUG
            print("[ChartVM] today → cache HIT (shared food_today/water_today)")
            #endif
            chartData = aggregateHourly(food: cachedFood, water: cachedWater)
            totalCaloriesSum = chartData.reduce(0) { $0 + $1.calories }
            totalWaterSum = chartData.reduce(0) { $0 + $1.waterMl }
            avgProtein = chartData.reduce(0) { $0 + $1.protein }
            avgFat = chartData.reduce(0) { $0 + $1.fat }
            avgCarbs = chartData.reduce(0) { $0 + $1.carbs }
            daysCount = 1
            chartState = .loaded(chartData)
            return
        }

        let keptExisting: Bool
        if keepLoadedData, case .loaded = chartState {
            keptExisting = true
        } else {
            keptExisting = false
            chartState = .loading
            chartData = []
            resetAverages()
        }

        do {
            try Task.checkCancellation()
            guard currentID == loadTaskID else { return }
            let summaries: [DailySummary]

            switch periodState.type {
            case .today:
                if let foodService, let waterService {
                    #if DEBUG
                    print("[Network] ChartVM getTodayFood")
                    #endif
                    let food = try await foodService.getTodayFood()
                    #if DEBUG
                    print("[Network] ChartVM getTodayWater")
                    #endif
                    let water = try await waterService.getTodayWater()
                    try? await cacheService?.set("food_today", food, ttl: 300)
                    try? await cacheService?.set("water_today", water, ttl: 300)
                    chartData = aggregateHourly(food: food, water: water)
                    totalCaloriesSum = chartData.reduce(0) { $0 + $1.calories }
                    totalWaterSum = chartData.reduce(0) { $0 + $1.waterMl }
                    avgProtein = chartData.reduce(0) { $0 + $1.protein }
                    avgFat = chartData.reduce(0) { $0 + $1.fat }
                    avgCarbs = chartData.reduce(0) { $0 + $1.carbs }
                    daysCount = 1
                    guard currentID == loadTaskID else { return }
                    chartState = .loaded(chartData)
                    return
                }
                #if DEBUG
                print("[Network] ChartVM getTodayDailySummary")
                #endif
                let summary = try await service.getTodayDailySummary()
                summaries = summary.id == nil ? [] : [summary]

            case .week, .month, .custom:
                let range = currentRange()
                #if DEBUG
                print("[Network] ChartVM getDailySummaryRange \(periodState.type)")
                #endif
                summaries = try await service.getDailySummaryRange(from: range.from, to: range.to)
            }

            try Task.checkCancellation()
            chartData = summaries.compactMap { summary -> ChartDataPoint? in
                guard let date = parseDateOnly(summary.date) else {
                    return nil
                }

                return ChartDataPoint(
                    date: date,
                    label: "",
                    calories: summary.totalCalories,
                    protein: Double(summary.totalProtein),
                    fat: Double(summary.totalFat),
                    carbs: Double(summary.totalCarbs),
                    waterMl: summary.totalWaterMl
                )
            }
            let range = currentRange()
            let activityDict = await loadActivityCachedDict(from: range.from, to: range.to)
            guard currentID == loadTaskID else { return }
            chartData = applyActivity(activityDict, to: chartData)
            calculateAverages()
            let level = aggregationLevel()
            let aggregated = aggregateData(chartData, level: level)
            guard currentID == loadTaskID else { return }
            chartState = .loaded(aggregated)
            try? await cacheService?.set(summariesKey, summaries, ttl: 600)

        } catch let error as APIError {
            if case .unauthorized = error {
                coordinator?.goToAuth()
            }
            guard currentID == loadTaskID else { return }
            if keptExisting { return }
            if await applyCachedSummaries(key: summariesKey, currentID: currentID) { return }
            chartState = .error(ErrorMapper.map(error))
        } catch {
            if error is CancellationError { return }
            guard currentID == loadTaskID else { return }
            if keptExisting { return }
            if await applyCachedSummaries(key: summariesKey, currentID: currentID) { return }
            chartState = .error(ErrorMapper.map(error))
        }
    }

    func setPeriod(_ period: PeriodType) {
        let previousPeriod = lastRequestedPeriod
        periodState.type = period
        lastRequestedPeriod = period
        // Today contains hourly points; the remaining periods contain daily buckets.
        // Never briefly present one resolution as the other while loading.
        startPeriodLoad(keepPreviousCharts: previousPeriod != .today && period != .today)
    }

    func setCustomRange(from: Date, to: Date) {
        let previousPeriod = lastRequestedPeriod
        periodState.fromDate = from
        periodState.toDate = to
        periodState.type = .custom
        lastRequestedPeriod = .custom
        startPeriodLoad(keepPreviousCharts: previousPeriod != .today)
    }

    private func startPeriodLoad(keepPreviousCharts: Bool = true) {
        let hasPreviousCharts: Bool
        if case .loaded = chartState {
            hasPreviousCharts = true
        } else {
            hasPreviousCharts = false
        }
        let keepsPreviousCharts = keepPreviousCharts && hasPreviousCharts

        isPeriodLoading = keepsPreviousCharts
        loadTask?.cancel()
        loadTaskID &+= 1
        let taskID = loadTaskID

        loadTask = Task { [weak self] in
            guard let self else { return }
            await self.loadChartData(keepLoadedData: keepsPreviousCharts)
            guard self.loadTaskID == taskID else { return }
            // Weight has its own request lifecycle. Waiting for its endpoint
            // here kept the chart overlay spinning and made the charts look
            // blocked on the weight request.
            self.isPeriodLoading = false
        }
        Task { [weak self] in
            await self?.loadWeightSummary()
        }
    }

    private func calculateAverages() {
        guard !chartData.isEmpty else {
            resetAverages()
            return
        }
        daysCount = chartData.count
        let sums = chartData.reduce(
            (cal: 0.0, water: 0, prot: 0.0, fat: 0.0, carbs: 0.0)
        ) { acc, pt in
            (acc.cal + pt.calories,
             acc.water + pt.waterMl,
             acc.prot + pt.protein,
             acc.fat + pt.fat,
             acc.carbs + pt.carbs)
        }
        totalCaloriesSum = sums.cal
        totalWaterSum = sums.water
        avgProtein = sums.prot / Double(daysCount)
        avgFat = sums.fat / Double(daysCount)
        avgCarbs = sums.carbs / Double(daysCount)
    }

    private var chartSummariesKey: String {
        let range = currentRange()

        switch periodState.type {
        case .today:
            return "chart_summaries_today"
        case .week:
            return "chart_summaries_week_\(range.from)_\(range.to)"
        case .month:
            return "chart_summaries_month_\(range.from)_\(range.to)"
        case .custom:
            return "chart_summaries_custom_\(range.from)_\(range.to)"
        }
    }

    private func resetAverages() {
        totalCaloriesSum = 0
        totalWaterSum = 0
        avgProtein = 0
        avgFat = 0
        avgCarbs = 0
        daysCount = 0
    }

    private func formatDate(_ date: Date) -> String {
        Self.dateOnlyFormatter().string(from: date)
    }

    private func parseDateOnly(_ dateString: String) -> Date? {
        Self.dateOnlyFormatter().date(
            from: String(dateString.prefix(10))
        )
    }

    private func parseDate(_ dateString: String) -> Date? {
        // Timestamps arrive with an explicit offset, but parsing still has to
        // stay on the profile calendar: a device with a non-Gregorian calendar
        // or a locale-specific 12/24-hour format would otherwise shift or
        // reject `createdAt` and place the entry in the wrong hourly bucket.
        AppDate.parseISO(dateString)
            ?? Self.dateOnlyFormatter().date(from: String(dateString.prefix(10)))
    }
}
