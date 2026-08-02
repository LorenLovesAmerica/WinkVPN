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

