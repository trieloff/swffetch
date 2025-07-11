//
//  SwiftFFetchDocumentFollowingTests.swift
//  SwiftFFetchTests
//
//  Tests for document following functionality in FFetch.
//
import XCTest
import SwiftSoup
@testable import SwiftFFetch

final class SwiftFFetchDocumentFollowingTests: XCTestCase {

    func testDocumentFollowing() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()

        // Mock the index response
        let entries = [
            ["title": "Entry 0", "path": "/document-0"],
            ["title": "Entry 1", "path": "/document-1"]
        ]
        let data = createMockResponse(total: 2, offset: 0, limit: 255, entries: entries)
        client.mockResponse(for: baseURL, data: data)

        // Mock the document responses
        let doc0URL = URL(string: "https://example.com/document-0")!
        let doc1URL = URL(string: "https://example.com/document-1")!

        let doc0HTML = "<!DOCTYPE html><html><head><title>Document 0</title></head><body><p>Content 0</p></body></html>"
        let doc1HTML = "<!DOCTYPE html><html><head><title>Document 1</title></head><body><p>Content 1</p></body></html>"

        client.mockResponse(for: doc0URL, data: doc0HTML.data(using: .utf8)!)
        client.mockResponse(for: doc1URL, data: doc1HTML.data(using: .utf8)!)

        let entriesWithDocs = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .follow("path", as: "document")
            .all()

        XCTAssertEqual(entriesWithDocs.count, 2)

        for (index, entry) in entriesWithDocs.enumerated() {
            XCTAssertEqual(entry["title"] as? String, "Entry \(index)")
            XCTAssertEqual(entry["path"] as? String, "/document-\(index)")
            // New error-aware logic:
            if let error = entry["document_error"] as? String {
                XCTFail("Unexpected error for document: \(error)")
            } else {
                XCTAssertNotNil(entry["document"])
                XCTAssertTrue(entry["document"] is Document)
            }
        }
    }

    func testDocumentFollowingWithMissingDocument() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()

        // Mock the index response
        let entries = [
            ["title": "Entry 0", "path": "/missing-document"]
        ]
        let data = createMockResponse(total: 1, offset: 0, limit: 255, entries: entries)
        client.mockResponse(for: baseURL, data: data)

        // Don't mock the document response (404)

        let entriesWithDocs = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .follow("path", as: "document")
            .all()

        XCTAssertEqual(entriesWithDocs.count, 1)

        let entry = entriesWithDocs[0]
        XCTAssertEqual(entry["title"] as? String, "Entry 0")
        XCTAssertEqual(entry["path"] as? String, "/missing-document")
        XCTAssertNil(entry["document"])
        // Should have an error field describing the failure
        XCTAssertNotNil(entry["document_error"])
        XCTAssertTrue((entry["document_error"] as? String)?.contains("HTTP error") ?? false ||
                      (entry["document_error"] as? String)?.contains("Network error") ?? false ||
                      (entry["document_error"] as? String)?.contains("No HTTPURLResponse") ?? false ||
                      (entry["document_error"] as? String)?.contains("HTML parsing error") ?? false)
    }
}
