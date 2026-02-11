import Foundation

public final class MockLocalJSON: LocalJSONProtocol, @unchecked Sendable {
    /// Thread-safe via `lock`. All access to `_storage` must go through `withLock`.
    private var _storage: [String: Data] = [:]
    private let lock = NSLock()

    private func withLock<T>(_ body: (inout [String: Data]) throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body(&_storage)
    }

    public var mockData: [String: Data] {
        get { withLock { $0 } }
        set { withLock { $0 = newValue } }
    }

    public init() {}

    public func getJSON(from file: String) throws -> Data {
        guard let data = withLock({ $0[file] }) else {
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
        withLock { $0[path] = jsonData }
    }

    public func exists(file: String) -> Bool {
        withLock { $0[file] != nil }
    }

    public func delete(file: String) throws {
        let existed: Bool = withLock { $0.removeValue(forKey: file) != nil }
        if !existed {
            throw MockLocalJSONError.fileNotFound(file)
        }
    }

    public func listFiles(in directory: String) throws -> [String] {
        withLock { storage in
            storage.keys.filter { key in
                if directory.isEmpty {
                    return !key.contains("/")
                }
                let prefix = directory.hasSuffix("/") ? directory : "\(directory)/"
                guard key.hasPrefix(prefix) else { return false }
                let remainder = String(key.dropFirst(prefix.count))
                return !remainder.contains("/")
            }
            .sorted()
        }
    }
}

public enum MockLocalJSONError: Error {
    case fileNotFound(String)
}
