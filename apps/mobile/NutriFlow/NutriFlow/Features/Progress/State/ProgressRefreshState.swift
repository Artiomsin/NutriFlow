import Foundation
import Observation

@MainActor
@Observable
final class ProgressRefreshState {
    private(set) var revision: UInt = 0

    func invalidate() {
        revision &+= 1
    }
}