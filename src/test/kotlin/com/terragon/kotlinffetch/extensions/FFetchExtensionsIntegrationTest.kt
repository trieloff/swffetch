package com.terragon.kotlinffetch.extensions

import com.terragon.kotlinffetch.FFetch
import com.terragon.kotlinffetch.FFetchContext
import com.terragon.kotlinffetch.FFetchEntry
import com.terragon.kotlinffetch.TestDataGenerator
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.asFlow
import kotlinx.coroutines.flow.toList
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.Test
import java.net.URL
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * Integration tests that exercise extension functions directly on FFetch instances
 * These tests ensure that the actual extension functions are covered in code coverage
 */
class FFetchExtensionsIntegrationTest {
    
    private fun createTestFFetch(entries: List<FFetchEntry>): FFetch {
        return object : FFetch(URL("https://integration.test.com"), FFetchContext()) {
            override suspend fun createFlow(): Flow<FFetchEntry> = entries.asFlow()
        }
    }
    
    // ========== DIRECT EXTENSION FUNCTION CALLS ==========
    
    @Test
    fun testFFetchAllExtension() = runTest {
        val entries = TestDataGenerator.createFFetchEntries(15, "ffetch_all")
        val ffetch = createTestFFetch(entries)
        
        val result = ffetch.all()
        assertEquals(15, result.size)
        assertEquals("ffetch_all_1", result.first()["id"])
        assertEquals("ffetch_all_15", result.last()["id"])
    }
    
    @Test
    fun testFFetchFirstExtension() = runTest {
        val entries = TestDataGenerator.createFFetchEntries(8, "ffetch_first")
        val ffetch = createTestFFetch(entries)
        
        val result = ffetch.first()
        assertEquals("ffetch_first_1", result["id"])
        assertEquals("Title 1", result["title"])
    }
    
    @Test
    fun testFFetchCountExtension() = runTest {
        val entries = TestDataGenerator.createFFetchEntries(25, "ffetch_count")
        val ffetch = createTestFFetch(entries)
        
        val result = ffetch.count()
        assertEquals(25, result)
    }
    
    @Test
    fun testFFetchMapExtension() = runTest {
        val entries = TestDataGenerator.createFFetchEntries(5, "ffetch_map")
        val ffetch = createTestFFetch(entries)
        
        val result = ffetch.map { entry ->
            "MAPPED_${entry["title"]}"
        }.toList()
        
        assertEquals(5, result.size)
        assertEquals("MAPPED_Title 1", result[0])
        assertEquals("MAPPED_Title 5", result[4])
    }
    
    @Test
    fun testFFetchFilterExtension() = runTest {
        val entries = TestDataGenerator.createFFetchEntries(20, "ffetch_filter")
        val ffetch = createTestFFetch(entries)
        
        val result = ffetch.filter { entry ->
            val index = entry["index"] as Int
            index % 2 == 0
        }.toList()
        
        assertEquals(10, result.size)
        assertTrue(result.all { (it["index"] as Int) % 2 == 0 })
    }
    
    @Test
    fun testFFetchLimitExtension() = runTest {
        val entries = TestDataGenerator.createFFetchEntries(50, "ffetch_limit")
        val ffetch = createTestFFetch(entries)
        
        val result = ffetch.limit(7).toList()
        assertEquals(7, result.size)
        assertEquals("ffetch_limit_1", result[0]["id"])
        assertEquals("ffetch_limit_7", result[6]["id"])
    }
    
    @Test
    fun testFFetchSkipExtension() = runTest {
        val entries = TestDataGenerator.createFFetchEntries(15, "ffetch_skip")
        val ffetch = createTestFFetch(entries)
        
        val result = ffetch.skip(10).toList()
        assertEquals(5, result.size)
        assertEquals("ffetch_skip_11", result[0]["id"])
        assertEquals("ffetch_skip_15", result[4]["id"])
    }
    
    @Test
    fun testFFetchSliceExtension() = runTest {
        val entries = TestDataGenerator.createFFetchEntries(20, "ffetch_slice")
        val ffetch = createTestFFetch(entries)
        
        val result = ffetch.slice(5..9).toList()
        assertEquals(5, result.size)
        assertEquals("ffetch_slice_6", result[0]["id"])
        assertEquals("ffetch_slice_10", result[4]["id"])
    }
    
    // ========== CHAINED EXTENSION OPERATIONS ==========
    
    @Test
    fun testChainedFFetchExtensions() = runTest {
        val entries = TestDataGenerator.createFFetchEntries(100, "chained")
        val ffetch = createTestFFetch(entries)
        
        val result = ffetch
            .filter { (it["index"] as Int) > 50 }
            .map { "PROCESSED_${it["id"]}" }
            .skip(10)
            .limit(5)
            .toList()
        
        assertEquals(5, result.size)
        assertEquals("PROCESSED_chained_61", result[0]) // 51-60 filtered, 10 skipped = start at 61
        assertEquals("PROCESSED_chained_65", result[4])
    }
    
    @Test
    fun testComplexFFetchChain() = runTest {
        val entries = TestDataGenerator.createFFetchEntries(200, "complex")
        val ffetch = createTestFFetch(entries)
        
        // Filter even indices, map to uppercase titles, skip first 5, take 10
        val titles = ffetch
            .filter { entry -> (entry["index"] as Int) % 2 == 0 }
            .map { entry -> entry["title"].toString().uppercase() }
            .skip(5)
            .limit(10)
            .toList()
        
        assertEquals(10, titles.size)
        assertTrue(titles.all { it.startsWith("TITLE") })
        assertEquals("TITLE 12", titles[0]) // 2,4,6,8,10 skipped, starts at 12
    }
    
    @Test
    fun testFFetchExtensionWithSliceAndTransform() = runTest {
        val entries = TestDataGenerator.createFFetchEntries(30, "slice_transform")
        val ffetch = createTestFFetch(entries)
        
        val result = ffetch
            .slice(10..19) // Take entries 11-20
            .map { entry ->
                mapOf(
                    "original_id" to entry["id"],
                    "transformed_title" to "TRANSFORMED_${entry["title"]}",
                    "index_doubled" to (entry["index"] as Int) * 2
                )
            }
            .toList()
        
        assertEquals(10, result.size)
        assertEquals("slice_transform_11", result[0]["original_id"])
        assertEquals("TRANSFORMED_Title 11", result[0]["transformed_title"])
        assertEquals(22, result[0]["index_doubled"]) // 11 * 2
    }
    
    // ========== EDGE CASE TESTING ==========
    
    @Test
    fun testFFetchExtensionsWithEmptyData() = runTest {
        val ffetch = createTestFFetch(emptyList())
        
        assertEquals(0, ffetch.count())
        assertTrue(ffetch.all().isEmpty())
        assertTrue(ffetch.filter { true }.toList().isEmpty())
        assertTrue(ffetch.map { it["id"] }.toList().isEmpty())
        assertTrue(ffetch.limit(10).toList().isEmpty())
        assertTrue(ffetch.skip(5).toList().isEmpty())
        assertTrue(ffetch.slice(0..10).toList().isEmpty())
    }
    
    @Test
    fun testFFetchExtensionsWithSingleEntry() = runTest {
        val entry = TestDataGenerator.createFFetchEntry("single", "Single Title", "Single Description")
        val ffetch = createTestFFetch(listOf(entry))
        
        assertEquals(1, ffetch.count())
        assertEquals(1, ffetch.all().size)
        assertEquals("single", ffetch.first()["id"])
        assertEquals(1, ffetch.filter { true }.toList().size)
        assertEquals(1, ffetch.map { it["title"] }.toList().size)
        assertEquals(1, ffetch.limit(10).toList().size)
        assertEquals(0, ffetch.skip(1).toList().size)
        assertEquals(1, ffetch.slice(0..0).toList().size)
    }
    
    @Test
    fun testFFetchExtensionsWithNullableData() = runTest {
        val entries = TestDataGenerator.createEntriesWithNulls(20)
        val ffetch = createTestFFetch(entries)
        
        val allEntries = ffetch.all()
        assertEquals(20, allEntries.size)
        
        val nonEmptyTitles = ffetch.filter { entry ->
            entry["title"].toString().isNotEmpty()
        }.toList()
        assertTrue(nonEmptyTitles.size < 20) // Some should be filtered out
        
        val safeValues = ffetch.map { entry ->
            entry["optional_field"] ?: "DEFAULT"
        }.toList()
        assertEquals(20, safeValues.size)
        assertTrue(safeValues.contains("DEFAULT"))
    }
    
    // ========== TYPE TRANSFORMATION TESTS ==========
    
    @Test
    fun testFFetchExtensionTypeTransformation() = runTest {
        val productEntries = TestDataGenerator.createProductEntries(10)
        val ffetch = createTestFFetch(productEntries)
        
        data class Product(val id: String, val name: String, val price: Double, val category: String)
        
        val products = ffetch
            .filter { entry -> (entry["price"] as Double) > 30.0 }
            .map { entry ->
                Product(
                    id = entry["id"].toString(),
                    name = entry["name"].toString(),
                    price = entry["price"] as Double,
                    category = entry["category"].toString()
                )
            }
            .toList()
        
        assertTrue(products.isNotEmpty())
        assertTrue(products.all { it.price > 30.0 })
        assertEquals("product_4", products[0].id) // First product with price > 30 (40.0)
    }
    
    @Test
    fun testFFetchExtensionComplexAggregation() = runTest {
        val entries = TestDataGenerator.createFFetchEntries(100, "aggregation")
        val ffetch = createTestFFetch(entries)
        
        // Count entries by category using extension functions
        val categoryData = ffetch
            .map { entry -> entry["category"].toString() }
            .toList()
            .groupBy { it }
            .mapValues { it.value.size }
        
        assertTrue(categoryData.containsKey("even"))
        assertTrue(categoryData.containsKey("odd"))
        assertEquals(50, categoryData["even"])
        assertEquals(50, categoryData["odd"])
    }
}