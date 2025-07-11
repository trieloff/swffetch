//
//  TestSupport.swift
//  SwiftFFetchTests
//
//  Shared test support: mock HTTP client and helpers
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
        if !url.isFileURL, url.scheme != nil, let base = responses.keys.first(where: { $0.scheme != nil && $0.host == url.host }) {
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
