import Foundation

final class ActivityService: ActivityServiceProtocol, Sendable {
    
    private let client: HTTPClient
    private let queue = SyncQueue.shared
    
    init(client: HTTPClient){
        self.client = client
    }
    
    /// Public entry point: enqueues entries locally, then attempts network send.
    /// On success, clears sent entries from the queue.
    func sync(entries: [DailyActivity]) async throws {
        
        // Persist entries locally before attempting network call so they survive
        // network failures and can be retried later.
        let payloads = entries.map { entry in
            [
                "date": entry.date,
                "steps": entry.steps,
                "activeCalories": entry.activeCalories,
                "basalCalories": entry.basalCalories,
                "distanceMeters": entry.distanceMeters
            ]
        }
        payloads.forEach { queue.enqueue($0) }
        queue.trimToMaxEntries()
        
        do {
            try await send(entries: entries)
            
            // Success: remove sent entries from the queue and cleanup old records.
            entries.forEach { queue.remove($0.date) }
            queue.removeOlderThan(days: 30)
            
            print("[ActivityService] synced \(entries.count) entries")
        } catch {
            print("[ActivityService] sync failed for \(entries.count) entries: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Low-level send without local enqueue. Used by the coordinator when
    /// retrying entries that are already in the queue.
    func send(entries: [DailyActivity]) async throws {
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
