#!/usr/bin/env bash
# WinFix11.sh — фоновые фигуры теперь только сплошная заливка (без обводок,
# которые выглядели как перекрывающиеся маркерные штрихи), премиальная
# чёрная карточка 'Безлимитная подписка' открывает полноэкранную PRO-подписку
# с 3 тарифами и красными бейджами скидок, аватар в профиле стал заметнее
# (чёрный кружок с жёлтой иконкой в чёрной обводке), и фикс: если после входа
# через Google подгрузка профиля падала — весь процесс замирал молча,
# теперь обёрнуто в try/catch с повторной попыткой.
set -e
echo "Обновляю файлы..."

mkdir -p "app/src/main/java/com/winkvpn/app"
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
                                // Раньше если этот запрос падал (например, профиль ещё
                                // не успел создаться триггером), исключение улетало
                                // необработанным и весь процесс входа замирал молча —
                                // кнопка навсегда оставалась в состоянии "Входим…".
                                try {
                                    var fetched = ProfileRepository.fetchCurrentProfile()
                                    if (fetched == null) {
                                        // На случай если строка профиля создаётся триггером
                                        // с небольшой задержкой сразу после регистрации —
                                        // одна повторная попытка через паузу.
                                        kotlinx.coroutines.delay(500)
                                        fetched = ProfileRepository.fetchCurrentProfile()
                                    }
                                    applyProfile(fetched)
                                } catch (e: Exception) {
                                    // не критично — подтянем профиль позже
                                }
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
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.unit.dp
import kotlin.math.sin

/**
 * Все фоновые декоративные фигуры — ТОЛЬКО сплошная заливка, без единой
 * обводки/линии. Раньше многосоставные линии (Stroke) на стыках давали
 * эффект "перекрывающихся маркерных штрихов" — теперь везде цельный силуэт.
 */
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

/** Ключ — простой цельный силуэт: кольцо (evenOdd, сплошная заливка) + один блок-стержень с зубцом */
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
        val color = DesignGrey.copy(alpha = alpha)

        val ringOuterR = h * 0.44f
        val ringInnerR = h * 0.24f
        val ringCenter = Offset(w * 0.27f, h * 0.5f)

        val ring = Path().apply {
            fillType = PathFillType.EvenOdd
            addOval(Rect(center = ringCenter, radius = ringOuterR))
            addOval(Rect(center = ringCenter, radius = ringInnerR))
        }
        drawPath(ring, color)

        // стержень + один широкий зубец — единая сплошная фигура, без штрихов
        val shaftTop = h * 0.5f - h * 0.1f
        val shaftBottom = h * 0.5f + h * 0.1f
        val shaft = Path().apply {
            moveTo(ringCenter.x + ringOuterR * 0.62f, shaftTop)
            lineTo(w * 0.92f, shaftTop)
            lineTo(w * 0.92f, h * 0.5f + h * 0.34f)
            lineTo(w * 0.78f, h * 0.5f + h * 0.34f)
            lineTo(w * 0.78f, shaftBottom)
            lineTo(ringCenter.x + ringOuterR * 0.62f, shaftBottom)
            close()
        }
        drawPath(shaft, color)
    }
}

/** Подарок — цельная заливка: коробка + крышка + простой бант, без обводок */
@Composable
fun GiftIcon(sizeDp: Int, alpha: Float, modifier: Modifier = Modifier) {
    val dy by rememberFloatOffset(periodMs = 7200, amplitude = 9f)
    Canvas(
        modifier = modifier
            .size(sizeDp.dp)
            .offset(y = dy.dp)
    ) {
        drawGiftSilhouette(this, DesignGrey.copy(alpha = alpha))
    }
}

@Composable
fun GiftGlyph(sizeDp: Int = 22, tint: Color = Color.Black, modifier: Modifier = Modifier) {
    Canvas(modifier = modifier.size(sizeDp.dp)) {
        drawGiftSilhouette(this, tint)
    }
}

private fun drawGiftSilhouette(scope: DrawScope, color: Color) {
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
        drawPath(box, color)

        val lid = Path().apply {
            addRoundRect(
                RoundRect(
                    left = w * 0.06f, top = h * 0.32f, right = w * 0.94f, bottom = h * 0.45f,
                    cornerRadius = CornerRadius(w * 0.03f)
                )
            )
        }
        drawPath(lid, color)

        val leftPetal = Path().apply {
            moveTo(w * 0.5f, h * 0.35f)
            cubicTo(w * 0.5f, h * 0.14f, w * 0.24f, h * 0.04f, w * 0.19f, h * 0.19f)
            cubicTo(w * 0.15f, h * 0.31f, w * 0.34f, h * 0.35f, w * 0.5f, h * 0.35f)
            close()
        }
        drawPath(leftPetal, color)
        val rightPetal = Path().apply {
            moveTo(w * 0.5f, h * 0.35f)
            cubicTo(w * 0.5f, h * 0.14f, w * 0.76f, h * 0.04f, w * 0.81f, h * 0.19f)
            cubicTo(w * 0.85f, h * 0.31f, w * 0.66f, h * 0.35f, w * 0.5f, h * 0.35f)
            close()
        }
        drawPath(rightPetal, color)

        drawCircle(color, radius = w * 0.045f, center = Offset(w * 0.5f, h * 0.35f))
    }
}

/**
 * Стрелка — теперь сплошной силуэт "запятой"/хука, указывающий вниз,
 * а не тонкая линия (раньше линия выглядела как маркерный штрих).
 */
@Composable
fun CurvedArrow(widthDp: Int, heightDp: Int, alpha: Float, modifier: Modifier = Modifier) {
    Canvas(modifier = modifier.size(width = widthDp.dp, height = heightDp.dp)) {
        val w = size.width
        val h = size.height
        val color = DesignGrey.copy(alpha = alpha)

        // Сплошная фигура-"хук": широкая дуга, сужающаяся к наконечнику снизу
        val path = Path().apply {
            moveTo(w * 0.62f, h * 0.02f)
            cubicTo(w * 0.98f, h * 0.22f, w * 0.95f, h * 0.55f, w * 0.55f, h * 0.72f)
            cubicTo(w * 0.40f, h * 0.78f, w * 0.32f, h * 0.80f, w * 0.30f, h * 0.90f)
            lineTo(w * 0.46f, h * 0.90f)
            lineTo(w * 0.22f, h * 1.0f)
            lineTo(w * 0.06f, h * 0.84f)
            lineTo(w * 0.20f, h * 0.84f)
            cubicTo(w * 0.22f, h * 0.68f, w * 0.34f, h * 0.62f, w * 0.50f, h * 0.55f)
            cubicTo(w * 0.80f, h * 0.42f, w * 0.82f, h * 0.24f, w * 0.50f, h * 0.10f)
            close()
        }
        drawPath(path, color)
    }
}

/** Иконка Telegram — сплошной силуэт бумажного самолётика */
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

/** Иконка наушников (поддержка) — сплошные детали, дуга — толстая заливка вместо обводки */
@Composable
fun HeadsetGlyph(sizeDp: Int = 22, tint: Color = Color.Black, modifier: Modifier = Modifier) {
    Canvas(modifier = modifier.size(sizeDp.dp)) {
        val w = size.width
        val h = size.height

        // дуга оголовья — сплошная заливка (кольцо через evenOdd), не обводка
        val band = Path().apply {
            fillType = PathFillType.EvenOdd
            addArc(Rect(w * 0.10f, h * 0.02f, w * 0.90f, h * 0.86f), startAngleDegrees = 180f, sweepAngleDegrees = 180f)
            lineTo(w * 0.90f, h * 0.5f)
            addArc(Rect(w * 0.24f, h * 0.16f, w * 0.76f, h * 0.86f), startAngleDegrees = 0f, sweepAngleDegrees = -180f)
            close()
        }
        drawPath(band, tint)

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

/** "Праздничная" иконка — сплошной конус + сплошные конфетти-фигурки (без линий-штрихов) */
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
        drawPath(cone, color)

        // конфетти — сплошные фигурки (кружки и квадратики), не линии
        drawCircle(color, radius = w * 0.035f, center = Offset(w * 0.72f, h * 0.20f))
        drawCircle(color, radius = w * 0.026f, center = Offset(w * 0.55f, h * 0.10f))
        drawCircle(color, radius = w * 0.03f, center = Offset(w * 0.92f, h * 0.30f))

        rotate(degrees = 20f, pivot = Offset(w * 0.85f, h * 0.52f)) {
            drawRect(
                color,
                topLeft = Offset(w * 0.80f, h * 0.47f),
                size = Size(w * 0.10f, h * 0.10f)
            )
        }
        rotate(degrees = -15f, pivot = Offset(w * 0.62f, h * 0.72f)) {
            drawRect(
                color,
                topLeft = Offset(w * 0.58f, h * 0.68f),
                size = Size(w * 0.08f, h * 0.08f)
            )
        }
    }
}

WINKVPN_EOF

cat > "app/src/main/java/com/winkvpn/app/ui/screens/ProfileScreen.kt" << 'WINKVPN_EOF'
package com.winkvpn.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
                        .size(104.dp)
                        .clip(CircleShape)
                        .background(WinkBlack.copy(alpha = 0.08f))
                        .border(width = 3.dp, color = WinkBlack, shape = CircleShape),
                    contentAlignment = Alignment.Center
                ) {
                    Box(
                        modifier = Modifier
                            .size(84.dp)
                            .clip(CircleShape)
                            .background(WinkBlack),
                        contentAlignment = Alignment.Center
                    ) {
                        PersonIcon(sizeDp = 42, tint = WinkYellow)
                    }
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
fun MainScreen(onProfileClick: () -> Unit = {}) {
    var connState by remember { mutableStateOf(ConnState.OFF) }
    var serverIdx by remember { mutableIntStateOf(0) }
    var trafficMb by remember { mutableFloatStateOf(0f) }
    var connectingStepText by remember { mutableStateOf("Поиск сервера…") }
    var promoOpen by remember { mutableStateOf(false) }
    var subscriptionOpen by remember { mutableStateOf(false) }
    var selectedPlan by remember { mutableStateOf(1) } // 0=1мес, 1=3мес, 2=12мес — по умолчанию самый выгодный
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

            // Topbar — значок профиля слева, рядом логотип и название
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 26.dp),
                horizontalArrangement = Arrangement.Start,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Box(
                    modifier = Modifier
                        .size(38.dp)
                        .clip(RoundedCornerShape(12.dp))
                        .background(WinkBlack09)
                        .clickable(onClick = onProfileClick),
                    contentAlignment = Alignment.Center
                ) {
                    PersonIcon(sizeDp = 19, tint = WinkBlack)
                }
                Spacer(Modifier.width(12.dp))
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

            // Сервер — пока только Германия
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
                        .padding(horizontal = 16.dp, vertical = 11.dp)
                ) {
                    Text(server.flag, fontSize = 18.sp)
                    Spacer(Modifier.width(8.dp))
                    Text(server.name, fontSize = 14.sp, fontWeight = FontWeight.Bold, color = WinkBlack, modifier = Modifier.weight(1f))
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

            // Слева — компактные ячейки (промокод / телеграм / поддержка),
            // справа — большой квадрат "Безлимитная подписка"
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 22.dp)
                    .height(IntrinsicSize.Min),
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                Column(
                    modifier = Modifier.weight(1f),
                    verticalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    CompactActionCell(
                        label = "Промокод",
                        icon = { GiftGlyph(sizeDp = 20) },
                        onClick = { promoOpen = true }
                    )
                    CompactActionCell(
                        label = "Наш Telegram",
                        icon = { TelegramPaperPlaneIcon(sizeDp = 19, tint = WinkBlack) },
                        onClick = {
                            val intent = Intent(Intent.ACTION_VIEW, Uri.parse("https://t.me/Winkvpn_official"))
                            context.startActivity(intent)
                        }
                    )
                    CompactActionCell(
                        label = "Поддержка",
                        icon = { HeadsetGlyph(sizeDp = 20) },
                        onClick = {
                            val intent = Intent(Intent.ACTION_VIEW, Uri.parse("https://t.me/WinkSupport_Bot"))
                            context.startActivity(intent)
                        }
                    )
                }

                Box(
                    modifier = Modifier
                        .weight(1f)
                        .fillMaxHeight()
                        .clip(RoundedCornerShape(22.dp))
                        .background(WinkBlack)
                        .clickable { subscriptionOpen = true }
                        .padding(16.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.Center
                    ) {
                        Box(
                            modifier = Modifier
                                .clip(RoundedCornerShape(14.dp))
                                .background(WinkYellow)
                                .padding(horizontal = 12.dp, vertical = 8.dp)
                        ) {
                            InfinityIcon(widthDp = 42, heightDp = 22, tint = WinkBlack)
                        }
                        Spacer(Modifier.height(12.dp))
                        Text(
                            "Безлимитная\nподписка",
                            fontSize = 14.sp,
                            fontWeight = FontWeight.Black,
                            color = WinkWhite,
                            textAlign = TextAlign.Center,
                            lineHeight = 17.sp
                        )
                        Spacer(Modifier.height(6.dp))
                        Text(
                            "PRO",
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Black,
                            color = WinkYellow,
                            letterSpacing = 1.5.sp
                        )
                    }
                }
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

        // Subscription modal
        SubscriptionScreen(
            visible = subscriptionOpen,
            selectedPlan = selectedPlan,
            onSelectPlan = { selectedPlan = it },
            onDismiss = { subscriptionOpen = false }
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
private fun CompactActionCell(
    label: String,
    icon: @Composable () -> Unit,
    onClick: () -> Unit
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(WinkBlack09)
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 13.dp)
    ) {
        icon()
        Spacer(Modifier.width(10.dp))
        Text(
            label,
            fontSize = 13.sp,
            fontWeight = FontWeight.Bold,
            color = WinkBlack,
            maxLines = 1
        )
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

private data class PricingPlan(
    val label: String,
    val price: String,
    val badges: List<String>
)

private val pricingPlans = listOf(
    PricingPlan("1 месяц", "119₽", emptyList()),
    PricingPlan("3 месяца", "299₽", listOf("Скидка!")),
    PricingPlan("12 месяцев", "999₽", listOf("Скидка", "Самое выгодное предложение")),
)

@Composable
private fun SubscriptionScreen(
    visible: Boolean,
    selectedPlan: Int,
    onSelectPlan: (Int) -> Unit,
    onDismiss: () -> Unit
) {
    AnimatedVisibility(
        visible = visible,
        enter = fadeIn(tween(300, easing = FastOutSlowInEasing)) +
            slideInVertically(tween(340, easing = FastOutSlowInEasing), initialOffsetY = { it / 6 }),
        exit = fadeOut(tween(220, easing = FastOutSlowInEasing)) +
            slideOutVertically(tween(220, easing = FastOutSlowInEasing), targetOffsetY = { it / 6 })
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(WinkYellow)
        ) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 26.dp)
            ) {
                Spacer(Modifier.height(56.dp))

                Row(verticalAlignment = Alignment.CenterVertically) {
                    Box(
                        modifier = Modifier
                            .size(38.dp)
                            .clip(RoundedCornerShape(12.dp))
                            .background(WinkBlack09)
                            .clickable(onClick = onDismiss),
                        contentAlignment = Alignment.Center
                    ) {
                        Text("←", fontSize = 18.sp, fontWeight = FontWeight.Black, color = WinkBlack)
                    }
                    Spacer(Modifier.width(14.dp))
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(10.dp))
                            .background(WinkBlack)
                            .padding(horizontal = 10.dp, vertical = 5.dp)
                    ) {
                        InfinityIcon(widthDp = 26, heightDp = 14, tint = WinkYellow)
                    }
                }

                Spacer(Modifier.height(28.dp))

                Text(
                    "PRO Подписка включает:",
                    fontSize = 24.sp,
                    fontWeight = FontWeight.Black,
                    color = WinkBlack,
                    lineHeight = 28.sp
                )

                Spacer(Modifier.height(22.dp))

                val features = listOf(
                    "Безлимитное продление работы VPN бесплатно",
                    "Отключение рекламы",
                    "Новые и улучшенные регионы (постепенно добавляем новые)",
                    "Быстрый трафик"
                )
                Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                    features.forEach { feature ->
                        Row(verticalAlignment = Alignment.Top) {
                            Box(
                                modifier = Modifier
                                    .padding(top = 7.dp)
                                    .size(6.dp)
                                    .clip(RoundedCornerShape(3.dp))
                                    .background(WinkBlack)
                            )
                            Spacer(Modifier.width(12.dp))
                            Text(
                                feature,
                                fontSize = 15.sp,
                                fontWeight = FontWeight.SemiBold,
                                color = WinkBlack,
                                lineHeight = 21.sp
                            )
                        }
                    }
                }

                Spacer(Modifier.height(32.dp))

                Text(
                    "Выберите тариф",
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Black,
                    color = WinkBlack.copy(alpha = 0.4f),
                    letterSpacing = 0.5.sp
                )
                Spacer(Modifier.height(12.dp))

                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    pricingPlans.forEachIndexed { index, plan ->
                        PricingCard(
                            plan = plan,
                            selected = selectedPlan == index,
                            onClick = { onSelectPlan(index) }
                        )
                    }
                }

                Spacer(Modifier.height(24.dp))

                PrimaryButton(text = "Оформить подписку") {
                    // TODO: подключить реальную оплату (платёжный провайдер) на бэкенде
                    onDismiss()
                }

                Spacer(Modifier.height(40.dp))
            }
        }
    }
}

@Composable
private fun PricingCard(
    plan: PricingPlan,
    selected: Boolean,
    onClick: () -> Unit
) {
    Box {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = if (plan.badges.isNotEmpty()) 12.dp else 0.dp)
                .clip(RoundedCornerShape(18.dp))
                .background(if (selected) WinkBlack else WinkBlack09)
                .clickable(onClick = onClick)
                .padding(horizontal = 20.dp, vertical = 18.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    plan.label,
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Black,
                    color = if (selected) WinkWhite else WinkBlack
                )
                Text(
                    plan.price,
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Black,
                    color = if (selected) WinkYellow else WinkBlack
                )
            }
        }

        // Красные бейджи-вывески — аккуратно наверху карточки, чуть внахлёст
        if (plan.badges.isNotEmpty()) {
            Row(
                modifier = Modifier
                    .align(Alignment.TopStart)
                    .padding(start = 16.dp),
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                plan.badges.forEach { badge ->
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(8.dp))
                            .background(Color(0xFFE53935))
                            .padding(horizontal = 9.dp, vertical = 4.dp)
                    ) {
                        Text(
                            badge,
                            fontSize = 10.sp,
                            fontWeight = FontWeight.Black,
                            color = WinkWhite
                        )
                    }
                }
            }
        }
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

echo "Готово!"
echo "Дальше: git add -A && git commit -m subscription_and_fixes && git push"