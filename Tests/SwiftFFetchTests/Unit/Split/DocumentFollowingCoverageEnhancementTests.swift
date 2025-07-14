//
//  DocumentFollowingCoverageEnhancementTests.swift
//  SwiftFFetchTests
//
//  Comprehensive tests to achieve 95%+ coverage for FFetch+DocumentFollowing.swift
//  Tests focus on previously uncovered edge cases and boundary conditions
//
import XCTest
import SwiftSoup
@testable import SwiftFFetch

final class DocumentFollowingCoverageEnhancementTests: XCTestCase {

    // MARK: - Security Edge Cases

    func testDocumentFollowingWithWildcardSecurityEdgeCases() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()

        let entries = createWildcardSecurityTestEntries()
        let data = createMockResponse(total: 3, offset: 0, limit: 255, entries: entries)
        client.mockResponse(for: baseURL, data: data)

        setupMockResponses(for: client, urls: [
            "https://malicious.com/../../etc/passwd",
            "https://sub.example.com/document",
            "https://example.com/relative/path/to/document"
        ])

        let entriesWithDocs = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .allow("*")
            .follow("path", as: "document")
            .all()

        XCTAssertEqual(entriesWithDocs.count, 3)
        verifySuccessfulProcessing(for: entriesWithDocs)
    }

    private func createWildcardSecurityTestEntries() -> [[String: String]] {
        return [
            ["title": "Entry 0", "path": "https://malicious.com/../../etc/passwd"],
            ["title": "Entry 1", "path": "https://sub.example.com/document"],
            ["title": "Entry 2", "path": "/relative/path/to/document"]
        ]
    }

    private func setupMockResponses(for client: MockHTTPClient, urls: [String]) {
        for (index, urlString) in urls.enumerated() {
            let url = URL(string: urlString)!
            let html = """
                <!DOCTYPE html>
                <html><head><title>Document \(index)</title></head>
                <body><p>Content</p></body></html>
                """
            client.mockResponse(for: url, data: Data(html.utf8))
        }
    }

    private func verifySuccessfulProcessing(for entries: [[String: Any]]) {
        for entry in entries {
            XCTAssertNotNil(entry["document"])
            XCTAssertNil(entry["document_error"])
        }
    }

    func testDocumentFollowingHostnameValidationWithComplexURLs() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()

        let entries = createComplexURLTestEntries()
        let data = createMockResponse(total: 5, offset: 0, limit: 255, entries: entries)
        client.mockResponse(for: baseURL, data: data)

        setupMockResponses(for: client, urls: [
            "https://user:pass@example.com:8080/path?query=value#fragment",
            "https://example.com/path%20with%20spaces",
            "https://example.com/path/../relative",
            "https://example.com/protocol-relative",
            "https://example.com/example.com/no-protocol"
        ])

        let entriesWithDocs = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .follow("path", as: "document")
            .all()

        XCTAssertEqual(entriesWithDocs.count, 5)
        verifySuccessfulProcessing(for: entriesWithDocs)
    }

    private func createComplexURLTestEntries() -> [[String: String]] {
        return [
            ["title": "Entry 0", "path": "https://user:pass@example.com:8080/path?query=value#fragment"],
            ["title": "Entry 1", "path": "https://example.com/path%20with%20spaces"],
            ["title": "Entry 2", "path": "https://example.com/path/../relative"],
            ["title": "Entry 3", "path": "//example.com/protocol-relative"],
            ["title": "Entry 4", "path": "example.com/no-protocol"]
        ]
    }

    // MARK: - URL Resolution Edge Cases

    func testDocumentFollowingURLResolutionEdgeCases() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()

        let entries = createURLResolutionTestEntries()
        let data = createMockResponse(total: 9, offset: 0, limit: 255, entries: entries)
        client.mockResponse(for: baseURL, data: data)

        setupMockResponses(for: client, urls: [
            "https://example.com/",
            "https://example.com/path/",
            "https://example.com/relative",
            "https://example.com/current",
            "https://example.com/path%20with%20spaces"
        ])

        let entriesWithDocs = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .follow("path", as: "document")
            .all()

        XCTAssertEqual(entriesWithDocs.count, 9)
        verifyErrorHandling(for: entriesWithDocs)
    }

    private func createURLResolutionTestEntries() -> [[String: String]] {
        return [
            ["title": "Entry 0", "path": ""], // Empty string
            ["title": "Entry 1", "path": "  "], // Whitespace only
            ["title": "Entry 2", "path": "#fragment-only"], // Fragment only
            ["title": "Entry 3", "path": "?query=only"], // Query only
            ["title": "Entry 4", "path": "/"], // Root path
            ["title": "Entry 5", "path": "/path/"], // Trailing slash
            ["title": "Entry 6", "path": "../relative"], // Relative path
            ["title": "Entry 7", "path": "./current"], // Current directory
            ["title": "Entry 8", "path": "path with spaces"] // Spaces in path
        ]
    }

    private func verifyErrorHandling(for entries: [[String: Any]]) {
        let errors = entries.compactMap { $0["document_error"] as? String }
        XCTAssertGreaterThanOrEqual(errors.count, 4, "Should have at least 4 error entries for invalid URLs")
    }

    func testDocumentFollowingHostnameValidationWithEmptyAndNilHost() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()

        let entries = createHostnameValidationEntries()
        let data = createMockResponse(total: 5, offset: 0, limit: 255, entries: entries)
        client.mockResponse(for: baseURL, data: data)

        let entriesWithDocs = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .follow("path", as: "document")
            .all()

        XCTAssertEqual(entriesWithDocs.count, 5)
        try verifyHostnameSecurityBlocks(for: entriesWithDocs)
    }

    private func createHostnameValidationEntries() -> [[String: String]] {
        return [
            ["title": "Entry 0", "path": "file:///local/path"],
            ["title": "Entry 1", "path": "mailto:test@example.com"],
            ["title": "Entry 2", "path": "tel:+1234567890"],
            ["title": "Entry 3", "path": "data:text/html,<html></html>"],
            ["title": "Entry 4", "path": "about:blank"]
        ]
    }

    private func verifyHostnameSecurityBlocks(for entries: [[String: Any]]) throws {
        for entry in entries {
            XCTAssertNil(entry["document"])
            XCTAssertNotNil(entry["document_error"])
            let error = try XCTUnwrap(entry["document_error"] as? String)
            XCTAssertTrue(error.contains("not allowed"))
        }
    }

    // MARK: - Error Handling Edge Cases

    func testDocumentFollowingGracefulErrorHandlingInConcurrentTasks() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()

        // Create many entries to trigger concurrent processing
        let entries = Array(0..<20).map { index in
            ["title": "Entry \(index)", "path": "/doc-\(index)"]
        }
        let data = createMockResponse(total: 20, offset: 0, limit: 255, entries: entries)
        client.mockResponse(for: baseURL, data: data)

        // Mix of successful and failing requests
        for index in 0..<20 {
            let docURL = URL(string: "https://example.com/doc-\(index)")!
            if index % 5 == 0 {
                // Network errors
                client.mockError(for: docURL, error: URLError(.notConnectedToInternet))
            } else if index % 5 == 1 {
                // HTTP errors
                client.mockResponse(for: docURL, data: Data(), statusCode: 500)
            } else if index % 5 == 2 {
                // Empty data
                client.mockResponse(for: docURL, data: Data())
            } else if index % 5 == 3 {
                // Invalid HTML
                let invalidHTML = "Invalid HTML"
                client.mockResponse(for: docURL, data: Data(invalidHTML.utf8))
            } else {
                // Success
                let html = """
                <!DOCTYPE html>
                <html><head><title>Document \(index)</title></head>
                <body><p>Content</p></body></html>
                """
                client.mockResponse(for: docURL, data: html.data(using: .utf8)!)
            }
        }

        // Use low concurrency to trigger the catch blocks in concurrent processing
        let context = FFetchContext(maxConcurrency: 3)
        let entriesWithDocs = try await FFetch(url: baseURL, context: context)
            .withHTTPClient(client)
            .follow("path", as: "document")
            .all()

        XCTAssertEqual(entriesWithDocs.count, 20)

        // Verify we have both successes and errors
        let successful = entriesWithDocs.filter { $0["document"] != nil }
        let failed = entriesWithDocs.filter { $0["document_error"] != nil }

        XCTAssertGreaterThan(successful.count, 0)
        XCTAssertGreaterThan(failed.count, 0)

        // Verify error types
        let errors = failed.compactMap { $0["document_error"] as? String }
        XCTAssertTrue(errors.contains { $0.contains("Network error") })
        XCTAssertTrue(errors.contains { $0.contains("HTTP error") })
        XCTAssertTrue(errors.contains { $0.contains("HTML parsing error") })
    }

    // MARK: - Integration Scenarios

    func testDocumentFollowingChainedWithSecurityConfiguration() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()

        // Complex scenario with chained security configuration
        let entries = [
            ["title": "Entry 0", "path": "https://allowed1.com/doc-0"],
            ["title": "Entry 1", "path": "https://allowed2.com/doc-1"],
            ["title": "Entry 2", "path": "https://blocked.com/doc-2"],
            ["title": "Entry 3", "path": "/local/doc-3"]
        ]
        let data = createMockResponse(total: 4, offset: 0, limit: 255, entries: entries)
        client.mockResponse(for: baseURL, data: data)

        // Mock responses
        let urls = [
            "https://allowed1.com/doc-0",
            "https://allowed2.com/doc-1",
            "https://allowed1.com/local/doc-3"  // This should be allowed as relative to allowed1.com
        ]

        for (index, urlString) in urls.enumerated() {
            let url = URL(string: urlString)!
            let html = """
                <!DOCTYPE html>
                <html><head><title>Document \(index)</title></head>
                <body><p>Content</p></body></html>
                """
            client.mockResponse(for: url, data: Data(html.utf8))
        }

        let entriesWithDocs = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .allow(["allowed1.com", "allowed2.com"])
            .follow("path", as: "document")
            .all()

        XCTAssertEqual(entriesWithDocs.count, 4)

        // Verify specific outcomes
        let doc0 = entriesWithDocs[0]
        let doc1 = entriesWithDocs[1]
        let doc2 = entriesWithDocs[2]
        let doc3 = entriesWithDocs[3]

        XCTAssertNotNil(doc0["document"])  // allowed1.com
        XCTAssertNotNil(doc1["document"])  // allowed2.com
        XCTAssertNil(doc2["document"])     // blocked.com
        XCTAssertNotNil(doc3["document"])  // relative to example.com
    }

    func testDocumentFollowingMemoryManagementWithLargeDataset() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()

        // Create a large dataset to test memory management
        let entries = Array(0..<100).map { index in
            ["title": "Entry \(index)", "path": "/doc-\(index)"]
        }
        let data = createMockResponse(total: 100, offset: 0, limit: 255, entries: entries)
        client.mockResponse(for: baseURL, data: data)

        // Mock all document responses
        for index in 0..<100 {
            let docURL = URL(string: "https://example.com/doc-\(index)")!
            let html = """
                <!DOCTYPE html>
                <html><head><title>Document \(index)</title></head>
                <body><p>Content \(index)</p></body></html>
                """
            client.mockResponse(for: docURL, data: html.data(using: .utf8)!)
        }

        let entriesWithDocs = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .follow("path", as: "document")
            .all()

        XCTAssertEqual(entriesWithDocs.count, 100)

        // Verify all documents were processed
        for entry in entriesWithDocs {
            XCTAssertNotNil(entry["document"])
            XCTAssertNil(entry["document_error"])
        }
    }

    // MARK: - Boundary Conditions

    func testDocumentFollowingBoundaryConditions() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()

        // Test boundary conditions - only use valid URLs that will resolve properly
        let entries = [
            ["title": "Entry 0", "path": "/"],  // Root path
            ["title": "Entry 1", "path": "/path"], // No trailing slash
            ["title": "Entry 2", "path": "/path/"], // Trailing slash
            ["title": "Entry 3", "path": "/path?query=value"], // With query
            ["title": "Entry 4", "path": "/path#fragment"], // With fragment
            ["title": "Entry 5", "path": "/relative/path"], // Relative path
            ["title": "Entry 6", "path": "https://example.com/external"], // Absolute URL
            ["title": "Entry 7", "path": "/path with spaces"], // Spaces in path
            ["title": "Entry 8", "path": "/path/../normalized"], // Path normalization
            ["title": "Entry 9", "path": "/path/to/resource"] // Deep path
        ]
        let data = createMockResponse(total: 10, offset: 0, limit: 255, entries: entries)
        client.mockResponse(for: baseURL, data: data)

        // Mock responses for the actual resolved URLs
        let resolvedURLs = [
            "https://example.com/",
            "https://example.com/path",
            "https://example.com/path/",
            "https://example.com/path?query=value",
            "https://example.com/path#fragment",
            "https://example.com/relative/path",
            "https://example.com/external",
            "https://example.com/path%20with%20spaces",
            "https://example.com/normalized",
            "https://example.com/path/to/resource"
        ]

        for (index, urlString) in resolvedURLs.enumerated() {
            let docURL = URL(string: urlString)!
            let html = """
                <!DOCTYPE html>
                <html><head><title>Document \(index)</title></head>
                <body><p>Content</p></body></html>
                """
            client.mockResponse(for: docURL, data: html.data(using: .utf8)!)
        }

        let entriesWithDocs = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .follow("path", as: "document")
            .all()

        XCTAssertEqual(entriesWithDocs.count, 10)

        // Verify successful processing
        for entry in entriesWithDocs {
            XCTAssertNotNil(entry["document"])
            XCTAssertNil(entry["document_error"])
        }
    }
}
