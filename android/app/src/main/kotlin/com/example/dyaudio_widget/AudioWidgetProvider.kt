package com.example.dyaudio_widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class AudioWidgetProvider : AppWidgetProvider() {

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_TOGGLE_RECORDING) {
            val newState = RecordingController.toggle(context)
            if (newState == null) {
                // No mic permission yet: open the app so the user can grant it.
                val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                launchIntent?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                launchIntent?.let { context.startActivity(it) }
            }
            updateAllWidgets(context)
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, buildRemoteViews(context))
        }
    }

    companion object {
        const val ACTION_TOGGLE_RECORDING = "com.example.dyaudio_widget.ACTION_TOGGLE_RECORDING"

        fun updateAllWidgets(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, AudioWidgetProvider::class.java))
            for (id in ids) {
                manager.updateAppWidget(id, buildRemoteViews(context))
            }
        }

        private fun buildRemoteViews(context: Context): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.audio_widget)

            val hasPermission = RecordingController.hasMicPermission(context)
            val isRecording = hasPermission && RecordingController.isRecording(context)

            val (cardBg, badgeBg, label) = when {
                !hasPermission -> Triple(
                    R.drawable.widget_card_no_permission,
                    R.drawable.icon_badge_no_permission,
                    context.getString(R.string.audio_widget_label_no_permission)
                )
                isRecording -> Triple(
                    R.drawable.widget_card_recording,
                    R.drawable.icon_badge_recording,
                    context.getString(R.string.audio_widget_label_recording)
                )
                else -> Triple(
                    R.drawable.widget_card_idle,
                    R.drawable.icon_badge_idle,
                    context.getString(R.string.audio_widget_label_idle)
                )
            }
            views.setInt(R.id.widget_root, "setBackgroundResource", cardBg)
            views.setInt(R.id.widget_icon_badge, "setBackgroundResource", badgeBg)
            views.setTextViewText(R.id.widget_label, label)

            val toggleIntent = Intent(context, AudioWidgetProvider::class.java)
                .setAction(ACTION_TOGGLE_RECORDING)
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                0,
                toggleIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

            return views
        }
    }
}
