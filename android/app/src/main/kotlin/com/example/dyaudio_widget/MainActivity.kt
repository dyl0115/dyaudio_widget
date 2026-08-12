package com.example.dyaudio_widget

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.example.dyaudio_widget/recorder"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        RecordingController.ensureIdleNotification(applicationContext)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasPermission" -> result.success(RecordingController.hasMicPermission(applicationContext))
                "isRecording" -> result.success(RecordingController.isRecording(applicationContext))
                "toggle" -> {
                    val newState = RecordingController.toggle(applicationContext)
                    result.success(newState)
                }
                "start" -> {
                    RecordingController.start(applicationContext)
                    result.success(true)
                }
                "stop" -> {
                    RecordingController.stop(applicationContext)
                    result.success(false)
                }
                else -> result.notImplemented()
            }
        }
    }
}
