import Foundation

enum TabScreen: Int, CaseIterable, Sendable {
    case home = 0
    case progress = 1
    case settings = 2

    var screenName: String {
        switch self {
        case .home:     return "home"
        case .progress: return "progress"
        case .settings: return "settings"
        }
    }

    func trackOpen(_ tracker: AnalyticsTracking?) {
        tracker?.track(.screenView(screen: screenName))
    }
}