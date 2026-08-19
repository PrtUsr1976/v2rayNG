package com.v2ray.ang.util

import android.content.ContentResolver
import android.net.Uri
import java.io.IOException
import java.util.Locale

/**
 * Reads subscription header overrides from a selected hwid or agent_v file.
 */
object AgentVConfig {
    private val aliases = mapOf(
        "user-agent" to "User-Agent",
        "x-hwid" to "x-hwid",
        "x-device-os" to "x-device-os",
        "x-ver-os" to "x-ver-os",
        "x-device-model" to "x-device-model",
    )

    fun parse(content: String): Map<String, String> {
        val headers = linkedMapOf<String, Pair<String, String>>()
        content.removePrefix("\uFEFF").lineSequence().forEachIndexed { index, rawLine ->
            val line = rawLine.trim()
            if (line.isEmpty() || line.startsWith('#') || line.startsWith(';')) {
                return@forEachIndexed
            }

            val equalsIndex = line.indexOf('=')
            val whitespace = Regex("[ \\t]+").find(line)
            val separatorStart: Int
            val separatorEnd: Int
            if (equalsIndex > 0) {
                separatorStart = equalsIndex
                separatorEnd = equalsIndex + 1
            } else if (whitespace != null && whitespace.range.first > 0) {
                separatorStart = whitespace.range.first
                separatorEnd = whitespace.range.last + 1
            } else {
                throw IllegalArgumentException(
                    "Invalid header line ${index + 1}: expected key=value or key value"
                )
            }

            val rawKey = line.substring(0, separatorStart).trim()
            val value = line.substring(separatorEnd).trim()
            if (rawKey.isEmpty() || value.isEmpty()) {
                throw IllegalArgumentException("Invalid header line ${index + 1}: empty key or value")
            }
            val normalized = rawKey.replace('_', '-').lowercase(Locale.ROOT)
            val headerName = aliases[normalized] ?: rawKey.replace('_', '-')
            headers[normalized] = headerName to value
        }
        return headers.values.associateTo(linkedMapOf()) { it }
    }

    fun merge(
        standardHeaders: Map<String, String>,
        overrides: Map<String, String>
    ): Map<String, String> {
        val merged = linkedMapOf<String, Pair<String, String>>()
        (standardHeaders.asSequence() + overrides.asSequence()).forEach { (name, value) ->
            merged[name.lowercase(Locale.ROOT)] = name to value
        }
        return merged.values.associateTo(linkedMapOf()) { it }
    }

    @Throws(IOException::class, IllegalArgumentException::class, SecurityException::class)
    fun read(contentResolver: ContentResolver, uriString: String): Map<String, String> {
        val uri = Uri.parse(uriString)
        val content = contentResolver.openInputStream(uri)?.bufferedReader(Charsets.UTF_8)?.use {
            it.readText()
        } ?: throw IOException("Unable to open subscription header file")
        return parse(content)
    }
}
