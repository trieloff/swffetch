//
//  Copyright © 2025 Adobe. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import SwiftSoup

/// Represents a single entry from an AEM index response
public typealias FFetchEntry = [String: Any]

/// Represents the JSON response structure from AEM indices
public struct FFetchResponse: Codable {
    /// Total number of entries available
    public let total: Int

    /// Current offset in the result set
    public let offset: Int

    /// Maximum number of entries requested
    public let limit: Int

    /// Array of data entries
    public let data: [FFetchEntry]

    public init(total: Int, offset: Int, limit: Int, data: [FFetchEntry]) {
        self.total = total
        self.offset = offset
        self.limit = limit
        self.data = data
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        total = try container.decode(Int.self, forKey: .total)
        offset = try container.decode(Int.self, forKey: .offset)
        limit = try container.decode(Int.self, forKey: .limit)

        // Decode data as an array of dictionaries
        let dataArray = try container.decode([[String: AnyCodable]].self, forKey: .data)
        data = dataArray.map { dict in
            dict.mapValues { $0.value }
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(total, forKey: .total)
        try container.encode(offset, forKey: .offset)
        try container.encode(limit, forKey: .limit)

        // Encode data as an array of dictionaries
        let dataArray = data.map { dict in
            dict.mapValues { AnyCodable($0) }
        }
        try container.encode(dataArray, forKey: .data)
    }

    private enum CodingKeys: String, CodingKey {
        case total, offset, limit, data
    }
}

/// Helper type for encoding/decoding Any values
public struct AnyCodable: Codable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let arrayValue = try? container.decode([AnyCodable].self) {
            value = arrayValue.map { $0.value }
        } else if let dictValue = try? container.decode([String: AnyCodable].self) {
            value = dictValue.mapValues { $0.value }
        } else {
            throw DecodingError.typeMismatch(
                AnyCodable.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Could not decode value"
                )
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let boolValue as Bool:
            try container.encode(boolValue)
        case let intValue as Int:
            try container.encode(intValue)
        case let doubleValue as Double:
            try container.encode(doubleValue)
        case let stringValue as String:
            try container.encode(stringValue)
        case let arrayValue as [Any]:
            try container.encode(arrayValue.map { AnyCodable($0) })
        case let dictValue as [String: Any]:
            try container.encode(dictValue.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(
                    codingPath: encoder.codingPath,
                    debugDescription: "Could not encode value of type \(type(of: value))"
                )
            )
        }
    }
}

/// Errors that can occur during FFetch operations
public enum FFetchError: Error, LocalizedError {
    case invalidURL(String)
    case networkError(Error)
    case decodingError(Error)
    case invalidResponse
    case documentNotFound
    case operationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response format"
        case .documentNotFound:
            return "Document not found"
        case .operationFailed(let message):
            return "Operation failed: \(message)"
        }
    }
}

/// Protocol for HTTP client abstraction
public protocol FFetchHTTPClient {
    func fetch(_ url: URL, cachePolicy: URLRequest.CachePolicy) async throws -> (Data, URLResponse)
}

/// Protocol for HTML parsing abstraction
public protocol FFetchHTMLParser {
    func parse(_ html: String) throws -> Document
}

/// Default HTTP client implementation using URLSession
public struct DefaultFFetchHTTPClient: FFetchHTTPClient {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func fetch(_ url: URL, cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: url)
        request.cachePolicy = cachePolicy

        do {
            return try await session.data(for: request)
        } catch {
            throw FFetchError.networkError(error)
        }
    }
}

/// Default HTML parser implementation using SwiftSoup
public struct DefaultFFetchHTMLParser: FFetchHTMLParser {
    public init() {}

    public func parse(_ html: String) throws -> Document {
        do {
            return try SwiftSoup.parse(html)
        } catch {
            throw FFetchError.decodingError(error)
        }
    }
}

/// Configuration context for FFetch operations
public struct FFetchContext {
    /// Size of chunks to fetch during pagination
    public var chunkSize: Int

    /// Whether to reload cache
    public var cacheReload: Bool

    /// Name of the sheet to query (for multi-sheet responses)
    public var sheetName: String?

    /// HTTP client for making requests
    public var httpClient: FFetchHTTPClient

    /// HTML parser for parsing documents
    public var htmlParser: FFetchHTMLParser

    /// Total number of entries (set after first request)
    public var total: Int?

    /// Maximum number of concurrent operations
    public var maxConcurrency: Int

    public init(
        chunkSize: Int = 255,
        cacheReload: Bool = false,
        sheetName: String? = nil,
        httpClient: FFetchHTTPClient = DefaultFFetchHTTPClient(),
        htmlParser: FFetchHTMLParser = DefaultFFetchHTMLParser(),
        total: Int? = nil,
        maxConcurrency: Int = 5
    ) {
        self.chunkSize = chunkSize
        self.cacheReload = cacheReload
        self.sheetName = sheetName
        self.httpClient = httpClient
        self.htmlParser = htmlParser
        self.total = total
        self.maxConcurrency = maxConcurrency
    }
}

/// Protocol for chainable FFetch operations
public protocol FFetchOperation {
    associatedtype Element

    func execute(with context: FFetchContext) -> AsyncStream<Element>
}

/// Transform function type for map operations
public typealias FFetchTransform<Input, Output> = (Input) async throws -> Output

/// Predicate function type for filter operations
public typealias FFetchPredicate<Element> = (Element) async throws -> Bool
