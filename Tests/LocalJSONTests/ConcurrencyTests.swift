import Testing
import Foundation
@testable import LocalJSON

struct ConcurrencyTests {
    private struct Item: Codable, Equatable, Sendable {
        let id: Int
        let value: String
    }

    // MARK: - MockLocalJSON concurrency safety

    @Test func concurrentWritesToMockAreThreadSafe() async throws {
        let sut = MockLocalJSON()
        let count = 100

        try await withThrowingTaskGroup(of: Void.self) { group in
            for i in 0..<count {
                group.addTask {
                    try sut.writeJSON(data: Item(id: i, value: "item-\(i)"), to: "file-\(i).json")
                }
            }
            try await group.waitForAll()
        }

        #expect(sut.mockData.count == count)
    }

    @Test func concurrentReadsFromMockAreThreadSafe() async throws {
        let sut = MockLocalJSON()
        let count = 100

        for i in 0..<count {
            try sut.writeJSON(data: Item(id: i, value: "item-\(i)"), to: "file-\(i).json")
        }

        let results = try await withThrowingTaskGroup(of: Item.self, returning: [Item].self) { group in
            for i in 0..<count {
                group.addTask {
                    try sut.getJSON(from: "file-\(i).json", as: Item.self)
                }
            }
            var collected: [Item] = []
            for try await item in group {
                collected.append(item)
            }
            return collected
        }

        #expect(results.count == count)
    }

    @Test func concurrentReadWriteMixOnMockIsThreadSafe() async throws {
        let sut = MockLocalJSON()
        let count = 50

        // Pre-populate half the files
        for i in 0..<count {
            try sut.writeJSON(data: Item(id: i, value: "initial-\(i)"), to: "mix-\(i).json")
        }

        try await withThrowingTaskGroup(of: Void.self) { group in
            // Concurrent writes to new files
            for i in count..<(count * 2) {
                group.addTask {
                    try sut.writeJSON(data: Item(id: i, value: "new-\(i)"), to: "mix-\(i).json")
                }
            }
            // Concurrent reads from existing files
            for i in 0..<count {
                group.addTask {
                    _ = try sut.getJSON(from: "mix-\(i).json", as: Item.self)
                }
            }
            try await group.waitForAll()
        }

        #expect(sut.mockData.count == count * 2)
    }

    @Test func concurrentOverwritesOnMockAreThreadSafe() async throws {
        let sut = MockLocalJSON()
        let iterations = 100

        try await withThrowingTaskGroup(of: Void.self) { group in
            for i in 0..<iterations {
                group.addTask {
                    try sut.writeJSON(data: Item(id: i, value: "v\(i)"), to: "shared.json")
                }
            }
            try await group.waitForAll()
        }

        // File should exist with one of the values (last writer wins)
        let result = try sut.getJSON(from: "shared.json", as: Item.self)
        #expect(result.value.hasPrefix("v"))
    }

    // MARK: - LocalJSON file-system concurrency

    @Test func concurrentFileWritesThenReads() async throws {
        let sut = LocalJSON()
        let count = 20
        let prefix = "conc_test_\(UUID().uuidString)"

        // Concurrent writes
        try await withThrowingTaskGroup(of: Void.self) { group in
            for i in 0..<count {
                group.addTask {
                    try sut.writeJSON(data: Item(id: i, value: "val-\(i)"), to: "\(prefix)_\(i).json")
                }
            }
            try await group.waitForAll()
        }

        // Concurrent reads
        let results = try await withThrowingTaskGroup(of: Item.self, returning: [Item].self) { group in
            for i in 0..<count {
                group.addTask {
                    try sut.getJSON(from: "\(prefix)_\(i).json", as: Item.self)
                }
            }
            var collected: [Item] = []
            for try await item in group {
                collected.append(item)
            }
            return collected
        }

        #expect(results.count == count)

        // Cleanup
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        for i in 0..<count {
            try FileManager.default.removeItem(at: dir.appendingPathComponent("\(prefix)_\(i).json"))
        }
    }

    // MARK: - Async protocol DI under concurrency

    @Test func asyncProtocolDIWithConcurrentAccess() async throws {
        func fetchItems(using service: any LocalJSONProtocol, files: [String]) async throws -> [Item] {
            try await withThrowingTaskGroup(of: Item.self, returning: [Item].self) { group in
                for file in files {
                    group.addTask {
                        try await service.getJSON(from: file, as: Item.self)
                    }
                }
                var results: [Item] = []
                for try await item in group {
                    results.append(item)
                }
                return results
            }
        }

        let mock = MockLocalJSON()
        let files = (0..<20).map { "di-\($0).json" }
        for (i, file) in files.enumerated() {
            try mock.writeJSON(data: Item(id: i, value: "di-\(i)"), to: file)
        }

        let results = try await fetchItems(using: mock, files: files)
        #expect(results.count == 20)
    }
}
