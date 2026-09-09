package com.example.tulabe

import android.app.DownloadManager
import android.content.Context
import android.net.Uri
import android.os.Environment
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "tulabe/downloads")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "enqueue" -> enqueueDownload(call.arguments, result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun enqueueDownload(arguments: Any?, result: MethodChannel.Result) {
        val args = arguments as? Map<*, *>
        val url = args?.get("url") as? String
        val filename = args?.get("filename") as? String
        val title = args?.get("title") as? String
        val description = args?.get("description") as? String
        if (url.isNullOrEmpty() || filename.isNullOrEmpty()) {
            result.error("INVALID_ARGS", "url and filename are required", null)
            return
        }
        if (filename.contains("..") || filename.contains("/") || filename.contains("\\")) {
            result.error("INVALID_FILENAME", "filename must be a plain file name", null)
            return
        }
        try {
            val request = DownloadManager.Request(Uri.parse(url))
                .setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, filename)
                .setTitle(title ?: filename)
                .setDescription(description ?: "Tulabe download")
                .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
                .setAllowedOverMetered(true)
                .setAllowedOverRoaming(true)
                .setMimeType(mimeFor(filename))
            val manager = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
            val downloadId = manager.enqueue(request)
            result.success(downloadId)
        } catch (e: Exception) {
            result.error("ENQUEUE_FAILED", e.message, null)
        }
    }

    private fun mimeFor(filename: String): String {
        return when {
            filename.endsWith(".mp4", ignoreCase = true) -> "video/mp4"
            filename.endsWith(".mkv", ignoreCase = true) -> "video/x-matroska"
            filename.endsWith(".webm", ignoreCase = true) -> "video/webm"
            filename.endsWith(".avi", ignoreCase = true) -> "video/x-msvideo"
            else -> "video/mp2t"
        }
    }
}