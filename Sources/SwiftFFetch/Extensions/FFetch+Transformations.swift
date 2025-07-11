//
//  FFetch+Transformations.swift
//  SwiftFFetch
//
//  Transformation operations for FFetch sequences
//

import Foundation

// MARK: - Transformation Operations

extension FFetch {
    /// Transform entries using the provided function
    /// - Parameter transform: Async transformation function
    /// - Returns: New FFetchMapped instance with transformed entries
    public func map<T>(_ transform: @escaping FFetchTransform<FFetchEntry, T>) -> FFetchMapped<T> {
        let stream = AsyncStream<T> { continuation in
            Task {
                var buffer: [T] = []
                var activeTasks: [Task<T, Error>] = []

                for await entry in self {
                    let task = Task<T, Error> {
                        return try await transform(entry)
                    }
                    activeTasks.append(task)

                    // Limit concurrent tasks
                    if activeTasks.count >= context.maxConcurrency {
                        // Wait for all tasks to complete
                        for task in activeTasks {
                            do {
                                let result = try await task.value
                                buffer.append(result)
                            } catch {
                                // Handle transformation errors gracefully
                            }
                        }
                        activeTasks.removeAll()
                    }
                }

                // Process remaining tasks
                for task in activeTasks {
                    do {
                        let result = try await task.value
                        buffer.append(result)
                    } catch {
                        // Handle transformation errors gracefully
                    }
                }

                // Yield all results in order
                for item in buffer {
                    continuation.yield(item)
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

// MARK: - Transformation Operations for Mapped Sequences

extension FFetchMapped {
    /// Transform mapped entries using the provided function
    /// - Parameter transform: Async transformation function
    /// - Returns: New FFetchMapped instance with transformed entries
    public func map<U>(_ transform: @escaping (T) async throws -> U) -> FFetchMapped<U> {
        let stream = AsyncStream<U> { continuation in
            Task {
                do {
                    for await entry in self {
                        let transformed = try await transform(entry)
                        continuation.yield(transformed)
                    }
                } catch {
                    // Handle errors gracefully
                }
                continuation.finish()
            }
        }

        return FFetchMapped<U>(stream: stream, context: context)
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

    /// Skip a number of transformed entries from the beginning
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

    /// Extract a slice of transformed entries
    /// - Parameters:
    ///   - start: Starting index (inclusive)
    ///   - end: Ending index (exclusive)
    /// - Returns: New FFetchMapped instance with sliced results
    public func slice(_ start: Int, _ end: Int) -> FFetchMapped<T> {
        return skip(start).limit(end - start)
    }
}
