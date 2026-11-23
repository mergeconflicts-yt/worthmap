package com.contour.contour

import android.content.pm.ApplicationInfo
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

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
 */
class MainActivity : FlutterFragmentActivity() {
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
    }
}
