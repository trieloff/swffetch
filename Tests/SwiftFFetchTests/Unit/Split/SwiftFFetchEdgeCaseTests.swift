//
//  SwiftFFetchEdgeCaseTests.swift
//  SwiftFFetchTests
//
//  Tests for edge cases in FFetch: empty result, single entry, exact chunk boundary.
//
import XCTest
@testable import SwiftFFetch

final class SwiftFFetchEdgeCaseTests: XCTestCase {

    func testEmptyResult() async throws {
        let baseURL = URL(string: "https://example.com/empty.json")!
        let client = MockHTTPClient()
        mockIndexRequests(client: client, baseURL: baseURL, total: 0)

        let entries = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .all()

        XCTAssertEqual(entries.count, 0)
    }

    func testSingleEntry() async throws {
        let baseURL = URL(string: "https://example.com/single.json")!
        let client = MockHTTPClient()
        mockIndexRequests(client: client, baseURL: baseURL, total: 1)

        let entries = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .all()

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0]["title"] as? String, "Entry 0")
    }

    func testExactChunkBoundary() async throws {
        let baseURL = URL(string: "https://example.com/boundary.json")!
        let client = MockHTTPClient()
        mockIndexRequests(client: client, baseURL: baseURL, total: 255, chunkSize: 255)

        let entries = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .chunks(255)
            .all()

        XCTAssertEqual(entries.count, 255)
    }
}
