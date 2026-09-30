package gr.fandcs.callen

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

/**
 * Fires when the AlarmManager alarm of a scheduled fake call goes off.
 * Because it is driven by AlarmManager (not by a running service), the app can be
 * closed / swiped away after scheduling and the fake call will still happen.
 */
class FakeCallReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val name = intent.getStringExtra(EXTRA_NAME) ?: ""
        val number = intent.getStringExtra(EXTRA_NUMBER) ?: ""
        val mode = intent.getStringExtra(EXTRA_MODE) ?: MODE_APP

        if (mode == MODE_SYSTEM) {
            // Device's own phone UI. If it is not possible, fall back to the in-app screen.
            if (FakeCallConnectionService.tryIncomingCall(context, name, number)) return
        }
        showAppCall(context, name, number)
    }

    companion object {
        const val MODE_APP = "app"
        const val MODE_SYSTEM = "system"

        const val EXTRA_NAME = "fake_call_name"
        const val EXTRA_NUMBER = "fake_call_number"
        const val EXTRA_TRIGGER = "fake_call_trigger"
        const val EXTRA_MODE = "fake_call_mode"

        const val NOTIFICATION_ID = 5931
        private const val REQUEST_CODE = 5931
        private const val CHANNEL_ID = "fake_call_incoming"

        private fun alarmIntent(
            context: Context,
            name: String,
            number: String,
            mode: String,
        ): PendingIntent {
            val intent = Intent(context, FakeCallReceiver::class.java).apply {
                putExtra(EXTRA_NAME, name)
                putExtra(EXTRA_NUMBER, number)
                putExtra(EXTRA_MODE, mode)
            }
            return PendingIntent.getBroadcast(
                context,
                REQUEST_CODE,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        fun schedule(
            context: Context,
            delaySeconds: Int,
            name: String,
            number: String,
            mode: String,
        ) {
            cancel(context)
            if (mode == MODE_SYSTEM) FakeCallConnectionService.ensureAccountRegistered(context)

            val am = context.getSystemService(AlarmManager::class.java)
            val triggerAt = System.currentTimeMillis() + delaySeconds * 1000L
            val pending = alarmIntent(context, name, number, mode)

            var scheduled = false
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S || am.canScheduleExactAlarms()) {
                try {
                    am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pending)
                    scheduled = true
                } catch (e: SecurityException) {
                    // exact alarm permission revoked in the meantime -> fallback below
                }
            }
            if (!scheduled) {
                // setAlarmClock needs no special permission and is exact even in Doze.
                // Downside: the system shows an "alarm" icon in the status bar until it fires.
                val show = PendingIntent.getActivity(
                    context,
                    REQUEST_CODE,
                    Intent(context, MainActivity::class.java),
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
                am.setAlarmClock(AlarmManager.AlarmClockInfo(triggerAt, show), pending)
            }
        }

        fun cancel(context: Context) {
            val am = context.getSystemService(AlarmManager::class.java)
            am.cancel(alarmIntent(context, "", "", MODE_APP))
            NotificationManagerCompat.from(context).cancel(NOTIFICATION_ID)
        }

        /**
         * Shows the in-app (Flutter) fake call screen.
         * From the background Android blocks startActivity(), so we post a full-screen-intent
         * notification (the same mechanism real call apps use). startActivity() is still
         * attempted for the case where the app is in the foreground.
         */
        fun showAppCall(context: Context, name: String, number: String) {
            val launch = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
                putExtra(EXTRA_NAME, name)
                putExtra(EXTRA_NUMBER, number)
                putExtra(EXTRA_TRIGGER, true)
            }
            val pending = PendingIntent.getActivity(
                context,
                REQUEST_CODE,
                launch,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    "Εισερχόμενη κλήση",
                    NotificationManager.IMPORTANCE_HIGH,
                ).apply {
                    setSound(null, null) // the Flutter screen plays the ringtone itself
                    enableVibration(false)
                    lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
                }
                context.getSystemService(NotificationManager::class.java)
                    .createNotificationChannel(channel)
            }

            val title = when {
                name.isNotBlank() -> name
                number.isNotBlank() -> number
                else -> "Άγνωστος αριθμός"
            }
            val notification = NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.sym_call_incoming)
                .setContentTitle(title)
                .setContentText("Εισερχόμενη κλήση")
                .setCategory(NotificationCompat.CATEGORY_CALL)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setOngoing(true)
                .setAutoCancel(true)
                .setTimeoutAfter(60_000L)
                .setContentIntent(pending)
                .setFullScreenIntent(pending, true)
                .build()

            try {
                NotificationManagerCompat.from(context).notify(NOTIFICATION_ID, notification)
            } catch (e: SecurityException) {
                // POST_NOTIFICATIONS not granted
            }

            try {
                context.startActivity(launch)
            } catch (e: Exception) {
                // blocked in background -> the full-screen notification handles it
            }
        }
    }
}
