import Foundation

public protocol LocalJSONProtocol: Sendable {
    func getJSON(from file: String) throws -> Data
    func getJSON<T: Decodable>(from file: String, as type: T.Type) throws -> T
    func writeJSON<T: Encodable>(data: T, to path: String) throws
}
