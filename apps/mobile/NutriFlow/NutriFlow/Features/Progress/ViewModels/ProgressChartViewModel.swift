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
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var loadTaskID = 0
    @ObservationIgnored private let periodState: PeriodState

    var showDaySheet = false
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
        f.timeZone = TimeZone(abbreviation: "UTC")
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

    init(coordinator: AppCoordinator, service: DailySummaryServiceProtocol, periodState: PeriodState, foodService: FoodServiceProtocol? = nil, waterService: WaterTrackingServiceProtocol? = nil, goalsService: GoalsServiceProtocol? = nil) {
        print("ProgressChartViewModel init")
        self.coordinator = coordinator
        self.service = service
        self.periodState = periodState
        self.foodService = foodService
        self.waterService = waterService
        self.goalsService = goalsService
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

        async let food = foodService?.getFoodByDate(date: date) ?? []
        async let water = waterService?.getWaterByDate(date: date) ?? []
        async let goals = goalsService?.getGoals()

        do {
            let (f, w, g) = try await (food, water, goals)
            (selectedDateFood, selectedDateWater, selectedDateGoals) = (f, w, g)
        } catch {
            selectedDateFood = []
            selectedDateWater = []
            selectedDateGoals = nil
        }
        showDaySheet = true
    }

    func handleBarTap(label: String) {
        guard canTapBars else { return }
        let points: [ChartDataPoint]
        if case .loaded(let data) = chartState {
            points = data
        } else {
            points = chartData
        }
        guard let point = points.first(where: { $0.label == label }) else { return }
        let dateStr = Self.dateOnlyFormatter.string(from: point.date)
        Task { await loadDayDetail(date: dateStr) }
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
            let days = Calendar.current.dateComponents([.day], from: periodState.fromDate, to: periodState.toDate).day ?? 0
            if days <= 7 { return .day }
            if days <= 60 { return .week }
            return .month
        }
    }

    private func aggregateData(_ data: [ChartDataPoint], level: AggregationLevel) -> [ChartDataPoint] {
        guard !data.isEmpty else { return [] }
        let sorted = data.sorted { $0.date < $1.date }
        let calendar = Calendar.current

        switch level {
        case .day:
            return sorted.map { pt in
                ChartDataPoint(date: pt.date, label: Self.labelFormatter.string(from: pt.date), calories: pt.calories, protein: pt.protein, fat: pt.fat, carbs: pt.carbs, waterMl: pt.waterMl)
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
                    waterMl: pts.reduce(0) { $0 + $1.waterMl } / pts.count
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
                    waterMl: pts.reduce(0) { $0 + $1.waterMl } / pts.count
                )
            }
        }
    }

    func loadChartData() async {
        let currentID = loadTaskID

        do {
            try Task.checkCancellation()
            guard currentID == loadTaskID else { return }
            chartState = .loading
            chartData = []
            resetAverages()
            let summaries: [DailySummary]

            switch periodState.type {
            case .today:
                if let foodService, let waterService {
                    let food = try await foodService.getTodayFood()
                    let water = try await waterService.getTodayWater()
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
                let summary = try await service.getTodayDailySummary()
                summaries = summary.id == nil ? [] : [summary]

            case .week:
                let cal = Calendar.current
                let from = formatDate(cal.date(byAdding: .day, value: -6, to: Date()) ?? Date())
                let to = formatDate(Date())
                summaries = try await service.getDailySummaryRange(from: from, to: to)

            case .month:
                let cal = Calendar.current
                let from = formatDate(cal.date(byAdding: .day, value: -29, to: Date()) ?? Date())
                let to = formatDate(Date())
                summaries = try await service.getDailySummaryRange(from: from, to: to)

            case .custom:
                let from = formatDate(periodState.fromDate)
                let to = formatDate(periodState.toDate)
                summaries = try await service.getDailySummaryRange(from: from, to: to)
            }

            try Task.checkCancellation()
            chartData = summaries
                .filter { $0.totalCalories > 0 || $0.totalWaterMl > 0 }
                .map { summary in ChartDataPoint(
                date: parseDateOnly(summary.date),
                label: "",
                calories: summary.totalCalories,
                protein: Double(summary.totalProtein),
                fat: Double(summary.totalFat),
                carbs: Double(summary.totalCarbs),
                waterMl: summary.totalWaterMl
            )
            }
            calculateAverages()
            let level = aggregationLevel()
            let aggregated = aggregateData(chartData, level: level)
            guard currentID == loadTaskID else { return }
            chartState = .loaded(aggregated)

        } catch let error as APIError {
            if case .unauthorized = error {
                coordinator?.goToAuth()
            }
            guard currentID == loadTaskID else { return }
            chartState = .error(error)
        } catch {
            if error is CancellationError { return }
            guard currentID == loadTaskID else { return }
            chartState = .error(error)
        }
    }

    func setPeriod(_ period: PeriodType) {
        periodState.type = period
        loadTask?.cancel()
        loadTaskID &+= 1
        loadTask = Task {
            await loadChartData()
        }
    }

    func setCustomRange(from: Date, to: Date) {
        periodState.fromDate = from
        periodState.toDate = to
        periodState.type = .custom
        loadTask?.cancel()
        loadTaskID &+= 1
        loadTask = Task {
            await loadChartData()
        }
    }

    private func calculateAverages() {
        guard !chartData.isEmpty else { return }
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

    private func parseDateOnly(_ dateString: String) -> Date {
        Self.dateOnlyFormatter.date(from: String(dateString.prefix(10))) ?? Date()
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
