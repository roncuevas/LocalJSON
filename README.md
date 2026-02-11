# LocalJSON

A lightweight Swift package for reading and writing JSON files to the Documents directory. Type-safe with `Codable`, protocol-driven for easy testing, and thread-safe for concurrent access.

## Requirements

- Swift 6.0+
- iOS 13.0+ / macOS 10.15+ / tvOS 13.0+ / watchOS 6.0+
- No external dependencies

## Installation

Add LocalJSON to your project via Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/roncuevas/LocalJSON.git", from: "1.0.0")
]
```

Or in Xcode: **File > Add Package Dependencies** and paste the repository URL.

## Usage

### Basic read and write

```swift
import LocalJSON

struct User: Codable {
    let name: String
    let age: Int
}

let storage = LocalJSON()

// Write
try storage.writeJSON(data: User(name: "Ron", age: 30), to: "user.json")

// Read (type-safe)
let user = try storage.getJSON(from: "user.json", as: User.self)

// Read (raw Data)
let data = try storage.getJSON(from: "user.json")
```

All files are stored in the app's Documents directory. Writes use pretty-printed JSON formatting.

### Async/await

Every method on `LocalJSONProtocol` has an async overload that works automatically:

```swift
let user = try await storage.getJSON(from: "user.json", as: User.self)
try await storage.writeJSON(data: user, to: "user.json")
```

### Dependency injection with the protocol

All implementations conform to `LocalJSONProtocol`, so you can swap them in your app or tests:

```swift
class UserRepository {
    private let storage: any LocalJSONProtocol

    init(storage: any LocalJSONProtocol) {
        self.storage = storage
    }

    func loadUser() throws -> User {
        try storage.getJSON(from: "user.json", as: User.self)
    }
}

// Production
let repo = UserRepository(storage: LocalJSON())

// Tests
let repo = UserRepository(storage: MockLocalJSON())
```

### SwiftUI Environment

LocalJSON includes a SwiftUI `EnvironmentValues` extension for injecting the storage:

```swift
@Environment(\.localJSON) private var storage

// Override in a parent view
ContentView()
    .environment(\.localJSON, LocalJSON())
```

The default value is `MockLocalJSON()`, so previews work without file system access.

### MockLocalJSON

An in-memory implementation for unit tests. Thread-safe, no disk I/O:

```swift
let mock = MockLocalJSON()

try mock.writeJSON(data: User(name: "Test", age: 25), to: "user.json")
let user = try mock.getJSON(from: "user.json", as: User.self)

// Access the underlying storage directly
mock.mockData["user.json"] = someRawData
```

### CachedLocalJSON

A caching decorator that wraps any `LocalJSONProtocol` implementation. Reduces redundant disk reads and skips identical writes:

```swift
let cached = CachedLocalJSON(wrapping: LocalJSON())

// First read hits disk, subsequent reads return from memory
let user = try cached.getJSON(from: "user.json", as: User.self)
let same = try cached.getJSON(from: "user.json", as: User.self) // cache hit

// Writing identical data is skipped (no disk I/O)
try cached.writeJSON(data: user, to: "user.json") // writes to disk
try cached.writeJSON(data: user, to: "user.json") // skipped, data unchanged
```

#### Cache policy

Configure behavior with `CachePolicy`:

```swift
// Default: read cache + write dedup, 5 min TTL, max 100 entries
let cached = CachedLocalJSON(wrapping: LocalJSON())

// Custom policy
let policy = CachePolicy(
    readCacheEnabled: true,     // Return cached data on reads (default: true)
    writeDedupEnabled: true,    // Skip identical writes (default: true)
    ttl: 600,                   // Cache entries expire after 10 minutes (default: 300)
    maxEntries: 50              // Keep at most 50 entries in cache (default: 100)
)
let cached = CachedLocalJSON(wrapping: LocalJSON(), policy: policy)

// Disable caching entirely (pure pass-through)
let passthrough = CachedLocalJSON(wrapping: LocalJSON(), policy: .disabled)
```

| Parameter | Default | Description |
|---|---|---|
| `readCacheEnabled` | `true` | Return data from memory on cache hits |
| `writeDedupEnabled` | `true` | Skip writes when data is identical to cached |
| `ttl` | `300` (5 min) | Seconds before a cache entry expires. `nil` = no expiration |
| `maxEntries` | `100` | Maximum cached files. `nil` = unlimited. Uses LRU eviction |

#### Manual cache control

```swift
// Invalidate a single file (next read will hit disk)
cached.invalidate(file: "user.json")

// Clear the entire cache
cached.clearCache()
```

#### Combining with dependency injection

Since `CachedLocalJSON` conforms to `LocalJSONProtocol`, it works anywhere the protocol is expected:

```swift
// Production: cached file system
let storage: any LocalJSONProtocol = CachedLocalJSON(wrapping: LocalJSON())

// Tests: cached mock (useful for verifying dedup behavior)
let storage: any LocalJSONProtocol = CachedLocalJSON(wrapping: MockLocalJSON())

// SwiftUI environment
ContentView()
    .environment(\.localJSON, CachedLocalJSON(wrapping: LocalJSON()))
```

## Architecture

```
Sources/LocalJSON/
├── Protocols/
│   └── LocalJSONProtocol.swift        # Protocol + async overloads
├── Services/
│   ├── LocalJSON.swift                # File system implementation
│   ├── MockLocalJSON.swift            # In-memory implementation for tests
│   └── CachedLocalJSON.swift          # Caching decorator (read cache + write dedup)
├── Models/
│   └── CachePolicy.swift             # Cache configuration
└── Extensions/
    └── LocalJSON+Environment.swift    # SwiftUI EnvironmentValues
```

## Running tests

```bash
swift build
swift test
```
