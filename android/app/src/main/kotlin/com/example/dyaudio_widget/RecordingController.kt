package com.example.dyaudio_widget

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat

/**
 * Single source of truth for recording state. Both the home screen widget
 * and the in-app toggle go through here so they always agree on state.
 */
object RecordingController {
    private const val PREFS_NAME = "audio_widget_prefs"
    private const val KEY_IS_RECORDING = "is_recording"
    private const val IDLE_CHANNEL_ID = "idle_trigger_channel"
    private const val IDLE_NOTIFICATION_ID = 43

    fun hasMicPermission(context: Context): Boolean {
        return ContextCompat.checkSelfPermission(
            context,
            android.Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED
    }

    fun isRecording(context: Context): Boolean {
        return prefs(context).getBoolean(KEY_IS_RECORDING, false)
    }

    /** Shows the "탭하여 시작" lock-screen-visible notification if we're idle. Call on app open. */
    fun ensureIdleNotification(context: Context) {
        if (!isRecording(context)) {
            showIdleNotification(context)
        }
    }

    private fun setRecording(context: Context, recording: Boolean) {
        prefs(context).edit().putBoolean(KEY_IS_RECORDING, recording).apply()
        AudioWidgetProvider.updateAllWidgets(context)
        if (recording) {
            NotificationManagerCompat.from(context).cancel(IDLE_NOTIFICATION_ID)
        } else {
            showIdleNotification(context)
        }
    }

    // Tapping "시작" sends the same broadcast the widget tap does, so this stays a
    // notification action rather than a foreground service: no need to keep anything
    // running while idle, and it reuses RecordingController.toggle() via the receiver.
    private fun showIdleNotification(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(context, android.Manifest.permission.POST_NOTIFICATIONS)
            != PackageManager.PERMISSION_GRANTED
        ) {
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channel = NotificationChannel(
                IDLE_CHANNEL_ID,
                "녹음 대기 알림",
                NotificationManager.IMPORTANCE_LOW
            )
            manager.createNotificationChannel(channel)
        }

        val toggleIntent = Intent(context, AudioWidgetProvider::class.java)
            .setAction(AudioWidgetProvider.ACTION_TOGGLE_RECORDING)
        val pendingIntent = PendingIntent.getBroadcast(
            context, 1, toggleIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(context, IDLE_CHANNEL_ID)
            .setContentTitle("녹음 대기 중")
            .setContentText("탭하여 바로 녹음을 시작하세요")
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setOngoing(true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .addAction(0, "시작", pendingIntent)
            .build()
        NotificationManagerCompat.from(context).notify(IDLE_NOTIFICATION_ID, notification)
    }

    /** Returns the new recording state, or null if permission is missing. */
    fun toggle(context: Context): Boolean? {
        if (!hasMicPermission(context)) {
            return null
        }
        return if (isRecording(context)) {
            stop(context)
            false
        } else {
            start(context)
            true
        }
    }

    fun start(context: Context) {
        if (isRecording(context)) return
        val intent = Intent(context, AudioRecordingService::class.java)
            .setAction(AudioRecordingService.ACTION_START)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(intent)
        } else {
            context.startService(intent)
        }
        setRecording(context, true)
    }

    fun stop(context: Context) {
        if (!isRecording(context)) return
        val intent = Intent(context, AudioRecordingService::class.java)
            .setAction(AudioRecordingService.ACTION_STOP)
        context.startService(intent)
        setRecording(context, false)
    }

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
}
