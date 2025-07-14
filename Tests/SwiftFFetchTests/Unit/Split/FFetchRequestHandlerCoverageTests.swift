//
//  FFetchRequestHandlerCoverageTests.swift
//  SwiftFFetchTests
//
//  Tests to improve coverage of FFetchRequestHandler internal logic
//  by creating specific scenarios through the FFetch public interface
//

import XCTest
@testable import SwiftFFetch

final class FFetchRequestHandlerCoverageTests: XCTestCase {

    // MARK: - Tests for HTTP Error Response Handling

    func testFFetchWithServerErrorStatusCodes() async throws {
        // Test to cover lines 124-128 in validateHTTPResponse - non-200, non-404 HTTP status codes
        let mockClient = MockHTTPClient()
        let baseURL = URL(string: "https://example.com/test.json")!

        let testCases = [500, 401, 403, 503, 422, 429]

        for statusCode in testCases {
            mockClient.responses.removeAll()
            mockClient.errors.removeAll()

            // Mock the first URL that will be called (with offset=0&limit=255)
            let firstURL = URL(string: "\(baseURL.absoluteString)?offset=0&limit=255")!
            mockClient.mockResponse(for: firstURL, data: Data(), statusCode: statusCode)

            let ffetch = FFetch(url: baseURL).withHTTPClient(mockClient)
            var yieldedCount = 0

            for await _ in ffetch {
                yieldedCount += 1
            }

            // Should not yield any entries for error status codes
            XCTAssertEqual(yieldedCount, 0, "Should not yield any entries for status code \(statusCode)")
        }
    }

    func testFFetchWith404StatusCode() async throws {
        // Test to cover lines 119-123 in validateHTTPResponse - 404 handling (graceful stream finish)
        let mockClient = MockHTTPClient()
        let baseURL = URL(string: "https://example.com/test.json")!

        // Mock 404 response - this should be handled gracefully
        let firstURL = URL(string: "\(baseURL.absoluteString)?offset=0&limit=255")!
        mockClient.mockResponse(for: firstURL, data: Data(), statusCode: 404)

        let ffetch = FFetch(url: baseURL).withHTTPClient(mockClient)
        var yieldedCount = 0

        for await _ in ffetch {
            yieldedCount += 1
        }

        // 404 should result in graceful termination with no entries
        XCTAssertEqual(yieldedCount, 0)
    }

    // MARK: - Tests for Error Rethrow Paths

    func testFFetchWithHTTPClientThrowingFFetchError() async throws {
        // Test to cover line 103 in executeRequest - FFetchError rethrow path
        let mockClient = MockHTTPClient()
        let baseURL = URL(string: "https://example.com/test.json")!

        let firstURL = URL(string: "\(baseURL.absoluteString)?offset=0&limit=255")!
        // Mock an FFetchError to be thrown by the HTTP client
        mockClient.mockError(for: firstURL, error: FFetchError.invalidURL("test error"))

        let ffetch = FFetch(url: baseURL).withHTTPClient(mockClient)
        var yieldedCount = 0

        for await _ in ffetch {
            yieldedCount += 1
        }

        // Should not yield any entries when HTTP client throws FFetchError
        XCTAssertEqual(yieldedCount, 0)
    }

    func testFFetchWithHTTPClientThrowingOtherError() async throws {
        // Test to cover lines 104-106 in executeRequest - other error conversion to FFetchError.networkError
        let mockClient = MockHTTPClient()
        let baseURL = URL(string: "https://example.com/test.json")!

        let firstURL = URL(string: "\(baseURL.absoluteString)?offset=0&limit=255")!
        // Mock a non-FFetchError to be thrown by the HTTP client
        let originalError = URLError(.timedOut)
        mockClient.mockError(for: firstURL, error: originalError)

        let ffetch = FFetch(url: baseURL).withHTTPClient(mockClient)
        var yieldedCount = 0

        for await _ in ffetch {
            yieldedCount += 1
        }

        // Should not yield any entries when HTTP client throws other errors
        XCTAssertEqual(yieldedCount, 0)
    }

    func testFFetchWithInvalidJSONResponse() async throws {
        // Test JSON decoding error path through executeRequest
        let mockClient = MockHTTPClient()
        let baseURL = URL(string: "https://example.com/test.json")!

        let firstURL = URL(string: "\(baseURL.absoluteString)?offset=0&limit=255")!
        // Mock invalid JSON data
        let invalidJSONData = Data("invalid json data".utf8)
        mockClient.mockResponse(for: firstURL, data: invalidJSONData, statusCode: 200)

        let ffetch = FFetch(url: baseURL).withHTTPClient(mockClient)
        var yieldedCount = 0

        for await _ in ffetch {
            yieldedCount += 1
        }

        // Should not yield any entries when JSON is invalid
        XCTAssertEqual(yieldedCount, 0)
    }

    // MARK: - Tests for Pagination Edge Cases

    func testFFetchWithTotalDiscoveryOnFirstRequest() async throws {
        // Test to cover line 45 - total discovery on first request
        let mockClient = MockHTTPClient()
        let baseURL = URL(string: "https://example.com/test.json")!

        let ffetch = FFetch(url: baseURL)
            .withHTTPClient(mockClient)
            .chunks(2) // Small chunk size to trigger multiple requests

        // Mock first request - total discovered here
        let firstEntries = [createTestEntry(index: 0), createTestEntry(index: 1)]
        let firstResponse = FFetchResponse(total: 3, offset: 0, limit: 2, data: firstEntries)
        let firstData = try JSONEncoder().encode(firstResponse)

        let firstURL = URL(string: "\(baseURL.absoluteString)?offset=0&limit=2")!
        mockClient.mockResponse(for: firstURL, data: firstData)

        // Mock second request - last entry
        let secondEntries = [createTestEntry(index: 2)]
        let secondResponse = FFetchResponse(total: 3, offset: 2, limit: 2, data: secondEntries)
        let secondData = try JSONEncoder().encode(secondResponse)

        let secondURL = URL(string: "\(baseURL.absoluteString)?offset=2&limit=2")!
        mockClient.mockResponse(for: secondURL, data: secondData)

        var yieldedEntries: [FFetchEntry] = []

        for await entry in ffetch {
            yieldedEntries.append(entry)
        }

        XCTAssertEqual(yieldedEntries.count, 3)
        // Verify that entries are in correct order
        for (index, entry) in yieldedEntries.enumerated() {
            XCTAssertEqual(entry["title"] as? String, "Entry \(index)")
        }
    }

    func testFFetchWithPaginationEndByTotal() async throws {
        // Test to cover lines 54-55 - pagination ending by checking offset + chunkSize >= total
        let mockClient = MockHTTPClient()
        let baseURL = URL(string: "https://example.com/test.json")!

        let ffetch = FFetch(url: baseURL)
            .withHTTPClient(mockClient)
            .chunks(3)

        // First request - 3 entries, total 5
        let firstEntries = Array(0..<3).map(createTestEntry)
        let firstResponse = FFetchResponse(total: 5, offset: 0, limit: 3, data: firstEntries)
        let firstData = try JSONEncoder().encode(firstResponse)

        let firstURL = URL(string: "\(baseURL.absoluteString)?offset=0&limit=3")!
        mockClient.mockResponse(for: firstURL, data: firstData)

        // Second request - 2 entries (reaching total, should trigger line 54-55)
        let secondEntries = Array(3..<5).map(createTestEntry)
        let secondResponse = FFetchResponse(total: 5, offset: 3, limit: 3, data: secondEntries)
        let secondData = try JSONEncoder().encode(secondResponse)

        let secondURL = URL(string: "\(baseURL.absoluteString)?offset=3&limit=3")!
        mockClient.mockResponse(for: secondURL, data: secondData)

        var yieldedEntries: [FFetchEntry] = []

        for await entry in ffetch {
            yieldedEntries.append(entry)
        }

        XCTAssertEqual(yieldedEntries.count, 5)
        // Verify entries are in correct order
        for (index, entry) in yieldedEntries.enumerated() {
            XCTAssertEqual(entry["title"] as? String, "Entry \(index)")
        }
    }

    // MARK: - Tests for Sheet Name Parameter

    func testFFetchWithSheetNameParameter() async throws {
        // Test to cover line 75 - sheet name parameter addition
        let mockClient = MockHTTPClient()
        let baseURL = URL(string: "https://example.com/test.json")!

        let ffetch = FFetch(url: baseURL)
            .withHTTPClient(mockClient)
            .sheet("testSheet")

        let entries = [createTestEntry(index: 0)]
        let response = FFetchResponse(total: 1, offset: 0, limit: 255, data: entries)
        let data = try JSONEncoder().encode(response)

        // The URL should include the sheet parameter
        let expectedURL = URL(string: "\(baseURL.absoluteString)?offset=0&limit=255&sheet=testSheet")!
        mockClient.mockResponse(for: expectedURL, data: data)

        var yieldedEntries: [FFetchEntry] = []

        for await entry in ffetch {
            yieldedEntries.append(entry)
        }

        XCTAssertEqual(yieldedEntries.count, 1)
        XCTAssertEqual(yieldedEntries.first?["title"] as? String, "Entry 0")
    }

    // MARK: - Integration Test for Network Error Mid-Pagination

    func testFFetchWithNetworkErrorMidPagination() async throws {
        // Test network error handling during pagination
        let mockClient = MockHTTPClient()
        let baseURL = URL(string: "https://example.com/test.json")!

        let ffetch = FFetch(url: baseURL)
            .withHTTPClient(mockClient)
            .chunks(2)

        // First request succeeds
        let firstEntries = [createTestEntry(index: 0), createTestEntry(index: 1)]
        let firstResponse = FFetchResponse(total: 4, offset: 0, limit: 2, data: firstEntries)
        let firstData = try JSONEncoder().encode(firstResponse)

        let firstURL = URL(string: "\(baseURL.absoluteString)?offset=0&limit=2")!
        mockClient.mockResponse(for: firstURL, data: firstData)

        // Second request fails
        let secondURL = URL(string: "\(baseURL.absoluteString)?offset=2&limit=2")!
        mockClient.mockError(for: secondURL, error: URLError(.networkConnectionLost))

        var yieldedEntries: [FFetchEntry] = []

        for await entry in ffetch {
            yieldedEntries.append(entry)
        }

        // Should have received first 2 entries before error stops iteration
        XCTAssertEqual(yieldedEntries.count, 2)
    }
}

// MARK: - Helper Functions

private func createTestEntry(index: Int) -> FFetchEntry {
    return [
        "title": "Entry \(index)",
        "path": "/entry-\(index)",
        "published": index % 2 == 0
    ]
}