#!/usr/bin/env bash
# WinFix9.sh — фикс: раньше ЛЮБАЯ ошибка Google-входа молча считалась
# 'отменой пользователем', поэтому реальная причина сбоя была не видна.
# Теперь настоящая ошибка показывается текстом под кнопкой.
# Плюс: нормальная иконка профиля (не два кружочка), и экран профиля
# теперь показывает 'Не авторизован' + кнопку входа, если ты ещё не вошёл.
set -e
echo "Обновляю файлы..."

mkdir -p "app/src/main/java/com/winkvpn/app"
mkdir -p "app/src/main/java/com/winkvpn/app/data"
mkdir -p "app/src/main/java/com/winkvpn/app/ui/screens"

cat > "app/src/main/java/com/winkvpn/app/MainActivity.kt" << 'WINKVPN_EOF'
package com.winkvpn.app

import android.content.Intent
import android.net.Uri
import android.net.VpnService
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Surface
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import com.winkvpn.app.data.GoogleAuthManager
import com.winkvpn.app.data.GoogleSignInResult
import com.winkvpn.app.data.Profile
import com.winkvpn.app.data.ProfileRepository
import com.winkvpn.app.ui.screens.*
import com.winkvpn.app.ui.theme.WinkYellow
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {

    private val vpnPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.StartActivityForResult()
    ) { /* результат обработаем, когда подключим настоящий туннель */ }

    private fun requestVpnPermissionIfNeeded() {
        val intent = VpnService.prepare(this)
        if (intent != null) {
            vpnPermissionLauncher.launch(intent)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            Surface(modifier = Modifier.fillMaxSize(), color = WinkYellow) {
                var screen by remember { mutableStateOf(Screen.SPLASH) }
                var previousScreen by remember { mutableStateOf(Screen.MAIN) }
                val scope = rememberCoroutineScope()

                var isGoogleLoading by remember { mutableStateOf(false) }
                var googleErrorMessage by remember { mutableStateOf<String?>(null) }

                var profile by remember { mutableStateOf<Profile?>(null) }
                var appLanguage by remember { mutableStateOf(AppLanguage.RU) }

                fun applyProfile(fetched: Profile?) {
                    profile = fetched
                    if (fetched != null) {
                        appLanguage = if (fetched.language == "en") AppLanguage.EN else AppLanguage.RU
                    }
                }

                // Как только попадаем на главный экран — подгружаем профиль (если уже вошли)
                LaunchedEffect(screen) {
                    if (screen == Screen.MAIN && profile == null && GoogleAuthManager.isSignedIn()) {
                        applyProfile(ProfileRepository.fetchCurrentProfile())
                    }
                }

                // Общая логика входа через Google — используется и на экране приветствия,
                // и на экране профиля (если человек пропустил вход раньше).
                fun doGoogleSignIn(onSuccess: () -> Unit) {
                    googleErrorMessage = null
                    isGoogleLoading = true
                    scope.launch {
                        when (val result = GoogleAuthManager.signIn(this@MainActivity)) {
                            is GoogleSignInResult.Success -> {
                                applyProfile(ProfileRepository.fetchCurrentProfile())
                                isGoogleLoading = false
                                onSuccess()
                            }
                            is GoogleSignInResult.Cancelled -> {
                                isGoogleLoading = false
                            }
                            is GoogleSignInResult.Error -> {
                                isGoogleLoading = false
                                googleErrorMessage = result.message
                            }
                        }
                    }
                }

                var waitingForTelegramReturn by remember { mutableStateOf(false) }
                var hasPausedSinceWaiting by remember { mutableStateOf(false) }

                val lifecycleOwner = LocalLifecycleOwner.current
                DisposableEffect(waitingForTelegramReturn) {
                    if (!waitingForTelegramReturn) return@DisposableEffect onDispose {}
                    hasPausedSinceWaiting = false
                    val observer = LifecycleEventObserver { _, event ->
                        when (event) {
                            Lifecycle.Event.ON_PAUSE -> hasPausedSinceWaiting = true
                            Lifecycle.Event.ON_RESUME -> {
                                if (hasPausedSinceWaiting) {
                                    waitingForTelegramReturn = false
                                    screen = Screen.TELEGRAM_THANKS
                                }
                            }
                            else -> {}
                        }
                    }
                    lifecycleOwner.lifecycle.addObserver(observer)
                    onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
                }

                AnimatedContent(
                    targetState = screen,
                    transitionSpec = {
                        (slideInHorizontally(tween(450)) { it / 3 } + fadeIn(tween(450))) togetherWith
                            (slideOutHorizontally(tween(450)) { -it / 3 } + fadeOut(tween(450)))
                    },
                    label = "screenTransition"
                ) { current ->
                    when (current) {
                        Screen.SPLASH -> SplashScreen(onFinished = { screen = Screen.WELCOME })

                        Screen.WELCOME -> WelcomeScreen(
                            isLoading = isGoogleLoading,
                            errorMessage = googleErrorMessage,
                            onGoogleLogin = { doGoogleSignIn(onSuccess = { screen = Screen.TELEGRAM }) },
                            onSkip = { screen = Screen.TELEGRAM }
                        )

                        Screen.TELEGRAM -> TelegramScreen(
                            isWaitingForReturn = waitingForTelegramReturn,
                            onJoin = {
                                val intent = Intent(Intent.ACTION_VIEW, Uri.parse("https://t.me/Winkvpn_official"))
                                startActivity(intent)
                                waitingForTelegramReturn = true
                            },
                            onSkip = { screen = Screen.THANKS }
                        )

                        Screen.TELEGRAM_THANKS -> TelegramThanksScreen(
                            onContinue = { screen = Screen.THANKS }
                        )

                        Screen.THANKS -> ThanksScreen(
                            onStart = {
                                requestVpnPermissionIfNeeded()
                                screen = Screen.MAIN
                            }
                        )

                        Screen.MAIN -> MainScreen(
                            onProfileClick = {
                                previousScreen = Screen.MAIN
                                screen = Screen.PROFILE
                            }
                        )

                        Screen.PROFILE -> ProfileScreen(
                            isAuthenticated = GoogleAuthManager.isSignedIn() && profile != null,
                            email = profile?.email,
                            nickname = profile?.nickname ?: "",
                            userNumber = profile?.user_number,
                            language = appLanguage,
                            isGoogleLoading = isGoogleLoading,
                            googleErrorMessage = googleErrorMessage,
                            onGoogleLogin = { doGoogleSignIn(onSuccess = {}) },
                            onNicknameChange = { newNick ->
                                profile = profile?.copy(nickname = newNick)
                                scope.launch { ProfileRepository.updateNickname(newNick) }
                            },
                            onLanguageChange = { newLang ->
                                appLanguage = newLang
                                profile = profile?.copy(language = if (newLang == AppLanguage.EN) "en" else "ru")
                                scope.launch {
                                    ProfileRepository.updateLanguage(if (newLang == AppLanguage.EN) "en" else "ru")
                                }
                            },
                            onBack = { screen = previousScreen }
                        )
                    }
                }
            }
        }
    }
}

WINKVPN_EOF

cat > "app/src/main/java/com/winkvpn/app/data/GoogleAuthManager.kt" << 'WINKVPN_EOF'
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

WINKVPN_EOF

cat > "app/src/main/java/com/winkvpn/app/ui/screens/AppIcons.kt" << 'WINKVPN_EOF'
package com.winkvpn.app.ui.screens

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.unit.dp

/** Узнаваемая иконка "человек" — голова + купол плеч одним силуэтом (не два кружочка) */
@Composable
fun PersonIcon(sizeDp: Int = 20, tint: Color = Color.Black, modifier: Modifier = Modifier) {
    Canvas(modifier = modifier.size(sizeDp.dp)) {
        val w = size.width
        val h = size.height

        // голова
        drawCircle(tint, radius = w * 0.17f, center = Offset(w * 0.5f, h * 0.27f))

        // плечи/тело — купол: узкий сверху, широкий снизу, низ уходит за край
        // иконки (Canvas сам обрежет по своим границам — получается плоский низ)
        val body = Path().apply {
            moveTo(w * 0.5f, h * 0.40f)
            cubicTo(w * 0.22f, h * 0.40f, w * 0.10f, h * 0.62f, w * 0.10f, h * 1.05f)
            lineTo(w * 0.90f, h * 1.05f)
            cubicTo(w * 0.90f, h * 0.62f, w * 0.78f, h * 0.40f, w * 0.5f, h * 0.40f)
            close()
        }
        drawPath(body, tint)
    }
}

/** Символ бесконечности — для карточки "Безлимитная подписка" */
@Composable
fun InfinityIcon(widthDp: Int = 48, heightDp: Int = 26, tint: Color = Color.Black, modifier: Modifier = Modifier) {
    Canvas(modifier = modifier.size(width = widthDp.dp, height = heightDp.dp)) {
        val w = size.width
        val h = size.height
        val sw = h * 0.34f

        val path = Path().apply {
            moveTo(w * 0.5f, h * 0.5f)
            cubicTo(w * 0.36f, h * 0.02f, w * 0.02f, h * 0.02f, w * 0.02f, h * 0.5f)
            cubicTo(w * 0.02f, h * 0.98f, w * 0.36f, h * 0.98f, w * 0.5f, h * 0.5f)
            cubicTo(w * 0.64f, h * 0.02f, w * 0.98f, h * 0.02f, w * 0.98f, h * 0.5f)
            cubicTo(w * 0.98f, h * 0.98f, w * 0.64f, h * 0.98f, w * 0.5f, h * 0.5f)
            close()
        }
        drawPath(
            path, tint,
            style = Stroke(width = sw, cap = StrokeCap.Round)
        )
    }
}

WINKVPN_EOF

cat > "app/src/main/java/com/winkvpn/app/ui/screens/ProfileScreen.kt" << 'WINKVPN_EOF'
package com.winkvpn.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.winkvpn.app.AppLanguage
import com.winkvpn.app.ui.theme.WinkBlack
import com.winkvpn.app.ui.theme.WinkBlack09
import com.winkvpn.app.ui.theme.WinkWhite
import com.winkvpn.app.ui.theme.WinkYellow

@Composable
fun ProfileScreen(
    isAuthenticated: Boolean,
    email: String?,
    nickname: String,
    userNumber: Long?,
    language: AppLanguage,
    isGoogleLoading: Boolean,
    googleErrorMessage: String?,
    onGoogleLogin: () -> Unit,
    onNicknameChange: (String) -> Unit,
    onLanguageChange: (AppLanguage) -> Unit,
    onBack: () -> Unit
) {
    var editedNickname by remember(nickname) { mutableStateOf(nickname) }
    val isRu = language == AppLanguage.RU

    Box(modifier = Modifier.fillMaxSize()) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 26.dp)
        ) {
            Spacer(Modifier.height(56.dp))

            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(
                    modifier = Modifier
                        .size(38.dp)
                        .clip(RoundedCornerShape(12.dp))
                        .background(WinkBlack09)
                        .clickable(onClick = onBack),
                    contentAlignment = Alignment.Center
                ) {
                    Text("←", fontSize = 18.sp, fontWeight = FontWeight.Black, color = WinkBlack)
                }
                Spacer(Modifier.width(14.dp))
                Text(
                    if (isRu) "Профиль" else "Profile",
                    fontSize = 22.sp,
                    fontWeight = FontWeight.Black,
                    color = WinkBlack
                )
            }

            Spacer(Modifier.height(40.dp))

            Box(
                modifier = Modifier.fillMaxWidth(),
                contentAlignment = Alignment.Center
            ) {
                Box(
                    modifier = Modifier
                        .size(96.dp)
                        .clip(CircleShape)
                        .background(WinkBlack09),
                    contentAlignment = Alignment.Center
                ) {
                    PersonIcon(sizeDp = 46, tint = WinkBlack)
                }
            }

            Spacer(Modifier.height(24.dp))

            if (!isAuthenticated) {
                // ── Не авторизован — предлагаем войти ──
                Text(
                    "Не авторизован",
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Black,
                    color = WinkBlack,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth()
                )
                Spacer(Modifier.height(8.dp))
                Text(
                    "Войдите, чтобы сохранить бонусы и настройки",
                    fontSize = 13.5.sp,
                    fontWeight = FontWeight.Medium,
                    color = WinkBlack.copy(alpha = 0.5f),
                    textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth()
                )
                Spacer(Modifier.height(24.dp))
                PrimaryButton(
                    text = if (isGoogleLoading) "Входим…" else "Войти через Google",
                    onClick = { if (!isGoogleLoading) onGoogleLogin() }
                )
                if (googleErrorMessage != null) {
                    Spacer(Modifier.height(10.dp))
                    Text(
                        googleErrorMessage,
                        color = Color(0xFFC62828),
                        fontSize = 12.5.sp,
                        fontWeight = FontWeight.Bold,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.fillMaxWidth()
                    )
                }
                return@Column
            }

            // ── Авторизован — полный профиль ──
            Box(modifier = Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(99.dp))
                        .background(WinkBlack09)
                        .padding(horizontal = 16.dp, vertical = 7.dp)
                ) {
                    Text(
                        "ID: ${userNumber ?: "—"}",
                        fontSize = 13.sp,
                        fontWeight = FontWeight.Bold,
                        color = WinkBlack.copy(alpha = 0.6f)
                    )
                }
            }

            Spacer(Modifier.height(28.dp))

            Text(
                if (isRu) "Почта" else "Email",
                fontSize = 12.sp, fontWeight = FontWeight.Black,
                color = WinkBlack.copy(alpha = 0.4f)
            )
            Spacer(Modifier.height(6.dp))
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(16.dp))
                    .background(WinkBlack09)
                    .padding(horizontal = 16.dp, vertical = 14.dp)
            ) {
                Text(
                    email ?: "—",
                    fontSize = 15.sp, fontWeight = FontWeight.Bold, color = WinkBlack
                )
            }

            Spacer(Modifier.height(20.dp))

            Text(
                if (isRu) "Никнейм" else "Nickname",
                fontSize = 12.sp, fontWeight = FontWeight.Black,
                color = WinkBlack.copy(alpha = 0.4f)
            )
            Spacer(Modifier.height(6.dp))
            TextField(
                value = editedNickname,
                onValueChange = {
                    editedNickname = it
                    onNicknameChange(it)
                },
                singleLine = true,
                textStyle = TextStyle(color = WinkBlack, fontSize = 15.sp, fontWeight = FontWeight.Bold),
                colors = TextFieldDefaults.colors(
                    focusedContainerColor = WinkBlack09,
                    unfocusedContainerColor = WinkBlack09,
                    disabledContainerColor = WinkBlack09,
                    focusedIndicatorColor = Color.Transparent,
                    unfocusedIndicatorColor = Color.Transparent,
                    disabledIndicatorColor = Color.Transparent,
                    cursorColor = WinkBlack
                ),
                shape = RoundedCornerShape(16.dp),
                modifier = Modifier.fillMaxWidth()
            )

            Spacer(Modifier.height(28.dp))

            Text(
                if (isRu) "Язык" else "Language",
                fontSize = 12.sp, fontWeight = FontWeight.Black,
                color = WinkBlack.copy(alpha = 0.4f)
            )
            Spacer(Modifier.height(8.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                LanguageChip(
                    label = "Русский",
                    selected = language == AppLanguage.RU,
                    onClick = { onLanguageChange(AppLanguage.RU) },
                    modifier = Modifier.weight(1f)
                )
                LanguageChip(
                    label = "English",
                    selected = language == AppLanguage.EN,
                    onClick = { onLanguageChange(AppLanguage.EN) },
                    modifier = Modifier.weight(1f)
                )
            }
        }
    }
}

@Composable
private fun LanguageChip(
    label: String,
    selected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Box(
        contentAlignment = Alignment.Center,
        modifier = modifier
            .clip(RoundedCornerShape(16.dp))
            .background(if (selected) WinkBlack else WinkBlack09)
            .clickable(onClick = onClick)
            .padding(vertical = 14.dp)
    ) {
        Text(
            label,
            fontSize = 14.sp,
            fontWeight = FontWeight.Black,
            color = if (selected) WinkWhite else WinkBlack
        )
    }
}

WINKVPN_EOF

echo "Готово!"
echo "Дальше: git add -A && git commit -m fix_google_signin && git push"