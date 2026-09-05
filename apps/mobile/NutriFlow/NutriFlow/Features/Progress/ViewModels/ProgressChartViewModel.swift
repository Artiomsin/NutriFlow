import Foundation
import Observation

@Observable
@MainActor
final class ProgressChartViewModel {

    var chartState: ChartState = .idle
    var chartData: [ChartDataPoint] = []

    var selectedDate: Date = Date()

    var totalCaloriesSum: Int = 0
    var totalWaterSum: Int = 0
    var avgProtein: Double = 0
    var avgFat: Double = 0
    var avgCarbs: Double = 0
    var daysCount: Int = 0
    @ObservationIgnored private weak var coordinator: AppCoordinator?
    @ObservationIgnored private let service: DailySummaryServiceProtocol
    @ObservationIgnored private let foodService: FoodServiceProtocol?
    @ObservationIgnored private let waterService: WaterTrackingServiceProtocol?
    @ObservationIgnored private let goalsService: GoalsServiceProtocol?
    @ObservationIgnored private let activityService: ActivityServiceProtocol?
    @ObservationIgnored private let cacheService: CacheService?
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var loadTaskID = 0
    @ObservationIgnored private let periodState: PeriodState
    @ObservationIgnored private var lastProgressRevision: UInt?

    var showDaySheet = false
    var dayDetailState: DayDetailState = .idle
    var selectedDateFood: [FoodEntry] = []
    var selectedDateWater: [WaterEntry] = []
    var selectedDateStr: String = ""
    var selectedDateGoals: UserGoals?

    var canTapBars: Bool {
        periodState.type != .today && aggregationLevel() == .day
    }

    private static let dateOnlyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone.current
        return f
    }()
    private static let labelFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d.M"
        return f
    }()
    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f
    }()

    init(coordinator: AppCoordinator, service: DailySummaryServiceProtocol, periodState: PeriodState, foodService: FoodServiceProtocol? = nil, waterService: WaterTrackingServiceProtocol? = nil, goalsService: GoalsServiceProtocol? = nil, activityService: ActivityServiceProtocol? = nil, cacheService: CacheService? = nil) {
        print("ProgressChartViewModel init")
        self.coordinator = coordinator
        self.service = service
        self.periodState = periodState
        self.foodService = foodService
        self.waterService = waterService
        self.goalsService = goalsService
        self.activityService = activityService
        self.cacheService = cacheService
    }

    deinit {
        loadTask?.cancel()
        print("ProgressChartViewModel deinit")
    }

    func loadDayDetail(date: String) async {
        selectedDateStr = date
        selectedDateFood = []
        selectedDateWater = []
        selectedDateGoals = nil
        dayDetailState = .loading

        do {
            async let food = foodService?.getFoodByDate(date: date) ?? []
            async let water = waterService?.getWaterByDate(date: date) ?? []
            async let goals = goalsService?.getGoals()

            let (f, w, g) = try await (food, water, goals)
            try Task.checkCancellation()

            selectedDateFood = f
            selectedDateWater = w
            selectedDateGoals = g
            dayDetailState = .loaded
            showDaySheet = true
        } catch is CancellationError {
            return
        } catch {
            dayDetailState = .error(error)
            showDaySheet = true
        }
    }

    func handleBarTap(point: ChartDataPoint) {
        guard canTapBars else { return }
        let dateStr = Self.dateOnlyFormatter.string(from: point.date)
        Task { [weak self] in await self?.loadDayDetail(date: dateStr) }
    }

    private func aggregateHourly(food: [FoodEntry], water: [WaterEntry]) -> [ChartDataPoint] {
        var calByHour: [Int: Int] = [:]
        var protByHour: [Int: Double] = [:]
        var fatByHour: [Int: Double] = [:]
        var carbsByHour: [Int: Double] = [:]
        var waterByHour: [Int: Int] = [:]

        let cal = Calendar.current

        for entry in food {
            guard let date = parseDate(entry.createdAt) else { continue }
            let hour = cal.component(.hour, from: date)
            calByHour[hour, default: 0] += entry.calories
            protByHour[hour, default: 0] += Double(entry.protein ?? 0)
            fatByHour[hour, default: 0] += Double(entry.fat ?? 0)
            carbsByHour[hour, default: 0] += Double(entry.carbs ?? 0)
        }

        for entry in water {
            guard let date = parseDate(entry.createdAt) else { continue }
            let hour = cal.component(.hour, from: date)
            waterByHour[hour, default: 0] += entry.amountMl
        }

        let allHours = Set(calByHour.keys).union(Set(waterByHour.keys)).sorted()
        let todayStart = cal.startOfDay(for: Date())

        return allHours.map { hour in
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
            let days = (Calendar.current.dateComponents([.day], from: periodState.fromDate, to: periodState.toDate).day ?? 0) + 1
            if days <= 7 { return .day }
            if days <= 60 { return .week }
            return .month
        }
    }

    private func currentRange() -> (from: String, to: String) {
        switch periodState.type {
        case .today:
            let today = formatDate(Date())
            return (today, today)
        case .week:
            let from = formatDate(Calendar.current.date(byAdding: .day, value: -6, to: Date()) ?? Date())
            return (from, formatDate(Date()))
        case .month:
            let from = formatDate(Calendar.current.date(byAdding: .day, value: -29, to: Date()) ?? Date())
            return (from, formatDate(Date()))
        case .custom:
            return (formatDate(periodState.fromDate), formatDate(periodState.toDate))
        }
    }

    private func applyActivity(_ dict: [String: ActivityDayPoint], to points: [ChartDataPoint]) -> [ChartDataPoint] {
        guard !dict.isEmpty else { return points }
        return points.map { pt in
            let dateStr = Self.dateOnlyFormatter.string(from: pt.date)
            guard let a = dict[dateStr] else { return pt }
            var updated = pt
            updated.steps = a.steps
            updated.activeCalories = a.activeCalories
            updated.distanceMeters = a.distanceMeters
            updated.netCalories = a.netCalories
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
        let calendar = Calendar.current

        switch level {
        case .day:
            return sorted.map { pt in
                ChartDataPoint(date: pt.date, label: Self.labelFormatter.string(from: pt.date), calories: pt.calories, protein: pt.protein, fat: pt.fat, carbs: pt.carbs, waterMl: pt.waterMl, steps: pt.steps, activeCalories: pt.activeCalories, distanceMeters: pt.distanceMeters, netCalories: pt.netCalories)
            }

        case .week:
            var grouped: [Date: [ChartDataPoint]] = [:]
            for pt in sorted {
                let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: pt.date)
                guard let start = calendar.date(from: comps) else { continue }
                grouped[start, default: []].append(pt)
            }
            return grouped.keys.sorted().map { start in
                let pts = grouped[start]!
                let end = calendar.date(byAdding: .day, value: 6, to: start) ?? start
                return ChartDataPoint(
                    date: start,
                    label: "\(Self.labelFormatter.string(from: start))-\(Self.labelFormatter.string(from: end))",
                    calories: pts.reduce(0) { $0 + $1.calories } / pts.count,
                    protein: pts.reduce(0.0) { $0 + $1.protein } / Double(pts.count),
                    fat: pts.reduce(0.0) { $0 + $1.fat } / Double(pts.count),
                    carbs: pts.reduce(0.0) { $0 + $1.carbs } / Double(pts.count),
                    waterMl: pts.reduce(0) { $0 + $1.waterMl } / pts.count,
                    steps: pts.reduce(0) { $0 + $1.steps },
                    activeCalories: pts.reduce(0) { $0 + $1.activeCalories },
                    distanceMeters: pts.reduce(0) { $0 + $1.distanceMeters },
                    netCalories: pts.reduce(0) { $0 + $1.netCalories }
                )
            }

        case .month:
            var grouped: [Date: [ChartDataPoint]] = [:]
            for pt in sorted {
                let comps = calendar.dateComponents([.year, .month], from: pt.date)
                guard let start = calendar.date(from: comps) else { continue }
                grouped[start, default: []].append(pt)
            }
            return grouped.keys.sorted().map { start in
                let pts = grouped[start]!
                return ChartDataPoint(
                    date: start,
                    label: Self.monthFormatter.string(from: start).capitalized,
                    calories: pts.reduce(0) { $0 + $1.calories } / pts.count,
                    protein: pts.reduce(0.0) { $0 + $1.protein } / Double(pts.count),
                    fat: pts.reduce(0.0) { $0 + $1.fat } / Double(pts.count),
                    carbs: pts.reduce(0.0) { $0 + $1.carbs } / Double(pts.count),
                    waterMl: pts.reduce(0) { $0 + $1.waterMl } / pts.count,
                    steps: pts.reduce(0) { $0 + $1.steps },
                    activeCalories: pts.reduce(0) { $0 + $1.activeCalories },
                    distanceMeters: pts.reduce(0) { $0 + $1.distanceMeters },
                    netCalories: pts.reduce(0) { $0 + $1.netCalories }
                )
            }
        }
    }

    func refreshData() async {
        await cacheService?.remove(chartSummariesKey)
        await cacheService?.remove(chartSummariesKey + "_activity")
        await cacheService?.remove("chart_today")
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

    func refreshIfNeeded(currentRevision: UInt) async {
        guard lastProgressRevision != currentRevision else { return }
        await refreshData()
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
            chartState = .error(error)
        } catch {
            if error is CancellationError { return }
            guard currentID == loadTaskID else { return }
            if keptExisting { return }
            if await applyCachedSummaries(key: summariesKey, currentID: currentID) { return }
            chartState = .error(error)
        }
    }

    func setPeriod(_ period: PeriodType) {
        periodState.type = period
        loadTask?.cancel()
        loadTaskID &+= 1
        loadTask = Task { [weak self] in
            await self?.loadChartData()
        }
    }

    func setCustomRange(from: Date, to: Date) {
        periodState.fromDate = from
        periodState.toDate = to
        periodState.type = .custom
        loadTask?.cancel()
        loadTaskID &+= 1
        loadTask = Task { [weak self] in
            await self?.loadChartData()
        }
    }

    private func calculateAverages() {
        guard !chartData.isEmpty else {
            resetAverages()
            return
        }
        daysCount = chartData.count
        let sums = chartData.reduce(
            (cal: 0, water: 0, prot: 0.0, fat: 0.0, carbs: 0.0)
        ) { acc, pt in
            (acc.cal + pt.calories, acc.water + pt.waterMl, acc.prot + pt.protein, acc.fat + pt.fat, acc.carbs + pt.carbs)
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
        Self.dateOnlyFormatter.string(from: date)
    }

    private func parseDateOnly(_ dateString: String) -> Date? {
        Self.dateOnlyFormatter.date(
            from: String(dateString.prefix(10))
        )
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let dateTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        return f
    }()
    private static let dateTimeShortFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        return f
    }()

    private func parseDate(_ dateString: String) -> Date? {
        if let d = Self.isoFormatter.date(from: dateString) { return d }
        if let d = Self.dateTimeFormatter.date(from: dateString) { return d }
        if let d = Self.dateTimeShortFormatter.date(from: dateString) { return d }
        return Self.dateOnlyFormatter.date(from: String(dateString.prefix(10)))
    }
}
