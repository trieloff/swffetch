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
}
