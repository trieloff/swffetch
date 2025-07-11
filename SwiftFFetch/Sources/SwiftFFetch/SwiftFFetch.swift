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

import Foundation

/// SwiftFFetch - A Swift port of the ffetch library for Adobe Experience Manager Edge Delivery Services
///
/// SwiftFFetch provides a fluent API for working with AEM indices, offering lazy pagination,
/// filtering, transformation, and document following capabilities.
///
/// ## Features
///
/// - **Lazy Pagination**: Efficiently stream large datasets without loading everything into memory
/// - **Fluent API**: Chain operations like `filter`, `map`, `limit`, and `slice`
/// - **Async/Await**: Built on Swift's modern concurrency model
/// - **Document Following**: Follow references to fetch and parse HTML documents
/// - **Multi-sheet Support**: Work with multi-sheet JSON responses
/// - **Configurable**: Customize HTTP client, HTML parser, and concurrency settings
/// - **Minimal Dependencies**: Only depends on Foundation and a lightweight HTML parser
///
/// ## Basic Usage
///
/// ```swift
/// import SwiftFFetch
///
/// // Stream all entries
/// let entries = try ffetch("/query-index.json")
/// for await entry in entries {
///     print(entry["title"] as? String ?? "No title")
/// }
///
/// // Get first 10 published entries
/// let published = try await ffetch("/query-index.json")
///     .filter { ($0["published"] as? Bool) == true }
///     .limit(10)
///     .all()
/// ```
///
/// ## Advanced Usage
///
/// ```swift
/// // Follow document references and extract titles
/// let titles = try await ffetch("/query-index.json")
///     .follow("path", as: "document")
///     .map { entry -> String in
///         guard let doc = entry["document"] as? Document else { return "No document" }
///         return try doc.select("title").first()?.text() ?? "No title"
///     }
///     .limit(5)
///     .all()
/// ```
///
/// ## Configuration
///
/// ```swift
/// // Custom chunk size and concurrency
/// let entries = try ffetch("/query-index.json")
///     .chunks(100)
///     .withMaxConcurrency(10)
///     .withCacheReload(true)
/// ```
public enum SwiftFFetch {
    /// Current version of SwiftFFetch
    public static let version = "1.0.0"

    /// Build information
    public static let build = "SwiftFFetch \(version) - Swift port of ffetch for AEM Edge Delivery Services"
}
