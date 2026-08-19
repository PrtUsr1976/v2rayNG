package com.v2ray.ang.util

import android.content.ContentResolver
import android.net.Uri
import android.provider.DocumentsContract
import com.google.gson.JsonElement
import com.google.gson.JsonObject
import com.google.gson.JsonParser
import com.v2ray.ang.AppConfig
import java.net.URLDecoder
import java.net.URLEncoder
import java.nio.charset.StandardCharsets
import java.util.Locale

object SubscriptionVlessExporter {
    private val vlessPattern = Regex("vless://[^\\s\\\"'<>]+", RegexOption.IGNORE_CASE)
    private val invalidFileNameCharacters = Regex("[\\x00-\\x1f\\\\/:*?\\\"<>|]")
    private val vlessLinkComparator = compareBy<String> {
        getVlessSortName(it).lowercase(Locale.ROOT)
    }.thenBy {
        it.lowercase(Locale.ROOT)
    }.thenBy { it }

    fun export(
        contentResolver: ContentResolver,
        directoryUri: String,
        subscriptionName: String,
        originalContent: String
    ) {
        try {
            val links = extractOriginalVlessLinks(originalContent)
            val treeUri = Uri.parse(directoryUri)
            val fileName = "${getSafeFileName(subscriptionName)}.txt"
            val documentUri = findDocument(contentResolver, treeUri, fileName)
                ?: createDocument(contentResolver, treeUri, fileName)
                ?: error("Unable to create $fileName")
            val text = if (links.isEmpty()) "" else links.joinToString("\n", postfix = "\n")
            contentResolver.openOutputStream(documentUri, "wt")?.bufferedWriter(Charsets.UTF_8)?.use {
                it.write(text)
            } ?: error("Unable to open $fileName for writing")
            LogUtil.i(AppConfig.TAG, "Subscription VLESS export: wrote ${links.size} links to $fileName")
        } catch (e: Exception) {
            LogUtil.e(AppConfig.TAG, "Subscription VLESS export failed", e)
        }
    }

    fun extractOriginalVlessLinks(content: String?): List<String> {
        if (content.isNullOrBlank()) return emptyList()
        val decoded = runCatching { Utils.decode(content) }.getOrDefault("")
        val rawLinks = sequenceOf(content, decoded)
            .flatMap { vlessPattern.findAll(it).map(MatchResult::value) }
            .distinct()
            .toList()
        val links = if (rawLinks.isNotEmpty()) rawLinks else extractJsonVlessLinks(content)
        return links.sortedWith(vlessLinkComparator)
    }

    private fun extractJsonVlessLinks(content: String): List<String> {
        val root = runCatching { JsonParser.parseString(content) }.getOrNull()
            ?.takeIf(JsonElement::isJsonArray)?.asJsonArray
            ?: return emptyList()
        return root.mapNotNull { element ->
            element.takeIf(JsonElement::isJsonObject)?.asJsonObject?.let(::jsonConfigToVless)
        }
    }

    private fun jsonConfigToVless(config: JsonObject): String? {
        val outbounds = config.array("outbounds") ?: return null
        val outbound = outbounds.firstNotNullOfOrNull { element ->
            element.takeIf(JsonElement::isJsonObject)?.asJsonObject
                ?.takeIf { it.string("protocol").equals("vless", ignoreCase = true) }
        } ?: return null
        val settings = outbound.obj("settings") ?: return null
        val vnext = settings.array("vnext")?.firstOrNull()
            ?.takeIf(JsonElement::isJsonObject)?.asJsonObject
        val source = vnext ?: settings
        val user = source.array("users")?.firstOrNull()
            ?.takeIf(JsonElement::isJsonObject)?.asJsonObject
        val address = source.string("address") ?: return null
        val port = source.int("port") ?: return null
        val id = user?.string("id") ?: source.string("id") ?: return null
        val encryption = user?.string("encryption") ?: source.string("encryption") ?: "none"
        val flow = user?.string("flow") ?: source.string("flow")
        val stream = outbound.obj("streamSettings") ?: JsonObject()
        val network = stream.string("network") ?: "tcp"
        val security = stream.string("security") ?: "none"
        val query = linkedMapOf<String, String>()
        query["encryption"] = encryption
        flow?.takeIf(String::isNotBlank)?.let { query["flow"] = it }
        query["security"] = security
        query["type"] = network

        when (security.lowercase(Locale.ROOT)) {
            "reality" -> addReality(query, stream.obj("realitySettings"))
            "tls" -> addTls(query, stream.obj("tlsSettings"))
        }
        stream.get("finalmask")?.takeUnless(JsonElement::isJsonNull)?.let {
            query["fm"] = JsonUtil.toJson(it)
        }
        when (network.lowercase(Locale.ROOT)) {
            "tcp" -> query["headerType"] =
                stream.obj("tcpSettings")?.obj("header")?.string("type") ?: "none"
            "ws" -> {
                val transport = stream.obj("wsSettings")
                transport?.string("path")?.let { query["path"] = it }
                (transport?.string("host")
                    ?: transport?.obj("headers")?.string("Host"))?.let { query["host"] = it }
            }
            "xhttp" -> {
                val transport = stream.obj("xhttpSettings")
                transport?.string("host")?.let { query["host"] = it }
                transport?.string("path")?.let { query["path"] = it }
                transport?.string("mode")?.let { query["mode"] = it }
                transport?.get("extra")?.takeUnless(JsonElement::isJsonNull)?.let {
                    query["extra"] = JsonUtil.toJson(it)
                }
            }
            "grpc" -> {
                val transport = stream.obj("grpcSettings")
                transport?.string("authority")?.let { query["authority"] = it }
                transport?.string("serviceName")?.let { query["serviceName"] = it }
                query["mode"] = if (transport?.boolean("multiMode") == true) "multi" else "gun"
            }
        }

        val name = config.string("remarks")
            ?: config.string("name")
            ?: outbound.string("tag")
            ?: address
        val host = if (address.contains(':') && !address.startsWith('[')) "[$address]" else address
        val queryText = query.entries.joinToString("&") { (key, value) ->
            "${encode(key)}=${encode(value)}"
        }
        return "vless://${encode(id)}@$host:$port?$queryText#${encode(name)}"
    }

    private fun addReality(query: MutableMap<String, String>, settings: JsonObject?) {
        settings ?: return
        settings.string("serverName")?.let { query["sni"] = it }
        settings.string("fingerprint")?.let { query["fp"] = it }
        settings.string("publicKey")?.let { query["pbk"] = it }
        settings.string("shortId")?.let { query["sid"] = it }
        if (settings.has("spiderX")) query["spx"] = settings.string("spiderX").orEmpty()
    }

    private fun addTls(query: MutableMap<String, String>, settings: JsonObject?) {
        settings?.string("serverName")?.let { query["sni"] = it }
        settings?.string("fingerprint")?.let { query["fp"] = it }
        settings?.array("alpn")?.joinToString(",") { it.asString }?.let { query["alpn"] = it }
        val insecure = settings?.boolean("insecure") ?: false
        val allowInsecure = settings?.boolean("allowInsecure") ?: false
        query["insecure"] = if (insecure) "1" else "0"
        query["allowInsecure"] = if (allowInsecure) "1" else "0"
    }

    private fun JsonObject.obj(name: String): JsonObject? =
        get(name)?.takeIf(JsonElement::isJsonObject)?.asJsonObject

    private fun JsonObject.array(name: String) =
        get(name)?.takeIf(JsonElement::isJsonArray)?.asJsonArray

    private fun JsonObject.string(name: String): String? =
        get(name)?.takeUnless(JsonElement::isJsonNull)?.runCatching { asString }?.getOrNull()

    private fun JsonObject.int(name: String): Int? =
        get(name)?.takeUnless(JsonElement::isJsonNull)?.runCatching { asInt }?.getOrNull()

    private fun JsonObject.boolean(name: String): Boolean? =
        get(name)?.takeUnless(JsonElement::isJsonNull)?.runCatching { asBoolean }?.getOrNull()

    private fun encode(value: String): String =
        URLEncoder.encode(value, StandardCharsets.UTF_8.name()).replace("+", "%20")

    internal fun getVlessSortName(link: String): String {
        val fragment = link.substringAfterLast('#', "")
        if (fragment.isBlank()) return link
        return runCatching {
            URLDecoder.decode(fragment.replace("+", "%2B"), StandardCharsets.UTF_8.name())
        }.getOrDefault(fragment)
    }

    fun getSafeFileName(remarks: String?): String {
        val name = remarks?.trim().takeUnless { it.isNullOrBlank() } ?: "subscription"
        return name.replace(invalidFileNameCharacters, "_")
            .trim()
            .trimEnd('.')
            .ifBlank { "subscription" }
    }

    private fun findDocument(
        contentResolver: ContentResolver,
        treeUri: Uri,
        fileName: String
    ): Uri? {
        val treeDocumentId = DocumentsContract.getTreeDocumentId(treeUri)
        val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(treeUri, treeDocumentId)
        return contentResolver.query(
            childrenUri,
            arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID, DocumentsContract.Document.COLUMN_DISPLAY_NAME),
            null,
            null,
            null
        )?.use { cursor ->
            val idColumn = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_DOCUMENT_ID)
            val nameColumn = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_DISPLAY_NAME)
            while (cursor.moveToNext()) {
                if (cursor.getString(nameColumn) == fileName) {
                    return@use DocumentsContract.buildDocumentUriUsingTree(treeUri, cursor.getString(idColumn))
                }
            }
            null
        }
    }

    private fun createDocument(
        contentResolver: ContentResolver,
        treeUri: Uri,
        fileName: String
    ): Uri? {
        val parentUri = DocumentsContract.buildDocumentUriUsingTree(
            treeUri,
            DocumentsContract.getTreeDocumentId(treeUri)
        )
        return DocumentsContract.createDocument(contentResolver, parentUri, "text/plain", fileName)
    }
}
