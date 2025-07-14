//
//  SwiftFFetchCacheTests.swift
//  SwiftFFetchTests
//
//  Tests for cache reload logic in FFetch.
//
import XCTest
@testable import SwiftFFetch

final class SwiftFFetchCacheTests: XCTestCase {

    func testCacheReload() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()
        mockIndexRequests(client: client, baseURL: baseURL, total: 5)

        let ffetch = FFetch(url: baseURL)
            .withHTTPClient(client)
            .withCacheReload(true)

        var count = 0
        for await _ in ffetch {
            count += 1
        }

        XCTAssertEqual(count, 5)
    }

    func testCacheConfiguration() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()
        mockIndexRequests(client: client, baseURL: baseURL, total: 3)

        // Test default cache behavior
        let ffetchDefault = FFetch(url: baseURL)
            .withHTTPClient(client)
            .cache(.default)

        var count = 0
        for await _ in ffetchDefault {
            count += 1
        }

        XCTAssertEqual(count, 3)
    }

    func testNoCacheConfiguration() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()
        mockIndexRequests(client: client, baseURL: baseURL, total: 3)

        // Test no-cache behavior
        let ffetchNoCache = FFetch(url: baseURL)
            .withHTTPClient(client)
            .cache(.noCache)

        var count = 0
        for await _ in ffetchNoCache {
            count += 1
        }

        XCTAssertEqual(count, 3)
    }

    func testCacheOnlyConfiguration() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()
        mockIndexRequests(client: client, baseURL: baseURL, total: 3)

        // Test cache-only behavior
        let ffetchCacheOnly = FFetch(url: baseURL)
            .withHTTPClient(client)
            .cache(.cacheOnly)

        var count = 0
        for await _ in ffetchCacheOnly {
            count += 1
        }

        XCTAssertEqual(count, 3)
    }

    func testCustomCacheConfiguration() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()
        mockIndexRequests(client: client, baseURL: baseURL, total: 3)

        // Test custom cache configuration
        let customCache = URLCache(memoryCapacity: 1024 * 1024, diskCapacity: 0)
        let customConfig = FFetchCacheConfig(
            policy: .useProtocolCachePolicy,
            cache: customCache,
            maxAge: 3600
        )

        let ffetchCustom = FFetch(url: baseURL)
            .withHTTPClient(client)
            .cache(customConfig)

        var count = 0
        for await _ in ffetchCustom {
            count += 1
        }

        XCTAssertEqual(count, 3)
    }

    func testBackwardCompatibilityReloadCache() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()
        mockIndexRequests(client: client, baseURL: baseURL, total: 3)

        // Test backward compatibility with reloadCache()
        let ffetch = FFetch(url: baseURL)
            .withHTTPClient(client)
            .reloadCache()

        var count = 0
        for await _ in ffetch {
            count += 1
        }

        XCTAssertEqual(count, 3)
    }

    func testWithCacheReloadFalse() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()
        mockIndexRequests(client: client, baseURL: baseURL, total: 3)

        // Test withCacheReload(false) - this covers the missing .default region
        let ffetch = FFetch(url: baseURL)
            .withHTTPClient(client)
            .withCacheReload(false)

        var count = 0
        for await _ in ffetch {
            count += 1
        }

        XCTAssertEqual(count, 3)
    }

    func testWithCacheReloadDefaultParameter() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()
        mockIndexRequests(client: client, baseURL: baseURL, total: 2)

        // Test withCacheReload() with default parameter (true)
        let ffetch = FFetch(url: baseURL)
            .withHTTPClient(client)
            .withCacheReload() // Default parameter should be true

        var count = 0
        for await _ in ffetch {
            count += 1
        }

        XCTAssertEqual(count, 2)
    }

    func testCacheConfigurationChaining() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()
        mockIndexRequests(client: client, baseURL: baseURL, total: 4)

        // Test chaining cache configurations to ensure proper override behavior
        let ffetch = FFetch(url: baseURL)
            .withHTTPClient(client)
            .cache(.default)
            .withCacheReload(false) // Should override previous cache setting
            .cache(.noCache) // Should override again

        var count = 0
        for await _ in ffetch {
            count += 1
        }

        XCTAssertEqual(count, 4)
    }

    func testBackwardCompatibilityCacheMethods() {
        let baseURL = URL(string: "https://example.com/query-index.json")!

        // Test all cache-related methods create valid instances
        let ffetch1 = FFetch(url: baseURL).withCacheReload(true)
        let ffetch2 = FFetch(url: baseURL).withCacheReload(false)
        let ffetch3 = FFetch(url: baseURL).withCacheReload() // Default true
        let ffetch4 = FFetch(url: baseURL).reloadCache()

        XCTAssertNotNil(ffetch1)
        XCTAssertNotNil(ffetch2)
        XCTAssertNotNil(ffetch3)
        XCTAssertNotNil(ffetch4)

        // Ensure they are different instances (value semantics for struct)
        XCTAssertNotEqual(ffetch1.context.cacheConfig.policy, ffetch2.context.cacheConfig.policy)
        XCTAssertNotEqual(ffetch3.context.cacheConfig.policy, ffetch2.context.cacheConfig.policy)
        XCTAssertEqual(ffetch1.context.cacheConfig.policy, ffetch3.context.cacheConfig.policy)
    }

    func testCacheConfigEdgeCases() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()
        mockIndexRequests(client: client, baseURL: baseURL, total: 1)

        // Test cache configuration with all possible enum values
        let configs: [FFetchCacheConfig] = [
            .default,
            .noCache,
            .cacheOnly,
            .cacheElseLoad,
            FFetchCacheConfig(policy: .useProtocolCachePolicy, cache: nil, maxAge: 0)
        ]

        for config in configs {
            let ffetch = FFetch(url: baseURL)
                .withHTTPClient(client)
                .cache(config)

            var count = 0
            for await _ in ffetch {
                count += 1
            }
            XCTAssertEqual(count, 1, "Config \(config) should work correctly")
        }
    }
}
