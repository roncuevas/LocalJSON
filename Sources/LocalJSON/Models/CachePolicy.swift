import Foundation

public struct CachePolicy: Sendable {
    public let readCacheEnabled: Bool
    public let writeDedupEnabled: Bool
    public let ttl: TimeInterval?
    public let maxEntries: Int?

    public init(
        readCacheEnabled: Bool = true,
        writeDedupEnabled: Bool = true,
        ttl: TimeInterval? = 300,
        maxEntries: Int? = 100
    ) {
        self.readCacheEnabled = readCacheEnabled
        self.writeDedupEnabled = writeDedupEnabled
        self.ttl = ttl
        self.maxEntries = maxEntries
    }

    public static let disabled = CachePolicy(
        readCacheEnabled: false,
        writeDedupEnabled: false,
        ttl: nil,
        maxEntries: nil
    )
}
