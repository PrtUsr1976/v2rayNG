package com.v2ray.ang

import com.v2ray.ang.util.SubscriptionVlessExporter
import org.junit.Assert.assertEquals
import org.junit.Test

class SubscriptionVlessExporterTest {
    @Test
    fun extractOriginalVlessLinksPreservesParametersAndSorts() {
        val first = "vless://0000@a.example:443?spx=&type=tcp#Beta"
        val second = "vless://ffff@z.example:443?type=tcp#Alpha"

        val result = SubscriptionVlessExporter.extractOriginalVlessLinks("$first\n$second\n$first\nss://ignored")

        assertEquals(listOf(second, first), result)
    }

    @Test
    fun extractOriginalVlessLinksSortsByDecodedDisplayName() {
        val beta = "vless://0000@example.com:443#Beta"
        val alpha = "vless://ffff@example.com:443#%D0%90%D0%BB%D1%8C%D1%84%D0%B0"

        val result = SubscriptionVlessExporter.extractOriginalVlessLinks("$beta\n$alpha")

        assertEquals(listOf(beta, alpha), result)
        assertEquals("Альфа", SubscriptionVlessExporter.getVlessSortName(alpha))
    }

    @Test
    fun getSafeFileNameReplacesInvalidCharacters() {
        assertEquals("work_home", SubscriptionVlessExporter.getSafeFileName(" work/home. "))
        assertEquals("subscription", SubscriptionVlessExporter.getSafeFileName(""))
    }
}
