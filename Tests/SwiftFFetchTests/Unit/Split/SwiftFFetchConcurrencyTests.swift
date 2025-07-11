//
//  SwiftFFetchConcurrencyTests.swift
//  SwiftFFetchTests
//
//  Tests for max concurrency functionality in FFetch.
//
import XCTest
@testable import SwiftFFetch

final class SwiftFFetchConcurrencyTests: XCTestCase {

    func testMaxConcurrency() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()
        mockIndexRequests(client: client, baseURL: baseURL, total: 10)

        let ffetch = FFetch(url: baseURL)
            .withHTTPClient(client)
            .withMaxConcurrency(2)

        var count = 0
        for await _ in ffetch {
            count += 1
        }

        XCTAssertEqual(count, 10)
    }
}
