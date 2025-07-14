//
//  FFetchTypesHTMLParserTests.swift
//  SwiftFFetchTests
//
//  Focused tests for DefaultFFetchHTMLParser type
//
import XCTest
import Foundation
import SwiftSoup
@testable import SwiftFFetch

final class FFetchTypesHTMLParserTests: XCTestCase {

    // MARK: - DefaultFFetchHTMLParser Tests

    func testDefaultFFetchHTMLParserInit() {
        let parser = DefaultFFetchHTMLParser()
        XCTAssertNotNil(parser)
    }

    func testDefaultFFetchHTMLParserValidHTML() throws {
        let parser = DefaultFFetchHTMLParser()
        let html = "<html><body><h1>Test</h1></body></html>"

        let document = try parser.parse(html)
        XCTAssertNotNil(document)
        XCTAssertEqual(try document.select("h1").text(), "Test")
    }

    func testDefaultFFetchHTMLParserEmptyHTML() throws {
        let parser = DefaultFFetchHTMLParser()
        let html = ""

        let document = try parser.parse(html)
        XCTAssertNotNil(document)
    }

    func testDefaultFFetchHTMLParserMalformedHTML() throws {
        let parser = DefaultFFetchHTMLParser()
        let html = "<html><body><h1>Test</body></html>" // Missing closing h1 tag

        // SwiftSoup should handle malformed HTML gracefully
        let document = try parser.parse(html)
        XCTAssertNotNil(document)
        XCTAssertEqual(try document.select("h1").text(), "Test")
    }

    // MARK: - SwiftSoup Error Handling Tests

    func testDefaultFFetchHTMLParserWithSwiftSoupError() {
        // Create a scenario where SwiftSoup might fail
        let parser = DefaultFFetchHTMLParser()
        let extremelyLargeHTML = String(repeating: "<div>" + String(repeating: "x", count: 1000) + "</div>", count: 100)

        // This should not throw as SwiftSoup handles large documents
        XCTAssertNoThrow(try parser.parse(extremelyLargeHTML))
    }

    func testDefaultFFetchHTMLParserWithMalformedHTML() throws {
        let parser = DefaultFFetchHTMLParser()
        let malformedHTMLs = [
            "",
            "<html>",
            "</html>",
            "<text>unclosed",
            "<!DOCTYPE html><html><body><p></p></body></html>"
        ]

        for html in malformedHTMLs {
            let document = try parser.parse(html)
            XCTAssertNotNil(document)
        }
    }
}
