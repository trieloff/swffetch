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

package com.terragon.kotlinffetch.mock

import com.terragon.kotlinffetch.FFetchHTTPClient
import com.terragon.kotlinffetch.FFetchCacheConfig
import com.terragon.kotlinffetch.FFetchError
import io.ktor.client.statement.*
import io.ktor.http.*
import io.ktor.utils.io.*
import kotlinx.coroutines.delay
import java.net.ConnectException
import java.net.SocketTimeoutException
import java.net.UnknownHostException
import javax.net.ssl.SSLException

class FailingMockClient : FFetchHTTPClient {
    
    enum class FailureMode {
        DNS_FAILURE,
        CONNECTION_TIMEOUT,
        SSL_ERROR,
        HTTP_400,
        HTTP_401,
        HTTP_403,
        HTTP_404,
        HTTP_500,
        HTTP_502,
        HTTP_503,
        HTTP_504,
        NETWORK_INTERRUPTION,
        SLOW_RESPONSE,
        CONNECTION_REFUSED
    }
    
    private var failureMode: FailureMode? = null
    private var delayMs: Long = 0
    private var shouldFail: Boolean = false
    private var responseContent: String = ""
    private var statusCode: HttpStatusCode = HttpStatusCode.OK
    
    fun setFailureMode(mode: FailureMode) {
        this.failureMode = mode
        this.shouldFail = true
    }
    
    fun setDelay(delayMs: Long) {
        this.delayMs = delayMs
    }
    
    fun setSuccessResponse(content: String, status: HttpStatusCode = HttpStatusCode.OK) {
        this.responseContent = content
        this.statusCode = status
        this.shouldFail = false
    }
    
    fun reset() {
        this.failureMode = null
        this.delayMs = 0
        this.shouldFail = false
        this.responseContent = ""
        this.statusCode = HttpStatusCode.OK
    }
    
    override suspend fun fetch(url: String, cacheConfig: FFetchCacheConfig): Pair<String, HttpResponse> {
        if (delayMs > 0) {
            delay(delayMs)
        }
        
        if (shouldFail && failureMode != null) {
            when (failureMode) {
                FailureMode.DNS_FAILURE -> throw UnknownHostException("Host not found")
                FailureMode.CONNECTION_TIMEOUT -> throw SocketTimeoutException("Connection timed out")
                FailureMode.SSL_ERROR -> throw SSLException("SSL handshake failed")
                FailureMode.CONNECTION_REFUSED -> throw ConnectException("Connection refused")
                FailureMode.NETWORK_INTERRUPTION -> throw java.io.IOException("Network interrupted")
                FailureMode.SLOW_RESPONSE -> {
                    delay(30000) // 30 second delay
                    throw SocketTimeoutException("Read timed out")
                }
                FailureMode.HTTP_400 -> return createErrorResponse(HttpStatusCode.BadRequest, "Bad Request")
                FailureMode.HTTP_401 -> return createErrorResponse(HttpStatusCode.Unauthorized, "Unauthorized")
                FailureMode.HTTP_403 -> return createErrorResponse(HttpStatusCode.Forbidden, "Forbidden")
                FailureMode.HTTP_404 -> return createErrorResponse(HttpStatusCode.NotFound, "Not Found")
                FailureMode.HTTP_500 -> return createErrorResponse(HttpStatusCode.InternalServerError, "Internal Server Error")
                FailureMode.HTTP_502 -> return createErrorResponse(HttpStatusCode.BadGateway, "Bad Gateway")
                FailureMode.HTTP_503 -> return createErrorResponse(HttpStatusCode.ServiceUnavailable, "Service Unavailable")
                FailureMode.HTTP_504 -> return createErrorResponse(HttpStatusCode.GatewayTimeout, "Gateway Timeout")
            }
        }
        
        return createSuccessResponse(responseContent)
    }
    
    private fun createErrorResponse(status: HttpStatusCode, message: String): Pair<String, HttpResponse> {
        val response = object : HttpResponse() {
            override val call: io.ktor.client.call.HttpClientCall
                get() = TODO("Not implemented for mock")
            override val content: ByteReadChannel
                get() = TODO("Not implemented for mock")
            override val headers: Headers = Headers.Empty
            override val requestTime: io.ktor.util.date.GMTDate
                get() = TODO("Not implemented for mock")
            override val responseTime: io.ktor.util.date.GMTDate
                get() = TODO("Not implemented for mock")
            override val status: HttpStatusCode = status
            override val version: HttpProtocolVersion = HttpProtocolVersion.HTTP_1_1
        }
        return Pair(message, response)
    }
    
    private fun createSuccessResponse(content: String): Pair<String, HttpResponse> {
        val response = object : HttpResponse() {
            override val call: io.ktor.client.call.HttpClientCall
                get() = TODO("Not implemented for mock")
            override val content: ByteReadChannel
                get() = TODO("Not implemented for mock")
            override val headers: Headers = Headers.Empty
            override val requestTime: io.ktor.util.date.GMTDate
                get() = TODO("Not implemented for mock")
            override val responseTime: io.ktor.util.date.GMTDate
                get() = TODO("Not implemented for mock")
            override val status: HttpStatusCode = statusCode
            override val version: HttpProtocolVersion = HttpProtocolVersion.HTTP_1_1
        }
        return Pair(content, response)
    }
}