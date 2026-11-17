import Foundation

final class ActivityService: ActivityServiceProtocol, Sendable {
    
    private let client: HTTPClient
    
    init(client: HTTPClient){
        self.client = client
    }
    
    /// Sends activity entries directly. Failures are surfaced to the caller;
    /// there is no local retry queue, so no data from one session can be
    /// replayed into another account.
    func sync(entries: [DailyActivity]) async throws {
        // `DailyActivity` encodes nil fields as omitted keys, which matches
        // the backend's optional schema fields.
        try await send(entries: entries)
        print("[ActivityService] synced \(entries.count) entries")
    }
    
    private func send(entries: [DailyActivity]) async throws {
        let request = APIRequest(
            path: ActivityEndpoints.sync,
            method: .POST,
            body: ActivitySyncRequest(entries: entries)
        )
        try await client.sendVoid(request)
    }
    
    func getRange(from: String, to: String) async throws -> [ActivityDayPoint] {
        let endpoint = ActivityEndpoints.range(from: from, to: to)
        let request = APIRequest<NeverBody>(
            path: endpoint.path,
            method: .GET,
            queryItems: endpoint.query
        )
        return try await client.send(request)
    }
}
