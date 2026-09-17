import Foundation

enum TrackingEvent {
    case appLaunched
    case appForeground
    case appBackground
    case loggedIn
    case registered
    case loggedOut
    case screenView(screen: String)

    var name: String {
        switch self {
        case .appLaunched:     return "app_launched"
        case .appForeground:   return "app_foreground"
        case .appBackground:   return "app_background"
        case .loggedIn:        return "logged_in"
        case .registered:      return "registered"
        case .loggedOut:       return "logged_out"
        case .screenView:      return "screen_view"
        }
    }

    var properties: [String: any Sendable]? {
        switch self {
        case .screenView(let screen):
            return ["screen": screen]
        default:
            return nil
        }
    }
}
