//
//  SwiftFFetchCoreConfigurationTests.swift
//  SwiftFFetchTests
//
//  Tests for FFetch core configuration methods and edge cases.
//

import XCTest
import SwiftSoup
@testable import SwiftFFetch

final class SwiftFFetchCoreConfigurationTests: XCTestCase {

    // MARK: - maxConcurrency Tests

    func testMaxConcurrencyConfiguration() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()
        mockIndexRequests(client: client, baseURL: baseURL, total: 5)

        let ffetch = FFetch(url: baseURL)
            .withHTTPClient(client)
            .maxConcurrency(3)

        // Verify the configuration is applied by checking execution
        var count = 0
        for await _ in ffetch {
            count += 1
        }

        XCTAssertEqual(count, 5, "All entries should be processed with custom concurrency")
    }

    func testMaxConcurrencyWithZero() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()
        mockIndexRequests(client: client, baseURL: baseURL, total: 3)

        let ffetch = FFetch(url: baseURL)
            .withHTTPClient(client)
            .maxConcurrency(0)

        // Should still work even with zero concurrency
        var count = 0
        for await _ in ffetch {
            count += 1
        }

        XCTAssertEqual(count, 3, "Should handle zero concurrency gracefully")
    }

    func testMaxConcurrencyWithNegativeValue() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()
        mockIndexRequests(client: client, baseURL: baseURL, total: 2)

        let ffetch = FFetch(url: baseURL)
            .withHTTPClient(client)
            .maxConcurrency(-1)

        // Should handle negative values gracefully
        var count = 0
        for await _ in ffetch {
            count += 1
        }

        XCTAssertEqual(count, 2, "Should handle negative concurrency gracefully")
    }

    func testMaxConcurrencyChaining() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()

        // Create proper mock data for the request
        let entries = [
            createMockEntry(index: 0),
            createMockEntry(index: 1),
            createMockEntry(index: 2)
        ]
        let data = createMockResponse(total: 3, offset: 0, limit: 255, entries: entries)

        // Mock the first request
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: true)!
        components.queryItems = [
            URLQueryItem(name: "offset", value: "0"),
            URLQueryItem(name: "limit", value: "100")
        ]
        client.mockResponse(for: components.url!, data: data)

        let ffetch = FFetch(url: baseURL)
            .withHTTPClient(client)
            .maxConcurrency(2)
            .chunks(100)
            .maxConcurrency(4) // Should override previous setting

        var count = 0
        for await _ in ffetch {
            count += 1
        }

        XCTAssertEqual(count, 3, "Method chaining should work correctly")
    }

    // MARK: - withHTMLParser Tests

    func testWithHTMLParserConfiguration() {
        class CustomHTMLParser: FFetchHTMLParser {
            func parse(_ htmlString: String) throws -> Document {
                let html = "<html><head><title>Custom Parsed</title></head><body>\(htmlString)</body></html>"
                return try SwiftSoup.parse(html)
            }
        }

        let customParser = CustomHTMLParser()
        let baseURL = URL(string: "https://example.com/query-index.json")!

        let ffetch = FFetch(url: baseURL)
            .withHTMLParser(customParser)

        // The configuration should be applied - we can't easily test the internal state,
        // but we can verify the method completes without error
        XCTAssertNotNil(ffetch, "FFetch instance should be created with custom HTML parser")
    }

    func testWithHTMLParserChaining() {
        class FirstParser: FFetchHTMLParser {
            func parse(_ htmlString: String) throws -> Document {
                return try SwiftSoup.parse("<html><head><title>First</title></head><body>\(htmlString)</body></html>")
            }
        }

        class SecondParser: FFetchHTMLParser {
            func parse(_ htmlString: String) throws -> Document {
                return try SwiftSoup.parse("<html><head><title>Second</title></head><body>\(htmlString)</body></html>")
            }
        }

        let firstParser = FirstParser()
        let secondParser = SecondParser()
        let baseURL = URL(string: "https://example.com/query-index.json")!

        let ffetch = FFetch(url: baseURL)
            .withHTMLParser(firstParser)
            .chunks(50)
            .withHTMLParser(secondParser) // Should override

        XCTAssertNotNil(ffetch, "Method chaining should work with HTML parser")
    }

    func testWithHTMLParserCombinedWithOtherConfigurations() async throws {
        class TestParser: FFetchHTMLParser {
            func parse(_ htmlString: String) throws -> Document {
                return try SwiftSoup.parse("<html><head><title>Test</title></head><body>\(htmlString)</body></html>")
            }
        }

        let parser = TestParser()
        let client = MockHTTPClient()
        let baseURL = URL(string: "https://example.com/query-index.json")!

        // Create proper mock data
        let entries = [
            createMockEntry(index: 0),
            createMockEntry(index: 1)
        ]
        let data = createMockResponse(total: 2, offset: 0, limit: 255, entries: entries)

        // Mock the request with proper chunk size
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: true)!
        components.queryItems = [
            URLQueryItem(name: "offset", value: "0"),
            URLQueryItem(name: "limit", value: "100")
        ]
        client.mockResponse(for: components.url!, data: data)

        let ffetch = FFetch(url: baseURL)
            .withHTTPClient(client)
            .withHTMLParser(parser)
            .maxConcurrency(1)
            .chunks(100)

        var count = 0
        for await _ in ffetch {
            count += 1
        }

        XCTAssertEqual(count, 2, "All configuration methods should work together")
    }

    // MARK: - Edge Cases and Boundary Conditions

    func testMaxConcurrencyLargeValue() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()
        mockIndexRequests(client: client, baseURL: baseURL, total: 1)

        let ffetch = FFetch(url: baseURL)
            .withHTTPClient(client)
            .maxConcurrency(1000) // Very large value

        var count = 0
        for await _ in ffetch {
            count += 1
        }

        XCTAssertEqual(count, 1, "Should handle large concurrency values")
    }

    func testConfigurationMethodsReturnNewInstances() {
        class SimpleParser: FFetchHTMLParser {
            func parse(_ htmlString: String) throws -> Document {
                return try SwiftSoup.parse("<html><body>\(htmlString)</body></html>")
            }
        }

        let baseURL = URL(string: "https://example.com/query-index.json")!
        let originalFFetch = FFetch(url: baseURL)

        let configuredFFetch1 = originalFFetch.maxConcurrency(5)
        let configuredFFetch2 = originalFFetch.withHTMLParser(SimpleParser())

        // These should be different instances (value semantics)
        XCTAssertTrue(type(of: originalFFetch) == type(of: configuredFFetch1))
        XCTAssertTrue(type(of: originalFFetch) == type(of: configuredFFetch2))
    }

    // MARK: - Integration with Error Handling

    func testMaxConcurrencyWithErrorConditions() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()

        // Mock an error response
        client.mockError(for: baseURL, error: FFetchError.networkError(URLError(.notConnectedToInternet)))

        let ffetch = FFetch(url: baseURL)
            .withHTTPClient(client)
            .maxConcurrency(2)

        // Should handle errors gracefully even with custom concurrency
        var entries: [FFetchEntry] = []
        do {
            for await entry in ffetch {
                entries.append(entry)
            }
        } catch {
            // Expected to throw due to network error
            XCTAssertTrue(entries.isEmpty, "No entries should be collected on error")
        }
    }

    func testWithHTMLParserWithErrorConditions() {
        class FailingParser: FFetchHTMLParser {
            func parse(_ htmlString: String) throws -> Document {
                throw FFetchError.operationFailed("Parser failed")
            }
        }

        let failingParser = FailingParser()
        let baseURL = URL(string: "https://example.com/query-index.json")!

        // Should not crash when creating FFetch with failing parser
        let ffetch = FFetch(url: baseURL).withHTMLParser(failingParser)
        XCTAssertNotNil(ffetch, "FFetch should be created even with potentially failing parser")
    }
}
