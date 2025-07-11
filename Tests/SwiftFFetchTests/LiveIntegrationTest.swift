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

import XCTest
@testable import SwiftFFetch
import SwiftSoup

/// Integration tests that use a real, highly available HTTP endpoint.
/// These tests are designed to verify end-to-end functionality with live data.
/// Note: The content at the endpoint may change over time, so assertions should be robust.
final class LiveIntegrationTest: XCTestCase {

    /// Tests fetching and parsing live data from the aem.live docpages index endpoint.
    /// This endpoint is highly available, but its content may change.
    func testFetchLiveDocpagesIndex() async throws {
        let url = URL(string: "https://www.aem.live/docpages-index.json?limit=3")!
        let entries = try await FFetch(url: url)
            .limit(3)
            .follow("path", as: "document")
            .map { entry -> [String: Any] in
                var result = entry
                if let document = entry["document"] as? SwiftSoup.Document {
                    result["htmlTitle"] = try? document.select("title").first()?.text()
                    result["metaTagsCount"] = (try? document.select("meta").count) ?? 0
                    result["hasDescriptionMeta"] = (try? document.select("meta[name=description]").first()) != nil
                    result["hasKeywordsMeta"] = (try? document.select("meta[name=keywords]").first()) != nil
                }
                return result
            }
            .all()

        XCTAssertGreaterThan(entries.count, 0, "Expected at least one entry from the live endpoint")
        XCTAssertLessThanOrEqual(entries.count, 3, "Should not return more than 3 entries due to limit")

        for entry in entries {
            XCTAssertNotNil(entry["path"], "Entry should have a 'path' key")
            XCTAssertNotNil(entry["title"], "Entry should have a 'title' key")

            if let error = entry["document_error"] as? String {
                XCTFail("Error fetching document: \(error)")
            }

            let htmlTitle = entry["htmlTitle"] as? String
            XCTAssertNotNil(htmlTitle, "HTML page should have a <title>")
            XCTAssertFalse(htmlTitle?.isEmpty ?? true, "HTML page should have a non-empty <title>")

            let metaTagsCount = entry["metaTagsCount"] as? Int ?? 0
            XCTAssertGreaterThan(metaTagsCount, 0, "HTML page should have at least one <meta> tag")

            let hasDescription = entry["hasDescriptionMeta"] as? Bool ?? false
            let hasKeywords = entry["hasKeywordsMeta"] as? Bool ?? false
            XCTAssertTrue(hasDescription || hasKeywords, "HTML page should have a description or keywords meta tag")
        }
    }
}
