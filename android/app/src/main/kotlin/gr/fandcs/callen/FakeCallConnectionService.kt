package gr.fandcs.callen

import android.content.ComponentName
import android.content.Context
import android.net.Uri
import android.os.Bundle
import android.telecom.Connection
import android.telecom.ConnectionRequest
import android.telecom.ConnectionService
import android.telecom.DisconnectCause
import android.telecom.PhoneAccount
import android.telecom.PhoneAccountHandle
import android.telecom.TelecomManager

/**
 * The "Callen" phone account is registered ONLY while a fake call is scheduled
 * or active, and unregistered as soon as the call ends / is rejected.
 *
 * This way it never shows up in the SIM picker during normal outgoing calls.
 */
class FakeCallConnectionService : ConnectionService() {

    override fun onCreateIncomingConnection(
        connectionManagerPhoneAccount: PhoneAccountHandle?,
        request: ConnectionRequest?,
    ): Connection {
        val (name, number) = readCaller(request)
        return FakeConnection(applicationContext, name, number).apply {
            setInitialized()
            setRinging()
        }
    }

    override fun onCreateIncomingConnectionFailed(
        connectionManagerPhoneAccount: PhoneAccountHandle?,
        request: ConnectionRequest?,
    ) {
        val (name, number) = readCaller(request)
        unregisterAccount(applicationContext)
        FakeCallReceiver.showAppCall(applicationContext, name, number)
    }

    private fun readCaller(request: ConnectionRequest?): Pair<String, String> {
        val extras = request?.extras
        val nested = extras?.getBundle(TelecomManager.EXTRA_INCOMING_CALL_EXTRAS)
        val name   = extras?.getString(FakeCallReceiver.EXTRA_NAME)
            ?: nested?.getString(FakeCallReceiver.EXTRA_NAME) ?: ""
        val number = extras?.getString(FakeCallReceiver.EXTRA_NUMBER)
            ?: nested?.getString(FakeCallReceiver.EXTRA_NUMBER) ?: ""
        return Pair(name, number)
    }

    private class FakeConnection(
        private val ctx: Context,
        name: String,
        number: String,
    ) : Connection() {
        init {
            setConnectionCapabilities(CAPABILITY_MUTE)
            setAddress(
                Uri.fromParts(PhoneAccount.SCHEME_TEL, number.ifBlank { "000000" }, null),
                if (number.isBlank()) TelecomManager.PRESENTATION_UNKNOWN
                else TelecomManager.PRESENTATION_ALLOWED,
            )
            if (name.isNotBlank()) {
                setCallerDisplayName(name, TelecomManager.PRESENTATION_ALLOWED)
            }
        }

        override fun onAnswer()                { setActive() }
        override fun onAnswer(videoState: Int) { setActive() }

        override fun onReject() {
            setDisconnected(DisconnectCause(DisconnectCause.REJECTED))
            destroy(); unregisterAccount(ctx)
        }
        override fun onDisconnect() {
            setDisconnected(DisconnectCause(DisconnectCause.LOCAL))
            destroy(); unregisterAccount(ctx)
        }
        override fun onAbort() {
            setDisconnected(DisconnectCause(DisconnectCause.CANCELED))
            destroy(); unregisterAccount(ctx)
        }
    }

    companion object {
        private const val ACCOUNT_ID = "callen_fake_call"

        fun handle(context: Context) = PhoneAccountHandle(
            ComponentName(context, FakeCallConnectionService::class.java),
            ACCOUNT_ID,
        )

        private fun telecom(context: Context): TelecomManager =
            context.getSystemService(TelecomManager::class.java)

        fun registerAccount(context: Context) {
            try {
                val account = PhoneAccount.builder(handle(context), "Callen")
                    .setCapabilities(PhoneAccount.CAPABILITY_CALL_PROVIDER)
                    .setSupportedUriSchemes(listOf(PhoneAccount.SCHEME_TEL))
                    .setShortDescription("Callen fake call")
                    .build()
                telecom(context).registerPhoneAccount(account)
            } catch (_: Exception) {}
        }

        fun unregisterAccount(context: Context) {
            try { telecom(context).unregisterPhoneAccount(handle(context)) }
            catch (_: Exception) {}
        }

        // alias kept for compatibility
        fun ensureAccountRegistered(context: Context) = registerAccount(context)

        fun isAccountEnabled(context: Context): Boolean? {
            registerAccount(context)
            return try {
                telecom(context).getPhoneAccount(handle(context))?.isEnabled
            } catch (_: Exception) { null }
        }

        fun tryIncomingCall(context: Context, name: String, number: String): Boolean {
            registerAccount(context)
            Thread.sleep(300)   // let Telecom commit the registration
            return try {
                val extras = Bundle().apply {
                    putParcelable(
                        TelecomManager.EXTRA_INCOMING_CALL_ADDRESS,
                        Uri.fromParts(PhoneAccount.SCHEME_TEL, number.ifBlank { "000000" }, null),
                    )
                    putString(FakeCallReceiver.EXTRA_NAME, name)
                    putString(FakeCallReceiver.EXTRA_NUMBER, number)
                }
                telecom(context).addNewIncomingCall(handle(context), extras)
                true
            } catch (_: Exception) {
                unregisterAccount(context)
                false
            }
        }
    }
}
