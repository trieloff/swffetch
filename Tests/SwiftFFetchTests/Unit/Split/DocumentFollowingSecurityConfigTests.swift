//
//  DocumentFollowingSecurityConfigTests.swift
//  SwiftFFetchTests
//
//  Security configuration tests for document following functionality in FFetch.
//
import XCTest
import SwiftSoup
@testable import SwiftFFetch

final class DocumentFollowingSecurityConfigTests: XCTestCase {

    func testDocumentFollowingAllowChaining() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()

        // Mock the index response
        let entries = [
            ["title": "Entry 0", "path": "https://first.com/document-0"],
            ["title": "Entry 1", "path": "https://second.com/document-1"]
        ]
        let data = createMockResponse(total: 2, offset: 0, limit: 255, entries: entries)
        client.mockResponse(for: baseURL, data: data)

        // Mock the document responses
        let doc0URL = URL(string: "https://first.com/document-0")!
        let doc1URL = URL(string: "https://second.com/document-1")!
        let doc0HTML = """
        <!DOCTYPE html><html><head><title>Document 0</title></head><body><p>Content 0</p></body></html>
        """
        let doc1HTML = """
        <!DOCTYPE html><html><head><title>Document 1</title></head><body><p>Content 1</p></body></html>
        """
        client.mockResponse(for: doc0URL, data: doc0HTML.data(using: .utf8)!)
        client.mockResponse(for: doc1URL, data: doc1HTML.data(using: .utf8)!)

        let entriesWithDocs = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .allow("first.com")
            .allow("second.com")
            .follow("path", as: "document")
            .all()

        XCTAssertEqual(entriesWithDocs.count, 2)

        // Both entries should succeed (chained allow calls)
        for (index, entry) in entriesWithDocs.enumerated() {
            XCTAssertEqual(entry["title"] as? String, "Entry \(index)")
            XCTAssertNotNil(entry["document"])
            XCTAssertNil(entry["document_error"])
        }
    }
}
