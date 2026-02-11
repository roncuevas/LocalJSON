import SwiftUI

private struct LocalJSONKey: EnvironmentKey {
    static let defaultValue: any LocalJSONProtocol = MockLocalJSON()
}

public extension EnvironmentValues {
    var localJSON: any LocalJSONProtocol {
        get { self[LocalJSONKey.self] }
        set { self[LocalJSONKey.self] = newValue }
    }
}
