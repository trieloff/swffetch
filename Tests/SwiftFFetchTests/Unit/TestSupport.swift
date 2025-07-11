//
//  TestSupport.swift
//  SwiftFFetchTests
//
//  Shared test support: mock HTTP client and helpers
//
//  Integration helpers and advanced mock client for integration tests
//

import XCTest
import Foundation
@testable import SwiftFFetch

class MockHTTPClient: FFetchHTTPClient {
    var responses: [URL: (Data, HTTPURLResponse)] = [:]
    var errors: [URL: Error] = [:]

    func fetch(_ url: URL, cachePolicy: URLRequest.CachePolicy) async throws -> (Data, URLResponse) {
        // Try exact match first
        if let error = errors[url] {
            throw error
        }
        if let response = responses[url] {
            return response
        }

        // Try to match relative URLs against the entry point base URL
        // (Assume the entry point is always absolute and all other paths are relative)
        if !url.isFileURL, url.scheme != nil,
           let base = responses.keys.first(where: { $0.scheme != nil && $0.host == url.host }) {
            // Compose a relative path from the base
            let relative = URL(string: url.path, relativeTo: base)?.absoluteURL
            if let relative = relative {
                if let error = errors[relative] {
                    throw error
                }
                if let response = responses[relative] {
                    return response
                }
            }
        }
        // Default 404 response
        let httpResponse = HTTPURLResponse(
            url: url,
            statusCode: 404,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )!
        return (Data(), httpResponse)
    }

    func mockResponse(for url: URL, data: Data, statusCode: Int = 200) {
        let httpResponse = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        responses[url] = (data, httpResponse)
    }

    func mockError(for url: URL, error: Error) {
        errors[url] = error
    }
}

// MARK: - Integration helpers and advanced mock client

class AdvancedMockHTTPClient: FFetchHTTPClient {
    private var requestCount = 0
    private var requestDelays: [TimeInterval] = []
    private var responses: [String: (Data, HTTPURLResponse)] = [:]
    private var errors: [String: Error] = [:]

    func addDelay(_ delay: TimeInterval) {
        requestDelays.append(delay)
    }

    func fetch(_ url: URL, cachePolicy: URLRequest.CachePolicy) async throws -> (Data, URLResponse) {
        requestCount += 1

        // Simulate network delay
        if requestCount <= requestDelays.count {
            try await Task.sleep(nanoseconds: UInt64(requestDelays[requestCount - 1] * 1_000_000_000))
        }

        let key = url.absoluteString

        if let error = errors[key] {
            throw error
        }

        if let response = responses[key] {
            return response
        }

        // Try to match relative URLs against the entry point base URL
        if let base = responses.keys.first(where: { $0.hasPrefix("https://") }) {
            if let relativeURL = URL(string: url.path, relativeTo: URL(string: base))?.absoluteString {
                if let error = errors[relativeURL] {
                    throw error
                }
                if let response = responses[relativeURL] {
                    return response
                }
            }
        }

        // Default 404 response
        let httpResponse = HTTPURLResponse(
            url: url,
            statusCode: 404,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )!
        return (Data(), httpResponse)
    }

    func mockResponse(for urlString: String, data: Data, statusCode: Int = 200) {
        let url = URL(string: urlString)!
        let httpResponse = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        responses[urlString] = (data, httpResponse)
    }

    func mockError(for urlString: String, error: Error) {
        errors[urlString] = error
    }

    var totalRequests: Int { requestCount }

    func reset() {
        requestCount = 0
        requestDelays.removeAll()
        responses.removeAll()
        errors.removeAll()
    }
}

// MARK: - Integration Test Helpers

func createBlogPostEntry(id: Int, published: Bool = true, category: String = "tech") -> FFetchEntry {
    return [
        "id": id,
        "title": "Blog Post \(id)",
        "path": "/blog/post-\(id)",
        "published": published,
        "category": category,
        "publishedDate": "2024-01-\(String(format: "%02d", id % 28 + 1))",
        "author": "Author \(id % 3 + 1)",
        "tags": ["tag\(id % 5)", "tag\(id % 3)"],
        "excerpt": "This is excerpt for blog post \(id)",
        "readTime": id % 10 + 1
    ]
}

func createProductEntry(id: Int, inStock: Bool = true, price: Double = 99.99) -> FFetchEntry {
    return [
        "id": id,
        "name": "Product \(id)",
        "path": "/products/product-\(id)",
        "sku": "SKU-\(String(format: "%04d", id))",
        "price": price + Double(id),
        "inStock": inStock,
        "category": ["electronics", "clothing", "books"][id % 3],
        "rating": (id % 5) + 1,
        "reviews": id * 2,
        "description": "High-quality product \(id) with amazing features"
    ]
}

func mockBlogIndex(client: AdvancedMockHTTPClient, total: Int = 50, chunkSize: Int = 255) {
    let baseURL = "https://example.com/blog-index.json"

    for offset in stride(from: 0, to: total, by: chunkSize) {
        let entries = Array(offset..<min(offset + chunkSize, total)).map { index in
            createBlogPostEntry(id: index, published: index % 4 != 0) // 75% published
        }

        let response = FFetchResponse(
            total: total,
            offset: offset,
            limit: chunkSize,
            data: entries
        )

        let data: Data
        do {
            data = try JSONEncoder().encode(response)
        } catch {
            XCTFail("Failed to encode FFetchResponse: \(error)")
            continue
        }
        let url = "\(baseURL)?offset=\(offset)&limit=\(chunkSize)"
        client.mockResponse(for: url, data: data)
    }
}

func mockProductIndex(client: AdvancedMockHTTPClient, total: Int = 100, chunkSize: Int = 255) {
    let baseURL = "https://example.com/products-index.json"

    for offset in stride(from: 0, to: total, by: chunkSize) {
        let entries = Array(offset..<min(offset + chunkSize, total)).map { index in
            createProductEntry(id: index, inStock: index % 5 != 0) // 80% in stock
        }

        let response = FFetchResponse(
            total: total,
            offset: offset,
            limit: chunkSize,
            data: entries
        )

        let data: Data
        do {
            data = try JSONEncoder().encode(response)
        } catch {
            XCTFail("Failed to encode FFetchResponse: \(error)")
            continue
        }
        let url = "\(baseURL)?offset=\(offset)&limit=\(chunkSize)"
        client.mockResponse(for: url, data: data)
    }
}

func mockDocumentResponses(client: AdvancedMockHTTPClient, count: Int) {
    for docIndex in 0..<count {
        let html = """
        <!DOCTYPE html>
        <html>
        <head><title>Document \(docIndex)</title></head>
        <body><p>Content \(docIndex)</p></body>
        </html>
        """
        let url = "https://example.com/document-\(docIndex)"
        client.mockResponse(for: url, data: html.data(using: .utf8)!)
    }
}

// MARK: - Test Helpers

func createMockResponse(total: Int, offset: Int, limit: Int, entries: [FFetchEntry]) -> Data {
    let response = FFetchResponse(total: total, offset: offset, limit: limit, data: entries)
    do {
        return try JSONEncoder().encode(response)
    } catch {
        XCTFail("Failed to encode FFetchResponse: \(error)")
        return Data()
    }
}

func createMockEntry(index: Int) -> FFetchEntry {
    return [
        "title": "Entry \(index)",
        "path": "/entry-\(index)",
        "published": index % 2 == 0
    ]
}

func mockIndexRequests(
    client: MockHTTPClient,
    baseURL: URL,
    total: Int,
    chunkSize: Int = 255,
    sheet: String? = nil
) {
    for offset in stride(from: 0, to: total, by: chunkSize) {
        let entries = Array(offset..<min(offset + chunkSize, total)).map(createMockEntry)
        let data = createMockResponse(
            total: total,
            offset: offset,
            limit: chunkSize,
            entries: entries
        )

        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: true)!
        var queryItems = [
            URLQueryItem(name: "offset", value: String(offset)),
            URLQueryItem(name: "limit", value: String(chunkSize))
        ]

        if let sheet = sheet {
            queryItems.append(URLQueryItem(name: "sheet", value: sheet))
        }

        components.queryItems = queryItems
        client.mockResponse(for: components.url!, data: data)
    }
}
