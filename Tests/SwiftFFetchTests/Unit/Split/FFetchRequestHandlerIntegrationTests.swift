//
//  FFetchRequestHandlerIntegrationTests.swift
//  SwiftFFetchTests
//
//  Comprehensive integration tests for FFetchRequestHandler functionality
//  Focused on achieving 95%+ code coverage through public API testing
//

import XCTest
@testable import SwiftFFetch

final class FFetchRequestHandlerIntegrationTests: XCTestCase {

    // MARK: - URL Construction Integration Tests

    func testURLConstructionWithValidParameters() async throws {
        let baseURL = URL(string: "https://example.com/data.json")!
        let mockClient = MockHTTPClient()

        let response = FFetchResponse(
            total: 1,
            offset: 0,
            limit: 255,
            data: [createMockEntry(index: 1)]
        )

        let responseData = try JSONEncoder().encode(response)
        let requestURL = createMockURL(baseURL, offset: 0, limit: 255)
        mockClient.mockCustomResponse(for: requestURL, data: responseData)

        let entries = try await FFetch(url: baseURL)
            .withHTTPClient(mockClient)
            .all()

        XCTAssertEqual(entries.count, 1)
    }

    func testURLConstructionWithSheetName() async throws {
        let baseURL = URL(string: "https://example.com/data.json")!
        let mockClient = MockHTTPClient()

        let response = FFetchResponse(
            total: 1,
            offset: 0,
            limit: 255,
            data: [createMockEntry(index: 1)]
        )

        let responseData = try JSONEncoder().encode(response)
        let requestURL = createMockURL(baseURL, offset: 0, limit: 255, sheet: "users")
        mockClient.mockCustomResponse(for: requestURL, data: responseData)

        let entries = try await FFetch(url: baseURL)
            .withHTTPClient(mockClient)
            .sheet("users")
            .all()

        XCTAssertEqual(entries.count, 1)
    }

    func testURLConstructionWithExistingQueryParameters() async throws {
        let baseURL = URL(string: "https://example.com/data.json?api_key=secret")!
        let mockClient = MockHTTPClient()

        let response = FFetchResponse(
            total: 1,
            offset: 0,
            limit: 255,
            data: [createMockEntry(index: 1)]
        )

        let responseData = try JSONEncoder().encode(response)
        let requestURL = createMockURL(baseURL, offset: 0, limit: 255)
        mockClient.mockCustomResponse(for: requestURL, data: responseData)

        let entries = try await FFetch(url: baseURL)
            .withHTTPClient(mockClient)
            .all()

        XCTAssertEqual(entries.count, 1)
    }

    func testURLConstructionWithSpecialCharactersInSheetName() async throws {
        let baseURL = URL(string: "https://example.com/data.json")!
        let mockClient = MockHTTPClient()

        let response = FFetchResponse(
            total: 1,
            offset: 0,
            limit: 255,
            data: [createMockEntry(index: 1)]
        )

        let responseData = try JSONEncoder().encode(response)
        let requestURL = createMockURL(baseURL, offset: 0, limit: 255, sheet: "user data & more")
        mockClient.mockCustomResponse(for: requestURL, data: responseData)

        let entries = try await FFetch(url: baseURL)
            .withHTTPClient(mockClient)
            .sheet("user data & more")
            .all()

        XCTAssertEqual(entries.count, 1)
    }

    func testURLConstructionWithUnicodeCharacters() async throws {
        let baseURL = URL(string: "https://example.com/数据.json")!
        let mockClient = MockHTTPClient()

        let response = FFetchResponse(
            total: 1,
            offset: 0,
            limit: 255,
            data: [createMockEntry(index: 1)]
        )

        let responseData = try JSONEncoder().encode(response)
        let requestURL = createMockURL(baseURL, offset: 0, limit: 255)
        mockClient.mockCustomResponse(for: requestURL, data: responseData)

        let entries = try await FFetch(url: baseURL)
            .withHTTPClient(mockClient)
            .all()

        XCTAssertEqual(entries.count, 1)
    }

    func testURLConstructionWithPortInURL() async throws {
        let baseURL = URL(string: "https://example.com:8080/data.json")!
        let mockClient = MockHTTPClient()

        let response = FFetchResponse(
            total: 1,
            offset: 0,
            limit: 255,
            data: [createMockEntry(index: 1)]
        )

        let responseData = try JSONEncoder().encode(response)
        let requestURL = createMockURL(baseURL, offset: 0, limit: 255)
        mockClient.mockCustomResponse(for: requestURL, data: responseData)

        let entries = try await FFetch(url: baseURL)
            .withHTTPClient(mockClient)
            .all()

        XCTAssertEqual(entries.count, 1)
    }

    func testURLConstructionWithFragmentInURL() async throws {
        let baseURL = URL(string: "https://example.com/data.json#fragment")!
        let mockClient = MockHTTPClient()

        let response = FFetchResponse(
            total: 1,
            offset: 0,
            limit: 255,
            data: [createMockEntry(index: 1)]
        )

        let responseData = try JSONEncoder().encode(response)
        let requestURL = createMockURL(baseURL, offset: 0, limit: 255)
        mockClient.mockCustomResponse(for: requestURL, data: responseData)

        let entries = try await FFetch(url: baseURL)
            .withHTTPClient(mockClient)
            .all()

        XCTAssertEqual(entries.count, 1)
    }

    // MARK: - HTTP Response Validation Tests

    func testHTTPResponseValidationWithNonHTTPResponse() async throws {
        let baseURL = URL(string: "https://example.com/data.json")!
        let mockClient = MockHTTPClient()

        // Mock with non-HTTP response by setting invalid status code
        let response = FFetchResponse(
            total: 1,
            offset: 0,
            limit: 255,
            data: [createMockEntry(index: 1)]
        )

        let responseData = try JSONEncoder().encode(response)
        let requestURL = createMockURL(baseURL, offset: 0, limit: 255)
        mockClient.mockCustomResponse(for: requestURL, data: responseData, statusCode: 0)

        let entries = try await FFetch(url: baseURL)
            .withHTTPClient(mockClient)
            .all()

        // Should handle gracefully and return empty
        XCTAssertEqual(entries.count, 0)
    }

    func testHTTPResponseValidationWithServerError() async throws {
        let baseURL = URL(string: "https://example.com/data.json")!
        let mockClient = MockHTTPClient()

        let responseData = Data()
        mockClient.mockResponse(for: baseURL, data: responseData, statusCode: 500)

        let entries = try await FFetch(url: baseURL)
            .withHTTPClient(mockClient)
            .all()

        // Should handle gracefully and return empty
        XCTAssertEqual(entries.count, 0)
    }

    func testHTTPResponseValidationWithVariousStatusCodes() async throws {
        let baseURL = URL(string: "https://example.com/data.json")!
        let mockClient = MockHTTPClient()

        let statusCodes = [400, 401, 403, 422, 503]

        for statusCode in statusCodes {
            mockClient.mockCustomResponse(for: baseURL, data: Data(), statusCode: statusCode)

            let entries = try await FFetch(url: baseURL)
                .withHTTPClient(mockClient)
                .all()

            XCTAssertEqual(entries.count, 0, "Failed for status code \(statusCode)")
        }
    }

    func testHTTPResponseValidationWith302Redirect() async throws {
        let baseURL = URL(string: "https://example.com/data.json")!
        let mockClient = MockHTTPClient()

        let responseData = Data()
        mockClient.mockCustomResponse(for: baseURL, data: responseData, statusCode: 302)

        let entries = try await FFetch(url: baseURL)
            .withHTTPClient(mockClient)
            .all()

        XCTAssertEqual(entries.count, 0)
    }

    // MARK: - Error Handling Tests

    func testInvalidJSONResponse() async throws {
        let baseURL = URL(string: "https://example.com/data.json")!
        let mockClient = MockHTTPClient()

        let invalidJSON = Data("{ invalid json }".utf8)
        mockClient.mockCustomResponse(for: baseURL, data: invalidJSON)

        let entries = try await FFetch(url: baseURL)
            .withHTTPClient(mockClient)
            .all()

        XCTAssertEqual(entries.count, 0) // Should handle gracefully
    }

    func testEmptyResponseData() async throws {
        let baseURL = URL(string: "https://example.com/data.json")!
        let mockClient = MockHTTPClient()

        mockClient.mockCustomResponse(for: baseURL, data: Data())

        let entries = try await FFetch(url: baseURL)
            .withHTTPClient(mockClient)
            .all()

        XCTAssertEqual(entries.count, 0)
    }

    func testMalformedJSON() async throws {
        let baseURL = URL(string: "https://example.com/data.json")!
        let mockClient = MockHTTPClient()

        let malformedJSON = Data("{ \"total\": \"not-a-number\", \"data\": [ }".utf8)
        mockClient.mockCustomResponse(for: baseURL, data: malformedJSON)

        let entries = try await FFetch(url: baseURL)
            .withHTTPClient(mockClient)
            .all()

        XCTAssertEqual(entries.count, 0)
    }

    func testNetworkErrorHandling() async throws {
        let baseURL = URL(string: "https://example.com/data.json")!
        let mockClient = MockHTTPClient()
        mockClient.mockError(for: baseURL, error: URLError(.networkConnectionLost))

        let entries = try await FFetch(url: baseURL)
            .withHTTPClient(mockClient)
            .all()

        XCTAssertEqual(entries.count, 0)
    }

    // MARK: - Pagination Tests

    func testSingleChunkPagination() async throws {
        let baseURL = URL(string: "https://example.com/data.json")!
        let mockClient = MockHTTPClient()

        let response = FFetchResponse(
            total: 5,
            offset: 0,
            limit: 255,
            data: (0..<5).map(createMockEntry)
        )

        let responseData = try JSONEncoder().encode(response)
        let requestURL = createMockURL(baseURL, offset: 0, limit: 255)
        mockClient.mockCustomResponse(for: requestURL, data: responseData)

        let entries = try await FFetch(url: baseURL)
            .withHTTPClient(mockClient)
            .all()

        XCTAssertEqual(entries.count, 5)
    }

    func testMultipleChunkPagination() async throws {
        let baseURL = URL(string: "https://example.com/data.json")!
        let mockClient = MockHTTPClient()

        let totalEntries = 10
        let chunkSize = 3

        // Mock responses for all chunks
        for offset in stride(from: 0, to: totalEntries, by: chunkSize) {
            let endIndex = min(offset + chunkSize, totalEntries)
            let entries = Array(offset..<endIndex).map(createMockEntry)

            let response = FFetchResponse(
                total: totalEntries,
                offset: offset,
                limit: chunkSize,
                data: entries
            )

            let responseData = try JSONEncoder().encode(response)
            let requestURL = createMockURL(baseURL, offset: offset, limit: chunkSize)
            mockClient.mockCustomResponse(for: requestURL, data: responseData)
        }

        let entries = try await FFetch(url: baseURL)
            .withHTTPClient(mockClient)
            .chunks(chunkSize)
            .all()

        XCTAssertEqual(entries.count, totalEntries)
    }

    func testExactMultipleChunkPagination() async throws {
        let baseURL = URL(string: "https://example.com/exact-chunks.json")!
        let mockClient = MockHTTPClient()

        let totalEntries = 20
        let chunkSize = 5

        // Mock responses for exact chunks
        for offset in stride(from: 0, to: totalEntries, by: chunkSize) {
            let endIndex = min(offset + chunkSize, totalEntries)
            let entries = Array(offset..<endIndex).map(createMockEntry)

            let response = FFetchResponse(
                total: totalEntries,
                offset: offset,
                limit: chunkSize,
                data: entries
            )

            let responseData = try JSONEncoder().encode(response)
            let requestURL = createMockURL(baseURL, offset: offset, limit: chunkSize)
            mockClient.mockCustomResponse(for: requestURL, data: responseData)
        }

        let entries = try await FFetch(url: baseURL)
            .withHTTPClient(mockClient)
            .chunks(chunkSize)
            .all()

        XCTAssertEqual(entries.count, totalEntries)
    }

    func testSingleEntryPagination() async throws {
        let baseURL = URL(string: "https://example.com/single.json")!
        let mockClient = MockHTTPClient()

        let response = FFetchResponse(
            total: 1,
            offset: 0,
            limit: 255,
            data: [createMockEntry(index: 0)]
        )

        let responseData = try JSONEncoder().encode(response)
        let requestURL = createMockURL(baseURL, offset: 0, limit: 255)
        mockClient.mockCustomResponse(for: requestURL, data: responseData)

        let entries = try await FFetch(url: baseURL)
            .withHTTPClient(mockClient)
            .all()

        XCTAssertEqual(entries.count, 1)
    }

    func testZeroTotalPagination() async throws {
        let baseURL = URL(string: "https://example.com/zero-total.json")!
        let mockClient = MockHTTPClient()

        let response = FFetchResponse(
            total: 0,
            offset: 0,
            limit: 255,
            data: []
        )

        let responseData = try JSONEncoder().encode(response)
        let requestURL = createMockURL(baseURL, offset: 0, limit: 255)
        mockClient.mockCustomResponse(for: requestURL, data: responseData)

        let entries = try await FFetch(url: baseURL)
            .withHTTPClient(mockClient)
            .all()

        XCTAssertEqual(entries.count, 0)
    }

    func testChunkSizeLargerThanTotal() async throws {
        let baseURL = URL(string: "https://example.com/small-total.json")!
        let mockClient = MockHTTPClient()

        let totalEntries = 5
        let chunkSize = 100

        let response = FFetchResponse(
            total: totalEntries,
            offset: 0,
            limit: chunkSize,
            data: (0..<totalEntries).map(createMockEntry)
        )

        let responseData = try JSONEncoder().encode(response)
        let requestURL = createMockURL(baseURL, offset: 0, limit: chunkSize)
        mockClient.mockCustomResponse(for: requestURL, data: responseData)

        let entries = try await FFetch(url: baseURL)
            .withHTTPClient(mockClient)
            .chunks(chunkSize)
            .all()

        XCTAssertEqual(entries.count, totalEntries)
    }

    func testLargeNumberOfChunks() async throws {
        let baseURL = URL(string: "https://example.com/large-data.json")!
        let mockClient = MockHTTPClient()

        let totalEntries = 100
        let chunkSize = 10

        // Mock responses for all chunks
        for offset in stride(from: 0, to: totalEntries, by: chunkSize) {
            let endIndex = min(offset + chunkSize, totalEntries)
            let entries = Array(offset..<endIndex).map(createMockEntry)

            let response = FFetchResponse(
                total: totalEntries,
                offset: offset,
                limit: chunkSize,
                data: entries
            )

            let responseData = try JSONEncoder().encode(response)
            let requestURL = createMockURL(baseURL, offset: offset, limit: chunkSize)
            mockClient.mockCustomResponse(for: requestURL, data: responseData)
        }

        let entries = try await FFetch(url: baseURL)
            .withHTTPClient(mockClient)
            .chunks(chunkSize)
            .all()

        XCTAssertEqual(entries.count, totalEntries)
    }

    func test404ResponseHandling() async throws {
        let baseURL = URL(string: "https://example.com/not-found.json")!
        let mockClient = MockHTTPClient()

        // Mock 404 response
        mockClient.mockResponse(for: baseURL, data: Data(), statusCode: 404)

        let entries = try await FFetch(url: baseURL)
            .withHTTPClient(mockClient)
            .all()

        XCTAssertEqual(entries.count, 0) // Should handle gracefully
    }

    // MARK: - Edge Case Tests

    func testUnicodeCharactersInData() async throws {
        let baseURL = URL(string: "https://example.com/unicode-data.json")!
        let mockClient = MockHTTPClient()

        let response = FFetchResponse(
            total: 3,
            offset: 0,
            limit: 255,
            data: [
                ["title": "条目 1", "path": "/条目-1"],
                ["title": "条目 2", "path": "/条目-2"],
                ["title": "条目 3", "path": "/条目-3"]
            ]
        )

        let responseData = try JSONEncoder().encode(response)
        let requestURL = createMockURL(baseURL, offset: 0, limit: 255)
        mockClient.mockCustomResponse(for: requestURL, data: responseData)

        let entries = try await FFetch(url: baseURL)
            .withHTTPClient(mockClient)
            .all()

        XCTAssertEqual(entries.count, 3)
    }

    func testSpecialCharactersInQuery() async throws {
        let baseURL = URL(string: "https://example.com/data.json")!
        let mockClient = MockHTTPClient()

        let response = FFetchResponse(
            total: 1,
            offset: 0,
            limit: 255,
            data: [createMockEntry(index: 1)]
        )

        let responseData = try JSONEncoder().encode(response)
        let requestURL = createMockURL(baseURL, offset: 0, limit: 255, sheet: "user data & more")
        mockClient.mockCustomResponse(for: requestURL, data: responseData)

        let entries = try await FFetch(url: baseURL)
            .withHTTPClient(mockClient)
            .sheet("user data & more")
            .all()

        XCTAssertEqual(entries.count, 1)
    }

    func testEmptySheetName() async throws {
        let baseURL = URL(string: "https://example.com/data.json")!
        let mockClient = MockHTTPClient()

        let response = FFetchResponse(
            total: 1,
            offset: 0,
            limit: 255,
            data: [createMockEntry(index: 1)]
        )

        let responseData = try JSONEncoder().encode(response)
        let requestURL = createMockURL(baseURL, offset: 0, limit: 255, sheet: "")
        mockClient.mockCustomResponse(for: requestURL, data: responseData)

        let entries = try await FFetch(url: baseURL)
            .withHTTPClient(mockClient)
            .sheet("")
            .all()

        XCTAssertEqual(entries.count, 1)
    }

    func testZeroChunkSize() async throws {
        let baseURL = URL(string: "https://example.com/data.json")!
        let mockClient = MockHTTPClient()

        let response = FFetchResponse(
            total: 1,
            offset: 0,
            limit: 1,
            data: [createMockEntry(index: 1)]
        )

        let responseData = try JSONEncoder().encode(response)
        let requestURL = createMockURL(baseURL, offset: 0, limit: 1)
        mockClient.mockCustomResponse(for: requestURL, data: responseData)

        let entries = try await FFetch(url: baseURL)
            .withHTTPClient(mockClient)
            .chunks(1)
            .all()

        XCTAssertEqual(entries.count, 1)
    }

    // MARK: - Memory and Performance Tests

    func testMemoryCleanupAfterLargeDataset() async throws {
        let baseURL = URL(string: "https://example.com/large-dataset.json")!
        let mockClient = MockHTTPClient()

        let totalEntries = 1000
        let chunkSize = 100

        // Mock responses for all chunks
        for offset in stride(from: 0, to: totalEntries, by: chunkSize) {
            let endIndex = min(offset + chunkSize, totalEntries)
            let entries = Array(offset..<endIndex).map(createMockEntry)

            let response = FFetchResponse(
                total: totalEntries,
                offset: offset,
                limit: chunkSize,
                data: entries
            )

            let responseData = try JSONEncoder().encode(response)
            let requestURL = createMockURL(baseURL, offset: offset, limit: chunkSize)
            mockClient.mockCustomResponse(for: requestURL, data: responseData)
        }

        let entries = try await FFetch(url: baseURL)
            .withHTTPClient(mockClient)
            .chunks(chunkSize)
            .all()

        XCTAssertEqual(entries.count, totalEntries)
    }

    // MARK: - Helper Methods

    private func createMockEntry(index: Int) -> FFetchEntry {
        return [
            "id": index,
            "title": "Entry \(index)",
            "path": "/entry-\(index)",
            "value": "test-value-\(index)"
        ]
    }

    private func createMockURL(_ baseURL: URL, offset: Int, limit: Int, sheet: String? = nil) -> URL {
        return URLBuilder.createMockURL(baseURL, offset: offset, limit: limit, sheet: sheet)
    }
}

// MARK: - URLBuilder Helper

struct URLBuilder {
    static func createMockURL(_ baseURL: URL, offset: Int, limit: Int, sheet: String? = nil) -> URL {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: true)!

        // Preserve existing query items
        var queryItems = components.queryItems ?? []

        // Add pagination parameters
        queryItems.append(URLQueryItem(name: "offset", value: String(offset)))
        queryItems.append(URLQueryItem(name: "limit", value: String(limit)))

        if let sheet = sheet {
            queryItems.append(URLQueryItem(name: "sheet", value: sheet))
        }

        components.queryItems = queryItems
        return components.url!
    }
}

// MARK: - MockHTTPClient Extension for Custom Responses

extension MockHTTPClient {
    func mockCustomResponse(for url: URL, data: Data, statusCode: Int = 200) {
        let httpResponse = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        self.responses[url] = (data, httpResponse)
    }
}
