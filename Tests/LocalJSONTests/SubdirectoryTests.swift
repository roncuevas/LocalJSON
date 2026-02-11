import Testing
import Foundation
@testable import LocalJSON

struct SubdirectoryTests {
    private struct Item: Codable, Equatable {
        let id: Int
        let value: String
    }

    private let sut = LocalJSON()

    @Test func writeCreatesIntermediateDirectories() throws {
        let file = "sub_\(UUID().uuidString)/file.json"
        defer { cleanup(file) }

        try sut.writeJSON(data: Item(id: 1, value: "a"), to: file)
        #expect(sut.exists(file: file) == true)
    }

    @Test func writeAndReadFromSubdirectory() throws {
        let dir = "users_\(UUID().uuidString)"
        let file = "\(dir)/ron.json"
        defer { cleanup(file) }

        let item = Item(id: 1, value: "ron")
        try sut.writeJSON(data: item, to: file)
        let result = try sut.getJSON(from: file, as: Item.self)
        #expect(result == item)
    }

    @Test func nestedSubdirectories() throws {
        let dir = "a_\(UUID().uuidString)"
        let file = "\(dir)/b/c/file.json"
        defer { cleanupDirectory(dir) }

        try sut.writeJSON(data: Item(id: 1, value: "deep"), to: file)
        let result = try sut.getJSON(from: file, as: Item.self)
        #expect(result == Item(id: 1, value: "deep"))
    }

    @Test func listFilesInSubdirectory() throws {
        let dir = "list_\(UUID().uuidString)"
        defer { cleanupDirectory(dir) }

        try sut.writeJSON(data: Item(id: 1, value: "a"), to: "\(dir)/a.json")
        try sut.writeJSON(data: Item(id: 2, value: "b"), to: "\(dir)/b.json")

        let files = try sut.listFiles(in: dir)
        #expect(files.count == 2)
        #expect(files.contains("\(dir)/a.json"))
        #expect(files.contains("\(dir)/b.json"))
    }

    @Test func existsInSubdirectory() throws {
        let dir = "exists_\(UUID().uuidString)"
        let file = "\(dir)/item.json"
        defer { cleanup(file) }

        #expect(sut.exists(file: file) == false)
        try sut.writeJSON(data: Item(id: 1, value: "a"), to: file)
        #expect(sut.exists(file: file) == true)
    }

    @Test func deleteFromSubdirectory() throws {
        let dir = "del_\(UUID().uuidString)"
        let file = "\(dir)/item.json"
        defer { cleanupDirectory(dir) }

        try sut.writeJSON(data: Item(id: 1, value: "a"), to: file)
        try sut.delete(file: file)
        #expect(sut.exists(file: file) == false)
    }

    // MARK: - Helpers

    private func cleanup(_ file: String) {
        let parts = file.split(separator: "/")
        if parts.count > 1 {
            cleanupDirectory(String(parts[0]))
        } else {
            try? sut.delete(file: file)
        }
    }

    private func cleanupDirectory(_ directory: String) {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(directory)
        try? FileManager.default.removeItem(at: url)
    }
}
