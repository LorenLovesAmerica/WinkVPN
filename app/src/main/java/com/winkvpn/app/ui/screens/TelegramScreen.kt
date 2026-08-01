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


