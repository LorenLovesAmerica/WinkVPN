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

