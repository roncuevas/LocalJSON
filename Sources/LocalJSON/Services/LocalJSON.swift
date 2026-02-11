import Foundation

public final class LocalJSON: LocalJSONProtocol {
    public init() {}

    public func getJSON(from file: String) throws -> Data {
        let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(file)
        return try Data(contentsOf: fileURL)
    }

    public func getJSON<T: Decodable>(from file: String, as type: T.Type) throws -> T {
        let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(file)
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(T.self, from: data)
    }

    public func writeJSON<T: Encodable>(data: T, to path: String) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let jsonData = try encoder.encode(data)
        let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(path)
        try jsonData.write(to: fileURL)
    }
}
