import Foundation
import AmplitudeUnified

final class AmplitudeAnalyticsProvider: AnalyticsProvider, @unchecked Sendable {
    let name = "amplitude"
    let amplitude: Amplitude

    init(apiKey: String) {
        amplitude = Amplitude(
            apiKey: apiKey,
            serverZone: .US
        )
    }

    func track(event: TrackingEvent) {
        amplitude.track(
            eventType: event.name,
            eventProperties: event.properties
        )
    }
}
