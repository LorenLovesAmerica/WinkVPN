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

