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
import Foundation
import SwiftSoup
@testable import SwiftFFetch

/// Integration tests that simulate real-world usage patterns
class MockedIntegrationTest: XCTestCase {

    // MARK: - Mock HTTP Client with Advanced Behavior

    class AdvancedMockHTTPClient: FFetchHTTPClient {
        private var requestCount = 0
        private var requestDelays: [TimeInterval] = []
        private var responses: [String: (Data, HTTPURLResponse)] = [:]
        private var errors: [String: Error] = [:]

        func addDelay(_ delay: TimeInterval) {
            requestDelays.append(delay)
        }

        func fetch(_ url: URL, cachePolicy: URLRequest.CachePolicy) async throws -> (Data, URLResponse) {
            requestCount += 1

            // Simulate network delay
            if requestCount <= requestDelays.count {
                try await Task.sleep(nanoseconds: UInt64(requestDelays[requestCount - 1] * 1_000_000_000))
            }

            let key = url.absoluteString
            print("[AdvancedMockHTTPClient] fetch called with URL: \(key)")

            if let error = errors[key] {
                print("[AdvancedMockHTTPClient] Found error for key: \(key)")
                throw error
            }

            if let response = responses[key] {
                print("[AdvancedMockHTTPClient] Found response for key: \(key)")
                return response
            }

            // Try to match relative URLs against the entry point base URL
            if let base = responses.keys.first(where: { $0.hasPrefix("https://") }) {
                if let relativeURL = URL(string: url.path, relativeTo: URL(string: base))?.absoluteString {
                    if let error = errors[relativeURL] {
                        print("[AdvancedMockHTTPClient] Found error for relative URL: \(relativeURL)")
                        throw error
                    }
                    if let response = responses[relativeURL] {
                        print("[AdvancedMockHTTPClient] Found response for relative URL: \(relativeURL)")
                        return response
                    }
                }
            }

            print("[AdvancedMockHTTPClient] No response found for URL: \(key), returning 404")
            // Default 404 response
            let httpResponse = HTTPURLResponse(
                url: url,
                statusCode: 404,
                httpVersion: "HTTP/1.1",
                headerFields: nil
            )!
            return (Data(), httpResponse)
        }

        func mockResponse(for urlString: String, data: Data, statusCode: Int = 200) {
            let url = URL(string: urlString)!
            let httpResponse = HTTPURLResponse(
                url: url,
                statusCode: statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )!
            responses[urlString] = (data, httpResponse)
        }

        func mockError(for urlString: String, error: Error) {
            errors[urlString] = error
        }

        var totalRequests: Int { requestCount }

        func reset() {
            requestCount = 0
            requestDelays.removeAll()
            responses.removeAll()
            errors.removeAll()
        }
    }

    // MARK: - Test Helpers

    func createBlogPostEntry(id: Int, published: Bool = true, category: String = "tech") -> FFetchEntry {
        return [
            "id": id,
            "title": "Blog Post \(id)",
            "path": "/blog/post-\(id)",
            "published": published,
            "category": category,
            "publishedDate": "2024-01-\(String(format: "%02d", id % 28 + 1))",
            "author": "Author \(id % 3 + 1)",
            "tags": ["tag\(id % 5)", "tag\(id % 3)"],
            "excerpt": "This is excerpt for blog post \(id)",
            "readTime": id % 10 + 1
        ]
    }

    func createProductEntry(id: Int, inStock: Bool = true, price: Double = 99.99) -> FFetchEntry {
        return [
            "id": id,
            "name": "Product \(id)",
            "path": "/products/product-\(id)",
            "sku": "SKU-\(String(format: "%04d", id))",
            "price": price + Double(id),
            "inStock": inStock,
            "category": ["electronics", "clothing", "books"][id % 3],
            "rating": (id % 5) + 1,
            "reviews": id * 2,
            "description": "High-quality product \(id) with amazing features"
        ]
    }

    func mockBlogIndex(client: AdvancedMockHTTPClient, total: Int = 50) {
        let baseURL = "https://example.com/blog-index.json"
        let chunkSizes = [10, 20]
        for chunkSize in chunkSizes {
            for offset in stride(from: 0, to: total, by: chunkSize) {
                let entries = Array(offset..<min(offset + chunkSize, total)).map { index in
                    createBlogPostEntry(id: index, published: index % 4 != 0) // 75% published
                }

                let response = FFetchResponse(
                    total: total,
                    offset: offset,
                    limit: chunkSize,
                    data: entries
                )

                let data: Data
                do {
                    data = try JSONEncoder().encode(response)
                } catch {
                    XCTFail("Failed to encode FFetchResponse: \(error)")
                    continue
                }
                let url = "\(baseURL)?offset=\(offset)&limit=\(chunkSize)"
                client.mockResponse(for: url, data: data)
            }
        }
    }

    func mockProductIndex(client: AdvancedMockHTTPClient, total: Int = 100) {
        let baseURL = "https://example.com/products-index.json"
        let chunkSize = 25

        for offset in stride(from: 0, to: total, by: chunkSize) {
            let entries = Array(offset..<min(offset + chunkSize, total)).map { index in
                createProductEntry(id: index, inStock: index % 5 != 0) // 80% in stock
            }

            let response = FFetchResponse(
                total: total,
                offset: offset,
                limit: chunkSize,
                data: entries
            )

            let data: Data
            do {
                data = try JSONEncoder().encode(response)
            } catch {
                XCTFail("Failed to encode FFetchResponse: \(error)")
                continue
            }
            let url = "\(baseURL)?offset=\(offset)&limit=\(chunkSize)"
            client.mockResponse(for: url, data: data)
        }
    }

    func mockDocumentResponses(client: AdvancedMockHTTPClient, count: Int) {
        for docIndex in 0..<count {
            let html = """
            <!DOCTYPE html>
            <html>
            <head>
                <title>Document \(docIndex)</title>
                <meta name="description" content="Description for document \(docIndex)">
                <meta name="keywords" content="keyword1, keyword2, keyword\(docIndex)">
            </head>
            <body>
                <header>
                    <h1>Document \(docIndex)</h1>
                </header>
                <main>
                    <p>This is the main content of document \(docIndex).</p>
                    <img src="/images/image-\(docIndex).jpg" alt="Image \(docIndex)">
                    <section>
                        <h2>Section \(docIndex)</h2>
                        <p>Additional content for section \(docIndex).</p>
                    </section>
                </main>
                <footer>
                    <p>Footer content</p>
                </footer>
            </body>
            </html>
            """

            let url = "https://example.com/blog/post-\(docIndex)"
            client.mockResponse(for: url, data: html.data(using: .utf8)!)
        }
    }

    // MARK: - Real-world Scenario Tests

    func testBlogPostProcessingWorkflow() async throws {
        let client = AdvancedMockHTTPClient()
        mockBlogIndex(client: client, total: 50)
        mockDocumentResponses(client: client, count: 50)

        let baseURL = URL(string: "https://example.com/blog-index.json")!

        // Simulate a real blog processing workflow:
        // 1. Get all published posts
        // 2. Filter by category
        // 3. Sort by date (simulate with ID)
        // 4. Get first 10
        // 5. Follow document links
        // 6. Extract titles and meta information

        let processedPosts = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .chunks(10)
            .filter { post in
                return (post["published"] as? Bool) == true
            }
            .filter { post in
                return (post["category"] as? String) == "tech"
            }
            .limit(10)
            .follow("path", as: "document")
            .map { post -> [String: Any] in
                var result: [String: Any] = [:]
                result["id"] = post["id"]
                result["title"] = post["title"]
                result["author"] = post["author"]
                result["publishedDate"] = post["publishedDate"]
                result["readTime"] = post["readTime"]

                if let document = post["document"] as? Document {
                    result["htmlTitle"] = try? document.select("title").first()?.text()
                    result["description"] = try? document.select("meta[name=description]").first()?.attr("content")
                    result["keywords"] = try? document.select("meta[name=keywords]").first()?.attr("content")
                    result["imageCount"] = try? document.select("img").count
                }

                return result
            }
            .all()

        XCTAssertGreaterThan(processedPosts.count, 0)
        XCTAssertLessThanOrEqual(processedPosts.count, 10)

        // Verify structure
        for post in processedPosts {
            XCTAssertNotNil(post["id"])
            XCTAssertNotNil(post["title"])
            XCTAssertNotNil(post["author"])
            XCTAssertNotNil(post["htmlTitle"])
            XCTAssertNotNil(post["description"])
            XCTAssertNotNil(post["imageCount"])
        }
    }

    func testECommerceProductCatalog() async throws {
        let client = AdvancedMockHTTPClient()
        mockProductIndex(client: client, total: 100)

        let baseURL = URL(string: "https://example.com/products-index.json")!

        // E-commerce scenario:
        // 1. Get all in-stock products
        // 2. Filter by category
        // 3. Filter by price range
        // 4. Sort by rating (simulate with modulo)
        // 5. Get product details

        let affordableElectronics = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .chunks(25)
            .filter { product in
                return (product["inStock"] as? Bool) == true
            }
            .filter { product in
                return (product["category"] as? String) == "electronics"
            }
            .filter { product in
                let price = product["price"] as? Double ?? 0
                return price >= 100 && price <= 200
            }
            .filter { product in
                let rating = product["rating"] as? Int ?? 0
                return rating >= 4
            }
            .map { product -> [String: Any] in
                return [
                    "id": product["id"] as Any,
                    "name": product["name"] as Any,
                    "sku": product["sku"] as Any,
                    "price": product["price"] as Any,
                    "rating": product["rating"] as Any,
                    "reviews": product["reviews"] as Any,
                    "formattedPrice": String(format: "$%.2f", product["price"] as? Double ?? 0),
                    "ratingStars": String(repeating: "⭐", count: product["rating"] as? Int ?? 0)
                ]
            }
            .limit(20)
            .all()

        XCTAssertGreaterThan(affordableElectronics.count, 0)

        // Verify all products meet criteria
        for product in affordableElectronics {
            let price = product["price"] as? Double ?? 0
            XCTAssertGreaterThanOrEqual(price, 100)
            XCTAssertLessThanOrEqual(price, 200)

            let rating = product["rating"] as? Int ?? 0
            XCTAssertGreaterThanOrEqual(rating, 4)

            XCTAssertNotNil(product["formattedPrice"])
            XCTAssertNotNil(product["ratingStars"])
        }
    }

    func testContentManagementWorkflow() async throws {
        let client = AdvancedMockHTTPClient()
        mockBlogIndex(client: client, total: 30)
        mockDocumentResponses(client: client, count: 30)

        let baseURL = URL(string: "https://example.com/blog-index.json")!

        // Content management scenario:
        // 1. Get all posts
        // 2. Follow document links
        // 3. Extract SEO information
        // 4. Generate content audit report

        let seoAudit = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .chunks(10)
            .follow("path", as: "document")
            .map { post -> [String: Any] in
                var audit: [String: Any] = [:]
                audit["id"] = post["id"]
                audit["title"] = post["title"]
                audit["path"] = post["path"]
                audit["published"] = post["published"]

                if let document = post["document"] as? Document {
                    // SEO audit checks
                    let htmlTitle = try? document.select("title").first()?.text()
                    let description = try? document.select("meta[name=description]").first()?.attr("content")
                    let keywords = try? document.select("meta[name=keywords]").first()?.attr("content")
                    let h1Count = try? document.select("h1").count
                    let _ = try? document.select("h2").count
                    let imageCount = try? document.select("img").count
                    let imagesWithAlt = try? document.select("img[alt]").count

                    audit["htmlTitle"] = htmlTitle
                    audit["description"] = description
                    audit["keywords"] = keywords
                    audit["h1Count"] = h1Count
                    audit["imageCount"] = imageCount
                    audit["imagesWithAlt"] = imagesWithAlt

                    // SEO score calculation
                    var score = 0
                    if htmlTitle != nil && !htmlTitle!.isEmpty { score += 20 }
                    if description != nil && !description!.isEmpty { score += 20 }
                    if keywords != nil && !keywords!.isEmpty { score += 10 }
                    if h1Count == 1 { score += 20 }
                    if imageCount ?? 0 > 0 && imagesWithAlt == imageCount { score += 30 }

                    audit["seoScore"] = score
                    audit["seoGrade"] = score >= 80 ? "A" : score >= 60 ? "B" : score >= 40 ? "C" : "D"
                } else {
                    audit["seoScore"] = 0
                    audit["seoGrade"] = "F"
                }

                return audit
            }
            .all()

        XCTAssertEqual(seoAudit.count, 30)

        // Verify audit structure
        for audit in seoAudit {
            XCTAssertNotNil(audit["seoScore"])
            XCTAssertNotNil(audit["seoGrade"])

            let score = audit["seoScore"] as? Int ?? 0
            XCTAssertGreaterThanOrEqual(score, 0)
            XCTAssertLessThanOrEqual(score, 100)
        }

        // Calculate summary statistics
        let scores = seoAudit.compactMap { $0["seoScore"] as? Int }
        let averageScore = scores.reduce(0, +) / scores.count
        let highPerformingPages = seoAudit.filter { ($0["seoScore"] as? Int ?? 0) >= 80 }.count

        XCTAssertGreaterThan(averageScore, 0)
        print("Average SEO Score: \(averageScore)")
        print("High Performing Pages: \(highPerformingPages)/\(seoAudit.count)")
    }

    func testPerformanceOptimizedStreaming() async throws {
        let client = AdvancedMockHTTPClient()
        mockProductIndex(client: client, total: 1000)

        // Add realistic network delays
        for _ in 0..<50 { // Simulate 50 requests
            client.addDelay(0.1) // 100ms delay per request
        }

        let baseURL = URL(string: "https://example.com/products-index.json")!

        let startTime = CFAbsoluteTimeGetCurrent()

        // Process large dataset efficiently
        let expensiveProducts = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .chunks(25) // Larger chunks for better performance
            .withMaxConcurrency(3) // Limited concurrency
            .filter { product in
                let price = product["price"] as? Double ?? 0
                return price > 500
            }
            .limit(50) // Early termination
            .map { product -> [String: Any] in
                return [
                    "id": product["id"] as Any,
                    "name": product["name"] as Any,
                    "price": product["price"] as Any,
                    "formattedPrice": String(format: "$%.2f", product["price"] as? Double ?? 0)
                ]
            }
            .all()

        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime

        XCTAssertGreaterThan(expensiveProducts.count, 0)
        XCTAssertLessThanOrEqual(expensiveProducts.count, 50)

        // Verify performance (should be much faster due to early termination)
        XCTAssertLessThan(duration, 10.0) // Should complete quickly due to limit

        // Verify we made fewer requests due to early termination
        XCTAssertLessThan(client.totalRequests, 50) // Should be much less than full dataset

        print("Processed \(expensiveProducts.count) products in \(String(format: "%.2f", duration))s with \(client.totalRequests) requests")
    }

    func testErrorRecoveryAndResilience() async throws {
        let client = AdvancedMockHTTPClient()

        // Mock partial success scenario
        let baseURL = "https://example.com/blog-index.json"

        // First request succeeds
        let firstResponse = FFetchResponse(
            total: 20,
            offset: 0,
            limit: 10,
            data: Array(0..<10).map { createBlogPostEntry(id: $0) }
        )
        do {
            let data = try JSONEncoder().encode(firstResponse)
            client.mockResponse(for: "\(baseURL)?offset=0&limit=10", data: data)
        } catch {
            XCTFail("Failed to encode firstResponse: \(error)")
        }

        // Second request fails
        client.mockError(for: "\(baseURL)?offset=10&limit=10", error: URLError(.networkConnectionLost))

        let url = URL(string: baseURL)!
        let entries = try await FFetch(url: url)
            .withHTTPClient(client)
            .chunks(10)
            .map { entry -> [String: Any] in
                return [
                    "id": entry["id"] as Any,
                    "title": entry["title"] as Any,
                    "processed": true
                ]
            }
            .all()

        // Should get first 10 entries before the error
        XCTAssertEqual(entries.count, 10)

        for (index, entry) in entries.enumerated() {
            XCTAssertEqual(entry["id"] as? Int, index)
            XCTAssertEqual(entry["processed"] as? Bool, true)
        }
    }

    func testMultiSheetWorkflow() async throws {
        let client = AdvancedMockHTTPClient()
        let baseURL = "https://example.com/multi-sheet-index.json"

        // Mock products sheet
        let productsResponse = FFetchResponse(
            total: 10,
            offset: 0,
            limit: 255,
            data: Array(0..<10).map { createProductEntry(id: $0) }
        )
        do {
            let data = try JSONEncoder().encode(productsResponse)
            client.mockResponse(for: "\(baseURL)?offset=0&limit=255&sheet=products", data: data)
        } catch {
            XCTFail("Failed to encode productsResponse: \(error)")
        }

        // Mock blog sheet
        let blogResponse = FFetchResponse(
            total: 5,
            offset: 0,
            limit: 255,
            data: Array(0..<5).map { createBlogPostEntry(id: $0) }
        )
        do {
            let data = try JSONEncoder().encode(blogResponse)
            client.mockResponse(for: "\(baseURL)?offset=0&limit=255&sheet=blog", data: data)
        } catch {
            XCTFail("Failed to encode blogResponse: \(error)")
        }

        let url = URL(string: baseURL)!

        // Process products sheet
        let products = try await FFetch(url: url)
            .withHTTPClient(client)
            .sheet("products")
            .filter { product in
                return (product["inStock"] as? Bool) == true
            }
            .map { product -> [String: Any] in
                return [
                    "type": "product",
                    "id": product["id"] as Any,
                    "name": product["name"] as Any,
                    "price": product["price"] as Any
                ]
            }
            .all()

        // Process blog sheet
        let blogPosts = try await FFetch(url: url)
            .withHTTPClient(client)
            .sheet("blog")
            .filter { post in
                return (post["published"] as? Bool) == true
            }
            .map { post -> [String: Any] in
                return [
                    "type": "blog",
                    "id": post["id"] as Any,
                    "title": post["title"] as Any,
                    "author": post["author"] as Any
                ]
            }
            .all()

        XCTAssertGreaterThan(products.count, 0)
        XCTAssertGreaterThan(blogPosts.count, 0)

        // Verify type differentiation
        for product in products {
            XCTAssertEqual(product["type"] as? String, "product")
        }

        for post in blogPosts {
            XCTAssertEqual(post["type"] as? String, "blog")
        }
    }

    func testComplexDataAggregation() async throws {
        let client = AdvancedMockHTTPClient()
        mockBlogIndex(client: client, total: 100)

        let baseURL = URL(string: "https://example.com/blog-index.json")!

        // Complex aggregation: Group by author and calculate statistics
        let allPosts = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .chunks(20)
            .filter { post in
                // Accept true for Bool, NSNumber, or any value that is "truthy"
                if let isPublished = post["published"] as? Bool {
                    return isPublished
                }
                if let publishedNumber = post["published"] as? NSNumber {
                    return publishedNumber.boolValue
                }
                if let publishedString = post["published"] as? String {
                    return publishedString == "true" || publishedString == "1"
                }
                return false
            }
            .all()



        // Group by author
        var authorStats: [String: [String: Any]] = [:]

        for post in allPosts {
            let author = post["author"] as? String ?? "Unknown"
            let readTime = post["readTime"] as? Int ?? 0

            if authorStats[author] == nil {
                authorStats[author] = [
                    "postCount": 0,
                    "totalReadTime": 0,
                    "categories": Set<String>()
                ]
            }

            var stats = authorStats[author]!
            stats["postCount"] = (stats["postCount"] as? Int ?? 0) + 1
            stats["totalReadTime"] = (stats["totalReadTime"] as? Int ?? 0) + readTime

            if let category = post["category"] as? String {
                var categories = stats["categories"] as? Set<String> ?? Set()
                categories.insert(category)
                stats["categories"] = categories
            }

            authorStats[author] = stats
        }

        // Calculate final statistics
        for (author, stats) in authorStats {
            let postCount = stats["postCount"] as? Int ?? 0
            let totalReadTime = stats["totalReadTime"] as? Int ?? 0
            let averageReadTime = postCount > 0 ? totalReadTime / postCount : 0

            authorStats[author]?["averageReadTime"] = averageReadTime
            authorStats[author]?["categoryCount"] = (stats["categories"] as? Set<String>)?.count ?? 0
        }

        // If allPosts is empty, fail early with diagnostic
        if allPosts.isEmpty {
            XCTFail("No posts were returned from FFetch. Check mockBlogIndex or filter logic.")
            return
        }

        XCTAssertGreaterThan(authorStats.count, 0)

        // Verify statistics
        for (_, stats) in authorStats {
            XCTAssertGreaterThan(stats["postCount"] as? Int ?? 0, 0)
            XCTAssertGreaterThanOrEqual(stats["averageReadTime"] as? Int ?? 0, 0)
            XCTAssertGreaterThanOrEqual(stats["categoryCount"] as? Int ?? 0, 0)
        }
    }
}
