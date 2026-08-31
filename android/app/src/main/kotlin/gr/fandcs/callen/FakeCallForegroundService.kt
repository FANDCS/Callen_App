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

        return START_STICKY
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
        val channelId = "app_background"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "Εφαρμογή στο παρασκήνιο",
                NotificationManager.IMPORTANCE_LOW,
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
        return NotificationCompat.Builder(this, channelId)
            .setContentTitle("Κλήσεις")
            .setContentText("Η εφαρμογή τρέχει στο παρασκήνιο")
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
