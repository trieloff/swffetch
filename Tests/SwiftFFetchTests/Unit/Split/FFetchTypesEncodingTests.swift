//
//  FFetchTypesEncodingTests.swift
//  SwiftFFetchTests
//
//  Focused tests for encoding/decoding and type safety
//
import XCTest
import Foundation
@testable import SwiftFFetch

final class FFetchTypesEncodingTests: XCTestCase {

    // MARK: - Type Safety Edge Cases Tests

    func testFFetchEntryTypealias() {
        let entry: FFetchEntry = ["key": "value", "number": 42]
        XCTAssertEqual(entry["key"] as? String, "value")
        XCTAssertEqual(entry["number"] as? Int, 42)
    }

    func testFFetchTransformTypealias() async throws {
        let transform: FFetchTransform<String, Int> = { input in
            return input.count
        }

        let result = try await transform("hello")
        XCTAssertEqual(result, 5)
    }

    func testFFetchPredicateTypealias() async throws {
        let predicate: FFetchPredicate<String> = { input in
            return input.count > 3
        }

        let result1 = try await predicate("hello")
        let result2 = try await predicate("hi")
        XCTAssertTrue(result1)
        XCTAssertFalse(result2)
    }

    // MARK: - Advanced Tests for Coverage Enhancement

    func testFFetchResponseEncodingDecodingRoundTrip() throws {
        let originalData: [FFetchEntry] = [
            ["id": 1, "name": "Test 1", "active": true],
            ["id": 2, "name": "Test 2", "active": false]
        ]
        let originalResponse = FFetchResponse(total: 100, offset: 0, limit: 10, data: originalData)

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let encodedData = try encoder.encode(originalResponse)
        let decodedResponse = try decoder.decode(FFetchResponse.self, from: encodedData)

        XCTAssertEqual(decodedResponse.total, originalResponse.total)
        XCTAssertEqual(decodedResponse.offset, originalResponse.offset)
        XCTAssertEqual(decodedResponse.limit, originalResponse.limit)
        XCTAssertEqual(decodedResponse.data.count, originalResponse.data.count)
        XCTAssertEqual(decodedResponse.data[0]["id"] as? Int, 1)
        XCTAssertEqual(decodedResponse.data[0]["name"] as? String, "Test 1")
        XCTAssertEqual(decodedResponse.data[0]["active"] as? Bool, true)
    }

    func testFFetchResponseDecodingWithComplexTypes() throws {
        let jsonString = """
        {
            "total": 50,
            "offset": 10,
            "limit": 5,
            "data": [
                {
                    "id": 1,
                    "nested": {"key": "value"},
                    "array": [1, 2, 3],
                    "value": 42
                }
            ]
        }
        """

        let jsonData = jsonString.data(using: .utf8)!
        let response = try JSONDecoder().decode(FFetchResponse.self, from: jsonData)

        XCTAssertEqual(response.total, 50)
        XCTAssertEqual(response.offset, 10)
        XCTAssertEqual(response.limit, 5)
        XCTAssertEqual(response.data.count, 1)
        XCTAssertNotNil(response.data[0]["nested"])
        XCTAssertNotNil(response.data[0]["array"])
    }

    // MARK: - AnyCodable Edge Cases Tests

    func testAnyCodableWithComplexDecodingType() throws {
        let jsonString = "{\"value\": \"test\", \"number\": 42}"
        let jsonData = jsonString.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(AnyCodable.self, from: jsonData)
        let dict = decoded.value as? [String: Any]
        XCTAssertNotNil(dict)
        XCTAssertEqual(dict?["value"] as? String, "test")
    }

    func testAnyCodableWithUnsupportedEncodingType() throws {
        struct UnsupportedType {
            let value: String
        }

        let unsupportedValue = UnsupportedType(value: "test")
        let anyCodable = AnyCodable(unsupportedValue)

        XCTAssertThrowsError(try JSONEncoder().encode(anyCodable)) { error in
            XCTAssertTrue(error is EncodingError)
        }
    }

    func testAnyCodableWithNestedStructures() throws {
        let nestedDict: [String: Any] = [
            "level1": ["level2": ["value": 42]],
            "array": [[1, 2], [3, 4]],
            "mixed": ["string", 123, true]
        ]

        let anyCodable = AnyCodable(nestedDict)
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let encodedData = try encoder.encode(anyCodable)
        let decodedAnyCodable = try decoder.decode(AnyCodable.self, from: encodedData)

        XCTAssertNotNil(decodedAnyCodable.value)
    }

    func testAnyCodableWithEmptyCollections() throws {
        let emptyDict: [String: Any] = [:]
        let emptyArray: [Any] = []

        let dictCodable = AnyCodable(emptyDict)
        let arrayCodable = AnyCodable(emptyArray)

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let encodedDict = try encoder.encode(dictCodable)
        let encodedArray = try encoder.encode(arrayCodable)

        let decodedDict = try decoder.decode(AnyCodable.self, from: encodedDict)
        let decodedArray = try decoder.decode(AnyCodable.self, from: encodedArray)

        XCTAssertTrue((decodedDict.value as? [String: Any])?.isEmpty ?? false)
        XCTAssertTrue((decodedArray.value as? [Any])?.isEmpty ?? false)
    }
}
