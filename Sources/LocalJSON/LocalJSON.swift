import Foundation

final class LocalJSON {
    static func getJSON(from file: String) -> Data {
        let fileURL = URL(fileURLWithPath: #file).deletingLastPathComponent().appendingPathComponent(file)
        return try! Data(contentsOf: fileURL)
    }

    static func getJSON<T: Decodable>(from file: String, as type: T) throws -> T {
        let fileURL = URL(fileURLWithPath: #file).deletingLastPathComponent().appendingPathComponent(file)
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(T.self, from: data)
    }

    static func writeJSON<T: Encodable>(data: T, to path: String) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let jsonData = try encoder.encode(data)
        let fileURL = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .appendingPathComponent(path)
        try jsonData.write(to: fileURL)
    }
}
