package com.example.dyaudio_widget

import android.app.Activity
import android.os.Build
import android.os.Bundle

/**
 * Invisible activity that exists only so recording can be toggled from the lock screen.
 *
 * Android 14+ throws a SecurityException if a microphone foreground service is started
 * while the app is in the background, which is what happened when the notification
 * targeted the service directly. Bouncing through an activity fixes both halves of the
 * problem: showWhenLocked lets it come up over the keyguard without unlocking, and
 * having a visible activity puts the app in the foreground so the service start is
 * allowed. It finishes immediately, so nothing is actually drawn.
 */
class RecordingTriggerActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        }
        RecordingController.toggle(applicationContext)
        finish()
    }
}
