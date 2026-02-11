import XCTest
@testable import LocalJSON

final class PerformanceTests: XCTestCase {
    private struct Item: Codable, Equatable, Sendable {
        let id: Int
        let title: String
        let tags: [String]
    }

    private static let sampleItem = Item(id: 1, title: "Performance", tags: ["swift", "json", "test"])

    // MARK: - MockLocalJSON sync performance

    func testMockSyncWritePerformance() throws {
        let sut = MockLocalJSON()
        let item = Self.sampleItem
        measure {
            for i in 0..<1000 {
                try! sut.writeJSON(data: item, to: "perf-\(i).json")
            }
        }
    }

    func testMockSyncReadPerformance() throws {
        let sut = MockLocalJSON()
        let item = Self.sampleItem
        for i in 0..<1000 {
            try sut.writeJSON(data: item, to: "perf-\(i).json")
        }
        measure {
            for i in 0..<1000 {
                _ = try! sut.getJSON(from: "perf-\(i).json", as: Item.self)
            }
        }
    }

    func testMockSyncRawReadPerformance() throws {
        let sut = MockLocalJSON()
        let item = Self.sampleItem
        for i in 0..<1000 {
            try sut.writeJSON(data: item, to: "perf-\(i).json")
        }
        measure {
            for i in 0..<1000 {
                _ = try! sut.getJSON(from: "perf-\(i).json")
            }
        }
    }

    // MARK: - MockLocalJSON async performance

    func testMockAsyncWritePerformance() {
        let sut: any LocalJSONProtocol = MockLocalJSON()
        let item = Self.sampleItem
        measure {
            let exp = expectation(description: "async write")
            Task {
                for i in 0..<1000 {
                    try await sut.writeJSON(data: item, to: "aperf-\(i).json")
                }
                exp.fulfill()
            }
            wait(for: [exp], timeout: 10)
        }
    }

    func testMockAsyncReadPerformance() {
        let sut = MockLocalJSON()
        let item = Self.sampleItem
        for i in 0..<1000 {
            try! sut.writeJSON(data: item, to: "aperf-\(i).json")
        }
        let protocolSut: any LocalJSONProtocol = sut
        measure {
            let exp = expectation(description: "async read")
            Task {
                for i in 0..<1000 {
                    _ = try await protocolSut.getJSON(from: "aperf-\(i).json", as: Item.self)
                }
                exp.fulfill()
            }
            wait(for: [exp], timeout: 10)
        }
    }

    // MARK: - LocalJSON file-system sync performance

    func testFileSystemSyncWritePerformance() throws {
        let sut = LocalJSON()
        let item = Self.sampleItem
        let prefix = "fsperf_\(UUID().uuidString)"
        measure {
            for i in 0..<100 {
                try! sut.writeJSON(data: item, to: "\(prefix)_\(i).json")
            }
        }
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        for i in 0..<100 {
            try? FileManager.default.removeItem(at: dir.appendingPathComponent("\(prefix)_\(i).json"))
        }
    }

    func testFileSystemSyncReadPerformance() throws {
        let sut = LocalJSON()
        let item = Self.sampleItem
        let prefix = "fsperf_r_\(UUID().uuidString)"
        for i in 0..<100 {
            try sut.writeJSON(data: item, to: "\(prefix)_\(i).json")
        }
        measure {
            for i in 0..<100 {
                _ = try! sut.getJSON(from: "\(prefix)_\(i).json", as: Item.self)
            }
        }
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        for i in 0..<100 {
            try? FileManager.default.removeItem(at: dir.appendingPathComponent("\(prefix)_\(i).json"))
        }
    }

    func testFileSystemSyncRawReadPerformance() throws {
        let sut = LocalJSON()
        let item = Self.sampleItem
        let prefix = "fsperf_raw_\(UUID().uuidString)"
        for i in 0..<100 {
            try sut.writeJSON(data: item, to: "\(prefix)_\(i).json")
        }
        measure {
            for i in 0..<100 {
                _ = try! sut.getJSON(from: "\(prefix)_\(i).json")
            }
        }
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        for i in 0..<100 {
            try? FileManager.default.removeItem(at: dir.appendingPathComponent("\(prefix)_\(i).json"))
        }
    }

    // MARK: - Concurrent performance

    func testMockConcurrentWritePerformance() {
        let sut = MockLocalJSON()
        let item = Self.sampleItem
        measure {
            let exp = expectation(description: "concurrent write")
            Task {
                try await withThrowingTaskGroup(of: Void.self) { group in
                    for i in 0..<500 {
                        group.addTask {
                            try sut.writeJSON(data: item, to: "cperf-\(i).json")
                        }
                    }
                    try await group.waitForAll()
                }
                exp.fulfill()
            }
            wait(for: [exp], timeout: 10)
        }
    }

    func testMockConcurrentReadPerformance() {
        let sut = MockLocalJSON()
        let item = Self.sampleItem
        for i in 0..<500 {
            try! sut.writeJSON(data: item, to: "cperf-\(i).json")
        }
        measure {
            let exp = expectation(description: "concurrent read")
            Task {
                try await withThrowingTaskGroup(of: Item.self) { group in
                    for i in 0..<500 {
                        group.addTask {
                            try sut.getJSON(from: "cperf-\(i).json", as: Item.self)
                        }
                    }
                    for try await _ in group {}
                }
                exp.fulfill()
            }
            wait(for: [exp], timeout: 10)
        }
    }

    func testFileSystemConcurrentWritePerformance() {
        let sut = LocalJSON()
        let item = Self.sampleItem
        let prefix = "fscperf_\(UUID().uuidString)"
        measure {
            let exp = expectation(description: "fs concurrent write")
            Task {
                try await withThrowingTaskGroup(of: Void.self) { group in
                    for i in 0..<50 {
                        group.addTask {
                            try sut.writeJSON(data: item, to: "\(prefix)_\(i).json")
                        }
                    }
                    try await group.waitForAll()
                }
                exp.fulfill()
            }
            wait(for: [exp], timeout: 10)
        }
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        for i in 0..<50 {
            try? FileManager.default.removeItem(at: dir.appendingPathComponent("\(prefix)_\(i).json"))
        }
    }

    // MARK: - Encoding/Decoding performance

    func testEncodingPerformance() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let item = Self.sampleItem
        measure {
            for _ in 0..<5000 {
                _ = try! encoder.encode(item)
            }
        }
    }

    func testDecodingPerformance() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(Self.sampleItem)
        let decoder = JSONDecoder()
        measure {
            for _ in 0..<5000 {
                _ = try! decoder.decode(Item.self, from: data)
            }
        }
    }
}
