#!/usr/bin/env bash
# WinFix8.sh — реальная база данных (Supabase Postgres) + профиль пользователя:
# уникальный 5-значный ID, никнейм, выбор языка (RU/EN), значок профиля на главном,
# только сервер Германия, новая раскладка нижних кнопок (промокод/telegram/поддержка
# слева компактно + большая карточка 'Безлимитная подписка' справа), поддержка теперь
# ведёт на @WinkSupport_Bot. Google Web Client ID уже вписан в код.
set -e
echo "Обновляю файлы..."

mkdir -p "app"
mkdir -p "app/src/main/java/com/winkvpn/app"
mkdir -p "app/src/main/java/com/winkvpn/app/data"
mkdir -p "app/src/main/java/com/winkvpn/app/ui/screens"

cat > "supabase_migration.sql" << 'WINKVPN_EOF'
-- ═══════════════════════════════════════════════════════════════════
-- Wink VPN — таблица профилей пользователей
-- Выполнить в Supabase Dashboard → SQL Editor → New query → Run
-- ═══════════════════════════════════════════════════════════════════

-- Последовательность для 5-значных ID пользователей (10000, 10001, 10002...)
create sequence if not exists public.user_number_seq start with 10000 increment by 1;

-- Таблица профилей — одна строка на пользователя, привязана к auth.users
create table if not exists public.profiles (
  id uuid references auth.users on delete cascade primary key,
  user_number bigint unique not null default nextval('public.user_number_seq'),
  email text,
  nickname text,
  language text not null default 'ru',
  created_at timestamptz not null default now()
);

-- Функция: при регистрации нового пользователя автоматически создаём профиль
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, email, nickname, language)
  values (
    new.id,
    new.email,
    split_part(coalesce(new.email, 'user'), '@', 1),
    'ru'
  )
  on conflict (id) do nothing;
  return new;
end;
$$ language plpgsql security definer set search_path = public;

-- Триггер: срабатывает сразу после создания записи в auth.users
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- Row Level Security — каждый видит и меняет только свою запись
alter table public.profiles enable row level security;

drop policy if exists "Users can view own profile" on public.profiles;
create policy "Users can view own profile"
  on public.profiles for select
  using (auth.uid() = id);

drop policy if exists "Users can update own profile" on public.profiles;
create policy "Users can update own profile"
  on public.profiles for update
  using (auth.uid() = id);

-- ═══════════════════════════════════════════════════════════════════
-- Готово. Проверить: Table Editor → profiles — таблица должна появиться.
-- Как только кто-то войдёт через Google, строка создастся автоматически.
-- ═══════════════════════════════════════════════════════════════════

WINKVPN_EOF

cat > "app/build.gradle.kts" << 'WINKVPN_EOF'
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.serialization")
    id("org.jetbrains.kotlin.plugin.compose")
}

android {
    namespace = "com.winkvpn.app"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.winkvpn.app"
        minSdk = 26
        targetSdk = 36
        versionCode = 1
        versionName = "0.2.0-alpha"
    }

    buildFeatures {
        compose = true
    }

    // ПРИМЕЧАНИЕ: начиная с Kotlin 2.0, компилятор Compose — отдельный плагин
    // (org.jetbrains.kotlin.plugin.compose, подключён выше), поэтому старый
    // блок composeOptions { kotlinCompilerExtensionVersion = ... } больше не нужен.

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildTypes {
        release {
            isMinifyEnabled = false
        }
    }
}

// Начиная с новых версий Kotlin Gradle Plugin, старый синтаксис
// `kotlinOptions { jvmTarget = "17" }` внутри android{} стал ошибкой —
// теперь настройки компилятора Kotlin задаются отдельным top-level блоком.
kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.activity:activity-compose:1.9.0")
    implementation(platform("androidx.compose:compose-bom:2026.06.00"))
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
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.7.3")

    // ── Google Sign-In через современный Credential Manager API ──
    implementation("androidx.credentials:credentials:1.3.0")
    implementation("androidx.credentials:credentials-play-services-auth:1.3.0")
    implementation("com.google.android.libraries.identity.googleid:googleid:1.1.1")

    // Куда позже добавим:
    // implementation("com.wireguard.android:tunnel:1.0.20230706") // реальный WireGuard туннель
}

WINKVPN_EOF

cat > "app/src/main/java/com/winkvpn/app/AppState.kt" << 'WINKVPN_EOF'
package com.winkvpn.app

enum class Screen { SPLASH, WELCOME, TELEGRAM, TELEGRAM_THANKS, THANKS, MAIN, PROFILE }

enum class AppLanguage { RU, EN }

data class VpnServer(
    val flag: String,
    val name: String,
    val ping: String,
    val ipPrefix: String,
    val speed: String
)

// Пока только одна честная рабочая локация — Германия.
// Остальные страны уберём из выбора, пока не поднимем для них отдельные серверы.
val servers = listOf(
    VpnServer("🇩🇪", "Германия", "11 мс", "185.220.10.", "92"),
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
 * Web Client ID из Google Cloud Console (создан ранее в этом чате,
 * тип Web application — именно он нужен для проверки токена на стороне Supabase).
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

cat > "app/src/main/java/com/winkvpn/app/data/ProfileRepository.kt" << 'WINKVPN_EOF'
package com.winkvpn.app.data

import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.postgrest.from
import kotlinx.serialization.Serializable

@Serializable
data class Profile(
    val id: String,
    val user_number: Long = 0,
    val email: String? = null,
    val nickname: String? = null,
    val language: String = "ru"
)

object ProfileRepository {

    /** Достаёт профиль текущего вошедшего пользователя (строка уже создана
     * автоматически триггером в Supabase в момент первой регистрации). */
    suspend fun fetchCurrentProfile(): Profile? {
        val userId = SupabaseClientProvider.client.auth.currentUserOrNull()?.id ?: return null
        return SupabaseClientProvider.client.from("profiles")
            .select {
                filter { eq("id", userId) }
            }
            .decodeSingleOrNull<Profile>()
    }

    suspend fun updateNickname(nickname: String) {
        val userId = SupabaseClientProvider.client.auth.currentUserOrNull()?.id ?: return
        SupabaseClientProvider.client.from("profiles").update(
            { set("nickname", nickname) }
        ) {
            filter { eq("id", userId) }
        }
    }

    suspend fun updateLanguage(language: String) {
        val userId = SupabaseClientProvider.client.auth.currentUserOrNull()?.id ?: return
        SupabaseClientProvider.client.from("profiles").update(
            { set("language", language) }
        ) {
            filter { eq("id", userId) }
        }
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

/** Простая, узнаваемая иконка "человек в кружке" — для кнопки профиля */
@Composable
fun PersonIcon(sizeDp: Int = 20, tint: Color = Color.Black, modifier: Modifier = Modifier) {
    Canvas(modifier = modifier.size(sizeDp.dp)) {
        val w = size.width
        val h = size.height

        // голова
        drawCircle(tint, radius = w * 0.19f, center = Offset(w * 0.5f, h * 0.32f))

        // плечи — низ окружности, "срезанный" верхом прямоугольной области
        val shoulders = Path().apply {
            addOval(
                androidx.compose.ui.geometry.Rect(
                    left = w * 0.16f, top = h * 0.52f, right = w * 0.84f, bottom = h * 1.22f
                )
            )
        }
        drawPath(shoulders, tint)
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
    email: String?,
    nickname: String,
    userNumber: Long?,
    language: AppLanguage,
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

            // Верхняя панель — назад + заголовок
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

            Spacer(Modifier.height(32.dp))

            // Большой аватар
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

            Spacer(Modifier.height(14.dp))

            // ID пользователя
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

            // Почта (только просмотр)
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

            // Ник (редактируемый)
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

            // Язык
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
                        .background(WinkBlack09)
                        .padding(16.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.Center
                    ) {
                        InfinityIcon(widthDp = 46, heightDp = 24, tint = WinkBlack)
                        Spacer(Modifier.height(10.dp))
                        Text(
                            "Безлимитная\nподписка",
                            fontSize = 14.sp,
                            fontWeight = FontWeight.Black,
                            color = WinkBlack,
                            textAlign = TextAlign.Center,
                            lineHeight = 17.sp
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

echo ""
echo "════════════════════════════════════════════════════════"
echo "Готово! Файлы обновлены."
echo ""
echo "ВАЖНО — сделай это ДО того как кто-то попробует войти:"
echo "1) Открой Supabase -> SQL Editor -> New query"
echo "2) Вставь содержимое файла supabase_migration.sql (он в корне репозитория)"
echo "3) Нажми Run"
echo ""
echo "Дальше: git add -A && git commit -m profile_and_db && git push"
echo "════════════════════════════════════════════════════════"