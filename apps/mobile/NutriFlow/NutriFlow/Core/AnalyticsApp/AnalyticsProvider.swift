import Foundation

protocol AnalyticsTracking: Sendable {
    func track(_ event: TrackingEvent)
}

protocol AnalyticsProvider: Sendable {
    var name: String { get }
    func track(event: TrackingEvent)
}
