//
//  SwiftFFetchTypeSafetyTests.swift
//  SwiftFFetchTests
//
//  Tests for decoding, AnyCodable, and type safety in FFetch.
//
import XCTest
@testable import SwiftFFetch

final class SwiftFFetchTypeSafetyTests: XCTestCase {

    func testFFetchResponseDecoding() throws {
        let jsonData = Data("""
        {
            "total": 100,
            "offset": 0,
            "limit": 10,
            "data": [
                {"title": "Test", "count": 42, "active": true},
                {"title": "Test 2", "count": 24, "active": false}
            ]
        }
        """.utf8)

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
