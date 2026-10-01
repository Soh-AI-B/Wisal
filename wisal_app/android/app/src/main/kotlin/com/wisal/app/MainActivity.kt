package com.wisal.app

import android.Manifest
import android.app.AlarmManager
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.concurrent.thread

class MainActivity : FlutterActivity() {
    private var pending: MethodChannel.Result? = null
    private var pendingName: String = ""

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "wisal/native")
            .setMethodCallHandler { call, result -> handle(call, result) }
        // Unconditional, once per cold start: self-heals if alarms were cleared (force-stop, OEM cleanup)
        // without the notification config having changed, which the "saveConfig" diff-check below would miss.
        Alarms.rescheduleFromConfig(applicationContext)
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "granted" -> result.success(granted(call.argument<String>("name") ?: ""))
            "request" -> request(call.argument<String>("name") ?: "", result)
            "listContacts" -> bg(result) { Contacts.list(applicationContext) }
            "saveConfig" -> {
                // pushConfig() runs on every sync (e.g. every app resume), not just when the user changes
                // reminder/sentence settings — only re-arm when that part of the config actually changed,
                // otherwise a routine resync could defer an already-armed, imminent alarm to the next cycle.
                val before = Store.config(applicationContext).optJSONObject("notifications")?.toString()
                Store.saveConfig(applicationContext, call.arguments as String)
                val after = Store.config(applicationContext).optJSONObject("notifications")?.toString()
                if (before != after) {
                    android.util.Log.d("Wisal", "notification config changed, rescheduling: $after")
                    Alarms.rescheduleFromConfig(applicationContext)
                }
                result.success(null)
            }
            "sync" -> bg(result) { Sync.run(applicationContext) }
            "schedule" -> {
                Scheduler.set(applicationContext, call.arguments as Boolean)
                result.success(null)
            }
            "openBatterySettings" -> {
                startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                result.success(null)
            }
            "openExactAlarmSettings" -> {
                if (Build.VERSION.SDK_INT >= 31) {
                    startActivity(Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, Uri.parse("package:$packageName")))
                }
                result.success(null)
            }
            "testNotification" -> result.success(Notifier.postTest(applicationContext, Store.config(applicationContext)))
            else -> result.notImplemented()
        }
    }

    private fun bg(result: MethodChannel.Result, block: () -> Any?) {
        thread {
            try {
                val r = block()
                runOnUiThread { result.success(r) }
            } catch (e: Exception) {
                runOnUiThread { result.error("native", e.message, null) }
            }
        }
    }

    private fun perm(name: String): String? = when (name) {
        "contacts" -> Manifest.permission.READ_CONTACTS
        "callLog" -> Manifest.permission.READ_CALL_LOG
        "notifications" -> if (Build.VERSION.SDK_INT >= 33) Manifest.permission.POST_NOTIFICATIONS else null
        else -> null
    }

    private fun granted(name: String): Boolean {
        // Covers both the Android 13+ runtime permission and the app-wide "block notifications" switch.
        if (name == "notifications") return NotificationManagerCompat.from(this).areNotificationsEnabled()
        if (name == "exactAlarm") {
            return Build.VERSION.SDK_INT < 31 || getSystemService(AlarmManager::class.java).canScheduleExactAlarms()
        }
        val p = perm(name) ?: return true
        return ContextCompat.checkSelfPermission(this, p) == PackageManager.PERMISSION_GRANTED
    }

    private fun request(name: String, result: MethodChannel.Result) {
        if (granted(name)) {
            result.success(true)
            return
        }
        val p = perm(name)
        if (p == null) {
            result.success(false)
            return
        }
        pending = result
        pendingName = name
        ActivityCompat.requestPermissions(this, arrayOf(p), 42)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 42) {
            pending?.success(granted(pendingName))
            pending = null
        }
    }
}
