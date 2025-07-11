//
//  FFetchMapped.swift
//  SwiftFFetch
//
//  Mapped FFetch sequence for transformed results
//

import Foundation

/// Mapped FFetch sequence for transformed results
public struct FFetchMapped<T>: AsyncSequence {
    public typealias Element = T

    private let stream: AsyncStream<T>
    internal let context: FFetchContext

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
