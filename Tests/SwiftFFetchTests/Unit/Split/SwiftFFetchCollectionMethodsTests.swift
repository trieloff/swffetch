//
//  SwiftFFetchCollectionMethodsTests.swift
//  SwiftFFetchTests
//
//  Tests for collection methods in FFetch: .all, .first, .count
//

import XCTest
@testable import SwiftFFetch

final class SwiftFFetchCollectionMethodsTests: XCTestCase {

    func testAllMethod() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()
        mockIndexRequests(client: client, baseURL: baseURL, total: 5)

        let allEntries = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .all()

        XCTAssertEqual(allEntries.count, 5)

        for (index, entry) in allEntries.enumerated() {
            XCTAssertEqual(entry["title"] as? String, "Entry \(index)")
        }
    }

    func testFirstMethod() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()
        mockIndexRequests(client: client, baseURL: baseURL, total: 5)

        let firstEntry = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .first()

        XCTAssertNotNil(firstEntry)
        XCTAssertEqual(firstEntry?["title"] as? String, "Entry 0")
    }

    func testFirstMethodWithEmptyResult() async throws {
        let baseURL = URL(string: "https://example.com/not-found.json")!
        let client = MockHTTPClient()
        // Don't add any mock responses

        let firstEntry = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .first()

        XCTAssertNil(firstEntry)
    }

    func testCountMethod() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()
        mockIndexRequests(client: client, baseURL: baseURL, total: 15)

        let count = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .count()

        XCTAssertEqual(count, 15)
    }
}
