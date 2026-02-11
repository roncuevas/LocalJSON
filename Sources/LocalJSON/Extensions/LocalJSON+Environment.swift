import SwiftUI

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
private struct LocalJSONKey: EnvironmentKey {
    static let defaultValue: any LocalJSONProtocol = MockLocalJSON()
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public extension EnvironmentValues {
    var localJSON: any LocalJSONProtocol {
        get { self[LocalJSONKey.self] }
        set { self[LocalJSONKey.self] = newValue }
    }
}
