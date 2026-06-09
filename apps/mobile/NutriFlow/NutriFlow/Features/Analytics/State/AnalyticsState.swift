import Foundation

enum AnalyticsState {
    case idle
    case loading
    case loaded(AnalyticsResponse)
    case empty
    case error(Error)
}
