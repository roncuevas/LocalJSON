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

All files are stored in the app's Documents directory. Writes use pretty-printed JSON formatting by default.

### Async/await

Every method on `LocalJSONProtocol` has an async overload that works automatically:

```swift
let user = try await storage.getJSON(from: "user.json", as: User.self)
try await storage.writeJSON(data: user, to: "user.json")
```

### File management

```swift
// Check if a file exists
let exists = storage.exists(file: "user.json")

// Delete a file
try storage.delete(file: "user.json")

// List all JSON files in the root directory
let files = try storage.listFiles()

// List JSON files in a subdirectory
let subFiles = try storage.listFiles(in: "backups")
```

### Subdirectories

Intermediate directories are created automatically on write:

```swift
try storage.writeJSON(data: user, to: "users/profiles/ron.json")
let user = try storage.getJSON(from: "users/profiles/ron.json", as: User.self)
```

### `@JSONStored` property wrapper

Persist properties automatically with `@JSONStored`:

```swift
class Settings {
    @JSONStored("theme.json")
    var theme: Theme?

    @JSONStored("prefs.json", using: CachedLocalJSON(wrapping: LocalJSON()))
    var preferences: Preferences?
}

let settings = Settings()
settings.theme = Theme(name: "dark") // writes to disk
let current = settings.theme         // reads from disk

// Error-handling via projected value
try settings.$theme.save(Theme(name: "light"))
let loaded = try settings.$theme.load()
try settings.$theme.remove()
```

### Custom encoder/decoder

All services accept optional `JSONEncoder` and `JSONDecoder` in their initializers:

```swift
let encoder = JSONEncoder()
encoder.dateEncodingStrategy = .iso8601

let decoder = JSONDecoder()
decoder.dateDecodingStrategy = .iso8601

let storage = LocalJSON(encoder: encoder, decoder: decoder)
let mock = MockLocalJSON(encoder: encoder, decoder: decoder)
let cached = CachedLocalJSON(wrapping: storage, encoder: encoder, decoder: decoder)
```

Defaults: pretty-printed encoder, standard decoder.

### File observation

Observe file changes reactively with `AsyncStream`:

```swift
for await user in storage.changes(to: "user.json", as: User.self, checkEvery: 2) {
    if let user {
        print("User updated: \(user.name)")
    } else {
        print("File deleted or unreadable")
    }
}
```

- Emits the current value immediately
- Polls every `checkEvery` seconds (default: 1)
- Only emits when raw bytes change
- Yields `nil` when the file doesn't exist or can't be decoded
- Cancels cleanly when the task is cancelled
- Works with any `LocalJSONProtocol` conformer

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

### Error handling

`LocalJSON` throws typed `LocalJSONError` values:

```swift
do {
    let user = try storage.getJSON(from: "user.json", as: User.self)
} catch let error as LocalJSONError {
    switch error {
    case .fileNotFound(let file):
        print("Missing: \(file)")
    case .decodingFailed(let file, let underlying):
        print("Bad JSON in \(file): \(underlying)")
    case .encodingFailed(let underlying):
        print("Encode error: \(underlying)")
    case .writeFailed(let file, let underlying):
        print("Write error for \(file): \(underlying)")
    case .deleteFailed(let file, let underlying):
        print("Delete error for \(file): \(underlying)")
    case .directoryNotFound(let dir):
        print("No directory: \(dir)")
    }
}
```

All cases conform to `LocalizedError` with descriptive `errorDescription`. `MockLocalJSON` uses its own `MockLocalJSONError`. `CachedLocalJSON` passes through errors from its wrapped implementation.

## Architecture

```
Sources/LocalJSON/
├── Protocols/
│   └── LocalJSONProtocol.swift        # Protocol + async overloads + file observation
├── Services/
│   ├── LocalJSON.swift                # File system implementation
│   ├── MockLocalJSON.swift            # In-memory implementation for tests
│   └── CachedLocalJSON.swift          # Caching decorator (read cache + write dedup)
├── Models/
│   ├── CachePolicy.swift              # Cache configuration
│   └── LocalJSONError.swift           # Typed error enum
├── PropertyWrappers/
│   └── JSONStored.swift               # @JSONStored property wrapper
└── Extensions/
    └── LocalJSON+Environment.swift    # SwiftUI EnvironmentValues
```

## Running tests

```bash
swift build
swift test
```
