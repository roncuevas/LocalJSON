import Testing
import Foundation
@testable import LocalJSON

struct MockLocalJSONTests {
    private struct User: Codable, Equatable {
        let name: String
        let age: Int
    }

    @Test func writeAndReadData() throws {
        let sut = MockLocalJSON()
        let user = User(name: "Ron", age: 30)

        try sut.writeJSON(data: user, to: "user.json")
        let result = try sut.getJSON(from: "user.json", as: User.self)

        #expect(result == user)
    }

    @Test func getJSONReturnsRawData() throws {
        let sut = MockLocalJSON()
        let user = User(name: "Ana", age: 25)

        try sut.writeJSON(data: user, to: "ana.json")
        let data = try sut.getJSON(from: "ana.json")
        let decoded = try JSONDecoder().decode(User.self, from: data)

        #expect(decoded == user)
    }

    @Test func getJSONThrowsWhenFileNotFound() {
        let sut = MockLocalJSON()

        #expect(throws: MockLocalJSONError.self) {
            _ = try sut.getJSON(from: "nonexistent.json")
        }
    }

    @Test func getJSONDecodableThrowsWhenFileNotFound() {
        let sut = MockLocalJSON()

        #expect(throws: MockLocalJSONError.self) {
            _ = try sut.getJSON(from: "missing.json", as: User.self)
        }
    }

    @Test func writeOverwritesExistingFile() throws {
        let sut = MockLocalJSON()

        try sut.writeJSON(data: User(name: "V1", age: 1), to: "file.json")
        try sut.writeJSON(data: User(name: "V2", age: 2), to: "file.json")

        let result = try sut.getJSON(from: "file.json", as: User.self)
        #expect(result.name == "V2")
        #expect(result.age == 2)
    }

    @Test func multipleFilesAreIsolated() throws {
        let sut = MockLocalJSON()

        try sut.writeJSON(data: User(name: "A", age: 1), to: "a.json")
        try sut.writeJSON(data: User(name: "B", age: 2), to: "b.json")

        let a = try sut.getJSON(from: "a.json", as: User.self)
        let b = try sut.getJSON(from: "b.json", as: User.self)

        #expect(a.name == "A")
        #expect(b.name == "B")
    }
}
