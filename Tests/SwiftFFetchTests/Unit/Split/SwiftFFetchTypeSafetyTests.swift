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

    func testFFetchResponseEncoding() throws {
        let data: [FFetchEntry] = [
            ["title": "Test", "count": 42, "active": true],
            ["title": "Test 2", "count": 24, "active": false]
        ]
        let response = FFetchResponse(total: 100, offset: 0, limit: 10, data: data)

        let encoded = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(FFetchResponse.self, from: encoded)

        XCTAssertEqual(decoded.total, 100)
        XCTAssertEqual(decoded.offset, 0)
        XCTAssertEqual(decoded.limit, 10)
        XCTAssertEqual(decoded.data.count, 2)
        XCTAssertEqual(decoded.data[0]["title"] as? String, "Test")
        XCTAssertEqual(decoded.data[0]["count"] as? Int, 42)
        XCTAssertEqual(decoded.data[0]["active"] as? Bool, true)
    }

    func testFFetchResponseInit() {
        let data: [FFetchEntry] = [["key": "value"]]
        let response = FFetchResponse(total: 50, offset: 10, limit: 20, data: data)

        XCTAssertEqual(response.total, 50)
        XCTAssertEqual(response.offset, 10)
        XCTAssertEqual(response.limit, 20)
        XCTAssertEqual(response.data.count, 1)
        XCTAssertEqual(response.data[0]["key"] as? String, "value")
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

    func testAnyCodableWithPrimitiveTypes() throws {
        // Test Bool
        let boolValue = AnyCodable(true)
        let boolData = try JSONEncoder().encode(boolValue)
        let decodedBool = try JSONDecoder().decode(AnyCodable.self, from: boolData)
        XCTAssertEqual(decodedBool.value as? Bool, true)

        // Test Int
        let intValue = AnyCodable(42)
        let intData = try JSONEncoder().encode(intValue)
        let decodedInt = try JSONDecoder().decode(AnyCodable.self, from: intData)
        XCTAssertEqual(decodedInt.value as? Int, 42)

        // Test Double
        let doubleValue = AnyCodable(3.14)
        let doubleData = try JSONEncoder().encode(doubleValue)
        let decodedDouble = try JSONDecoder().decode(AnyCodable.self, from: doubleData)
        XCTAssertEqual(decodedDouble.value as? Double ?? 0.0, 3.14, accuracy: 0.001)

        // Test String
        let stringValue = AnyCodable("hello")
        let stringData = try JSONEncoder().encode(stringValue)
        let decodedString = try JSONDecoder().decode(AnyCodable.self, from: stringData)
        XCTAssertEqual(decodedString.value as? String, "hello")
    }

    func testAnyCodableWithArrayAndDictionary() throws {
        // Test Array
        let arrayValue = AnyCodable(["a", "b", "c"])
        let arrayData = try JSONEncoder().encode(arrayValue)
        let decodedArray = try JSONDecoder().decode(AnyCodable.self, from: arrayData)
        XCTAssertEqual(decodedArray.value as? [String], ["a", "b", "c"])

        // Test Dictionary
        let dictValue = AnyCodable(["key1": "value1", "key2": "value2"])
        let dictData = try JSONEncoder().encode(dictValue)
        let decodedDict = try JSONDecoder().decode(AnyCodable.self, from: dictData)
        let resultDict = decodedDict.value as? [String: String]
        XCTAssertEqual(resultDict?["key1"], "value1")
        XCTAssertEqual(resultDict?["key2"], "value2")
    }

    func testAnyCodableInvalidType() throws {
        // Test encoding unsupported type
        struct UnsupportedType {}
        let invalidValue = AnyCodable(UnsupportedType())

        XCTAssertThrowsError(try JSONEncoder().encode(invalidValue)) { error in
            XCTAssertTrue(error is EncodingError)
        }
    }

    func testAnyCodableDecodingError() throws {
        // Test invalid JSON that can't be decoded as any supported type
        let invalidData = Data("null".utf8)

        XCTAssertThrowsError(try JSONDecoder().decode(AnyCodable.self, from: invalidData)) { error in
            XCTAssertTrue(error is DecodingError)
        }
    }
}
