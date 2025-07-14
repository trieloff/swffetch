//
//  DocumentFollowingErrorConditionsTests.swift
//  SwiftFFetchTests
//
//  Tests for error conditions in document following to achieve full coverage.
//
import XCTest
import SwiftSoup
@testable import SwiftFFetch

final class DocumentFollowingErrorConditionsTests: XCTestCase {

    func testDocumentFollowingWithMissingURLField() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()

        // Mock the index response with entry missing the URL field
        let entries = [
            ["title": "Entry 0"],  // Missing "path" field
            ["title": "Entry 1", "path": 123]  // Invalid type for "path" field
        ]
        let data = createMockResponse(total: 2, offset: 0, limit: 255, entries: entries)
        client.mockResponse(for: baseURL, data: data)

        let entriesWithDocs = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .follow("path", as: "document")
            .all()

        XCTAssertEqual(entriesWithDocs.count, 2)

        // Both entries should have errors for missing/invalid field
        for (index, entry) in entriesWithDocs.enumerated() {
            XCTAssertEqual(entry["title"] as? String, "Entry \(index)")
            XCTAssertNil(entry["document"])
            XCTAssertNotNil(entry["document_error"])
            let errorText = (entry["document_error"] as? String)?.contains(
                "Missing or invalid URL string in field 'path'"
            ) ?? false
            XCTAssertTrue(errorText)
        }
    }

    func testDocumentFollowingWithInvalidURLResolution() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()

        // Mock the index response with URLs that cannot be resolved
        let entries = [
            ["title": "Entry 0", "path": "://invalid-url-scheme"],
            ["title": "Entry 1", "path": ""]
        ]
        let data = createMockResponse(total: 2, offset: 0, limit: 255, entries: entries)
        client.mockResponse(for: baseURL, data: data)

        let entriesWithDocs = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .follow("path", as: "document")
            .all()

        XCTAssertEqual(entriesWithDocs.count, 2)

        // Both entries should have URL resolution errors
        for (index, entry) in entriesWithDocs.enumerated() {
            XCTAssertEqual(entry["title"] as? String, "Entry \(index)")
            XCTAssertNil(entry["document"])
            XCTAssertNotNil(entry["document_error"])
            let errorMessage = entry["document_error"] as? String ?? ""
            XCTAssertTrue(
                errorMessage.contains("Could not resolve URL") || errorMessage.contains("not allowed"),
                "Expected URL resolution or security error for entry \(index), got: \(errorMessage)"
            )
        }
    }

    func testDocumentFollowingWithNetworkErrors() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()

        // Mock the index response
        let entries = [
            ["title": "Entry 0", "path": "/network-error-doc"]
        ]
        let data = createMockResponse(total: 1, offset: 0, limit: 255, entries: entries)
        client.mockResponse(for: baseURL, data: data)

        // Mock a network error for the document URL
        let docURL = URL(string: "https://example.com/network-error-doc")!
        let networkError = URLError(.notConnectedToInternet)
        client.mockError(for: docURL, error: networkError)

        let entriesWithDocs = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .follow("path", as: "document")
            .all()

        XCTAssertEqual(entriesWithDocs.count, 1)

        let entry = entriesWithDocs[0]
        XCTAssertEqual(entry["title"] as? String, "Entry 0")
        XCTAssertNil(entry["document"])
        XCTAssertNotNil(entry["document_error"])
        XCTAssertTrue((entry["document_error"] as? String)?.contains("Network error") ?? false)
    }

    func testDocumentFollowingWithParsingErrors() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!

        // Create a custom HTML parser that always throws an error
        class FailingHTMLParser: FFetchHTMLParser {
            func parse(_ html: String) throws -> Document {
                throw FFetchError.operationFailed("Simulated parsing error")
            }
        }

        let client = MockHTTPClient()

        // Mock the index response
        let entries = [
            ["title": "Entry 0", "path": "/doc-0"]
        ]
        let data = createMockResponse(total: 1, offset: 0, limit: 255, entries: entries)
        client.mockResponse(for: baseURL, data: data)

        // Mock a successful document response
        let docURL = URL(string: "https://example.com/doc-0")!
        let html = "<html><body><p>Valid HTML</p></body></html>"
        client.mockResponse(for: docURL, data: html.data(using: .utf8)!)

        // Create context with failing parser
        let context = FFetchContext(
            cacheConfig: FFetchCacheConfig.default,
            httpClient: client,
            htmlParser: FailingHTMLParser(),
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
        XCTAssertTrue((entry["document_error"] as? String)?.contains("HTML parsing error") ?? false)
    }

    func testDocumentFollowingConcurrentTaskErrors() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()

        // Create many entries to trigger concurrent processing
        let entries = Array(0..<10).map { index in
            ["title": "Entry \(index)", "path": "/doc-\(index)"]
        }
        let data = createMockResponse(total: 10, offset: 0, limit: 255, entries: entries)
        client.mockResponse(for: baseURL, data: data)

        // Mock some successful responses and some network errors
        for index in 0..<10 {
            let docURL = URL(string: "https://example.com/doc-\(index)")!
            if index % 3 == 0 {
                // Every third document has a network error
                client.mockError(for: docURL, error: URLError(.networkConnectionLost))
            } else {
                // Others are successful
                let html = "<html><body><p>Document \(index)</p></body></html>"
                client.mockResponse(for: docURL, data: html.data(using: .utf8)!)
            }
        }

        // Use a low concurrency limit to force multiple batches
        let context = FFetchContext(maxConcurrency: 3)
        let entriesWithDocs = try await FFetch(url: baseURL, context: context)
            .withHTTPClient(client)
            .follow("path", as: "document")
            .all()

        XCTAssertEqual(entriesWithDocs.count, 10)

        // Check that we got both successful results and error results
        var successCount = 0
        var errorCount = 0

        for entry in entriesWithDocs {
            if entry["document"] != nil {
                successCount += 1
                XCTAssertNil(entry["document_error"])
            } else {
                errorCount += 1
                XCTAssertNotNil(entry["document_error"])
            }
        }

        XCTAssertGreaterThan(successCount, 0, "Should have some successful documents")
        XCTAssertGreaterThan(errorCount, 0, "Should have some error documents")
    }
}
