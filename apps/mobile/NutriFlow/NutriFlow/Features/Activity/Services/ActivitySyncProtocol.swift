import Foundation

protocol ActivitySyncProtocol: AnyObject {
    var isSessionActive: Bool { get }
    var onActivityUpdate: ((DailyActivity) -> Void)? { get set }
    func start()
    func stop()
    func refresh() async
}
