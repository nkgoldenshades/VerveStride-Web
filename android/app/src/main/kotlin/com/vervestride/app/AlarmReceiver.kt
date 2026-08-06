package com.vervestride.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

/**
 * BroadcastReceiver that fires when a scheduled alarm is due.
 * Starts AlarmForegroundService directly — works even when the app is killed.
 *
 * Flutter's flutter_local_notifications fires this receiver via its own
 * internal alarm mechanism. We intercept the broadcast here to immediately
 * start the foreground service so sound plays regardless of app state.
 */
class AlarmReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val alarmId = intent.getStringExtra("alarm_id") ?: "default"
        val title = intent.getStringExtra("alarm_title") ?: "Alarm"
        val body = intent.getStringExtra("alarm_body") ?: "Time for your reminder"

        val serviceIntent = Intent(context, AlarmForegroundService::class.java).apply {
            action = AlarmForegroundService.ACTION_START_ALARM
            putExtra(AlarmForegroundService.EXTRA_ALARM_ID, alarmId)
            putExtra(AlarmForegroundService.EXTRA_ALARM_TITLE, title)
            putExtra(AlarmForegroundService.EXTRA_ALARM_BODY, body)
            putExtra(AlarmForegroundService.EXTRA_USE_DEFAULT_SOUND, true)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
        }
    }
}
