
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
    @ObservationIgnored private let session: SessionManager
    @ObservationIgnored private let service: DailySummaryServiceProtocol
    @ObservationIgnored var onUnauthorized: (() -> Void)?
    
    init(session: SessionManager, service: DailySummaryServiceProtocol) {
        self.session = session
        self.service = service
    }
    
    
    func loadToday() async {
        guard let token = session.accessToken() else {
            state = .error(APIError.unauthorized)
            return
        }
        state = .loading
        do {
            let result = try await service.getTodayDailySummary(token: token)
            state = .loaded(result)
        } catch let error as APIError {
            if case .unauthorized = error {
                session.logout()
                onUnauthorized?()
            }
            state = .error(error)
        } catch {
            state = .error(error)
        }
    }
    func loadByDate(date: String) async {
        guard let token = session.accessToken() else {
            state = .error(APIError.unauthorized)
            return
        }
        state = .loading
        do {
            let result = try await service.getDailySummaryByDate(token: token, date: date)
            state = .loaded(result)
        } catch let error as APIError {
            if case .unauthorized = error {
                session.logout()
                onUnauthorized?()
            }
            state = .error(error)
        } catch {
            state = .error(error)
        }
    }
    
    
    func loadChartData() async {
        guard let token = session.accessToken() else {
            chartState = .error(APIError.unauthorized)
            return
        }
        chartState = .loading
        chartData = []
        resetAverages()
        do {
            let summaries: [DailySummary]
            
            switch periodType {
            case .today:
                let summary = try await service.getTodayDailySummary(token: token)
                summaries = [summary]
                
            case .week:
                let from = formatDate(Date().addingTimeInterval(-7 * 86400))
                let to = formatDate(Date())
                summaries = try await service.getDailySummaryRange(token: token, from: from, to: to)
                
            case .month:
                let from = formatDate(Date().addingTimeInterval(-30 * 86400))
                let to = formatDate(Date())
                summaries = try await service.getDailySummaryRange(token: token, from: from, to: to)
                
            case .custom:
                let from = formatDate(fromDate)
                let to = formatDate(toDate)
                summaries = try await service.getDailySummaryRange(token: token, from: from, to: to)
            }
            
            chartData = summaries.map { summary in ChartDataPoint(
                date: parseDate(summary.date) ?? Date(),
                label: formatShortDate(summary.date),
                calories: summary.totalCalories,
                protein: summary.totalProtein,
                fat: summary.totalFat,
                carbs: summary.totalCarbs,
                waterMl: summary.totalWaterMl
            )
            }
            calculateAverages()
            chartState = .loaded(chartData)
            
        } catch let error as APIError {
            if case .unauthorized = error {
                session.logout()
                onUnauthorized?()
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
    
    
    private func groupSummaries(_ summaries: [DailySummary]) -> [(date: Date, label: String, calories: Int, protein: Double, fat: Double, carbs: Double, waterMl: Int)] {
        let count = summaries.count
        let calendar = Calendar.current
        let sorted = summaries.sorted { $0.date < $1.date }
        let parsed: [(date: Date, summary: DailySummary)] = sorted.compactMap {
            guard let d = parseDate($0.date) else { return nil }
            return (d, $0)
        }
        guard !parsed.isEmpty else { return [] }

        let days: Int
        if let first = parsed.first?.date, let last = parsed.last?.date {
            days = calendar.dateComponents([.day], from: first, to: last).day! + 1
        } else {
            days = count
        }

        let groupSize: Int
        switch periodType {
        case .today, .week:
            groupSize = 1
        case .month:
            groupSize = 7
        case .custom:
            if days <= 14 { groupSize = 1 }
            else if days <= 60 { groupSize = 7 }
            else if days <= 400 { groupSize = 30 }
            else { groupSize = 90 }
        }

        var result: [(Date, String, Int, Double, Double, Double, Int)] = []
        var current: [DailySummary] = []
        var currentStart: Date?

        for item in parsed {
            guard let start = currentStart ?? calendar.date(from: calendar.dateComponents([.year, .month, .day], from: item.date)) else {
                currentStart = item.date; current = [item.summary]; continue
            }
            if let diff = calendar.dateComponents([.day], from: start, to: item.date).day, diff < groupSize {
                current.append(item.summary)
            } else {
                if !current.isEmpty { result.append(makeGroup(current)) }
                currentStart = item.date
                current = [item.summary]
            }
        }
        if !current.isEmpty { result.append(makeGroup(current)) }

        return result
    }

    private func makeGroup(_ items: [DailySummary]) -> (Date, String, Int, Double, Double, Double, Int) {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        let date = parseDate(items.first?.date ?? "") ?? Date()
        let label = fmt.string(from: date)
        return (
            date, label,
            items.reduce(0) { $0 + $1.totalCalories },
            items.reduce(0) { $0 + $1.totalProtein },
            items.reduce(0) { $0 + $1.totalFat },
            items.reduce(0) { $0 + $1.totalCarbs },
            items.reduce(0) { $0 + $1.totalWaterMl }
        )
    }

    private func calculateAverages() {
        guard !chartData.isEmpty else { return }
        daysCount = chartData.count
        totalCaloriesSum = chartData.reduce(0) { $0 + $1.calories }
        totalWaterSum = chartData.reduce(0) { $0 + $1.waterMl }
        avgProtein = chartData.reduce(0) { $0 + $1.protein } / Double(daysCount)
        avgFat = chartData.reduce(0) { $0 + $1.fat } / Double(daysCount)
        avgCarbs = chartData.reduce(0) { $0 + $1.carbs } / Double(daysCount)
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
        return formatter.string(from: date)
    }
    
    private func formatShortDate(_ dateString: String) -> String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"
        guard let date = inputFormatter.date(from: dateString) else { return dateString }
        
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "MM/dd"
        return outputFormatter.string(from: date)
    }
    
    private func parseDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString)
    }
    
    func setPreviewState(_ newState: DailySummaryState) {
        state = newState
    }
}
