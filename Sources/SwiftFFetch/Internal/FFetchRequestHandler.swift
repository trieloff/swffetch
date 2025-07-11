//
//  FFetchRequestHandler.swift
//  SwiftFFetch
//
//  Internal request handling for FFetch
//

import Foundation

/// Internal class to handle HTTP requests and pagination
internal class FFetchRequestHandler {

    /// Perform paginated requests and yield entries
    /// - Parameters:
    ///   - url: Base URL for requests
    ///   - context: FFetch context
    ///   - continuation: AsyncStream continuation to yield entries
    internal static func performRequest(
        url: URL,
        context: FFetchContext,
        continuation: AsyncStream<FFetchEntry>.Continuation
    ) async throws {
        var mutableContext = context

        for offset in stride(from: 0, to: Int.max, by: mutableContext.chunkSize) {
            // Check if we've reached the total (if known)
            if let total = mutableContext.total, offset >= total {
                break
            }

            let requestURL = try buildRequestURL(
                url: url,
                offset: offset,
                context: mutableContext
            )

            let fetchResponse = try await executeRequest(
                url: requestURL,
                context: mutableContext,
                continuation: continuation
            )

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
        }

        continuation.finish()
    }

    /// Build request URL with pagination parameters
    private static func buildRequestURL(
        url: URL,
        offset: Int,
        context: FFetchContext
    ) throws -> URL {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        var queryItems = components?.queryItems ?? []

        queryItems.append(URLQueryItem(name: "offset", value: String(offset)))
        queryItems.append(URLQueryItem(name: "limit", value: String(context.chunkSize)))

        if let sheetName = context.sheetName {
            queryItems.append(URLQueryItem(name: "sheet", value: sheetName))
        }

        components?.queryItems = queryItems

        guard let requestURL = components?.url else {
            throw FFetchError.invalidURL(url.absoluteString)
        }

        return requestURL
    }

    /// Execute HTTP request and parse response
    private static func executeRequest(
        url: URL,
        context: FFetchContext,
        continuation: AsyncStream<FFetchEntry>.Continuation
    ) async throws -> FFetchResponse {
        let cachePolicy: URLRequest.CachePolicy = context.cacheReload
            ? .reloadIgnoringLocalCacheData
            : .useProtocolCachePolicy

        do {
            let (data, response) = try await context.httpClient.fetch(url, cachePolicy: cachePolicy)

            try validateHTTPResponse(response: response, continuation: continuation)

            // Parse JSON response
            let decoder = JSONDecoder()
            return try decoder.decode(FFetchResponse.self, from: data)

        } catch let error as FFetchError {
            throw error
        } catch {
            throw FFetchError.networkError(error)
        }
    }

    /// Validate HTTP response status
    private static func validateHTTPResponse(
        response: URLResponse,
        continuation: AsyncStream<FFetchEntry>.Continuation
    ) throws {
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
    }
}
