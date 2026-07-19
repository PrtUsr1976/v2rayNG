package com.v2ray.ang

import com.v2ray.ang.util.AgentVConfig
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class AgentVConfigTest {
    @Test
    fun parsesSupportedFields() {
        val headers = AgentVConfig.parse(
            """
            user_agent=Throne/1.1.4
            x_hwid=3b4f0a66-f4c4-499c-bc32-0787ae8d5d9b
            x_device_os=Windows
            x_ver_os=10.0.17763
            x_device_model=VirtualBox
            """.trimIndent()
        )

        assertEquals("Throne/1.1.4", headers["User-Agent"])
        assertEquals("3b4f0a66-f4c4-499c-bc32-0787ae8d5d9b", headers["X-HWID"])
        assertEquals("Windows", headers["X-Device-OS"])
        assertEquals("10.0.17763", headers["X-Ver-OS"])
        assertEquals("VirtualBox", headers["X-Device-Model"])
    }

    @Test
    fun supportsBomWhitespaceCommentsAndEqualsInValues() {
        val headers = AgentVConfig.parse(
            "\uFEFF # generated\n" +
                " USER_AGENT = Throne/1.1.4=custom \n" +
                "; ignored\n" +
                "x_hwid = id\n" +
                "x_device_os = Windows\n" +
                "x_ver_os = 10.0.17763\n" +
                "x_device_model = VirtualBox\n"
        )

        assertEquals("Throne/1.1.4=custom", headers["User-Agent"])
    }

    @Test
    fun rejectsMissingRequiredFields() {
        val error = assertThrows(IllegalArgumentException::class.java) {
            AgentVConfig.parse("user_agent=Throne/1.1.4")
        }

        assertTrue(error.message.orEmpty().contains("x_hwid"))
    }

    @Test
    fun rejectsMalformedLines() {
        assertThrows(IllegalArgumentException::class.java) {
            AgentVConfig.parse(
                """
                user_agent=Throne/1.1.4
                malformed
                x_hwid=id
                x_device_os=Windows
                x_ver_os=10
                x_device_model=VirtualBox
                """.trimIndent()
            )
        }
    }
}
