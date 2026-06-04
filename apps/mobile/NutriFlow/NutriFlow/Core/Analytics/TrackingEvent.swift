import Foundation

enum TrackingEvent {

    case loggedIn
    case registered
    case loggedOut

    case foodAdded(name: String, calories: Int)
    case foodDeleted

    var name: String {
        switch self {
        case .loggedIn:             return "logged_in"
        case .registered:           return "registered"
        case .loggedOut:            return "logged_out"
        case .foodAdded:            return "food_added"
        case .foodDeleted:          return "food_deleted"
        }
    }

    var properties: [String: Any]? {
        switch self {
        case .foodAdded(let name, let calories):
            return ["name": name, "calories": calories]
        default:
            return nil
        }
    }
}
