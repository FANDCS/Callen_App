package gr.fandcs.callen

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat

/**
 * Foreground service: κρατάει τη διεργασία "ζωντανή" όσο μετράει
 * αντίστροφα η ψεύτικη κλήση, με μια μόνιμη ειδοποίηση — αυτό
 * αποτρέπει το Android/Samsung από το να "κοιμίσει" την εφαρμογή στο
 * background πριν προλάβει να χτυπήσει η κλήση (κάτι που απλό
 * AlarmManager δεν εγγυάται σε Samsung λόγω επιθετικού battery
 * management).
 */
class FakeCallForegroundService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private var pendingRunnable: Runnable? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val delaySeconds = intent?.getIntExtra("delaySeconds", 15) ?: 15
        val name = intent?.getStringExtra("name") ?: ""
        val number = intent?.getStringExtra("number") ?: ""

        startForeground(NOTIFICATION_ID, buildNotification())

        pendingRunnable?.let { handler.removeCallbacks(it) }
        val runnable = Runnable { triggerFakeCall(name, number) }
        pendingRunnable = runnable
        handler.postDelayed(runnable, delaySeconds * 1000L)

        return START_NOT_STICKY
    }

    private fun triggerFakeCall(name: String, number: String) {
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
            putExtra("fake_call_name", name)
            putExtra("fake_call_number", number)
            putExtra("fake_call_trigger", true)
        }
        startActivity(launchIntent)
        stopSelf()
    }

    private fun buildNotification(): android.app.Notification {
        val channelId = "fake_call_pending"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "Ψεύτικη κλήση σε αναμονή",
                NotificationManager.IMPORTANCE_LOW,
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
        return NotificationCompat.Builder(this, channelId)
            .setContentTitle("Ψεύτικη κλήση προγραμματισμένη")
            .setContentText("Η εφαρμογή παραμένει ενεργή μέχρι να χτυπήσει.")
            .setSmallIcon(android.R.drawable.sym_call_incoming)
            .setOngoing(true)
            .build()
    }

    override fun onDestroy() {
        pendingRunnable?.let { handler.removeCallbacks(it) }
        super.onDestroy()
    }

    companion object {
        private const val NOTIFICATION_ID = 5931
    }
}
