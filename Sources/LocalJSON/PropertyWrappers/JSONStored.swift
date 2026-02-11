import Foundation

@propertyWrapper
public struct JSONStored<Value: Codable & Sendable>: Sendable {
    private let file: String
    private let storage: any LocalJSONProtocol

    public init(_ file: String, using storage: any LocalJSONProtocol = LocalJSON()) {
        self.file = file
        self.storage = storage
    }

    public var wrappedValue: Value? {
        get { try? storage.getJSON(from: file, as: Value.self) }
        nonmutating set {
            if let newValue {
                try? storage.writeJSON(data: newValue, to: file)
            } else {
                try? storage.delete(file: file)
            }
        }
    }

    public var projectedValue: JSONStored<Value> { self }

    public func load() throws -> Value {
        try storage.getJSON(from: file, as: Value.self)
    }

    public func save(_ value: Value) throws {
        try storage.writeJSON(data: value, to: file)
    }

    public func remove() throws {
        try storage.delete(file: file)
    }
}
