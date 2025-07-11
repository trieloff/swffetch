//
//  DocumentFollowingBasicSecurityTests.swift
//  SwiftFFetchTests
//
//  Basic hostname security tests for document following functionality in FFetch.
//
import XCTest
import SwiftSoup
@testable import SwiftFFetch

final class DocumentFollowingBasicSecurityTests: XCTestCase {

    func testDocumentFollowingHostnameSecurityDefault() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()

        // Mock the index response
        let entries = [
            ["title": "Entry 0", "path": "https://malicious.com/document-0"],
            ["title": "Entry 1", "path": "/document-1"]
        ]
        let data = createMockResponse(total: 2, offset: 0, limit: 255, entries: entries)
        client.mockResponse(for: baseURL, data: data)

        // Mock the allowed document response
        let doc1URL = URL(string: "https://example.com/document-1")!
        let doc1HTML = """
        <!DOCTYPE html><html><head><title>Document 1</title></head><body><p>Content 1</p></body></html>
        """
        client.mockResponse(for: doc1URL, data: doc1HTML.data(using: .utf8)!)

        let entriesWithDocs = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .follow("path", as: "document")
            .all()

        XCTAssertEqual(entriesWithDocs.count, 2)

        // First entry should be blocked due to hostname security
        let entry0 = entriesWithDocs[0]
        XCTAssertEqual(entry0["title"] as? String, "Entry 0")
        XCTAssertNil(entry0["document"])
        XCTAssertNotNil(entry0["document_error"])
        XCTAssertTrue((entry0["document_error"] as? String)?.contains("not allowed") ?? false)

        // Second entry should succeed (same hostname)
        let entry1 = entriesWithDocs[1]
        XCTAssertEqual(entry1["title"] as? String, "Entry 1")
        XCTAssertNotNil(entry1["document"])
        XCTAssertNil(entry1["document_error"])
    }

    func testDocumentFollowingHostnameSecurityWithAllowedHost() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()

        // Mock the index response
        let entries = [
            ["title": "Entry 0", "path": "https://allowed.com/document-0"],
            ["title": "Entry 1", "path": "https://blocked.com/document-1"]
        ]
        let data = createMockResponse(total: 2, offset: 0, limit: 255, entries: entries)
        client.mockResponse(for: baseURL, data: data)

        // Mock the allowed document response
        let doc0URL = URL(string: "https://allowed.com/document-0")!
        let doc0HTML = """
        <!DOCTYPE html><html><head><title>Document 0</title></head><body><p>Content 0</p></body></html>
        """
        client.mockResponse(for: doc0URL, data: doc0HTML.data(using: .utf8)!)

        let entriesWithDocs = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .allow("allowed.com")
            .follow("path", as: "document")
            .all()

        XCTAssertEqual(entriesWithDocs.count, 2)

        // First entry should succeed (explicitly allowed)
        let entry0 = entriesWithDocs[0]
        XCTAssertEqual(entry0["title"] as? String, "Entry 0")
        XCTAssertNotNil(entry0["document"])
        XCTAssertNil(entry0["document_error"])

        // Second entry should be blocked
        let entry1 = entriesWithDocs[1]
        XCTAssertEqual(entry1["title"] as? String, "Entry 1")
        XCTAssertNil(entry1["document"])
        XCTAssertNotNil(entry1["document_error"])
        XCTAssertTrue((entry1["document_error"] as? String)?.contains("not allowed") ?? false)
    }

    func testDocumentFollowingHostnameSecurityWithWildcard() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()

        // Mock the index response
        let entries = [
            ["title": "Entry 0", "path": "https://external.com/document-0"],
            ["title": "Entry 1", "path": "https://another.com/document-1"]
        ]
        let data = createMockResponse(total: 2, offset: 0, limit: 255, entries: entries)
        client.mockResponse(for: baseURL, data: data)

        // Mock the document responses
        let doc0URL = URL(string: "https://external.com/document-0")!
        let doc1URL = URL(string: "https://another.com/document-1")!
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
            .allow("*")
            .follow("path", as: "document")
            .all()

        XCTAssertEqual(entriesWithDocs.count, 2)

        // Both entries should succeed (wildcard allows all)
        for (index, entry) in entriesWithDocs.enumerated() {
            XCTAssertEqual(entry["title"] as? String, "Entry \(index)")
            XCTAssertNotNil(entry["document"])
            XCTAssertNil(entry["document_error"])
        }
    }

    func testDocumentFollowingHostnameSecurityWithRelativePaths() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()

        // Mock the index response with relative paths
        let entries = [
            ["title": "Entry 0", "path": "/document-0"],
            ["title": "Entry 1", "path": "document-1"]
        ]
        let data = createMockResponse(total: 2, offset: 0, limit: 255, entries: entries)
        client.mockResponse(for: baseURL, data: data)

        // Mock the document responses (relative paths should resolve to same host)
        let doc0URL = URL(string: "https://example.com/document-0")!
        let doc1URL = URL(string: "https://example.com/document-1")!
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
            .follow("path", as: "document")
            .all()

        XCTAssertEqual(entriesWithDocs.count, 2)

        // Both entries should succeed (relative paths resolve to same host)
        for (index, entry) in entriesWithDocs.enumerated() {
            XCTAssertEqual(entry["title"] as? String, "Entry \(index)")
            XCTAssertNotNil(entry["document"])
            XCTAssertNil(entry["document_error"])
        }
    }
}
