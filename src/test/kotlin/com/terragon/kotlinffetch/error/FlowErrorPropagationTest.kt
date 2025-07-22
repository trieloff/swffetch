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
import com.terragon.kotlinffetch.extensions.*
import com.terragon.kotlinffetch.mock.MockFFetchHTTPClient
import com.terragon.kotlinffetch.mock.FailingMockClient
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.CancellationException
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.BeforeEach

class FlowErrorPropagationTest {

    private lateinit var mockClient: MockFFetchHTTPClient
    private lateinit var failingClient: FailingMockClient
    private lateinit var context: FFetchContext

    @BeforeEach
    fun setUp() {
        mockClient = MockFFetchHTTPClient()
        failingClient = FailingMockClient()
        context = FFetchContext().apply {
            httpClient = mockClient
        }
    }

    @Test
    fun `Map transformation should propagate errors from upstream`() = runTest {
        context.httpClient = failingClient
        failingClient.setFailureMode(FailingMockClient.FailureMode.DNS_FAILURE)
        
        val ffetch = FFetch("https://example.com", context)
        val transformedFlow = ffetch.map { entry -> entry["id"]?.toString() ?: "unknown" }
        
        val exception = assertThrows(FFetchError.NetworkError::class.java) {
            runTest {
                transformedFlow.collect { /* consume */ }
            }
        }
        
        assertTrue(exception.message!!.contains("Network error"))
    }

    @Test
    fun `Map transformation should handle exceptions in transform function`() = runTest {
        val validJson = """{"total": 2, "offset": 0, "limit": 5, "data": [{"id": "1"}, {"id": "2"}]}"""
        mockClient.setResponse(validJson)
        
        val ffetch = FFetch("https://example.com", context)
        val transformedFlow = ffetch.map { entry -> 
            throw RuntimeException("Transform failed")
        }
        
        val exception = assertThrows(RuntimeException::class.java) {
            runTest {
                transformedFlow.collect { /* consume */ }
            }
        }
        
        assertEquals("Transform failed", exception.message)
    }

    @Test
    fun `Filter operation should propagate upstream errors`() = runTest {
        context.httpClient = failingClient
        failingClient.setFailureMode(FailingMockClient.FailureMode.HTTP_500)
        
        val ffetch = FFetch("https://example.com", context)
        val filteredFlow = ffetch.filter { entry -> entry["id"] != null }
        
        // Should not throw on filter creation, but on collection
        val (content, response) = context.httpClient.fetch("https://example.com")
        assertEquals(500, response.status.value)
    }

    @Test
    fun `Filter operation should handle exceptions in predicate function`() = runTest {
        val validJson = """{"total": 2, "offset": 0, "limit": 5, "data": [{"id": "1"}, {"id": "2"}]}"""
        mockClient.setResponse(validJson)
        
        val ffetch = FFetch("https://example.com", context)
        val filteredFlow = ffetch.filter { entry -> 
            throw IllegalArgumentException("Predicate failed")
        }
        
        val exception = assertThrows(IllegalArgumentException::class.java) {
            runTest {
                filteredFlow.asFlow().collect { /* consume */ }
            }
        }
        
        assertEquals("Predicate failed", exception.message)
    }

    @Test
    fun `Collection operations should propagate upstream errors`() = runTest {
        context.httpClient = failingClient
        failingClient.setFailureMode(FailingMockClient.FailureMode.NETWORK_INTERRUPTION)
        
        val ffetch = FFetch("https://example.com", context)
        
        val exception = assertThrows(FFetchError.NetworkError::class.java) {
            runTest {
                ffetch.all()
            }
        }
        
        assertTrue(exception.message!!.contains("Network interrupted"))
    }

    @Test
    fun `First operation should propagate upstream errors`() = runTest {
        context.httpClient = failingClient
        failingClient.setFailureMode(FailingMockClient.FailureMode.CONNECTION_TIMEOUT)
        
        val ffetch = FFetch("https://example.com", context)
        
        val exception = assertThrows(FFetchError.NetworkError::class.java) {
            runTest {
                ffetch.first()
            }
        }
        
        assertTrue(exception.message!!.contains("Connection timed out"))
    }

    @Test
    fun `Count operation should propagate upstream errors`() = runTest {
        context.httpClient = failingClient
        failingClient.setFailureMode(FailingMockClient.FailureMode.SSL_ERROR)
        
        val ffetch = FFetch("https://example.com", context)
        
        val exception = assertThrows(FFetchError.NetworkError::class.java) {
            runTest {
                ffetch.count()
            }
        }
        
        assertTrue(exception.message!!.contains("SSL handshake failed"))
    }

    @Test
    fun `Partial failure scenario should handle some success some failure`() = runTest {
        val validJson = """{"total": 3, "offset": 0, "limit": 5, "data": [{"id": "1"}, {"id": "2"}, {"id": "3"}]}"""
        mockClient.setResponse(validJson)
        
        val ffetch = FFetch("https://example.com", context)
        val transformedFlow = ffetch.map { entry -> 
            val id = entry["id"]?.toString()
            if (id == "2") {
                throw RuntimeException("Failed to process item 2")
            }
            "Processed: $id"
        }
        
        val exception = assertThrows(RuntimeException::class.java) {
            runTest {
                transformedFlow.collect { /* consume */ }
            }
        }
        
        assertEquals("Failed to process item 2", exception.message)
    }

    @Test
    fun `Error recovery with catch should work`() = runTest {
        val validJson = """{"total": 2, "offset": 0, "limit": 5, "data": [{"id": "1"}, {"id": "2"}]}"""
        mockClient.setResponse(validJson)
        
        val ffetch = FFetch("https://example.com", context)
        val transformedFlow = ffetch.map { entry -> 
            val id = entry["id"]?.toString()
            if (id == "2") {
                throw RuntimeException("Transform error")
            }
            "Success: $id"
        }.catch { emit("Error handled") }
        
        val results = mutableListOf<String>()
        transformedFlow.collect { result ->
            results.add(result)
        }
        
        assertEquals(2, results.size)
        assertEquals("Success: 1", results[0])
        assertEquals("Error handled", results[1])
    }

    @Test
    fun `Cancellation should be handled properly`() = runTest {
        val validJson = """{"total": 100, "offset": 0, "limit": 100, "data": [${(1..100).map { """{"id": "$it"}""" }.joinToString(",")}]}"""
        mockClient.setResponse(validJson)
        
        val ffetch = FFetch("https://example.com", context)
        val transformedFlow = ffetch.map { entry -> 
            val id = entry["id"]?.toString()
            if (id == "5") {
                throw CancellationException("Processing cancelled")
            }
            "Processed: $id"
        }
        
        val exception = assertThrows(CancellationException::class.java) {
            runTest {
                transformedFlow.collect { /* consume */ }
            }
        }
        
        assertEquals("Processing cancelled", exception.message)
    }

    @Test
    fun `Multiple transformation layers should propagate errors correctly`() = runTest {
        val validJson = """{"total": 3, "offset": 0, "limit": 5, "data": [{"id": "1"}, {"id": "2"}, {"id": "3"}]}"""
        mockClient.setResponse(validJson)
        
        val ffetch = FFetch("https://example.com", context)
        val transformedFlow = ffetch
            .map { entry -> entry["id"]?.toString() ?: "unknown" }
            .map { id -> 
                if (id == "2") throw IllegalStateException("Second transform failed")
                "Transformed: $id"
            }
            .filter { result -> 
                if (result.contains("3")) throw IllegalArgumentException("Filter failed")
                true
            }
        
        val exception = assertThrows(IllegalStateException::class.java) {
            runTest {
                transformedFlow.collect { /* consume */ }
            }
        }
        
        assertEquals("Second transform failed", exception.message)
    }

    @Test
    fun `Exception during Flow processing should preserve stack trace`() = runTest {
        val validJson = """{"total": 1, "offset": 0, "limit": 5, "data": [{"id": "1"}]}"""
        mockClient.setResponse(validJson)
        
        val ffetch = FFetch("https://example.com", context)
        val transformedFlow = ffetch.map { entry -> 
            throw RuntimeException("Detailed error with stack trace")
        }
        
        val exception = assertThrows(RuntimeException::class.java) {
            runTest {
                transformedFlow.collect { /* consume */ }
            }
        }
        
        assertEquals("Detailed error with stack trace", exception.message)
        assertNotNull(exception.stackTrace)
        assertTrue(exception.stackTrace.isNotEmpty())
    }

    @Test
    fun `Limit operation should handle errors before limit is reached`() = runTest {
        val validJson = """{"total": 5, "offset": 0, "limit": 5, "data": [{"id": "1"}, {"id": "2"}, {"id": "3"}, {"id": "4"}, {"id": "5"}]}"""
        mockClient.setResponse(validJson)
        
        val ffetch = FFetch("https://example.com", context)
        val limitedFlow = ffetch
            .map { entry -> 
                val id = entry["id"]?.toString()
                if (id == "2") throw RuntimeException("Error before limit")
                "Processed: $id"
            }
            .limit(3)
        
        val exception = assertThrows(RuntimeException::class.java) {
            runTest {
                limitedFlow.collect { /* consume */ }
            }
        }
        
        assertEquals("Error before limit", exception.message)
    }

    @Test
    fun `Skip operation should handle errors in skipped elements`() = runTest {
        val validJson = """{"total": 5, "offset": 0, "limit": 5, "data": [{"id": "1"}, {"id": "2"}, {"id": "3"}, {"id": "4"}, {"id": "5"}]}"""
        mockClient.setResponse(validJson)
        
        val ffetch = FFetch("https://example.com", context)
        val skippedFlow = ffetch
            .map { entry -> 
                val id = entry["id"]?.toString()
                if (id == "2") throw RuntimeException("Error in skipped element")
                "Processed: $id"
            }
            .skip(2)
        
        val exception = assertThrows(RuntimeException::class.java) {
            runTest {
                skippedFlow.collect { /* consume */ }
            }
        }
        
        assertEquals("Error in skipped element", exception.message)
    }
}