package com.v2ray.ang.util

import java.net.URI

data class SubscriptionImportEntry(
    val remarks: String,
    val url: String,
    val allowInsecureUrl: Boolean,
)

data class SubscriptionImportParseResult(
    val entries: List<SubscriptionImportEntry>,
    val skippedCount: Int,
)

object SubscriptionListImporter {
    /**
     * Parses one HTTP(S) subscription URL per line. Blank lines and comment
     * lines beginning with # or ; are ignored and are not counted as errors.
     */
    fun parse(content: String, existingRemarks: Collection<String> = emptyList()): SubscriptionImportParseResult {
        val entries = mutableListOf<SubscriptionImportEntry>()
        val usedRemarks = existingRemarks.mapTo(mutableSetOf()) { it.trim() }
        var skippedCount = 0

        content.removePrefix("\uFEFF").lineSequence().forEach { rawLine ->
            val line = rawLine.trim()
            if (line.isEmpty() || line.startsWith('#') || line.startsWith(';')) {
                return@forEach
            }

            val uri = runCatching { URI(line) }.getOrNull()
            val scheme = uri?.scheme?.lowercase()
            val host = uri?.host?.removePrefix("www.")
            if (scheme !in setOf("http", "https") || host.isNullOrBlank()) {
                skippedCount++
                return@forEach
            }

            entries += SubscriptionImportEntry(
                remarks = uniqueRemarks(primaryDomain(host), usedRemarks),
                url = line,
                allowInsecureUrl = scheme == "http",
            )
        }

        return SubscriptionImportParseResult(entries, skippedCount)
    }

    private fun primaryDomain(host: String): String {
        val labels = host.split('.').filter { it.isNotBlank() }
        return if (labels.size >= 2) labels[labels.lastIndex - 1] else host
    }

    private fun uniqueRemarks(base: String, usedRemarks: MutableSet<String>): String {
        if (usedRemarks.add(base)) return base

        var index = 2
        while (!usedRemarks.add("$base-$index")) {
            index++
        }
        return "$base-$index"
    }
}
