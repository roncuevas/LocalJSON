import Foundation

public protocol LocalJSONProtocol: Sendable {
    func getJSON(from file: String) throws -> Data
    func getJSON<T: Decodable>(from file: String, as type: T.Type) throws -> T
    func writeJSON<T: Encodable>(data: T, to path: String) throws
}

// MARK: - Async overloads
// Default async implementations run on the global concurrent executor (nonisolated),
// so callers from @MainActor contexts won't block the main thread.

public extension LocalJSONProtocol {
    func getJSON(from file: String) async throws -> Data {
        let sync: (String) throws -> Data = self.getJSON(from:)
        return try sync(file)
    }

    func getJSON<T: Decodable>(from file: String, as type: T.Type) async throws -> T {
        let sync: (String, T.Type) throws -> T = self.getJSON(from:as:)
        return try sync(file, type)
    }

    func writeJSON<T: Encodable>(data: T, to path: String) async throws {
        let sync: (T, String) throws -> Void = self.writeJSON(data:to:)
        try sync(data, path)
    }
}
