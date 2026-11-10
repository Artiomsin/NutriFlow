import Foundation
import Observation

@MainActor
@Observable
final class ProgressRefreshState {
    private(set) var revision: UInt = 0
    /// Increments only when every calendar-day query became invalid, for example
    /// after the profile time zone changes. Screens use it to refetch data that
    /// is already held in memory instead of only dropping cached responses.
    private(set) var fullReloadRevision: UInt = 0

    func invalidate() {
        revision &+= 1
    }

    func invalidateRequiringFullReload() {
        revision &+= 1
        fullReloadRevision &+= 1
    }
}
