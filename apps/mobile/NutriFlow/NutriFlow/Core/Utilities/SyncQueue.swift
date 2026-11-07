import Foundation

/// Persistent local queue for failed sync attempts.
/// Entries survive app relaunches and are retried with exponential backoff.
final class SyncQueue: @unchecked Sendable {

    static let shared = SyncQueue()

    private let defaults = UserDefaults.standard
    private let queueKey = "sync_queue_activity"

    // Limits
    private let maxQueueEntries = 1000
    private let maxQueueAgeDays = 30

    // Retry config: exponential backoff 1s → 2s → 4s → 8s ... capped at 5 min
    private let baseRetryDelay: TimeInterval = 1.0
    private let maxRetryDelay: TimeInterval = 300.0

    static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private init() {}

   

    /// All pending entries.
    var all: [[String: Any]] {
        guard let data = defaults.data(forKey: queueKey),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        return array
    }

    /// Entries whose nextRetryAt is in the past (ready to retry now).
    var readyForRetry: [[String: Any]] {
        let now = Date()
        return all.filter { entry in
            guard let retryAtString = entry["nextRetryAt"] as? String,
                  let retryAt = Self.isoFormatter.date(from: retryAtString) else {
                return true // No retry time means ready immediately
            }
            return retryAt <= now
        }
    }

    var isEmpty: Bool {
        all.isEmpty
    }

    var count: Int {
        all.count
    }

    /// Adds an entry to the queue. Skips if an entry with the same date already exists.
    func enqueue(_ entry: [String: Any]) {
        var array = all

        // Duplicate check by date
        if let date = entry["date"] as? String,
           array.contains(where: { $0["date"] as? String == date }) {
            print("[SyncQueue] skip duplicate entry for date \(date)")
            return
        }

        var newEntry = entry
        newEntry["retryCount"] = 0
        newEntry["nextRetryAt"] = Self.isoFormatter.string(from: Date())

        array.append(newEntry)
        save(array)
        print("[SyncQueue] enqueued entry for date \(newEntry["date"] ?? "?")")
    }

    /// Removes a single entry by date (called after successful sync).
    func remove(_ date: String) {
        var array = all
        array.removeAll { $0["date"] as? String == date }
        save(array)
    }

    /// Updates an existing entry (used to bump retryCount / nextRetryAt on failure).
    func update(_ entry: [String: Any]) {
        guard let date = entry["date"] as? String else { return }
        var array = all
        if let index = array.firstIndex(where: { $0["date"] as? String == date }) {
            array[index] = entry
            save(array)
        }
    }

    /// Clears the whole queue.
    func removeAll() {
        defaults.removeObject(forKey: queueKey)
    }

    /// Removes entries older than N days (date-based cleanup).
    func removeOlderThan(days: Int) {
        let calendar = Calendar.current
        guard let cutoff = calendar.date(byAdding: .day, value: -days, to: Date()) else { return }

        var array = all
        array.removeAll { entry in
            guard let dateStr = entry["date"] as? String,
                  let date = Self.isoFormatter.date(from: dateStr + "T00:00:00Z") else {
                return false
            }
            return date < cutoff
        }
        save(array)
    }

    /// Keeps only the newest N entries, dropping the oldest if over the limit.
    func trimToMaxEntries() {
        var array = all
        if array.count > maxQueueEntries {
            array = Array(array.suffix(maxQueueEntries))
            save(array)
        }
    }

 

    private func save(_ array: [[String: Any]]) {
        guard let data = try? JSONSerialization.data(withJSONObject: array) else { return }
        defaults.set(data, forKey: queueKey)
    }
}
