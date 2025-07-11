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

        // Use a smaller chunk size to force multiple requests
        let chunkSize = 10

        // Mock successful first page (10 entries)
        mockBlogIndex(client: client, total: 20, chunkSize: chunkSize)

        // Mock an error for the second page request
        let errorURL = "https://example.com/blog-index.json?offset=10&limit=10"
        client.mockError(for: errorURL, error: URLError(.networkConnectionLost))

        let ffetch = FFetch(url: URL(string: "https://example.com/blog-index.json")!)
            .withHTTPClient(client)
            .chunks(chunkSize)

        var entries: [FFetchEntry] = []

        // The current implementation handles errors gracefully by stopping iteration
        // without propagating the error, so we just count the entries we get
        for await entry in ffetch {
            entries.append(entry)
        }

        // Should have received entries from first page only (10 entries)
        // Second page request fails but error is handled gracefully
        XCTAssertEqual(entries.count, 10)

        // Verify we got the expected entries from the first page
        XCTAssertEqual(entries.count, 10)
        for (index, entry) in entries.enumerated() {
            XCTAssertEqual(entry["id"] as? Int, index)
        }
    }
}
