//
//  FFetch+DocumentFollowing.swift
//  SwiftFFetch
//
//  Document following operations for FFetch sequences
//

import Foundation

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

                        // Limit concurrent tasks
                        if pendingTasks.count >= context.maxConcurrency {
                            // Wait for all tasks to complete and yield results
                            for task in pendingTasks {
                                do {
                                    let result = try await task.value
                                    continuation.yield(result)
                                } catch {
                                    // Handle errors gracefully - continue with other tasks
                                }
                            }
                            pendingTasks.removeAll()
                        }
                    }

                    // Process remaining tasks
                    for task in pendingTasks {
                        do {
                            let result = try await task.value
                            continuation.yield(result)
                        } catch {
                            // Handle errors gracefully
                        }
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
            return createErrorEntry(
                entry: entry,
                newFieldName: newFieldName,
                error: "Missing or invalid URL string in field '\(fieldName)'"
            )
        }

        let documentURL = resolveDocumentURL(urlString: urlString)
        guard let resolvedURL = documentURL else {
            return createErrorEntry(
                entry: entry,
                newFieldName: newFieldName,
                error: "Could not resolve URL from field '\(fieldName)': \(urlString)"
            )
        }

        do {
            let (data, response) = try await context.httpClient.fetch(
                resolvedURL,
                cachePolicy: .useProtocolCachePolicy
            )

            if let httpResponse = response as? HTTPURLResponse {
                guard httpResponse.statusCode == 200 else {
                    return createErrorEntry(
                        entry: entry,
                        newFieldName: newFieldName,
                        error: "HTTP error \(httpResponse.statusCode) for \(resolvedURL)"
                    )
                }
            } else {
                return createErrorEntry(
                    entry: entry,
                    newFieldName: newFieldName,
                    error: "No HTTPURLResponse for \(resolvedURL)"
                )
            }

            return try parseDocumentData(
                data: data,
                entry: entry,
                newFieldName: newFieldName,
                resolvedURL: resolvedURL
            )

        } catch {
            return createErrorEntry(
                entry: entry,
                newFieldName: newFieldName,
                error: "Network error for \(resolvedURL): \(error)"
            )
        }
    }

    /// Resolve document URL from string
    private func resolveDocumentURL(urlString: String) -> URL? {
        if let absURL = URL(string: urlString), absURL.scheme != nil {
            return absURL
        } else {
            return URL(string: urlString, relativeTo: self.url)?.absoluteURL
        }
    }

    /// Parse document data and return updated entry
    private func parseDocumentData(
        data: Data,
        entry: FFetchEntry,
        newFieldName: String,
        resolvedURL: URL
    ) throws -> FFetchEntry {
        let html = String(data: data, encoding: .utf8) ?? ""
        do {
            let document = try context.htmlParser.parse(html)
            var result = entry
            result[newFieldName] = document
            return result
        } catch {
            return createErrorEntry(
                entry: entry,
                newFieldName: newFieldName,
                error: "HTML parsing error for \(resolvedURL): \(error)"
            )
        }
    }

    /// Create an entry with error information
    private func createErrorEntry(
        entry: FFetchEntry,
        newFieldName: String,
        error: String
    ) -> FFetchEntry {
        var result = entry
        result[newFieldName] = nil
        result["\(newFieldName)_error"] = error
        return result
    }
}
