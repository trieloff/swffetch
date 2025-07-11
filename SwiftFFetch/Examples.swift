//
//  Examples.swift
//  SwiftFFetch
//
//  Created by SwiftFFetch on 2025-07-11.
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

import Foundation
import SwiftSoup
import SwiftFFetch

/// Examples demonstrating various SwiftFFetch usage patterns
public class FFetchExamples {

    // MARK: - Basic Usage Examples

    /// Example 1: Basic streaming of all entries
    public static func basicStreaming() async throws {
        print("=== Basic Streaming Example ===")

        let entries = try ffetch("https://example.com/query-index.json")
        var count = 0

        for await entry in entries {
            let title = entry["title"] as? String ?? "No title"
            print("Entry \(count): \(title)")
            count += 1

            // Stop after 5 entries for demo
            if count >= 5 { break }
        }

        print("Processed \(count) entries\n")
    }

    /// Example 2: Get first entry
    public static func getFirstEntry() async throws {
        print("=== Get First Entry Example ===")

        let firstEntry = try await ffetch("https://example.com/query-index.json").first()

        if let entry = firstEntry {
            print("First entry title: \(entry["title"] as? String ?? "No title")")
        } else {
            print("No entries found")
        }
        print()
    }

    /// Example 3: Collect all entries
    public static func collectAllEntries() async throws {
        print("=== Collect All Entries Example ===")

        let allEntries = try await ffetch("https://example.com/query-index.json")
            .limit(10) // Limit for demo purposes
            .all()

        print("Total entries collected: \(allEntries.count)")

        for (index, entry) in allEntries.enumerated() {
            let title = entry["title"] as? String ?? "No title"
            print("  \(index + 1). \(title)")
        }
        print()
    }

    // MARK: - Filtering Examples

    /// Example 4: Filter published content
    public static func filterPublishedContent() async throws {
        print("=== Filter Published Content Example ===")

        let publishedEntries = try await ffetch("https://example.com/blog-index.json")
            .filter { entry in
                return (entry["published"] as? Bool) == true
            }
            .limit(5)
            .all()

        print("Found \(publishedEntries.count) published entries:")
        for entry in publishedEntries {
            let title = entry["title"] as? String ?? "No title"
            let author = entry["author"] as? String ?? "Unknown"
            print("  - \(title) by \(author)")
        }
        print()
    }

    /// Example 5: Complex filtering with multiple conditions
    public static func complexFiltering() async throws {
        print("=== Complex Filtering Example ===")

        let techPosts = try await ffetch("https://example.com/blog-index.json")
            .filter { entry in
                // Must be published
                guard (entry["published"] as? Bool) == true else { return false }

                // Must be in tech category
                guard (entry["category"] as? String) == "tech" else { return false }

                // Must have minimum read time
                let readTime = entry["readTime"] as? Int ?? 0
                return readTime >= 3
            }
            .limit(10)
            .all()

        print("Found \(techPosts.count) tech posts with 3+ min read time:")
        for post in techPosts {
            let title = post["title"] as? String ?? "No title"
            let readTime = post["readTime"] as? Int ?? 0
            print("  - \(title) (\(readTime) min read)")
        }
        print()
    }

    // MARK: - Mapping Examples

    /// Example 6: Simple mapping to extract titles
    public static func simpleMappingExample() async throws {
        print("=== Simple Mapping Example ===")

        let titles = try await ffetch("https://example.com/blog-index.json")
            .map { entry in
                return entry["title"] as? String ?? "Untitled"
            }
            .limit(5)
            .all()

        print("Extracted titles:")
        for title in titles {
            print("  - \(title)")
        }
        print()
    }

    /// Example 7: Complex mapping with transformation
    public static func complexMappingExample() async throws {
        print("=== Complex Mapping Example ===")

        let summaries = try await ffetch("https://example.com/blog-index.json")
            .filter { entry in
                (entry["published"] as? Bool) == true
            }
            .map { entry -> [String: Any] in
                return [
                    "id": entry["id"] as Any,
                    "title": entry["title"] as? String ?? "Untitled",
                    "author": entry["author"] as? String ?? "Unknown",
                    "summary": "\(entry["title"] as? String ?? "Untitled") by \(entry["author"] as? String ?? "Unknown")",
                    "publishedDate": entry["publishedDate"] as? String ?? "Unknown",
                    "readTime": entry["readTime"] as? Int ?? 0,
                    "formattedReadTime": "\(entry["readTime"] as? Int ?? 0) min read"
                ]
            }
            .limit(5)
            .all()

        print("Blog post summaries:")
        for summary in summaries {
            print("  - \(summary["summary"] as? String ?? "No summary")")
            print("    Published: \(summary["publishedDate"] as? String ?? "Unknown")")
            print("    Read time: \(summary["formattedReadTime"] as? String ?? "Unknown")")
            print()
        }
    }

    // MARK: - Chaining Operations Examples

    /// Example 8: Complex operation chaining
    public static func complexChaining() async throws {
        print("=== Complex Chaining Example ===")

        let result = try await ffetch("https://example.com/blog-index.json")
            .filter { entry in
                (entry["published"] as? Bool) == true
            }
            .filter { entry in
                (entry["category"] as? String) == "tech"
            }
            .map { entry -> [String: Any] in
                return [
                    "title": (entry["title"] as? String ?? "").uppercased(),
                    "author": entry["author"] as? String ?? "Unknown",
                    "readTime": entry["readTime"] as? Int ?? 0
                ]
            }
            .filter { entry in
                let readTime = entry["readTime"] as? Int ?? 0
                return readTime >= 5
            }
            .limit(3)
            .all()

        print("Final filtered and transformed results:")
        for entry in result {
            print("  - \(entry["title"] as? String ?? "No title")")
            print("    Author: \(entry["author"] as? String ?? "Unknown")")
            print("    Read time: \(entry["readTime"] as? Int ?? 0) minutes")
            print()
        }
    }

    // MARK: - Pagination Examples

    /// Example 9: Custom chunk sizes
    public static func customChunkSizes() async throws {
        print("=== Custom Chunk Sizes Example ===")

        let entries = try await ffetch("https://example.com/large-index.json")
            .chunks(50) // Fetch 50 entries at a time
            .limit(100) // Only process first 100 entries
            .all()

        print("Processed \(entries.count) entries using chunk size of 50")
        print()
    }

    /// Example 10: Slice operations
    public static func sliceOperations() async throws {
        print("=== Slice Operations Example ===")

        // Get entries 10-19 (skip first 10, take next 10)
        let middleEntries = try await ffetch("https://example.com/blog-index.json")
            .slice(10, 20)
            .all()

        print("Entries 10-19:")
        for (index, entry) in middleEntries.enumerated() {
            let title = entry["title"] as? String ?? "No title"
            print("  \(index + 10): \(title)")
        }
        print()
    }

    // MARK: - Multi-sheet Examples

    /// Example 11: Working with multiple sheets
    public static func multiSheetExample() async throws {
        print("=== Multi-sheet Example ===")

        // Process products sheet
        let products = try await ffetch("https://example.com/multi-sheet-index.json")
            .sheet("products")
            .filter { product in
                (product["inStock"] as? Bool) == true
            }
            .map { product -> [String: Any] in
                return [
                    "name": product["name"] as? String ?? "Unknown",
                    "price": product["price"] as? Double ?? 0.0,
                    "category": product["category"] as? String ?? "Unknown"
                ]
            }
            .limit(5)
            .all()

        print("Products in stock:")
        for product in products {
            let name = product["name"] as? String ?? "Unknown"
            let price = product["price"] as? Double ?? 0.0
            let category = product["category"] as? String ?? "Unknown"
            print("  - \(name): $\(String(format: "%.2f", price)) (\(category))")
        }

        // Process blog sheet
        let blogPosts = try await ffetch("https://example.com/multi-sheet-index.json")
            .sheet("blog")
            .filter { post in
                (post["published"] as? Bool) == true
            }
            .map { post -> [String: Any] in
                return [
                    "title": post["title"] as? String ?? "Untitled",
                    "author": post["author"] as? String ?? "Unknown",
                    "publishedDate": post["publishedDate"] as? String ?? "Unknown"
                ]
            }
            .limit(3)
            .all()

        print("\nRecent blog posts:")
        for post in blogPosts {
            let title = post["title"] as? String ?? "Untitled"
            let author = post["author"] as? String ?? "Unknown"
            print("  - \(title) by \(author)")
        }
        print()
    }

    // MARK: - Document Following Examples

    /// Example 12: Basic document following
    public static func documentFollowing() async throws {
        print("=== Document Following Example ===")

        let postsWithContent = try await ffetch("https://example.com/blog-index.json")
            .follow("path", as: "document")
            .map { entry -> [String: Any] in
                var result: [String: Any] = [
                    "title": entry["title"] as? String ?? "Untitled",
                    "path": entry["path"] as? String ?? "Unknown"
                ]

                if let document = entry["document"] as? Document {
                    result["htmlTitle"] = try? document.select("title").first()?.text()
                    result["hasDocument"] = true
                } else {
                    result["hasDocument"] = false
                }

                return result
            }
            .limit(3)
            .all()

        print("Posts with followed documents:")
        for post in postsWithContent {
            let title = post["title"] as? String ?? "Untitled"
            let hasDoc = post["hasDocument"] as? Bool ?? false
            let htmlTitle = post["htmlTitle"] as? String ?? "No HTML title"

            print("  - \(title)")
            print("    Has document: \(hasDoc)")
            if hasDoc {
                print("    HTML title: \(htmlTitle)")
            }
            print()
        }
    }

    /// Example 13: Advanced document processing
    public static func advancedDocumentProcessing() async throws {
        print("=== Advanced Document Processing Example ===")

        let seoAnalysis = try await ffetch("https://example.com/blog-index.json")
            .follow("path", as: "document")
            .map { entry -> [String: Any] in
                var analysis: [String: Any] = [
                    "title": entry["title"] as? String ?? "Untitled",
                    "path": entry["path"] as? String ?? "Unknown"
                ]

                if let document = entry["document"] as? Document {
                    // Extract SEO information
                    let htmlTitle = try? document.select("title").first()?.text()
                    let description = try? document.select("meta[name=description]").first()?.attr("content")
                    let keywords = try? document.select("meta[name=keywords]").first()?.attr("content")
                    let h1Count = try? document.select("h1").count()
                    let h2Count = try? document.select("h2").count()
                    let imageCount = try? document.select("img").count()
                    let imagesWithAlt = try? document.select("img[alt]").count()

                    analysis["htmlTitle"] = htmlTitle
                    analysis["description"] = description
                    analysis["keywords"] = keywords
                    analysis["h1Count"] = h1Count
                    analysis["h2Count"] = h2Count
                    analysis["imageCount"] = imageCount
                    analysis["imagesWithAlt"] = imagesWithAlt

                    // Calculate SEO score
                    var seoScore = 0
                    if htmlTitle != nil && !htmlTitle!.isEmpty { seoScore += 20 }
                    if description != nil && !description!.isEmpty { seoScore += 20 }
                    if keywords != nil && !keywords!.isEmpty { seoScore += 10 }
                    if h1Count == 1 { seoScore += 20 }
                    if imageCount ?? 0 > 0 && imagesWithAlt == imageCount { seoScore += 30 }

                    analysis["seoScore"] = seoScore
                    analysis["seoGrade"] = seoScore >= 80 ? "A" : seoScore >= 60 ? "B" : seoScore >= 40 ? "C" : "D"
                }

                return analysis
            }
            .limit(5)
            .all()

        print("SEO Analysis Results:")
        for analysis in seoAnalysis {
            let title = analysis["title"] as? String ?? "Untitled"
            let seoScore = analysis["seoScore"] as? Int ?? 0
            let seoGrade = analysis["seoGrade"] as? String ?? "F"
            let h1Count = analysis["h1Count"] as? Int ?? 0
            let imageCount = analysis["imageCount"] as? Int ?? 0
            let imagesWithAlt = analysis["imagesWithAlt"] as? Int ?? 0

            print("  - \(title)")
            print("    SEO Score: \(seoScore)/100 (Grade: \(seoGrade))")
            print("    H1 tags: \(h1Count)")
            print("    Images: \(imageCount) (with alt: \(imagesWithAlt))")
            print()
        }
    }

    // MARK: - Performance Examples

    /// Example 14: Performance optimization
    public static func performanceOptimization() async throws {
        print("=== Performance Optimization Example ===")

        let startTime = CFAbsoluteTimeGetCurrent()

        let optimizedResults = try await ffetch("https://example.com/large-index.json")
            .chunks(100)                // Larger chunks for better throughput
            .withMaxConcurrency(3)      // Control concurrency
            .filter { entry in
                // Quick filtering to reduce processing
                return (entry["priority"] as? String) == "high"
            }
            .limit(20)                  // Early termination
            .map { entry -> [String: Any] in
                return [
                    "id": entry["id"] as Any,
                    "title": entry["title"] as? String ?? "Untitled",
                    "priority": entry["priority"] as? String ?? "Unknown"
                ]
            }
            .all()

        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime

        print("Processed \(optimizedResults.count) high-priority entries in \(String(format: "%.2f", duration))s")
        print()
    }

    // MARK: - Error Handling Examples

    /// Example 15: Error handling
    public static func errorHandlingExample() async {
        print("=== Error Handling Example ===")

        do {
            let entries = try await ffetch("https://example.com/invalid-url.json")
                .limit(5)
                .all()

            print("Found \(entries.count) entries")

        } catch FFetchError.invalidURL(let url) {
            print("Invalid URL provided: \(url)")
        } catch FFetchError.networkError(let error) {
            print("Network error occurred: \(error.localizedDescription)")
        } catch FFetchError.decodingError(let error) {
            print("Failed to decode response: \(error.localizedDescription)")
        } catch {
            print("Unexpected error: \(error)")
        }
        print()
    }

    // MARK: - Real-world Scenarios

    /// Example 16: E-commerce product catalog
    public static func ecommerceProductCatalog() async throws {
        print("=== E-commerce Product Catalog Example ===")

        let affordableElectronics = try await ffetch("https://example.com/products-index.json")
            .sheet("products")
            .filter { product in
                // In stock products only
                return (product["inStock"] as? Bool) == true
            }
            .filter { product in
                // Electronics category
                return (product["category"] as? String) == "electronics"
            }
            .filter { product in
                // Price range $100-$500
                let price = product["price"] as? Double ?? 0
                return price >= 100 && price <= 500
            }
            .filter { product in
                // Good ratings only
                let rating = product["rating"] as? Int ?? 0
                return rating >= 4
            }
            .map { product -> [String: Any] in
                return [
                    "id": product["id"] as Any,
                    "name": product["name"] as? String ?? "Unknown",
                    "price": product["price"] as? Double ?? 0.0,
                    "rating": product["rating"] as? Int ?? 0,
                    "formattedPrice": String(format: "$%.2f", product["price"] as? Double ?? 0),
                    "ratingStars": String(repeating: "⭐", count: product["rating"] as? Int ?? 0)
                ]
            }
            .limit(10)
            .all()

        print("Affordable Electronics (4+ stars, $100-$500):")
        for product in affordableElectronics {
            let name = product["name"] as? String ?? "Unknown"
            let formattedPrice = product["formattedPrice"] as? String ?? "$0.00"
            let ratingStars = product["ratingStars"] as? String ?? ""

            print("  - \(name): \(formattedPrice) \(ratingStars)")
        }
        print()
    }

    /// Example 17: Content management workflow
    public static func contentManagementWorkflow() async throws {
        print("=== Content Management Workflow Example ===")

        // Get content statistics
        let contentStats = try await ffetch("https://example.com/content-index.json")
            .follow("path", as: "document")
            .map { content -> [String: Any] in
                var stats: [String: Any] = [
                    "id": content["id"] as Any,
                    "title": content["title"] as? String ?? "Untitled",
                    "type": content["type"] as? String ?? "Unknown",
                    "published": content["published"] as? Bool ?? false
                ]

                if let document = content["document"] as? Document {
                    let wordCount = try? document.select("body").text().split(separator: " ").count
                    let headingCount = try? document.select("h1, h2, h3, h4, h5, h6").count()
                    let linkCount = try? document.select("a").count()
                    let imageCount = try? document.select("img").count()

                    stats["wordCount"] = wordCount
                    stats["headingCount"] = headingCount
                    stats["linkCount"] = linkCount
                    stats["imageCount"] = imageCount

                    // Content quality score
                    var qualityScore = 0
                    if wordCount ?? 0 >= 300 { qualityScore += 25 }
                    if headingCount ?? 0 >= 2 { qualityScore += 25 }
                    if linkCount ?? 0 >= 1 { qualityScore += 25 }
                    if imageCount ?? 0 >= 1 { qualityScore += 25 }

                    stats["qualityScore"] = qualityScore
                }

                return stats
            }
            .all()

        // Calculate aggregated statistics
        let totalContent = contentStats.count
        let publishedContent = contentStats.filter { ($0["published"] as? Bool) == true }.count
        let averageWordCount = contentStats.compactMap { $0["wordCount"] as? Int }.reduce(0, +) / max(1, totalContent)
        let highQualityContent = contentStats.filter { ($0["qualityScore"] as? Int ?? 0) >= 75 }.count

        print("Content Management Report:")
        print("  Total content pieces: \(totalContent)")
        print("  Published content: \(publishedContent)")
        print("  Average word count: \(averageWordCount)")
        print("  High quality content: \(highQualityContent)")
        print("  Quality percentage: \(Int(Double(highQualityContent) / Double(totalContent) * 100))%")
        print()
    }

    // MARK: - Custom Configuration Examples

    /// Example 18: Custom HTTP client
    public static func customHTTPClientExample() async throws {
        print("=== Custom HTTP Client Example ===")

        // Create custom HTTP client with specific configuration
        let customClient = CustomHTTPClient()

        let entries = try await ffetch("https://example.com/query-index.json")
            .withHTTPClient(customClient)
            .withCacheReload(true)
            .limit(5)
            .all()

        print("Fetched \(entries.count) entries using custom HTTP client")
        print()
    }

    /// Example 19: All examples runner
    public static func runAllExamples() async throws {
        print("🚀 Running SwiftFFetch Examples")
        print("=" * 50)

        let examples: [(String, () async throws -> Void)] = [
            ("Basic Streaming", basicStreaming),
            ("Get First Entry", getFirstEntry),
            ("Collect All Entries", collectAllEntries),
            ("Filter Published Content", filterPublishedContent),
            ("Complex Filtering", complexFiltering),
            ("Simple Mapping", simpleMappingExample),
            ("Complex Mapping", complexMappingExample),
            ("Complex Chaining", complexChaining),
            ("Custom Chunk Sizes", customChunkSizes),
            ("Slice Operations", sliceOperations),
            ("Multi-sheet Example", multiSheetExample),
            ("Document Following", documentFollowing),
            ("Advanced Document Processing", advancedDocumentProcessing),
            ("Performance Optimization", performanceOptimization),
            ("Error Handling", errorHandlingExample),
            ("E-commerce Product Catalog", ecommerceProductCatalog),
            ("Content Management Workflow", contentManagementWorkflow),
            ("Custom HTTP Client", customHTTPClientExample)
        ]

        for (name, example) in examples {
            print("Running: \(name)")
            do {
                try await example()
            } catch {
                print("❌ Error in \(name): \(error)")
            }
            print("-" * 30)
        }

        print("✅ All examples completed!")
    }
}

// MARK: - Helper Classes

/// Custom HTTP client example
public class CustomHTTPClient: FFetchHTTPClient {
    private let session: URLSession

    public init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }

    public func fetch(_ url: URL, cachePolicy: URLRequest.CachePolicy) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: url)
        request.cachePolicy = cachePolicy
        request.setValue("SwiftFFetch/1.0", forHTTPHeaderField: "User-Agent")

        return try await session.data(for: request)
    }
}

// MARK: - String Extension for Convenience

extension String {
    static func *(lhs: String, rhs: Int) -> String {
        return String(repeating: lhs, count: rhs)
    }
}
