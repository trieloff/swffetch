# Security Features in SwiftFFetch

## Overview

SwiftFFetch includes several security features designed to protect applications from common web security vulnerabilities. The most important of these is the **hostname restriction** feature for document following operations.

## Hostname Restriction for Document Following

### The Problem

When following links to fetch HTML documents, applications can be vulnerable to several types of attacks:

1. **Server-Side Request Forgery (SSRF)**: Malicious actors could trick your application into making requests to internal services or unintended external hosts
2. **Data Exfiltration**: Uncontrolled document following could be used to extract sensitive data from internal networks
3. **Cross-Site Request Forgery (CSRF)**: Applications might inadvertently make requests to external services on behalf of users

### The Solution

SwiftFFetch implements a **hostname allowlist** system that restricts document following to approved hostnames only.

#### Default Behavior

By default, document following is restricted to the **same hostname** as the initial JSON request:

```swift
// If your initial request is to https://example.com/query-index.json
// Then document following will only work for URLs like:
// - https://example.com/document.html  ✅ Allowed
// - /relative/path.html                ✅ Allowed (resolves to same host)
// - https://malicious.com/evil.html    ❌ Blocked
```

#### Explicit Allowlist

You can explicitly allow additional hostnames using the `.allow()` method:

```swift
// Allow a specific hostname
let entries = try await FFetch(url: "https://example.com/query-index.json")
    .allow("trusted.com")
    .follow("path", as: "document")
    .all()

// Allow multiple hostnames
let entries = try await FFetch(url: "https://example.com/query-index.json")
    .allow(["api.example.com", "cdn.example.com"])
    .follow("path", as: "document")
    .all()

// Allow all hostnames (use with extreme caution)
let entries = try await FFetch(url: "https://example.com/query-index.json")
    .allow("*")
    .follow("path", as: "document")
    .all()
```

### Security Best Practices

#### 1. Principle of Least Privilege
Only allow the minimum set of hostnames required for your application to function.

```swift
// ❌ Too permissive
.allow("*")

// ✅ Specific and minimal
.allow(["api.example.com", "cdn.example.com"])
```

#### 2. Validate Hostnames
Ensure that hostnames you're allowing are under your control or from trusted partners.

```swift
// ❌ Potentially dangerous
.allow("user-provided-hostname.com")

// ✅ Validated and trusted
.allow("api.yourcompany.com")
```

#### 3. Monitor and Log
Consider logging blocked requests to detect potential security issues:

```swift
let entries = try await FFetch(url: "https://example.com/query-index.json")
    .follow("path", as: "document")
    .all()

for entry in entries {
    if let error = entry["document_error"] as? String {
        if error.contains("not allowed") {
            print("⚠️  Security block: \(error)")
        }
    }
}
```

#### 4. Handle Errors Gracefully
Design your application to continue functioning even when some documents are blocked:

```swift
for entry in entries {
    if let doc = entry["document"] as? Document {
        // Process the document
        processDocument(doc)
    } else if let error = entry["document_error"] as? String {
        // Log the error but continue processing
        print("Document unavailable: \(error)")
        // Use fallback data or skip this entry
    }
}
```

### Technical Implementation

The security check is performed in the `followDocument` method before any network request is made:

1. **URL Resolution**: The target URL is resolved (handling relative paths)
2. **Hostname Extraction**: The hostname is extracted from the resolved URL
3. **Allowlist Check**: The hostname is checked against the allowed hosts set
4. **Request or Block**: If allowed, the request proceeds; if blocked, an error is returned

### Error Messages

When a hostname is blocked, you'll receive a descriptive error message:

```
"Hostname 'malicious.com' is not allowed for document following. Use .allow() to permit additional hostnames."
```

### Edge Cases

#### Relative URLs
Relative URLs are resolved against the base URL and will typically be allowed (since they resolve to the same host):

```swift
// Base URL: https://example.com/query-index.json
// Relative URL: "/document.html" → "https://example.com/document.html" ✅ Allowed
```

#### URLs without Hostnames
URLs without hostnames (like `file://` URLs) are always blocked:

```swift
// file:///local/document.html ❌ Always blocked
```

#### Subdomains
Subdomains are treated as separate hostnames and must be explicitly allowed:

```swift
// Base: https://example.com/
// Target: https://api.example.com/ ❌ Blocked (different hostname)
// Must use: .allow("api.example.com")
```

### Migration Guide

If you're upgrading from a version without hostname restrictions:

1. **Test your application** to identify which external hostnames are being accessed
2. **Add explicit allow calls** for legitimate external hostnames
3. **Review and minimize** the set of allowed hostnames
4. **Monitor error logs** for any blocked requests that should be allowed

### Performance Considerations

The hostname security check adds minimal overhead:
- String comparison operations are very fast
- The check happens before any network request, so failed checks don't waste network resources
- The allowed hosts set is stored in memory for fast lookup

### Compliance

This security feature helps with:
- **OWASP Top 10**: Mitigates SSRF vulnerabilities
- **Security Audits**: Demonstrates proactive security measures
- **Internal Security Policies**: Provides controls for network access
- **Zero Trust Architecture**: Implements explicit allowlisting

## Summary

The hostname restriction feature provides a robust defense against common web application security vulnerabilities while maintaining flexibility for legitimate use cases. By defaulting to a secure configuration and requiring explicit allowlisting, SwiftFFetch helps developers build more secure applications without compromising functionality.