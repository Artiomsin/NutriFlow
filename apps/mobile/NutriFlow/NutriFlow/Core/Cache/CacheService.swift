import Foundation

actor CacheService {
    private let fm = FileManager.default
    private let dir: URL

    init() {
        let caches = fm.urls(for: .cachesDirectory, in: .userDomainMask).first!
        dir = caches.appendingPathComponent("nutriflow_cache", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    func get<T: Codable & Sendable>(_ key: String, ignoreTTL: Bool = false) throws -> T? {
        let file = dir.appendingPathComponent("\(key).json")
        guard let data = try? Data(contentsOf: file) else {
            #if DEBUG
            print("[Cache] MISS \(key)")
            #endif
            return nil
        }
        let meta = try JSONDecoder().decode(CacheMeta.self, from: data)
        guard ignoreTTL || meta.expiry > Date() else {
            #if DEBUG
            print("[Cache] EXPIRED \(key) (\(Int(meta.expiry.timeIntervalSinceNow * -1))s ago)")
            #endif
            try? fm.removeItem(at: file)
            return nil
        }
        #if DEBUG
        print("[Cache] HIT \(key)\(ignoreTTL ? " (stale)" : "")")
        #endif
        return try JSONDecoder().decode(T.self, from: meta.payload)
    }

    func set<T: Codable & Sendable>(_ key: String, _ value: T, ttl: TimeInterval) throws {
        #if DEBUG
        print("[Cache] SET \(key) (ttl: \(Int(ttl))s)")
        #endif
        let meta = CacheMeta(
            payload: try JSONEncoder().encode(value),
            expiry: Date().addingTimeInterval(ttl)
        )
        let data = try JSONEncoder().encode(meta)
        try data.write(to: dir.appendingPathComponent("\(key).json"), options: .atomic)
    }

    func remove(_ key: String) {
        #if DEBUG
        print("[Cache] REMOVE \(key)")
        #endif
        let file = dir.appendingPathComponent("\(key).json")
        try? fm.removeItem(at: file)
    }

    func removeByPrefix(_ prefix: String) {
        #if DEBUG
        print("[Cache] REMOVE by prefix: \(prefix)*")
        #endif
        guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }
        for file in files where file.lastPathComponent.hasPrefix(prefix) {
            try? fm.removeItem(at: file)
        }
    }

    func clear() {
        #if DEBUG
        print("[Cache] CLEAR all")
        #endif
        try? fm.removeItem(at: dir)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
    }
}

private struct CacheMeta: Codable {
    let payload: Data
    let expiry: Date
}
