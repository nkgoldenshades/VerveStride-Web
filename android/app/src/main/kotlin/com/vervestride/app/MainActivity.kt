package com.vervestride.app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val shareChannelName = "com.vervestride.app/share"
    private val alarmChannelName = "com.vervestride/alarm"

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        handleAlarmIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleAlarmIntent(intent)
    }

    private fun handleAlarmIntent(intent: Intent?) {
        // fullScreenIntent or AlarmReceiver tap lands here with STOP_ALARM or alarm extras
        val action = intent?.action ?: return
        if (action == "STOP_ALARM") {
            stopAlarmService()
            return
        }
        // Auto-start alarm if launched by fullScreenIntent with alarm_id
        val alarmId = intent.getStringExtra(AlarmForegroundService.EXTRA_ALARM_ID) ?: return
        val title = intent.getStringExtra(AlarmForegroundService.EXTRA_ALARM_TITLE) ?: "Alarm"
        val body = intent.getStringExtra(AlarmForegroundService.EXTRA_ALARM_BODY) ?: "Alarm"
        startAlarmService(alarmId, title, body, true, null)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, alarmChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startAlarmService" -> {
                        val alarmId = call.argument<String>("alarmId") ?: "default"
                        val title = call.argument<String>("title") ?: "Alarm"
                        val body = call.argument<String>("body") ?: "Alarm is ringing"
                        val useDefaultSound = call.argument<Boolean>("useDefaultSound") ?: true
                        val customSoundUri = call.argument<String>("customSoundUri")
                        startAlarmService(alarmId, title, body, useDefaultSound, customSoundUri)
                        result.success(null)
                    }
                    "stopAlarmService" -> {
                        stopAlarmService()
                        result.success(null)
                    }
                    "isIgnoringBatteryOptimizations" -> {
                        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                        result.success(pm.isIgnoringBatteryOptimizations(packageName))
                    }
                    "requestIgnoreBatteryOptimizations" -> {
                        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                            data = Uri.parse("package:$packageName")
                        }
                        startActivity(intent)
                        result.success(null)
                    }
                    "openBatterySettings" -> {
                        // Opens MIUI/OEM battery settings directly
                        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                            data = Uri.parse("package:$packageName")
                        }
                        startActivity(intent)
                        result.success(null)
                    }
                    "isAlarmRinging" -> {
                        result.success(AlarmForegroundService.isAlarmRinging)
                    }
                    "scheduleAlarm" -> {
                        val alarmId = call.argument<String>("alarmId") ?: "default"
                        val title = call.argument<String>("title") ?: "Alarm"
                        val body = call.argument<String>("body") ?: "Time for your reminder"
                        val triggerAtMillis = call.argument<Long>("triggerAtMillis")
                            ?: (call.argument<Int>("triggerAtMillis")?.toLong())
                        if (triggerAtMillis == null) {
                            result.error("INVALID_ARGS", "triggerAtMillis is required", null)
                            return@setMethodCallHandler
                        }
                        scheduleAlarm(alarmId, title, body, triggerAtMillis)
                        result.success(null)
                    }
                    "cancelAlarm" -> {
                        val alarmId = call.argument<String>("alarmId") ?: "default"
                        cancelAlarm(alarmId)
                        result.success(null)
                    }
                    // NEW: Comprehensive permission and compatibility checks
                    "checkAlarmPermission" -> {
                        result.success(canScheduleExactAlarms())
                    }
                    "requestAlarmPermission" -> {
                        requestAlarmPermission()
                        result.success(null)
                    }
                    "checkNotificationPermission" -> {
                        result.success(hasNotificationPermission())
                    }
                    "requestNotificationPermission" -> {
                        requestNotificationPermission()
                        result.success(null)
                    }
                    "checkBatteryOptimization" -> {
                        result.success(isIgnoringBatteryOptimizations())
                    }
                    "requestBatteryOptimizationExemption" -> {
                        requestBatteryOptimizationExemption()
                        result.success(null)
                    }
                    "getDeviceInfo" -> {
                        result.success(getDeviceInfo())
                    }
                    "openAppSettings" -> {
                        openAppSettings()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, shareChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "shareRouteWithMaps" -> {
                        val text = call.argument<String>("text")
                        val subject = call.argument<String>("subject")
                        val mapsUrl = call.argument<String>("mapsUrl")

                        if (text.isNullOrBlank()) {
                            result.error("INVALID_ARGS", "Missing share text", null)
                            return@setMethodCallHandler
                        }

                        try {
                            val sendIntent = Intent(Intent.ACTION_SEND).apply {
                                type = "text/plain"
                                putExtra(Intent.EXTRA_TEXT, text)
                                if (!subject.isNullOrBlank()) {
                                    putExtra(Intent.EXTRA_SUBJECT, subject)
                                }
                            }

                            val chooserTitle = subject ?: "Share"
                            val chooserIntent = Intent.createChooser(sendIntent, chooserTitle)

                            if (!mapsUrl.isNullOrBlank()) {
                                val mapsUri = Uri.parse(mapsUrl)
                                val mapsIntent = Intent(Intent.ACTION_VIEW, mapsUri)
                                chooserIntent.putExtra(
                                    Intent.EXTRA_INITIAL_INTENTS,
                                    arrayOf(mapsIntent)
                                )
                            }

                            startActivity(chooserIntent)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("SHARE_FAILED", e.message, null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun startAlarmService(
        alarmId: String,
        title: String,
        body: String,
        useDefaultSound: Boolean,
        customSoundUri: String?
    ) {
        val serviceIntent = Intent(this, AlarmForegroundService::class.java).apply {
            action = AlarmForegroundService.ACTION_START_ALARM
            putExtra(AlarmForegroundService.EXTRA_ALARM_ID, alarmId)
            putExtra(AlarmForegroundService.EXTRA_ALARM_TITLE, title)
            putExtra(AlarmForegroundService.EXTRA_ALARM_BODY, body)
            putExtra(AlarmForegroundService.EXTRA_USE_DEFAULT_SOUND, useDefaultSound)
            putExtra(AlarmForegroundService.EXTRA_CUSTOM_SOUND_URI, customSoundUri)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }
    }

    private fun stopAlarmService() {
        val serviceIntent = Intent(this, AlarmForegroundService::class.java).apply {
            action = AlarmForegroundService.ACTION_STOP_ALARM
        }
        startService(serviceIntent)
    }

    private fun scheduleAlarm(alarmId: String, title: String, body: String, triggerAtMillis: Long) {
        val intent = Intent(this, AlarmReceiver::class.java).apply {
            putExtra("alarm_id", alarmId)
            putExtra("alarm_title", title)
            putExtra("alarm_body", body)
        }
        val requestCode = alarmId.hashCode()
        val pendingIntent = PendingIntent.getBroadcast(
            this,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !alarmManager.canScheduleExactAlarms()) {
            // Fallback to inexact if exact alarm permission not granted
            alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
        } else {
            alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
        }
    }

    private fun cancelAlarm(alarmId: String) {
        val intent = Intent(this, AlarmReceiver::class.java)
        val requestCode = alarmId.hashCode()
        val pendingIntent = PendingIntent.getBroadcast(
            this,
            requestCode,
            intent,
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
        ) ?: return
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.cancel(pendingIntent)
        pendingIntent.cancel()
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // UNIVERSAL COMPATIBILITY METHODS (Android 5.0+ / API 21+)
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * Check if app can schedule exact alarms
     * Android 12+ (API 31+) requires explicit permission
     * Older versions always return true
     */
    private fun canScheduleExactAlarms(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarmManager.canScheduleExactAlarms()
        } else {
            true // Always granted on Android 5-11
        }
    }

    /**
     * Request exact alarm permission (Android 12+)
     * Opens system settings on older versions as fallback
     */
    private fun requestAlarmPermission() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                // Android 12+ specific intent
                val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
                startActivity(intent)
            } else {
                // Fallback for older Android - open app settings
                openAppSettings()
            }
        } catch (e: Exception) {
            // Some devices/manufacturers don't support ACTION_REQUEST_SCHEDULE_EXACT_ALARM
            // Fallback to app settings
            openAppSettings()
        }
    }

    /**
     * Check notification permission (Android 13+)
     * Older versions always return true (permission auto-granted)
     */
    private fun hasNotificationPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) == 
                android.content.pm.PackageManager.PERMISSION_GRANTED
        } else {
            true // Auto-granted on Android 12 and below
        }
    }

    /**
     * Request notification permission (Android 13+)
     * No-op on older versions (auto-granted)
     */
    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 1001)
        }
    }

    /**
     * Check if app is exempt from battery optimization
     * Works on Android 6+ (API 23+)
     */
    private fun isIgnoringBatteryOptimizations(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            pm.isIgnoringBatteryOptimizations(packageName)
        } else {
            true // Battery optimization doesn't exist on Android 5
        }
    }

    /**
     * Request battery optimization exemption
     * Critical for alarms to work reliably on all devices
     */
    private fun requestBatteryOptimizationExemption() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                intent.data = Uri.parse("package:$packageName")
                startActivity(intent)
            }
        } catch (e: Exception) {
            // Some manufacturers (Xiaomi, Huawei, Oppo) don't support this
            // Fallback to battery settings
            openBatterySettings()
        }
    }

    /**
     * Open battery settings (manufacturer-specific)
     * Works on Xiaomi MIUI, Huawei EMUI, Oppo ColorOS, etc.
     */
    private fun openBatterySettings() {
        try {
            val manufacturer = Build.MANUFACTURER.lowercase()
            val intent = when {
                // Xiaomi MIUI
                manufacturer.contains("xiaomi") -> {
                    Intent().apply {
                        component = android.content.ComponentName(
                            "com.miui.powerkeeper",
                            "com.miui.powerkeeper.ui.HiddenAppsConfigActivity"
                        )
                        putExtra("package_name", packageName)
                        putExtra("package_label", applicationInfo.loadLabel(packageManager))
                    }
                }
                // Huawei EMUI
                manufacturer.contains("huawei") -> {
                    Intent().apply {
                        component = android.content.ComponentName(
                            "com.huawei.systemmanager",
                            "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity"
                        )
                    }
                }
                // Oppo ColorOS
                manufacturer.contains("oppo") -> {
                    Intent().apply {
                        component = android.content.ComponentName(
                            "com.coloros.safecenter",
                            "com.coloros.safecenter.permission.startup.StartupAppListActivity"
                        )
                    }
                }
                // Vivo FuntouchOS
                manufacturer.contains("vivo") -> {
                    Intent().apply {
                        component = android.content.ComponentName(
                            "com.vivo.permissionmanager",
                            "com.vivo.permissionmanager.activity.BgStartUpManagerActivity"
                        )
                    }
                }
                // Samsung OneUI
                manufacturer.contains("samsung") -> {
                    Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                        data = Uri.parse("package:$packageName")
                    }
                }
                // Default for other manufacturers
                else -> {
                    Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                        data = Uri.parse("package:$packageName")
                    }
                }
            }
            startActivity(intent)
        } catch (e: Exception) {
            // Ultimate fallback - app details
            openAppSettings()
        }
    }

    /**
     * Open app settings (works on all Android versions)
     */
    private fun openAppSettings() {
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
        intent.data = Uri.parse("package:$packageName")
        startActivity(intent)
    }

    /**
     * Get device information for debugging
     * Helps identify manufacturer-specific issues
     */
    private fun getDeviceInfo(): Map<String, Any> {
        return mapOf(
            "manufacturer" to Build.MANUFACTURER,
            "model" to Build.MODEL,
            "androidVersion" to Build.VERSION.RELEASE,
            "sdkInt" to Build.VERSION.SDK_INT,
            "brand" to Build.BRAND,
            "device" to Build.DEVICE,
            "canScheduleExactAlarms" to canScheduleExactAlarms(),
            "hasNotificationPermission" to hasNotificationPermission(),
            "isIgnoringBatteryOptimizations" to isIgnoringBatteryOptimizations()
        )
    }
}
