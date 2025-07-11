//
//  SwiftFFetchErrorHandlingTests.swift
//  SwiftFFetchTests
//
//  Tests for error handling in FFetch (not found, network error, etc.)
//

import XCTest
@testable import SwiftFFetch

final class SwiftFFetchErrorHandlingTests: XCTestCase {

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
}
