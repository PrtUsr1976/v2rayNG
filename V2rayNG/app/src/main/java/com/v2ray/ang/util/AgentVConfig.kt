package com.v2ray.ang.util

import android.content.ContentResolver
import android.net.Uri
import java.io.IOException

/**
 * Reads the agent_v key=value format and converts the supported fields to
 * subscription request headers.
 */
object AgentVConfig {
    private val headerNames = linkedMapOf(
        "user_agent" to "User-Agent",
        "x_hwid" to "X-HWID",
        "x_device_os" to "X-Device-OS",
        "x_ver_os" to "X-Ver-OS",
        "x_device_model" to "X-Device-Model",
    )

    /**
     * Parses agent_v content. Blank lines and lines starting with # or ; are ignored.
     * All supported fields are required so a partial device identity is never sent.
     */
    fun parse(content: String): Map<String, String> {
        val values = mutableMapOf<String, String>()

        content.removePrefix("\uFEFF").lineSequence().forEachIndexed { index, rawLine ->
            val line = rawLine.trim()
            if (line.isEmpty() || line.startsWith('#') || line.startsWith(';')) {
                return@forEachIndexed
            }

            val separator = line.indexOf('=')
            if (separator <= 0) {
                throw IllegalArgumentException("Invalid agent_v line ${index + 1}: expected key=value")
            }

            val key = line.substring(0, separator).trim().lowercase()
            val value = line.substring(separator + 1).trim()
            if (key in headerNames && value.isNotEmpty()) {
                values[key] = value
            }
        }

        val missing = headerNames.keys.filter { values[it].isNullOrBlank() }
        if (missing.isNotEmpty()) {
            throw IllegalArgumentException("Missing agent_v fields: ${missing.joinToString()}")
        }

        return headerNames.mapValues { (key, _) -> values.getValue(key) }
            .mapKeys { (key, _) -> headerNames.getValue(key) }
    }

    /** Reads and parses a persistable Storage Access Framework URI. */
    @Throws(IOException::class, IllegalArgumentException::class, SecurityException::class)
    fun read(contentResolver: ContentResolver, uriString: String): Map<String, String> {
        val uri = Uri.parse(uriString)
        val content = contentResolver.openInputStream(uri)?.bufferedReader(Charsets.UTF_8)?.use {
            it.readText()
        } ?: throw IOException("Unable to open agent_v")

        return parse(content)
    }
}
