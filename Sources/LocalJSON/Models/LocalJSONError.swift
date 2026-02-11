import Foundation

public enum LocalJSONError: Error, LocalizedError {
    case fileNotFound(String)
    case decodingFailed(file: String, underlying: Error)
    case encodingFailed(underlying: Error)
    case writeFailed(file: String, underlying: Error)
    case deleteFailed(file: String, underlying: Error)
    case directoryNotFound(String)

    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let file):
            return "File not found: \(file)"
        case .decodingFailed(let file, let underlying):
            return "Failed to decode \(file): \(underlying.localizedDescription)"
        case .encodingFailed(let underlying):
            return "Failed to encode data: \(underlying.localizedDescription)"
        case .writeFailed(let file, let underlying):
            return "Failed to write \(file): \(underlying.localizedDescription)"
        case .deleteFailed(let file, let underlying):
            return "Failed to delete \(file): \(underlying.localizedDescription)"
        case .directoryNotFound(let directory):
            return "Directory not found: \(directory)"
        }
    }
}
