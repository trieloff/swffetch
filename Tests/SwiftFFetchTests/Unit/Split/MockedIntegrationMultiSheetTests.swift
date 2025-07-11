//
//  MockedIntegrationMultiSheetTests.swift
//  SwiftFFetchTests
//
//  Integration test for multi-sheet workflows using AdvancedMockHTTPClient.
//

import XCTest
@testable import SwiftFFetch

final class MockedIntegrationMultiSheetTests: XCTestCase {

    func testMultiSheetWorkflow() async throws {
        let client = AdvancedMockHTTPClient()
        let baseURL = "https://example.com/multi-sheet-index.json"

        // Mock two sheets: "products" and "blog"
        let productsEntries = (0..<5).map { id in
            [
                "id": id,
                "name": "Product \(id)",
                "path": "/products/product-\(id)",
                "sheet": "products"
            ] as [String: Any]
        }
        let blogEntries = (0..<3).map { id in
            [
                "id": id,
                "title": "Blog \(id)",
                "path": "/blog/post-\(id)",
                "sheet": "blog"
            ] as [String: Any]
        }

        let productsResponse = FFetchResponse(
            total: 5,
            offset: 0,
            limit: 255,
            data: productsEntries
        )
        let blogResponse = FFetchResponse(
            total: 3,
            offset: 0,
            limit: 255,
            data: blogEntries
        )

        let encoder = JSONEncoder()
        let productsData = try encoder.encode(productsResponse)
        let blogData = try encoder.encode(blogResponse)

        client.mockResponse(for: "\(baseURL)?offset=0&limit=255&sheet=products", data: productsData)
        client.mockResponse(for: "\(baseURL)?offset=0&limit=255&sheet=blog", data: blogData)

        // Test fetching products sheet
        let products = try await FFetch(url: URL(string: baseURL)!)
            .withHTTPClient(client)
            .sheet("products")
            .all()
        XCTAssertEqual(products.count, 5)
        XCTAssertEqual(products.first?["sheet"] as? String, "products")

        // Test fetching blog sheet
        let blogs = try await FFetch(url: URL(string: baseURL)!)
            .withHTTPClient(client)
            .sheet("blog")
            .all()
        XCTAssertEqual(blogs.count, 3)
        XCTAssertEqual(blogs.first?["sheet"] as? String, "blog")
    }
}
