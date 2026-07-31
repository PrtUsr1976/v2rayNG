package com.v2ray.ang

import com.v2ray.ang.util.SubscriptionVlessExporter
import org.junit.Assert.assertEquals
import org.junit.Test

class SubscriptionVlessExporterTest {
    @Test
    fun extractOriginalVlessLinksPreservesParametersAndSorts() {
        val first = "vless://id@b.example:443?spx=&type=tcp#B"
        val second = "vless://id@a.example:443?type=tcp#A"

        val result = SubscriptionVlessExporter.extractOriginalVlessLinks("$first\n$second\n$first\nss://ignored")

        assertEquals(listOf(second, first), result)
    }

    @Test
    fun getSafeFileNameReplacesInvalidCharacters() {
        assertEquals("work_home", SubscriptionVlessExporter.getSafeFileName(" work/home. "))
        assertEquals("subscription", SubscriptionVlessExporter.getSafeFileName(""))
    }
}
