import UserNotifications

@MainActor
protocol NotificationManaging: AnyObject {
    func authorizationStatus() async -> UNAuthorizationStatus
    func requestAuthorizationIfNeeded() async -> Bool
    func hasPendingRequest(identifier: String) async -> Bool
    func schedule(_ notification: AppNotification) async
    func cancelPending(identifiers: [String])
    func cancel(identifiers: [String])
}
