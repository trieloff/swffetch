//
//  SwiftFFetchTransformationTests.swift
//  SwiftFFetchTests
//
//  Tests for transformation operations in FFetch: map, filter, limit, skip, slice, chaining.
//
import XCTest
@testable import SwiftFFetch

final class SwiftFFetchTransformationTests: XCTestCase {

    func testMapOperation() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()
        mockIndexRequests(client: client, baseURL: baseURL, total: 10)

        let titles = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .map { entry in
                return entry["title"] as? String ?? "No title"
            }
            .all()

        XCTAssertEqual(titles.count, 10)
        for (index, title) in titles.enumerated() {
            XCTAssertEqual(title, "Entry \(index)")
        }
    }

    func testFilterOperation() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()
        mockIndexRequests(client: client, baseURL: baseURL, total: 10)

        let publishedEntries = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .filter { entry in
                return (entry["published"] as? Bool) == true
            }
            .all()

        // Should have 5 published entries (even indices: 0, 2, 4, 6, 8)
        XCTAssertEqual(publishedEntries.count, 5)

        for entry in publishedEntries {
            XCTAssertTrue((entry["published"] as? Bool) == true)
        }
    }

    func testLimitOperation() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()
        mockIndexRequests(client: client, baseURL: baseURL, total: 100)

        let limitedEntries = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .limit(10)
            .all()

        XCTAssertEqual(limitedEntries.count, 10)

        for (index, entry) in limitedEntries.enumerated() {
            XCTAssertEqual(entry["title"] as? String, "Entry \(index)")
        }
    }

    func testSkipOperation() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()
        mockIndexRequests(client: client, baseURL: baseURL, total: 20)

        let skippedEntries = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .skip(10)
            .all()

        XCTAssertEqual(skippedEntries.count, 10)

        for (index, entry) in skippedEntries.enumerated() {
            XCTAssertEqual(entry["title"] as? String, "Entry \(index + 10)")
        }
    }

    func testSliceOperation() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()
        mockIndexRequests(client: client, baseURL: baseURL, total: 20)

        let slicedEntries = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .slice(5, 10)
            .all()

        XCTAssertEqual(slicedEntries.count, 5)

        for (index, entry) in slicedEntries.enumerated() {
            XCTAssertEqual(entry["title"] as? String, "Entry \(index + 5)")
        }
    }

    func testComplexChaining() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()
        mockIndexRequests(client: client, baseURL: baseURL, total: 100)

        let result = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .filter { entry in
                return (entry["published"] as? Bool) == true
            }
            .map { entry in
                return (entry["title"] as? String ?? "").uppercased()
            }
            .limit(3)
            .all()

        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result[0], "ENTRY 0")
        XCTAssertEqual(result[1], "ENTRY 2")
        XCTAssertEqual(result[2], "ENTRY 4")
    }
}
