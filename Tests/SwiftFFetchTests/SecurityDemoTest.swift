//
//  SecurityDemoTest.swift
//  SwiftFFetchTests
//
//  Demonstration of hostname security features in SwiftFFetch
//

import XCTest
import SwiftSoup
@testable import SwiftFFetch

/// Demonstration test showing the hostname security feature in action
final class SecurityDemoTest: XCTestCase {

    /// Mock HTTP client for testing
    private var client: MockHTTPClient!

    override func setUp() {
        super.setUp()
        client = MockHTTPClient()
    }

    /// Comprehensive demonstration of security features
    func testSecurityFeatureDemo() async throws {
        print("\n🔒 SwiftFFetch Security Feature Demonstration")
        print("=" * 60)

        let baseURL = URL(string: "https://example.com/query-index.json")!
        setupMockData(baseURL: baseURL)

        // Test 1: Default security (same hostname only)
        print("\n📋 Test 1: Default Security (Same Hostname Only)")
        let defaultSecurityEntries = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .follow("path", as: "document")
            .all()

        printSecurityResults(defaultSecurityEntries, testName: "Default Security")

        // Test 2: Explicitly allow trusted hostname
        print("\n📋 Test 2: Allow Trusted Hostname")
        let trustedHostEntries = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .allow("trusted.com")
            .follow("path", as: "document")
            .all()

        printSecurityResults(trustedHostEntries, testName: "Trusted Host")

        // Test 3: Allow multiple hostnames
        print("\n📋 Test 3: Allow Multiple Hostnames")
        let multiHostEntries = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .allow(["trusted.com", "api.example.com"])
            .follow("path", as: "document")
            .all()

        printSecurityResults(multiHostEntries, testName: "Multiple Hosts")

        // Test 4: Wildcard (allow all - demonstrate risk)
        print("\n📋 Test 4: Wildcard Allow All (⚠️ High Risk)")
        let wildcardEntries = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .allow("*")
            .follow("path", as: "document")
            .all()

        printSecurityResults(wildcardEntries, testName: "Wildcard (All Allowed)")

        // Verify expected behavior
        XCTAssertEqual(defaultSecurityEntries.count, 5)
        XCTAssertEqual(trustedHostEntries.count, 5)
        XCTAssertEqual(multiHostEntries.count, 5)
        XCTAssertEqual(wildcardEntries.count, 5)

        print("\n✅ Security feature demonstration completed successfully!")
        print("=" * 60)
    }

    /// Setup mock data for demo test
    private func setupMockData(baseURL: URL) {
        // Mock index response with mixed hostname URLs
        let entries = [
            ["title": "Same Host Document", "path": "/same-host.html"],
            ["title": "Trusted External", "path": "https://trusted.com/document.html"],
            ["title": "Malicious External", "path": "https://malicious.com/evil.html"],
            ["title": "API Document", "path": "https://api.example.com/data.html"],
            ["title": "Relative Path", "path": "relative/doc.html"]
        ]

        let data = createMockResponse(total: 5, offset: 0, limit: 255, entries: entries)
        client.mockResponse(for: baseURL, data: data)

        // Mock responses for allowed documents
        let sameHostHTML = "<html><head><title>Same Host</title></head><body>Safe content</body></html>"
        let trustedHTML = "<html><head><title>Trusted</title></head><body>Trusted content</body></html>"
        let apiHTML = "<html><head><title>API</title></head><body>API content</body></html>"
        let relativeHTML = "<html><head><title>Relative</title></head><body>Relative content</body></html>"

        client.mockResponse(for: URL(string: "https://example.com/same-host.html")!,
                           data: sameHostHTML.data(using: .utf8)!)
        client.mockResponse(for: URL(string: "https://trusted.com/document.html")!,
                           data: trustedHTML.data(using: .utf8)!)
        client.mockResponse(for: URL(string: "https://api.example.com/data.html")!,
                           data: apiHTML.data(using: .utf8)!)
        client.mockResponse(for: URL(string: "https://example.com/relative/doc.html")!,
                           data: relativeHTML.data(using: .utf8)!)
    }

    /// Helper method to print security test results
    private func printSecurityResults(_ entries: [FFetchEntry], testName: String) {
        print("\n\(testName) Results:")
        for entry in entries {
            let title = entry["title"] as? String ?? "Unknown"
            _ = entry["path"] as? String ?? "Unknown"

            if entry["document"] != nil {
                print("  ✅ \(title): Document loaded successfully")
            } else if let error = entry["document_error"] as? String {
                if error.contains("not allowed") {
                    print("  🔒 \(title): BLOCKED - \(error)")
                } else {
                    print("  ❌ \(title): ERROR - \(error)")
                }
            } else {
                print("  ❓ \(title): Unknown state")
            }
        }
    }

    /// Test demonstrating security bypass attempts
    func testSecurityBypassAttempts() async throws {
        print("\n🛡️ Testing Security Bypass Attempts")
        print("=" * 50)

        let baseURL = URL(string: "https://example.com/query-index.json")!

        // Attempt various bypass techniques
        let maliciousEntries = [
            ["title": "Direct Malicious", "path": "https://malicious.com/steal-data"],
            ["title": "Protocol Bypass", "path": "file:///etc/passwd"],
            ["title": "IP Address", "path": "https://192.168.1.1/internal"],
            ["title": "Subdomain Bypass", "path": "https://evil.example.com/attack"],
            ["title": "Port Bypass", "path": "https://different.com:8080/internal"]
        ]

        let data = createMockResponse(total: 5, offset: 0, limit: 255, entries: maliciousEntries)
        client.mockResponse(for: baseURL, data: data)

        let results = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .follow("path", as: "document")
            .all()

        print("\nBypass Attempt Results:")
        var blockedCount = 0
        for entry in results {
            let title = entry["title"] as? String ?? "Unknown"
            if let error = entry["document_error"] as? String {
                if error.contains("not allowed") {
                    print("  🔒 \(title): Successfully blocked")
                    blockedCount += 1
                } else {
                    print("  ❌ \(title): Other error - \(error)")
                }
            } else {
                print("  ⚠️ \(title): Unexpectedly allowed!")
            }
        }

        print("\n🛡️ Security Summary: \(blockedCount)/\(results.count) malicious requests blocked")
        XCTAssertEqual(blockedCount, results.count, "All malicious requests should be blocked")
    }

    /// Test proper error handling and user experience
    func testSecurityErrorHandling() async throws {
        print("\n🔧 Testing Security Error Handling")
        print("=" * 40)

        let baseURL = URL(string: "https://example.com/query-index.json")!

        let mixedEntries = [
            ["title": "Valid Document", "path": "/valid.html"],
            ["title": "Blocked Document", "path": "https://blocked.com/doc.html"]
        ]

        let data = createMockResponse(total: 2, offset: 0, limit: 255, entries: mixedEntries)
        client.mockResponse(for: baseURL, data: data)

        // Mock valid document
        let validHTML = "<html><head><title>Valid</title></head><body>Valid content</body></html>"
        client.mockResponse(for: URL(string: "https://example.com/valid.html")!, data: validHTML.data(using: .utf8)!)

        let results = try await FFetch(url: baseURL)
            .withHTTPClient(client)
            .follow("path", as: "document")
            .all()

        print("\nError Handling Results:")
        var validCount = 0
        var blockedCount = 0

        for entry in results {
            let title = entry["title"] as? String ?? "Unknown"

            if entry["document"] != nil {
                print("  ✅ \(title): Document processed successfully")
                validCount += 1
            } else if let error = entry["document_error"] as? String {
                if error.contains("not allowed") {
                    print("  🔒 \(title): Gracefully blocked with clear error message")
                    blockedCount += 1
                } else {
                    print("  ❌ \(title): Other error - \(error)")
                }
            }
        }

        print("\n📊 Results: \(validCount) valid, \(blockedCount) blocked")
        print("✅ Application continues to function with mixed security outcomes")

        XCTAssertEqual(validCount, 1, "Valid document should be processed")
        XCTAssertEqual(blockedCount, 1, "Blocked document should have security error")
    }
}

// MARK: - Helper Extensions

private extension String {
    static func * (left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}
