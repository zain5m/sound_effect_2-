package com.example.sound_effect_2

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.os.Process
import android.os.SystemClock
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.ArrayDeque

class RealtimeAudioPlayer(private val context: Context, messenger: BinaryMessenger) :
    MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private val channel = MethodChannel(messenger, "sound_effect_2/realtime_audio")
    private val events = EventChannel(messenger, "sound_effect_2/realtime_audio/events")
    private val main = Handler(Looper.getMainLooper())
    private val thread = HandlerThread("PitchSpeedAudio", Process.THREAD_PRIORITY_AUDIO).apply { start() }
    private val worker = Handler(thread.looper)
    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val attributes = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_MEDIA)
        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build()
    private var sink: EventChannel.EventSink? = null
    private var track: AudioTrack? = null
    private var handle = 0L
    private var session = 0L
    private var sampleRate = 44100
    private var channelCount = 2
    private var sourceFrames = 0
    private var sourcePosition = 0.0
    private var playing = false
    private var completed = false
    private var draining = false
    private var resumeOnFocusGain = false
    private var focusRequest: AudioFocusRequest? = null
    private var lastEventTime = 0L
    private val output = FloatArray(1024)
    private val timing = DoubleArray(2)
    private var pendingFrames = 0
    private var pendingOffset = 0
    private var writtenFrames = 0L
    private var headWrap = 0L
    private var lastHead = 0L
    private var closed = false
    @Volatile private var parameters = Pair(1.0, 0.0)

    private data class PositionSpan(val start: Long, val frames: Int, val from: Double, val to: Double)
    private val positions = ArrayDeque<PositionSpan>()

    private val updateParameters = Runnable {
        val values = parameters
        if (handle != 0L) nativeSetParameters(handle, values.first, values.second)
    }
    private val pump = object : Runnable {
        override fun run() {
            if (!playing || handle == 0L) return
            try {
                val player = track ?: return
                if (pendingFrames == 0 && !draining) {
                    pendingFrames = nativeRender(handle, output, timing)
                    pendingOffset = 0
                    draining = pendingFrames == 0
                }
                var written = 0
                if (pendingFrames > 0) {
                    written = player.write(output, pendingOffset * channelCount,
                        (pendingFrames - pendingOffset) * channelCount, AudioTrack.WRITE_NON_BLOCKING)
                    check(written >= 0) { "Audio output failed ($written)" }
                    val frames = written / channelCount
                    if (frames > 0) {
                        val delta = timing[1] - timing[0]
                        positions.add(PositionSpan(writtenFrames, frames,
                            timing[0] + delta * pendingOffset / pendingFrames,
                            timing[0] + delta * (pendingOffset + frames) / pendingFrames))
                        writtenFrames += frames
                        pendingOffset += frames
                        if (pendingOffset == pendingFrames) pendingFrames = 0
                    }
                }
                val played = updatePosition()
                if (draining && played >= writtenFrames) {
                    sourcePosition = sourceFrames.toDouble()
                    playing = false
                    completed = true
                    player.pause()
                    abandonFocus()
                    publish()
                    return
                }
                if (SystemClock.elapsedRealtime() - lastEventTime >= 50) publish()
                if (written > 0) worker.post(this) else worker.postDelayed(this, 4)
            } catch (error: Exception) {
                releasePlayer()
                publish(error.message ?: "Audio playback failed")
            }
        }
    }

    private val focusListener = AudioManager.OnAudioFocusChangeListener { change ->
        worker.post {
            when (change) {
                AudioManager.AUDIOFOCUS_GAIN -> {
                    track?.setVolume(1f)
                    if (resumeOnFocusGain && handle != 0L) {
                        resumeOnFocusGain = false
                        startPlayback(false)
                    }
                }
                AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK -> track?.setVolume(0.2f)
                AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> {
                    val resume = playing
                    pausePlayback(false)
                    resumeOnFocusGain = resume
                }
                AudioManager.AUDIOFOCUS_LOSS -> pausePlayback(true)
            }
        }
    }
    private val noisyReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == AudioManager.ACTION_AUDIO_BECOMING_NOISY) {
                worker.post { pausePlayback(true) }
            }
        }
    }

    init {
        channel.setMethodCallHandler(this)
        events.setStreamHandler(this)
        val filter = IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY)
        if (Build.VERSION.SDK_INT >= 33) {
            context.registerReceiver(noisyReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            context.registerReceiver(noisyReceiver, filter)
        }
    }

    override fun onListen(arguments: Any?, eventSink: EventChannel.EventSink) {
        sink = eventSink
        worker.post { publish() }
    }

    override fun onCancel(arguments: Any?) { sink = null }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (closed) {
            result.error("disposed", "Audio engine is closed", null)
            return
        }
        if (call.method == "setParameters") {
            val speed = call.argument<Number>("speed")?.toDouble() ?: 1.0
            val pitch = call.argument<Number>("pitch")?.toDouble() ?: 0.0
            if (!speed.isFinite() || speed !in 0.5..2.0 || !pitch.isFinite() || pitch !in -12.0..12.0) {
                result.error("parameters", "Invalid pitch or speed", null)
                return
            }
            parameters = Pair(speed, pitch)
            worker.removeCallbacks(updateParameters)
            worker.post(updateParameters)
            result.success(null)
            return
        }
        if (call.method !in setOf("load", "play", "pause", "seek", "stop", "dispose")) {
            result.notImplemented()
            return
        }
        worker.post {
            try {
                val id = call.argument<Number>("id")?.toLong() ?: session
                when (call.method) {
                    "load" -> load(call, id)
                    "stop", "dispose" -> { releasePlayer(); session = id; publish() }
                    else -> if (id == session) {
                        when (call.method) {
                            "play" -> startPlayback(true)
                            "pause" -> pausePlayback(true)
                            "seek" -> seek(call.argument<Number>("positionUs")?.toLong() ?: 0L)
                        }
                    }
                }
                main.post { result.success(null) }
            } catch (error: Throwable) {
                releasePlayer()
                publish()
                main.post { result.error("audio", error.message ?: "Audio engine failed", null) }
            }
        }
    }

    private fun load(call: MethodCall, id: Long) {
        releasePlayer()
        session = id
        System.loadLibrary("stretch")
        val data = call.argument<List<ByteArray>>("channels") ?: error("Missing PCM data")
        sampleRate = call.argument<Int>("sampleRate") ?: error("Missing sample rate")
        sourceFrames = call.argument<Int>("frames") ?: error("Missing frame count")
        channelCount = data.size
        val speed = call.argument<Number>("speed")?.toDouble() ?: 1.0
        val pitch = call.argument<Number>("pitch")?.toDouble() ?: 0.0
        handle = nativeCreate(data.toTypedArray(), sampleRate, sourceFrames, speed, pitch)
        check(handle != 0L) { "Could not create audio processor" }
        val mask = if (channelCount == 1) AudioFormat.CHANNEL_OUT_MONO else AudioFormat.CHANNEL_OUT_STEREO
        val minimum = AudioTrack.getMinBufferSize(sampleRate, mask, AudioFormat.ENCODING_PCM_FLOAT)
        check(minimum > 0) { "Float PCM output is unavailable" }
        val builder = AudioTrack.Builder().setAudioAttributes(attributes)
            .setAudioFormat(AudioFormat.Builder().setEncoding(AudioFormat.ENCODING_PCM_FLOAT)
                .setSampleRate(sampleRate).setChannelMask(mask).build())
            .setTransferMode(AudioTrack.MODE_STREAM)
            .setBufferSizeInBytes(maxOf(minimum, 1024 * channelCount * 4))
        if (Build.VERSION.SDK_INT >= 26) builder.setPerformanceMode(AudioTrack.PERFORMANCE_MODE_LOW_LATENCY)
        track = builder.build()
        check(track?.state == AudioTrack.STATE_INITIALIZED) { "Could not initialize audio output" }
        publish()
    }

    private fun requestFocus() {
        val granted = if (Build.VERSION.SDK_INT >= 26) {
            val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                .setAudioAttributes(attributes).setOnAudioFocusChangeListener(focusListener, worker).build()
            focusRequest = request
            audioManager.requestAudioFocus(request)
        } else {
            @Suppress("DEPRECATION")
            audioManager.requestAudioFocus(focusListener, AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN)
        }
        check(granted == AudioManager.AUDIOFOCUS_REQUEST_GRANTED) { "Audio focus is unavailable" }
    }

    private fun abandonFocus() {
        if (Build.VERSION.SDK_INT >= 26) {
            focusRequest?.let { audioManager.abandonAudioFocusRequest(it) }
            focusRequest = null
        } else {
            @Suppress("DEPRECATION")
            audioManager.abandonAudioFocus(focusListener)
        }
        resumeOnFocusGain = false
    }

    private fun startPlayback(acquireFocus: Boolean) {
        if (handle == 0L || playing) return
        if (acquireFocus) requestFocus()
        if (completed || sourcePosition >= sourceFrames) seek(0)
        playing = true
        completed = false
        track?.setVolume(1f)
        track?.play()
        worker.removeCallbacks(pump)
        worker.post(pump)
        publish()
    }

    private fun pausePlayback(abandon: Boolean) {
        worker.removeCallbacks(pump)
        track?.pause()
        updatePosition()
        playing = false
        if (abandon) abandonFocus()
        publish()
    }

    private fun seek(positionUs: Long) {
        if (handle == 0L) return
        val frame = (positionUs.toDouble() * sampleRate / 1000000).toLong()
            .coerceIn(0L, sourceFrames.toLong()).toInt()
        worker.removeCallbacks(pump)
        track?.pause()
        track?.flush()
        nativeSeek(handle, frame)
        clearQueue()
        sourcePosition = frame.toDouble()
        if (playing) {
            track?.play()
            worker.post(pump)
        }
        publish()
    }

    private fun updatePosition(): Long {
        val head = (track?.playbackHeadPosition ?: 0).toLong() and 0xffffffffL
        if (head < lastHead) headWrap += 1L shl 32
        lastHead = head
        val played = headWrap + head
        while (positions.isNotEmpty() && played >= positions.first.start + positions.first.frames) {
            sourcePosition = positions.removeFirst().to
        }
        positions.peekFirst()?.let {
            val fraction = ((played - it.start).toDouble() / it.frames).coerceIn(0.0, 1.0)
            sourcePosition = it.from + (it.to - it.from) * fraction
        }
        return played
    }

    private fun clearQueue() {
        positions.clear()
        pendingFrames = 0
        pendingOffset = 0
        writtenFrames = 0
        lastHead = 0
        headWrap = 0
        draining = false
        completed = false
    }

    private fun releasePlayer() {
        worker.removeCallbacks(pump)
        playing = false
        val player = track
        track = null
        if (player != null) {
            runCatching { player.pause(); player.flush() }
            runCatching { player.release() }
        }
        if (handle != 0L) nativeDestroy(handle)
        handle = 0L
        sourceFrames = 0
        sourcePosition = 0.0
        clearQueue()
        abandonFocus()
    }

    private fun publish(error: String? = null) {
        lastEventTime = SystemClock.elapsedRealtime()
        val state = mapOf("id" to session, "playing" to playing, "loaded" to (handle != 0L),
            "completed" to completed, "positionUs" to (sourcePosition * 1000000 / sampleRate).toLong(),
            "durationUs" to (sourceFrames.toLong() * 1000000 / sampleRate), "error" to error)
        main.post { sink?.success(state) }
    }

    fun close() {
        if (closed) return
        closed = true
        channel.setMethodCallHandler(null)
        events.setStreamHandler(null)
        sink = null
        context.unregisterReceiver(noisyReceiver)
        worker.post { releasePlayer(); thread.quitSafely() }
    }

    private external fun nativeCreate(data: Array<ByteArray>, sampleRate: Int, frames: Int, speed: Double, pitch: Double): Long
    private external fun nativeDestroy(handle: Long)
    private external fun nativeSetParameters(handle: Long, speed: Double, pitch: Double)
    private external fun nativeSeek(handle: Long, frame: Int)
    private external fun nativeRender(handle: Long, output: FloatArray, timing: DoubleArray): Int
}
