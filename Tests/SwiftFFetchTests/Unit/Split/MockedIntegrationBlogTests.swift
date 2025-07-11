//
//  MockedIntegrationBlogTests.swift
//  SwiftFFetchTests
//
//  Integration tests for blog workflows, content management, and data aggregation.
//

import XCTest
import SwiftSoup
@testable import SwiftFFetch

final class MockedIntegrationBlogTests: XCTestCase {

    func testBlogPostProcessingWorkflow() async throws {
        let client = AdvancedMockHTTPClient()
        mockBlogIndex(client: client, total: 50)

        let ffetch = FFetch(url: URL(string: "https://example.com/blog-index.json")!)
            .withHTTPClient(client)
            .filter { entry in
                (entry["published"] as? Bool) == true
            }
            .map { entry in
                [
                    "id": entry["id"] ?? "",
                    "title": entry["title"] ?? "",
                    "author": entry["author"] ?? "",
                    "tags": entry["tags"] ?? [],
                    "excerpt": entry["excerpt"] ?? ""
                ]
            }
            .limit(10)

        let posts = try await ffetch.all()
        XCTAssertEqual(posts.count, 10)
        for post in posts {
            XCTAssertTrue((post["title"] as? String)?.contains("Blog Post") ?? false)
            XCTAssertTrue((post["author"] as? String)?.contains("Author") ?? false)
        }
    }

    func testContentManagementWorkflow() async throws {
        let client = AdvancedMockHTTPClient()
        mockBlogIndex(client: client, total: 30)

        let ffetch = FFetch(url: URL(string: "https://example.com/blog-index.json")!)
            .withHTTPClient(client)
            .filter { entry in
                (entry["category"] as? String) == "tech"
            }
            .map { entry in
                [
                    "id": entry["id"] ?? "",
                    "title": entry["title"] ?? "",
                    "publishedDate": entry["publishedDate"] ?? "",
                    "readTime": entry["readTime"] ?? 0
                ]
            }
            .limit(5)

        let techPosts = try await ffetch.all()
        XCTAssertEqual(techPosts.count, 5)
        for post in techPosts {
            XCTAssertEqual(post["readTime"] as? Int ?? 0 >= 0, true)
        }
    }

    func testComplexDataAggregation() async throws {
        let client = AdvancedMockHTTPClient()
        mockBlogIndex(client: client, total: 100)

        let ffetch = FFetch(url: URL(string: "https://example.com/blog-index.json")!)
            .withHTTPClient(client)
            .filter { entry in
                (entry["published"] as? Bool) == true
            }

        let posts = try await ffetch.all()
        let authorCounts = Dictionary(grouping: posts, by: { $0["author"] as? String ?? "" })
            .mapValues { $0.count }

        XCTAssertFalse(authorCounts.isEmpty)
        for (author, count) in authorCounts {
            XCTAssertTrue(author.hasPrefix("Author"))
            XCTAssertGreaterThan(count, 0)
        }
    }
}
