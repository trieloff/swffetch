//
//  FFetchTypesCacheConfigTests.swift
//  SwiftFFetchTests
//
//  Focused tests for FFetchCacheConfig type
//
import XCTest
import Foundation
@testable import SwiftFFetch

final class FFetchTypesCacheConfigTests: XCTestCase {

    // MARK: - FFetchCacheConfig Tests

    func testFFetchCacheConfigDefault() {
        let config = FFetchCacheConfig.default
        XCTAssertEqual(config.policy, .useProtocolCachePolicy)
        XCTAssertNil(config.cache)
        XCTAssertNil(config.maxAge)
        XCTAssertFalse(config.ignoreServerCacheControl)
    }

    func testFFetchCacheConfigNoCache() {
        let config = FFetchCacheConfig.noCache
        XCTAssertEqual(config.policy, .reloadIgnoringLocalCacheData)
        XCTAssertNil(config.cache)
        XCTAssertNil(config.maxAge)
        XCTAssertFalse(config.ignoreServerCacheControl)
    }

    func testFFetchCacheConfigCacheOnly() {
        let config = FFetchCacheConfig.cacheOnly
        XCTAssertEqual(config.policy, .returnCacheDataDontLoad)
        XCTAssertNil(config.cache)
        XCTAssertNil(config.maxAge)
        XCTAssertFalse(config.ignoreServerCacheControl)
    }

    func testFFetchCacheConfigCacheElseLoad() {
        let config = FFetchCacheConfig.cacheElseLoad
        XCTAssertEqual(config.policy, .returnCacheDataElseLoad)
        XCTAssertNil(config.cache)
        XCTAssertNil(config.maxAge)
        XCTAssertFalse(config.ignoreServerCacheControl)
    }

    func testFFetchCacheConfigCustomInit() {
        let customCache = URLCache(memoryCapacity: 1024, diskCapacity: 2048)
        let config = FFetchCacheConfig(
            policy: .reloadRevalidatingCacheData,
            cache: customCache,
            maxAge: 3600,
            ignoreServerCacheControl: true
        )

        XCTAssertEqual(config.policy, .reloadRevalidatingCacheData)
        XCTAssertNotNil(config.cache)
        XCTAssertEqual(config.maxAge, 3600)
        XCTAssertTrue(config.ignoreServerCacheControl)
    }

    func testFFetchCacheConfigInitWithDefaults() {
        let config = FFetchCacheConfig()
        XCTAssertEqual(config.policy, .useProtocolCachePolicy)
        XCTAssertNil(config.cache)
        XCTAssertNil(config.maxAge)
        XCTAssertFalse(config.ignoreServerCacheControl)
    }

    // MARK: - FFetchCacheConfig Edge Cases Tests

    func testFFetchCacheConfigWithZeroMaxAge() {
        let config = FFetchCacheConfig(maxAge: 0)
        XCTAssertEqual(config.maxAge, 0)
        XCTAssertFalse(config.ignoreServerCacheControl)
    }

    func testFFetchCacheConfigWithNegativeMaxAge() {
        let config = FFetchCacheConfig(maxAge: -1)
        XCTAssertEqual(config.maxAge, -1)
    }

    func testFFetchCacheConfigWithVeryLargeMaxAge() {
        let largeMaxAge: TimeInterval = 365 * 24 * 60 * 60 // 1 year in seconds
        let config = FFetchCacheConfig(maxAge: largeMaxAge)
        XCTAssertEqual(config.maxAge, largeMaxAge)
    }
}
