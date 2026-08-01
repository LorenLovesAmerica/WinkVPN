#!/usr/bin/env bash
# Wink VPN — полная пересборка проекта (репозиторий был потерян).
# Включает: все экраны, VPN-имитацию, премиальные фоновые иконки,
# сплэш с настоящими фигурами логотипа, Supabase (уже настроен на твой проект),
# Google-вход через Credential Manager (ЗАМЕНИ GOOGLE_WEB_CLIENT_ID перед сборкой!).
set -e
echo "Разворачиваю проект Wink VPN..."

mkdir -p "app"
mkdir -p "app/src/main"
mkdir -p "app/src/main/java/com/winkvpn/app"
mkdir -p "app/src/main/java/com/winkvpn/app/data"
mkdir -p "app/src/main/java/com/winkvpn/app/ui/screens"
mkdir -p "app/src/main/java/com/winkvpn/app/ui/theme"
mkdir -p "app/src/main/java/com/winkvpn/app/vpn"
mkdir -p "app/src/main/res/drawable"
mkdir -p "app/src/main/res/values"
mkdir -p "gradle/wrapper"

cat > ".gitignore" << 'WINKVPN_EOF'
*.iml
.gradle
/local.properties
.idea
.DS_Store
/build
/captures
.externalNativeBuild
.cxx
local.properties

WINKVPN_EOF

cat > "app/build.gradle.kts" << 'WINKVPN_EOF'
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.serialization")
}

android {
    namespace = "com.winkvpn.app"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.winkvpn.app"
        minSdk = 26
        targetSdk = 34
        versionCode = 1
        versionName = "0.2.0-alpha"
    }

    buildFeatures {
        compose = true
    }

    composeOptions {
        kotlinCompilerExtensionVersion = "1.5.14"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
        }
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.activity:activity-compose:1.9.0")
    implementation(platform("androidx.compose:compose-bom:2024.06.00"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-graphics")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.animation:animation")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.1")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.8.1")

    // ── Supabase (база данных + авторизация) ──
    implementation(platform("io.github.jan-tennert.supabase:bom:3.7.0"))
    implementation("io.github.jan-tennert.supabase:postgrest-kt")
    implementation("io.github.jan-tennert.supabase:auth-kt")
    implementation("io.ktor:ktor-client-okhttp:3.5.0")
    implementation("io.ktor:ktor-client-core:3.5.0")

    // ── Google Sign-In через современный Credential Manager API ──
    implementation("androidx.credentials:credentials:1.3.0")
    implementation("androidx.credentials:credentials-play-services-auth:1.3.0")
    implementation("com.google.android.libraries.identity.googleid:googleid:1.1.1")

    // Куда позже добавим:
    // implementation("com.wireguard.android:tunnel:1.0.20230706") // реальный WireGuard туннель
}

WINKVPN_EOF

cat > "app/src/main/AndroidManifest.xml" << 'WINKVPN_EOF'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_SPECIAL_USE" />

    <application
        android:allowBackup="true"
        android:icon="@drawable/ic_launcher_full"
        android:label="Wink VPN"
        android:roundIcon="@drawable/ic_launcher_full"
        android:theme="@style/Theme.WinkVpn"
        android:supportsRtl="true">

        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:theme="@style/Theme.WinkVpn">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>

        <!--
            Заготовка VPN-сервиса.
            Система Android требует явного объявления сервиса с этим intent-filter,
            чтобы приложение вообще могло запросить право быть VPN-клиентом.
            Реальный туннель (WireGuard) подключим сюда позже.
        -->
        <service
            android:name=".vpn.WinkVpnService"
            android:permission="android.permission.BIND_VPN_SERVICE"
            android:exported="false"
            android:foregroundServiceType="specialUse">
            <intent-filter>
                <action android:name="android.net.VpnService" />
            </intent-filter>
        </service>

    </application>
</manifest>

WINKVPN_EOF

cat > "app/src/main/java/com/winkvpn/app/AppState.kt" << 'WINKVPN_EOF'
package com.winkvpn.app

enum class Screen { SPLASH, WELCOME, TELEGRAM, TELEGRAM_THANKS, THANKS, MAIN }

data class VpnServer(
    val flag: String,
    val name: String,
    val ping: String,
    val ipPrefix: String,
    val speed: String
)

val servers = listOf(
    VpnServer("🇩🇪", "Германия", "11 мс", "185.220.10.", "92"),
    VpnServer("🇳🇱", "Нидерланды", "9 мс", "194.165.22.", "105"),
    VpnServer("🇫🇮", "Финляндия", "14 мс", "37.120.48.", "78"),
    VpnServer("🇸🇪", "Швеция", "13 мс", "46.166.18.", "88"),
)

WINKVPN_EOF

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
                val scope = rememberCoroutineScope()

                var isGoogleLoading by remember { mutableStateOf(false) }
                var googleErrorMessage by remember { mutableStateOf<String?>(null) }

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
                            onGoogleLogin = {
                                googleErrorMessage = null
                                isGoogleLoading = true
                                scope.launch {
                                    when (val result = GoogleAuthManager.signIn(this@MainActivity)) {
                                        is GoogleSignInResult.Success -> {
                                            isGoogleLoading = false
                                            screen = Screen.TELEGRAM
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
                            },
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

                        Screen.MAIN -> MainScreen()
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
import androidx.credentials.exceptions.GetCredentialException
import com.google.android.libraries.identity.googleid.GetGoogleIdOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import com.google.android.libraries.identity.googleid.GoogleIdTokenParsingException
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.providers.Google
import io.github.jan.supabase.auth.providers.builtin.IDToken

/**
 * ═══════════════════════════════════════════════════════════════════════
 * ВАЖНО: замени значение ниже на настоящий Google Web Client ID
 * (создаётся в Google Cloud Console → Credentials → Web application,
 * см. шаг 2.3 инструкции). Без этого Google-вход не заработает —
 * приложение будет показывать ошибку при попытке войти.
 * ═══════════════════════════════════════════════════════════════════════
 */
private const val GOOGLE_WEB_CLIENT_ID = "ВСТАВЬ_СЮДА_GOOGLE_WEB_CLIENT_ID.apps.googleusercontent.com"

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

                // Передаём Google ID-токен в Supabase — он сам проверит его
                // подлинность и создаст/найдёт пользователя в базе.
                SupabaseClientProvider.client.auth.signInWith(IDToken) {
                    this.idToken = idToken
                    provider = Google
                }

                GoogleSignInResult.Success
            } else {
                GoogleSignInResult.Error("Неожиданный тип учётных данных")
            }
        } catch (e: GetCredentialException) {
            GoogleSignInResult.Cancelled
        } catch (e: GoogleIdTokenParsingException) {
            GoogleSignInResult.Error("Не удалось разобрать токен Google: ${e.message}")
        } catch (e: Exception) {
            GoogleSignInResult.Error(e.message ?: "Неизвестная ошибка входа")
        }
    }

    /** Текущий пользователь уже авторизован (сессия восстановлена автоматически SDK) */
    fun isSignedIn(): Boolean {
        return SupabaseClientProvider.client.auth.currentUserOrNull() != null
    }

    suspend fun signOut() {
        SupabaseClientProvider.client.auth.signOut()
    }
}

WINKVPN_EOF

cat > "app/src/main/java/com/winkvpn/app/data/SupabaseClientProvider.kt" << 'WINKVPN_EOF'
package com.winkvpn.app.data

import io.github.jan.supabase.auth.Auth
import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.postgrest.Postgrest

/**
 * Единая точка входа в Supabase — база данных + авторизация.
 * URL и anon-ключ безопасны для встраивания в клиентский код: это ПУБЛИЧНЫЕ
 * ключи, специально предназначенные для использования в приложениях, доступ
 * к данным всё равно регулируется правилами Row Level Security на стороне
 * самого Supabase. Секретный service_role ключ сюда никогда не должен попадать.
 */
object SupabaseClientProvider {

    val client = createSupabaseClient(
        supabaseUrl = "https://zzriuszuflbuwtbpmtob.supabase.co",
        supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp6cml1c3p1ZmxidXd0YnBtdG9iIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU1NDM1ODgsImV4cCI6MjEwMTExOTU4OH0.r7iV4Y3huYX0PywOFIuXoLrExuomFaeb5GVDtaasF3g"
    ) {
        install(Auth)
        install(Postgrest)
    }
}

WINKVPN_EOF

cat > "app/src/main/java/com/winkvpn/app/ui/screens/BackgroundShapes.kt" << 'WINKVPN_EOF'
package com.winkvpn.app.ui.screens

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.RoundRect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathFillType
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.unit.dp
import kotlin.math.sin

private val DesignGrey = Color(0xFF4A4A4A)

@Composable
private fun rememberFloatOffset(periodMs: Int, amplitude: Float): androidx.compose.runtime.State<Float> {
    val transition = rememberInfiniteTransition(label = "float")
    val phase by transition.animateFloat(
        initialValue = 0f,
        targetValue = (2 * Math.PI).toFloat(),
        animationSpec = infiniteRepeatable(tween(periodMs, easing = LinearEasing), RepeatMode.Restart),
        label = "floatPhase"
    )
    return androidx.compose.runtime.remember {
        androidx.compose.runtime.derivedStateOf { sin(phase.toDouble()).toFloat() * amplitude }
    }
}

@Composable
fun KeyIcon(widthDp: Int, heightDp: Int, alpha: Float, modifier: Modifier = Modifier) {
    val dy by rememberFloatOffset(periodMs = 6500, amplitude = 10f)
    Canvas(
        modifier = modifier
            .size(width = widthDp.dp, height = heightDp.dp)
            .offset(y = dy.dp)
    ) {
        val w = size.width
        val h = size.height

        val ringOuterR = h * 0.42f
        val ringInnerR = h * 0.24f
        val ringCenter = Offset(w * 0.25f, h * 0.5f)

        val ring = Path().apply {
            fillType = PathFillType.EvenOdd
            addOval(Rect(center = ringCenter, radius = ringOuterR))
            addOval(Rect(center = ringCenter, radius = ringInnerR))
        }
        drawPath(ring, DesignGrey.copy(alpha = alpha * 0.9f))

        val shaftTop = h * 0.5f - h * 0.085f
        val shaftBottom = h * 0.5f + h * 0.085f
        val shaft = Path().apply {
            moveTo(ringCenter.x + ringOuterR * 0.58f, shaftTop)
            lineTo(w * 0.94f, shaftTop)
            lineTo(w * 0.94f, h * 0.5f + h * 0.36f)
            lineTo(w * 0.845f, h * 0.5f + h * 0.36f)
            lineTo(w * 0.845f, shaftBottom)
            lineTo(w * 0.72f, shaftBottom)
            lineTo(w * 0.72f, h * 0.5f + h * 0.24f)
            lineTo(w * 0.655f, h * 0.5f + h * 0.24f)
            lineTo(w * 0.655f, shaftBottom)
            lineTo(ringCenter.x + ringOuterR * 0.58f, shaftBottom)
            close()
        }
        drawPath(shaft, DesignGrey.copy(alpha = (alpha * 1.1f).coerceAtMost(1f)))
    }
}

@Composable
fun GiftIcon(sizeDp: Int, alpha: Float, modifier: Modifier = Modifier) {
    val dy by rememberFloatOffset(periodMs = 7200, amplitude = 9f)
    Canvas(
        modifier = modifier
            .size(sizeDp.dp)
            .offset(y = dy.dp)
    ) {
        drawGiftSilhouette(this, alpha)
    }
}

@Composable
fun GiftGlyph(sizeDp: Int = 22, tint: Color = Color.Black, modifier: Modifier = Modifier) {
    Canvas(modifier = modifier.size(sizeDp.dp)) {
        drawGiftGlyphSolid(this, tint)
    }
}

private fun drawGiftSilhouette(scope: DrawScope, alpha: Float) {
    with(scope) {
        val w = size.width
        val h = size.height
        val ribbonW = w * 0.15f

        val box = Path().apply {
            fillType = PathFillType.EvenOdd
            addRoundRect(
                RoundRect(
                    left = w * 0.13f, top = h * 0.43f, right = w * 0.87f, bottom = h * 0.93f,
                    cornerRadius = CornerRadius(w * 0.045f)
                )
            )
            addRect(Rect(left = w * 0.5f - ribbonW / 2, top = h * 0.43f, right = w * 0.5f + ribbonW / 2, bottom = h * 0.93f))
        }
        drawPath(box, DesignGrey.copy(alpha = alpha * 0.85f))

        val lid = Path().apply {
            addRoundRect(
                RoundRect(
                    left = w * 0.06f, top = h * 0.32f, right = w * 0.94f, bottom = h * 0.45f,
                    cornerRadius = CornerRadius(w * 0.03f)
                )
            )
        }
        drawPath(lid, DesignGrey.copy(alpha = (alpha * 1.05f).coerceAtMost(1f)))

        val leftPetal = Path().apply {
            moveTo(w * 0.5f, h * 0.35f)
            cubicTo(w * 0.5f, h * 0.14f, w * 0.24f, h * 0.04f, w * 0.19f, h * 0.19f)
            cubicTo(w * 0.15f, h * 0.31f, w * 0.34f, h * 0.35f, w * 0.5f, h * 0.35f)
            close()
        }
        drawPath(leftPetal, DesignGrey.copy(alpha = (alpha * 1.15f).coerceAtMost(1f)))
        val rightPetal = Path().apply {
            moveTo(w * 0.5f, h * 0.35f)
            cubicTo(w * 0.5f, h * 0.14f, w * 0.76f, h * 0.04f, w * 0.81f, h * 0.19f)
            cubicTo(w * 0.85f, h * 0.31f, w * 0.66f, h * 0.35f, w * 0.5f, h * 0.35f)
            close()
        }
        drawPath(rightPetal, DesignGrey.copy(alpha = (alpha * 1.15f).coerceAtMost(1f)))

        drawCircle(DesignGrey.copy(alpha = alpha), radius = w * 0.045f, center = Offset(w * 0.5f, h * 0.35f))
    }
}

private fun drawGiftGlyphSolid(scope: DrawScope, tint: Color) {
    with(scope) {
        val w = size.width
        val h = size.height
        val ribbonW = w * 0.16f

        val box = Path().apply {
            fillType = PathFillType.EvenOdd
            addRoundRect(
                RoundRect(
                    left = w * 0.14f, top = h * 0.42f, right = w * 0.86f, bottom = h * 0.92f,
                    cornerRadius = CornerRadius(w * 0.04f)
                )
            )
            addRect(Rect(left = w * 0.5f - ribbonW / 2, top = h * 0.42f, right = w * 0.5f + ribbonW / 2, bottom = h * 0.92f))
        }
        drawPath(box, tint)

        val lid = Path().apply {
            addRoundRect(
                RoundRect(
                    left = w * 0.08f, top = h * 0.32f, right = w * 0.92f, bottom = h * 0.44f,
                    cornerRadius = CornerRadius(w * 0.025f)
                )
            )
        }
        drawPath(lid, tint)

        val leftPetal = Path().apply {
            moveTo(w * 0.5f, h * 0.34f)
            cubicTo(w * 0.5f, h * 0.18f, w * 0.28f, h * 0.1f, w * 0.24f, h * 0.22f)
            cubicTo(w * 0.21f, h * 0.32f, w * 0.36f, h * 0.34f, w * 0.5f, h * 0.34f)
            close()
        }
        drawPath(leftPetal, tint)
        val rightPetal = Path().apply {
            moveTo(w * 0.5f, h * 0.34f)
            cubicTo(w * 0.5f, h * 0.18f, w * 0.72f, h * 0.1f, w * 0.76f, h * 0.22f)
            cubicTo(w * 0.79f, h * 0.32f, w * 0.64f, h * 0.34f, w * 0.5f, h * 0.34f)
            close()
        }
        drawPath(rightPetal, tint)
    }
}

@Composable
fun CurvedArrow(widthDp: Int, heightDp: Int, alpha: Float, modifier: Modifier = Modifier) {
    Canvas(modifier = modifier.size(width = widthDp.dp, height = heightDp.dp)) {
        val sw = size.width * 0.075f
        val stroke = Stroke(width = sw, cap = StrokeCap.Round, join = StrokeJoin.Round)
        val color = DesignGrey.copy(alpha = alpha)
        val w = size.width
        val h = size.height

        val path = Path().apply {
            moveTo(w * 0.77f, h * 0.055f)
            cubicTo(w * 1.0f, h * 0.28f, w * 0.92f, h * 0.53f, w * 0.58f, h * 0.69f)
            cubicTo(w * 0.365f, h * 0.8f, w * 0.27f, h * 0.83f, w * 0.26f, h * 0.945f)
        }
        drawPath(path, color, style = stroke)

        val tip = Path().apply {
            moveTo(w * 0.15f, h * 0.885f)
            lineTo(w * 0.26f, h * 0.97f)
            lineTo(w * 0.37f, h * 0.878f)
        }
        drawPath(tip, color, style = stroke)
    }
}

@Composable
fun TelegramPaperPlaneIcon(sizeDp: Int = 22, tint: Color = Color.White, modifier: Modifier = Modifier) {
    Canvas(modifier = modifier.size(sizeDp.dp)) {
        val w = size.width
        val h = size.height
        val plane = Path().apply {
            moveTo(w * 0.06f, h * 0.52f)
            lineTo(w * 0.94f, h * 0.10f)
            lineTo(w * 0.62f, h * 0.92f)
            lineTo(w * 0.47f, h * 0.60f)
            close()
        }
        drawPath(plane, tint)
    }
}

@Composable
fun HeadsetGlyph(sizeDp: Int = 22, tint: Color = Color.Black, modifier: Modifier = Modifier) {
    Canvas(modifier = modifier.size(sizeDp.dp)) {
        val w = size.width
        val h = size.height
        val sw = w * 0.14f

        val headband = Path().apply {
            addArc(Rect(w * 0.12f, h * 0.05f, w * 0.88f, h * 0.85f), startAngleDegrees = 180f, sweepAngleDegrees = 180f)
        }
        drawPath(headband, tint, style = Stroke(width = sw, cap = StrokeCap.Round))

        drawRoundRect(
            tint,
            topLeft = Offset(w * 0.06f, h * 0.55f),
            size = Size(w * 0.22f, h * 0.38f),
            cornerRadius = CornerRadius(w * 0.09f)
        )
        drawRoundRect(
            tint,
            topLeft = Offset(w * 0.72f, h * 0.55f),
            size = Size(w * 0.22f, h * 0.38f),
            cornerRadius = CornerRadius(w * 0.09f)
        )
    }
}

@Composable
fun PartyIcon(sizeDp: Int, alpha: Float, modifier: Modifier = Modifier) {
    val dy by rememberFloatOffset(periodMs = 6800, amplitude = 8f)
    Canvas(
        modifier = modifier
            .size(sizeDp.dp)
            .offset(y = dy.dp)
    ) {
        val w = size.width
        val h = size.height
        val color = DesignGrey.copy(alpha = alpha)

        val cone = Path().apply {
            moveTo(w * 0.09f, h * 0.94f)
            lineTo(w * 0.46f, h * 0.38f)
            lineTo(w * 0.72f, h * 0.64f)
            close()
        }
        drawPath(cone, color.copy(alpha = (alpha * 1.05f).coerceAtMost(1f)))

        val sw = w * 0.05f
        val cap = StrokeCap.Round
        drawLine(color, Offset(w * 0.60f, h * 0.28f), Offset(w * 0.80f, h * 0.12f), sw, cap)
        drawLine(color, Offset(w * 0.80f, h * 0.48f), Offset(w * 1.0f, h * 0.40f), sw, cap)
        drawLine(color, Offset(w * 0.66f, h * 0.70f), Offset(w * 0.88f, h * 0.78f), sw, cap)
        drawCircle(color, radius = w * 0.032f, center = Offset(w * 0.92f, h * 0.22f))
        drawCircle(color, radius = w * 0.024f, center = Offset(w * 0.55f, h * 0.10f))
        drawCircle(color, radius = w * 0.02f, center = Offset(w * 0.30f, h * 0.20f))
        drawCircle(color, radius = w * 0.026f, center = Offset(w * 0.95f, h * 0.62f))
    }
}

WINKVPN_EOF

cat > "app/src/main/java/com/winkvpn/app/ui/screens/Common.kt" << 'WINKVPN_EOF'
package com.winkvpn.app.ui.screens

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.winkvpn.app.R
import com.winkvpn.app.ui.theme.WinkBlack
import com.winkvpn.app.ui.theme.WinkBlack10
import com.winkvpn.app.ui.theme.WinkWhite

/** Логотип + название "Wink VPN" — переиспользуется на всех экранах онбординга */
@Composable
fun BrandBlock(logoSize: Int = 72, textSize: Int = 26) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Image(
            painter = painterResource(id = R.drawable.logo_wink),
            contentDescription = null,
            modifier = Modifier.height(logoSize.dp)
        )
        Spacer(Modifier.height(10.dp))
        Text(
            "Wink VPN",
            fontSize = textSize.sp,
            fontWeight = FontWeight.Black,
            fontStyle = FontStyle.Italic,
            color = WinkBlack
        )
    }
}

/** Заголовок + подзаголовок по центру */
@Composable
fun ScreenCopy(title: String, subtitle: String) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier.padding(horizontal = 30.dp)
    ) {
        Text(
            title,
            fontSize = 25.sp,
            fontWeight = FontWeight.Black,
            color = WinkBlack,
            textAlign = TextAlign.Center,
            lineHeight = 29.sp
        )
        if (subtitle.isNotBlank()) {
        Spacer(Modifier.height(12.dp))
        Text(
            subtitle,
            fontSize = 14.5.sp,
            fontWeight = FontWeight.Medium,
            color = WinkBlack.copy(alpha = 0.5f),
            textAlign = TextAlign.Center,
            lineHeight = 21.sp
        )
        }
    }
}

/** Основная чёрная кнопка с белым текстом — как на регистрации */
@Composable
fun PrimaryButton(
    text: String,
    modifier: Modifier = Modifier,
    leadingIcon: (@Composable () -> Unit)? = null,
    onClick: () -> Unit
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.Center,
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(100.dp))
            .background(WinkBlack)
            .clickable(onClick = onClick)
            .padding(vertical = 18.dp)
    ) {
        leadingIcon?.invoke()
        if (leadingIcon != null) Spacer(Modifier.width(10.dp))
        Text(text, color = WinkWhite, fontSize = 16.sp, fontWeight = FontWeight.Black)
    }
}

/** Второстепенная кнопка "Пропустить" — полупрозрачная */
@Composable
fun GhostButton(text: String, modifier: Modifier = Modifier, onClick: () -> Unit) {
    Box(
        contentAlignment = Alignment.Center,
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(100.dp))
            .background(WinkBlack10)
            .clickable(onClick = onClick)
            .padding(vertical = 18.dp)
    ) {
        Text(text, color = WinkBlack, fontSize = 16.sp, fontWeight = FontWeight.Black)
    }
}

/** Точки-индикатор прогресса онбординга (3 экрана) */
@Composable
fun StepDots(activeIndex: Int, total: Int = 3) {
    Row(horizontalArrangement = Arrangement.spacedBy(7.dp)) {
        repeat(total) { i ->
            Box(
                modifier = Modifier
                    .height(6.dp)
                    .width(if (i == activeIndex) 22.dp else 6.dp)
                    .clip(RoundedCornerShape(3.dp))
                    .background(if (i == activeIndex) WinkBlack else WinkBlack.copy(alpha = 0.2f))
            )
        }
    }
}

WINKVPN_EOF

cat > "app/src/main/java/com/winkvpn/app/ui/screens/MainScreen.kt" << 'WINKVPN_EOF'
@file:OptIn(androidx.compose.animation.ExperimentalAnimationApi::class)

package com.winkvpn.app.ui.screens

import android.content.Intent
import android.net.Uri
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.*
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.winkvpn.app.R
import com.winkvpn.app.VpnServer
import com.winkvpn.app.servers
import com.winkvpn.app.ui.theme.*
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.random.Random

private enum class ConnState { OFF, CONNECTING, ON }

@Composable
fun MainScreen() {
    var connState by remember { mutableStateOf(ConnState.OFF) }
    var serverIdx by remember { mutableIntStateOf(0) }
    var trafficMb by remember { mutableFloatStateOf(0f) }
    var connectingStepText by remember { mutableStateOf("Поиск сервера…") }
    var promoOpen by remember { mutableStateOf(false) }
    var confettiTrigger by remember { mutableIntStateOf(0) }

    val server = servers[serverIdx]
    val scope = rememberCoroutineScope()
    val context = androidx.compose.ui.platform.LocalContext.current

    // Счётчик трафика, пока подключено (имитация — как в HTML)
    LaunchedEffect(connState) {
        if (connState == ConnState.ON) {
            trafficMb = 0f
            while (true) {
                delay(1000)
                trafficMb += 0.21f
            }
        }
    }

    fun startConnecting() {
        connState = ConnState.CONNECTING
        scope.launch {
            val steps = listOf("Поиск сервера…", "Шифрование…", "Установка туннеля…")
            for (s in steps) {
                connectingStepText = s
                delay(450)
            }
            connState = ConnState.ON
        }
    }

    fun disconnect() {
        connState = ConnState.OFF
    }

    Box(modifier = Modifier.fillMaxSize()) {
        // фоновые тонкие стрелки
        Box(
            modifier = Modifier
                .align(Alignment.TopEnd)
                .offset(x = 10.dp, y = (-20).dp)
        ) {
            CurvedArrow(widthDp = 130, heightDp = 170, alpha = 0.09f)
        }

        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(top = 48.dp)
        ) {

            // Topbar — только логотип и название, без лишней кнопки
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 26.dp),
                horizontalArrangement = Arrangement.Start,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Image(
                    painter = painterResource(id = R.drawable.logo_wink),
                    contentDescription = null,
                    modifier = Modifier.height(26.dp)
                )
                Spacer(Modifier.width(10.dp))
                Text(
                    "Wink VPN",
                    fontSize = 22.sp,
                    fontWeight = FontWeight.Black,
                    fontStyle = FontStyle.Italic,
                    color = WinkBlack
                )
            }

            Spacer(Modifier.height(14.dp))

            // Status pill
            Box(modifier = Modifier.padding(start = 26.dp)) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .clip(RoundedCornerShape(99.dp))
                        .background(WinkBlack09)
                        .padding(horizontal = 18.dp, vertical = 9.dp)
                ) {
                    val dotColor by animateColorAsState(
                        if (connState == ConnState.ON) WinkGreen else Color(0xFF888888),
                        label = "dotColor"
                    )
                    Box(
                        modifier = Modifier
                            .size(9.dp)
                            .clip(CircleShape)
                            .background(dotColor)
                    )
                    Spacer(Modifier.width(8.dp))
                    Text(
                        if (connState == ConnState.ON) "Подключено" else "Не подключено",
                        fontSize = 13.sp, fontWeight = FontWeight.Bold, color = WinkBlack
                    )
                }
            }

            Spacer(Modifier.height(18.dp))

            // Power button
            Box(modifier = Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                PowerButton(
                    connected = connState == ConnState.ON,
                    connecting = connState == ConnState.CONNECTING,
                    onClick = {
                        when (connState) {
                            ConnState.OFF -> startConnecting()
                            ConnState.ON -> disconnect()
                            ConnState.CONNECTING -> {}
                        }
                    }
                )
            }

            Spacer(Modifier.height(18.dp))

            // Country selector
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 22.dp),
                horizontalArrangement = Arrangement.spacedBy(10.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .weight(1f)
                        .clip(RoundedCornerShape(99.dp))
                        .background(WinkBlack09)
                        .clickable { serverIdx = (serverIdx + 1) % servers.size }
                        .padding(horizontal = 16.dp, vertical = 11.dp)
                ) {
                    Text(server.flag, fontSize = 18.sp)
                    Spacer(Modifier.width(8.dp))
                    Text(server.name, fontSize = 14.sp, fontWeight = FontWeight.Bold, color = WinkBlack, modifier = Modifier.weight(1f))
                    Text("▼", fontSize = 12.sp, color = WinkBlack.copy(alpha = 0.35f))
                }
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    modifier = Modifier
                        .clip(RoundedCornerShape(18.dp))
                        .background(WinkBlack09)
                        .padding(horizontal = 14.dp, vertical = 11.dp)
                ) {
                    Text(
                        if (connState == ConnState.ON) server.speed else "—",
                        fontSize = 15.sp, fontWeight = FontWeight.Black, color = WinkBlack
                    )
                    Text("МБ/С", fontSize = 9.sp, fontWeight = FontWeight.Bold, color = WinkBlack.copy(alpha = 0.35f))
                }
            }

            Spacer(Modifier.height(16.dp))

            // Info cards
            Row(
                modifier = Modifier.fillMaxWidth().padding(horizontal = 22.dp),
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                InfoCard("Пинг", if (connState == ConnState.ON) server.ping else "—", Modifier.weight(1f))
                InfoCard("Трафик", if (connState == ConnState.ON) "${"%.1f".format(trafficMb)} МБ" else "—", Modifier.weight(1f))
                InfoCard("IP", if (connState == ConnState.ON) "${server.ipPrefix}${Random.nextInt(10, 99)}" else "—", Modifier.weight(1f), fontSize = 12)
            }

            // Connect button — сразу под карточками, а не внизу экрана
            Box(modifier = Modifier.fillMaxWidth().padding(horizontal = 22.dp).padding(top = 18.dp)) {
                val btnColor by animateColorAsState(
                    if (connState == ConnState.ON) Color(0xFF222222) else WinkBlack,
                    label = "connBtnColor"
                )
                Box(
                    contentAlignment = Alignment.Center,
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(100.dp))
                        .background(btnColor)
                        .clickable {
                            when (connState) {
                                ConnState.OFF -> startConnecting()
                                ConnState.ON -> disconnect()
                                ConnState.CONNECTING -> {}
                            }
                        }
                        .padding(vertical = 18.dp)
                ) {
                    Text(
                        if (connState == ConnState.ON) "Отключиться" else "Подключиться",
                        color = WinkWhite, fontSize = 16.sp, fontWeight = FontWeight.Black
                    )
                }
            }

            Spacer(Modifier.height(16.dp))

            // Три полупрозрачные серые кнопки: промокод / телеграм / поддержка
            Column(
                modifier = Modifier.fillMaxWidth().padding(horizontal = 22.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                ActionRowButton(
                    label = "Активировать промокод",
                    icon = { GiftGlyph(sizeDp = 20) },
                    onClick = { promoOpen = true }
                )
                ActionRowButton(
                    label = "Наш Telegram канал",
                    icon = { TelegramPaperPlaneIcon(sizeDp = 19, tint = WinkBlack) },
                    onClick = {
                        val intent = Intent(Intent.ACTION_VIEW, Uri.parse("https://t.me/Winkvpn_official"))
                        context.startActivity(intent)
                    }
                )
                ActionRowButton(
                    label = "Поддержка",
                    icon = { HeadsetGlyph(sizeDp = 20) },
                    onClick = {
                        val intent = Intent(Intent.ACTION_VIEW, Uri.parse("https://t.me/Winkvpn_official"))
                        context.startActivity(intent)
                    }
                )
            }

            Spacer(Modifier.height(24.dp))
            Spacer(Modifier.height(24.dp))
        }

        // Connecting overlay
        AnimatedVisibility(
            visible = connState == ConnState.CONNECTING,
            enter = fadeIn(tween(220, easing = FastOutSlowInEasing)),
            exit = fadeOut(tween(180, easing = FastOutSlowInEasing))
        ) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(WinkYellow.copy(alpha = 0.94f)),
                contentAlignment = Alignment.Center
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    SpinnerRing()
                    Spacer(Modifier.height(18.dp))
                    Text("Подключение…", fontSize = 18.sp, fontWeight = FontWeight.Black, color = WinkBlack)
                    Spacer(Modifier.height(4.dp))
                    Text(connectingStepText, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = WinkBlack.copy(alpha = 0.45f))
                }
            }
        }

        // Promo modal
        PromoModal(
            visible = promoOpen,
            onDismiss = { promoOpen = false },
            onSuccess = {
                confettiTrigger++
            },
            onOpenTelegram = {
                val intent = Intent(Intent.ACTION_VIEW, Uri.parse("https://t.me/Winkvpn_official"))
                context.startActivity(intent)
            }
        )

        // Confetti overlay
        ConfettiOverlay(trigger = confettiTrigger)
    }
}

@Composable
private fun PowerButton(connected: Boolean, connecting: Boolean, onClick: () -> Unit) {
    val ringColor by animateColorAsState(
        if (connected) WinkGreen else WinkBlack,
        animationSpec = tween(650), label = "ringColor"
    )

    val infinite = rememberInfiniteTransition(label = "glow")
    val glowPulse by infinite.animateFloat(
        initialValue = 0.14f, targetValue = 0.24f,
        animationSpec = infiniteRepeatable(tween(1600, easing = FastOutSlowInEasing), RepeatMode.Reverse),
        label = "glowPulse"
    )

    val spinAnim = remember { Animatable(0f) }
    LaunchedEffect(connecting) {
        if (connecting) {
            spinAnim.snapTo(0f)
            spinAnim.animateTo(360f, animationSpec = tween(500, easing = FastOutSlowInEasing))
        }
    }

    Box(
        modifier = Modifier.size(196.dp),
        contentAlignment = Alignment.Center
    ) {
        // мягкое зелёное свечение позади кольца, видно только при подключении
        if (connected) {
            Box(
                modifier = Modifier
                    .size(196.dp)
                    .clip(CircleShape)
                    .background(WinkGreen.copy(alpha = glowPulse))
            )
        }

        // единственное кольцо — просто чёрная полоска, зелёная при подключении
        Box(
            modifier = Modifier
                .size(168.dp)
                .border(width = 6.dp, color = ringColor, shape = CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Box(
                modifier = Modifier
                    .size(148.dp)
                    .clip(CircleShape)
                    .background(WinkYellow)
                    .clickable(onClick = onClick),
                contentAlignment = Alignment.Center
            ) {
                Image(
                    painter = painterResource(id = R.drawable.logo_wink),
                    contentDescription = null,
                    modifier = Modifier
                        .height(76.dp)
                        .graphicsLayer {
                            rotationZ = spinAnim.value
                        }
                )
            }
        }
    }
}

@Composable
private fun ActionRowButton(
    label: String,
    icon: @Composable () -> Unit,
    onClick: () -> Unit
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(20.dp))
            .background(WinkBlack09)
            .clickable(onClick = onClick)
            .padding(horizontal = 18.dp, vertical = 15.dp)
    ) {
        icon()
        Spacer(Modifier.width(14.dp))
        Text(label, fontSize = 14.5.sp, fontWeight = FontWeight.Bold, color = WinkBlack)
    }
}

@Composable
private fun InfoCard(label: String, value: String, modifier: Modifier = Modifier, fontSize: Int = 16) {
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(20.dp))
            .background(WinkBlack09)
            .padding(horizontal = 13.dp, vertical = 12.dp)
    ) {
        Text(label.uppercase(), fontSize = 10.sp, fontWeight = FontWeight.Black, color = WinkBlack38)
        Spacer(Modifier.height(4.dp))
        Text(value, fontSize = fontSize.sp, fontWeight = FontWeight.Black, color = WinkBlack)
    }
}

@Composable
private fun SpinnerRing() {
    val infinite = rememberInfiniteTransition(label = "spin")
    val rotation by infinite.animateFloat(
        0f, 360f,
        animationSpec = infiniteRepeatable(tween(750, easing = LinearEasing)),
        label = "rot"
    )
    Canvas(modifier = Modifier.size(52.dp).graphicsLayer { rotationZ = rotation }) {
        drawArc(
            color = WinkBlack,
            startAngle = 0f,
            sweepAngle = 90f,
            useCenter = false,
            style = androidx.compose.ui.graphics.drawscope.Stroke(width = 4.dp.toPx(), cap = androidx.compose.ui.graphics.StrokeCap.Round)
        )
        drawArc(
            color = WinkBlack.copy(alpha = 0.12f),
            startAngle = 90f,
            sweepAngle = 270f,
            useCenter = false,
            style = androidx.compose.ui.graphics.drawscope.Stroke(width = 4.dp.toPx(), cap = androidx.compose.ui.graphics.StrokeCap.Round)
        )
    }
}

@Composable
private fun PromoModal(
    visible: Boolean,
    onDismiss: () -> Unit,
    onSuccess: () -> Unit,
    onOpenTelegram: () -> Unit
) {
    var input by remember { mutableStateOf("") }
    var message by remember { mutableStateOf("") }
    var isError by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()

    AnimatedVisibility(
        visible = visible,
        enter = fadeIn(tween(260, easing = FastOutSlowInEasing)),
        exit = fadeOut(tween(200, easing = FastOutSlowInEasing))
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Color.Black.copy(alpha = 0.45f))
                .clickable(
                    indication = null,
                    interactionSource = remember { MutableInteractionSource() },
                    onClick = onDismiss
                )
        ) {
            Box(
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .fillMaxWidth()
                    .animateEnterExit(
                        enter = slideInVertically(
                            animationSpec = tween(340, easing = FastOutSlowInEasing),
                            initialOffsetY = { it }
                        ) + fadeIn(tween(260)),
                        exit = slideOutVertically(
                            animationSpec = tween(220, easing = FastOutSlowInEasing),
                            targetOffsetY = { it }
                        ) + fadeOut(tween(180))
                    )
                    .clip(RoundedCornerShape(topStart = 32.dp, topEnd = 32.dp))
                    .background(WinkYellow)
                    .clickable(
                        indication = null,
                        interactionSource = remember { MutableInteractionSource() },
                        onClick = {} // перехватывает тап, чтобы не закрывать модалку при клике внутри
                    )
                    .padding(horizontal = 26.dp, vertical = 24.dp)
            ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Box(
                    modifier = Modifier
                        .width(38.dp).height(4.dp)
                        .clip(RoundedCornerShape(99.dp))
                        .background(WinkBlack.copy(alpha = 0.2f))
                )
                Spacer(Modifier.height(22.dp))
                Text("Активация промокода", fontSize = 21.sp, fontWeight = FontWeight.Black, color = WinkBlack)
                Spacer(Modifier.height(8.dp))
                Text(
                    "Есть промокод? Активируйте ниже!",
                    fontSize = 14.sp, color = WinkBlack.copy(alpha = 0.5f),
                    fontWeight = FontWeight.Medium, textAlign = TextAlign.Center
                )
                Spacer(Modifier.height(22.dp))

                TextField(
                    value = input,
                    onValueChange = { input = it.uppercase() },
                    singleLine = true,
                    placeholder = {
                        Text(
                            "Введите промокод",
                            color = WinkBlack.copy(alpha = 0.3f),
                            fontSize = 16.sp, fontWeight = FontWeight.SemiBold,
                            modifier = Modifier.fillMaxWidth(), textAlign = TextAlign.Center
                        )
                    },
                    textStyle = TextStyle(
                        color = WinkBlack, fontSize = 16.sp, fontWeight = FontWeight.Black,
                        textAlign = TextAlign.Center
                    ),
                    colors = TextFieldDefaults.colors(
                        focusedContainerColor = WinkBlack.copy(alpha = 0.08f),
                        unfocusedContainerColor = WinkBlack.copy(alpha = 0.08f),
                        disabledContainerColor = WinkBlack.copy(alpha = 0.08f),
                        focusedIndicatorColor = Color.Transparent,
                        unfocusedIndicatorColor = Color.Transparent,
                        disabledIndicatorColor = Color.Transparent,
                        cursorColor = WinkBlack
                    ),
                    shape = RoundedCornerShape(18.dp),
                    modifier = Modifier.fillMaxWidth()
                )

                Spacer(Modifier.height(10.dp))
                if (message.isNotEmpty()) {
                    Text(
                        message,
                        fontSize = 13.sp, fontWeight = FontWeight.Bold,
                        color = if (isError) Color(0xFFC62828) else Color(0xFF1B8A3D)
                    )
                    Spacer(Modifier.height(6.dp))
                }

                PrimaryButton(text = "Активировать") {
                    if (input.trim().equals("test", ignoreCase = true)) {
                        message = "Промокод активирован! 🎉"
                        isError = false
                        onSuccess()
                        scope.launch {
                            delay(1400)
                            onDismiss()
                        }
                    } else {
                        message = "Такой промокод не найден"
                        isError = true
                    }
                }

                Spacer(Modifier.height(20.dp))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        "Новый промокод уже в нашем Telegram  ",
                        fontSize = 12.5.sp, color = WinkBlack.copy(alpha = 0.55f), fontWeight = FontWeight.SemiBold
                    )
                    Text(
                        "Перейти",
                        fontSize = 12.5.sp, color = WinkBlack, fontWeight = FontWeight.Black,
                        modifier = Modifier.clickable(
                            indication = null,
                            interactionSource = remember { MutableInteractionSource() },
                            onClick = onOpenTelegram
                        )
                    )
                }
            }
        }
    }
    }
}

private data class ConfettiPiece(
    val startX: Float,
    val color: Color,
    val delayMs: Int,
    val durationMs: Int,
    val rotationStart: Float,
    val isCircle: Boolean
)

@Composable
private fun ConfettiOverlay(trigger: Int) {
    if (trigger == 0) return
    var pieces by remember(trigger) {
        mutableStateOf(
            List(60) {
                ConfettiPiece(
                    startX = Random.nextFloat(),
                    color = listOf(WinkBlack, WinkYellow, WinkWhite, Color(0xFF333333)).random(),
                    delayMs = Random.nextInt(0, 400),
                    durationMs = Random.nextInt(2000, 3200),
                    rotationStart = Random.nextFloat() * 360f,
                    isCircle = Random.nextBoolean()
                )
            }
        )
    }
    var active by remember(trigger) { mutableStateOf(true) }
    LaunchedEffect(trigger) {
        active = true
        delay(3600)
        active = false
    }
    if (!active) return

    val density = LocalDensity.current
    BoxWithConstraints(modifier = Modifier.fillMaxSize()) {
        val heightPx = with(density) { maxHeight.toPx() }
        pieces.forEach { piece ->
            key(piece) {
                val progress = remember { Animatable(0f) }
                LaunchedEffect(piece) {
                    delay(piece.delayMs.toLong())
                    progress.animateTo(1f, animationSpec = tween(piece.durationMs, easing = LinearEasing))
                }
                val yOffsetPx = progress.value * heightPx
                val alpha = 1f - progress.value
                val rotation = piece.rotationStart + progress.value * 540f

                Box(
                    modifier = Modifier
                        .offset {
                            androidx.compose.ui.unit.IntOffset(
                                x = (piece.startX * (with(density) { maxWidth.toPx() })).toInt(),
                                y = yOffsetPx.toInt() - with(density) { 20.dp.toPx() }.toInt()
                            )
                        }
                        .size(width = 9.dp, height = 14.dp)
                        .graphicsLayer {
                            this.alpha = alpha.coerceIn(0f, 1f)
                            rotationZ = rotation
                        }
                        .clip(if (piece.isCircle) CircleShape else RoundedCornerShape(2.dp))
                        .background(piece.color)
                )
            }
        }
    }
}

WINKVPN_EOF

cat > "app/src/main/java/com/winkvpn/app/ui/screens/SplashScreen.kt" << 'WINKVPN_EOF'
package com.winkvpn.app.ui.screens

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.LinearOutSlowInEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.material3.Text
import com.winkvpn.app.R
import com.winkvpn.app.ui.theme.WinkBlack
import kotlinx.coroutines.delay

@Composable
fun SplashScreen(onFinished: () -> Unit) {
    val faceW = 280.dp
    val faceH = 262.dp
    val checkmarkOffset = Pair(105.7.dp, (-2.4).dp)
    val checkmarkSize = Pair(124.9.dp, 108.7.dp)
    val eyeOffset = Pair((-2.6).dp, 15.3.dp)
    val eyeSize = Pair(88.5.dp, 161.2.dp)
    val mouthOffset = Pair(21.0.dp, 125.1.dp)
    val mouthSize = Pair(261.4.dp, 139.3.dp)

    val starInitial = Pair(97.dp, (-33).dp)
    val starCenter = Pair(0.dp, 0.dp)
    val starFinal = Pair((-97).dp, 0.dp)

    val logoScale = remember { Animatable(0.82f) }
    val faceAlpha = remember { Animatable(1f) }
    val eyeScaleY = remember { Animatable(1f) }
    val starPhaseA = remember { Animatable(0f) }
    val starPhaseB = remember { Animatable(0f) }
    val floatingStarAlpha = remember { Animatable(1f) }
    val finalStarAlpha = remember { Animatable(0f) }
    var visibleCharCount by remember { mutableStateOf(0) }
    val fullText = "Wink VPN"

    LaunchedEffect(Unit) {
        logoScale.animateTo(1.05f, tween(420, easing = FastOutSlowInEasing))
        logoScale.animateTo(1f, tween(180, easing = FastOutSlowInEasing))

        eyeScaleY.animateTo(0.1f, tween(90, easing = FastOutSlowInEasing))
        eyeScaleY.animateTo(1f, tween(160, easing = FastOutSlowInEasing))

        delay(200)

        faceAlpha.animateTo(0f, tween(380, easing = FastOutSlowInEasing))

        starPhaseA.animateTo(1f, tween(380, easing = FastOutSlowInEasing))

        delay(40)

        starPhaseB.animateTo(1f, tween(420, easing = LinearOutSlowInEasing))
        floatingStarAlpha.animateTo(0f, tween(180, easing = FastOutSlowInEasing))
        finalStarAlpha.animateTo(1f, tween(180, easing = FastOutSlowInEasing))

        for (i in 1..fullText.length) {
            visibleCharCount = i
            delay(38)
        }

        delay(650)
        onFinished()
    }

    fun lerp(a: Dp, b: Dp, t: Float): Dp = a + (b - a) * t

    val starX: Dp
    val starY: Dp
    if (starPhaseB.value <= 0f) {
        starX = lerp(starInitial.first, starCenter.first, starPhaseA.value)
        starY = lerp(starInitial.second, starCenter.second, starPhaseA.value)
    } else {
        starX = lerp(starCenter.first, starFinal.first, starPhaseB.value)
        starY = lerp(starCenter.second, starFinal.second, starPhaseB.value)
    }

    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {

        Box(
            modifier = Modifier
                .size(faceW, faceH)
                .graphicsLayer {
                    scaleX = logoScale.value
                    scaleY = logoScale.value
                    alpha = faceAlpha.value
                }
        ) {
            Image(
                painter = painterResource(id = R.drawable.logo_mouth),
                contentDescription = null,
                contentScale = ContentScale.FillBounds,
                modifier = Modifier
                    .offset(x = mouthOffset.first, y = mouthOffset.second)
                    .size(mouthSize.first, mouthSize.second)
            )
            Image(
                painter = painterResource(id = R.drawable.logo_checkmark),
                contentDescription = null,
                contentScale = ContentScale.FillBounds,
                modifier = Modifier
                    .offset(x = checkmarkOffset.first, y = checkmarkOffset.second)
                    .size(checkmarkSize.first, checkmarkSize.second)
            )
            Image(
                painter = painterResource(id = R.drawable.logo_eye),
                contentDescription = null,
                contentScale = ContentScale.FillBounds,
                modifier = Modifier
                    .offset(x = eyeOffset.first, y = eyeOffset.second)
                    .size(eyeSize.first, eyeSize.second)
                    .graphicsLayer { scaleY = eyeScaleY.value }
            )
        }

        Image(
            painter = painterResource(id = R.drawable.logo_star),
            contentDescription = null,
            modifier = Modifier
                .size(30.dp)
                .offset(x = starX, y = starY)
                .graphicsLayer { alpha = floatingStarAlpha.value }
        )

        Row(verticalAlignment = Alignment.CenterVertically) {
            Image(
                painter = painterResource(id = R.drawable.logo_star),
                contentDescription = null,
                modifier = Modifier
                    .size(28.dp)
                    .graphicsLayer { alpha = finalStarAlpha.value }
            )
            Spacer(Modifier.width(10.dp))
            Box(modifier = Modifier.width(190.dp)) {
                Text(
                    fullText.take(visibleCharCount),
                    fontSize = 32.sp,
                    fontWeight = FontWeight.Black,
                    fontStyle = FontStyle.Italic,
                    color = WinkBlack
                )
            }
        }
    }
}

WINKVPN_EOF

cat > "app/src/main/java/com/winkvpn/app/ui/screens/TelegramScreen.kt" << 'WINKVPN_EOF'
@file:OptIn(androidx.compose.animation.ExperimentalAnimationApi::class)

package com.winkvpn.app.ui.screens

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.winkvpn.app.ui.theme.WinkBlack
import com.winkvpn.app.ui.theme.WinkYellow

@Composable
fun TelegramScreen(
    isWaitingForReturn: Boolean,
    onJoin: () -> Unit,
    onSkip: () -> Unit
) {
    Box(modifier = Modifier.fillMaxSize()) {
        GiftIcon(
            sizeDp = 220, alpha = 0.16f,
            modifier = Modifier.align(Alignment.TopEnd).offset(x = 45.dp, y = 75.dp)
        )
        GiftIcon(
            sizeDp = 170, alpha = 0.11f,
            modifier = Modifier.align(Alignment.BottomStart).offset(x = (-40).dp, y = (-110).dp)
        )

        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(top = 60.dp, bottom = 30.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Column(
                modifier = Modifier.weight(1f),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center
            ) {
                BrandBlock()
                Spacer(Modifier.height(30.dp))
                ScreenCopy(
                    title = "Присоединяйтесь к нашему Telegram каналу!",
                    subtitle = "Будьте в курсе новостей и получайте секретные промокоды!"
                )
                Spacer(Modifier.height(34.dp))
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 28.dp),
                    verticalArrangement = Arrangement.spacedBy(14.dp)
                ) {
                    PrimaryButton(
                        text = "Присоединиться",
                        leadingIcon = { TelegramPaperPlaneIcon(sizeDp = 20) },
                        onClick = onJoin
                    )
                    GhostButton(text = "Пропустить", onClick = onSkip)
                }
            }
            StepDots(activeIndex = 1)
        }

        // Модалка ожидания возврата из Telegram — плавное появление/исчезание
        AnimatedVisibility(
            visible = isWaitingForReturn,
            enter = fadeIn(tween(240, easing = FastOutSlowInEasing)),
            exit = fadeOut(tween(180, easing = FastOutSlowInEasing))
        ) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Color.Black.copy(alpha = 0.35f)),
                contentAlignment = Alignment.Center
            ) {
                Box(
                    modifier = Modifier
                        .padding(horizontal = 40.dp)
                        .animateEnterExit(
                            enter = scaleIn(tween(280, easing = FastOutSlowInEasing), initialScale = 0.85f) + fadeIn(tween(240)),
                            exit = scaleOut(tween(180), targetScale = 0.9f) + fadeOut(tween(150))
                        )
                        .background(WinkYellow, shape = androidx.compose.foundation.shape.RoundedCornerShape(24.dp))
                        .padding(horizontal = 28.dp, vertical = 26.dp)
                ) {
                    Text(
                        "Перенаправление, ожидаем возвращения!",
                        color = WinkBlack,
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Black,
                        textAlign = TextAlign.Center
                    )
                }
            }
        }
    }
}


WINKVPN_EOF

cat > "app/src/main/java/com/winkvpn/app/ui/screens/TelegramThanksScreen.kt" << 'WINKVPN_EOF'
package com.winkvpn.app.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

@Composable
fun TelegramThanksScreen(onContinue: () -> Unit) {
    Box(modifier = Modifier.fillMaxSize()) {
        PartyIcon(
            sizeDp = 200, alpha = 0.16f,
            modifier = Modifier.align(Alignment.TopEnd).offset(x = 40.dp, y = 80.dp)
        )
        PartyIcon(
            sizeDp = 150, alpha = 0.11f,
            modifier = Modifier.align(Alignment.BottomStart).offset(x = (-30).dp, y = (-100).dp)
        )

        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(top = 60.dp, bottom = 30.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Column(
                modifier = Modifier.weight(1f),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center
            ) {
                BrandBlock()
                Spacer(Modifier.height(30.dp))
                ScreenCopy(
                    title = "Спасибо за присоединение! Давайте продолжим",
                    subtitle = ""
                )
                Spacer(Modifier.height(34.dp))
                Box(modifier = Modifier.fillMaxWidth().padding(horizontal = 28.dp)) {
                    PrimaryButton(text = "Продолжить", onClick = onContinue)
                }
            }
        }
    }
}

WINKVPN_EOF

cat > "app/src/main/java/com/winkvpn/app/ui/screens/ThanksScreen.kt" << 'WINKVPN_EOF'
package com.winkvpn.app.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

@Composable
fun ThanksScreen(onStart: () -> Unit) {
    Box(modifier = Modifier.fillMaxSize()) {
        CurvedArrow(
            widthDp = 220, heightDp = 300, alpha = 0.18f,
            modifier = Modifier.align(Alignment.BottomCenter).offset(y = (-70).dp)
        )

        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(top = 60.dp, bottom = 30.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Column(
                modifier = Modifier.weight(1f),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center
            ) {
                BrandBlock()
                Spacer(Modifier.height(30.dp))
                ScreenCopy(
                    title = "Спасибо, что начали использовать Wink VPN!",
                    subtitle = "Начинай пользоваться уже — жми кнопку!"
                )
                Spacer(Modifier.height(34.dp))
                Box(modifier = Modifier.fillMaxWidth().padding(horizontal = 28.dp)) {
                    PrimaryButton(text = "Начать!", onClick = onStart)
                }
            }
            StepDots(activeIndex = 2)
        }
    }
}

WINKVPN_EOF

cat > "app/src/main/java/com/winkvpn/app/ui/screens/WelcomeScreen.kt" << 'WINKVPN_EOF'
package com.winkvpn.app.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable
fun WelcomeScreen(
    isLoading: Boolean,
    errorMessage: String?,
    onGoogleLogin: () -> Unit,
    onSkip: () -> Unit
) {
    Box(modifier = Modifier.fillMaxSize()) {
        KeyIcon(
            widthDp = 280, heightDp = 175, alpha = 0.16f,
            modifier = Modifier.align(Alignment.TopStart).offset(x = (-70).dp, y = 90.dp)
        )
        KeyIcon(
            widthDp = 210, heightDp = 131, alpha = 0.11f,
            modifier = Modifier.align(Alignment.BottomEnd).offset(x = 55.dp, y = (-130).dp)
        )

        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(top = 60.dp, bottom = 30.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Column(
                modifier = Modifier.weight(1f),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center
            ) {
                BrandBlock()
                Spacer(Modifier.height(30.dp))
                ScreenCopy(
                    title = "Добро пожаловать\nв Wink VPN!",
                    subtitle = "Вы можете войти в аккаунт, это поможет сохранить ваши бонусы!"
                )
                Spacer(Modifier.height(34.dp))
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 28.dp),
                    verticalArrangement = Arrangement.spacedBy(14.dp)
                ) {
                    PrimaryButton(
                        text = if (isLoading) "Входим…" else "Войти через Google",
                        leadingIcon = if (isLoading) null else { { GoogleGlyph() } },
                        onClick = { if (!isLoading) onGoogleLogin() }
                    )
                    GhostButton(text = "Пропустить", onClick = onSkip)
                    if (errorMessage != null) {
                        Text(
                            errorMessage,
                            color = Color(0xFFC62828),
                            fontSize = 12.5.sp,
                            fontWeight = FontWeight.Bold
                        )
                    }
                }
            }
            StepDots(activeIndex = 0)
        }
    }
}

/** Простая монохромная "G" — полноценную многоцветную Google-иконку можно добавить позже как drawable */
@Composable
private fun GoogleGlyph() {
    Box(
        modifier = androidx.compose.ui.Modifier.size(22.dp),
        contentAlignment = Alignment.Center
    ) {
        Text("G", color = Color.White, fontWeight = FontWeight.Black)
    }
}

WINKVPN_EOF

cat > "app/src/main/java/com/winkvpn/app/ui/theme/Theme.kt" << 'WINKVPN_EOF'
package com.winkvpn.app.ui.theme

import androidx.compose.ui.graphics.Color

val WinkYellow = Color(0xFFFFDA1A)
val WinkBlack = Color(0xFF111111)
val WinkWhite = Color(0xFFFFFFFF)
val WinkGreen = Color(0xFF16A34A)

val WinkBlack10 = Color(0x1A111111)
val WinkBlack09 = Color(0x17111111)
val WinkBlack38 = Color(0x61111111)
val WinkBlack50 = Color(0x80111111)

WINKVPN_EOF

cat > "app/src/main/java/com/winkvpn/app/vpn/WinkVpnService.kt" << 'WINKVPN_EOF'
package com.winkvpn.app.vpn

import android.net.VpnService
import android.content.Intent
import android.os.ParcelFileDescriptor

/**
 * ЗАГОТОВКА VPN-СЕРВИСА. Это НЕ рабочий VPN — только скелет с правильной
 * архитектурой Android VpnService, чтобы приложение уже сейчас могло
 * корректно запросить у системы разрешение на VPN-соединения.
 *
 * Что нужно добавить для реальной работы: зависимость WireGuard SDK,
 * конфиг сервера (публичный ключ, endpoint, allowed IPs) с бэкенда,
 * Builder().addAddress(...).addRoute(...).establish() — создание TUN-интерфейса.
 */
class WinkVpnService : VpnService() {

    private var tunInterface: ParcelFileDescriptor? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // TODO: здесь будет реальная установка туннеля через Builder(), когда подключим WireGuard
        return START_STICKY
    }

    override fun onDestroy() {
        tunInterface?.close()
        tunInterface = null
        super.onDestroy()
    }

    override fun onRevoke() {
        tunInterface?.close()
        stopSelf()
    }
}

WINKVPN_EOF

cat > "app/src/main/res/values/colors.xml" << 'WINKVPN_EOF'
<resources>
    <color name="wink_yellow">#FFFFDA1A</color>
</resources>

WINKVPN_EOF

cat > "app/src/main/res/values/strings.xml" << 'WINKVPN_EOF'
<resources>
    <string name="app_name">Wink VPN</string>
</resources>

WINKVPN_EOF

cat > "app/src/main/res/values/themes.xml" << 'WINKVPN_EOF'
<resources>
    <style name="Theme.WinkVpn" parent="android:Theme.Material.Light.NoActionBar">
        <item name="android:windowBackground">@color/wink_yellow</item>
        <item name="android:colorBackground">@color/wink_yellow</item>
        <item name="android:windowDisablePreview">false</item>
    </style>
</resources>

WINKVPN_EOF

cat > "build.gradle.kts" << 'WINKVPN_EOF'
// Top-level build file
plugins {
    id("com.android.application") version "8.5.0" apply false
    id("org.jetbrains.kotlin.android") version "1.9.24" apply false
    id("org.jetbrains.kotlin.plugin.serialization") version "1.9.24" apply false
}

WINKVPN_EOF

cat > "gradle.properties" << 'WINKVPN_EOF'
org.gradle.jvmargs=-Xmx2048m -Dfile.encoding=UTF-8
android.useAndroidX=true
android.nonTransitiveRClass=true
kotlin.code.style=official

WINKVPN_EOF

cat > "gradle/wrapper/gradle-wrapper.properties" << 'WINKVPN_EOF'
distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
distributionUrl=https\://services.gradle.org/distributions/gradle-8.7-bin.zip
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists

WINKVPN_EOF

cat > "settings.gradle.kts" << 'WINKVPN_EOF'
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "WinkVPN"
include(":app")

WINKVPN_EOF

cat > "app/src/main/res/drawable/ic_launcher_full.png.b64" << 'WINKVPN_EOF'
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
WINKVPN_EOF
base64 -d "app/src/main/res/drawable/ic_launcher_full.png.b64" > "app/src/main/res/drawable/ic_launcher_full.png"
rm "app/src/main/res/drawable/ic_launcher_full.png.b64"

cat > "app/src/main/res/drawable/logo_checkmark.png.b64" << 'WINKVPN_EOF'
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
WINKVPN_EOF
base64 -d "app/src/main/res/drawable/logo_checkmark.png.b64" > "app/src/main/res/drawable/logo_checkmark.png"
rm "app/src/main/res/drawable/logo_checkmark.png.b64"

cat > "app/src/main/res/drawable/logo_eye.png.b64" << 'WINKVPN_EOF'
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
WINKVPN_EOF
base64 -d "app/src/main/res/drawable/logo_eye.png.b64" > "app/src/main/res/drawable/logo_eye.png"
rm "app/src/main/res/drawable/logo_eye.png.b64"

cat > "app/src/main/res/drawable/logo_mouth.png.b64" << 'WINKVPN_EOF'
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
WINKVPN_EOF
base64 -d "app/src/main/res/drawable/logo_mouth.png.b64" > "app/src/main/res/drawable/logo_mouth.png"
rm "app/src/main/res/drawable/logo_mouth.png.b64"

cat > "app/src/main/res/drawable/logo_star.png.b64" << 'WINKVPN_EOF'
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
WINKVPN_EOF
base64 -d "app/src/main/res/drawable/logo_star.png.b64" > "app/src/main/res/drawable/logo_star.png"
rm "app/src/main/res/drawable/logo_star.png.b64"

cat > "app/src/main/res/drawable/logo_wink.png.b64" << 'WINKVPN_EOF'
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
WINKVPN_EOF
base64 -d "app/src/main/res/drawable/logo_wink.png.b64" > "app/src/main/res/drawable/logo_wink.png"
rm "app/src/main/res/drawable/logo_wink.png.b64"

echo ""
echo "════════════════════════════════════════════════════════"
echo "Готово! Проект развёрнут."
echo ""
echo "ВАЖНО: перед сборкой замени плейсхолдер в файле:"
echo "  app/src/main/java/com/winkvpn/app/data/GoogleAuthManager.kt"
echo "на настоящий Google Web Client ID (константа GOOGLE_WEB_CLIENT_ID)."
echo "Без этого Google-вход не заработает."
echo ""
echo "Дальше: git add -A && git commit -m wink_init && git push"
echo "════════════════════════════════════════════════════════"