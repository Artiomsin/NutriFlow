import Foundation
import Observation

@MainActor
@Observable
final class ProgressRefreshState {
    private(set) var revision: UInt = 0
    /// Changes only when a successful mutation may have changed the active goals.
    private(set) var goalsRevision: UInt = 0
    /// Changes when profile inputs or the current weight changed while goals may be manual.
    private(set) var manualGoalsDecisionRevision: UInt = 0
    /// Increments only when every calendar-day query became invalid, for example
    /// after the profile time zone changes. Screens use it to refetch data that
    /// is already held in memory instead of only dropping cached responses.
    private(set) var fullReloadRevision: UInt = 0

    func invalidate() {
        revision &+= 1
    }

    func invalidateGoals() {
        goalsRevision &+= 1
        revision &+= 1
    }

    func invalidateGoalsRequiringManualDecision() {
        manualGoalsDecisionRevision &+= 1
        invalidateGoals()
    }

    func invalidateRequiringFullReload() {
        revision &+= 1
        fullReloadRevision &+= 1
    }
}
