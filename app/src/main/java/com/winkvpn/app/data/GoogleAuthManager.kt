package com.winkvpn.app.data

import android.content.Context
import androidx.credentials.CredentialManager
import androidx.credentials.CustomCredential
import androidx.credentials.GetCredentialRequest
import androidx.credentials.exceptions.GetCredentialCancellationException
import androidx.credentials.exceptions.GetCredentialException
import androidx.credentials.exceptions.NoCredentialException
import com.google.android.libraries.identity.googleid.GetGoogleIdOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import com.google.android.libraries.identity.googleid.GoogleIdTokenParsingException
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.providers.Google
import io.github.jan.supabase.auth.providers.builtin.IDToken

/**
 * Web Client ID из Google Cloud Console (тип Web application — именно он
 * нужен для проверки токена на стороне Supabase).
 */
private const val GOOGLE_WEB_CLIENT_ID = "706014079943-mp693b1oa09ss3pv77gjgrcvugkov278.apps.googleusercontent.com"

sealed class GoogleSignInResult {
    data object Success : GoogleSignInResult()
    data class Error(val message: String) : GoogleSignInResult()
    data object Cancelled : GoogleSignInResult()
}

object GoogleAuthManager {

    suspend fun signIn(context: Context): GoogleSignInResult {
        val credentialManager = CredentialManager.create(context)

        val googleIdOption = GetGoogleIdOption.Builder()
            .setFilterByAuthorizedAccounts(false)
            .setServerClientId(GOOGLE_WEB_CLIENT_ID)
            .setAutoSelectEnabled(false)
            .build()

        val request = GetCredentialRequest.Builder()
            .addCredentialOption(googleIdOption)
            .build()

        return try {
            val result = credentialManager.getCredential(context, request)
            val credential = result.credential

            if (credential is CustomCredential &&
                credential.type == GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL
            ) {
                val googleIdTokenCredential = GoogleIdTokenCredential.createFrom(credential.data)
                val idToken = googleIdTokenCredential.idToken

                SupabaseClientProvider.client.auth.signInWith(IDToken) {
                    this.idToken = idToken
                    provider = Google
                }

                GoogleSignInResult.Success
            } else {
                GoogleSignInResult.Error("Неожиданный тип учётных данных")
            }
        } catch (e: GetCredentialCancellationException) {
            // Пользователь сам закрыл окно выбора аккаунта — это НЕ ошибка
            GoogleSignInResult.Cancelled
        } catch (e: NoCredentialException) {
            // На устройстве нет ни одного добавленного Google-аккаунта
            GoogleSignInResult.Error("На устройстве не найден Google-аккаунт. Добавь его в Настройки → Аккаунты.")
        } catch (e: GetCredentialException) {
            // ЛЮБАЯ другая ошибка Credential Manager — раньше эта ветка молча
            // считалась "отменой", из-за чего реальная причина была не видна.
            // Показываем настоящее сообщение, чтобы можно было понять причину.
            GoogleSignInResult.Error("Ошибка входа (${e.type}): ${e.message ?: "без деталей"}")
        } catch (e: GoogleIdTokenParsingException) {
            GoogleSignInResult.Error("Не удалось разобрать токен Google: ${e.message}")
        } catch (e: Exception) {
            GoogleSignInResult.Error("${e.javaClass.simpleName}: ${e.message ?: "неизвестная ошибка"}")
        }
    }

    fun isSignedIn(): Boolean {
        return SupabaseClientProvider.client.auth.currentUserOrNull() != null
    }

    suspend fun signOut() {
        SupabaseClientProvider.client.auth.signOut()
    }
}

