import Testing
import Foundation
@testable import LocalJSON

struct LocalJSONAsyncTests {
    private struct Item: Codable, Equatable, Sendable {
        let id: Int
        let title: String
    }

    private let testFile = "localjson_async_test_\(UUID().uuidString).json"

    /// Call through protocol type to ensure async overloads are dispatched.
    private func makeSUT() -> any LocalJSONProtocol {
        LocalJSON()
    }

    @Test func asyncWriteAndReadDecodable() async throws {
        let sut = makeSUT()
        let item = Item(id: 1, title: "AsyncTest")

        try await sut.writeJSON(data: item, to: testFile)
        let result: Item = try await sut.getJSON(from: testFile, as: Item.self)

        #expect(result == item)
        try removeTestFile()
    }

    @Test func asyncWriteAndReadRawData() async throws {
        let sut = makeSUT()
        let item = Item(id: 2, title: "RawAsync")

        try await sut.writeJSON(data: item, to: testFile)
        let data: Data = try await sut.getJSON(from: testFile)
        let decoded = try JSONDecoder().decode(Item.self, from: data)

        #expect(decoded == item)
        try removeTestFile()
    }

    @Test func asyncWritePrettyPrintsJSON() async throws {
        let sut = makeSUT()
        let item = Item(id: 3, title: "PrettyAsync")

        try await sut.writeJSON(data: item, to: testFile)
        let data: Data = try await sut.getJSON(from: testFile)
        let jsonString = String(data: data, encoding: .utf8)!

        #expect(jsonString.contains("\n"))
        try removeTestFile()
    }

    @Test func asyncGetJSONThrowsForMissingFile() async {
        let sut = makeSUT()

        await #expect(throws: (any Error).self) {
            let _: Data = try await sut.getJSON(from: "does_not_exist_\(UUID().uuidString).json")
        }
    }

    @Test func asyncGetJSONDecodableThrowsForMissingFile() async {
        let sut = makeSUT()

        await #expect(throws: (any Error).self) {
            _ = try await sut.getJSON(from: "does_not_exist_\(UUID().uuidString).json", as: Item.self)
        }
    }

    @Test func asyncOverwriteFile() async throws {
        let sut = makeSUT()

        try await sut.writeJSON(data: Item(id: 1, title: "Old"), to: testFile)
        try await sut.writeJSON(data: Item(id: 2, title: "New"), to: testFile)

        let result: Item = try await sut.getJSON(from: testFile, as: Item.self)
        #expect(result.id == 2)
        #expect(result.title == "New")
        try removeTestFile()
    }

    private func removeTestFile() throws {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(testFile)
        try FileManager.default.removeItem(at: url)
    }
}
