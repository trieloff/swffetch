//
//  FFetchTypesTests.swift
//  SwiftFFetchTests
//
//  Minimal comprehensive tests for all types in FFetchTypes.swift
//  This file now contains only core integration tests
//
import XCTest
import Foundation
import SwiftSoup
@testable import SwiftFFetch

final class FFetchTypesTests: XCTestCase {

    // MARK: - Core Integration Tests

    func testTypesIntegration() {
        // Test that all types work together correctly
        let context = FFetchContext()
        XCTAssertNotNil(context.httpClient)
        XCTAssertNotNil(context.htmlParser)

        // Test error creation
        let error = FFetchError.invalidURL("test")
        XCTAssertEqual(error.errorDescription, "Invalid URL: test")

        // Test cache config
        let config = FFetchCacheConfig.default
        XCTAssertEqual(config.policy, .useProtocolCachePolicy)

        // Test client creation
        let client = DefaultFFetchHTTPClient()
        XCTAssertNotNil(client)

        // Test parser creation
        let parser = DefaultFFetchHTMLParser()
        XCTAssertNotNil(parser)
    }

    func testFFetchResponseRoundTrip() throws {
        let originalData: [FFetchEntry] = [
            ["id": 1, "name": "Test"]
        ]
        let originalResponse = FFetchResponse(total: 1, offset: 0, limit: 10, data: originalData)

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let encodedData = try encoder.encode(originalResponse)
        let decodedResponse = try decoder.decode(FFetchResponse.self, from: encodedData)

        XCTAssertEqual(decodedResponse.total, 1)
        XCTAssertEqual(decodedResponse.data.count, 1)
    }
}
