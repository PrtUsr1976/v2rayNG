package com.v2ray.ang

import com.v2ray.ang.dto.UrlContentRequest
import com.v2ray.ang.util.AgentVConfig
import com.v2ray.ang.util.HttpUtil
import com.v2ray.ang.util.JsonUtil
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test
import java.io.ByteArrayOutputStream
import java.net.ServerSocket
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.zip.GZIPOutputStream

class AgentVHttpHeadersTest {
    @Test
    fun sendsExactHappUserAgentAndAllSelectedFileHeaders() {
        val server = ServerSocket(0)
        val executor = Executors.newSingleThreadExecutor()
        val receivedHeaders = executor.submit<Map<String, String>> {
            server.accept().use { socket ->
                val reader = socket.getInputStream().bufferedReader()
                reader.readLine()
                val headers = buildMap {
                    while (true) {
                        val line = reader.readLine() ?: break
                        if (line.isEmpty()) break
                        val separator = line.indexOf(':')
                        if (separator > 0) {
                            put(
                                line.substring(0, separator).trim().lowercase(),
                                line.substring(separator + 1).trim()
                            )
                        }
                    }
                }
                socket.getOutputStream().write(
                    "HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nok"
                        .toByteArray()
                )
                socket.getOutputStream().flush()
                headers
            }
        }

        try {
            val fileHeaders = AgentVConfig.parse(
                """
                user_agent	Happ/3.3.6/Windows/2607171516600
                x_hwid=fake-hwid
                accept-language ru-RU
                """.trimIndent()
            )
            val response = HttpUtil.getUrlContentWithUserAgent(
                UrlContentRequest(
                    url = "http://127.0.0.1:${server.localPort}/subscription?private=value",
                    userAgent = "subscription-default",
                    requestHeaders = JsonUtil.toJson(fileHeaders),
                    timeout = 5000
                )
            )
            val headers = receivedHeaders.get(5, TimeUnit.SECONDS)

            assertEquals("ok", response)
            assertEquals("Happ/3.3.6/Windows/2607171516600", headers["user-agent"])
            assertEquals("fake-hwid", headers["x-hwid"])
            assertEquals("ru-RU", headers["accept-language"])
        } finally {
            server.close()
            executor.shutdownNow()
        }
    }

    @Test
    fun decompressesExplicitGzipResponse() {
        val compressed = ByteArrayOutputStream().also { output ->
            GZIPOutputStream(output).use { it.write("decoded".toByteArray()) }
        }.toByteArray()
        val server = ServerSocket(0)
        val executor = Executors.newSingleThreadExecutor()
        executor.submit {
            server.accept().use { socket ->
                val reader = socket.getInputStream().bufferedReader()
                while (!reader.readLine().isNullOrEmpty()) {
                    // Consume the request headers before writing the response.
                }
                socket.getOutputStream().write(
                    "HTTP/1.1 200 OK\r\nContent-Encoding: gzip\r\nContent-Length: ${compressed.size}\r\nConnection: close\r\n\r\n"
                        .toByteArray()
                )
                socket.getOutputStream().write(compressed)
                socket.getOutputStream().flush()
            }
        }

        try {
            val response = HttpUtil.getUrlContentWithUserAgent(
                UrlContentRequest(
                    url = "http://127.0.0.1:${server.localPort}/gzip",
                    requestHeaders = JsonUtil.toJson(mapOf("Accept-Encoding" to "gzip")),
                    timeout = 5000
                )
            )
            assertEquals("decoded", response)
        } finally {
            server.close()
            executor.shutdownNow()
        }
    }

    @Test
    fun safeLoggingHelpersRemoveUrlSecretsAndMaskHeaders() {
        val safe = HttpUtil.safeUrl("https://user:pass@example.test:8443/path?token=secret")
        val masked = HttpUtil.maskHeaders(
            mapOf(
                "Authorization" to "private",
                "Cookie" to "private",
                "X-Api-Key" to "private",
                "X-Token" to "private",
                "X-Secret-Value" to "private",
                "Accept" to "text/plain"
            )
        )

        assertEquals("https://example.test:8443", safe)
        assertFalse(safe.contains("user"))
        assertFalse(safe.contains("token"))
        assertEquals("***", masked["Authorization"])
        assertEquals("***", masked["Cookie"])
        assertEquals("***", masked["X-Api-Key"])
        assertEquals("***", masked["X-Token"])
        assertEquals("***", masked["X-Secret-Value"])
        assertEquals("text/plain", masked["Accept"])
    }
}
