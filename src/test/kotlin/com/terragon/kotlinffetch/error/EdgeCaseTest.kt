//
// Copyright © 2025 Terragon Labs. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

package com.terragon.kotlinffetch.error

import com.terragon.kotlinffetch.*
import com.terragon.kotlinffetch.mock.MockFFetchHTTPClient
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.BeforeEach

class EdgeCaseTest {

    private lateinit var mockClient: MockFFetchHTTPClient
    private lateinit var context: FFetchContext

    @BeforeEach
    fun setUp() {
        mockClient = MockFFetchHTTPClient()
        context = FFetchContext().apply {
            httpClient = mockClient
        }
    }

    @Test
    fun `Invalid URL should throw InvalidURL error`() {
        val invalidUrls = listOf(
            "",
            "not-a-url",
            "://missing-scheme",
            "http://",
            "ftp://unsupported-scheme.com",
            "javascript:alert('xss')",
            "data:text/html,<script>alert('xss')</script>"
        )

        invalidUrls.forEach { invalidUrl ->
            val exception = assertThrows(FFetchError.InvalidURL::class.java) {
                FFetch(invalidUrl)
            }
            
            assertTrue(exception.message!!.contains(invalidUrl))
        }
    }

    @Test
    fun `Zero chunk size should work but be inefficient`() {
        val context = FFetchContext().apply {
            chunkSize = 0
            httpClient = mockClient
        }
        
        // Should not throw an exception, but will likely be inefficient
        val ffetch = FFetch("https://example.com", context)
        assertEquals(0, ffetch.context.chunkSize)
    }

    @Test
    fun `Negative chunk size should work but be problematic`() {
        val context = FFetchContext().apply {
            chunkSize = -1
            httpClient = mockClient
        }
        
        // Should not throw an exception, but behavior is undefined
        val ffetch = FFetch("https://example.com", context)
        assertEquals(-1, ffetch.context.chunkSize)
    }

    @Test
    fun `Extremely large chunk size should be handled`() {
        val context = FFetchContext().apply {
            chunkSize = Int.MAX_VALUE
            httpClient = mockClient
        }
        
        val ffetch = FFetch("https://example.com", context)
        assertEquals(Int.MAX_VALUE, ffetch.context.chunkSize)
    }

    @Test
    fun `Zero concurrency limit should work but be sequential`() {
        val context = FFetchContext().apply {
            maxConcurrency = 0
            httpClient = mockClient
        }
        
        val ffetch = FFetch("https://example.com", context)
        assertEquals(0, ffetch.context.maxConcurrency)
    }

    @Test
    fun `Negative concurrency limit should be handled`() {
        val context = FFetchContext().apply {
            maxConcurrency = -1
            httpClient = mockClient
        }
        
        val ffetch = FFetch("https://example.com", context)
        assertEquals(-1, ffetch.context.maxConcurrency)
    }

    @Test
    fun `Extremely high concurrency limit should be accepted`() {
        val context = FFetchContext().apply {
            maxConcurrency = 10000
            httpClient = mockClient
        }
        
        val ffetch = FFetch("https://example.com", context)
        assertEquals(10000, ffetch.context.maxConcurrency)
    }

    @Test
    fun `Sheet names with special characters should be handled`() {
        val specialSheetNames = listOf(
            "sheet-with-dashes",
            "sheet_with_underscores",
            "sheet with spaces",
            "sheet@with#special$chars%",
            "sheet.with.dots",
            "sheet/with/slashes",
            "sheet\\with\\backslashes",
            "sheet\"with\"quotes",
            "sheet'with'apostrophes",
            "sheet<with>brackets",
            "sheet[with]square[brackets]",
            "sheet{with}curly{braces}",
            "sheet|with|pipes",
            "sheet+with+plus+signs",
            "sheet=with=equals",
            "sheet?with?questions",
            "sheet&with&ampersands",
            "sheetñwithñunicode字符",
            "🎉emoji🎉sheet🎉",
            ""
        )

        specialSheetNames.forEach { sheetName ->
            val context = FFetchContext().apply {
                this.sheetName = sheetName
                httpClient = mockClient
            }
            
            val ffetch = FFetch("https://example.com", context)
            assertEquals(sheetName, ffetch.context.sheetName)
        }
    }

    @Test
    fun `Very long sheet name should be handled`() {
        val longSheetName = "a".repeat(10000)
        val context = FFetchContext().apply {
            sheetName = longSheetName
            httpClient = mockClient
        }
        
        val ffetch = FFetch("https://example.com", context)
        assertEquals(longSheetName, ffetch.context.sheetName)
    }

    @Test
    fun `Cache configuration with invalid maxAge should be handled`() {
        val invalidMaxAges = listOf(
            -1L,
            0L,
            Long.MAX_VALUE,
            Long.MIN_VALUE
        )

        invalidMaxAges.forEach { maxAge ->
            val cacheConfig = FFetchCacheConfig(maxAge = maxAge)
            val context = FFetchContext().apply {
                this.cacheConfig = cacheConfig
                httpClient = mockClient
            }
            
            val ffetch = FFetch("https://example.com", context)
            assertEquals(maxAge, ffetch.context.cacheConfig.maxAge)
        }
    }

    @Test
    fun `Cache configuration with conflicting flags should be handled`() {
        val conflictingConfigs = listOf(
            FFetchCacheConfig(noCache = true, cacheOnly = true),
            FFetchCacheConfig(noCache = true, cacheElseLoad = true),
            FFetchCacheConfig(cacheOnly = true, cacheElseLoad = true),
            FFetchCacheConfig(noCache = true, cacheOnly = true, cacheElseLoad = true)
        )

        conflictingConfigs.forEach { cacheConfig ->
            val context = FFetchContext().apply {
                this.cacheConfig = cacheConfig
                httpClient = mockClient
            }
            
            // Should not throw an exception, but behavior might be undefined
            val ffetch = FFetch("https://example.com", context)
            assertEquals(cacheConfig, ffetch.context.cacheConfig)
        }
    }

    @Test
    fun `URLs with unusual but valid schemes should be handled`() {
        val validUrls = listOf(
            "https://example.com",
            "http://example.com",
            "https://example.com:8080",
            "https://example.com/path",
            "https://example.com/path?query=value",
            "https://example.com/path#fragment",
            "https://example.com/path?query=value#fragment",
            "https://user:pass@example.com",
            "https://subdomain.example.com",
            "https://example.com/path/to/resource.json",
            "https://127.0.0.1:8080",
            "https://[::1]:8080",
            "https://localhost"
        )

        validUrls.forEach { url ->
            // Should not throw an exception for valid URLs
            val ffetch = FFetch(url, context)
            assertEquals(url, ffetch.url.toString())
        }
    }

    @Test
    fun `URLs with international domain names should be handled`() {
        val internationalUrls = listOf(
            "https://例え.テスト",
            "https://xn--r8jz45g.xn--zckzah",  // Punycode version
            "https://пример.тест",
            "https://مثال.آزمایشی"
        )

        internationalUrls.forEach { url ->
            try {
                val ffetch = FFetch(url, context)
                assertNotNull(ffetch.url)
            } catch (e: FFetchError.InvalidURL) {
                // Some IDNs might not be supported, which is acceptable
                assertTrue(e.message!!.contains(url))
            }
        }
    }

    @Test
    fun `Empty allowed hosts should be populated with initial hostname`() {
        val context = FFetchContext().apply {
            allowedHosts.clear()
            httpClient = mockClient
        }
        
        val ffetch = FFetch("https://example.com", context)
        
        assertTrue(ffetch.context.allowedHosts.contains("example.com"))
        assertEquals(1, ffetch.context.allowedHosts.size)
    }

    @Test
    fun `Wildcard allowed hosts should be preserved`() {
        val context = FFetchContext().apply {
            allowedHosts.clear()
            allowedHosts.add("*")
            httpClient = mockClient
        }
        
        val ffetch = FFetch("https://example.com", context)
        
        assertTrue(ffetch.context.allowedHosts.contains("*"))
        assertTrue(ffetch.context.allowedHosts.contains("example.com"))
    }

    @Test
    fun `Multiple allowed hosts should be preserved`() {
        val context = FFetchContext().apply {
            allowedHosts.clear()
            allowedHosts.addAll(listOf("example.com", "api.example.com", "cdn.example.com"))
            httpClient = mockClient
        }
        
        val ffetch = FFetch("https://test.com", context)
        
        assertTrue(ffetch.context.allowedHosts.contains("example.com"))
        assertTrue(ffetch.context.allowedHosts.contains("api.example.com"))
        assertTrue(ffetch.context.allowedHosts.contains("cdn.example.com"))
        assertTrue(ffetch.context.allowedHosts.contains("test.com"))
        assertEquals(4, ffetch.context.allowedHosts.size)
    }

    @Test
    fun `URL without hostname should handle allowed hosts gracefully`() {
        val context = FFetchContext().apply {
            allowedHosts.clear()
            httpClient = mockClient
        }
        
        // This might not be a valid scenario, but should not crash
        try {
            val ffetch = FFetch("https://", context)
            // If it doesn't throw, check that allowedHosts is handled gracefully
            assertNotNull(ffetch.context.allowedHosts)
        } catch (e: FFetchError.InvalidURL) {
            // This is acceptable for invalid URLs
            assertTrue(e.message!!.contains("https://"))
        }
    }

    @Test
    fun `Default context values should be reasonable`() {
        val context = FFetchContext()
        
        assertTrue(context.chunkSize > 0)
        assertTrue(context.maxConcurrency > 0)
        assertNotNull(context.httpClient)
        assertNotNull(context.htmlParser)
        assertNotNull(context.cacheConfig)
        assertNotNull(context.allowedHosts)
        assertFalse(context.cacheReload) // deprecated but should have a default
        assertNull(context.sheetName) // should be null by default
        assertNull(context.total) // should be null initially
    }
}