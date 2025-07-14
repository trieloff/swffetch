//
//  DocumentFollowingNonHTTPResponseTests.swift
//  SwiftFFetchTests
//
//  Tests specifically for non-HTTPURLResponse error handling in document following.
//  This test file focuses on covering the non-HTTPURLResponse error path.
//
import XCTest
import SwiftSoup
@testable import SwiftFFetch

final class DocumentFollowingNonHTTPResponseTests: XCTestCase {

    func testDocumentFollowingWithNonHTTPURLResponse() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!

        // Create a custom HTTP client that returns non-HTTPURLResponse for documents
        class NonHTTPResponseClient: FFetchHTTPClient {
            func fetch(_ url: URL, cacheConfig: FFetchCacheConfig) async throws -> (Data, URLResponse) {
                if url.absoluteString.contains("query-index.json") {
                    // Return proper response for the index
                    let entries = [
                        ["title": "Entry 0", "path": "/non-http-doc"]
                    ]
                    let response = FFetchResponse(total: 1, offset: 0, limit: 255, data: entries)
                    let data = try JSONEncoder().encode(response)
                    let httpResponse = HTTPURLResponse(
                        url: url,
                        statusCode: 200,
                        httpVersion: "HTTP/1.1",
                        headerFields: ["Content-Type": "application/json"]
                    )!
                    return (data, httpResponse)
                } else {
                    // Return non-HTTPURLResponse for document fetch
                    let response = URLResponse(
                        url: url,
                        mimeType: "text/html",
                        expectedContentLength: 100,
                        textEncodingName: "utf-8"
                    )
                    let html = "<html><body><p>Document content</p></body></html>"
                    return (html.data(using: .utf8)!, response)
                }
            }
        }

        let context = FFetchContext(
            cacheConfig: FFetchCacheConfig.default,
            httpClient: NonHTTPResponseClient(),
            htmlParser: DefaultFFetchHTMLParser(),
            maxConcurrency: 5,
            allowedHosts: Set(["example.com"])
        )

        let entriesWithDocs = try await FFetch(url: baseURL, context: context)
            .follow("path", as: "document")
            .all()

        XCTAssertEqual(entriesWithDocs.count, 1)

        let entry = entriesWithDocs[0]
        XCTAssertEqual(entry["title"] as? String, "Entry 0")
        XCTAssertNil(entry["document"])
        XCTAssertNotNil(entry["document_error"])
        XCTAssertTrue((entry["document_error"] as? String)?.contains("No HTTPURLResponse") ?? false)
    }

    func testDocumentFollowingWithFileURLs() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()

        // Mock the index response with file URLs (no hostname)
        let entries = [
            ["title": "Entry 0", "path": "file:///local/document.html"],
            ["title": "Entry 1", "path": "data:text/html,<html><body>Inline</body></html>"]
        ]
        let data = createMockResponse(total: 2, offset: 0, limit: 255, entries: entries)
        client.mockResponse(for: baseURL, data: data)

        let entriesWithDocs = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .follow("path", as: "document")
            .all()

        XCTAssertEqual(entriesWithDocs.count, 2)

        // Both entries should be blocked due to security (no hostname)
        for (index, entry) in entriesWithDocs.enumerated() {
            XCTAssertEqual(entry["title"] as? String, "Entry \(index)")
            XCTAssertNil(entry["document"])
            XCTAssertNotNil(entry["document_error"])
            XCTAssertTrue((entry["document_error"] as? String)?.contains("not allowed") ?? false)
        }
    }

    func testDocumentFollowingWithEmptyAndNilValues() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()

        // Mock the index response with various edge case values
        let entries: [FFetchEntry] = [
            ["title": "Entry 0", "path": ""],  // Empty string
            ["title": "Entry 1"],  // Missing field entirely (instead of NSNull which doesn't encode)
            ["title": "Entry 2", "path": 42],  // Wrong type
            ["title": "Entry 3", "path": " "]  // Whitespace only
        ]
        let data = createMockResponse(total: 4, offset: 0, limit: 255, entries: entries)
        client.mockResponse(for: baseURL, data: data)

        let entriesWithDocs = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .follow("path", as: "document")
            .all()

        XCTAssertEqual(entriesWithDocs.count, 4)

        // All entries should have errors due to invalid/missing URLs
        for (index, entry) in entriesWithDocs.enumerated() {
            XCTAssertEqual(entry["title"] as? String, "Entry \(index)")
            XCTAssertNil(entry["document"])
            XCTAssertNotNil(entry["document_error"])
            let errorMessage = entry["document_error"] as? String ?? ""
            XCTAssertTrue(
                errorMessage.contains("Missing or invalid URL string") ||
                errorMessage.contains("Could not resolve URL") ||
                errorMessage.contains("not allowed") ||
                errorMessage.contains("HTTP error"),
                "Expected URL validation or HTTP error for entry \(index), got: \(errorMessage)"
            )
        }
    }

    func testDocumentFollowingWithCustomFieldNames() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()

        // Mock the index response with custom field names
        let entries = [
            ["title": "Entry 0", "url": "/doc-0"],  // Using "url" instead of "path"
            ["title": "Entry 1", "link": "/doc-1"]  // Using "link" instead of "path"
        ]
        let data = createMockResponse(total: 2, offset: 0, limit: 255, entries: entries)
        client.mockResponse(for: baseURL, data: data)

        // Mock document responses
        let doc0URL = URL(string: "https://example.com/doc-0")!
        let doc1URL = URL(string: "https://example.com/doc-1")!
        let html0 = "<html><body><p>Document 0</p></body></html>"
        let html1 = "<html><body><p>Document 1</p></body></html>"
        client.mockResponse(for: doc0URL, data: html0.data(using: .utf8)!)
        client.mockResponse(for: doc1URL, data: html1.data(using: .utf8)!)

        // Test with custom field names and target field names
        let entriesWithDocs0 = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .follow("url", as: "webpage")  // Custom source and target field names
            .all()

        let entriesWithDocs1 = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .follow("link")  // Custom source field, default target
            .all()

        XCTAssertEqual(entriesWithDocs0.count, 2)
        XCTAssertEqual(entriesWithDocs1.count, 2)

        // First test - custom field names
        let entry0 = entriesWithDocs0[0]
        XCTAssertEqual(entry0["title"] as? String, "Entry 0")
        XCTAssertNotNil(entry0["webpage"])  // Should use custom target field name
        XCTAssertNil(entry0["webpage_error"])

        // Second entry should have error (missing "url" field)
        let entry1Test0 = entriesWithDocs0[1]
        XCTAssertEqual(entry1Test0["title"] as? String, "Entry 1")
        XCTAssertNil(entry1Test0["webpage"])
        XCTAssertNotNil(entry1Test0["webpage_error"])
        let entry1Error = (entry1Test0["webpage_error"] as? String)?.contains(
            "Missing or invalid URL string in field 'url'"
        ) ?? false
        XCTAssertTrue(entry1Error)

        // Second test - different source field
        let entry0Test1 = entriesWithDocs1[0]
        XCTAssertEqual(entry0Test1["title"] as? String, "Entry 0")
        XCTAssertNil(entry0Test1["link"])  // Should have error (missing "link" field)
        XCTAssertNotNil(entry0Test1["link_error"])

        let entry1Test1 = entriesWithDocs1[1]
        XCTAssertEqual(entry1Test1["title"] as? String, "Entry 1")
        XCTAssertNotNil(entry1Test1["link"])  // Should be successful
        XCTAssertNil(entry1Test1["link_error"])
    }
}
