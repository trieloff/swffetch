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
import com.terragon.kotlinffetch.mock.FailingMockClient
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.BeforeEach
import java.net.ConnectException
import java.net.SocketTimeoutException
import java.net.UnknownHostException
import javax.net.ssl.SSLException

class NetworkErrorTest {

    private lateinit var failingClient: FailingMockClient
    private lateinit var context: FFetchContext

    @BeforeEach
    fun setUp() {
        failingClient = FailingMockClient()
        context = FFetchContext().apply {
            httpClient = failingClient
        }
    }

    @Test
    fun `DNS resolution failure should throw NetworkError`() = runTest {
        failingClient.setFailureMode(FailingMockClient.FailureMode.DNS_FAILURE)
        
        val exception = assertThrows(FFetchError.NetworkError::class.java) {
            runTest {
                context.httpClient.fetch("https://nonexistent.example.com")
            }
        }
        
        assertTrue(exception.cause is UnknownHostException)
        assertTrue(exception.message!!.contains("Network error"))
    }

    @Test
    fun `Connection timeout should throw NetworkError`() = runTest {
        failingClient.setFailureMode(FailingMockClient.FailureMode.CONNECTION_TIMEOUT)
        
        val exception = assertThrows(FFetchError.NetworkError::class.java) {
            runTest {
                context.httpClient.fetch("https://example.com")
            }
        }
        
        assertTrue(exception.cause is SocketTimeoutException)
        assertTrue(exception.message!!.contains("Connection timed out"))
    }

    @Test
    fun `SSL handshake failure should throw NetworkError`() = runTest {
        failingClient.setFailureMode(FailingMockClient.FailureMode.SSL_ERROR)
        
        val exception = assertThrows(FFetchError.NetworkError::class.java) {
            runTest {
                context.httpClient.fetch("https://example.com")
            }
        }
        
        assertTrue(exception.cause is SSLException)
        assertTrue(exception.message!!.contains("SSL handshake failed"))
    }

    @Test
    fun `Connection refused should throw NetworkError`() = runTest {
        failingClient.setFailureMode(FailingMockClient.FailureMode.CONNECTION_REFUSED)
        
        val exception = assertThrows(FFetchError.NetworkError::class.java) {
            runTest {
                context.httpClient.fetch("https://example.com")
            }
        }
        
        assertTrue(exception.cause is ConnectException)
        assertTrue(exception.message!!.contains("Connection refused"))
    }

    @Test
    fun `Network interruption should throw NetworkError`() = runTest {
        failingClient.setFailureMode(FailingMockClient.FailureMode.NETWORK_INTERRUPTION)
        
        val exception = assertThrows(FFetchError.NetworkError::class.java) {
            runTest {
                context.httpClient.fetch("https://example.com")
            }
        }
        
        assertTrue(exception.cause is java.io.IOException)
        assertTrue(exception.message!!.contains("Network interrupted"))
    }

    @Test
    fun `HTTP 400 Bad Request should return error response`() = runTest {
        failingClient.setFailureMode(FailingMockClient.FailureMode.HTTP_400)
        
        val (content, response) = context.httpClient.fetch("https://example.com")
        
        assertEquals("Bad Request", content)
        assertEquals(400, response.status.value)
    }

    @Test
    fun `HTTP 401 Unauthorized should return error response`() = runTest {
        failingClient.setFailureMode(FailingMockClient.FailureMode.HTTP_401)
        
        val (content, response) = context.httpClient.fetch("https://example.com")
        
        assertEquals("Unauthorized", content)
        assertEquals(401, response.status.value)
    }

    @Test
    fun `HTTP 403 Forbidden should return error response`() = runTest {
        failingClient.setFailureMode(FailingMockClient.FailureMode.HTTP_403)
        
        val (content, response) = context.httpClient.fetch("https://example.com")
        
        assertEquals("Forbidden", content)
        assertEquals(403, response.status.value)
    }

    @Test
    fun `HTTP 404 Not Found should return error response`() = runTest {
        failingClient.setFailureMode(FailingMockClient.FailureMode.HTTP_404)
        
        val (content, response) = context.httpClient.fetch("https://example.com")
        
        assertEquals("Not Found", content)
        assertEquals(404, response.status.value)
    }

    @Test
    fun `HTTP 500 Internal Server Error should return error response`() = runTest {
        failingClient.setFailureMode(FailingMockClient.FailureMode.HTTP_500)
        
        val (content, response) = context.httpClient.fetch("https://example.com")
        
        assertEquals("Internal Server Error", content)
        assertEquals(500, response.status.value)
    }

    @Test
    fun `HTTP 502 Bad Gateway should return error response`() = runTest {
        failingClient.setFailureMode(FailingMockClient.FailureMode.HTTP_502)
        
        val (content, response) = context.httpClient.fetch("https://example.com")
        
        assertEquals("Bad Gateway", content)
        assertEquals(502, response.status.value)
    }

    @Test
    fun `HTTP 503 Service Unavailable should return error response`() = runTest {
        failingClient.setFailureMode(FailingMockClient.FailureMode.HTTP_503)
        
        val (content, response) = context.httpClient.fetch("https://example.com")
        
        assertEquals("Service Unavailable", content)
        assertEquals(503, response.status.value)
    }

    @Test
    fun `HTTP 504 Gateway Timeout should return error response`() = runTest {
        failingClient.setFailureMode(FailingMockClient.FailureMode.HTTP_504)
        
        val (content, response) = context.httpClient.fetch("https://example.com")
        
        assertEquals("Gateway Timeout", content)
        assertEquals(504, response.status.value)
    }

    @Test
    fun `Slow response should timeout and throw NetworkError`() = runTest {
        failingClient.setFailureMode(FailingMockClient.FailureMode.SLOW_RESPONSE)
        
        val exception = assertThrows(FFetchError.NetworkError::class.java) {
            runTest {
                context.httpClient.fetch("https://example.com")
            }
        }
        
        assertTrue(exception.cause is SocketTimeoutException)
        assertTrue(exception.message!!.contains("Read timed out"))
    }

    @Test
    fun `Multiple network errors should be handled consistently`() = runTest {
        val errorModes = listOf(
            FailingMockClient.FailureMode.DNS_FAILURE,
            FailingMockClient.FailureMode.CONNECTION_TIMEOUT,
            FailingMockClient.FailureMode.SSL_ERROR,
            FailingMockClient.FailureMode.CONNECTION_REFUSED,
            FailingMockClient.FailureMode.NETWORK_INTERRUPTION
        )

        errorModes.forEach { mode ->
            failingClient.reset()
            failingClient.setFailureMode(mode)
            
            val exception = assertThrows(FFetchError.NetworkError::class.java) {
                runTest {
                    context.httpClient.fetch("https://example.com")
                }
            }
            
            assertNotNull(exception.cause)
            assertTrue(exception.message!!.startsWith("Network error"))
        }
    }

    @Test
    fun `HTTP error status codes should preserve original status`() = runTest {
        val httpErrorModes = mapOf(
            FailingMockClient.FailureMode.HTTP_400 to 400,
            FailingMockClient.FailureMode.HTTP_401 to 401,
            FailingMockClient.FailureMode.HTTP_403 to 403,
            FailingMockClient.FailureMode.HTTP_404 to 404,
            FailingMockClient.FailureMode.HTTP_500 to 500,
            FailingMockClient.FailureMode.HTTP_502 to 502,
            FailingMockClient.FailureMode.HTTP_503 to 503,
            FailingMockClient.FailureMode.HTTP_504 to 504
        )

        httpErrorModes.forEach { (mode, expectedStatusCode) ->
            failingClient.reset()
            failingClient.setFailureMode(mode)
            
            val (_, response) = context.httpClient.fetch("https://example.com")
            assertEquals(expectedStatusCode, response.status.value)
        }
    }
}