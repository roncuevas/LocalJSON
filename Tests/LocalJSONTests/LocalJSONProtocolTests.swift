import Testing
import Foundation
@testable import LocalJSON

struct LocalJSONProtocolTests {
    @Test func localJSONConformsToProtocol() {
        let instance: any LocalJSONProtocol = LocalJSON()
        #expect(instance is LocalJSON)
    }

    @Test func mockLocalJSONConformsToProtocol() {
        let instance: any LocalJSONProtocol = MockLocalJSON()
        #expect(instance is MockLocalJSON)
    }

    @Test func protocolCanBeUsedForDependencyInjection() throws {
        struct Item: Codable, Equatable {
            let value: String
        }

        func loadItem(using service: any LocalJSONProtocol, file: String) throws -> Item {
            try service.getJSON(from: file, as: Item.self)
        }

        let mock = MockLocalJSON()
        try mock.writeJSON(data: Item(value: "injected"), to: "di.json")

        let result = try loadItem(using: mock, file: "di.json")
        #expect(result.value == "injected")
    }
}
