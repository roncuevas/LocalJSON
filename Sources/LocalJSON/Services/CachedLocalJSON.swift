import Foundation

public final class CachedLocalJSON: LocalJSONProtocol, @unchecked Sendable {
    private struct CacheEntry {
        var data: Data
        var lastAccessed: Date
        let createdAt: Date
    }

    private let wrapped: any LocalJSONProtocol
    private let policy: CachePolicy
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var cache: [String: CacheEntry] = [:]
    private let lock = NSLock()

    private func withLock<T>(_ body: (inout [String: CacheEntry]) throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body(&cache)
    }

    public init(
        wrapping inner: any LocalJSONProtocol,
        policy: CachePolicy = CachePolicy(),
        encoder: JSONEncoder? = nil,
        decoder: JSONDecoder? = nil
    ) {
        self.wrapped = inner
        self.policy = policy
        if let encoder {
            self.encoder = encoder
        } else {
            let e = JSONEncoder()
            e.outputFormatting = .prettyPrinted
            self.encoder = e
        }
        self.decoder = decoder ?? JSONDecoder()
    }

    // MARK: - LocalJSONProtocol

    public func getJSON(from file: String) throws -> Data {
        if !policy.readCacheEnabled {
            return try wrapped.getJSON(from: file)
        }

        let cached: CacheEntry? = withLock { cache in
            guard var entry = cache[file] else { return nil }
            if let ttl = policy.ttl, Date().timeIntervalSince(entry.createdAt) > ttl {
                cache.removeValue(forKey: file)
                return nil
            }
            entry.lastAccessed = Date()
            cache[file] = entry
            return entry
        }

        if let cached {
            return cached.data
        }

        let data = try wrapped.getJSON(from: file)

        withLock { cache in
            cache[file] = CacheEntry(data: data, lastAccessed: Date(), createdAt: Date())
            evictIfNeeded(&cache)
        }

        return data
    }

    public func getJSON<T: Decodable>(from file: String, as type: T.Type) throws -> T {
        let data = try getJSON(from: file)
        return try decoder.decode(T.self, from: data)
    }

    public func writeJSON<T: Encodable>(data: T, to path: String) throws {
        let jsonData = try encoder.encode(data)

        if policy.writeDedupEnabled {
            let shouldSkip: Bool = withLock { cache in
                guard let entry = cache[path] else { return false }
                if let ttl = policy.ttl, Date().timeIntervalSince(entry.createdAt) > ttl {
                    return false
                }
                return entry.data == jsonData
            }
            if shouldSkip { return }
        }

        try wrapped.writeJSON(data: data, to: path)

        if policy.readCacheEnabled || policy.writeDedupEnabled {
            withLock { cache in
                cache[path] = CacheEntry(data: jsonData, lastAccessed: Date(), createdAt: Date())
                evictIfNeeded(&cache)
            }
        }
    }

    public func exists(file: String) -> Bool {
        wrapped.exists(file: file)
    }

    public func delete(file: String) throws {
        try wrapped.delete(file: file)
        _ = withLock { $0.removeValue(forKey: file) }
    }

    public func listFiles(in directory: String) throws -> [String] {
        try wrapped.listFiles(in: directory)
    }

    // MARK: - Cache management

    public func clearCache() {
        withLock { $0.removeAll() }
    }

    public func invalidate(file: String) {
        _ = withLock { $0.removeValue(forKey: file) }
    }

    // MARK: - Private

    private func evictIfNeeded(_ cache: inout [String: CacheEntry]) {
        guard let max = policy.maxEntries, cache.count > max else { return }
        let sorted = cache.sorted { $0.value.lastAccessed < $1.value.lastAccessed }
        let toRemove = cache.count - max
        for entry in sorted.prefix(toRemove) {
            cache.removeValue(forKey: entry.key)
        }
    }
}
