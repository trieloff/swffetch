//
//  SwiftFFetchInitializationTests.swift
//  SwiftFFetchTests
//
//  Tests for FFetch initialization and convenience functions.
//

import XCTest
@testable import SwiftFFetch

final class SwiftFFetchInitializationTests: XCTestCase {

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
}
