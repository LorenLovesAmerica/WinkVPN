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

                // Как только попадаем на главный экран — подгружаем профиль
                LaunchedEffect(screen) {
                    if (screen == Screen.MAIN && profile == null) {
                        val fetched = ProfileRepository.fetchCurrentProfile()
                        if (fetched != null) {
                            profile = fetched
                            appLanguage = if (fetched.language == "en") AppLanguage.EN else AppLanguage.RU
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

                        Screen.MAIN -> MainScreen(
                            onProfileClick = {
                                previousScreen = Screen.MAIN
                                screen = Screen.PROFILE
                            }
                        )

                        Screen.PROFILE -> ProfileScreen(
                            email = profile?.email,
                            nickname = profile?.nickname ?: "",
                            userNumber = profile?.user_number,
                            language = appLanguage,
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

