//
//  StreamingTests.swift
//  SwiftFFetchTests
//
//  Tests for streaming entries from FFetch
//

import XCTest
@testable import SwiftFFetch

final class StreamingTests: XCTestCase {

    func testBasicStreaming() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()
        mockIndexRequests(client: client, baseURL: baseURL, total: 10)

        let ffetch = FFetch(url: baseURL).withHTTPClient(client)
        var count = 0

        for await entry in ffetch {
            XCTAssertEqual(entry["title"] as? String, "Entry \(count)")
            count += 1
        }

        XCTAssertEqual(count, 10)
    }

    func testLargeDatasetStreaming() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()
        mockIndexRequests(client: client, baseURL: baseURL, total: 555)

        let ffetch = FFetch(url: baseURL).withHTTPClient(client)
        var count = 0

        for await entry in ffetch {
            XCTAssertEqual(entry["title"] as? String, "Entry \(count)")
            count += 1
        }

        XCTAssertEqual(count, 555)
    }

    func testCustomChunkSize() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()
        mockIndexRequests(client: client, baseURL: baseURL, total: 100, chunkSize: 10)

        let ffetch = FFetch(url: baseURL)
            .withHTTPClient(client)
            .chunks(10)

        var count = 0
        for await entry in ffetch {
            XCTAssertEqual(entry["title"] as? String, "Entry \(count)")
            count += 1
        }

        XCTAssertEqual(count, 100)
    }
}
