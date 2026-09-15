package com.example.sound_effect_2

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var audioPlayer: RealtimeAudioPlayer? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        audioPlayer = RealtimeAudioPlayer(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        audioPlayer?.close()
        audioPlayer = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
