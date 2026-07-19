package com.v2ray.ang

import com.v2ray.ang.util.SubscriptionListImporter
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SubscriptionListImporterTest {
    @Test
    fun createsOneGroupForEveryValidNonEmptyLine() {
        val result = SubscriptionListImporter.parse(
            """
            https://ent.xtls.win/sub/first
            https://sub.arza.top/sub/token
            https://subs.un1c4d3.ru/sub/token
            https://ent.xtls.win/sub/fourth
            """.trimIndent()
        )

        assertEquals(4, result.entries.size)
        assertEquals("xtls", result.entries[0].remarks)
        assertEquals("arza", result.entries[1].remarks)
        assertEquals("un1c4d3", result.entries[2].remarks)
        assertEquals("xtls-2", result.entries[3].remarks)
        assertEquals(0, result.skippedCount)
    }

    @Test
    fun avoidsExistingGroupNames() {
        val result = SubscriptionListImporter.parse(
            "https://ent.xtls.win/sub/token",
            existingRemarks = listOf("xtls", "xtls-2")
        )

        assertEquals("xtls-3", result.entries.single().remarks)
    }

    @Test
    fun ignoresBlankAndCommentLinesAndReportsInvalidUrls() {
        val result = SubscriptionListImporter.parse(
            """

            # comment
            ; comment
            not a url
            ftp://example.com/sub
            https://valid.example/sub
            """.trimIndent()
        )

        assertEquals(1, result.entries.size)
        assertEquals(2, result.skippedCount)
    }

    @Test
    fun marksHttpLinksAsInsecure() {
        val result = SubscriptionListImporter.parse(
            """
            http://plain.example/sub
            https://secure.example/sub
            """.trimIndent()
        )

        assertTrue(result.entries[0].allowInsecureUrl)
        assertFalse(result.entries[1].allowInsecureUrl)
    }
}
