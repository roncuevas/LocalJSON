import Foundation

public final class LocalJSON: LocalJSONProtocol {
    private var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    public init() {}

    public func getJSON(from file: String) throws -> Data {
        let fileURL = documentsURL.appendingPathComponent(file)
        do {
            return try Data(contentsOf: fileURL)
        } catch {
            throw LocalJSONError.fileNotFound(file)
        }
    }

    public func getJSON<T: Decodable>(from file: String, as type: T.Type) throws -> T {
        let data = try getJSON(from: file)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw LocalJSONError.decodingFailed(file: file, underlying: error)
        }
    }

    public func writeJSON<T: Encodable>(data: T, to path: String) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let jsonData: Data
        do {
            jsonData = try encoder.encode(data)
        } catch {
            throw LocalJSONError.encodingFailed(underlying: error)
        }
        let fileURL = documentsURL.appendingPathComponent(path)
        let directory = fileURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try jsonData.write(to: fileURL)
        } catch {
            throw LocalJSONError.writeFailed(file: path, underlying: error)
        }
    }

    public func exists(file: String) -> Bool {
        let url = documentsURL.appendingPathComponent(file)
        return FileManager.default.fileExists(atPath: url.path)
    }

    public func delete(file: String) throws {
        let url = documentsURL.appendingPathComponent(file)
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            throw LocalJSONError.deleteFailed(file: file, underlying: error)
        }
    }

    public func listFiles(in directory: String) throws -> [String] {
        let base = documentsURL
        let target = directory.isEmpty ? base : base.appendingPathComponent(directory)
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: target, includingPropertiesForKeys: nil)
            return contents
                .filter { $0.pathExtension == "json" }
                .map { directory.isEmpty ? $0.lastPathComponent : "\(directory)/\($0.lastPathComponent)" }
                .sorted()
        } catch {
            throw LocalJSONError.directoryNotFound(directory)
        }
    }
}
