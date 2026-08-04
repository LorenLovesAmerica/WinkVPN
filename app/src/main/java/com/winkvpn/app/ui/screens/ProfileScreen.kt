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

