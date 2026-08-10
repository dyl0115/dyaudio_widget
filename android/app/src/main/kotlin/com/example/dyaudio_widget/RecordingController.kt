package com.example.dyaudio_widget

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.ContextCompat

/**
 * Single source of truth for recording state. Both the home screen widget
 * and the in-app toggle go through here so they always agree on state.
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

    private fun setRecording(context: Context, recording: Boolean) {
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
