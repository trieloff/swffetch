//
//  MockedIntegrationResilienceTests.swift
//  SwiftFFetchTests
//
//  Tests for error recovery and resilience in integration scenarios.
//

import XCTest
@testable import SwiftFFetch

final class MockedIntegrationResilienceTests: XCTestCase {

    func testErrorRecoveryAndResilience() async throws {
        let client = AdvancedMockHTTPClient()

        // Simulate a blog index with some errors
        mockBlogIndex(client: client, total: 20)
        // Simulate a network error for a specific post
        let errorURL = "https://example.com/blog/post-5"
        client.mockError(for: errorURL, error: URLError(.networkConnectionLost))

        let ffetch = FFetch(url: URL(string: "https://example.com/blog-index.json")!)
            .withHTTPClient(client)

        var recoveredCount = 0
        let errorCount = 0

        for try await entry in ffetch {
            if let path = entry["path"] as? String, path == "/blog/post-5" {
                // Should not reach here, error should be thrown
                XCTFail("Should not yield entry for post-5 due to error")
            } else {
                recoveredCount += 1
            }
        }

        // Now try with error-tolerant logic
        let tolerantFFetch = FFetch(url: URL(string: "https://example.com/blog-index.json")!)
            .withHTTPClient(client)

        var entries: [FFetchEntry] = []
        for try await entry in tolerantFFetch {
            entries.append(entry)
        }

        // Should have one error and 19 successful entries
        XCTAssertEqual(entries.count, 19)
        XCTAssertEqual(errorCount, 1)
    }
}
