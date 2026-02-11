import Foundation

public final class MockLocalJSON: LocalJSONProtocol {
    public nonisolated(unsafe) var mockData: [String: Data] = [:]

    public init() {}

    public func getJSON(from file: String) throws -> Data {
        guard let data = mockData[file] else {
            throw MockLocalJSONError.fileNotFound(file)
        }
        return data
    }

    public func getJSON<T: Decodable>(from file: String, as type: T.Type) throws -> T {
        let data = try getJSON(from: file)
        return try JSONDecoder().decode(T.self, from: data)
    }

    public func writeJSON<T: Encodable>(data: T, to path: String) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let jsonData = try encoder.encode(data)
        mockData[path] = jsonData
    }
}

public enum MockLocalJSONError: Error {
    case fileNotFound(String)
}
