//
//  SwiftFFetchTests.swift
//  SwiftFFetchTests
//
//  Created by SwiftFFetch on 2024-01-01.
//  Copyright © 2024 Adobe. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import XCTest
import Foundation
import SwiftSoup
@testable import SwiftFFetch

final class SwiftFFetchTests: XCTestCase {

    // MARK: - Mock HTTP Client

    class MockHTTPClient: FFetchHTTPClient {
        var responses: [URL: (Data, HTTPURLResponse)] = [:]
        var errors: [URL: Error] = [:]

        func fetch(_ url: URL, cachePolicy: URLRequest.CachePolicy) async throws -> (Data, URLResponse) {
            // Try exact match first
            if let error = errors[url] {
                throw error
            }
            if let response = responses[url] {
                return response
            }

            // Try to match relative URLs against the entry point base URL
            // (Assume the entry point is always absolute and all other paths are relative)
            if !url.isFileURL, url.scheme != nil, let base = responses.keys.first(where: { $0.scheme != nil && $0.host == url.host }) {
                // Compose a relative path from the base
                let relative = URL(string: url.path, relativeTo: base)?.absoluteURL
                if let relative = relative {
                    if let error = errors[relative] {
                        throw error
                    }
                    if let response = responses[relative] {
                        return response
                    }
                }
            }

            // Default 404 response
            let httpResponse = HTTPURLResponse(
                url: url,
                statusCode: 404,
                httpVersion: "HTTP/1.1",
                headerFields: nil
            )!
            return (Data(), httpResponse)
        }

        func mockResponse(for url: URL, data: Data, statusCode: Int = 200) {
            let httpResponse = HTTPURLResponse(
                url: url,
                statusCode: statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )!
            responses[url] = (data, httpResponse)
        }

        func mockError(for url: URL, error: Error) {
            errors[url] = error
        }
    }

    // MARK: - Test Helpers

    func createMockResponse(total: Int, offset: Int, limit: Int, entries: [FFetchEntry]) -> Data {
        let response = FFetchResponse(total: total, offset: offset, limit: limit, data: entries)
        return try! JSONEncoder().encode(response)
    }

    func createMockEntry(index: Int) -> FFetchEntry {
        return [
            "title": "Entry \(index)",
            "path": "/entry-\(index)",
            "published": index % 2 == 0
        ]
    }

    func mockIndexRequests(
        client: MockHTTPClient,
        baseURL: URL,
        total: Int,
        chunkSize: Int = 255,
        sheet: String? = nil
    ) {
        for offset in stride(from: 0, to: total, by: chunkSize) {
            let entries = Array(offset..<min(offset + chunkSize, total)).map(createMockEntry)
            let data = createMockResponse(
                total: total,
                offset: offset,
                limit: chunkSize,
                entries: entries
            )

            var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: true)!
            var queryItems = [
                URLQueryItem(name: "offset", value: String(offset)),
                URLQueryItem(name: "limit", value: String(chunkSize))
            ]

            if let sheet = sheet {
                queryItems.append(URLQueryItem(name: "sheet", value: sheet))
            }

            components.queryItems = queryItems
            client.mockResponse(for: components.url!, data: data)
        }
    }

    // MARK: - Basic Tests

    func testFFetchInitialization() throws {
        let ffetch = try FFetch(url: "https://example.com/index.json")
        XCTAssertNotNil(ffetch)
    }

    func testFFetchInitializationWithInvalidURL() {
        XCTAssertThrowsError(try FFetch(url: "")) { error in
            XCTAssertTrue(error is FFetchError)
            if case .invalidURL = error as? FFetchError {
                // Expected
            } else {
                XCTFail("Expected invalidURL error")
            }
        }
    }

    func testConvenienceFunction() throws {
        let ffetch1 = try ffetch("https://example.com/index.json")
        let ffetch2 = ffetch(URL(string: "https://example.com/index.json")!)

        XCTAssertNotNil(ffetch1)
        XCTAssertNotNil(ffetch2)
    }

    // MARK: - Streaming Tests

    func testBasicStreaming() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()
        mockIndexRequests(client: client, baseURL: baseURL, total: 10)

        let ffetch = FFetch(url: baseURL).withHTTPClient(client)
        var count = 0

        for await entry in ffetch {
            XCTAssertEqual(entry["title"] as? String, "Entry \(count)")
            count += 1
        }

        XCTAssertEqual(count, 10)
    }

    func testLargeDatasetStreaming() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()
        mockIndexRequests(client: client, baseURL: baseURL, total: 555)

        let ffetch = FFetch(url: baseURL).withHTTPClient(client)
        var count = 0

        for await entry in ffetch {
            XCTAssertEqual(entry["title"] as? String, "Entry \(count)")
            count += 1
        }

        XCTAssertEqual(count, 555)
    }

    func testCustomChunkSize() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()
        mockIndexRequests(client: client, baseURL: baseURL, total: 100, chunkSize: 10)

        let ffetch = FFetch(url: baseURL)
            .withHTTPClient(client)
            .chunks(10)

        var count = 0
        for await entry in ffetch {
            XCTAssertEqual(entry["title"] as? String, "Entry \(count)")
            count += 1
        }

        XCTAssertEqual(count, 100)
    }

    // MARK: - Sheet Tests

    func testSheetSelection() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()
        mockIndexRequests(client: client, baseURL: baseURL, total: 10, sheet: "products")

        let ffetch = FFetch(url: baseURL)
            .withHTTPClient(client)
            .sheet("products")

        var count = 0
        for await entry in ffetch {
            XCTAssertEqual(entry["title"] as? String, "Entry \(count)")
            count += 1
        }

        XCTAssertEqual(count, 10)
    }

    // MARK: - Error Handling Tests

    func testNotFoundHandling() async throws {
        let baseURL = URL(string: "https://example.com/not-found.json")!
        let client = MockHTTPClient()
        // Don't add any mock responses, so it will return 404

        let ffetch = FFetch(url: baseURL).withHTTPClient(client)
        var count = 0

        for await _ in ffetch {
            count += 1
        }

        XCTAssertEqual(count, 0)
    }

    func testNetworkErrorHandling() async throws {
        let baseURL = URL(string: "https://example.com/error.json")!
        let client = MockHTTPClient()
        client.mockError(for: baseURL, error: URLError(.networkConnectionLost))

        let ffetch = FFetch(url: baseURL).withHTTPClient(client)
        var count = 0

        for await _ in ffetch {
            count += 1
        }

        XCTAssertEqual(count, 0)
    }

    // MARK: - Transformation Tests

    func testMapOperation() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()
        mockIndexRequests(client: client, baseURL: baseURL, total: 10)

        let titles = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .map { entry in
                return entry["title"] as? String ?? "No title"
            }
            .all()

        XCTAssertEqual(titles.count, 10)
        for (index, title) in titles.enumerated() {
            XCTAssertEqual(title, "Entry \(index)")
        }
    }

    func testFilterOperation() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()
        mockIndexRequests(client: client, baseURL: baseURL, total: 10)

        let publishedEntries = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .filter { entry in
                return (entry["published"] as? Bool) == true
            }
            .all()

        // Should have 5 published entries (even indices: 0, 2, 4, 6, 8)
        XCTAssertEqual(publishedEntries.count, 5)

        for entry in publishedEntries {
            XCTAssertTrue((entry["published"] as? Bool) == true)
        }
    }

    func testLimitOperation() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()
        mockIndexRequests(client: client, baseURL: baseURL, total: 100)

        let limitedEntries = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .limit(10)
            .all()

        XCTAssertEqual(limitedEntries.count, 10)

        for (index, entry) in limitedEntries.enumerated() {
            XCTAssertEqual(entry["title"] as? String, "Entry \(index)")
        }
    }

    func testSkipOperation() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()
        mockIndexRequests(client: client, baseURL: baseURL, total: 20)

        let skippedEntries = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .skip(10)
            .all()

        XCTAssertEqual(skippedEntries.count, 10)

        for (index, entry) in skippedEntries.enumerated() {
            XCTAssertEqual(entry["title"] as? String, "Entry \(index + 10)")
        }
    }

    func testSliceOperation() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()
        mockIndexRequests(client: client, baseURL: baseURL, total: 20)

        let slicedEntries = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .slice(5, 10)
            .all()

        XCTAssertEqual(slicedEntries.count, 5)

        for (index, entry) in slicedEntries.enumerated() {
            XCTAssertEqual(entry["title"] as? String, "Entry \(index + 5)")
        }
    }

    // MARK: - Chaining Tests

    func testComplexChaining() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()
        mockIndexRequests(client: client, baseURL: baseURL, total: 100)

        let result = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .filter { entry in
                return (entry["published"] as? Bool) == true
            }
            .map { entry in
                return (entry["title"] as? String ?? "").uppercased()
            }
            .limit(3)
            .all()

        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result[0], "ENTRY 0")
        XCTAssertEqual(result[1], "ENTRY 2")
        XCTAssertEqual(result[2], "ENTRY 4")
    }

    // MARK: - Collection Methods Tests

    func testAllMethod() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()
        mockIndexRequests(client: client, baseURL: baseURL, total: 5)

        let allEntries = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .all()

        XCTAssertEqual(allEntries.count, 5)

        for (index, entry) in allEntries.enumerated() {
            XCTAssertEqual(entry["title"] as? String, "Entry \(index)")
        }
    }

    func testFirstMethod() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()
        mockIndexRequests(client: client, baseURL: baseURL, total: 5)

        let firstEntry = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .first()

        XCTAssertNotNil(firstEntry)
        XCTAssertEqual(firstEntry?["title"] as? String, "Entry 0")
    }

    func testFirstMethodWithEmptyResult() async throws {
        let baseURL = URL(string: "https://example.com/not-found.json")!
        let client = MockHTTPClient()
        // Don't add any mock responses

        let firstEntry = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .first()

        XCTAssertNil(firstEntry)
    }

    func testCountMethod() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()
        mockIndexRequests(client: client, baseURL: baseURL, total: 15)

        let count = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .count()

        XCTAssertEqual(count, 15)
    }

    // MARK: - Document Following Tests

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

    // MARK: - Cache Tests

    func testCacheReload() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()
        mockIndexRequests(client: client, baseURL: baseURL, total: 5)

        let ffetch = FFetch(url: baseURL)
            .withHTTPClient(client)
            .withCacheReload(true)

        var count = 0
        for await _ in ffetch {
            count += 1
        }

        XCTAssertEqual(count, 5)
    }

    // MARK: - Concurrency Tests

    func testMaxConcurrency() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()
        mockIndexRequests(client: client, baseURL: baseURL, total: 10)

        let ffetch = FFetch(url: baseURL)
            .withHTTPClient(client)
            .withMaxConcurrency(2)

        var count = 0
        for await _ in ffetch {
            count += 1
        }

        XCTAssertEqual(count, 10)
    }

    // MARK: - Performance Tests

    func testPerformanceWithLargeDataset() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()
        mockIndexRequests(client: client, baseURL: baseURL, total: 1000)

        let startTime = CFAbsoluteTimeGetCurrent()

        let count = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .count()

        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime

        XCTAssertEqual(count, 1000)
        XCTAssertLessThan(duration, 5.0) // Should complete within 5 seconds
    }

    func testMemoryEfficiencyWithLargeDataset() async throws {
        let baseURL = URL(string: "https://example.com/query-index.json")!
        let client = MockHTTPClient()
        mockIndexRequests(client: client, baseURL: baseURL, total: 10000)

        // This test ensures we don't load all data into memory at once
        var count = 0
        for await _ in FFetch(url: baseURL).withHTTPClient(client) {
            count += 1
            if count >= 100 { // Only process first 100 items
                break
            }
        }

        XCTAssertEqual(count, 100)
    }

    // MARK: - Edge Cases

    func testEmptyResult() async throws {
        let baseURL = URL(string: "https://example.com/empty.json")!
        let client = MockHTTPClient()
        mockIndexRequests(client: client, baseURL: baseURL, total: 0)

        let entries = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .all()

        XCTAssertEqual(entries.count, 0)
    }

    func testSingleEntry() async throws {
        let baseURL = URL(string: "https://example.com/single.json")!
        let client = MockHTTPClient()
        mockIndexRequests(client: client, baseURL: baseURL, total: 1)

        let entries = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .all()

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0]["title"] as? String, "Entry 0")
    }

    func testExactChunkBoundary() async throws {
        let baseURL = URL(string: "https://example.com/boundary.json")!
        let client = MockHTTPClient()
        mockIndexRequests(client: client, baseURL: baseURL, total: 255, chunkSize: 255)

        let entries = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .chunks(255)
            .all()

        XCTAssertEqual(entries.count, 255)
    }

    // MARK: - Type Safety Tests

    func testFFetchResponseDecoding() throws {
        let jsonData = """
        {
            "total": 100,
            "offset": 0,
            "limit": 10,
            "data": [
                {"title": "Test", "count": 42, "active": true},
                {"title": "Test 2", "count": 24, "active": false}
            ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(FFetchResponse.self, from: jsonData)

        XCTAssertEqual(response.total, 100)
        XCTAssertEqual(response.offset, 0)
        XCTAssertEqual(response.limit, 10)
        XCTAssertEqual(response.data.count, 2)

        XCTAssertEqual(response.data[0]["title"] as? String, "Test")
        XCTAssertEqual(response.data[0]["count"] as? Int, 42)
        XCTAssertEqual(response.data[0]["active"] as? Bool, true)

        XCTAssertEqual(response.data[1]["title"] as? String, "Test 2")
        XCTAssertEqual(response.data[1]["count"] as? Int, 24)
        XCTAssertEqual(response.data[1]["active"] as? Bool, false)
    }

    func testAnyCodableWithComplexData() throws {
        let complexData = [
            "string": "hello",
            "number": 42,
            "boolean": true,
            "array": [1, 2, 3],
            "nested": ["key": "value"]
        ] as [String: Any]

        let encoded = try JSONEncoder().encode(complexData.mapValues { AnyCodable($0) })
        let decoded = try JSONDecoder().decode([String: AnyCodable].self, from: encoded)

        XCTAssertEqual(decoded["string"]?.value as? String, "hello")
        XCTAssertEqual(decoded["number"]?.value as? Int, 42)
        XCTAssertEqual(decoded["boolean"]?.value as? Bool, true)

        let decodedArray = decoded["array"]?.value as? [Int]
        XCTAssertEqual(decodedArray, [1, 2, 3])

        let decodedNested = decoded["nested"]?.value as? [String: Any]
        XCTAssertEqual(decodedNested?["key"] as? String, "value")
    }
}
