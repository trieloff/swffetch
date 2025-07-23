# SwiftFFetch

[![96% Vibe_Coded](https://img.shields.io/badge/96%25-Vibe_Coded-ff69b4?style=for-the-badge&logo=zedindustries&logoColor=white)](https://github.com/trieloff/vibe-coded-badge-action)

[![codecov](https://img.shields.io/codecov/c/github/trieloff/swffetch?token=SROMISB0K5&style=for-the-badge&logo=codecov&logoColor=white)](https://codecov.io/gh/trieloff/swffetch)
[![Build Status](https://img.shields.io/github/actions/workflow/status/trieloff/swffetch/test.yaml?style=for-the-badge&logo=github)](https://github.com/trieloff/swffetch/actions)
[![Swift 5.9+](https://img.shields.io/badge/Swift-5.9%2B-orange?style=for-the-badge&logo=swift&logoColor=white)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-iOS%2015%2B%20%7C%20macOS%2012%2B%20%7C%20tvOS%2015%2B%20%7C%20watchOS%208%2B-lightgrey?style=for-the-badge)](https://developer.apple.com)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue?style=for-the-badge)](LICENSE)
[![SPM](https://img.shields.io/badge/SPM-Compatible-brightgreen?style=for-the-badge&logo=swift&logoColor=white)](https://swift.org/package-manager)

SwiftFFetch is a Swift library for fetching and processing content from AEM (.live) Content APIs and similar JSON-based endpoints. It is designed for composable applications, making it easy to retrieve, paginate, and process content in a Swift-native way.

## Features

- **Swift-native API**: Designed for idiomatic use in Swift projects.
- **Async/Await Support**: Uses Swift concurrency for efficient, modern code.
- **Pagination**: Handles paginated endpoints seamlessly.
- **Composable**: Chainable methods for mapping, filtering, and transforming content.
- **HTTP Caching**: Intelligent caching with respect for HTTP cache control headers.
- **Sheet Selection**: Access specific sheets in multi-sheet JSON resources.
- **Extensible**: Easily integrate with your own models and workflows.

## Installation

Add SwiftFFetch to your `Package.swift` dependencies:

```swift
.package(url: "https://github.com/your-org/swffetch.git", from: "1.0.0")
```

Then add `"SwiftFFetch"` to your target dependencies.

## Usage

### Fetch Entries from an Index

```swift
import SwiftFFetch

let entries = FFetch(url: "https://example.com/query-index.json")
for try await entry in entries {
    print(entry["title"] as? String ?? "")
}
```

### Get the First Entry

```swift
let firstEntry = try await FFetch(url: "https://example.com/query-index.json").first()
print(firstEntry?["title"] as? String ?? "")
```

### Get All Entries as an Array

```swift
let allEntries = try await FFetch(url: "https://example.com/query-index.json").all()
print("Total entries: \(allEntries.count)")
```

## HTTP Caching

SwiftFFetch includes comprehensive HTTP caching support that respects server cache control headers by default and allows for custom cache configurations.

### Default Caching Behavior

By default, SwiftFFetch uses a shared memory cache and respects HTTP cache control headers:

```swift
// First request fetches from server
let entries1 = try await FFetch(url: "https://example.com/api/data.json").all()

// Second request uses cache if server sent appropriate cache headers
let entries2 = try await FFetch(url: "https://example.com/api/data.json").all()
```

### Cache Configuration

Use the `.cache()` method to configure caching behavior:

```swift
// Always fetch fresh data (bypass cache)
let freshData = try await FFetch(url: "https://example.com/api/data.json")
    .cache(.noCache)
    .all()

// Only use cached data (won't make network request)
let cachedData = try await FFetch(url: "https://example.com/api/data.json")
    .cache(.cacheOnly)
    .all()

// Use cache if available, otherwise load from network
let data = try await FFetch(url: "https://example.com/api/data.json")
    .cache(.cacheElseLoad)
    .all()
```

### Custom Cache Configuration

Create your own cache with specific memory and disk limits:

```swift
let customCache = URLCache(
    memoryCapacity: 10 * 1024 * 1024,  // 10MB
    diskCapacity: 50 * 1024 * 1024     // 50MB
)

let customConfig = FFetchCacheConfig(
    policy: .useProtocolCachePolicy,
    cache: customCache,
    maxAge: 3600  // Cache for 1 hour regardless of server headers
)

let data = try await FFetch(url: "https://example.com/api/data.json")
    .cache(customConfig)
    .all()
```

### Cache Sharing

The cache is reusable between multiple FFetch calls and can be shared with other HTTP requests:

```swift
// Create a shared cache for your application
let appCache = URLCache(memoryCapacity: 20 * 1024 * 1024, diskCapacity: 100 * 1024 * 1024)
let config = FFetchCacheConfig(cache: appCache)

// Use with FFetch
let ffetchData = try await FFetch(url: "https://api.example.com/data.json")
    .cache(config)
    .all()

// Use the same cache with URLSession
let sessionConfig = URLSessionConfiguration.default
sessionConfig.urlCache = appCache
let session = URLSession(configuration: sessionConfig)
```

### Backward Compatibility

Legacy cache methods are still supported:

```swift
// Legacy method - maps to .cache(.noCache)
let freshData = try await FFetch(url: "https://example.com/api/data.json")
    .reloadCache()
    .all()

// Legacy method with parameter
let data = try await FFetch(url: "https://example.com/api/data.json")
    .withCacheReload(false)  // Uses default cache behavior
    .all()
```

## Advanced Usage

```swift
let allEntries = try await FFetch(url: "https://example.com/query-index.json").all()
allEntries.forEach { entry in
    print(entry)
}
```

### Map and Filter Entries

```swift
let filteredTitles = FFetch(url: "https://example.com/query-index.json")
    .map { $0["title"] as? String }
    .filter { $0?.contains("Swift") == true }

for try await title in filteredTitles {
    print(title ?? "")
}
```

### Control Pagination with `chunks` and `limit`

```swift
let limitedEntries = FFetch(url: "https://example.com/query-index.json")
    .chunks(100)
    .limit(5)

for try await entry in limitedEntries {
    print(entry)
}
```

### Access a Specific Sheet

```swift
let productEntries = FFetch(url: "https://example.com/query-index.json")
    .sheet("products")

for try await entry in productEntries {
    print(entry["sku"] as? String ?? "")
}
```

### Document Following with Security

SwiftFFetch provides a `follow()` method to fetch HTML documents referenced in your data. For security, document following is restricted to the same hostname as your initial request by default.

```swift
// Basic document following (same hostname only)
let entriesWithDocs = try await FFetch(url: "https://example.com/query-index.json")
    .follow("path", as: "document")  // follows URLs in 'path' field
    .all()

// The 'document' field will contain parsed HTML Document objects
for entry in entriesWithDocs {
    if let doc = entry["document"] as? Document {
        print(doc.title())
    }
}
```

#### Allowing Additional Hostnames

To allow document following to other hostnames, use the `allow()` method:

```swift
// Allow specific hostname
let entries = try await FFetch(url: "https://example.com/query-index.json")
    .allow("trusted.com")
    .follow("path", as: "document")
    .all()

// Allow multiple hostnames
let entries = try await FFetch(url: "https://example.com/query-index.json")
    .allow(["trusted.com", "api.example.com"])
    .follow("path", as: "document")
    .all()

// Allow all hostnames (use with caution)
let entries = try await FFetch(url: "https://example.com/query-index.json")
    .allow("*")
    .follow("path", as: "document")
    .all()
```

#### Security Considerations

The hostname restriction is an important security feature that prevents:
- **Cross-site request forgery (CSRF)**: Malicious sites cannot trick your app into fetching arbitrary content
- **Data exfiltration**: Prevents accidental requests to untrusted domains
- **Server-side request forgery (SSRF)**: Reduces risk of unintended internal network access

By default, only the hostname of your initial JSON request is allowed. This mirrors the security model used by web browsers for cross-origin requests.

## About Query Index Files

The `query-index.json` files used in the examples above are typically generated by AEM Live sites as part of their content indexing process. For more information about how these index files are created and structured, see the [AEM Live Indexing Documentation](https://www.aem.live/developer/indexing).

## Example

See `Examples.swift` in the repository for more detailed usage.

## License

This project is licensed under the terms of the Apache License 2.0. See [LICENSE](LICENSE) for details.

## Development Setup

### Quick Commands
Use the provided Makefile for common development tasks:

```bash
# Run all tests
make test

# Run tests with coverage
make coverage

# Generate detailed coverage report
make coverage-report

# Run swiftlint
make lint

# Build the project
make build

# Clean build artifacts
make clean

# Install dependencies
make install

# Format code (requires swiftformat)
make format
```

### Pre-commit Hook
This project uses SwiftLint as a pre-commit hook to ensure code quality. The hook automatically runs before each commit and will prevent commits if there are any linting violations.

To bypass the pre-commit hook (not recommended), use:
```bash
git commit --no-verify
```

To set up the pre-commit hook automatically, run:
```bash
./scripts/setup-pre-commit-hook.sh
```

This script will:
- Check if SwiftLint is installed (and install it via Homebrew if needed)
- Install the pre-commit hook
- Test the hook to ensure it works correctly
