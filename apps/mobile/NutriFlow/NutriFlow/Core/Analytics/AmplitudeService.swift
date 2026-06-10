import Foundation
import AmplitudeUnified

final class AmplitudeService: @unchecked Sendable {
    static let shared = AmplitudeService()
    static var isEnabled = false
    private let amplitude: Amplitude

    private init() {
        amplitude = Amplitude(
            apiKey: APIConfig.amplitudeApiKey,
            serverZone: .US
        )
    }

    func track(_ event: TrackingEvent) {
        guard Self.isEnabled else { return }
        #if DEBUG
        print("[Amplitude] Tracked: \(event.name) props: \(event.properties ?? [:])")
        #endif
        amplitude.track(
            eventType: event.name,
            eventProperties: event.properties
        )
    }
}
