import Foundation

protocol AnalyticsProvider: Sendable {
    var name: String { get }
    func track(event: TrackingEvent)
}
