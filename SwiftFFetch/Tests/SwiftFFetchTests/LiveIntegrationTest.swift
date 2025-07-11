//
//  LiveIntegrationTest.swift
//  SwiftFFetchTests
//
//  Created by SwiftFFetch on 2024-01-01.
//  Copyright © 2024 Adobe. All rights reserved.
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

import XCTest
import Foundation
@testable import SwiftFFetch

/// Integration tests that use a real, highly available HTTP endpoint.
/// These tests are designed to verify end-to-end functionality with live data.
/// Note: The content at the endpoint may change over time, so assertions should be robust.
final class LiveIntegrationTest: XCTestCase {

    /// Tests fetching and parsing live data from the aem.live docpages index endpoint.
    /// This endpoint is highly available, but its content may change.
    func testFetchLiveDocpagesIndex() async throws {
        let url = URL(string: "https://www.aem.live/docpages-index.json?limit=3")!
        let fetcher = FFetch(url: url)

        // Attempt to fetch the first chunk of entries (limit=3)
        let entries = try await fetcher
            .limit(3)
            .all()

        // The endpoint should return up to 3 entries in an array
        XCTAssertGreaterThan(entries.count, 0, "Expected at least one entry from the live endpoint")
        XCTAssertLessThanOrEqual(entries.count, 3, "Should not return more than 3 entries due to limit")

        // Check that each entry has expected keys (structure may evolve, so check for presence, not exact values)
        for entry in entries {
            // The docpages-index typically includes at least "path" and "title"
            XCTAssertNotNil(entry["path"], "Entry should have a 'path' key")
            XCTAssertNotNil(entry["title"], "Entry should have a 'title' key")
            // Optionally check for other common keys
            // e.g., "published", "author", etc., but do not fail if missing
        }
    }
}
