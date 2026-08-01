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

