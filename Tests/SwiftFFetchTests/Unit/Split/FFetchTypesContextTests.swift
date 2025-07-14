//
//  FFetchTypesContextTests.swift
//  SwiftFFetchTests
//
//  Focused tests for FFetchContext type
//
import XCTest
import Foundation
@testable import SwiftFFetch

final class FFetchTypesContextTests: XCTestCase {

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

    // MARK: - FFetchContext Edge Cases Tests

    func testFFetchContextWithZeroChunkSize() {
        let context = FFetchContext(chunkSize: 0)
        XCTAssertEqual(context.chunkSize, 0)
    }

    func testFFetchContextWithNegativeChunkSize() {
        let context = FFetchContext(chunkSize: -1)
        XCTAssertEqual(context.chunkSize, -1)
    }

    func testFFetchContextWithVeryLargeChunkSize() {
        let largeChunkSize = Int.max
        let context = FFetchContext(chunkSize: largeChunkSize)
        XCTAssertEqual(context.chunkSize, largeChunkSize)
    }

    func testFFetchContextWithZeroMaxConcurrency() {
        let context = FFetchContext(maxConcurrency: 0)
        XCTAssertEqual(context.maxConcurrency, 0)
    }

    func testFFetchContextWithSingleHostInAllowedHosts() {
        let allowedHosts: Set<String> = ["example.com"]
        let context = FFetchContext(allowedHosts: allowedHosts)
        XCTAssertEqual(context.allowedHosts, allowedHosts)
    }

    func testFFetchContextWithMultipleHostsInAllowedHosts() {
        let allowedHosts: Set<String> = ["example.com", "test.com", "api.example.com"]
        let context = FFetchContext(allowedHosts: allowedHosts)
        XCTAssertEqual(context.allowedHosts.count, 3)
        XCTAssertTrue(context.allowedHosts.contains("example.com"))
        XCTAssertTrue(context.allowedHosts.contains("test.com"))
    }

    func testFFetchContextWithEmptyAllowedHosts() {
        let context = FFetchContext(allowedHosts: [])
        XCTAssertTrue(context.allowedHosts.isEmpty)
    }

    func testFFetchContextWithWildcardInAllowedHosts() {
        let allowedHosts: Set<String> = ["*"]
        let context = FFetchContext(allowedHosts: allowedHosts)
        XCTAssertEqual(context.allowedHosts, ["*"])
    }

    func testFFetchContextComplexInitialization() {
        let customCache = URLCache(memoryCapacity: 1024, diskCapacity: 2048)
        let customClient = DefaultFFetchHTTPClient(cache: customCache)
        let customParser = DefaultFFetchHTMLParser()
        let customCacheConfig = FFetchCacheConfig(
            policy: .reloadRevalidatingCacheData,
            cache: customCache,
            maxAge: 7200,
            ignoreServerCacheControl: true
        )
        let allowedHosts: Set<String> = ["secure.example.com", "api.trusted.com"]

        let context = FFetchContext(
            chunkSize: 1000,
            cacheReload: false,
            cacheConfig: customCacheConfig,
            sheetName: "AdvancedSheet",
            httpClient: customClient,
            htmlParser: customParser,
            total: 10000,
            maxConcurrency: 20,
            allowedHosts: allowedHosts
        )

        XCTAssertEqual(context.chunkSize, 1000)
        XCTAssertFalse(context.cacheReload)
        XCTAssertEqual(context.cacheConfig.policy, .reloadRevalidatingCacheData)
        XCTAssertEqual(context.sheetName, "AdvancedSheet")
        XCTAssertTrue(context.httpClient is DefaultFFetchHTTPClient)
        XCTAssertTrue(context.htmlParser is DefaultFFetchHTMLParser)
        XCTAssertEqual(context.total, 10000)
        XCTAssertEqual(context.maxConcurrency, 20)
        XCTAssertEqual(context.allowedHosts, allowedHosts)
    }

    func testFFetchContextCacheConfigOverrideLogic() {
        // Test that cacheConfig overrides cacheReload when provided
        let context1 = FFetchContext(cacheReload: true, cacheConfig: FFetchCacheConfig.default)
        XCTAssertEqual(context1.cacheConfig.policy, .useProtocolCachePolicy) // Should be default, not noCache

        let context2 = FFetchContext(cacheReload: false, cacheConfig: FFetchCacheConfig.noCache)
        XCTAssertEqual(context2.cacheConfig.policy, .reloadIgnoringLocalCacheData) // Should be noCache, not default
    }

    // MARK: - Integration Tests with Mock Objects

    func testFFetchContextWithMockHTTPClient() async throws {
        let mockClient = MockFFetchHTTPClient()
        let context = FFetchContext(httpClient: mockClient)

        XCTAssertTrue(context.httpClient is MockFFetchHTTPClient)
    }

    func testFFetchContextWithMockHTMLParser() {
        let mockParser = MockFFetchHTMLParser()
        let context = FFetchContext(htmlParser: mockParser)

        XCTAssertTrue(context.htmlParser is MockFFetchHTMLParser)
    }

    func testFFetchContextWithMockObjectsAndErrorHandling() async {
        let mockClient = MockFFetchHTTPClient()
        mockClient.shouldThrowError = true

        let context = FFetchContext(httpClient: mockClient)
        let url = URL(string: "https://example.com")!

        // This tests the error handling path
        do {
            _ = try await context.httpClient.fetch(url, cacheConfig: .default)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is FFetchError)
        }
    }
}
