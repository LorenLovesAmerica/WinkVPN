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

/** Узнаваемая иконка "человек" — голова + купол плеч одним силуэтом (не два кружочка) */
@Composable
fun PersonIcon(sizeDp: Int = 20, tint: Color = Color.Black, modifier: Modifier = Modifier) {
    Canvas(modifier = modifier.size(sizeDp.dp)) {
        val w = size.width
        val h = size.height

        // голова
        drawCircle(tint, radius = w * 0.17f, center = Offset(w * 0.5f, h * 0.27f))

        // плечи/тело — купол: узкий сверху, широкий снизу, низ уходит за край
        // иконки (Canvas сам обрежет по своим границам — получается плоский низ)
        val body = Path().apply {
            moveTo(w * 0.5f, h * 0.40f)
            cubicTo(w * 0.22f, h * 0.40f, w * 0.10f, h * 0.62f, w * 0.10f, h * 1.05f)
            lineTo(w * 0.90f, h * 1.05f)
            cubicTo(w * 0.90f, h * 0.62f, w * 0.78f, h * 0.40f, w * 0.5f, h * 0.40f)
            close()
        }
        drawPath(body, tint)
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

