//
//  FFetch+CollectionOperations.swift
//  SwiftFFetch
//
//  Collection operations for FFetch sequences
//

import Foundation

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
}
