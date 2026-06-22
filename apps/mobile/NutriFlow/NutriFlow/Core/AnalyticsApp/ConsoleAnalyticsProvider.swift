import Foundation

final class ConsoleAnalyticsProvider: AnalyticsProvider {
    let name = "console"

    func track(event: TrackingEvent) {
        print("[Analytics] \(event.name) props: \(event.properties ?? [:])")
    }
}
