package com.vervestride.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import androidx.core.app.NotificationCompat

/**
 * Foreground service for continuous alarm ringing.
 * This keeps the alarm ringing even when the app is in background.
 */
class AlarmForegroundService : Service() {

    companion object {
        const val ACTION_START_ALARM = "ACTION_START_ALARM"
        const val ACTION_STOP_ALARM = "ACTION_STOP_ALARM"
        const val EXTRA_ALARM_ID = "alarm_id"
        const val EXTRA_ALARM_TITLE = "alarm_title"
        const val EXTRA_ALARM_BODY = "alarm_body"
        const val EXTRA_USE_DEFAULT_SOUND = "use_default_sound"
        const val EXTRA_CUSTOM_SOUND_URI = "custom_sound_uri"

        private const val NOTIFICATION_ID = 9999
        private const val CHANNEL_ID = "alarm_foreground_service"
        private const val WAKE_LOCK_TAG = "VerveStride::AlarmWakeLock"

        @JvmStatic
        var isAlarmRinging = false
            private set
    }

    private var mediaPlayer: MediaPlayer? = null
    private var vibrator: Vibrator? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private val handler = Handler(Looper.getMainLooper())
    private var alarmId: String? = null

    private val vibrationPattern = longArrayOf(0, 500, 500, 500, 500)

    private val keepAliveRunnable: Runnable = object : Runnable {
        override fun run() {
            if (!isAlarmRinging) return
            // Only restart if the player stopped unexpectedly (not looping properly)
            // Do NOT restart if already playing — isLooping=true handles continuous play
            val player = mediaPlayer
            if (player != null && !player.isPlaying) {
                try {
                    player.seekTo(0)
                    player.start()
                } catch (e: Exception) {
                    // Player in bad state, recreate it
                    player.release()
                    mediaPlayer = null
                    startAlarmSound(true, null)
                }
            }
            handler.postDelayed(this, 10000)
        }
    }

    override fun onCreate() {
        super.onCreate()
        vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        createNotificationChannel()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START_ALARM -> {
                alarmId = intent.getStringExtra(EXTRA_ALARM_ID) ?: "default"
                val title = intent.getStringExtra(EXTRA_ALARM_TITLE) ?: "Alarm"
                val body = intent.getStringExtra(EXTRA_ALARM_BODY) ?: "Alarm is ringing"
                val useDefaultSound = intent.getBooleanExtra(EXTRA_USE_DEFAULT_SOUND, true)
                val customSoundUri = intent.getStringExtra(EXTRA_CUSTOM_SOUND_URI)

                startAlarm(title, body, useDefaultSound, customSoundUri)
            }
            ACTION_STOP_ALARM -> {
                stopAlarm()
                stopSelf()
            }
            null -> {
                // Service restarted by OS after being killed — do not re-ring.
                // The alarm was already dismissed or will be re-triggered by the app.
                stopSelf()
            }
        }
        return START_NOT_STICKY
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Alarm Service",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Keeps alarm ringing in background"
                setSound(null, null)
                enableVibration(false)
            }

            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun startAlarm(title: String, body: String, useDefaultSound: Boolean, customSoundUri: String?) {
        if (isAlarmRinging) {
            // Already ringing — just update the foreground notification text.
            val notification = createForegroundNotification(title, body)
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.notify(NOTIFICATION_ID, notification)
            return
        }

        isAlarmRinging = true

        acquireWakeLock()
        startVibration()
        startAlarmSound(useDefaultSound, customSoundUri)

        val notification = createForegroundNotification(title, body)
        when {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q -> {
                startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
            }
            else -> startForeground(NOTIFICATION_ID, notification)
        }

        handler.postDelayed(keepAliveRunnable, 5000)
    }

    private fun startAlarmSound(useDefaultSound: Boolean, customSoundUri: String?) {
        try {
            val soundUri = when {
                customSoundUri != null -> Uri.parse(customSoundUri)
                useDefaultSound -> RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                else -> RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            }

            mediaPlayer = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                setDataSource(this@AlarmForegroundService, soundUri)
                isLooping = true
                prepare()
                start()
            }
        } catch (e: Exception) {
            e.printStackTrace()
            try {
                val defaultAlarm = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                mediaPlayer = MediaPlayer.create(this, defaultAlarm).apply {
                    isLooping = true
                    start()
                }
            } catch (e2: Exception) {
                e2.printStackTrace()
            }
        }
    }

    private fun startVibration() {
        vibrator?.let { vib ->
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vib.vibrate(VibrationEffect.createWaveform(vibrationPattern, 0))
            } else {
                @Suppress("DEPRECATION")
                vib.vibrate(vibrationPattern, 0)
            }
        }
    }

    private fun acquireWakeLock() {
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP or PowerManager.ON_AFTER_RELEASE,
            WAKE_LOCK_TAG
        ).apply {
            acquire(10 * 60 * 1000L)
        }
    }

    private fun createForegroundNotification(title: String, body: String): Notification {
        val openIntent = Intent(this, MainActivity::class.java).apply {
            action = AlarmForegroundService.ACTION_START_ALARM
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra(EXTRA_ALARM_ID, alarmId)
            putExtra(EXTRA_ALARM_TITLE, title)
            putExtra(EXTRA_ALARM_BODY, body)
        }

        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val stopIntent = Intent(this, AlarmForegroundService::class.java).apply {
            action = ACTION_STOP_ALARM
        }
        val stopPendingIntent = PendingIntent.getService(
            this,
            1,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(body)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setAutoCancel(false)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .addAction(
                R.mipmap.ic_launcher,
                "STOP",
                stopPendingIntent
            )
            .build()
    }

    private fun stopAlarm() {
        isAlarmRinging = false

        handler.removeCallbacks(keepAliveRunnable)

        mediaPlayer?.apply {
            if (isPlaying) {
                stop()
            }
            release()
        }
        mediaPlayer = null

        vibrator?.cancel()

        wakeLock?.apply {
            if (isHeld) release()
        }
        wakeLock = null
    }

    override fun onDestroy() {
        super.onDestroy()
        stopAlarm()
    }
}
