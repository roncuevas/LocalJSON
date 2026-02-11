import Testing
import Foundation
@testable import LocalJSON

struct LocalJSONTests {
    private struct Item: Codable, Equatable {
        let id: Int
        let title: String
    }

    private let testFile = "localjson_test_\(UUID().uuidString).json"
    private let sut = LocalJSON()

    @Test func writeAndReadDecodable() throws {
        let item = Item(id: 1, title: "Test")

        try sut.writeJSON(data: item, to: testFile)
        let result = try sut.getJSON(from: testFile, as: Item.self)

        #expect(result == item)
        try removeTestFile()
    }

    @Test func writeAndReadRawData() throws {
        let item = Item(id: 2, title: "Raw")

        try sut.writeJSON(data: item, to: testFile)
        let data = try sut.getJSON(from: testFile)
        let decoded = try JSONDecoder().decode(Item.self, from: data)

        #expect(decoded == item)
        try removeTestFile()
    }

    @Test func writePrettyPrintsJSON() throws {
        let item = Item(id: 3, title: "Pretty")

        try sut.writeJSON(data: item, to: testFile)
        let data = try sut.getJSON(from: testFile)
        let jsonString = String(data: data, encoding: .utf8)!

        #expect(jsonString.contains("\n"))
        try removeTestFile()
    }

    @Test func getJSONThrowsForMissingFile() {
        #expect(throws: (any Error).self) {
            _ = try sut.getJSON(from: "does_not_exist_\(UUID().uuidString).json")
        }
    }

    @Test func getJSONDecodableThrowsForMissingFile() {
        #expect(throws: (any Error).self) {
            _ = try sut.getJSON(from: "does_not_exist_\(UUID().uuidString).json", as: Item.self)
        }
    }

    @Test func overwriteFile() throws {
        try sut.writeJSON(data: Item(id: 1, title: "Old"), to: testFile)
        try sut.writeJSON(data: Item(id: 2, title: "New"), to: testFile)

        let result = try sut.getJSON(from: testFile, as: Item.self)
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
