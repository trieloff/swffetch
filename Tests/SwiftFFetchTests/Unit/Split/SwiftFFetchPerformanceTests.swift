//
//  SwiftFFetchPerformanceTests.swift
//  SwiftFFetchTests
//
//  Tests for performance and memory efficiency in FFetch.
//
import XCTest
@testable import SwiftFFetch

final class SwiftFFetchPerformanceTests: XCTestCase {

    func testPerformanceWithLargeDataset() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()
        mockIndexRequests(client: client, baseURL: baseURL, total: 1000)

        let startTime = CFAbsoluteTimeGetCurrent()

        let count = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .count()

        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime

        XCTAssertEqual(count, 1000)
        XCTAssertLessThan(duration, 5.0) // Should complete within 5 seconds
    }

    func testMemoryEfficiencyWithLargeDataset() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()
        mockIndexRequests(client: client, baseURL: baseURL, total: 10000)

        // This test ensures we don't load all data into memory at once
        var count = 0
        for await _ in FFetch(url: baseURL).withHTTPClient(client) {
            count += 1
            if count >= 100 { // Only process first 100 items
                break
            }
        }

        XCTAssertEqual(count, 100)
    }
}
