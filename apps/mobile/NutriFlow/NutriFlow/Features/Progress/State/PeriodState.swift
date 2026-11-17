import Foundation
import Observation

@Observable
@MainActor
final class PeriodState {
    // Progress opens with the information a person can act on now. The user can
    // switch to Week, Month, or a custom history range when they need a trend.
    var type: PeriodType = .today
    var fromDate: Date = Date()
    var toDate: Date = Date()
}
