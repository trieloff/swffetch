//
//  SwiftFFetchMappedTransformationTests.swift
//  SwiftFFetchTests
//
//  Tests for FFetchMapped transformation operations: map, filter, limit, skip, slice, error handling.
//
import XCTest
@testable import SwiftFFetch

final class SwiftFFetchMappedTransformationTests: XCTestCase {

    // MARK: - FFetchMapped Tests

    func testMappedMapOperation() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()
        mockIndexRequests(client: client, baseURL: baseURL, total: 5)

        let results = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .map { entry in
                return entry["title"] as? String ?? "No title"
            }
            .map { title in
                return title.uppercased()
            }
            .all()

        XCTAssertEqual(results.count, 5)
        for (index, result) in results.enumerated() {
            XCTAssertEqual(result, "ENTRY \(index)")
        }
    }

    func testMappedFilterOperation() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()
        mockIndexRequests(client: client, baseURL: baseURL, total: 10)

        let results = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .map { entry in
                let title = entry["title"] as? String ?? ""
                let components = title.components(separatedBy: " ")
                if components.count > 1, let lastComponent = components.last {
                    return Int(lastComponent) ?? 0
                }
                return 0
            }
            .filter { number in
                return number % 2 == 0
            }
            .all()

        XCTAssertEqual(results.count, 5)
        XCTAssertEqual(results, [0, 2, 4, 6, 8])
    }

    func testMappedLimitOperation() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()
        mockIndexRequests(client: client, baseURL: baseURL, total: 20)

        let results = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .map { entry in
                return entry["title"] as? String ?? ""
            }
            .limit(3)
            .all()

        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(results[0], "Entry 0")
        XCTAssertEqual(results[1], "Entry 1")
        XCTAssertEqual(results[2], "Entry 2")
    }

    func testMappedSkipOperation() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()
        mockIndexRequests(client: client, baseURL: baseURL, total: 10)

        let results = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .map { entry in
                return entry["title"] as? String ?? ""
            }
            .skip(7)
            .all()

        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(results[0], "Entry 7")
        XCTAssertEqual(results[1], "Entry 8")
        XCTAssertEqual(results[2], "Entry 9")
    }

    func testMappedSliceOperation() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()
        mockIndexRequests(client: client, baseURL: baseURL, total: 20)

        let results = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .map { entry in
                return entry["title"] as? String ?? ""
            }
            .slice(5, 8)
            .all()

        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(results[0], "Entry 5")
        XCTAssertEqual(results[1], "Entry 6")
        XCTAssertEqual(results[2], "Entry 7")
    }

    // MARK: - FFetchMapped Error Handling

    func testMappedMapWithError() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()
        mockIndexRequests(client: client, baseURL: baseURL, total: 5)

        let results = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .map { entry in
                return entry["title"] as? String ?? ""
            }
            .map { title in
                if title.contains("2") {
                    throw URLError(.badURL)
                }
                return title.uppercased()
            }
            .all()

        // Should have fewer than 5 results (error on Entry 2 causes graceful handling)
        XCTAssertLessThan(results.count, 5)
        // Check that at least some results were processed
        XCTAssertGreaterThan(results.count, 0)
        // Verify the successful transformations
        for result in results {
            XCTAssertFalse(result.contains("2"))
            XCTAssertTrue(result.starts(with: "ENTRY"))
        }
    }

    func testMappedFilterWithError() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()
        mockIndexRequests(client: client, baseURL: baseURL, total: 5)

        let results = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .map { entry in
                return entry["title"] as? String ?? ""
            }
            .filter { title in
                if title.contains("3") {
                    throw URLError(.badURL)
                }
                return title.contains("1") || title.contains("4")
            }
            .all()

        // Should have fewer than 5 results due to filtering and error handling
        XCTAssertLessThan(results.count, 5)
        // Verify that results don't contain the error-inducing entry
        for result in results {
            XCTAssertFalse(result.contains("3"))
        }
    }

    // MARK: - FFetchMapped Edge Cases

    func testMappedLimitZero() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()
        mockIndexRequests(client: client, baseURL: baseURL, total: 5)

        let results = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .map { entry in
                return entry["title"] as? String ?? ""
            }
            .limit(0)
            .all()

        XCTAssertEqual(results.count, 0)
    }

    func testMappedSkipMoreThanAvailable() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()
        mockIndexRequests(client: client, baseURL: baseURL, total: 3)

        let results = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .map { entry in
                return entry["title"] as? String ?? ""
            }
            .skip(10)
            .all()

        XCTAssertEqual(results.count, 0)
    }

    func testMappedSliceEdgeCases() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()
        mockIndexRequests(client: client, baseURL: baseURL, total: 10)

        // Test slice with same start and end
        let emptySlice = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .map { entry in
                return entry["title"] as? String ?? ""
            }
            .slice(3, 3)
            .all()
        XCTAssertEqual(emptySlice.count, 0)

        // Test slice beyond available data (need fresh client setup)
        let client2 = MockHTTPClient()
        mockIndexRequests(client: client2, baseURL: baseURL, total: 10)
        let beyondSlice = try await FFetch(url: baseURL)
            .withHTTPClient(client2)
            .map { entry in
                return entry["title"] as? String ?? ""
            }
            .slice(8, 15)
            .all()
        XCTAssertEqual(beyondSlice.count, 2) // Only entries 8 and 9 available
    }
}
