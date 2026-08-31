package gr.fandcs.callen

import android.content.ContentResolver
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val ringtoneChannelName = "gr.fandcs.callen/ringtone"
    private val fakeCallChannelName = "gr.fandcs.callen/fakecall"
    private val simChannelName = "gr.fandcs.callen/sim"
    private var ringtone: android.media.Ringtone? = null
    private var fakeCallChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ringtoneChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "play" -> { playRingtone(); result.success(null) }
                    "muteRingtone" -> { stopRingtoneSoundOnly(); result.success(null) }
                    "release" -> { stopRingtoneSoundOnly(); result.success(null) }
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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, simChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getSimContacts" -> result.success(readSimContacts())
                    else -> result.notImplemented()
                }
            }
    }

    private fun readSimContacts(): List<Map<String, String>> {
        val results = mutableListOf<Map<String, String>>()
        val resolver: ContentResolver = contentResolver
        try {
            val uri = Uri.parse("content://icc/adn")
            val cursor = resolver.query(uri, null, null, null, null)
            cursor?.use {
                val nameIndex = it.getColumnIndex("name")
                val numberIndex = it.getColumnIndex("number")
                while (it.moveToNext()) {
                    val name = if (nameIndex >= 0) it.getString(nameIndex) ?: "" else ""
                    val number = if (numberIndex >= 0) it.getString(numberIndex) ?: "" else ""
                    if (number.isNotBlank()) {
                        results.add(mapOf("name" to name, "number" to number))
                    }
                }
            }
        } catch (e: Exception) {
        }
        return results
    }

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

    private fun playRingtone() {
        stopRingtoneSoundOnly()
        val uri = RingtoneManager.getActualDefaultRingtoneUri(
            applicationContext,
            RingtoneManager.TYPE_RINGTONE,
        ) ?: return
        try {
            val r = RingtoneManager.getRingtone(applicationContext, uri) ?: return
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                r.audioAttributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            }
            // isLooping is left at its default (false): plays once, no repeat.
            ringtone = r
            r.play()
        } catch (e: Exception) {
        }
    }

    private fun stopRingtoneSoundOnly() {
        ringtone?.let {
            try {
                if (it.isPlaying) it.stop()
            } catch (e: Exception) {
            }
        }
        ringtone = null
    }

    override fun onDestroy() {
        stopRingtoneSoundOnly()
        super.onDestroy()
    }
}
