import Foundation

enum AnalyticsMode {
    case debug
    case live
}

final class AnalyticsManager: AnalyticsTracking, @unchecked Sendable {
    static let shared = AnalyticsManager()

    private var providers: [AnalyticsProvider] = []
    var isEnabled = true

    func setProviders(_ providers: [AnalyticsProvider]) {
        self.providers = providers
    }

    func setMode(_ mode: AnalyticsMode) {
        switch mode {
        case .debug:
            providers = []
        case .live:
            providers = [
                AmplitudeAnalyticsProvider(apiKey: APIConfig.amplitudeApiKey),
            ]
        }
    }

    func track(_ event: TrackingEvent) {
        guard isEnabled else { return }
        for provider in providers {
            provider.track(event: event)
        }
    }
}
