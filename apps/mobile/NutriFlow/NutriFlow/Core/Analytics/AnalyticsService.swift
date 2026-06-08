import Foundation
import AmplitudeUnified

final class AnalyticsService: @unchecked Sendable {
    static let shared = AnalyticsService()
    private let amplitude: Amplitude

    private init() {
        amplitude = Amplitude(
            apiKey: APIConfig.amplitudeApiKey,
            serverZone: .US
        )
    }

    func track(_ event: TrackingEvent) {
        #if DEBUG
        print("[Amplitude] Tracked: \(event.name) props: \(event.properties ?? [:])")
        #endif
        amplitude.track(
            eventType: event.name,
            eventProperties: event.properties
        )
    }
}
