//
//  DocumentFollowingAdvancedSecurityTests.swift
//  SwiftFFetchTests
//
//  Advanced hostname security tests for document following functionality in FFetch.
//
import XCTest
import SwiftSoup
@testable import SwiftFFetch

final class DocumentFollowingAdvancedSecurityTests: XCTestCase {

    func testDocumentFollowingHostnameSecurityWithMultipleHosts() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()

        // Mock the index response
        let entries = [
            ["title": "Entry 0", "path": "https://allowed1.com/document-0"],
            ["title": "Entry 1", "path": "https://allowed2.com/document-1"],
            ["title": "Entry 2", "path": "https://blocked.com/document-2"]
        ]
        let data = createMockResponse(total: 3, offset: 0, limit: 255, entries: entries)
        client.mockResponse(for: baseURL, data: data)

        // Mock the allowed document responses
        let doc0URL = URL(string: "https://allowed1.com/document-0")!
        let doc1URL = URL(string: "https://allowed2.com/document-1")!
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
            .allow(["allowed1.com", "allowed2.com"])
            .follow("path", as: "document")
            .all()

        XCTAssertEqual(entriesWithDocs.count, 3)

        // First two entries should succeed (explicitly allowed)
        for index in 0..<2 {
            let entry = entriesWithDocs[index]
            XCTAssertEqual(entry["title"] as? String, "Entry \(index)")
            XCTAssertNotNil(entry["document"])
            XCTAssertNil(entry["document_error"])
        }

        // Third entry should be blocked
        let entry2 = entriesWithDocs[2]
        XCTAssertEqual(entry2["title"] as? String, "Entry 2")
        XCTAssertNil(entry2["document"])
        XCTAssertNotNil(entry2["document_error"])
        XCTAssertTrue((entry2["document_error"] as? String)?.contains("not allowed") ?? false)
    }

    func testDocumentFollowingHostnameSecurityWithSubdomains() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()

        // Mock the index response with subdomain paths
        let entries = [
            ["title": "Entry 0", "path": "https://sub.example.com/document-0"],
            ["title": "Entry 1", "path": "https://api.example.com/document-1"]
        ]
        let data = createMockResponse(total: 2, offset: 0, limit: 255, entries: entries)
        client.mockResponse(for: baseURL, data: data)

        // Mock the allowed document response
        let doc0URL = URL(string: "https://sub.example.com/document-0")!
        let doc0HTML = """
        <!DOCTYPE html><html><head><title>Document 0</title></head><body><p>Content 0</p></body></html>
        """
        client.mockResponse(for: doc0URL, data: doc0HTML.data(using: .utf8)!)

        let entriesWithDocs = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .allow("sub.example.com")
            .follow("path", as: "document")
            .all()

        XCTAssertEqual(entriesWithDocs.count, 2)

        // First entry should succeed (subdomain explicitly allowed)
        let entry0 = entriesWithDocs[0]
        XCTAssertEqual(entry0["title"] as? String, "Entry 0")
        XCTAssertNotNil(entry0["document"])
        XCTAssertNil(entry0["document_error"])

        // Second entry should be blocked (different subdomain)
        let entry1 = entriesWithDocs[1]
        XCTAssertEqual(entry1["title"] as? String, "Entry 1")
        XCTAssertNil(entry1["document"])
        XCTAssertNotNil(entry1["document_error"])
        XCTAssertTrue((entry1["document_error"] as? String)?.contains("not allowed") ?? false)
    }

    func testDocumentFollowingHostnameSecurityWithInvalidURL() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()

        // Mock the index response with invalid URL that cannot be resolved
        let entries = [
            ["title": "Entry 0", "path": "://invalid-url"]
        ]
        let data = createMockResponse(total: 1, offset: 0, limit: 255, entries: entries)
        client.mockResponse(for: baseURL, data: data)

        let entriesWithDocs = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .follow("path", as: "document")
            .all()

        XCTAssertEqual(entriesWithDocs.count, 1)

        // Entry should fail with URL resolution error
        let entry = entriesWithDocs[0]
        XCTAssertEqual(entry["title"] as? String, "Entry 0")
        XCTAssertNil(entry["document"])
        XCTAssertNotNil(entry["document_error"])
        let errorMessage = entry["document_error"] as? String ?? ""
        XCTAssertTrue(errorMessage.contains("Could not resolve URL") || errorMessage.contains("not allowed"),
                     "Expected URL resolution or security error, got: \(errorMessage)")
    }

    func testDocumentFollowingHostnameSecurityWithEmptyHost() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()

        // Mock the index response with URL that has no host (like file://)
        let entries = [
            ["title": "Entry 0", "path": "file:///local/document.html"]
        ]
        let data = createMockResponse(total: 1, offset: 0, limit: 255, entries: entries)
        client.mockResponse(for: baseURL, data: data)

        let entriesWithDocs = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .follow("path", as: "document")
            .all()

        XCTAssertEqual(entriesWithDocs.count, 1)

        // Entry should fail with hostname security error
        let entry = entriesWithDocs[0]
        XCTAssertEqual(entry["title"] as? String, "Entry 0")
        XCTAssertNil(entry["document"])
        XCTAssertNotNil(entry["document_error"])
        XCTAssertTrue((entry["document_error"] as? String)?.contains("not allowed") ?? false)
    }
}
