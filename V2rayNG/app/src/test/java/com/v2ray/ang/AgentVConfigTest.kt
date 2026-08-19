package com.v2ray.ang

import com.v2ray.ang.util.AgentVConfig
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class AgentVConfigTest {
    @Test
    fun parsesEqualsWhitespaceTabsAliasesAndAdditionalHeaders() {
        val headers = AgentVConfig.parse(
            """
            user_agent=Happ/3.3.6/Windows/2607171516600
            X_HWID	fake-hwid
            x-device-os Windows
            accept_language = ru-RU
            X-Custom	value
            """.trimIndent()
        )

        assertEquals("Happ/3.3.6/Windows/2607171516600", headers["User-Agent"])
        assertEquals("fake-hwid", headers["x-hwid"])
        assertEquals("Windows", headers["x-device-os"])
        assertEquals("ru-RU", headers["accept-language"])
        assertEquals("value", headers["X-Custom"])
    }

    @Test
    fun ignoresCommentsAndUsesLastCaseInsensitiveDuplicate() {
        val headers = AgentVConfig.parse(
            "\uFEFF# generated\n" +
                "user_agent=first\n" +
                "; ignored\n" +
                "USER-AGENT second\n"
        )

        assertEquals(1, headers.size)
        assertEquals("second", headers["User-Agent"])
    }

    @Test
    fun permitsPartialFilesAndMergesOverridesCaseInsensitively() {
        val merged = AgentVConfig.merge(
            linkedMapOf("User-Agent" to "standard", "Accept" to "text/plain"),
            AgentVConfig.parse("user_agent custom\naccept application/json")
        )

        assertEquals(2, merged.size)
        assertEquals("custom", merged["User-Agent"])
        assertEquals("application/json", merged["accept"])
    }

    @Test
    fun rejectsMalformedLines() {
        assertThrows(IllegalArgumentException::class.java) {
            AgentVConfig.parse("malformed")
        }
    }
}
