package com.contour.contour

import android.content.pm.ApplicationInfo
import android.net.Uri
import android.provider.OpenableColumns
import androidx.activity.result.contract.ActivityResultContracts
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.IOException

/**
 * T08/T11: the Android runner.
 *
 * `FlutterFragmentActivity` is required by the `local_auth` platform
 * implementation (BiometricPrompt needs a fragment activity).
 *
 * T11 (SYSTEM_DESIGN 12.2): the `contour/backup_exclusions` handler reports
 * the OS-level backup/transfer truth. The release manifest sets
 * `allowBackup="false"` and the data-extraction rules exclude every domain
 * for cloud backup and device transfer (guarded by
 * test/privacy/android_manifest_test.dart), so every protected path kind is
 * excluded at the OS level. The handler answers per kind from that manifest
 * state; it never logs paths (AGENTS 2.6).
 *
 * P3-22 (SPEC 8.8): the `contour/import_intake` handler opens the system
 * document picker for one local PDF and returns its bytes. It reads the
 * content URI once, caps the read at the bound Dart sends, checks the `%PDF-`
 * signature and keeps no copy. It requests no permission, writes no database
 * row and logs nothing (AGENTS 2.6).
 */
class MainActivity : FlutterFragmentActivity() {
    private var intakeResult: MethodChannel.Result? = null
    private var intakeMaxBytes: Int = DEFAULT_MAX_BYTES

    private val pdfPicker = registerForActivityResult(
        ActivityResultContracts.OpenDocument(),
    ) { uri -> onPdfPicked(uri) }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "contour/backup_exclusions",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "apply" -> {
                    val backupsAllowed = (applicationInfo.flags and
                        ApplicationInfo.FLAG_ALLOW_BACKUP) != 0
                    result.success(!backupsAllowed)
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "contour/import_intake",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickPdf" -> {
                    if (intakeResult != null) {
                        // One picker at a time; a second call is a cancel.
                        result.success(null)
                        return@setMethodCallHandler
                    }
                    val arguments = call.arguments as? Map<*, *>
                    val requested = (arguments?.get("maxBytes") as? Number)?.toInt() ?: 0
                    intakeMaxBytes = if (requested > 0) requested else DEFAULT_MAX_BYTES
                    intakeResult = result
                    pdfPicker.launch(arrayOf("application/pdf"))
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun onPdfPicked(uri: Uri?) {
        val result = intakeResult ?: return
        intakeResult = null
        if (uri == null) {
            result.success(null)
            return
        }
        try {
            val name = displayName(uri)
                ?: uri.lastPathSegment?.substringAfterLast('/')
            if (name.isNullOrBlank()) {
                result.error("damaged", null, null)
                return
            }
            val bytes = readPdf(uri, intakeMaxBytes)
            if (bytes == null) {
                result.error("tooLarge", null, null)
                return
            }
            if (bytes.size < PDF_HEADER.size ||
                !bytes.copyOfRange(0, PDF_HEADER.size).contentEquals(PDF_HEADER)
            ) {
                result.error("notPdf", null, null)
                return
            }
            result.success(mapOf("name" to name, "bytes" to bytes))
        } catch (error: Exception) {
            // The error carries no path or content (AGENTS 2.6).
            result.error("damaged", null, null)
        }
    }

    private fun displayName(uri: Uri): String? {
        contentResolver.query(
            uri,
            arrayOf(OpenableColumns.DISPLAY_NAME),
            null,
            null,
            null,
        )?.use { cursor ->
            if (cursor.moveToFirst()) {
                val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (index >= 0) return cursor.getString(index)
            }
        }
        return null
    }

    /** Reads the URI once; null means the bound was exceeded. */
    private fun readPdf(uri: Uri, maxBytes: Int): ByteArray? {
        val input = contentResolver.openInputStream(uri) ?: throw IOException()
        input.use { stream ->
            val out = ByteArrayOutputStream()
            val buffer = ByteArray(64 * 1024)
            var total = 0
            while (true) {
                val read = stream.read(buffer)
                if (read < 0) break
                total += read
                if (total > maxBytes) return null
                out.write(buffer, 0, read)
            }
            return out.toByteArray()
        }
    }

    private companion object {
        const val DEFAULT_MAX_BYTES = 100 * 1024 * 1024
        val PDF_HEADER = byteArrayOf(0x25, 0x50, 0x44, 0x46, 0x2D)
    }
}
