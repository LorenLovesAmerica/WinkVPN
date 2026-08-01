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

