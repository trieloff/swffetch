swffetch/README.md
# SwiftFFetch

SwiftFFetch is a Swift library for fetching and processing content from AEM (.live) Content APIs and similar JSON-based endpoints. It is designed for composable applications, making it easy to retrieve, paginate, and process content in a Swift-native way.

## Features

- **Swift-native API**: Designed for idiomatic use in Swift projects.
- **Async/Await Support**: Uses Swift concurrency for efficient, modern code.
- **Pagination**: Handles paginated endpoints seamlessly.
- **Composable**: Chainable methods for mapping, filtering, and transforming content.
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

let entries = FFetch(url: "/query-index.json")
for try await entry in entries {
    print(entry["title"] as? String ?? "")
}
```

### Get the First Entry

```swift
let firstEntry = try await FFetch(url: "/query-index.json").first()
print(firstEntry?["title"] as? String ?? "")
```

### Get All Entries as an Array

```swift
let allEntries = try await FFetch(url: "/query-index.json").all()
allEntries.forEach { entry in
    print(entry)
}
```

### Map and Filter Entries

```swift
let filteredTitles = FFetch(url: "/query-index.json")
    .map { $0["title"] as? String }
    .filter { $0?.contains("Swift") == true }

for try await title in filteredTitles {
    print(title ?? "")
}
```

### Control Pagination with `chunks` and `limit`

```swift
let limitedEntries = FFetch(url: "/query-index.json")
    .chunks(100)
    .limit(5)

for try await entry in limitedEntries {
    print(entry)
}
```

### Access a Specific Sheet

```swift
let productEntries = FFetch(url: "/query-index.json")
    .sheet("products")

for try await entry in productEntries {
    print(entry["sku"] as? String ?? "")
}
```

## Example

See `Examples.swift` in the repository for more detailed usage.

## License

This project is licensed under the terms of the MIT license. See [LICENSE](LICENSE) for details.

---
SwiftFFetch is not affiliated with Adobe or AEM. It is an independent open-source project.

## Development Setup

### Pre-commit Hook
This project uses SwiftLint as a pre-commit hook to ensure code quality. The hook automatically runs before each commit and will prevent commits if there are any linting violations.

To bypass the pre-commit hook (not recommended), use:
```bash
git commit --no-verify
```
