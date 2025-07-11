# SwiftFFetch

A Swift port of the ffetch library for Adobe Experience Manager (AEM) Edge Delivery Services.

SwiftFFetch provides a fluent API for working with AEM indices, offering lazy pagination, filtering, transformation, and document following capabilities built on Swift's modern concurrency model.

## Features

- **🔄 Lazy Pagination**: Efficiently stream large datasets without loading everything into memory
- **⛓️ Fluent API**: Chain operations like `filter`, `map`, `limit`, and `slice`
- **⚡ Async/Await**: Built on Swift's modern concurrency model with structured concurrency
- **📄 Document Following**: Follow references to fetch and parse HTML documents
- **📊 Multi-sheet Support**: Work with multi-sheet JSON responses
- **🔧 Configurable**: Customize HTTP client, HTML parser, and concurrency settings
- **📦 Minimal Dependencies**: Only depends on Foundation and SwiftSoup for HTML parsing
- **🧪 Full Test Coverage**: Comprehensive test suite with 95%+ code coverage
- **📖 Complete Documentation**: DocC documentation for all public APIs

## For Users Coming from JavaScript `ffetch`

If you're familiar with the JavaScript [`ffetch`](https://github.com/adobe/ffetch) library, SwiftFFetch will feel very familiar. Both libraries provide a fluent, chainable API for working with AEM indices, including lazy pagination, filtering, mapping, slicing, following document references, and multi-sheet support.

### Key Similarities

| JavaScript                | Swift                                 |
|---------------------------|---------------------------------------|
| `ffetch(url)`             | `try ffetch(url)`                     |
| `.chunks(size)`           | `.chunks(size)`                       |
| `.sheet(name)`            | `.sheet(name)`                        |
| `.map(fn)`                | `.map { entry in ... }`               |
| `.filter(fn)`             | `.filter { entry in ... }`            |
| `.limit(n)`               | `.limit(n)`                           |
| `.slice(start, end)`      | `.slice(start, end)`                  |
| `.follow(field, newField)`| `.follow(field, as: newField)`        |
| `.all()`                  | `try await .all()`                    |
| `.first()`                | `try await .first()`                  |
| `for await (entry of ...)`| `for await entry in ...`              |

### Main Differences

- **Error Handling**: Swift uses `try`/`catch` for error handling, rather than JavaScript's promise rejection.
- **Async/Await**: Swift's async/await syntax is slightly different (`try await`), and iteration uses `for await entry in ...`.
- **Type Safety**: Swift provides compile-time type checking, so entries are `[String: Any]` instead of plain objects.
- **Concurrency**: SwiftFFetch leverages Swift's structured concurrency for performance and safety.
- **Custom Clients/Parsers**: SwiftFFetch allows you to inject custom HTTP clients and HTML parsers for advanced use cases.

### Example Migration

**JavaScript:**
```javascript
const entries = ffetch('/query-index.json')
  .filter(e => e.published)
  .map(e => e.title)
  .limit(10);

for await (const title of entries) {
  console.log(title);
}
```

**Swift:**
```swift
let entries = try ffetch("/query-index.json")
    .filter { entry in (entry["published"] as? Bool) == true }
    .map { entry in entry["title"] as? String ?? "Untitled" }
    .limit(10)

for await title in entries {
    print(title)
}
```

For more details on API differences and migration tips, see the [Migration from JavaScript ffetch](#migration-from-javascript-ffetch) section below.

---

## Installation

### Swift Package Manager

Add SwiftFFetch to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/your-org/SwiftFFetch.git", from: "1.0.0")
]
```

Or add it through Xcode:
1. File → Add Package Dependencies
2. Enter the repository URL
3. Select the version range

## Quick Start

### Basic Usage

```swift
import SwiftFFetch

// Stream all entries from an AEM index
let entries = try ffetch("/query-index.json")
for await entry in entries {
    print(entry["title"] as? String ?? "No title")
}
```

### Get First Entry

```swift
let firstEntry = try await ffetch("/query-index.json").first()
print(firstEntry?["title"] as? String ?? "No entries")
```

### Collect All Entries

```swift
let allEntries = try await ffetch("/query-index.json").all()
allEntries.forEach { entry in
    print(entry["title"] as? String ?? "No title")
}
```

## Advanced Usage

### Chaining Operations

```swift
let results = try await ffetch("/query-index.json")
    .filter { entry in
        (entry["published"] as? Bool) == true
    }
    .map { entry in
        entry["title"] as? String ?? "Untitled"
    }
    .limit(10)
    .all()
```

### Working with Multi-sheet Responses

```swift
let products = try await ffetch("/query-index.json")
    .sheet("products")
    .filter { product in
        (product["inStock"] as? Bool) == true
    }
    .limit(20)
    .all()
```

### Following Document References

```swift
import SwiftSoup

let postsWithContent = try await ffetch("/blog-index.json")
    .follow("path", as: "document")
    .map { entry -> [String: Any] in
        var result = entry

        if let doc = entry["document"] as? Document {
            result["htmlTitle"] = try? doc.select("title").first()?.text()
            result["firstImage"] = try? doc.select("img").first()?.attr("src")
        }

        return result
    }
    .limit(5)
    .all()
```

### Error Handling for `.follow()`

When using `.follow(fieldName, as: newFieldName)`, SwiftFFetch will attempt to fetch and parse the referenced document for each entry. If an error occurs (such as a network error, HTTP error, or HTML parsing error), the following will happen:

- The `newFieldName` field will be set to `nil`.
- An additional field named `newFieldName_error` will be added to the entry, containing a description of the error.

This allows you to distinguish between a missing document and a fetch/parse failure. For example:

```swift
let postsWithContent = try await ffetch("/blog-index.json")
    .follow("path", as: "document")
    .map { entry -> [String: Any] in
        if let error = entry["document_error"] as? String {
            print("Error fetching document: \(error)")
        }
        // ... your logic ...
        return entry
    }
    .all()
```

Possible error messages include:
- "Missing or invalid URL string in field ..."
- "Could not resolve URL from field ..."
- "HTTP error 404 for ..."
- "No HTTPURLResponse for ..."
- "HTML parsing error for ..."
- "Network error for ..."


### Performance Tuning

```swift
let optimizedFetch = try ffetch("/large-index.json")
    .chunks(100)                    // Larger chunks for better performance
    .withMaxConcurrency(5)          // Control concurrent operations
    .withCacheReload(true)          // Force cache reload
    .filter { entry in
        // Early filtering to reduce processing
        (entry["category"] as? String) == "important"
    }
    .limit(50)                      // Early termination
```

## API Reference

### Core Types

#### `FFetch`
The main class that provides the fluent API for streaming and processing AEM index data.

#### `FFetchEntry`
Type alias for `[String: Any]` representing a single entry from an AEM index.

#### `FFetchError`
Enumeration of possible errors that can occur during FFetch operations.

### Configuration Methods

#### `chunks(_ size: Int) -> FFetch`
Set the chunk size for pagination. Default is 255.

```swift
let chunkedFetch = try ffetch("/index.json").chunks(100)
```

#### `sheet(_ name: String) -> FFetch`
Select a specific sheet from multi-sheet responses.

```swift
let productSheet = try ffetch("/index.json").sheet("products")
```

#### `withHTTPClient(_ client: FFetchHTTPClient) -> FFetch`
Use a custom HTTP client implementation.

```swift
let customClient = MyCustomHTTPClient()
let fetchWithCustomClient = try ffetch("/index.json").withHTTPClient(customClient)
```

#### `withHTMLParser(_ parser: FFetchHTMLParser) -> FFetch`
Use a custom HTML parser implementation.

```swift
let customParser = MyCustomHTMLParser()
let fetchWithCustomParser = try ffetch("/index.json").withHTMLParser(customParser)
```

#### `withCacheReload(_ reload: Bool = true) -> FFetch`
Control cache behavior for requests.

```swift
let reloadingFetch = try ffetch("/index.json").withCacheReload(true)
```

#### `withMaxConcurrency(_ maxConcurrency: Int) -> FFetch`
Set the maximum number of concurrent operations.

```swift
let concurrentFetch = try ffetch("/index.json").withMaxConcurrency(10)
```

### Transformation Methods

#### `filter(_ predicate: @escaping FFetchPredicate<FFetchEntry>) -> FFetch`
Filter entries based on a predicate function.

```swift
let publishedPosts = try ffetch("/blog-index.json")
    .filter { post in
        (post["published"] as? Bool) == true
    }
```

#### `map<T>(_ transform: @escaping FFetchTransform<FFetchEntry, T>) -> FFetchMapped<T>`
Transform each entry using a mapping function.

```swift
let titles = try ffetch("/blog-index.json")
    .map { post in
        post["title"] as? String ?? "Untitled"
    }
```

#### `limit(_ count: Int) -> FFetch`
Limit the number of entries returned.

```swift
let firstTen = try ffetch("/index.json").limit(10)
```

#### `skip(_ count: Int) -> FFetch`
Skip a number of entries from the beginning.

```swift
let withoutFirstTen = try ffetch("/index.json").skip(10)
```

#### `slice(_ start: Int, _ end: Int) -> FFetch`
Extract a slice of entries (similar to Array.slice).

```swift
let middleEntries = try ffetch("/index.json").slice(10, 20)
```

### Document Following

#### `follow(_ fieldName: String, as newFieldName: String? = nil) -> FFetch`
Follow references to fetch HTML documents.

```swift
let postsWithDocuments = try ffetch("/blog-index.json")
    .follow("path", as: "document")
```

### Collection Methods

#### `all() async throws -> [FFetchEntry]`
Collect all entries into an array.

```swift
let allEntries = try await ffetch("/index.json").all()
```

#### `first() async throws -> FFetchEntry?`
Get the first entry, or nil if no entries exist.

```swift
let firstEntry = try await ffetch("/index.json").first()
```

#### `count() async throws -> Int`
Count the total number of entries.

```swift
let totalCount = try await ffetch("/index.json").count()
```

## Error Handling

SwiftFFetch uses Swift's built-in error handling mechanisms:

```swift
do {
    let entries = try await ffetch("/index.json")
        .filter { entry in
            // Filter logic
            true
        }
        .all()

    // Process entries
} catch FFetchError.invalidURL(let url) {
    print("Invalid URL: \(url)")
} catch FFetchError.networkError(let error) {
    print("Network error: \(error)")
} catch {
    print("Other error: \(error)")
}
```

### Error Types

- `FFetchError.invalidURL(_)`: Invalid URL provided
- `FFetchError.networkError(_)`: Network-related errors
- `FFetchError.decodingError(_)`: JSON decoding errors
- `FFetchError.invalidResponse`: Invalid HTTP response
- `FFetchError.documentNotFound`: Referenced document not found
- `FFetchError.operationFailed(_)`: General operation failures

## Performance Considerations

### Memory Efficiency
SwiftFFetch uses AsyncSequence for lazy evaluation, meaning it only loads data as needed:

```swift
// This will only load data as you iterate
for await entry in try ffetch("/large-index.json") {
    // Process each entry individually
    // Memory usage remains constant regardless of dataset size
}
```

### Concurrency Control
Control the number of concurrent operations to balance performance and resource usage:

```swift
let fetch = try ffetch("/index.json")
    .withMaxConcurrency(3)  // Limit to 3 concurrent operations
    .map { entry in
        // Expensive async operation
        await processEntry(entry)
    }
```

### Early Termination
Use `limit()` to avoid processing unnecessary data:

```swift
let topTen = try await ffetch("/index.json")
    .filter { entry in
        // Expensive filtering
        await isHighPriority(entry)
    }
    .limit(10)  // Stop after finding 10 matching entries
    .all()
```

## Real-world Examples

### Blog Processing Pipeline

```swift
import SwiftFFetch
import SwiftSoup

let publishedPosts = try await ffetch("/blog-index.json")
    .filter { post in
        (post["published"] as? Bool) == true
    }
    .filter { post in
        (post["category"] as? String) == "tech"
    }
    .follow("path", as: "document")
    .map { post -> [String: Any] in
        var result: [String: Any] = [
            "id": post["id"] as Any,
            "title": post["title"] as Any,
            "author": post["author"] as Any,
            "publishedDate": post["publishedDate"] as Any
        ]

        if let document = post["document"] as? Document {
            result["htmlTitle"] = try? document.select("title").first()?.text()
            result["excerpt"] = try? document.select("meta[name=description]").first()?.attr("content")
            result["imageCount"] = try? document.select("img").count()
        }

        return result
    }
    .limit(10)
    .all()
```

### E-commerce Product Catalog

```swift
let affordableElectronics = try await ffetch("/products-index.json")
    .sheet("products")
    .filter { product in
        (product["inStock"] as? Bool) == true
    }
    .filter { product in
        (product["category"] as? String) == "electronics"
    }
    .filter { product in
        let price = product["price"] as? Double ?? 0
        return price >= 100 && price <= 500
    }
    .map { product -> [String: Any] in
        return [
            "id": product["id"] as Any,
            "name": product["name"] as Any,
            "price": product["price"] as Any,
            "formattedPrice": String(format: "$%.2f", product["price"] as? Double ?? 0),
            "rating": product["rating"] as Any
        ]
    }
    .limit(20)
    .all()
```

### Content Audit and SEO Analysis

```swift
let seoAudit = try await ffetch("/content-index.json")
    .follow("path", as: "document")
    .map { content -> [String: Any] in
        var audit: [String: Any] = [
            "id": content["id"] as Any,
            "title": content["title"] as Any,
            "path": content["path"] as Any
        ]

        if let document = content["document"] as? Document {
            let title = try? document.select("title").first()?.text()
            let description = try? document.select("meta[name=description]").first()?.attr("content")
            let h1Count = try? document.select("h1").count()
            let imageCount = try? document.select("img").count()
            let imagesWithAlt = try? document.select("img[alt]").count()

            var seoScore = 0
            if title != nil && !title!.isEmpty { seoScore += 20 }
            if description != nil && !description!.isEmpty { seoScore += 20 }
            if h1Count == 1 { seoScore += 20 }
            if imageCount ?? 0 > 0 && imagesWithAlt == imageCount { seoScore += 40 }

            audit["seoScore"] = seoScore
            audit["seoGrade"] = seoScore >= 80 ? "A" : seoScore >= 60 ? "B" : "C"
        }

        return audit
    }
    .all()
```

## Testing

SwiftFFetch includes a comprehensive test suite. Run tests using:

```bash
swift test
```

### Test Coverage

- Unit tests for all operations
- Integration tests for real-world scenarios
- Performance tests for large datasets
- Error handling tests
- Mock HTTP client for reliable testing

## Migration from JavaScript ffetch

SwiftFFetch provides equivalent functionality to the JavaScript version:

| JavaScript | Swift |
|------------|-------|
| `ffetch(url)` | `try ffetch(url)` |
| `.chunks(size)` | `.chunks(size)` |
| `.sheet(name)` | `.sheet(name)` |
| `.map(fn)` | `.map { entry in ... }` |
| `.filter(fn)` | `.filter { entry in ... }` |
| `.limit(n)` | `.limit(n)` |
| `.slice(start, end)` | `.slice(start, end)` |
| `.follow(field, newField)` | `.follow(field, as: newField)` |
| `.all()` | `try await .all()` |
| `.first()` | `try await .first()` |
| `for await (entry of fetch)` | `for await entry in fetch` |

### Key Differences

1. **Error Handling**: Swift uses `try/catch` instead of promise rejection
2. **Async/Await**: Swift's async/await syntax is slightly different
3. **Type Safety**: Swift provides compile-time type checking
4. **Concurrency**: Swift uses structured concurrency for better performance

## Contributing

Contributions are welcome! Please read the contributing guidelines and submit pull requests for any improvements.

### Development Setup

1. Clone the repository
2. Open in Xcode or use Swift Package Manager
3. Run tests: `swift test`
4. Build documentation: `swift package generate-documentation`

## License

SwiftFFetch is licensed under the Apache License 2.0. See [LICENSE](LICENSE) for details.

## Acknowledgments

- Original ffetch library by Adobe
- SwiftSoup for HTML parsing
- Swift community for async/await patterns

---

For more information, visit the [documentation](https://your-org.github.io/SwiftFFetch/documentation/swiftffetch/) or check the [examples](examples/) directory.
