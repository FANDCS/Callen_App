package gr.fandcs.callen

import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.Ringtone
import android.media.RingtoneManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val ringtoneChannelName = "gr.fandcs.callen/ringtone"
    private val fakeCallChannelName = "gr.fandcs.callen/fakecall"
    private var ringtone: Ringtone? = null
    private var audioFocusRequest: AudioFocusRequest? = null
    private var fakeCallChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ringtoneChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "play" -> { playRingtone(); result.success(null) }
                    "muteRingtone" -> { muteRingtoneOnly(); result.success(null) }
                    "release" -> { releaseRingtone(); result.success(null) }
                    else -> result.notImplemented()
                }
            }

        fakeCallChannel =
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, fakeCallChannelName)
        fakeCallChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "schedule" -> {
                    val delaySeconds = call.argument<Int>("delaySeconds") ?: 15
                    val name = call.argument<String>("name") ?: ""
                    val number = call.argument<String>("number") ?: ""
                    scheduleFakeCall(delaySeconds, name, number)
                    result.success(null)
                }
                "cancel" -> {
                    cancelFakeCall()
                    result.success(null)
                }
                "consumePending" -> {
                    result.success(consumePendingFakeCallExtras(intent))
                }
                else -> result.notImplemented()
            }
        }
    }

    // --- Ψεύτικη κλήση: scheduling μέσω AlarmManager (δουλεύει και με
    // την εφαρμογή στο background, όχι μόνο foreground) ---

    private fun scheduleFakeCall(delaySeconds: Int, name: String, number: String) {
        val serviceIntent = Intent(this, FakeCallForegroundService::class.java).apply {
            putExtra("delaySeconds", delaySeconds)
            putExtra("name", name)
            putExtra("number", number)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }
    }

    private fun cancelFakeCall() {
        stopService(Intent(this, FakeCallForegroundService::class.java))
    }

    /** Διαβάζει (και καθαρίζει) τα extras ενός "fake call" intent, αν υπάρχουν. */
    private fun consumePendingFakeCallExtras(intent: Intent?): Map<String, Any>? {
        if (intent?.getBooleanExtra("fake_call_trigger", false) != true) return null
        val name = intent.getStringExtra("fake_call_name") ?: ""
        val number = intent.getStringExtra("fake_call_number") ?: ""
        intent.removeExtra("fake_call_trigger")
        return mapOf("name" to name, "number" to number)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val extras = consumePendingFakeCallExtras(intent)
        if (extras != null) {
            fakeCallChannel?.invokeMethod("onFakeCallTriggered", extras)
        }
    }

    // --- Ήχος κλήσης (όπως πριν) ---

    private fun requestExclusiveAudioFocus() {
        val audioManager = getSystemService(AUDIO_SERVICE) as AudioManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val attrs = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            val req = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE)
                .setAudioAttributes(attrs)
                .setWillPauseWhenDucked(true)
                .build()
            audioFocusRequest = req
            audioManager.requestAudioFocus(req)
        } else {
            @Suppress("DEPRECATION")
            audioManager.requestAudioFocus(
                null,
                AudioManager.STREAM_RING,
                AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE,
            )
        }
    }

    private fun abandonAudioFocus() {
        val audioManager = getSystemService(AUDIO_SERVICE) as AudioManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            audioFocusRequest?.let { audioManager.abandonAudioFocusRequest(it) }
        } else {
            @Suppress("DEPRECATION")
            audioManager.abandonAudioFocus(null)
        }
        audioFocusRequest = null
    }

    private fun playRingtone() {
        stopRingtoneSoundOnly()
        requestExclusiveAudioFocus()
        val uri = RingtoneManager.getActualDefaultRingtoneUri(
            applicationContext,
            RingtoneManager.TYPE_RINGTONE,
        )
        if (uri != null) {
            ringtone = RingtoneManager.getRingtone(applicationContext, uri)
            ringtone?.audioAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                ringtone?.isLooping = true
            }
            ringtone?.play()
        }
    }

    private fun stopRingtoneSoundOnly() {
        ringtone?.let { if (it.isPlaying) it.stop() }
        ringtone = null
    }

    private fun muteRingtoneOnly() {
        stopRingtoneSoundOnly()
    }

    private fun releaseRingtone() {
        stopRingtoneSoundOnly()
        abandonAudioFocus()
    }

    override fun onDestroy() {
        releaseRingtone()
        super.onDestroy()
    }
}
