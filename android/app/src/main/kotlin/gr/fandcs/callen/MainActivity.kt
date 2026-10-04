package gr.fandcs.callen

import android.app.AlarmManager
import android.app.NotificationManager
import android.content.ContentResolver
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.telecom.TelecomManager
import android.view.WindowManager
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val ringtoneChannelName = "gr.fandcs.callen/ringtone"
    private val fakeCallChannelName = "gr.fandcs.callen/fakecall"
    private val simChannelName = "gr.fandcs.callen/sim"
    private val callLogChannelName = "gr.fandcs.callen/calllog"
    private var ringtone: android.media.Ringtone? = null
    private var fakeCallChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (isFakeCallTrigger(intent)) allowOverLockScreen(true)
    }

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
                    // "app" (Callen's own screen, default) or "system" (device's phone UI)
                    val mode = call.argument<String>("mode") ?: FakeCallReceiver.MODE_APP
                    FakeCallReceiver.schedule(applicationContext, delaySeconds, name, number, mode)
                    result.success(null)
                }
                "cancel" -> {
                    FakeCallReceiver.cancel(applicationContext)
                    result.success(null)
                }
                "consumePending" -> {
                    result.success(consumePendingFakeCallExtras(intent))
                }
                "getStatus" -> result.success(getFakeCallStatus())
                "openSettings" -> {
                    val target = call.argument<String>("target") ?: ""
                    result.success(openFakeCallSettings(target))
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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, callLogChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "deleteEntry" -> {
                        val number = call.argument<String>("number") ?: ""
                        val timestampMs = call.argument<Long>("timestampMs") ?: 0L
                        deleteCallLogEntry(number, timestampMs)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun deleteCallLogEntry(number: String, timestampMs: Long) {
        try {
            val uri = android.provider.CallLog.Calls.CONTENT_URI
            val selection = "${android.provider.CallLog.Calls.NUMBER} = ? AND " +
                "${android.provider.CallLog.Calls.DATE} >= ? AND " +
                "${android.provider.CallLog.Calls.DATE} <= ?"
            val args = arrayOf(number, (timestampMs - 2000).toString(), (timestampMs + 2000).toString())
            contentResolver.delete(uri, selection, args)
        } catch (e: Exception) {
            // permission not granted or not available
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

    // ---------------------------------------------------------------- fake call

    /**
     * exactAlarm        : exact alarms allowed (otherwise the setAlarmClock fallback is used)
     * fullScreenIntent  : app may show the fake call screen over the lock screen (Android 14+)
     * systemCallAccount : true/false/null(unknown) - "Callen" calling account enabled,
     *                     required for mode "system"
     */
    private fun getFakeCallStatus(): Map<String, Any?> {
        val am = getSystemService(AlarmManager::class.java)
        val nm = getSystemService(NotificationManager::class.java)
        return mapOf(
            "exactAlarm" to
                (Build.VERSION.SDK_INT < Build.VERSION_CODES.S || am.canScheduleExactAlarms()),
            "fullScreenIntent" to (Build.VERSION.SDK_INT < 34 || nm.canUseFullScreenIntent()),
            "systemCallAccount" to FakeCallConnectionService.isAccountEnabled(applicationContext),
            "sdk" to Build.VERSION.SDK_INT,
        )
    }

    /** target: "exactAlarm" | "fullScreen" | "callAccount". Returns false if it could not open. */
    private fun openFakeCallSettings(target: String): Boolean {
        val pkg = Uri.parse("package:$packageName")
        val settingsIntent: Intent = when (target) {
            "exactAlarm" ->
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
                    Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, pkg)
                else null
            "fullScreen" ->
                if (Build.VERSION.SDK_INT >= 34)
                    Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT, pkg)
                else null
            "callAccount" -> {
                FakeCallConnectionService.ensureAccountRegistered(applicationContext)
                Intent(TelecomManager.ACTION_CHANGE_PHONE_ACCOUNTS)
            }
            else -> null
        } ?: return false

        return try {
            startActivity(settingsIntent)
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun isFakeCallTrigger(intent: Intent?): Boolean =
        intent?.getBooleanExtra(FakeCallReceiver.EXTRA_TRIGGER, false) == true

    private fun consumePendingFakeCallExtras(intent: Intent?): Map<String, Any>? {
        if (!isFakeCallTrigger(intent)) return null
        val name = intent?.getStringExtra(FakeCallReceiver.EXTRA_NAME) ?: ""
        val number = intent?.getStringExtra(FakeCallReceiver.EXTRA_NUMBER) ?: ""
        intent?.removeExtra(FakeCallReceiver.EXTRA_TRIGGER)
        NotificationManagerCompat.from(this).cancel(FakeCallReceiver.NOTIFICATION_ID)
        return mapOf("name" to name, "number" to number)
    }

    @Suppress("DEPRECATION")
    private fun allowOverLockScreen(enable: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(enable)
            setTurnScreenOn(enable)
        } else {
            val flags = WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            if (enable) window.addFlags(flags) else window.clearFlags(flags)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (isFakeCallTrigger(intent)) allowOverLockScreen(true)
        val extras = consumePendingFakeCallExtras(intent)
        if (extras != null) {
            fakeCallChannel?.invokeMethod("onFakeCallTriggered", extras)
        }
    }

    override fun onStop() {
        // Do not keep the app visible over the lock screen after the call screen is left.
        allowOverLockScreen(false)
        super.onStop()
    }

    // ---------------------------------------------------------------- ringtone

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
