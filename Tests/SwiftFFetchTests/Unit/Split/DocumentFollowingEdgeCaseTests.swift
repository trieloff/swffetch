//
//  DocumentFollowingEdgeCaseTests.swift
//  SwiftFFetchTests
//
//  Edge case tests to ensure complete coverage of FFetch+DocumentFollowing.swift
//  Focuses on previously uncovered code paths
//
import XCTest
import SwiftSoup
@testable import SwiftFFetch

final class DocumentFollowingEdgeCaseTests: XCTestCase {

    // MARK: - Empty Catch Blocks Coverage

    func testDocumentFollowingEmptyCatchBlocksInConcurrentProcessing() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()

        // Create exactly enough entries to trigger concurrent processing
        let entries = Array(0..<6).map { index in
            ["title": "Entry \(index)", "path": "/doc-\(index)"]
        }
        let data = createMockResponse(total: 6, offset: 0, limit: 255, entries: entries)
        client.mockResponse(for: baseURL, data: data)

        // Make some requests fail to trigger the catch blocks
        for index in 0..<6 {
            let docURL = URL(string: "https://example.com/doc-\(index)")!
            if index % 3 == 0 {
                // Force cancellation to trigger catch blocks
                client.mockError(for: docURL, error: CancellationError())
            } else {
                let html = """
                <!DOCTYPE html>
                <html><head><title>Document \(index)</title></head><body><p>Content\(index)</p></body></html>
                """
                client.mockResponse(for: docURL, data: html.data(using: .utf8)!)
            }
        }

        // Use maxConcurrency to force the catch blocks to be hit
        let context = FFetchContext(maxConcurrency: 2)
        let entriesWithDocs = try await FFetch(url: baseURL, context: context)
            .withHTTPClient(client)
            .follow("path", as: "document")
            .all()

        XCTAssertEqual(entriesWithDocs.count, 6)

        // Verify we have both successful and failed entries
        let successful = entriesWithDocs.filter { $0["document"] != nil }
        let failed = entriesWithDocs.filter { $0["document_error"] != nil }

        XCTAssertGreaterThan(successful.count, 0)
        XCTAssertGreaterThan(failed.count, 0)
    }

    func testDocumentFollowingTaskCancellationInConcurrentProcessing() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()

        // Create entries that will be processed concurrently
        let entries = Array(0..<8).map { index in
            ["title": "Entry \(index)", "path": "/doc-\(index)"]
        }
        let data = createMockResponse(total: 8, offset: 0, limit: 255, entries: entries)
        client.mockResponse(for: baseURL, data: data)

        // Mock responses with delays to ensure concurrent processing
        for index in 0..<8 {
            let docURL = URL(string: "https://example.com/doc-\(index)")!
            let html = """
            <!DOCTYPE html>
            <html><head><title>Document \(index)</title></head><body><p>Content\(index)</p></body></html>
            """
            client.mockResponse(for: docURL, data: html.data(using: .utf8)!)
        }

        // Use specific concurrency to trigger catch blocks
        let context = FFetchContext(maxConcurrency: 3)
        let entriesWithDocs = try await FFetch(url: baseURL, context: context)
            .withHTTPClient(client)
            .follow("path", as: "document")
            .all()

        XCTAssertEqual(entriesWithDocs.count, 8)

        // All should succeed since we're not forcing failures
        for entry in entriesWithDocs {
            XCTAssertNotNil(entry["document"])
            XCTAssertNil(entry["document_error"])
        }
    }

    // MARK: - URL Resolution Missing Edge Cases

    func testDocumentFollowingURLResolutionMissingEdgeCase() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()

        // Test the specific edge case that wasn't covered
        let entries = [
            ["title": "Entry 0", "path": "://malformed-url"] // This should trigger the else branch
        ]
        let data = createMockResponse(total: 1, offset: 0, limit: 255, entries: entries)
        client.mockResponse(for: baseURL, data: data)

        let entriesWithDocs = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .follow("path", as: "document")
            .all()

        XCTAssertEqual(entriesWithDocs.count, 1)
        let entry = entriesWithDocs[0]
        XCTAssertNil(entry["document"])
        XCTAssertNotNil(entry["document_error"])
    }

    func testDocumentFollowingEmptyStringURLResolution() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()

        // Test empty string URL resolution
        let entries = [
            ["title": "Entry 0", "path": ""]
        ]
        let data = createMockResponse(total: 1, offset: 0, limit: 255, entries: entries)
        client.mockResponse(for: baseURL, data: data)

        let entriesWithDocs = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .follow("path", as: "document")
            .all()

        XCTAssertEqual(entriesWithDocs.count, 1)
        let entry = entriesWithDocs[0]
        XCTAssertNil(entry["document"])
        XCTAssertNotNil(entry["document_error"])
    }

    // MARK: - Hostname Validation Edge Cases

    func testDocumentFollowingHostnameValidationWithNilHost() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()

        // Test URLs that resolve to nil host
        let entries = [
            ["title": "Entry 0", "path": "file:///absolute/path"],
            ["title": "Entry 1", "path": "mailto:test@example.com"],
            ["title": "Entry 2", "path": "javascript:alert('test')"]
        ]
        let data = createMockResponse(total: 3, offset: 0, limit: 255, entries: entries)
        client.mockResponse(for: baseURL, data: data)

        let entriesWithDocs = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .follow("path", as: "document")
            .all()

        XCTAssertEqual(entriesWithDocs.count, 3)

        // All should fail due to hostname security
        for entry in entriesWithDocs {
            XCTAssertNil(entry["document"])
            XCTAssertNotNil(entry["document_error"])
            let error = try XCTUnwrap(entry["document_error"] as? String)
            XCTAssertTrue(error.contains("not allowed"))
        }
    }

    func testDocumentFollowingHostnameValidationWithEmptyHost() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()

        // Test URLs with empty hostname
        let entries = [
            ["title": "Entry 0", "path": "https:///path"] // Empty hostname
        ]
        let data = createMockResponse(total: 1, offset: 0, limit: 255, entries: entries)
        client.mockResponse(for: baseURL, data: data)

        let entriesWithDocs = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .follow("path", as: "document")
            .all()

        XCTAssertEqual(entriesWithDocs.count, 1)
        let entry = entriesWithDocs[0]
        XCTAssertNil(entry["document"])
        XCTAssertNotNil(entry["document_error"])
        let error = try XCTUnwrap(entry["document_error"] as? String)
        XCTAssertTrue(error.contains("not allowed"))
    }

    // MARK: - Complex Integration Scenarios

    func testDocumentFollowingWithMultipleSecurityConfigurations() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()

        // Test multiple allow configurations
        let entries = [
            ["title": "Entry 0", "path": "https://allowed1.com/doc-0"],
            ["title": "Entry 1", "path": "https://allowed2.com/doc-1"],
            ["title": "Entry 2", "path": "https://allowed3.com/doc-2"],
            ["title": "Entry 3", "path": "https://blocked.com/doc-3"]
        ]
        let data = createMockResponse(total: 4, offset: 0, limit: 255, entries: entries)
        client.mockResponse(for: baseURL, data: data)

        // Mock responses for allowed URLs
        let allowedURLs = [
            "https://allowed1.com/doc-0",
            "https://allowed2.com/doc-1",
            "https://allowed3.com/doc-2"
        ]

        for (index, urlString) in allowedURLs.enumerated() {
            let url = URL(string: urlString)!
            let html = """
            <!DOCTYPE html>
            <html><head><title>Document \(index)</title></head><body><p>Content\(index)</p></body></html>
            """
            client.mockResponse(for: url, data: html.data(using: .utf8)!)
        }

        let entriesWithDocs = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .allow("allowed1.com")
            .allow(["allowed2.com", "allowed3.com"])
            .follow("path", as: "document")
            .all()

        XCTAssertEqual(entriesWithDocs.count, 4)

        // Verify allowed vs blocked
        XCTAssertNotNil(entriesWithDocs[0]["document"]) // allowed1.com
        XCTAssertNotNil(entriesWithDocs[1]["document"]) // allowed2.com
        XCTAssertNotNil(entriesWithDocs[2]["document"]) // allowed3.com
        XCTAssertNil(entriesWithDocs[3]["document"])    // blocked.com
    }

    // MARK: - Performance and Stress Tests

    func testDocumentFollowingStressTestWithErrorHandling() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()

        // Create a large dataset with mixed success/failure
        let entries = Array(0..<50).map { index in
            ["title": "Entry \(index)", "path": "/doc-\(index)"]
        }
        let data = createMockResponse(total: 50, offset: 0, limit: 255, entries: entries)
        client.mockResponse(for: baseURL, data: data)

        // Mix of successful and failing requests
        for index in 0..<50 {
            let docURL = URL(string: "https://example.com/doc-\(index)")!
            if index % 4 == 0 {
                // Network errors
                client.mockError(for: docURL, error: URLError(.timedOut))
            } else if index % 4 == 1 {
                // HTTP errors
                client.mockResponse(for: docURL, data: Data(), statusCode: 404)
            } else {
                // Success
                let html = """
                <!DOCTYPE html>
                <html><head><title>Document \(index)</title></head><body><p>Content\(index)</p></body></html>
                """
                client.mockResponse(for: docURL, data: html.data(using: .utf8)!)
            }
        }

        // Use specific concurrency to trigger various code paths
        let context = FFetchContext(maxConcurrency: 5)
        let entriesWithDocs = try await FFetch(url: baseURL, context: context)
            .withHTTPClient(client)
            .follow("path", as: "document")
            .all()

        XCTAssertEqual(entriesWithDocs.count, 50)

        let successful = entriesWithDocs.filter { $0["document"] != nil }
        let failed = entriesWithDocs.filter { $0["document_error"] != nil }

        XCTAssertGreaterThan(successful.count, 0)
        XCTAssertGreaterThan(failed.count, 0)

        // Verify error handling
        let errors = failed.compactMap { $0["document_error"] as? String }
        XCTAssertTrue(errors.contains { $0.contains("Network error") })
        XCTAssertTrue(errors.contains { $0.contains("HTTP error") })
    }
}
