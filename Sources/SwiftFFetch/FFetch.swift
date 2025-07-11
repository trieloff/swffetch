//
//  FFetch.swift
//  SwiftFFetch
//
//  Main FFetch implementation with simplified request handling
//

import Foundation

/// Main FFetch class for asynchronous data fetching
public struct FFetch: AsyncSequence {
    public typealias Element = FFetchEntry

    internal let url: URL
    internal let context: FFetchContext
    private let upstream: AsyncStream<FFetchEntry>?

    /// Initialize with URL and default context
    /// - Parameter url: Base URL for fetching data
    public init(url: URL) {
        self.url = url
        self.context = FFetchContext()
        self.upstream = nil
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

    /// Internal initializer with context and optional upstream
    internal init(url: URL, context: FFetchContext, upstream: AsyncStream<FFetchEntry>? = nil) {
        self.url = url
        var contextWithAllowedHost = context
        // Set the initial hostname as allowed if no hosts are explicitly allowed
        if contextWithAllowedHost.allowedHosts.isEmpty {
            if let host = url.host {
                contextWithAllowedHost.allowedHosts.insert(host)
            }
        }
        self.context = contextWithAllowedHost
        self.upstream = upstream
    }

    /// Create async iterator
    public func makeAsyncIterator() -> AsyncIterator {
        if let upstream = upstream {
            return AsyncIterator(stream: upstream)
        } else {
            let stream = createStream()
            return AsyncIterator(stream: stream)
        }
    }

    /// Create the main data stream
    private func createStream() -> AsyncStream<FFetchEntry> {
        return AsyncStream<FFetchEntry> { continuation in
            Task {
                do {
                    try await FFetchRequestHandler.performRequest(
                        url: url,
                        context: context,
                        continuation: continuation
                    )
                } catch {
                    continuation.finish()
                }
            }
        }
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

// MARK: - Configuration Methods

extension FFetch {
    /// Set custom chunk size for pagination
    /// - Parameter size: Chunk size (default: 255)
    /// - Returns: New FFetch instance with updated chunk size
    public func chunks(_ size: Int) -> FFetch {
        var newContext = context
        newContext.chunkSize = size
        return FFetch(url: url, context: newContext, upstream: upstream)
    }

    /// Select a specific sheet (for spreadsheet-like data sources)
    /// - Parameter name: Sheet name
    /// - Returns: New FFetch instance with sheet selection
    public func sheet(_ name: String) -> FFetch {
        var newContext = context
        newContext.sheetName = name
        return FFetch(url: url, context: newContext, upstream: upstream)
    }

    /// Set maximum concurrency for parallel operations
    /// - Parameter limit: Maximum concurrent operations
    /// - Returns: New FFetch instance with updated concurrency limit
    public func maxConcurrency(_ limit: Int) -> FFetch {
        var newContext = context
        newContext.maxConcurrency = limit
        return FFetch(url: url, context: newContext, upstream: upstream)
    }

    /// Force cache reload for requests
    /// - Returns: New FFetch instance with cache reload enabled
    public func reloadCache() -> FFetch {
        var newContext = context
        newContext.cacheReload = true
        return FFetch(url: url, context: newContext, upstream: upstream)
    }

    /// Enable cache reloading (backward compatibility)
    /// - Parameter reload: Whether to reload cache
    /// - Returns: New FFetch instance with cache reload setting
    public func withCacheReload(_ reload: Bool = true) -> FFetch {
        var newContext = context
        newContext.cacheReload = reload
        return FFetch(url: url, context: newContext, upstream: upstream)
    }

    /// Set maximum concurrency for operations (backward compatibility)
    /// - Parameter maxConcurrency: Maximum number of concurrent operations
    /// - Returns: New FFetch instance with updated concurrency setting
    public func withMaxConcurrency(_ maxConcurrency: Int) -> FFetch {
        var newContext = context
        newContext.maxConcurrency = maxConcurrency
        return FFetch(url: url, context: newContext, upstream: upstream)
    }

    /// Set custom HTTP client
    /// - Parameter client: Custom HTTP client
    /// - Returns: New FFetch instance with custom client
    public func withHTTPClient(_ client: FFetchHTTPClient) -> FFetch {
        var newContext = context
        newContext.httpClient = client
        return FFetch(url: url, context: newContext, upstream: upstream)
    }

    /// Set custom HTML parser
    /// - Parameter parser: Custom HTML parser
    /// - Returns: New FFetch instance with custom parser
    public func withHTMLParser(_ parser: FFetchHTMLParser) -> FFetch {
        var newContext = context
        newContext.htmlParser = parser
        return FFetch(url: url, context: newContext, upstream: upstream)
    }

    /// Allow document following to specific hostname(s)
    ///
    /// By default, document following is restricted to the same hostname as the initial request
    /// for security reasons. Use this method to explicitly allow additional hostnames.
    ///
    /// - Parameter hostname: Hostname to allow (e.g., "api.example.com"), or "*" to allow all hostnames
    /// - Returns: New FFetch instance with updated allowed hosts
    ///
    /// # Security Note
    /// Use caution when allowing additional hostnames, especially "*". This can expose your
    /// application to security risks if untrusted URLs are processed.
    ///
    /// # Example
    /// ```swift
    /// let entries = try await FFetch(url: "https://example.com/query-index.json")
    ///     .allow("trusted.com")
    ///     .follow("path", as: "document")
    ///     .all()
    /// ```
    public func allow(_ hostname: String) -> FFetch {
        var newContext = context
        if hostname == "*" {
            newContext.allowedHosts = ["*"]
        } else {
            newContext.allowedHosts.insert(hostname)
        }
        return FFetch(url: url, context: newContext, upstream: upstream)
    }

    /// Allow document following to multiple hostnames
    ///
    /// Convenience method to allow multiple hostnames at once. If any hostname is "*",
    /// all hostnames will be allowed.
    ///
    /// - Parameter hostnames: Array of hostnames to allow (e.g., ["api.example.com", "cdn.example.com"])
    /// - Returns: New FFetch instance with updated allowed hosts
    ///
    /// # Security Note
    /// Each hostname should be trusted. If the array contains "*", all hostnames will be allowed.
    ///
    /// # Example
    /// ```swift
    /// let entries = try await FFetch(url: "https://example.com/query-index.json")
    ///     .allow(["trusted.com", "api.example.com"])
    ///     .follow("path", as: "document")
    ///     .all()
    /// ```
    public func allow(_ hostnames: [String]) -> FFetch {
        var newContext = context
        for hostname in hostnames {
            if hostname == "*" {
                newContext.allowedHosts = ["*"]
                break
            } else {
                newContext.allowedHosts.insert(hostname)
            }
        }
        return FFetch(url: url, context: newContext, upstream: upstream)
    }
}

// MARK: - Convenience Functions

/// Create FFetch instance from URL string
/// - Parameter url: URL string to fetch from
/// - Returns: FFetch instance
/// - Throws: FFetchError.invalidURL if the URL is invalid
public func ffetch(_ url: String) throws -> FFetch {
    return try FFetch(url: url)
}

/// Create FFetch instance from URL
/// - Parameter url: URL
/// - Returns: FFetch instance
public func ffetch(_ url: URL) -> FFetch {
    return FFetch(url: url)
}
