import Testing
import Foundation
@testable import LocalJSON

struct LocalJSONErrorTests {
    // MARK: - Error descriptions

    @Test func fileNotFoundHasDescription() {
        let error = LocalJSONError.fileNotFound("missing.json")
        #expect(error.errorDescription?.contains("missing.json") == true)
    }

    @Test func decodingFailedHasDescription() {
        let underlying = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "bad format"])
        let error = LocalJSONError.decodingFailed(file: "bad.json", underlying: underlying)
        #expect(error.errorDescription?.contains("bad.json") == true)
        #expect(error.errorDescription?.contains("bad format") == true)
    }

    @Test func encodingFailedHasDescription() {
        let underlying = NSError(domain: "test", code: 2, userInfo: [NSLocalizedDescriptionKey: "cannot encode"])
        let error = LocalJSONError.encodingFailed(underlying: underlying)
        #expect(error.errorDescription?.contains("cannot encode") == true)
    }

    @Test func writeFailedHasDescription() {
        let underlying = NSError(domain: "test", code: 3, userInfo: [NSLocalizedDescriptionKey: "disk full"])
        let error = LocalJSONError.writeFailed(file: "data.json", underlying: underlying)
        #expect(error.errorDescription?.contains("data.json") == true)
        #expect(error.errorDescription?.contains("disk full") == true)
    }

    @Test func deleteFailedHasDescription() {
        let underlying = NSError(domain: "test", code: 4, userInfo: [NSLocalizedDescriptionKey: "no permission"])
        let error = LocalJSONError.deleteFailed(file: "locked.json", underlying: underlying)
        #expect(error.errorDescription?.contains("locked.json") == true)
        #expect(error.errorDescription?.contains("no permission") == true)
    }

    @Test func directoryNotFoundHasDescription() {
        let error = LocalJSONError.directoryNotFound("subdir")
        #expect(error.errorDescription?.contains("subdir") == true)
    }

    // MARK: - LocalJSON throws typed errors

    @Test func getJSONThrowsFileNotFound() {
        let sut = LocalJSON()
        #expect(throws: LocalJSONError.self) {
            _ = try sut.getJSON(from: "nonexistent-\(UUID().uuidString).json")
        }
    }

    @Test func getJSONTypedThrowsFileNotFound() {
        let sut = LocalJSON()
        #expect(throws: LocalJSONError.self) {
            _ = try sut.getJSON(from: "nonexistent-\(UUID().uuidString).json", as: [String].self)
        }
    }

    @Test func deleteThrowsDeleteFailed() {
        let sut = LocalJSON()
        #expect(throws: LocalJSONError.self) {
            try sut.delete(file: "nonexistent-\(UUID().uuidString).json")
        }
    }

    @Test func listFilesThrowsDirectoryNotFound() {
        let sut = LocalJSON()
        #expect(throws: LocalJSONError.self) {
            _ = try sut.listFiles(in: "nonexistent-dir-\(UUID().uuidString)")
        }
    }

    // MARK: - Error conforms to LocalizedError

    @Test func conformsToLocalizedError() {
        let error: LocalizedError = LocalJSONError.fileNotFound("test.json")
        #expect(error.errorDescription != nil)
    }

    // MARK: - MockLocalJSON still uses its own error

    @Test func mockStillThrowsMockError() {
        let mock = MockLocalJSON()
        #expect(throws: MockLocalJSONError.self) {
            _ = try mock.getJSON(from: "nope.json")
        }
    }

    // MARK: - CachedLocalJSON passes through wrapped errors

    @Test func cachedPassesThroughMockError() {
        let mock = MockLocalJSON()
        let cached = CachedLocalJSON(wrapping: mock)
        #expect(throws: MockLocalJSONError.self) {
            _ = try cached.getJSON(from: "nope.json")
        }
    }

    @Test func cachedPassesThroughLocalJSONError() throws {
        let real = LocalJSON()
        let cached = CachedLocalJSON(wrapping: real)
        #expect(throws: LocalJSONError.self) {
            _ = try cached.getJSON(from: "nonexistent-\(UUID().uuidString).json")
        }
    }
}
