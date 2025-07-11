//
//  SwiftFFetchSheetTests.swift
//  SwiftFFetchTests
//
//  Tests for sheet selection functionality in FFetch.
//
import XCTest
@testable import SwiftFFetch

final class SwiftFFetchSheetTests: XCTestCase {

    func testSheetSelection() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()
        mockIndexRequests(client: client, baseURL: baseURL, total: 10, sheet: "products")

        let ffetch = FFetch(url: baseURL)
            .withHTTPClient(client)
            .sheet("products")

        var count = 0
        for await entry in ffetch {
            XCTAssertEqual(entry["title"] as? String, "Entry \(count)")
            count += 1
        }

        XCTAssertEqual(count, 10)
    }
}
