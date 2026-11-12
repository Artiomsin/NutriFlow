import SwiftUI

/// Search scope for filtering categories in Category Manager.
enum SearchScope: String, CaseIterable {
    case all, personal, system

    /// Human-readable title for UI display.
    var displayTitle: String {
        switch self {
        case .all: return "All"
        case .personal: return "Personal"
        case .system: return "System"
        }
    }
}
