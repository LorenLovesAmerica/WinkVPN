#!/usr/bin/env bash
# WinFix10.sh — используем GetSignInWithGoogleOption вместо GetGoogleIdOption.
# Для ПЕРВОГО входа (аккаунт ещё не авторизован в приложении) GetGoogleIdOption
# часто падает с NoCredentialException даже если аккаунт есть на телефоне —
# это известная особенность Credential Manager API. GetSignInWithGoogleOption
# создан именно для явной кнопки 'Войти через Google' и надёжно показывает
# список аккаунтов на выбор.
set -e
echo "Обновляю файлы..."
mkdir -p "app/src/main/java/com/winkvpn/app/data"

cat > "app/src/main/java/com/winkvpn/app/data/GoogleAuthManager.kt" << 'WINKVPN_EOF'
package com.winkvpn.app.data

import android.content.Context
import androidx.credentials.CredentialManager
import androidx.credentials.CustomCredential
import androidx.credentials.GetCredentialRequest
import androidx.credentials.exceptions.GetCredentialCancellationException
import androidx.credentials.exceptions.GetCredentialException
import androidx.credentials.exceptions.NoCredentialException
import com.google.android.libraries.identity.googleid.GetSignInWithGoogleOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import com.google.android.libraries.identity.googleid.GoogleIdTokenParsingException
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.providers.Google
import io.github.jan.supabase.auth.providers.builtin.IDToken
import java.security.MessageDigest
import java.util.UUID

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

    /** Случайный nonce на каждый запрос — защита от replay-атак, Google это рекомендует */
    private fun generateHashedNonce(): String {
        val rawNonce = UUID.randomUUID().toString()
        val bytes = rawNonce.toByteArray()
        val digest = MessageDigest.getInstance("SHA-256").digest(bytes)
        return digest.joinToString("") { "%02x".format(it) }
    }

    suspend fun signIn(context: Context): GoogleSignInResult {
        val credentialManager = CredentialManager.create(context)

        // ВАЖНО: используем GetSignInWithGoogleOption, а не GetGoogleIdOption.
        // GetGoogleIdOption с filterByAuthorizedAccounts(false) в теории тоже должен
        // показывать все аккаунты, но на практике для ПЕРВОГО входа (аккаунт ещё
        // ни разу не авторизовывался в этом приложении) часто падает с
        // NoCredentialException, даже если Google-аккаунт есть на телефоне.
        // GetSignInWithGoogleOption — это именно "явная кнопка входа", она
        // гарантированно показывает список аккаунтов на выбор в любом случае.
        val signInWithGoogleOption = GetSignInWithGoogleOption.Builder(GOOGLE_WEB_CLIENT_ID)
            .setNonce(generateHashedNonce())
            .build()

        val request = GetCredentialRequest.Builder()
            .addCredentialOption(signInWithGoogleOption)
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
            GoogleSignInResult.Cancelled
        } catch (e: NoCredentialException) {
            GoogleSignInResult.Error("На устройстве не найден Google-аккаунт. Добавь его в Настройки → Аккаунты, затем попробуй снова.")
        } catch (e: GetCredentialException) {
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

WINKVPN_EOF

echo "Готово!"
echo "Дальше: git add -A && git commit -m fix_signin_with_google_option && git push"