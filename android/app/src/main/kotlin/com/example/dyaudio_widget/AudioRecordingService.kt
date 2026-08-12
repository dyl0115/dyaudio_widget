package com.example.dyaudio_widget

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.media.MediaRecorder
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Stays alive as a foreground service even while idle ("armed"), so that starting
 * capture later is just a message to an already-running service.
 *
 * This matters because Android 14+ refuses to start a microphone foreground service
 * while the app is in the background — which is exactly the situation when the trigger
 * comes from the lock screen. Arming happens when the app is opened (foreground, so
 * it's allowed), and the while-in-use grant then lives with the service, the same way
 * a voice recorder keeps recording after you lock the phone.
 */
class AudioRecordingService : Service() {

    private var recorder: MediaRecorder? = null
    private var lastError: String? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Always (re-)enter the foreground first: on the arm path this is what captures
        // the while-in-use grant, and on later paths it's a no-op refresh.
        enterForeground()

        when (intent?.action) {
            ACTION_START -> {
                startRecording()
                RecordingController.setRecording(applicationContext, recorder != null)
            }
            ACTION_STOP -> {
                stopRecording()
                RecordingController.setRecording(applicationContext, false)
            }
            // ACTION_ARM, and the null intent redelivered when START_STICKY restarts us,
            // both just mean "stay alive, idle" — never start capture off a null intent.
            else -> RecordingController.setRecording(applicationContext, false)
        }
        refreshNotification()
        return START_STICKY
    }

    override fun onDestroy() {
        stopRecording()
        super.onDestroy()
    }

    private fun enterForeground() {
        val serviceType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
        } else {
            0
        }
        try {
            ServiceCompat.startForeground(this, NOTIFICATION_ID, buildNotification(), serviceType)
        } catch (e: Exception) {
            // Surface it in the notification instead of dying silently, so the failure
            // is readable on the device without a debugger attached.
            lastError = e.javaClass.simpleName + ": " + e.message
        }
    }

    private fun refreshNotification() {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(NOTIFICATION_ID, buildNotification())
    }

    private fun startRecording() {
        if (recorder != null) return
        val dir = File(getExternalFilesDir(null), "recordings")
        if (!dir.exists()) dir.mkdirs()
        val fileName = "REC_" + SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date()) + ".m4a"
        val outputFile = File(dir, fileName)

        try {
            val mr = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                MediaRecorder(this)
            } else {
                @Suppress("DEPRECATION")
                MediaRecorder()
            }
            mr.setAudioSource(MediaRecorder.AudioSource.MIC)
            // Pin capture to the built-in mic even if a Bluetooth audio device is
            // connected, since SCO/HFP mic input is narrowband and sounds much worse.
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                audioManager.getDevices(AudioManager.GET_DEVICES_INPUTS)
                    .firstOrNull { it.type == AudioDeviceInfo.TYPE_BUILTIN_MIC }
                    ?.let { mr.setPreferredDevice(it) }
            }
            mr.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            mr.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            mr.setOutputFile(outputFile.absolutePath)
            mr.prepare()
            mr.start()
            recorder = mr
            lastError = null
        } catch (e: Exception) {
            recorder?.release()
            recorder = null
            lastError = e.javaClass.simpleName + ": " + e.message
        }
    }

    private fun stopRecording() {
        recorder?.let {
            try {
                it.stop()
            } catch (e: Exception) {
                // recording may be too short or already stopped; ignore
            } finally {
                it.release()
            }
        }
        recorder = null
    }

    private fun buildNotification(): Notification {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channel = NotificationChannel(
                CHANNEL_ID,
                "dyaudio",
                NotificationManager.IMPORTANCE_LOW
            )
            manager.createNotificationChannel(channel)
        }

        val active = recorder != null
        val action = if (active) ACTION_STOP else ACTION_START
        val intent = Intent(this, AudioRecordingService::class.java).setAction(action)
        val pendingIntent = PendingIntent.getService(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // The body must open the app rather than toggle: tapping a notification's body
        // on the lock screen always forces authentication, whereas its action buttons
        // fire without unlocking. So the toggle lives only on the button.
        val contentIntent = PendingIntent.getActivity(
            this, 2, Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val label = if (active) "종료" else "시작"
        val text = lastError ?: if (active) "진행 중 · 버튼으로 종료" else "버튼으로 시작"

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("dyaudio")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_menu_edit)
            .setOngoing(true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(contentIntent)
            .addAction(0, label, pendingIntent)
            .build()
    }

    companion object {
        const val ACTION_ARM = "com.example.dyaudio_widget.action.ARM"
        const val ACTION_START = "com.example.dyaudio_widget.action.START"
        const val ACTION_STOP = "com.example.dyaudio_widget.action.STOP"
        private const val CHANNEL_ID = "audio_recording_channel"
        private const val NOTIFICATION_ID = 42
    }
}
