    package gr.fandcs.callen

    import android.content.BroadcastReceiver
    import android.content.Context
    import android.content.Intent

    class FakeCallReceiver : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val launchIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
                putExtra("fake_call_name", intent.getStringExtra("fake_call_name"))
                putExtra(
                    "fake_call_number",
                    intent.getStringExtra("fake_call_number"),
                )
                putExtra("fake_call_trigger", true)
            }
            context.startActivity(launchIntent)
        }
    }
