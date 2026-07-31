package com.v2ray.ang.util

import android.content.ContentResolver
import android.net.Uri
import android.provider.DocumentsContract
import com.v2ray.ang.AppConfig

object SubscriptionVlessExporter {
    private val vlessPattern = Regex("vless://[^\\s\\\"'<>]+", RegexOption.IGNORE_CASE)
    private val invalidFileNameCharacters = Regex("[\\x00-\\x1f\\\\/:*?\\\"<>|]")

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
        return sequenceOf(content, decoded)
            .flatMap { vlessPattern.findAll(it).map(MatchResult::value) }
            .distinct()
            .sortedWith(String.CASE_INSENSITIVE_ORDER.thenBy { it })
            .toList()
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
