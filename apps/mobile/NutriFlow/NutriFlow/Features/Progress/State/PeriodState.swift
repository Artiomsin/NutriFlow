import Foundation
import Observation

@Observable
final class PeriodState {
    var type: PeriodType = .week
    var fromDate: Date = Calendar.current.date(byAdding: .day, value: -6, to: Date()) ?? Date()
    var toDate: Date = Date()
}
