package com.voltez.app

import android.os.CancellationSignal
import androidx.core.content.ContextCompat
import androidx.credentials.ClearCredentialStateRequest
import androidx.credentials.CredentialManager
import androidx.credentials.CredentialManagerCallback
import androidx.credentials.CustomCredential
import androidx.credentials.GetCredentialRequest
import androidx.credentials.GetCredentialResponse
import androidx.credentials.exceptions.ClearCredentialException
import androidx.credentials.exceptions.GetCredentialCancellationException
import androidx.credentials.exceptions.GetCredentialException
import androidx.credentials.exceptions.NoCredentialException
import com.google.android.libraries.identity.googleid.GetGoogleIdOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import com.google.android.libraries.identity.googleid.GoogleIdTokenParsingException
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val credentialManager by lazy { CredentialManager.create(this) }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            GOOGLE_AUTH_CHANNEL,
        ).setMethodCallHandler(::handleGoogleAuthCall)
    }

    private fun handleGoogleAuthCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getGoogleIdToken" -> requestGoogleIdToken(
                result = result,
                filterByAuthorizedAccounts = true,
            )
            "clearGoogleCredentialState" -> clearGoogleCredentialState(result)
            else -> result.notImplemented()
        }
    }

    private fun requestGoogleIdToken(
        result: MethodChannel.Result,
        filterByAuthorizedAccounts: Boolean,
    ) {
        val googleIdOption = GetGoogleIdOption.Builder()
            .setFilterByAuthorizedAccounts(filterByAuthorizedAccounts)
            .setServerClientId(BuildConfig.GOOGLE_WEB_CLIENT_ID)
            .setAutoSelectEnabled(false)
            .build()
        val request = GetCredentialRequest.Builder()
            .addCredentialOption(googleIdOption)
            .build()

        credentialManager.getCredentialAsync(
            this,
            request,
            CancellationSignal(),
            ContextCompat.getMainExecutor(this),
            object : CredentialManagerCallback<GetCredentialResponse, GetCredentialException> {
                override fun onResult(response: GetCredentialResponse) {
                    returnGoogleIdToken(response, result)
                }

                override fun onError(error: GetCredentialException) {
                    if (filterByAuthorizedAccounts && error is NoCredentialException) {
                        requestGoogleIdToken(
                            result = result,
                            filterByAuthorizedAccounts = false,
                        )
                        return
                    }

                    val code = when (error) {
                        is GetCredentialCancellationException -> "google_sign_in_cancelled"
                        is NoCredentialException -> "no_google_credential"
                        else -> "google_sign_in_failed"
                    }
                    result.error(code, error.message ?: "Google sign-in failed.", null)
                }
            },
        )
    }

    private fun returnGoogleIdToken(
        response: GetCredentialResponse,
        result: MethodChannel.Result,
    ) {
        val credential = response.credential
        if (
            credential !is CustomCredential ||
            credential.type != GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL
        ) {
            result.error(
                "unexpected_google_credential",
                "Google returned an unsupported credential type.",
                null,
            )
            return
        }

        try {
            val googleCredential = GoogleIdTokenCredential.createFrom(credential.data)
            result.success(googleCredential.idToken)
        } catch (error: GoogleIdTokenParsingException) {
            result.error(
                "invalid_google_credential",
                "Google returned an invalid ID token credential.",
                null,
            )
        }
    }

    private fun clearGoogleCredentialState(result: MethodChannel.Result) {
        credentialManager.clearCredentialStateAsync(
            ClearCredentialStateRequest(),
            CancellationSignal(),
            ContextCompat.getMainExecutor(this),
            object : CredentialManagerCallback<Void?, ClearCredentialException> {
                override fun onResult(response: Void?) {
                    result.success(null)
                }

                override fun onError(error: ClearCredentialException) {
                    result.error(
                        "google_sign_out_failed",
                        error.message ?: "Unable to clear Google credential state.",
                        null,
                    )
                }
            },
        )
    }

    companion object {
        private const val GOOGLE_AUTH_CHANNEL = "com.voltez.app/google_auth"
    }
}
