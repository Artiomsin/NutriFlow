import Foundation
import AmplitudeUnified

final class AnalyticsService {
    static let shared = AnalyticsService()
    private let amplitude: Amplitude

    private init() {
        amplitude = Amplitude(
            apiKey: "86206780988320a49ce0212856467f34",
            serverZone: .EU
        )
    }

    func track(_ event: TrackingEvent) {
        amplitude.track(
            eventType: event.name,
            eventProperties: event.properties
        )
    }
}
