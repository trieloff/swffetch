//
//  SwiftFFetchTransformationErrorTests.swift
//  SwiftFFetchTests
//
//  Tests for error handling and edge cases in FFetch transformation operations.
//
import XCTest
@testable import SwiftFFetch

final class SwiftFFetchTransformationErrorTests: XCTestCase {

    // MARK: - Error Handling Tests

    func testMapOperationWithError() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()
        mockIndexRequests(client: client, baseURL: baseURL, total: 5)

        let results = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .map { entry in
                let title = entry["title"] as? String ?? ""
                if title.contains("2") {
                    throw URLError(.badURL)
                }
                return title.uppercased()
            }
            .all()

        // Should have fewer than 5 results (error handling for Entry 2)
        XCTAssertLessThan(results.count, 5)
        // Check that at least some results were processed
        XCTAssertGreaterThan(results.count, 0)
        // Verify that the error-inducing entry is not present
        for result in results {
            XCTAssertFalse(result.contains("2"))
        }
    }

    func testFilterOperationWithError() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()
        mockIndexRequests(client: client, baseURL: baseURL, total: 5)

        let results = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .filter { entry in
                let title = entry["title"] as? String ?? ""
                if title.contains("3") {
                    throw URLError(.badURL)
                }
                return title.contains("1") || title.contains("4")
            }
            .all()

        // Should have fewer than 5 results due to filtering and error handling
        XCTAssertLessThan(results.count, 5)
        // Verify that results don't contain the error-inducing entry
        for entry in results {
            let title = entry["title"] as? String ?? ""
            XCTAssertFalse(title.contains("3"))
        }
    }

    // MARK: - Concurrency Tests

    func testMapOperationWithConcurrencyLimit() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()
        mockIndexRequests(client: client, baseURL: baseURL, total: 15)

        let context = FFetchContext(
            chunkSize: 255,
            httpClient: client,
            maxConcurrency: 3
        )

        let startTime = Date()
        let results = try await FFetch(url: baseURL, context: context)
            .map { entry in
                // Simulate async work
                try await Task.sleep(nanoseconds: 10_000_000) // 10ms
                return (entry["title"] as? String ?? "").uppercased()
            }
            .all()
        let duration = Date().timeIntervalSince(startTime)

        XCTAssertEqual(results.count, 15)
        // With concurrency limit of 3, it should process batches
        // This is more of a behavioral test than strict timing
        XCTAssertTrue(duration > 0.01) // At least some time passed
    }

    // MARK: - Edge Cases

    func testLimitZero() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()
        mockIndexRequests(client: client, baseURL: baseURL, total: 10)

        let results = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .limit(0)
            .all()

        XCTAssertEqual(results.count, 0)
    }

    func testSkipZero() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()
        mockIndexRequests(client: client, baseURL: baseURL, total: 5)

        let results = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .skip(0)
            .all()

        XCTAssertEqual(results.count, 5)
        for (index, entry) in results.enumerated() {
            XCTAssertEqual(entry["title"] as? String, "Entry \(index)")
        }
    }

    func testSkipMoreThanAvailable() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()
        mockIndexRequests(client: client, baseURL: baseURL, total: 5)

        let results = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .skip(10)
            .all()

        XCTAssertEqual(results.count, 0)
    }

    func testSliceEdgeCases() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()
        mockIndexRequests(client: client, baseURL: baseURL, total: 10)

        // Test slice with same start and end
        let emptySlice = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .slice(3, 3)
            .all()
        XCTAssertEqual(emptySlice.count, 0)

        // Test slice beyond available data
        let beyondSlice = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .slice(8, 15)
            .all()
        XCTAssertEqual(beyondSlice.count, 2) // Only entries 8 and 9 available
    }
}
