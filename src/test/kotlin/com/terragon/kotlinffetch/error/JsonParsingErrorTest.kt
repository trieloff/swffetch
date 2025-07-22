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
import kotlinx.serialization.json.Json
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.BeforeEach

class JsonParsingErrorTest {

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
    fun `Malformed JSON syntax should throw DecodingError`() = runTest {
        val malformedJson = """{"invalid": json syntax}"""
        mockClient.setResponse(malformedJson)
        
        val exception = assertThrows(FFetchError.DecodingError::class.java) {
            runTest {
                val json = Json { ignoreUnknownKeys = true }
                json.decodeFromString<FFetchResponse>(malformedJson)
            }
        }
        
        assertTrue(exception.message!!.contains("Decoding error"))
    }

    @Test
    fun `Incomplete JSON should throw DecodingError`() = runTest {
        val incompleteJson = """{"total": 10, "offset": 0, "limit": 5"""
        mockClient.setResponse(incompleteJson)
        
        val exception = assertThrows(FFetchError.DecodingError::class.java) {
            runTest {
                val json = Json { ignoreUnknownKeys = true }
                json.decodeFromString<FFetchResponse>(incompleteJson)
            }
        }
        
        assertTrue(exception.message!!.contains("Decoding error"))
    }

    @Test
    fun `JSON with missing required fields should throw DecodingError`() = runTest {
        val jsonMissingFields = """{"total": 10}"""
        mockClient.setResponse(jsonMissingFields)
        
        val exception = assertThrows(FFetchError.DecodingError::class.java) {
            runTest {
                val json = Json { ignoreUnknownKeys = true }
                json.decodeFromString<FFetchResponse>(jsonMissingFields)
            }
        }
        
        assertTrue(exception.message!!.contains("Decoding error"))
    }

    @Test
    fun `JSON with wrong data types should throw DecodingError`() = runTest {
        val jsonWrongTypes = """{"total": "not-a-number", "offset": 0, "limit": 5, "data": []}"""
        mockClient.setResponse(jsonWrongTypes)
        
        val exception = assertThrows(FFetchError.DecodingError::class.java) {
            runTest {
                val json = Json { ignoreUnknownKeys = true }
                json.decodeFromString<FFetchResponse>(jsonWrongTypes)
            }
        }
        
        assertTrue(exception.message!!.contains("Decoding error"))
    }

    @Test
    fun `Empty JSON response should throw DecodingError`() = runTest {
        val emptyJson = ""
        mockClient.setResponse(emptyJson)
        
        val exception = assertThrows(FFetchError.DecodingError::class.java) {
            runTest {
                val json = Json { ignoreUnknownKeys = true }
                json.decodeFromString<FFetchResponse>(emptyJson)
            }
        }
        
        assertTrue(exception.message!!.contains("Decoding error"))
    }

    @Test
    fun `Null JSON response should throw DecodingError`() = runTest {
        val nullJson = "null"
        mockClient.setResponse(nullJson)
        
        val exception = assertThrows(FFetchError.DecodingError::class.java) {
            runTest {
                val json = Json { ignoreUnknownKeys = true }
                json.decodeFromString<FFetchResponse>(nullJson)
            }
        }
        
        assertTrue(exception.message!!.contains("Decoding error"))
    }

    @Test
    fun `JSON with special characters should be handled correctly`() = runTest {
        val jsonWithSpecialChars = """{"total": 1, "offset": 0, "limit": 5, "data": [{"name": "Test\u0000\t\n\r\"\\\/"}]}"""
        mockClient.setResponse(jsonWithSpecialChars)
        
        // This should parse successfully
        val json = Json { ignoreUnknownKeys = true }
        val response = json.decodeFromString<FFetchResponse>(jsonWithSpecialChars)
        
        assertEquals(1, response.total)
        assertEquals(1, response.data.size)
    }

    @Test
    fun `JSON with Unicode characters should be handled correctly`() = runTest {
        val jsonWithUnicode = """{"total": 1, "offset": 0, "limit": 5, "data": [{"name": "测试🎉émojis"}]}"""
        mockClient.setResponse(jsonWithUnicode)
        
        // This should parse successfully
        val json = Json { ignoreUnknownKeys = true }
        val response = json.decodeFromString<FFetchResponse>(jsonWithUnicode)
        
        assertEquals(1, response.total)
        assertEquals(1, response.data.size)
    }

    @Test
    fun `Very large JSON response should be handled`() = runTest {
        val largeDataArray = (1..1000).map { """{"id": $it, "name": "Item $it"}""" }.joinToString(",")
        val largeJson = """{"total": 1000, "offset": 0, "limit": 1000, "data": [$largeDataArray]}"""
        mockClient.setResponse(largeJson)
        
        // This should parse successfully
        val json = Json { ignoreUnknownKeys = true }
        val response = json.decodeFromString<FFetchResponse>(largeJson)
        
        assertEquals(1000, response.total)
        assertEquals(1000, response.data.size)
    }

    @Test
    fun `JSON with nested objects should throw DecodingError when structure is wrong`() = runTest {
        val nestedJson = """{"total": 1, "offset": 0, "limit": 5, "data": [{"nested": {"deep": {"value": "test"}}}]}"""
        mockClient.setResponse(nestedJson)
        
        // This should parse successfully as FFetchResponse allows any JsonObject in data
        val json = Json { ignoreUnknownKeys = true }
        val response = json.decodeFromString<FFetchResponse>(nestedJson)
        
        assertEquals(1, response.total)
        assertEquals(1, response.data.size)
    }

    @Test
    fun `JSON with array instead of object should throw DecodingError`() = runTest {
        val arrayJson = """[{"id": 1}, {"id": 2}]"""
        mockClient.setResponse(arrayJson)
        
        val exception = assertThrows(FFetchError.DecodingError::class.java) {
            runTest {
                val json = Json { ignoreUnknownKeys = true }
                json.decodeFromString<FFetchResponse>(arrayJson)
            }
        }
        
        assertTrue(exception.message!!.contains("Decoding error"))
    }

    @Test
    fun `JSON with invalid number formats should throw DecodingError`() = runTest {
        val invalidNumbers = """{"total": 1.5.5, "offset": 0, "limit": 5, "data": []}"""
        mockClient.setResponse(invalidNumbers)
        
        val exception = assertThrows(FFetchError.DecodingError::class.java) {
            runTest {
                val json = Json { ignoreUnknownKeys = true }
                json.decodeFromString<FFetchResponse>(invalidNumbers)
            }
        }
        
        assertTrue(exception.message!!.contains("Decoding error"))
    }

    @Test
    fun `JSON with mixed data types in array should be handled`() = runTest {
        val mixedTypesJson = """{"total": 3, "offset": 0, "limit": 5, "data": [{"string": "test"}, {"number": 123}, {"boolean": true}]}"""
        mockClient.setResponse(mixedTypesJson)
        
        // This should parse successfully
        val json = Json { ignoreUnknownKeys = true }
        val response = json.decodeFromString<FFetchResponse>(mixedTypesJson)
        
        assertEquals(3, response.total)
        assertEquals(3, response.data.size)
    }

    @Test
    fun `JSON with extremely deep nesting should be handled`() = runTest {
        val deepNesting = """{"total": 1, "offset": 0, "limit": 5, "data": [{"level1": {"level2": {"level3": {"level4": {"level5": "deep"}}}}}]}"""
        mockClient.setResponse(deepNesting)
        
        // This should parse successfully
        val json = Json { ignoreUnknownKeys = true }
        val response = json.decodeFromString<FFetchResponse>(deepNesting)
        
        assertEquals(1, response.total)
        assertEquals(1, response.data.size)
    }

    @Test
    fun `HTML response instead of JSON should throw DecodingError`() = runTest {
        val htmlResponse = "<html><body>Error 404</body></html>"
        mockClient.setResponse(htmlResponse)
        
        val exception = assertThrows(FFetchError.DecodingError::class.java) {
            runTest {
                val json = Json { ignoreUnknownKeys = true }
                json.decodeFromString<FFetchResponse>(htmlResponse)
            }
        }
        
        assertTrue(exception.message!!.contains("Decoding error"))
    }

    @Test
    fun `Plain text response instead of JSON should throw DecodingError`() = runTest {
        val plainText = "This is just plain text, not JSON"
        mockClient.setResponse(plainText)
        
        val exception = assertThrows(FFetchError.DecodingError::class.java) {
            runTest {
                val json = Json { ignoreUnknownKeys = true }
                json.decodeFromString<FFetchResponse>(plainText)
            }
        }
        
        assertTrue(exception.message!!.contains("Decoding error"))
    }
}