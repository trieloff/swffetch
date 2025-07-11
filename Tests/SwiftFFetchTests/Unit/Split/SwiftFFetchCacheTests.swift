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
}
