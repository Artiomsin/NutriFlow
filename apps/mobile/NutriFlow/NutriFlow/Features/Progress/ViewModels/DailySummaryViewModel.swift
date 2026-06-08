import Foundation
import Observation

@Observable
@MainActor
final class DailySummaryViewModel {

    var state: DailySummaryState = .idle
    var chartState: ChartState = .idle
    
    var periodType: PeriodType = .week
    var chartData: [ChartDataPoint] = []
    
    var selectedDate: Date = Date()
    var fromDate: Date = Date().addingTimeInterval(-7 * 86400)
    var toDate: Date = Date()
    
    var totalCaloriesSum: Int = 0
    var totalWaterSum: Int = 0
    var avgProtein: Double = 0
    var avgFat: Double = 0
    var avgCarbs: Double = 0
    var daysCount: Int = 0
    @ObservationIgnored private let coordinator: AppCoordinator
    @ObservationIgnored private let service: DailySummaryServiceProtocol
    @ObservationIgnored private let foodService: FoodServiceProtocol?
    @ObservationIgnored private let waterService: WaterTrackingServiceProtocol?
    var dashboardFoodEntries: [FoodEntry] = []
    var dashboardWaterEntries: [WaterEntry] = []
    
    init(coordinator: AppCoordinator, service: DailySummaryServiceProtocol, foodService: FoodServiceProtocol? = nil, waterService: WaterTrackingServiceProtocol? = nil) {
        self.coordinator = coordinator
        self.service = service
        self.foodService = foodService
        self.waterService = waterService
    }
    
    func loadToday() async {
        state = .loading
        do {
            let result = try await service.getTodayDailySummary()
            if result.id == nil {
                state = .empty
            } else {
                state = .loaded(result)
            }
        } catch let error as APIError {
            if case .unauthorized = error {
                coordinator.goToAuth()
            }
            state = .error(error)
        } catch {
            state = .error(error)
        }
    }

    func loadDashboardToday() async {
        state = .loading
        dashboardFoodEntries = []
        dashboardWaterEntries = []
        do {
            let dashboard = try await service.getDashboardToday()
            if dashboard.dailySummary.id == nil {
                state = .empty
            } else {
                state = .loaded(dashboard.dailySummary)
            }
            dashboardFoodEntries = dashboard.foodEntries
            dashboardWaterEntries = dashboard.waterEntries
        } catch let error as APIError {
            if case .unauthorized = error {
                coordinator.goToAuth()
            }
            state = .error(error)
        } catch {
            state = .error(error)
        }
    }

    func loadByDate(date: String) async {
        state = .loading
        do {
            let result = try await service.getDailySummaryByDate(date: date)
            if result.id == nil {
                state = .empty
            } else {
                state = .loaded(result)
            }
        } catch let error as APIError {
            if case .unauthorized = error {
                coordinator.goToAuth()
            }
            state = .error(error)
        } catch {
            state = .error(error)
        }
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
        switch periodType {
        case .today, .week:
            return .day
        case .month:
            return .week
        case .custom:
            let days = Calendar.current.dateComponents([.day], from: fromDate, to: toDate).day ?? 0
            if days <= 14 { return .day }
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
            let f = DateFormatter()
            f.dateFormat = "d.M"
            return sorted.map { pt in
                ChartDataPoint(date: pt.date, label: f.string(from: pt.date), calories: pt.calories, protein: pt.protein, fat: pt.fat, carbs: pt.carbs, waterMl: pt.waterMl)
            }

        case .week:
            let f = DateFormatter()
            f.dateFormat = "d.M"
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
                    label: "\(f.string(from: start))-\(f.string(from: end))",
                    calories: pts.reduce(0) { $0 + $1.calories } / pts.count,
                    protein: pts.reduce(0.0) { $0 + $1.protein } / Double(pts.count),
                    fat: pts.reduce(0.0) { $0 + $1.fat } / Double(pts.count),
                    carbs: pts.reduce(0.0) { $0 + $1.carbs } / Double(pts.count),
                    waterMl: pts.reduce(0) { $0 + $1.waterMl } / pts.count
                )
            }

        case .month:
            let f = DateFormatter()
            f.dateFormat = "MMM"
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
                    label: f.string(from: start).capitalized,
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
        chartState = .loading
        chartData = []
        resetAverages()
        do {
            let summaries: [DailySummary]

            switch periodType {
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
                let from = formatDate(fromDate)
                let to = formatDate(toDate)
                summaries = try await service.getDailySummaryRange(from: from, to: to)
            }

            chartData = summaries
                .filter { $0.totalCalories > 0 || $0.totalWaterMl > 0 }
                .map { summary in ChartDataPoint(
                date: parseDateOnly(summary.date),
                label: "",
                calories: summary.totalCalories,
                protein: summary.totalProtein,
                fat: summary.totalFat,
                carbs: summary.totalCarbs,
                waterMl: summary.totalWaterMl
            )
            }
            calculateAverages()
            let level = aggregationLevel()
            let aggregated = aggregateData(chartData, level: level)
            chartState = .loaded(aggregated)

        } catch let error as APIError {
            if case .unauthorized = error {
                coordinator.goToAuth()
            }
            chartState = .error(error)
        } catch {
            chartState = .error(error)
        }
    }
    
    func setPeriod(_ period: PeriodType) {
        periodType = period
        Task {
            await loadChartData()
        }
    }
    
    func setCustomRange(from: Date, to: Date) {
        fromDate = from
        toDate = to
        periodType = .custom
        Task {
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
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        return formatter.string(from: date)
    }
    
    private func parseDateOnly(_ dateString: String) -> Date {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone.current
        return f.date(from: String(dateString.prefix(10))) ?? Date()
    }

    private func parseDate(_ dateString: String) -> Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: dateString) { return d }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        if let d = f.date(from: dateString) { return d }
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        if let d = f.date(from: dateString) { return d }
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: String(dateString.prefix(10)))
    }
    
    func setPreviewState(_ newState: DailySummaryState) {
        state = newState
    }
}
