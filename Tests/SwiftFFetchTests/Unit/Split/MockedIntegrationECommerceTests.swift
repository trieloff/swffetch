//
//  MockedIntegrationECommerceTests.swift
//  SwiftFFetchTests
//
//  Integration tests for e-commerce and performance scenarios using AdvancedMockHTTPClient.
//

import XCTest
@testable import SwiftFFetch

final class MockedIntegrationECommerceTests: XCTestCase {

    func testECommerceProductCatalog() async throws {
        let client = AdvancedMockHTTPClient()
        mockProductIndex(client: client, total: 100)

        let ffetch = FFetch(url: URL(string: "https://example.com/products-index.json")!)
            .withHTTPClient(client)

        var count = 0
        var totalPrice: Double = 0
        var inStockCount = 0

        for await entry in ffetch {
            count += 1
            if let price = entry["price"] as? Double {
                totalPrice += price
            }
            if let inStock = entry["inStock"] as? Bool, inStock {
                inStockCount += 1
            }
        }

        XCTAssertEqual(count, 100)
        XCTAssertGreaterThan(totalPrice, 0)
        XCTAssertGreaterThan(inStockCount, 0)
    }

    func testPerformanceOptimizedStreaming() async throws {
        let client = AdvancedMockHTTPClient()
        mockProductIndex(client: client, total: 1000)

        let ffetch = FFetch(url: URL(string: "https://example.com/products-index.json")!)
            .withHTTPClient(client)
            .chunks(100)

        var count = 0
        let startTime = CFAbsoluteTimeGetCurrent()

        for await _ in ffetch {
            count += 1
        }

        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime

        XCTAssertEqual(count, 1000)
        XCTAssertLessThan(duration, 5.0, "Should stream 1000 products in under 5 seconds")
    }
}
