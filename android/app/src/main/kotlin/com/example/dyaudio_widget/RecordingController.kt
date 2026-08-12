package com.example.dyaudio_widget

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.ContextCompat

/**
 * Single source of truth for recording state. The home screen widget, the in-app
 * toggle and the notification all go through here so they always agree on state.
 */
object RecordingController {
    private const val PREFS_NAME = "audio_widget_prefs"
    private const val KEY_IS_RECORDING = "is_recording"

    fun hasMicPermission(context: Context): Boolean {
        return ContextCompat.checkSelfPermission(
            context,
            android.Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED
    }

    fun isRecording(context: Context): Boolean {
        return prefs(context).getBoolean(KEY_IS_RECORDING, false)
    }

    /**
     * Brings the service up in its idle state so the lock-screen notification exists and,
     * more importantly, so later starts are messages to a running service rather than a
     * background service start (which Android 14+ rejects for microphone). Only safe to
     * call while the app is in the foreground — i.e. from the app being opened.
     */
    fun arm(context: Context) {
        if (!hasMicPermission(context) || isRecording(context)) return
        val intent = Intent(context, AudioRecordingService::class.java)
            .setAction(AudioRecordingService.ACTION_ARM)
        startService(context, intent)
    }

    fun setRecording(context: Context, recording: Boolean) {
        prefs(context).edit().putBoolean(KEY_IS_RECORDING, recording).apply()
        AudioWidgetProvider.updateAllWidgets(context)
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
        startService(context, intent)
        setRecording(context, true)
    }

    fun stop(context: Context) {
        if (!isRecording(context)) return
        val intent = Intent(context, AudioRecordingService::class.java)
            .setAction(AudioRecordingService.ACTION_STOP)
        startService(context, intent)
        setRecording(context, false)
    }

    private fun startService(context: Context, intent: Intent) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(intent)
        } else {
            context.startService(intent)
        }
    }

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
}
