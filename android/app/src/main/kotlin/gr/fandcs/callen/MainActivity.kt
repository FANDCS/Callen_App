package gr.fandcs.callen

import android.app.AlarmManager
import android.app.NotificationManager
import android.content.ContentResolver
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.OpenableColumns
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
    private var mediaPlayer: MediaPlayer? = null
    private var ringtoneChannel: MethodChannel? = null
    private var fakeCallChannel: MethodChannel? = null
    private var pendingAudioPick: MethodChannel.Result? = null

    companion object {
        private const val REQUEST_PICK_AUDIO = 4101

        // Γνωστοί τύποι αρχείων ήχου για το φίλτρο του επιλογέα αρχείων.
        private val AUDIO_MIME_TYPES = arrayOf(
            "audio/mpeg", "audio/mp3", "audio/mp4", "audio/m4a", "audio/x-m4a",
            "audio/aac", "audio/x-aac", "audio/wav", "audio/x-wav", "audio/wave",
            "audio/ogg", "audio/opus", "audio/flac", "audio/x-flac", "audio/amr",
            "audio/3gpp", "audio/3gpp2", "audio/midi", "audio/x-midi", "audio/webm",
            "audio/x-ms-wma", "application/ogg",
        )
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (isFakeCallTrigger(intent)) allowOverLockScreen(true)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        ringtoneChannel =
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ringtoneChannelName)
        ringtoneChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                // Ήχος χτυπήματος κλήσης: ο κανονικός προεπιλεγμένος ήχος της συσκευής
                "play" -> {
                    playRingtone()
                    result.success(null)
                }
                // Όσο η κλήση είναι ενεργή: παίζει το αρχείο ήχου (σε επανάληψη ή μία φορά)
                "playCallAudio" -> {
                    result.success(
                        playCallAudio(
                            call.argument<String>("uri") ?: "",
                            call.argument<Boolean>("loop") ?: true,
                        )
                    )
                }
                "muteRingtone", "release" -> {
                    stopRingtoneSoundOnly()
                    result.success(null)
                }
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
                "pickAudio" -> pickAudioFile(result)
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

    // ---------------------------------------------------------------- audio file picker

    @Suppress("DEPRECATION")
    private fun pickAudioFile(result: MethodChannel.Result) {
        if (pendingAudioPick != null) {
            result.error("busy", "An audio pick is already in progress", null)
            return
        }
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(Intent.EXTRA_MIME_TYPES, AUDIO_MIME_TYPES)
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
            )
        }
        pendingAudioPick = result
        try {
            startActivityForResult(intent, REQUEST_PICK_AUDIO)
        } catch (e: Exception) {
            pendingAudioPick = null
            result.success(null)
        }
    }

    @Suppress("DEPRECATION", "OVERRIDE_DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != REQUEST_PICK_AUDIO) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }
        val pending = pendingAudioPick ?: return
        pendingAudioPick = null
        val uri = if (resultCode == RESULT_OK) data?.data else null
        if (uri == null) {
            pending.success(null)
            return
        }
        // Κρατάμε πρόσβαση στο αρχείο ώστε να παίζει και μετά από επανεκκίνηση.
        try {
            contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
        } catch (e: Exception) {
        }
        pending.success(mapOf("uri" to uri.toString(), "name" to displayNameOf(uri)))
    }

    private fun displayNameOf(uri: Uri): String {
        try {
            contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use {
                if (it.moveToFirst()) {
                    val idx = it.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (idx >= 0) return it.getString(idx) ?: ""
                }
            }
        } catch (e: Exception) {
        }
        return uri.lastPathSegment ?: "audio"
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

    /** Ήχος χτυπήματος: ο προεπιλεγμένος ήχος κλήσης της συσκευής, μία φορά. */
    private fun playRingtone() {
        stopRingtoneSoundOnly()
        playDefaultRingtone()
    }

    /**
     * Όσο η κλήση είναι ενεργή. loop = true: επανάληψη μέχρι τέλος κλήσης.
     * loop = false: παίζει μία φορά και στέλνει "audioCompleted" στο τέλος.
     */
    private fun playCallAudio(uriString: String, loop: Boolean): Boolean {
        stopRingtoneSoundOnly()
        if (uriString.isEmpty()) return false
        val onDone: (() -> Unit)? =
            if (loop) null else { { ringtoneChannel?.invokeMethod("audioCompleted", null) } }
        return startCustomAudio(Uri.parse(uriString), loop, onFinished = onDone)
    }

    private fun startCustomAudio(uri: Uri, loop: Boolean, onFinished: (() -> Unit)?): Boolean {
        var player: MediaPlayer? = null
        return try {
            player = MediaPlayer()
            player.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            )
            player.setDataSource(applicationContext, uri)
            player.isLooping = loop
            if (onFinished != null) {
                player.setOnCompletionListener { onFinished() }
            }
            player.prepare()
            player.start()
            mediaPlayer = player
            true
        } catch (e: Exception) {
            player?.release()
            false
        }
    }

    private fun playDefaultRingtone() {
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

        mediaPlayer?.let {
            try {
                it.stop()
            } catch (e: Exception) {
            }
            it.release()
        }
        mediaPlayer = null
    }

    override fun onDestroy() {
        stopRingtoneSoundOnly()
        super.onDestroy()
    }
}
