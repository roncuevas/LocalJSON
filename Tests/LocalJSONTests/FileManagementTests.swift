import Testing
import Foundation
@testable import LocalJSON

struct FileManagementTests {
    private struct Item: Codable, Equatable {
        let id: Int
        let value: String
    }

    // MARK: - exists (Mock)

    @Test func existsReturnsFalseForMissingFile() {
        let sut = MockLocalJSON()
        #expect(sut.exists(file: "nope.json") == false)
    }

    @Test func existsReturnsTrueAfterWrite() throws {
        let sut = MockLocalJSON()
        try sut.writeJSON(data: Item(id: 1, value: "a"), to: "item.json")
        #expect(sut.exists(file: "item.json") == true)
    }

    @Test func existsReturnsFalseAfterDelete() throws {
        let sut = MockLocalJSON()
        try sut.writeJSON(data: Item(id: 1, value: "a"), to: "item.json")
        try sut.delete(file: "item.json")
        #expect(sut.exists(file: "item.json") == false)
    }

    // MARK: - delete (Mock)

    @Test func deleteRemovesFile() throws {
        let sut = MockLocalJSON()
        try sut.writeJSON(data: Item(id: 1, value: "a"), to: "item.json")
        try sut.delete(file: "item.json")

        #expect(throws: MockLocalJSONError.self) {
            _ = try sut.getJSON(from: "item.json")
        }
    }

    @Test func deleteThrowsForMissingFile() {
        let sut = MockLocalJSON()
        #expect(throws: MockLocalJSONError.self) {
            try sut.delete(file: "nope.json")
        }
    }

    // MARK: - listFiles (Mock)

    @Test func listFilesReturnsEmptyWhenNoFiles() throws {
        let sut = MockLocalJSON()
        let result = try sut.listFiles()
        #expect(result.isEmpty)
    }

    @Test func listFilesReturnsWrittenFiles() throws {
        let sut = MockLocalJSON()
        try sut.writeJSON(data: Item(id: 1, value: "a"), to: "a.json")
        try sut.writeJSON(data: Item(id: 2, value: "b"), to: "b.json")
        try sut.writeJSON(data: Item(id: 3, value: "c"), to: "c.json")

        let result = try sut.listFiles()
        #expect(result == ["a.json", "b.json", "c.json"])
    }

    @Test func listFilesExcludesSubdirectoryFiles() throws {
        let sut = MockLocalJSON()
        try sut.writeJSON(data: Item(id: 1, value: "a"), to: "root.json")
        try sut.writeJSON(data: Item(id: 2, value: "b"), to: "users/deep.json")

        let result = try sut.listFiles()
        #expect(result == ["root.json"])
    }

    @Test func listFilesInSubdirectory() throws {
        let sut = MockLocalJSON()
        try sut.writeJSON(data: Item(id: 1, value: "a"), to: "users/a.json")
        try sut.writeJSON(data: Item(id: 2, value: "b"), to: "users/b.json")
        try sut.writeJSON(data: Item(id: 3, value: "c"), to: "other/c.json")

        let result = try sut.listFiles(in: "users")
        #expect(result == ["users/a.json", "users/b.json"])
    }

    @Test func listFilesReturnsFullRelativePaths() throws {
        let sut = MockLocalJSON()
        try sut.writeJSON(data: Item(id: 1, value: "a"), to: "data/item.json")

        let files = try sut.listFiles(in: "data")
        #expect(files.count == 1)

        let item = try sut.getJSON(from: files[0], as: Item.self)
        #expect(item == Item(id: 1, value: "a"))
    }

    // MARK: - CachedLocalJSON delete invalidates cache

    @Test func cachedDeleteInvalidatesCache() throws {
        let mock = MockLocalJSON()
        let sut = CachedLocalJSON(wrapping: mock)

        try sut.writeJSON(data: Item(id: 1, value: "a"), to: "item.json")
        _ = try sut.getJSON(from: "item.json", as: Item.self)

        try sut.delete(file: "item.json")

        #expect(throws: (any Error).self) {
            _ = try sut.getJSON(from: "item.json", as: Item.self)
        }
    }

    // MARK: - File system (LocalJSON)

    @Test func fileSystemExists() throws {
        let sut = LocalJSON()
        let file = "test_exists_\(UUID().uuidString).json"
        defer { try? sut.delete(file: file) }

        #expect(sut.exists(file: file) == false)
        try sut.writeJSON(data: Item(id: 1, value: "a"), to: file)
        #expect(sut.exists(file: file) == true)
    }

    @Test func fileSystemDeleteRemovesFile() throws {
        let sut = LocalJSON()
        let file = "test_delete_\(UUID().uuidString).json"

        try sut.writeJSON(data: Item(id: 1, value: "a"), to: file)
        #expect(sut.exists(file: file) == true)

        try sut.delete(file: file)
        #expect(sut.exists(file: file) == false)
    }
}
