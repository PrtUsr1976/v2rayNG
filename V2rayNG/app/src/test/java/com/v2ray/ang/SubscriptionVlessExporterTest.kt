package com.v2ray.ang

import com.v2ray.ang.util.SubscriptionVlessExporter
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SubscriptionVlessExporterTest {
    @Test
    fun rawLinksRemainUnchangedAndAreSortedByDecodedName() {
        val beta = "vless://0000@a.example:443?spx=&type=tcp#Beta"
        val alpha = "vless://ffff@z.example:443?type=tcp#%D0%90%D0%BB%D1%8C%D1%84%D0%B0"

        val result = SubscriptionVlessExporter.extractOriginalVlessLinks(
            "$beta\n$alpha\n$beta\nss://ignored"
        )

        assertEquals(listOf(beta, alpha), result)
        assertEquals("Альфа", SubscriptionVlessExporter.getVlessSortName(alpha))
    }

    @Test
    fun convertsRealityTcpAndPreservesExplicitEmptySpiderX() {
        val json = """
            [{
              "remarks":"Reality node",
              "outbounds":[{
                "protocol":"vless",
                "settings":{"vnext":[{"address":"server.example","port":443,
                  "users":[{"id":"fake-id","encryption":"none","flow":"xtls-rprx-vision"}]}]},
                "streamSettings":{"network":"tcp","security":"reality",
                  "realitySettings":{"serverName":"sni.example","fingerprint":"chrome",
                    "publicKey":"fake-key","shortId":"01","spiderX":""},
                  "tcpSettings":{"header":{"type":"none"}},
                  "finalmask":{"tcp":[{"type":"padding"}]}}
              }]
            }]
        """.trimIndent()

        val links = SubscriptionVlessExporter.extractOriginalVlessLinks(json)

        assertEquals(1, links.size)
        assertTrue(links.single().startsWith("vless://fake-id@server.example:443?"))
        assertTrue(links.single().contains("security=reality"))
        assertTrue(links.single().contains("headerType=none"))
        assertTrue(links.single().contains("spx="))
        assertTrue(links.single().contains("fm=%7B"))
        assertTrue(links.single().endsWith("#Reality%20node"))
    }

    @Test
    fun convertsXhttpAndGrpcAndUsesOneOutboundPerTopLevelConfig() {
        val json = """
            [
              {"name":"XHTTP","outbounds":[
                {"protocol":"freedom","settings":{}},
                {"protocol":"vless","settings":{"address":"x.example","port":8443,
                  "id":"x-id","encryption":"none"},
                 "streamSettings":{"network":"xhttp","security":"tls",
                   "tlsSettings":{"serverName":"tls.example","alpn":["h2"]},
                   "xhttpSettings":{"host":"host.example","path":"/path","mode":"auto",
                     "extra":{"headers":{"X-Test":"value"}}}}},
                {"protocol":"vless","settings":{"address":"ignored.example","port":443,"id":"ignored"}}
              ]},
              {"name":"GRPC","outbounds":[
                {"protocol":"vless","settings":{"address":"g.example","port":443,"id":"g-id"},
                 "streamSettings":{"network":"grpc","security":"none",
                   "grpcSettings":{"authority":"authority.example","serviceName":"svc"}}}
              ]}
            ]
        """.trimIndent()

        val links = SubscriptionVlessExporter.extractOriginalVlessLinks(json)

        assertEquals(2, links.size)
        val xhttp = links.first { it.endsWith("#XHTTP") }
        val grpc = links.first { it.endsWith("#GRPC") }
        assertTrue(xhttp.contains("type=xhttp"))
        assertTrue(xhttp.contains("extra=%7B"))
        assertTrue(xhttp.contains("insecure=0"))
        assertTrue(xhttp.contains("allowInsecure=0"))
        assertTrue(grpc.contains("type=grpc"))
        assertTrue(grpc.contains("mode=gun"))
        assertTrue(grpc.contains("serviceName=svc"))
        assertFalse(links.any { it.contains("ignored.example") })
    }

    @Test
    fun doesNotConvertHysteriaOrHysteria2() {
        val json = """
            [{"outbounds":[
              {"protocol":"hysteria2","settings":{"address":"h.example","port":443}},
              {"protocol":"hysteria","settings":{"address":"old.example","port":443}}
            ]}]
        """.trimIndent()

        assertEquals(emptyList<String>(), SubscriptionVlessExporter.extractOriginalVlessLinks(json))
    }

    @Test
    fun getSafeFileNameReplacesInvalidCharacters() {
        assertEquals("work_home", SubscriptionVlessExporter.getSafeFileName(" work/home. "))
        assertEquals("subscription", SubscriptionVlessExporter.getSafeFileName(""))
    }
}
