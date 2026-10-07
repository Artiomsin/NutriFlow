import Foundation

@MainActor
protocol ActivitySyncProtocol: AnyObject {
    var isSessionActive: Bool { get }
    var onActivityUpdate: ((DailyActivity) -> Void)? { get set }
    var goalsProvider: (() -> UserGoals?)? { get set }
    func start()
    func stop()
    func refresh() async
    func authorizationDidChange()
}