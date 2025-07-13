//
//  FFetchTypesTests.swift
//  SwiftFFetchTests
//
//  Comprehensive tests for all types in FFetchTypes.swift
//
import XCTest
import Foundation
@testable import SwiftFFetch

final class FFetchTypesTests: XCTestCase {

    // MARK: - FFetchError Tests

    func testFFetchErrorInvalidURL() {
        let error = FFetchError.invalidURL("not-a-url")
        XCTAssertEqual(error.errorDescription, "Invalid URL: not-a-url")
    }

    func testFFetchErrorNetworkError() {
        let underlyingError = NSError(domain: "test", code: 404, userInfo: [NSLocalizedDescriptionKey: "Not Found"])
        let error = FFetchError.networkError(underlyingError)
        XCTAssertEqual(error.errorDescription, "Network error: Not Found")
    }

    func testFFetchErrorDecodingError() {
        let underlyingError = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON"])
        let error = FFetchError.decodingError(underlyingError)
        XCTAssertEqual(error.errorDescription, "Decoding error: Invalid JSON")
    }

    func testFFetchErrorInvalidResponse() {
        let error = FFetchError.invalidResponse
        XCTAssertEqual(error.errorDescription, "Invalid response format")
    }

    func testFFetchErrorDocumentNotFound() {
        let error = FFetchError.documentNotFound
        XCTAssertEqual(error.errorDescription, "Document not found")
    }

    func testFFetchErrorOperationFailed() {
        let error = FFetchError.operationFailed("Custom operation error")
        XCTAssertEqual(error.errorDescription, "Operation failed: Custom operation error")
    }

    // MARK: - FFetchCacheConfig Tests

    func testFFetchCacheConfigDefault() {
        let config = FFetchCacheConfig.default
        XCTAssertEqual(config.policy, .useProtocolCachePolicy)
        XCTAssertNil(config.cache)
        XCTAssertNil(config.maxAge)
        XCTAssertFalse(config.ignoreServerCacheControl)
    }

    func testFFetchCacheConfigNoCache() {
        let config = FFetchCacheConfig.noCache
        XCTAssertEqual(config.policy, .reloadIgnoringLocalCacheData)
        XCTAssertNil(config.cache)
        XCTAssertNil(config.maxAge)
        XCTAssertFalse(config.ignoreServerCacheControl)
    }

    func testFFetchCacheConfigCacheOnly() {
        let config = FFetchCacheConfig.cacheOnly
        XCTAssertEqual(config.policy, .returnCacheDataDontLoad)
        XCTAssertNil(config.cache)
        XCTAssertNil(config.maxAge)
        XCTAssertFalse(config.ignoreServerCacheControl)
    }

    func testFFetchCacheConfigCacheElseLoad() {
        let config = FFetchCacheConfig.cacheElseLoad
        XCTAssertEqual(config.policy, .returnCacheDataElseLoad)
        XCTAssertNil(config.cache)
        XCTAssertNil(config.maxAge)
        XCTAssertFalse(config.ignoreServerCacheControl)
    }

    func testFFetchCacheConfigCustomInit() {
        let customCache = URLCache(memoryCapacity: 1024, diskCapacity: 2048)
        let config = FFetchCacheConfig(
            policy: .reloadRevalidatingCacheData,
            cache: customCache,
            maxAge: 3600,
            ignoreServerCacheControl: true
        )

        XCTAssertEqual(config.policy, .reloadRevalidatingCacheData)
        XCTAssertNotNil(config.cache)
        XCTAssertEqual(config.maxAge, 3600)
        XCTAssertTrue(config.ignoreServerCacheControl)
    }

    func testFFetchCacheConfigInitWithDefaults() {
        let config = FFetchCacheConfig()
        XCTAssertEqual(config.policy, .useProtocolCachePolicy)
        XCTAssertNil(config.cache)
        XCTAssertNil(config.maxAge)
        XCTAssertFalse(config.ignoreServerCacheControl)
    }

    // MARK: - DefaultFFetchHTTPClient Tests

    func testDefaultFFetchHTTPClientInit() {
        let client = DefaultFFetchHTTPClient()
        // Test that client was initialized successfully
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

    // MARK: - DefaultFFetchHTMLParser Tests

    func testDefaultFFetchHTMLParserInit() {
        let parser = DefaultFFetchHTMLParser()
        XCTAssertNotNil(parser)
    }

    func testDefaultFFetchHTMLParserValidHTML() throws {
        let parser = DefaultFFetchHTMLParser()
        let html = "<html><body><h1>Test</h1></body></html>"

        let document = try parser.parse(html)
        XCTAssertNotNil(document)
        XCTAssertEqual(try document.select("h1").text(), "Test")
    }

    func testDefaultFFetchHTMLParserEmptyHTML() throws {
        let parser = DefaultFFetchHTMLParser()
        let html = ""

        let document = try parser.parse(html)
        XCTAssertNotNil(document)
    }

    func testDefaultFFetchHTMLParserMalformedHTML() throws {
        let parser = DefaultFFetchHTMLParser()
        let html = "<html><body><h1>Test</body></html>" // Missing closing h1 tag

        // SwiftSoup should handle malformed HTML gracefully
        let document = try parser.parse(html)
        XCTAssertNotNil(document)
        XCTAssertEqual(try document.select("h1").text(), "Test")
    }

    // MARK: - FFetchContext Tests

    func testFFetchContextDefaultInit() {
        let context = FFetchContext()

        XCTAssertEqual(context.chunkSize, 255)
        XCTAssertFalse(context.cacheReload)
        XCTAssertEqual(context.cacheConfig.policy, .useProtocolCachePolicy)
        XCTAssertNil(context.sheetName)
        XCTAssertNotNil(context.httpClient)
        XCTAssertNotNil(context.htmlParser)
        XCTAssertNil(context.total)
        XCTAssertEqual(context.maxConcurrency, 5)
        XCTAssertTrue(context.allowedHosts.isEmpty)
    }

    func testFFetchContextCustomInit() {
        let customClient = DefaultFFetchHTTPClient()
        let customParser = DefaultFFetchHTMLParser()
        let customCacheConfig = FFetchCacheConfig.noCache
        let allowedHosts: Set<String> = ["example.com", "trusted.com"]

        let context = FFetchContext(
            chunkSize: 100,
            cacheReload: true,
            cacheConfig: customCacheConfig,
            sheetName: "TestSheet",
            httpClient: customClient,
            htmlParser: customParser,
            total: 500,
            maxConcurrency: 10,
            allowedHosts: allowedHosts
        )

        XCTAssertEqual(context.chunkSize, 100)
        XCTAssertTrue(context.cacheReload)
        XCTAssertEqual(context.cacheConfig.policy, .reloadIgnoringLocalCacheData)
        XCTAssertEqual(context.sheetName, "TestSheet")
        XCTAssertNotNil(context.httpClient)
        XCTAssertNotNil(context.htmlParser)
        XCTAssertEqual(context.total, 500)
        XCTAssertEqual(context.maxConcurrency, 10)
        XCTAssertEqual(context.allowedHosts, allowedHosts)
    }

    func testFFetchContextBackwardCompatibilityCacheReload() {
        // Test backward compatibility: cacheReload = true should set noCache config
        let context = FFetchContext(cacheReload: true)
        XCTAssertTrue(context.cacheReload)
        XCTAssertEqual(context.cacheConfig.policy, .reloadIgnoringLocalCacheData)
    }

    func testFFetchContextBackwardCompatibilityCacheNoReload() {
        // Test backward compatibility: cacheReload = false should set default config
        let context = FFetchContext(cacheReload: false)
        XCTAssertFalse(context.cacheReload)
        XCTAssertEqual(context.cacheConfig.policy, .useProtocolCachePolicy)
    }

    func testFFetchContextExplicitCacheConfigOverridesReload() {
        // When both cacheReload and cacheConfig are provided, cacheConfig should take precedence
        let customConfig = FFetchCacheConfig.cacheOnly
        let context = FFetchContext(cacheReload: true, cacheConfig: customConfig)

        XCTAssertTrue(context.cacheReload)
        XCTAssertEqual(context.cacheConfig.policy, .returnCacheDataDontLoad)
    }

    func testFFetchContextPartialInit() {
        let context = FFetchContext(
            chunkSize: 50,
            maxConcurrency: 3
        )

        XCTAssertEqual(context.chunkSize, 50)
        XCTAssertFalse(context.cacheReload)
        XCTAssertEqual(context.cacheConfig.policy, .useProtocolCachePolicy)
        XCTAssertNil(context.sheetName)
        XCTAssertNotNil(context.httpClient)
        XCTAssertNotNil(context.htmlParser)
        XCTAssertNil(context.total)
        XCTAssertEqual(context.maxConcurrency, 3)
        XCTAssertTrue(context.allowedHosts.isEmpty)
    }

    // MARK: - Type Safety Edge Cases

    func testFFetchEntryTypealias() {
        let entry: FFetchEntry = ["key": "value", "number": 42]
        XCTAssertEqual(entry["key"] as? String, "value")
        XCTAssertEqual(entry["number"] as? Int, 42)
    }

    func testFFetchTransformTypealias() async throws {
        let transform: FFetchTransform<String, Int> = { input in
            return input.count
        }

        let result = try await transform("hello")
        XCTAssertEqual(result, 5)
    }

    func testFFetchPredicateTypealias() async throws {
        let predicate: FFetchPredicate<String> = { input in
            return input.count > 3
        }

        let result1 = try await predicate("hello")
        let result2 = try await predicate("hi")
        XCTAssertTrue(result1)
        XCTAssertFalse(result2)
    }
}
