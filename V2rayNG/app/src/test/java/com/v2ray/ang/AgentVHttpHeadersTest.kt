package com.v2ray.ang

import com.v2ray.ang.dto.UrlContentRequest
import com.v2ray.ang.util.AgentVConfig
import com.v2ray.ang.util.HttpUtil
import com.v2ray.ang.util.JsonUtil
import org.junit.Assert.assertEquals
import org.junit.Test
import java.net.ServerSocket
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

class AgentVHttpHeadersTest {
    @Test
    fun sendsAllAgentVHeadersInActualHttpRequest() {
        val server = ServerSocket(0)
        val executor = Executors.newSingleThreadExecutor()
        val receivedHeaders = executor.submit<Map<String, String>> {
            server.accept().use { socket ->
                val reader = socket.getInputStream().bufferedReader()
                reader.readLine() // request line
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
            val agentVHeaders = AgentVConfig.parse(
                """
                user_agent=Throne/1.1.4
                x_hwid=3b4f0a66-f4c4-499c-bc32-0787ae8d5d9b
                x_device_os=Windows
                x_ver_os=10.0.17763
                x_device_model=VirtualBox
                """.trimIndent()
            )

            val response = HttpUtil.getUrlContentWithUserAgent(
                UrlContentRequest(
                    url = "http://127.0.0.1:${server.localPort}/subscription",
                    requestHeaders = JsonUtil.toJson(agentVHeaders),
                    timeout = 5000
                )
            )
            val headers = receivedHeaders.get(5, TimeUnit.SECONDS)

            assertEquals("ok", response)
            assertEquals("Throne/1.1.4", headers["user-agent"])
            assertEquals("3b4f0a66-f4c4-499c-bc32-0787ae8d5d9b", headers["x-hwid"])
            assertEquals("Windows", headers["x-device-os"])
            assertEquals("10.0.17763", headers["x-ver-os"])
            assertEquals("VirtualBox", headers["x-device-model"])
        } finally {
            server.close()
            executor.shutdownNow()
        }
    }
}
