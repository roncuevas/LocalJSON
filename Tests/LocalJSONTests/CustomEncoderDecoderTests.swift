import Testing
import Foundation
@testable import LocalJSON

struct CustomEncoderDecoderTests {
    private struct Event: Codable, Equatable, Sendable {
        let name: String
        let date: Date
    }

    // MARK: - MockLocalJSON custom encoder/decoder

    @Test func mockUsesCustomEncoder() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let mock = MockLocalJSON(encoder: encoder, decoder: decoder)
        let event = Event(name: "Launch", date: Date(timeIntervalSince1970: 0))

        try mock.writeJSON(data: event, to: "event.json")
        let raw = try mock.getJSON(from: "event.json")
        let json = String(data: raw, encoding: .utf8)!
        #expect(json.contains("1970-01-01"))
    }

    @Test func mockUsesCustomDecoder() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let mock = MockLocalJSON(encoder: encoder, decoder: decoder)
        let event = Event(name: "Launch", date: Date(timeIntervalSince1970: 0))

        try mock.writeJSON(data: event, to: "event.json")
        let result = try mock.getJSON(from: "event.json", as: Event.self)
        #expect(result == event)
    }

    @Test func mockDefaultEncoderUsesDefaultDateStrategy() throws {
        let mock = MockLocalJSON()
        let event = Event(name: "Test", date: Date(timeIntervalSince1970: 1000))

        try mock.writeJSON(data: event, to: "event.json")
        let raw = try mock.getJSON(from: "event.json")
        let json = String(data: raw, encoding: .utf8)!
        // Default strategy encodes Date as a Double (timeIntervalSinceReferenceDate)
        #expect(!json.contains("1970"))
    }

    // MARK: - LocalJSON custom encoder/decoder

    @Test func localJSONUsesCustomEncoder() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let sut = LocalJSON(encoder: encoder, decoder: decoder)
        let file = "custom-enc-\(UUID().uuidString).json"
        let event = Event(name: "Launch", date: Date(timeIntervalSince1970: 0))

        try sut.writeJSON(data: event, to: file)
        defer { try? sut.delete(file: file) }

        let raw = try sut.getJSON(from: file)
        let json = String(data: raw, encoding: .utf8)!
        #expect(json.contains("1970-01-01"))

        let result = try sut.getJSON(from: file, as: Event.self)
        #expect(result == event)
    }

    @Test func localJSONDefaultEncoderIsPrettyPrinted() throws {
        let sut = LocalJSON()
        let file = "pretty-\(UUID().uuidString).json"

        try sut.writeJSON(data: ["key": "value"], to: file)
        defer { try? sut.delete(file: file) }

        let raw = try sut.getJSON(from: file)
        let json = String(data: raw, encoding: .utf8)!
        #expect(json.contains("\n"))
    }

    // MARK: - CachedLocalJSON custom encoder/decoder

    @Test func cachedUsesCustomEncoderDecoder() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let mock = MockLocalJSON(encoder: encoder, decoder: decoder)
        let cached = CachedLocalJSON(wrapping: mock, encoder: encoder, decoder: decoder)
        let event = Event(name: "Cached", date: Date(timeIntervalSince1970: 0))

        try cached.writeJSON(data: event, to: "event.json")
        let result = try cached.getJSON(from: "event.json", as: Event.self)
        #expect(result == event)

        let raw = try cached.getJSON(from: "event.json")
        let json = String(data: raw, encoding: .utf8)!
        #expect(json.contains("1970-01-01"))
    }

    @Test func cachedDedupUsesOwnEncoder() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let mock = MockLocalJSON(encoder: encoder, decoder: decoder)
        let cached = CachedLocalJSON(wrapping: mock, encoder: encoder, decoder: decoder)
        let event = Event(name: "Dedup", date: Date(timeIntervalSince1970: 0))

        try cached.writeJSON(data: event, to: "event.json")
        try cached.writeJSON(data: event, to: "event.json") // should be deduped

        let result = try cached.getJSON(from: "event.json", as: Event.self)
        #expect(result == event)
    }

    // MARK: - Encoder/decoder independence

    @Test func differentEncodersBetweenServicesWorkIndependently() throws {
        let iso8601Encoder = JSONEncoder()
        iso8601Encoder.dateEncodingStrategy = .iso8601
        let iso8601Decoder = JSONDecoder()
        iso8601Decoder.dateDecodingStrategy = .iso8601

        let mock1 = MockLocalJSON(encoder: iso8601Encoder, decoder: iso8601Decoder)
        let mock2 = MockLocalJSON() // default encoder

        let event = Event(name: "Test", date: Date(timeIntervalSince1970: 0))

        try mock1.writeJSON(data: event, to: "event.json")
        try mock2.writeJSON(data: event, to: "event.json")

        let raw1 = try mock1.getJSON(from: "event.json")
        let raw2 = try mock2.getJSON(from: "event.json")
        let json1 = String(data: raw1, encoding: .utf8)!
        let json2 = String(data: raw2, encoding: .utf8)!

        #expect(json1.contains("1970-01-01"))
        #expect(!json2.contains("1970-01-01"))
    }
}
