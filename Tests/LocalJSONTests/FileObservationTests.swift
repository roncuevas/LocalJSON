import Testing
import Foundation
@testable import LocalJSON

/// Thread-safe collector for stream values.
private final class Collector<T: Sendable>: @unchecked Sendable {
    private var _values: [T] = []
    private let lock = NSLock()

    var values: [T] {
        lock.lock()
        defer { lock.unlock() }
        return _values
    }

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return _values.count
    }

    func append(_ value: T) {
        lock.lock()
        defer { lock.unlock() }
        _values.append(value)
    }
}

struct FileObservationTests {
    private struct Item: Codable, Equatable, Sendable {
        let id: Int
        let value: String
    }

    /// Calls sync `delete` explicitly to avoid async overload resolution.
    private func syncDelete(_ mock: MockLocalJSON, file: String) throws {
        let sync: (String) throws -> Void = mock.delete(file:)
        try sync(file)
    }

    /// Calls sync `writeJSON` explicitly to avoid async overload resolution.
    private func syncWrite<T: Encodable>(_ mock: MockLocalJSON, data: T, to file: String) throws {
        let sync: (T, String) throws -> Void = mock.writeJSON(data:to:)
        try sync(data, file)
    }

    // MARK: - Basic emission

    @Test func emitsInitialValueImmediately() async throws {
        let mock = MockLocalJSON()
        try syncWrite(mock, data: Item(id: 1, value: "a"), to: "watch.json")

        let stream = mock.changes(to: "watch.json", as: Item.self, checkEvery: 0.05)
        var iterator = stream.makeAsyncIterator()

        let first = await iterator.next()
        #expect(first == Item(id: 1, value: "a"))
    }

    @Test func emitsNilWhenFileDoesNotExist() async throws {
        let mock = MockLocalJSON()

        let stream = mock.changes(to: "missing.json", as: Item.self, checkEvery: 0.05)
        var iterator = stream.makeAsyncIterator()

        let first = await iterator.next()
        #expect(first == Optional<Item>.none)
    }

    // MARK: - Change detection

    @Test func emitsNewValueAfterFileChanges() async throws {
        let mock = MockLocalJSON()
        try syncWrite(mock, data: Item(id: 1, value: "a"), to: "watch.json")

        let stream = mock.changes(to: "watch.json", as: Item.self, checkEvery: 0.05)
        let collector = Collector<Item?>()

        let collectTask = Task {
            for await value in stream {
                collector.append(value)
                if collector.count >= 2 { break }
            }
        }

        try await Task.sleep(nanoseconds: 100_000_000)
        try syncWrite(mock, data: Item(id: 2, value: "b"), to: "watch.json")
        try await Task.sleep(nanoseconds: 200_000_000)
        collectTask.cancel()

        let values = collector.values
        #expect(values.count >= 2)
        #expect(values[0] == Item(id: 1, value: "a"))
        #expect(values[1] == Item(id: 2, value: "b"))
    }

    @Test func doesNotEmitWhenDataUnchanged() async throws {
        let mock = MockLocalJSON()
        try syncWrite(mock, data: Item(id: 1, value: "a"), to: "watch.json")

        let stream = mock.changes(to: "watch.json", as: Item.self, checkEvery: 0.05)
        let collector = Collector<Item?>()

        let collectTask = Task {
            for await value in stream {
                collector.append(value)
            }
        }

        try await Task.sleep(nanoseconds: 300_000_000)
        collectTask.cancel()

        #expect(collector.count == 1)
    }

    // MARK: - File deletion

    @Test func emitsNilWhenFileIsDeleted() async throws {
        let mock = MockLocalJSON()
        try syncWrite(mock, data: Item(id: 1, value: "a"), to: "watch.json")

        let stream = mock.changes(to: "watch.json", as: Item.self, checkEvery: 0.05)
        let collector = Collector<Item?>()

        let collectTask = Task {
            for await value in stream {
                collector.append(value)
                if collector.count >= 2 { break }
            }
        }

        try await Task.sleep(nanoseconds: 100_000_000)
        try syncDelete(mock, file: "watch.json")
        try await Task.sleep(nanoseconds: 200_000_000)
        collectTask.cancel()

        let values = collector.values
        #expect(values.count >= 2)
        #expect(values[0] == Item(id: 1, value: "a"))
        #expect(values[1] == nil)
    }

    // MARK: - File creation

    @Test func emitsValueWhenFileAppears() async throws {
        let mock = MockLocalJSON()

        // Pre-create a stream for a non-existent file, then create it
        let stream = mock.changes(to: "appear.json", as: Item.self, checkEvery: 0.05)

        // Write the file after a short delay to give the stream time to start
        Task {
            try? await Task.sleep(nanoseconds: 150_000_000)
            try? syncWrite(mock, data: Item(id: 1, value: "new"), to: "appear.json")
        }

        // Collect values until we get a non-nil one
        var foundItem: Item?
        for await value in stream {
            if let value {
                foundItem = value
                break
            }
        }

        #expect(foundItem == Item(id: 1, value: "new"))
    }

    // MARK: - Cancellation

    @Test func cancellationStopsStream() async throws {
        let mock = MockLocalJSON()
        try syncWrite(mock, data: Item(id: 1, value: "a"), to: "watch.json")

        let stream = mock.changes(to: "watch.json", as: Item.self, checkEvery: 0.05)
        let collector = Collector<Item?>()

        let task = Task {
            for await value in stream {
                collector.append(value)
            }
        }

        try await Task.sleep(nanoseconds: 100_000_000)
        task.cancel()
        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(collector.count >= 1)
    }

    // MARK: - Works with any protocol conformer

    @Test func worksWithCachedLocalJSON() async throws {
        let mock = MockLocalJSON()
        let cached = CachedLocalJSON(wrapping: mock)
        let syncCachedWrite: (Item, String) throws -> Void = cached.writeJSON(data:to:)
        try syncCachedWrite(Item(id: 1, value: "cached"), "watch.json")

        let stream = cached.changes(to: "watch.json", as: Item.self, checkEvery: 0.05)
        var iterator = stream.makeAsyncIterator()

        let first = await iterator.next()
        #expect(first == Item(id: 1, value: "cached"))
    }
}
