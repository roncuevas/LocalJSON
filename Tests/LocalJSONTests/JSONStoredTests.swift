import Testing
import Foundation
@testable import LocalJSON

struct JSONStoredTests {
    private struct User: Codable, Equatable, Sendable {
        let name: String
        let age: Int
    }

    @Test func readReturnsNilWhenFileDoesNotExist() {
        let mock = MockLocalJSON()
        @JSONStored("user.json", using: mock) var user: User?
        #expect(user == nil)
    }

    @Test func writeAndReadValue() throws {
        let mock = MockLocalJSON()
        @JSONStored("user.json", using: mock) var user: User?

        user = User(name: "Ron", age: 30)
        #expect(user == User(name: "Ron", age: 30))
    }

    @Test func setNilDeletesFile() throws {
        let mock = MockLocalJSON()
        @JSONStored("user.json", using: mock) var user: User?

        user = User(name: "Ron", age: 30)
        #expect(mock.exists(file: "user.json") == true)

        user = nil
        #expect(mock.exists(file: "user.json") == false)
    }

    @Test func overwriteUpdatesValue() throws {
        let mock = MockLocalJSON()
        @JSONStored("user.json", using: mock) var user: User?

        user = User(name: "V1", age: 1)
        user = User(name: "V2", age: 2)
        #expect(user == User(name: "V2", age: 2))
    }

    @Test func projectedValueLoad() throws {
        let mock = MockLocalJSON()
        @JSONStored("user.json", using: mock) var user: User?

        user = User(name: "Ron", age: 30)
        let loaded = try $user.load()
        #expect(loaded == User(name: "Ron", age: 30))
    }

    @Test func projectedValueLoadThrowsForMissingFile() {
        let mock = MockLocalJSON()
        @JSONStored("user.json", using: mock) var user: User?
        _ = user // silence unused warning

        #expect(throws: (any Error).self) {
            _ = try $user.load()
        }
    }

    @Test func projectedValueSaveAndLoad() throws {
        let mock = MockLocalJSON()
        @JSONStored("user.json", using: mock) var user: User?

        try $user.save(User(name: "Ron", age: 30))
        let loaded = try $user.load()
        #expect(loaded == User(name: "Ron", age: 30))
    }

    @Test func projectedValueRemove() throws {
        let mock = MockLocalJSON()
        @JSONStored("user.json", using: mock) var user: User?

        user = User(name: "Ron", age: 30)
        try $user.remove()
        #expect(mock.exists(file: "user.json") == false)
    }
}
