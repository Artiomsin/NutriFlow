import Foundation

enum TrackingEvent {
    case loggedIn
    case registered
    case loggedOut
    case foodAdded(name: String, calories: Int)
    case foodDeleted
    case waterAdded(amountMl: Int)
    case waterDeleted
    case profileCreated
    case profileUpdated
    case screenView(screen: String)

    var name: String {
        switch self {
        case .loggedIn:        return "logged_in"
        case .registered:      return "registered"
        case .loggedOut:       return "logged_out"
        case .foodAdded:       return "food_added"
        case .foodDeleted:     return "food_deleted"
        case .waterAdded:      return "water_added"
        case .waterDeleted:    return "water_deleted"
        case .profileCreated:  return "profile_created"
        case .profileUpdated:  return "profile_updated"
        case .screenView:      return "screen_view"
        }
    }

    var properties: [String: any Sendable]? {
        switch self {
        case .foodAdded(let name, let calories):
            return ["name": name, "calories": calories]
        case .waterAdded(let amountMl):
            return ["amount_ml": amountMl]
        case .screenView(let screen):
            return ["screen": screen]
        default:
            return nil
        }
    }
}
