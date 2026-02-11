import Testing
import Foundation
@testable import LocalJSON

// MARK: - SpyLocalJSON

/// Wraps a `MockLocalJSON` and counts read/write calls (thread-safe).
private final class SpyLocalJSON: LocalJSONProtocol, @unchecked Sendable {
    private let inner = MockLocalJSON()
    private let lock = NSLock()
    private var _readCount = 0
    private var _writeCount = 0

    var readCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _readCount
    }

    var writeCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _writeCount
    }

    func getJSON(from file: String) throws -> Data {
        lock.lock()
        _readCount += 1
        lock.unlock()
        return try inner.getJSON(from: file)
    }

    func getJSON<T: Decodable>(from file: String, as type: T.Type) throws -> T {
        let data = try getJSON(from: file)
        return try JSONDecoder().decode(T.self, from: data)
    }

    func writeJSON<T: Encodable>(data: T, to path: String) throws {
        lock.lock()
        _writeCount += 1
        lock.unlock()
        try inner.writeJSON(data: data, to: path)
    }

    func exists(file: String) -> Bool {
        inner.exists(file: file)
    }

    func delete(file: String) throws {
        try inner.delete(file: file)
    }

    func listFiles(in directory: String) throws -> [String] {
        try inner.listFiles(in: directory)
    }

    /// Seed data directly into the underlying mock without incrementing spy counters.
    func seed<T: Encodable>(data: T, to path: String) throws {
        try inner.writeJSON(data: data, to: path)
    }
}

// MARK: - Tests

struct CachedLocalJSONTests {
    private struct Item: Codable, Equatable, Sendable {
        let id: Int
        let value: String
    }

    // MARK: - Read cache

    @Test func readCacheHitAvoidsUnderlyingCall() throws {
        let spy = SpyLocalJSON()
        try spy.seed(data: Item(id: 1, value: "a"), to: "file.json")
        let sut = CachedLocalJSON(wrapping: spy)

        _ = try sut.getJSON(from: "file.json")
        _ = try sut.getJSON(from: "file.json")
        _ = try sut.getJSON(from: "file.json")

        #expect(spy.readCount == 1)
    }

    @Test func typedReadCacheHitAvoidsUnderlyingCall() throws {
        let spy = SpyLocalJSON()
        try spy.seed(data: Item(id: 1, value: "a"), to: "file.json")
        let sut = CachedLocalJSON(wrapping: spy)

        _ = try sut.getJSON(from: "file.json")
        let item = try sut.getJSON(from: "file.json", as: Item.self)

        #expect(spy.readCount == 1)
        #expect(item == Item(id: 1, value: "a"))
    }

    @Test func readCacheDisabledAlwaysCallsUnderlying() throws {
        let spy = SpyLocalJSON()
        try spy.seed(data: Item(id: 1, value: "a"), to: "file.json")
        let sut = CachedLocalJSON(wrapping: spy, policy: CachePolicy(readCacheEnabled: false))

        _ = try sut.getJSON(from: "file.json")
        _ = try sut.getJSON(from: "file.json")
        _ = try sut.getJSON(from: "file.json")

        #expect(spy.readCount == 3)
    }

    @Test func disabledPolicyIsFullPassthrough() throws {
        let spy = SpyLocalJSON()
        try spy.seed(data: Item(id: 1, value: "a"), to: "file.json")
        let sut = CachedLocalJSON(wrapping: spy, policy: .disabled)

        _ = try sut.getJSON(from: "file.json")
        _ = try sut.getJSON(from: "file.json")
        try sut.writeJSON(data: Item(id: 1, value: "a"), to: "file.json")
        try sut.writeJSON(data: Item(id: 1, value: "a"), to: "file.json")

        #expect(spy.readCount == 2)
        #expect(spy.writeCount == 2)
    }

    // MARK: - TTL

    @Test func expiredEntryIsTreatedAsCacheMiss() throws {
        let spy = SpyLocalJSON()
        try spy.seed(data: Item(id: 1, value: "a"), to: "file.json")
        let sut = CachedLocalJSON(wrapping: spy, policy: CachePolicy(ttl: 0))

        _ = try sut.getJSON(from: "file.json")
        Thread.sleep(forTimeInterval: 0.01)
        _ = try sut.getJSON(from: "file.json")

        #expect(spy.readCount == 2)
    }

    @Test func nonExpiredEntryIsStillAHit() throws {
        let spy = SpyLocalJSON()
        try spy.seed(data: Item(id: 1, value: "a"), to: "file.json")
        let sut = CachedLocalJSON(wrapping: spy, policy: CachePolicy(ttl: 60))

        _ = try sut.getJSON(from: "file.json")
        _ = try sut.getJSON(from: "file.json")

        #expect(spy.readCount == 1)
    }

    // MARK: - Write dedup

    @Test func writeDedupSkipsIdenticalWrite() throws {
        let spy = SpyLocalJSON()
        let sut = CachedLocalJSON(wrapping: spy)

        try sut.writeJSON(data: Item(id: 1, value: "a"), to: "file.json")
        try sut.writeJSON(data: Item(id: 1, value: "a"), to: "file.json")
        try sut.writeJSON(data: Item(id: 1, value: "a"), to: "file.json")

        #expect(spy.writeCount == 1)
    }

    @Test func writeDedupAllowsDifferentData() throws {
        let spy = SpyLocalJSON()
        let sut = CachedLocalJSON(wrapping: spy)

        try sut.writeJSON(data: Item(id: 1, value: "a"), to: "file.json")
        try sut.writeJSON(data: Item(id: 2, value: "b"), to: "file.json")

        #expect(spy.writeCount == 2)
    }

    @Test func writeDedupDisabledAlwaysWrites() throws {
        let spy = SpyLocalJSON()
        let sut = CachedLocalJSON(wrapping: spy, policy: CachePolicy(writeDedupEnabled: false))

        try sut.writeJSON(data: Item(id: 1, value: "a"), to: "file.json")
        try sut.writeJSON(data: Item(id: 1, value: "a"), to: "file.json")

        #expect(spy.writeCount == 2)
    }

    // MARK: - Write populates read cache

    @Test func writeUpdatesReadCache() throws {
        let spy = SpyLocalJSON()
        let sut = CachedLocalJSON(wrapping: spy)

        try sut.writeJSON(data: Item(id: 1, value: "a"), to: "file.json")
        let result = try sut.getJSON(from: "file.json", as: Item.self)

        #expect(spy.readCount == 0)
        #expect(result == Item(id: 1, value: "a"))
    }

    @Test func writeUpdatesCacheForSubsequentRead() throws {
        let spy = SpyLocalJSON()
        let sut = CachedLocalJSON(wrapping: spy)

        try sut.writeJSON(data: Item(id: 1, value: "a"), to: "file.json")
        try sut.writeJSON(data: Item(id: 2, value: "b"), to: "file.json")
        let result = try sut.getJSON(from: "file.json", as: Item.self)

        #expect(spy.readCount == 0)
        #expect(result == Item(id: 2, value: "b"))
    }

    // MARK: - Eviction

    @Test func evictsOldestEntryWhenMaxExceeded() throws {
        let spy = SpyLocalJSON()
        let sut = CachedLocalJSON(wrapping: spy, policy: CachePolicy(maxEntries: 2))

        try spy.seed(data: Item(id: 1, value: "a"), to: "a.json")
        try spy.seed(data: Item(id: 2, value: "b"), to: "b.json")
        try spy.seed(data: Item(id: 3, value: "c"), to: "c.json")

        _ = try sut.getJSON(from: "a.json")
        _ = try sut.getJSON(from: "b.json")
        _ = try sut.getJSON(from: "c.json")

        // a.json was accessed first (oldest lastAccessed), should be evicted
        #expect(spy.readCount == 3)

        // Reading a.json again should be a cache miss (evicted)
        _ = try sut.getJSON(from: "a.json")
        #expect(spy.readCount == 4)

        // b.json should also have been evicted (only 2 entries fit)
        _ = try sut.getJSON(from: "c.json")
        #expect(spy.readCount == 4) // c.json is still cached
    }

    @Test func lruEvictsLeastRecentlyAccessedNotOldestCreated() throws {
        let spy = SpyLocalJSON()
        let sut = CachedLocalJSON(wrapping: spy, policy: CachePolicy(maxEntries: 2))

        try spy.seed(data: Item(id: 1, value: "a"), to: "a.json")
        try spy.seed(data: Item(id: 2, value: "b"), to: "b.json")
        try spy.seed(data: Item(id: 3, value: "c"), to: "c.json")

        _ = try sut.getJSON(from: "a.json") // access a
        _ = try sut.getJSON(from: "b.json") // access b
        _ = try sut.getJSON(from: "a.json") // re-access a (refreshes LRU)
        _ = try sut.getJSON(from: "c.json") // triggers eviction — b is LRU

        #expect(spy.readCount == 3) // a(miss), b(miss), a(hit=no call), c(miss)

        // b was evicted (least recently accessed), a should still be cached
        _ = try sut.getJSON(from: "a.json")
        #expect(spy.readCount == 3) // a is still cached

        _ = try sut.getJSON(from: "b.json")
        #expect(spy.readCount == 4) // b was evicted, re-read
    }

    // MARK: - Cache management

    @Test func clearCacheForcesSubsequentReads() throws {
        let spy = SpyLocalJSON()
        try spy.seed(data: Item(id: 1, value: "a"), to: "file.json")
        let sut = CachedLocalJSON(wrapping: spy)

        _ = try sut.getJSON(from: "file.json")
        #expect(spy.readCount == 1)

        sut.clearCache()

        _ = try sut.getJSON(from: "file.json")
        #expect(spy.readCount == 2)
    }

    @Test func invalidateSingleFile() throws {
        let spy = SpyLocalJSON()
        try spy.seed(data: Item(id: 1, value: "a"), to: "a.json")
        try spy.seed(data: Item(id: 2, value: "b"), to: "b.json")
        let sut = CachedLocalJSON(wrapping: spy)

        _ = try sut.getJSON(from: "a.json")
        _ = try sut.getJSON(from: "b.json")
        #expect(spy.readCount == 2)

        sut.invalidate(file: "a.json")

        _ = try sut.getJSON(from: "a.json") // miss — invalidated
        _ = try sut.getJSON(from: "b.json") // hit — still cached
        #expect(spy.readCount == 3)
    }

    // MARK: - Error handling

    @Test func readErrorIsNotCached() throws {
        let spy = SpyLocalJSON()
        let sut = CachedLocalJSON(wrapping: spy)

        // First read: file doesn't exist → error
        #expect(throws: (any Error).self) {
            _ = try sut.getJSON(from: "missing.json")
        }

        // Seed the file, then read again — should succeed
        try spy.seed(data: Item(id: 1, value: "a"), to: "missing.json")
        let result = try sut.getJSON(from: "missing.json", as: Item.self)
        #expect(result == Item(id: 1, value: "a"))
    }

    // MARK: - Protocol conformance

    @Test func cachedLocalJSONConformsToProtocol() {
        let instance: any LocalJSONProtocol = CachedLocalJSON(wrapping: MockLocalJSON())
        #expect(instance is CachedLocalJSON)
    }

    // MARK: - Concurrency

    @Test func concurrentReadsAndWritesAreThreadSafe() async throws {
        let spy = SpyLocalJSON()
        for i in 0..<50 {
            try spy.seed(data: Item(id: i, value: "v\(i)"), to: "file-\(i).json")
        }
        let sut = CachedLocalJSON(wrapping: spy)

        try await withThrowingTaskGroup(of: Void.self) { group in
            // 50 concurrent reads
            for i in 0..<50 {
                group.addTask {
                    _ = try sut.getJSON(from: "file-\(i).json", as: Item.self)
                }
            }
            // 50 concurrent writes
            for i in 0..<50 {
                group.addTask {
                    try sut.writeJSON(data: Item(id: i, value: "new-\(i)"), to: "write-\(i).json")
                }
            }
            try await group.waitForAll()
        }

        // Verify no crash/deadlock occurred and data is accessible
        let item = try sut.getJSON(from: "write-0.json", as: Item.self)
        #expect(item.id == 0)
    }
}
