//
//  FFetchTypesHTTPClientTests.swift
//  SwiftFFetchTests
//
//  Focused tests for DefaultFFetchHTTPClient type
//
import XCTest
import Foundation
@testable import SwiftFFetch

final class FFetchTypesHTTPClientTests: XCTestCase {

    // MARK: - DefaultFFetchHTTPClient Tests

    func testDefaultFFetchHTTPClientInit() {
        let client = DefaultFFetchHTTPClient()
        XCTAssertNotNil(client)
    }

    func testDefaultFFetchHTTPClientInitWithSession() {
        let session = URLSession.shared
        let client = DefaultFFetchHTTPClient(session: session)
        XCTAssertNotNil(client)
    }

    func testDefaultFFetchHTTPClientInitWithCache() {
        let cache = URLCache(memoryCapacity: 1024, diskCapacity: 2048)
        let client = DefaultFFetchHTTPClient(cache: cache)
        XCTAssertNotNil(client)
    }

    func testDefaultFFetchHTTPClientInitWithSessionAndCache() {
        let session = URLSession.shared
        let cache = URLCache(memoryCapacity: 1024, diskCapacity: 2048)
        let client = DefaultFFetchHTTPClient(session: session, cache: cache)
        XCTAssertNotNil(client)
    }

    func testDefaultFFetchHTTPClientFetchInvalidURL() async {
        let client = DefaultFFetchHTTPClient()
        let invalidURL = URL(string: "https://invalid-domain-that-does-not-exist-12345.com")!

        do {
            _ = try await client.fetch(invalidURL)
            XCTFail("Expected network error for invalid URL")
        } catch {
            if case FFetchError.networkError = error {
                // Expected error type
            } else {
                XCTFail("Expected FFetchError.networkError, got \(error)")
            }
        }
    }

    // MARK: - Advanced HTTP Client Tests

    func testDefaultFFetchHTTPClientWithCustomCacheAndMaxAge() async throws {
        let customCache = URLCache(memoryCapacity: 1024, diskCapacity: 2048)
        let cacheConfig = FFetchCacheConfig(
            policy: .useProtocolCachePolicy,
            cache: customCache,
            maxAge: 1800,
            ignoreServerCacheControl: true
        )

        let client = DefaultFFetchHTTPClient()
        let url = URL(string: "https://httpbin.org/headers")!

        // Test the custom cache path
        let (data, response) = try await client.fetch(url, cacheConfig: cacheConfig)

        XCTAssertFalse(data.isEmpty)
        XCTAssertNotNil(response)

        if let httpResponse = response as? HTTPURLResponse {
            XCTAssertEqual(httpResponse.statusCode, 200)
        }
    }

    func testDefaultFFetchHTTPClientWithCustomSession() async throws {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        let customSession = URLSession(configuration: config)

        let client = DefaultFFetchHTTPClient(session: customSession)
        let url = URL(string: "https://httpbin.org/get")!

        let (data, response) = try await client.fetch(url)

        XCTAssertFalse(data.isEmpty)
        XCTAssertNotNil(response)
    }

    func testDefaultFFetchHTTPClientCacheControlModification() async throws {
        let customCache = URLCache(memoryCapacity: 1024, diskCapacity: 2048)
        let cacheConfig = FFetchCacheConfig(
            policy: .useProtocolCachePolicy,
            cache: customCache,
            maxAge: 300,
            ignoreServerCacheControl: true
        )

        let client = DefaultFFetchHTTPClient()
        let url = URL(string: "https://httpbin.org/cache/60")!

        // This should exercise the cache control modification path
        let (data, response) = try await client.fetch(url, cacheConfig: cacheConfig)

        XCTAssertFalse(data.isEmpty)
        XCTAssertNotNil(response)
    }
}
