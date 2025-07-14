//
//  FFetchTypesErrorTests.swift
//  SwiftFFetchTests
//
//  Focused tests for FFetchError type
//
import XCTest
import Foundation
@testable import SwiftFFetch

final class FFetchTypesErrorTests: XCTestCase {

    // MARK: - FFetchError Tests

    func testFFetchErrorInvalidURL() {
        let error = FFetchError.invalidURL("not-a-url")
        XCTAssertEqual(error.errorDescription, "Invalid URL: not-a-url")
    }

    func testFFetchErrorNetworkError() {
        let underlyingError = NSError(domain: "test", code: 404, userInfo: [NSLocalizedDescriptionKey: "Not Found"])
        let error = FFetchError.networkError(underlyingError)
        XCTAssertEqual(error.errorDescription, "Network error: Not Found")
    }

    func testFFetchErrorDecodingError() {
        let underlyingError = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON"])
        let error = FFetchError.decodingError(underlyingError)
        XCTAssertEqual(error.errorDescription, "Decoding error: Invalid JSON")
    }

    func testFFetchErrorInvalidResponse() {
        let error = FFetchError.invalidResponse
        XCTAssertEqual(error.errorDescription, "Invalid response format")
    }

    func testFFetchErrorDocumentNotFound() {
        let error = FFetchError.documentNotFound
        XCTAssertEqual(error.errorDescription, "Document not found")
    }

    func testFFetchErrorOperationFailed() {
        let error = FFetchError.operationFailed("Custom operation error")
        XCTAssertEqual(error.errorDescription, "Operation failed: Custom operation error")
    }
}
