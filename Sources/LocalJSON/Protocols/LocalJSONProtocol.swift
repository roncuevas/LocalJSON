import Foundation

public protocol LocalJSONProtocol: Sendable {
    func getJSON(from file: String) throws -> Data
    func getJSON<T: Decodable>(from file: String, as type: T.Type) throws -> T
    func writeJSON<T: Encodable>(data: T, to path: String) throws
    func exists(file: String) -> Bool
    func delete(file: String) throws
    func listFiles(in directory: String) throws -> [String]
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

    func delete(file: String) async throws {
        let sync: (String) throws -> Void = self.delete(file:)
        try sync(file)
    }

    func listFiles(in directory: String) async throws -> [String] {
        let sync: (String) throws -> [String] = self.listFiles(in:)
        return try sync(directory)
    }
}

// MARK: - Convenience overloads

public extension LocalJSONProtocol {
    func listFiles() throws -> [String] {
        try listFiles(in: "")
    }

    func listFiles() async throws -> [String] {
        let sync: () throws -> [String] = self.listFiles
        return try sync()
    }
}

// MARK: - File observation

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public extension LocalJSONProtocol {
    func changes<T: Decodable & Sendable>(
        to file: String,
        as type: T.Type,
        checkEvery interval: TimeInterval = 1
    ) -> AsyncStream<T?> {
        let storage: any LocalJSONProtocol = self

        return AsyncStream { continuation in
            let task = Task { @Sendable in
                var isFirstPoll = true
                var lastBytes: Data?
                let readRaw = { (f: String) -> Data? in try? storage.getJSON(from: f) }
                let decode = { (f: String) -> T? in try? storage.getJSON(from: f, as: type) }

                while !Task.isCancelled {
                    let currentBytes = readRaw(file)

                    if isFirstPoll || currentBytes != lastBytes {
                        isFirstPoll = false
                        lastBytes = currentBytes
                        if currentBytes != nil {
                            continuation.yield(decode(file))
                        } else {
                            continuation.yield(nil)
                        }
                    }

                    try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                }

                continuation.finish()
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
}
