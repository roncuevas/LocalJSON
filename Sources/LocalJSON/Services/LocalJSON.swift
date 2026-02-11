import Foundation

public final class LocalJSON: LocalJSONProtocol {
    private var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    public init() {}

    public func getJSON(from file: String) throws -> Data {
        let fileURL = documentsURL.appendingPathComponent(file)
        return try Data(contentsOf: fileURL)
    }

    public func getJSON<T: Decodable>(from file: String, as type: T.Type) throws -> T {
        let fileURL = documentsURL.appendingPathComponent(file)
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(T.self, from: data)
    }

    public func writeJSON<T: Encodable>(data: T, to path: String) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let jsonData = try encoder.encode(data)
        let fileURL = documentsURL.appendingPathComponent(path)
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try jsonData.write(to: fileURL)
    }

    public func exists(file: String) -> Bool {
        let url = documentsURL.appendingPathComponent(file)
        return FileManager.default.fileExists(atPath: url.path)
    }

    public func delete(file: String) throws {
        let url = documentsURL.appendingPathComponent(file)
        try FileManager.default.removeItem(at: url)
    }

    public func listFiles(in directory: String) throws -> [String] {
        let base = documentsURL
        let target = directory.isEmpty ? base : base.appendingPathComponent(directory)
        let contents = try FileManager.default.contentsOfDirectory(at: target, includingPropertiesForKeys: nil)
        return contents
            .filter { $0.pathExtension == "json" }
            .map { directory.isEmpty ? $0.lastPathComponent : "\(directory)/\($0.lastPathComponent)" }
            .sorted()
    }
}
