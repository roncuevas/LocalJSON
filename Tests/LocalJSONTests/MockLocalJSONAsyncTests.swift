import Testing
import Foundation
@testable import LocalJSON

struct MockLocalJSONAsyncTests {
    private struct User: Codable, Equatable, Sendable {
        let name: String
        let age: Int
    }

    /// Call through protocol type to ensure async overloads are dispatched.
    private func makeSUT() -> any LocalJSONProtocol {
        MockLocalJSON()
    }

    @Test func asyncWriteAndRead() async throws {
        let sut = makeSUT()
        let user = User(name: "Ron", age: 30)

        try await sut.writeJSON(data: user, to: "user.json")
        let result: User = try await sut.getJSON(from: "user.json", as: User.self)

        #expect(result == user)
    }

    @Test func asyncGetJSONReturnsRawData() async throws {
        let sut = makeSUT()
        let user = User(name: "Ana", age: 25)

        try await sut.writeJSON(data: user, to: "ana.json")
        let data: Data = try await sut.getJSON(from: "ana.json")
        let decoded = try JSONDecoder().decode(User.self, from: data)

        #expect(decoded == user)
    }

    @Test func asyncGetJSONThrowsWhenFileNotFound() async {
        let sut = makeSUT()

        await #expect(throws: MockLocalJSONError.self) {
            let _: Data = try await sut.getJSON(from: "nonexistent.json")
        }
    }

    @Test func asyncGetJSONDecodableThrowsWhenFileNotFound() async {
        let sut = makeSUT()

        await #expect(throws: MockLocalJSONError.self) {
            _ = try await sut.getJSON(from: "missing.json", as: User.self)
        }
    }

    @Test func asyncWriteOverwritesExistingFile() async throws {
        let sut = makeSUT()

        try await sut.writeJSON(data: User(name: "V1", age: 1), to: "file.json")
        try await sut.writeJSON(data: User(name: "V2", age: 2), to: "file.json")

        let result: User = try await sut.getJSON(from: "file.json", as: User.self)
        #expect(result.name == "V2")
        #expect(result.age == 2)
    }

    @Test func asyncMultipleFilesAreIsolated() async throws {
        let sut = makeSUT()

        try await sut.writeJSON(data: User(name: "A", age: 1), to: "a.json")
        try await sut.writeJSON(data: User(name: "B", age: 2), to: "b.json")

        let a: User = try await sut.getJSON(from: "a.json", as: User.self)
        let b: User = try await sut.getJSON(from: "b.json", as: User.self)

        #expect(a.name == "A")
        #expect(b.name == "B")
    }
}
