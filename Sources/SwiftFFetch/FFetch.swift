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

/// Main FFetch class that provides a fluent API for working with AEM Edge Delivery Services
///
/// `FFetch` wraps HTTP requests to AEM indices and provides chainable operations for
/// filtering, mapping, and transforming data streams. It supports lazy pagination,
/// concurrent processing, and document following.
///
/// ## Basic Usage
///
/// ```swift
/// let entries = FFetch(url: "/query-index.json")
/// for await entry in entries {
///     print(entry["title"] as? String ?? "No title")
/// }
/// ```
///
/// ## Chaining Operations
///
/// ```swift
/// let results = await FFetch(url: "/query-index.json")
///     .filter { entry in
///         (entry["published"] as? Bool) == true
///     }
///     .map { entry in
///         entry["title"] as? String ?? "Untitled"
///     }
///     .limit(10)
///     .all()
/// ```
public struct FFetch: AsyncSequence {
    public typealias Element = FFetchEntry

    private let url: URL
    private let context: FFetchContext
    private let upstream: AsyncStream<FFetchEntry>?

    /// The total number of entries available (nil until first request completes)
    public var total: Int? {
        return context.total
    }

    /// Initialize FFetch with a URL string
    /// - Parameter url: URL string to fetch from
    /// - Throws: FFetchError.invalidURL if the URL is invalid
    public init(url: String) throws {
        guard let validURL = URL(string: url) else {
            throw FFetchError.invalidURL(url)
        }
        self.url = validURL
        self.context = FFetchContext()
        self.upstream = nil
    }

    /// Initialize FFetch with a URL
    /// - Parameter url: URL to fetch from
    public init(url: URL) {
        self.url = url
        self.context = FFetchContext()
        self.upstream = nil
    }

    /// Internal initializer for creating derived FFetch instances
    private init(url: URL, context: FFetchContext, upstream: AsyncStream<FFetchEntry>?) {
        self.url = url
        self.context = context
        self.upstream = upstream
    }

    /// Make an async iterator for the sequence
    public func makeAsyncIterator() -> AsyncIterator {
        if let upstream = upstream {
            return AsyncIterator(stream: upstream)
        }

        let stream = AsyncStream<FFetchEntry> { continuation in
            Task {
                do {
                    try await self.performRequest(continuation: continuation)
                } catch {
                    continuation.finish()
                }
            }
        }

        return AsyncIterator(stream: stream)
    }

    /// Internal method to perform the HTTP request and stream results
    private func performRequest(continuation: AsyncStream<FFetchEntry>.Continuation) async throws {
        var mutableContext = context

        for offset in stride(from: 0, to: Int.max, by: mutableContext.chunkSize) {
            // Check if we've reached the total (if known)
            if let total = mutableContext.total, offset >= total {
                break
            }

            // Build URL with pagination parameters
            var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
            var queryItems = components?.queryItems ?? []
            queryItems.append(URLQueryItem(name: "offset", value: String(offset)))
            queryItems.append(URLQueryItem(name: "limit", value: String(mutableContext.chunkSize)))

            if let sheetName = mutableContext.sheetName {
                queryItems.append(URLQueryItem(name: "sheet", value: sheetName))
            }

            components?.queryItems = queryItems

            guard let requestURL = components?.url else {
                throw FFetchError.invalidURL(url.absoluteString)
            }

            // Make the request
            let cachePolicy: URLRequest.CachePolicy = mutableContext.cacheReload
                ? .reloadIgnoringLocalCacheData
                : .useProtocolCachePolicy

            do {
                let (data, response) = try await mutableContext.httpClient.fetch(requestURL, cachePolicy: cachePolicy)

                // Check HTTP response
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw FFetchError.invalidResponse
                }

                guard httpResponse.statusCode == 200 else {
                    if httpResponse.statusCode == 404 {
                        // Handle 404 gracefully by finishing the stream
                        continuation.finish()
                        return
                    }
                    throw FFetchError.networkError(
                        URLError(.badServerResponse, userInfo: [
                            NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode)"
                        ])
                    )
                }

                // Parse JSON response
                let decoder = JSONDecoder()
                let fetchResponse = try decoder.decode(FFetchResponse.self, from: data)

                // Update total if this is the first request
                if mutableContext.total == nil {
                    mutableContext.total = fetchResponse.total
                }

                // Yield entries
                for entry in fetchResponse.data {
                    continuation.yield(entry)
                }

                // Check if we've reached the end
                if offset + mutableContext.chunkSize >= fetchResponse.total {
                    break
                }

            } catch let error as FFetchError {
                throw error
            } catch {
                throw FFetchError.networkError(error)
            }
        }

        continuation.finish()
    }

    /// Async iterator implementation
    public struct AsyncIterator: AsyncIteratorProtocol {
        private var streamIterator: AsyncStream<FFetchEntry>.AsyncIterator

        init(stream: AsyncStream<FFetchEntry>) {
            self.streamIterator = stream.makeAsyncIterator()
        }

        public mutating func next() async -> FFetchEntry? {
            return await streamIterator.next()
        }
    }
}

// MARK: - Fluent API Operations

extension FFetch {
    /// Set the chunk size for pagination
    /// - Parameter size: Number of entries to fetch per request
    /// - Returns: New FFetch instance with updated chunk size
    public func chunks(_ size: Int) -> FFetch {
        var newContext = context
        newContext.chunkSize = size
        return FFetch(url: url, context: newContext, upstream: upstream)
    }

    /// Select a specific sheet from multi-sheet responses
    /// - Parameter name: Name of the sheet to select
    /// - Returns: New FFetch instance configured for the specified sheet
    public func sheet(_ name: String) -> FFetch {
        var newContext = context
        newContext.sheetName = name
        return FFetch(url: url, context: newContext, upstream: upstream)
    }

    /// Set custom HTTP client
    /// - Parameter client: HTTP client implementation
    /// - Returns: New FFetch instance with custom HTTP client
    public func withHTTPClient(_ client: FFetchHTTPClient) -> FFetch {
        var newContext = context
        newContext.httpClient = client
        return FFetch(url: url, context: newContext, upstream: upstream)
    }

    /// Set custom HTML parser
    /// - Parameter parser: HTML parser implementation
    /// - Returns: New FFetch instance with custom HTML parser
    public func withHTMLParser(_ parser: FFetchHTMLParser) -> FFetch {
        var newContext = context
        newContext.htmlParser = parser
        return FFetch(url: url, context: newContext, upstream: upstream)
    }

    /// Enable cache reloading
    /// - Parameter reload: Whether to reload cache
    /// - Returns: New FFetch instance with cache reload setting
    public func withCacheReload(_ reload: Bool = true) -> FFetch {
        var newContext = context
        newContext.cacheReload = reload
        return FFetch(url: url, context: newContext, upstream: upstream)
    }

    /// Set maximum concurrency for operations
    /// - Parameter maxConcurrency: Maximum number of concurrent operations
    /// - Returns: New FFetch instance with updated concurrency setting
    public func withMaxConcurrency(_ maxConcurrency: Int) -> FFetch {
        var newContext = context
        newContext.maxConcurrency = maxConcurrency
        return FFetch(url: url, context: newContext, upstream: upstream)
    }
}

// MARK: - Transformation Operations

extension FFetch {
    /// Transform each entry using the provided function
    /// - Parameter transform: Async function to transform each entry
    /// - Returns: New FFetch instance that applies the transformation
    public func map<T>(_ transform: @escaping FFetchTransform<FFetchEntry, T>) -> FFetchMapped<T> {
        let stream = AsyncStream<T> { continuation in
            Task {
                do {
                    var buffer: [T] = []
                    var pendingTasks: [Task<T, Error>] = []

                    for await entry in self {
                        // Create task for transformation
                        let task = Task<T, Error> {
                            return try await transform(entry)
                        }

                        pendingTasks.append(task)

                        // Process in batches to control concurrency
                        if pendingTasks.count >= context.maxConcurrency {
                            // Wait for all tasks in current batch
                            for task in pendingTasks {
                                let result = try await task.value
                                buffer.append(result)
                            }
                            pendingTasks.removeAll()
                        }
                    }

                    // Process remaining tasks
                    for task in pendingTasks {
                        let result = try await task.value
                        buffer.append(result)
                    }

                    // Yield all results in order
                    for item in buffer {
                        continuation.yield(item)
                    }
                } catch {
                    // Handle errors gracefully
                }
                continuation.finish()
            }
        }

        return FFetchMapped(stream: stream, context: context)
    }

    /// Filter entries using the provided predicate
    /// - Parameter predicate: Async predicate function
    /// - Returns: New FFetch instance that filters entries
    public func filter(_ predicate: @escaping FFetchPredicate<FFetchEntry>) -> FFetch {
        let stream = AsyncStream<FFetchEntry> { continuation in
            Task {
                do {
                    for await entry in self where try await predicate(entry) {
                        continuation.yield(entry)
                    }
                } catch {
                    // Handle errors gracefully
                }
                continuation.finish()
            }
        }

        return FFetch(url: url, context: context, upstream: stream)
    }

    /// Limit the number of entries returned
    /// - Parameter count: Maximum number of entries to return
    /// - Returns: New FFetch instance with limited results
    public func limit(_ count: Int) -> FFetch {
        let stream = AsyncStream<FFetchEntry> { continuation in
            Task {
                var yielded = 0
                for await entry in self {
                    if yielded >= count {
                        break
                    }
                    continuation.yield(entry)
                    yielded += 1
                }
                continuation.finish()
            }
        }

        return FFetch(url: url, context: context, upstream: stream)
    }

    /// Skip a number of entries from the beginning
    /// - Parameter count: Number of entries to skip
    /// - Returns: New FFetch instance that skips entries
    public func skip(_ count: Int) -> FFetch {
        let stream = AsyncStream<FFetchEntry> { continuation in
            Task {
                var skipped = 0
                for await entry in self {
                    if skipped < count {
                        skipped += 1
                    } else {
                        continuation.yield(entry)
                    }
                }
                continuation.finish()
            }
        }

        return FFetch(url: url, context: context, upstream: stream)
    }

    /// Extract a slice of entries
    /// - Parameters:
    ///   - start: Starting index (inclusive)
    ///   - end: Ending index (exclusive)
    /// - Returns: New FFetch instance with sliced results
    public func slice(_ start: Int, _ end: Int) -> FFetch {
        return skip(start).limit(end - start)
    }
}

// MARK: - Document Following

extension FFetch {
    /// Follow references to fetch HTML documents
    /// - Parameters:
    ///   - fieldName: Name of the field containing the reference URL
    ///   - newFieldName: Name of the new field to store the document (defaults to fieldName)
    /// - Returns: New FFetch instance with document following
    public func follow(_ fieldName: String, as newFieldName: String? = nil) -> FFetch {
        let targetFieldName = newFieldName ?? fieldName

        let stream = AsyncStream<FFetchEntry> { continuation in
            Task {
                do {
                    var pendingTasks: [Task<FFetchEntry, Error>] = []

                    for await entry in self {
                        // Create task for document following
                        let task = Task<FFetchEntry, Error> {
                            return try await self.followDocument(
                                entry: entry,
                                fieldName: fieldName,
                                newFieldName: targetFieldName
                            )
                        }

                        pendingTasks.append(task)

                        // Process in batches to control concurrency
                        if pendingTasks.count >= context.maxConcurrency {
                            // Wait for all tasks in current batch
                            for task in pendingTasks {
                                let result = try await task.value
                                continuation.yield(result)
                            }
                            pendingTasks.removeAll()
                        }
                    }

                    // Process remaining tasks
                    for task in pendingTasks {
                        let result = try await task.value
                        continuation.yield(result)
                    }
                } catch {
                    // Handle errors gracefully
                }
                continuation.finish()
            }
        }

        return FFetch(url: url, context: context, upstream: stream)
    }

    /// Internal method to follow a document reference
    private func followDocument(
        entry: FFetchEntry,
        fieldName: String,
        newFieldName: String
    ) async throws -> FFetchEntry {
        guard let urlString = entry[fieldName] as? String else {
            var result = entry
            result[newFieldName] = nil
            result["\(newFieldName)_error"] = "Missing or invalid URL string in field '\(fieldName)'"
            return result
        }

        // Resolve relative URLs against the base URL
        let documentURL: URL?
        if let absURL = URL(string: urlString), absURL.scheme != nil {
            documentURL = absURL
        } else {
            documentURL = URL(string: urlString, relativeTo: self.url)?.absoluteURL
        }

        guard let resolvedURL = documentURL else {
            var result = entry
            result[newFieldName] = nil
            result["\(newFieldName)_error"] = "Could not resolve URL from field '\(fieldName)': \(urlString)"
            return result
        }

        do {
            let (data, response) = try await context.httpClient.fetch(resolvedURL, cachePolicy: .useProtocolCachePolicy)

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode != 200 {
                    var result = entry
                    result[newFieldName] = nil
                    result["\(newFieldName)_error"] = "HTTP error \(httpResponse.statusCode) for \(resolvedURL)"
                    return result
                }
            } else {
                var result = entry
                result[newFieldName] = nil
                result["\(newFieldName)_error"] = "No HTTPURLResponse for \(resolvedURL)"
                return result
            }

            let html = String(data: data, encoding: .utf8) ?? ""
            do {
                let document = try context.htmlParser.parse(html)
                var result = entry
                result[newFieldName] = document
                return result
            } catch {
                var result = entry
                result[newFieldName] = nil
                result["\(newFieldName)_error"] = "HTML parsing error for \(resolvedURL): \(error)"
                return result
            }

        } catch {
            var result = entry
            result[newFieldName] = nil
            result["\(newFieldName)_error"] = "Network error for \(resolvedURL): \(error)"
            return result
        }
    }
}

// MARK: - Collection Operations

extension FFetch {
    /// Collect all entries into an array
    /// - Returns: Array of all entries
    public func all() async throws -> [FFetchEntry] {
        var results: [FFetchEntry] = []
        for await entry in self {
            results.append(entry)
        }
        return results
    }

    /// Get the first entry
    /// - Returns: First entry or nil if no entries
    public func first() async throws -> FFetchEntry? {
        for await entry in self {
            return entry
        }
        return nil
    }

    /// Count the total number of entries
    /// - Returns: Total number of entries
    public func count() async throws -> Int {
        var count = 0
        for await _ in self {
            count += 1
        }
        return count
    }
}

/// Mapped FFetch sequence for transformed results
public struct FFetchMapped<T>: AsyncSequence {
    public typealias Element = T

    private let stream: AsyncStream<T>
    private let context: FFetchContext

    init(stream: AsyncStream<T>, context: FFetchContext) {
        self.stream = stream
        self.context = context
    }

    public func makeAsyncIterator() -> AsyncIterator {
        return AsyncIterator(streamIterator: stream.makeAsyncIterator())
    }

    /// Async iterator for mapped results
    public struct AsyncIterator: AsyncIteratorProtocol {
        private var streamIterator: AsyncStream<T>.AsyncIterator

        init(streamIterator: AsyncStream<T>.AsyncIterator) {
            self.streamIterator = streamIterator
        }

        public mutating func next() async -> T? {
            return await streamIterator.next()
        }
    }
}

// MARK: - Collection Operations for Mapped Sequences

extension FFetchMapped {
    /// Collect all transformed entries into an array
    /// - Returns: Array of all transformed entries
    public func all() async throws -> [T] {
        var results: [T] = []
        for await entry in self {
            results.append(entry)
        }
        return results
    }

    /// Get the first transformed entry
    /// - Returns: First transformed entry or nil if no entries
    public func first() async throws -> T? {
        for await entry in self {
            return entry
        }
        return nil
    }

    /// Count the total number of transformed entries
    /// - Returns: Total number of transformed entries
    public func count() async throws -> Int {
        var count = 0
        for await _ in self {
            count += 1
        }
        return count
    }

    /// Limit the number of transformed entries returned
    /// - Parameter count: Maximum number of entries to return
    /// - Returns: New FFetchMapped instance with limited results
    public func limit(_ count: Int) -> FFetchMapped<T> {
        let stream = AsyncStream<T> { continuation in
            Task {
                var yielded = 0
                for await entry in self {
                    if yielded >= count {
                        break
                    }
                    continuation.yield(entry)
                    yielded += 1
                }
                continuation.finish()
            }
        }

        return FFetchMapped(stream: stream, context: context)
    }

    /// Filter transformed entries using the provided predicate
    /// - Parameter predicate: Async predicate function
    /// - Returns: New FFetchMapped instance that filters entries
    public func filter(_ predicate: @escaping (T) async throws -> Bool) -> FFetchMapped<T> {
        let stream = AsyncStream<T> { continuation in
            Task {
                do {
                    for await entry in self where try await predicate(entry) {
                        continuation.yield(entry)
                    }
                } catch {
                    // Handle errors gracefully
                }
                continuation.finish()
            }
        }

        return FFetchMapped(stream: stream, context: context)
    }

    /// Transform each entry using another mapping function
    /// - Parameter transform: Async function to transform each entry
    /// - Returns: New FFetchMapped instance with double transformation
    public func map<U>(_ transform: @escaping (T) async throws -> U) -> FFetchMapped<U> {
        let stream = AsyncStream<U> { continuation in
            Task {
                do {
                    var buffer: [U] = []
                    var pendingTasks: [Task<U, Error>] = []

                    for await entry in self {
                        // Create task for transformation
                        let task = Task<U, Error> {
                            return try await transform(entry)
                        }

                        pendingTasks.append(task)

                        // Process in batches to control concurrency
                        if pendingTasks.count >= context.maxConcurrency {
                            // Wait for all tasks in current batch
                            for task in pendingTasks {
                                let result = try await task.value
                                buffer.append(result)
                            }
                            pendingTasks.removeAll()
                        }
                    }

                    // Process remaining tasks
                    for task in pendingTasks {
                        let result = try await task.value
                        buffer.append(result)
                    }

                    // Yield all results in order
                    for item in buffer {
                        continuation.yield(item)
                    }
                } catch {
                    // Handle errors gracefully
                }
                continuation.finish()
            }
        }

        return FFetchMapped<U>(stream: stream, context: context)
    }

    /// Skip a number of entries from the beginning
    /// - Parameter count: Number of entries to skip
    /// - Returns: New FFetchMapped instance that skips entries
    public func skip(_ count: Int) -> FFetchMapped<T> {
        let stream = AsyncStream<T> { continuation in
            Task {
                var skipped = 0
                for await entry in self {
                    if skipped < count {
                        skipped += 1
                    } else {
                        continuation.yield(entry)
                    }
                }
                continuation.finish()
            }
        }

        return FFetchMapped(stream: stream, context: context)
    }

    /// Extract a slice of entries
    /// - Parameters:
    ///   - start: Starting index (inclusive)
    ///   - end: Ending index (exclusive)
    /// - Returns: New FFetchMapped instance with sliced results
    public func slice(_ start: Int, _ end: Int) -> FFetchMapped<T> {
        return skip(start).limit(end - start)
    }
}

/// Convenience function to create FFetch instances
/// - Parameter url: URL string to fetch from
/// - Returns: FFetch instance
/// - Throws: FFetchError.invalidURL if the URL is invalid
public func ffetch(_ url: String) throws -> FFetch {
    return try FFetch(url: url)
}

/// Convenience function to create FFetch instances with URL
/// - Parameter url: URL to fetch from
/// - Returns: FFetch instance
public func ffetch(_ url: URL) -> FFetch {
    return FFetch(url: url)
}
