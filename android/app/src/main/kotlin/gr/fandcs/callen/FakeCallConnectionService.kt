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
import android.util.Log

/**
 * Fake incoming call shown with the device's OWN call UI (OEM in-call screen).
 *
 * Changes compared to the previous version:
 *  - The account is registered ONCE and stays registered. Previously it was
 *    re-registered on every check and unregistered after every call, which
 *    throws away the "enabled" state the user gave it in the system settings.
 *  - Because it stays registered, it must NOT show up in the SIM picker for
 *    normal outgoing calls. For that it only declares the private URI scheme
 *    [ACCOUNT_SCHEME] instead of "tel". (If a device refuses the call with this
 *    scheme, change ACCOUNT_SCHEME to PhoneAccount.SCHEME_TEL.)
 *  - No more silent `catch (_: Exception) {}`. Everything is logged under the
 *    tag "FakeCall":   adb logcat -s FakeCall Telecom
 *  - tryIncomingCall() checks that the account is enabled and returns false
 *    (so the caller can use the in‑app fallback) instead of failing silently.
 */
class FakeCallConnectionService : ConnectionService() {

    override fun onCreateIncomingConnection(
        connectionManagerPhoneAccount: PhoneAccountHandle?,
        request: ConnectionRequest?,
    ): Connection {
        val (name, number) = readCaller(request)
        Log.d(TAG, "onCreateIncomingConnection name=$name number=$number")
        return FakeConnection(name, number).apply {
            setInitialized()
            setRinging()
        }
    }

    override fun onCreateIncomingConnectionFailed(
        connectionManagerPhoneAccount: PhoneAccountHandle?,
        request: ConnectionRequest?,
    ) {
        val (name, number) = readCaller(request)
        Log.w(TAG, "onCreateIncomingConnectionFailed -> in-app fallback")
        FakeCallReceiver.showAppCall(applicationContext, name, number)
    }

    private fun readCaller(request: ConnectionRequest?): Pair<String, String> {
        val extras = request?.extras
        val nested = extras?.getBundle(TelecomManager.EXTRA_INCOMING_CALL_EXTRAS)
        val name = extras?.getString(FakeCallReceiver.EXTRA_NAME)
            ?: nested?.getString(FakeCallReceiver.EXTRA_NAME) ?: ""
        val number = extras?.getString(FakeCallReceiver.EXTRA_NUMBER)
            ?: nested?.getString(FakeCallReceiver.EXTRA_NUMBER) ?: ""
        return Pair(name, number)
    }

    private class FakeConnection(name: String, number: String) : Connection() {
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

        override fun onAnswer() { setActive() }
        override fun onAnswer(videoState: Int) { setActive() }

        override fun onReject() {
            setDisconnected(DisconnectCause(DisconnectCause.REJECTED))
            destroy()
        }

        override fun onDisconnect() {
            setDisconnected(DisconnectCause(DisconnectCause.LOCAL))
            destroy()
        }

        override fun onAbort() {
            setDisconnected(DisconnectCause(DisconnectCause.CANCELED))
            destroy()
        }
    }

    companion object {
        private const val TAG = "FakeCall"
        private const val ACCOUNT_ID = "callen_fake_call"

        // Private scheme => the account is not offered for normal tel: calls.
        private const val ACCOUNT_SCHEME = "callen"

        fun handle(context: Context) = PhoneAccountHandle(
            ComponentName(context, FakeCallConnectionService::class.java),
            ACCOUNT_ID,
        )

        private fun telecom(context: Context): TelecomManager =
            context.getSystemService(TelecomManager::class.java)

        private fun buildAccount(context: Context): PhoneAccount =
            PhoneAccount.builder(handle(context), "Callen")
                .setCapabilities(PhoneAccount.CAPABILITY_CALL_PROVIDER)
                .setSupportedUriSchemes(listOf(ACCOUNT_SCHEME))
                .setShortDescription("Callen fake call")
                .build()

        /**
         * Registers the account only if it is missing or its definition changed.
         * Returns true if a (re)registration actually happened.
         */
        private fun ensureRegistered(context: Context): Boolean {
            return try {
                val existing = telecom(context).getPhoneAccount(handle(context))
                val upToDate = existing != null &&
                    existing.capabilities == PhoneAccount.CAPABILITY_CALL_PROVIDER &&
                    existing.supportedUriSchemes == listOf(ACCOUNT_SCHEME)
                if (upToDate) {
                    false
                } else {
                    telecom(context).registerPhoneAccount(buildAccount(context))
                    Log.d(TAG, "PhoneAccount registered")
                    true
                }
            } catch (e: Exception) {
                Log.e(TAG, "ensureRegistered failed", e)
                false
            }
        }

        fun registerAccount(context: Context) { ensureRegistered(context) }

        /** Only call this if the user disables fake calls entirely. */
        fun unregisterAccount(context: Context) {
            try {
                telecom(context).unregisterPhoneAccount(handle(context))
                Log.d(TAG, "PhoneAccount unregistered")
            } catch (e: Exception) {
                Log.e(TAG, "unregisterAccount failed", e)
            }
        }

        // alias kept for compatibility
        fun ensureAccountRegistered(context: Context) = registerAccount(context)

        fun isAccountEnabled(context: Context): Boolean? {
            ensureRegistered(context)
            return try {
                val enabled = telecom(context).getPhoneAccount(handle(context))?.isEnabled
                Log.d(TAG, "isAccountEnabled=$enabled")
                enabled
            } catch (e: Exception) {
                Log.e(TAG, "isAccountEnabled failed", e)
                null
            }
        }

        /** Returns true if Telecom accepted the call (the OEM UI will ring). */
        fun tryIncomingCall(context: Context, name: String, number: String): Boolean {
            val justRegistered = ensureRegistered(context)
            if (justRegistered) Thread.sleep(300) // let Telecom commit the registration

            return try {
                val account = telecom(context).getPhoneAccount(handle(context))
                if (account == null) {
                    Log.w(TAG, "tryIncomingCall: account missing")
                    return false
                }
                if (!account.isEnabled) {
                    Log.w(TAG, "tryIncomingCall: account NOT enabled by the user")
                    return false
                }

                val extras = Bundle().apply {
                    putParcelable(
                        TelecomManager.EXTRA_INCOMING_CALL_ADDRESS,
                        Uri.fromParts(PhoneAccount.SCHEME_TEL, number.ifBlank { "000000" }, null),
                    )
                    putString(FakeCallReceiver.EXTRA_NAME, name)
                    putString(FakeCallReceiver.EXTRA_NUMBER, number)
                }
                telecom(context).addNewIncomingCall(handle(context), extras)
                Log.d(TAG, "addNewIncomingCall sent")
                true
            } catch (e: Exception) {
                Log.e(TAG, "addNewIncomingCall failed", e)
                false
            }
        }
    }
}
