//
//  CachingExample.swift
//  SwiftFFetch
//
//  Examples demonstrating HTTP caching capabilities in SwiftFFetch
//

import Foundation
import SwiftFFetch

// MARK: - Basic Caching Examples

/// Example 1: Default caching behavior
/// By default, SwiftFFetch uses a shared URLCache and respects HTTP cache control headers
func basicCachingExample() async throws {
    let url = "https://example.com/api/data.json"

    // First request - fetches from server
    let entries1 = try await ffetch(url).all()
    print("First request: \(entries1.count) entries")

    // Second request - uses cache if server sent appropriate cache headers
    let entries2 = try await ffetch(url).all()
    print("Second request: \(entries2.count) entries (likely from cache)")
}

/// Example 2: Forcing cache bypass
/// Sometimes you need fresh data regardless of cache headers
func forceFreshDataExample() async throws {
    let url = "https://example.com/api/live-data.json"

    // Always fetch fresh data from server
    let liveData = try await ffetch(url)
        .cache(.noCache)  // Bypasses cache completely
        .all()

    print("Live data: \(liveData.count) entries")
}

/// Example 3: Cache-only requests
/// Useful for offline scenarios or when you only want cached data
func cacheOnlyExample() async throws {
    let url = "https://example.com/api/cached-data.json"

    // First, populate the cache
    _ = try await ffetch(url).all()

    // Then, only use cached data (won't make network request)
    let cachedData = try await ffetch(url)
        .cache(.cacheOnly)
        .all()

    print("Cached data: \(cachedData.count) entries")
}

// MARK: - Advanced Caching Examples

/// Example 4: Custom cache configuration
/// Create your own cache with specific memory and disk limits
func customCacheExample() async throws {
    let url = "https://example.com/api/products.json"

    // Create a custom cache with 10MB memory and 50MB disk capacity
    let customCache = URLCache(
        memoryCapacity: 10 * 1024 * 1024,  // 10MB
        diskCapacity: 50 * 1024 * 1024     // 50MB
    )

    let customCacheConfig = FFetchCacheConfig(
        policy: .useProtocolCachePolicy,
        cache: customCache
    )

    let products = try await ffetch(url)
        .cache(customCacheConfig)
        .all()

    print("Products: \(products.count) entries")

    // Check cache statistics
    print("Cache memory usage: \(customCache.currentMemoryUsage) bytes")
    print("Cache disk usage: \(customCache.currentDiskUsage) bytes")
}

/// Example 5: Custom cache expiration
/// Override server cache headers with your own expiration time
func customExpirationExample() async throws {
    let url = "https://example.com/api/frequently-updated.json"

    let customConfig = FFetchCacheConfig(
        policy: .useProtocolCachePolicy,
        maxAge: 300,  // Cache for 5 minutes regardless of server headers
        ignoreServerCacheControl: true
    )

    let data = try await ffetch(url)
        .cache(customConfig)
        .all()

    print("Data with custom expiration: \(data.count) entries")
}

/// Example 6: Cache sharing between multiple requests
/// The same cache can be reused across different FFetch instances
func sharedCacheExample() async throws {
    // Create a shared cache for your application
    let sharedCache = URLCache(
        memoryCapacity: 20 * 1024 * 1024,  // 20MB
        diskCapacity: 100 * 1024 * 1024    // 100MB
    )

    let sharedConfig = FFetchCacheConfig(
        policy: .useProtocolCachePolicy,
        cache: sharedCache
    )

    // Use the same cache across multiple endpoints
    let products = try await ffetch("https://example.com/api/products.json")
        .cache(sharedConfig)
        .all()

    let categories = try await ffetch("https://example.com/api/categories.json")
        .cache(sharedConfig)
        .all()

    let orders = try await ffetch("https://example.com/api/orders.json")
        .cache(sharedConfig)
        .all()

    print("Products: \(products.count), Categories: \(categories.count), Orders: \(orders.count)")
    print("Total cache usage: \(sharedCache.currentMemoryUsage) bytes")
}

// MARK: - Document Following with Caching

/// Example 7: Document following with caching
/// When following document links, caching works for both index and documents
func documentFollowingWithCacheExample() async throws {
    let indexUrl = "https://example.com/content/query-index.json"

    // Create a cache configuration for both index and documents
    let cacheConfig = FFetchCacheConfig(
        policy: .useProtocolCachePolicy,
        cache: URLCache(memoryCapacity: 5 * 1024 * 1024, diskCapacity: 20 * 1024 * 1024)
    )

    let entriesWithDocs = try await ffetch(indexUrl)
        .cache(cacheConfig)
        .follow("path", as: "document")  // Document requests also use the cache
        .all()

    print("Entries with documents: \(entriesWithDocs.count)")

    // Second request will use cached index and documents
    let cachedEntriesWithDocs = try await ffetch(indexUrl)
        .cache(cacheConfig)
        .follow("path", as: "document")
        .all()

    print("Cached entries with documents: \(cachedEntriesWithDocs.count)")
}

// MARK: - Backward Compatibility Examples

/// Example 8: Using legacy cache reload methods
/// These methods still work but map to the new cache system
func backwardCompatibilityExample() async throws {
    let url = "https://example.com/api/legacy-data.json"

    // Legacy method - maps to .cache(.noCache)
    let freshData = try await ffetch(url)
        .reloadCache()
        .all()

    // Legacy method with parameter - maps to .cache(.noCache) or .cache(.default)
    let conditionalData = try await ffetch(url)
        .withCacheReload(false)  // Uses default cache behavior
        .all()

    print("Fresh data: \(freshData.count), Conditional data: \(conditionalData.count)")
}

// MARK: - Real-World Use Cases

/// Example 9: E-commerce product catalog with intelligent caching
func ecommerceProductCatalogExample() async throws {
    let baseUrl = "https://api.store.com"

    // Long-term cache for product categories (rarely change)
    let categoryCache = FFetchCacheConfig(
        policy: .useProtocolCachePolicy,
        maxAge: 24 * 60 * 60,  // 24 hours
        ignoreServerCacheControl: true
    )

    // Short-term cache for product prices (change frequently)
    let priceCache = FFetchCacheConfig(
        policy: .useProtocolCachePolicy,
        maxAge: 5 * 60,  // 5 minutes
        ignoreServerCacheControl: true
    )

    // No cache for cart contents (always fresh)
    let cartCache = FFetchCacheConfig(
        policy: .reloadIgnoringLocalCacheData
    )

    let categories = try await ffetch("\(baseUrl)/categories.json")
        .cache(categoryCache)
        .all()

    let products = try await ffetch("\(baseUrl)/products.json")
        .cache(priceCache)
        .all()

    let cart = try await ffetch("\(baseUrl)/cart.json")
        .cache(cartCache)
        .all()

    print("Categories: \(categories.count), Products: \(products.count), Cart: \(cart.count)")
}

/// Example 10: Content management system with document caching
func contentManagementExample() async throws {
    let cmsUrl = "https://cms.example.com"

    // Create a dedicated cache for CMS content
    let cmsCache = URLCache(
        memoryCapacity: 15 * 1024 * 1024,  // 15MB for HTML content
        diskCapacity: 100 * 1024 * 1024    // 100MB disk cache
    )

    let cacheConfig = FFetchCacheConfig(
        policy: .useProtocolCachePolicy,
        cache: cmsCache
    )

    // Fetch content index with document following
    let articles = try await ffetch("\(cmsUrl)/articles/query-index.json")
        .cache(cacheConfig)
        .follow("path", as: "document")
        .map { entry in
            var processed = entry
            if let doc = entry["document"] as? Document {
                processed["title"] = try? doc.title()
                processed["text"] = try? doc.text()
            }
            return processed
        }
        .all()

    print("Articles processed: \(articles.count)")
    print("CMS cache usage: \(cmsCache.currentMemoryUsage) bytes")
}

// MARK: - Cache Management Utilities

/// Example 11: Cache management and monitoring
func cacheManagementExample() async throws {
    let monitoredCache = URLCache(
        memoryCapacity: 10 * 1024 * 1024,
        diskCapacity: 50 * 1024 * 1024
    )

    let config = FFetchCacheConfig(cache: monitoredCache)

    // Perform some cached requests
    _ = try await ffetch("https://example.com/data1.json").cache(config).all()
    _ = try await ffetch("https://example.com/data2.json").cache(config).all()
    _ = try await ffetch("https://example.com/data3.json").cache(config).all()

    // Monitor cache usage
    print("Memory usage: \(monitoredCache.currentMemoryUsage) bytes")
    print("Disk usage: \(monitoredCache.currentDiskUsage) bytes")

    // Clear cache if needed
    monitoredCache.removeAllCachedResponses()
    print("Cache cleared")
}

// MARK: - Cache Best Practices

/// Example 12: Implementing cache best practices
func cacheBestPracticesExample() async throws {
    // 1. Use a shared cache for your application
    let appCache = URLCache(
        memoryCapacity: 20 * 1024 * 1024,  // 20MB memory
        diskCapacity: 100 * 1024 * 1024    // 100MB disk
    )

    // 2. Configure different cache policies for different data types
    let staticContentConfig = FFetchCacheConfig(
        policy: .useProtocolCachePolicy,
        cache: appCache,
        maxAge: 24 * 60 * 60  // 24 hours for static content
    )

    let dynamicContentConfig = FFetchCacheConfig(
        policy: .useProtocolCachePolicy,
        cache: appCache,
        maxAge: 5 * 60  // 5 minutes for dynamic content
    )

    // 3. Use appropriate cache policies for your use case
    let staticData = try await ffetch("https://example.com/static-config.json")
        .cache(staticContentConfig)
        .all()

    let dynamicData = try await ffetch("https://example.com/live-feed.json")
        .cache(dynamicContentConfig)
        .all()

    print("Static: \(staticData.count), Dynamic: \(dynamicData.count)")

    // 4. Monitor and manage cache size
    if appCache.currentMemoryUsage > 15 * 1024 * 1024 {  // > 15MB
        print("Cache getting large, consider clearing old entries")
    }
}

// MARK: - Integration with Other HTTP Requests

/// Example 13: Sharing cache with other HTTP requests in your app
func sharedCacheWithOtherRequestsExample() async throws {
    // Create a shared cache for your entire application
    let appWideCache = URLCache(
        memoryCapacity: 30 * 1024 * 1024,  // 30MB
        diskCapacity: 200 * 1024 * 1024    // 200MB
    )

    // Use it with FFetch
    let ffetchConfig = FFetchCacheConfig(cache: appWideCache)
    let ffetchData = try await ffetch("https://api.example.com/data.json")
        .cache(ffetchConfig)
        .all()

    // Use the same cache with regular URLSession requests
    let sessionConfig = URLSessionConfiguration.default
    sessionConfig.urlCache = appWideCache
    let session = URLSession(configuration: sessionConfig)

    let request = URLRequest(url: URL(string: "https://api.example.com/other-data.json")!)
    let (data, _) = try await session.data(for: request)

    print("FFetch data: \(ffetchData.count) entries")
    print("URLSession data: \(data.count) bytes")
    print("Shared cache usage: \(appWideCache.currentMemoryUsage) bytes")
}

// MARK: - Running Examples

/// Run all caching examples
func runAllCachingExamples() async throws {
    print("=== SwiftFFetch Caching Examples ===\n")

    print("1. Basic Caching:")
    try await basicCachingExample()

    print("\n2. Force Fresh Data:")
    try await forceFreshDataExample()

    print("\n3. Cache Only:")
    try await cacheOnlyExample()

    print("\n4. Custom Cache:")
    try await customCacheExample()

    print("\n5. Custom Expiration:")
    try await customExpirationExample()

    print("\n6. Shared Cache:")
    try await sharedCacheExample()

    print("\n7. Document Following with Cache:")
    try await documentFollowingWithCacheExample()

    print("\n8. Backward Compatibility:")
    try await backwardCompatibilityExample()

    print("\n9. E-commerce Example:")
    try await ecommerceProductCatalogExample()

    print("\n10. Content Management Example:")
    try await contentManagementExample()

    print("\n11. Cache Management:")
    try await cacheManagementExample()

    print("\n12. Best Practices:")
    try await cacheBestPracticesExample()

    print("\n13. Shared Cache with Other Requests:")
    try await sharedCacheWithOtherRequestsExample()

    print("\n=== All Examples Complete ===")
}
