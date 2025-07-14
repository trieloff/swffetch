//
//  SwiftFFetchInitializationTests.swift
//  SwiftFFetchTests
//
//  Tests for FFetch initialization and convenience functions.
//

import XCTest
@testable import SwiftFFetch

final class SwiftFFetchInitializationTests: XCTestCase {

    func testFFetchInitialization() throws {
        let ffetch = try FFetch(url: "https://example.com/index.json")
        XCTAssertNotNil(ffetch)
    }

    func testFFetchInitializationWithInvalidURL() {
        XCTAssertThrowsError(try FFetch(url: "")) { error in
            XCTAssertTrue(error is FFetchError)
            if case .invalidURL = error as? FFetchError {
                // Expected
            } else {
                XCTFail("Expected invalidURL error")
            }
        }
    }

    func testConvenienceFunction() throws {
        let ffetch1 = try ffetch("https://example.com/index.json")
        guard let url = URL(string: "https://example.com/index.json") else {
            XCTFail("Failed to create URL")
            return
        }
        let ffetch2 = ffetch(url)

        XCTAssertNotNil(ffetch1)
        XCTAssertNotNil(ffetch2)
    }

    func testFFetchInitializationWithComplexURLs() throws {
        // Test various URL formats to ensure robust initialization
        let testURLs = [
            "https://example.com/path/to/resource.json",
            "https://example.com:8080/api/data.json",
            "https://subdomain.example.com/query-index.json",
            "https://example.com/path%20with%20spaces.json"
        ]

        for urlString in testURLs {
            let ffetch = try FFetch(url: urlString)
            XCTAssertNotNil(ffetch)
            XCTAssertEqual(ffetch.url.absoluteString, urlString)
        }
    }

    func testFFetchInitializationPerformance() throws {
        // Test initialization performance with many instances
        let urlString = "https://example.com/data.json"

        let startTime = CFAbsoluteTimeGetCurrent()
        for _ in 0..<100 {
            _ = try FFetch(url: urlString)
        }
        let endTime = CFAbsoluteTimeGetCurrent()

        // Basic performance check - should complete quickly
        let duration = endTime - startTime
        XCTAssertLessThan(duration, 1.0, "Initialization should be fast")
    }

    func testFFetchConvenienceFunctionEquivalence() throws {
        // Ensure convenience functions produce equivalent results
        let urlString = "https://example.com/test.json"
        let url = URL(string: urlString)!

        let ffetch1 = try ffetch(urlString)
        let ffetch2 = ffetch(url)

        XCTAssertEqual(ffetch1.url, ffetch2.url)
        XCTAssertEqual(ffetch1.context.chunkSize, ffetch2.context.chunkSize)
        XCTAssertEqual(ffetch1.context.maxConcurrency, ffetch2.context.maxConcurrency)
    }

    func testFFetchInitializationURLComponents() throws {
        // Test URL component extraction during initialization
        let urlString = "https://api.example.com:443/v1/data.json"
        let ffetch = try FFetch(url: urlString)

        XCTAssertEqual(ffetch.url.scheme, "https")
        XCTAssertEqual(ffetch.url.host, "api.example.com")
        XCTAssertEqual(ffetch.url.port, 443)
        XCTAssertEqual(ffetch.url.path, "/v1/data.json")
    }
}
