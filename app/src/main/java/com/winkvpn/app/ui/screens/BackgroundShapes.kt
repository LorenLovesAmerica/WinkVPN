package com.winkvpn.app.ui.screens

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.RoundRect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathFillType
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.unit.dp
import kotlin.math.sin

/**
 * Все фоновые декоративные фигуры — ТОЛЬКО сплошная заливка, без единой
 * обводки/линии. Раньше многосоставные линии (Stroke) на стыках давали
 * эффект "перекрывающихся маркерных штрихов" — теперь везде цельный силуэт.
 */
private val DesignGrey = Color(0xFF4A4A4A)

@Composable
private fun rememberFloatOffset(periodMs: Int, amplitude: Float): androidx.compose.runtime.State<Float> {
    val transition = rememberInfiniteTransition(label = "float")
    val phase by transition.animateFloat(
        initialValue = 0f,
        targetValue = (2 * Math.PI).toFloat(),
        animationSpec = infiniteRepeatable(tween(periodMs, easing = LinearEasing), RepeatMode.Restart),
        label = "floatPhase"
    )
    return androidx.compose.runtime.remember {
        androidx.compose.runtime.derivedStateOf { sin(phase.toDouble()).toFloat() * amplitude }
    }
}

/** Ключ — простой цельный силуэт: кольцо (evenOdd, сплошная заливка) + один блок-стержень с зубцом */
@Composable
fun KeyIcon(widthDp: Int, heightDp: Int, alpha: Float, modifier: Modifier = Modifier) {
    val dy by rememberFloatOffset(periodMs = 6500, amplitude = 10f)
    Canvas(
        modifier = modifier
            .size(width = widthDp.dp, height = heightDp.dp)
            .offset(y = dy.dp)
    ) {
        val w = size.width
        val h = size.height
        val color = DesignGrey.copy(alpha = alpha)

        val ringOuterR = h * 0.44f
        val ringInnerR = h * 0.24f
        val ringCenter = Offset(w * 0.27f, h * 0.5f)

        val ring = Path().apply {
            fillType = PathFillType.EvenOdd
            addOval(Rect(center = ringCenter, radius = ringOuterR))
            addOval(Rect(center = ringCenter, radius = ringInnerR))
        }
        drawPath(ring, color)

        // стержень + один широкий зубец — единая сплошная фигура, без штрихов
        val shaftTop = h * 0.5f - h * 0.1f
        val shaftBottom = h * 0.5f + h * 0.1f
        val shaft = Path().apply {
            moveTo(ringCenter.x + ringOuterR * 0.62f, shaftTop)
            lineTo(w * 0.92f, shaftTop)
            lineTo(w * 0.92f, h * 0.5f + h * 0.34f)
            lineTo(w * 0.78f, h * 0.5f + h * 0.34f)
            lineTo(w * 0.78f, shaftBottom)
            lineTo(ringCenter.x + ringOuterR * 0.62f, shaftBottom)
            close()
        }
        drawPath(shaft, color)
    }
}

/** Подарок — цельная заливка: коробка + крышка + простой бант, без обводок */
@Composable
fun GiftIcon(sizeDp: Int, alpha: Float, modifier: Modifier = Modifier) {
    val dy by rememberFloatOffset(periodMs = 7200, amplitude = 9f)
    Canvas(
        modifier = modifier
            .size(sizeDp.dp)
            .offset(y = dy.dp)
    ) {
        drawGiftSilhouette(this, DesignGrey.copy(alpha = alpha))
    }
}

@Composable
fun GiftGlyph(sizeDp: Int = 22, tint: Color = Color.Black, modifier: Modifier = Modifier) {
    Canvas(modifier = modifier.size(sizeDp.dp)) {
        drawGiftSilhouette(this, tint)
    }
}

private fun drawGiftSilhouette(scope: DrawScope, color: Color) {
    with(scope) {
        val w = size.width
        val h = size.height
        val ribbonW = w * 0.15f

        val box = Path().apply {
            fillType = PathFillType.EvenOdd
            addRoundRect(
                RoundRect(
                    left = w * 0.13f, top = h * 0.43f, right = w * 0.87f, bottom = h * 0.93f,
                    cornerRadius = CornerRadius(w * 0.045f)
                )
            )
            addRect(Rect(left = w * 0.5f - ribbonW / 2, top = h * 0.43f, right = w * 0.5f + ribbonW / 2, bottom = h * 0.93f))
        }
        drawPath(box, color)

        val lid = Path().apply {
            addRoundRect(
                RoundRect(
                    left = w * 0.06f, top = h * 0.32f, right = w * 0.94f, bottom = h * 0.45f,
                    cornerRadius = CornerRadius(w * 0.03f)
                )
            )
        }
        drawPath(lid, color)

        val leftPetal = Path().apply {
            moveTo(w * 0.5f, h * 0.35f)
            cubicTo(w * 0.5f, h * 0.14f, w * 0.24f, h * 0.04f, w * 0.19f, h * 0.19f)
            cubicTo(w * 0.15f, h * 0.31f, w * 0.34f, h * 0.35f, w * 0.5f, h * 0.35f)
            close()
        }
        drawPath(leftPetal, color)
        val rightPetal = Path().apply {
            moveTo(w * 0.5f, h * 0.35f)
            cubicTo(w * 0.5f, h * 0.14f, w * 0.76f, h * 0.04f, w * 0.81f, h * 0.19f)
            cubicTo(w * 0.85f, h * 0.31f, w * 0.66f, h * 0.35f, w * 0.5f, h * 0.35f)
            close()
        }
        drawPath(rightPetal, color)

        drawCircle(color, radius = w * 0.045f, center = Offset(w * 0.5f, h * 0.35f))
    }
}

/**
 * Стрелка — теперь сплошной силуэт "запятой"/хука, указывающий вниз,
 * а не тонкая линия (раньше линия выглядела как маркерный штрих).
 */
@Composable
fun CurvedArrow(widthDp: Int, heightDp: Int, alpha: Float, modifier: Modifier = Modifier) {
    Canvas(modifier = modifier.size(width = widthDp.dp, height = heightDp.dp)) {
        val w = size.width
        val h = size.height
        val color = DesignGrey.copy(alpha = alpha)

        // Сплошная фигура-"хук": широкая дуга, сужающаяся к наконечнику снизу
        val path = Path().apply {
            moveTo(w * 0.62f, h * 0.02f)
            cubicTo(w * 0.98f, h * 0.22f, w * 0.95f, h * 0.55f, w * 0.55f, h * 0.72f)
            cubicTo(w * 0.40f, h * 0.78f, w * 0.32f, h * 0.80f, w * 0.30f, h * 0.90f)
            lineTo(w * 0.46f, h * 0.90f)
            lineTo(w * 0.22f, h * 1.0f)
            lineTo(w * 0.06f, h * 0.84f)
            lineTo(w * 0.20f, h * 0.84f)
            cubicTo(w * 0.22f, h * 0.68f, w * 0.34f, h * 0.62f, w * 0.50f, h * 0.55f)
            cubicTo(w * 0.80f, h * 0.42f, w * 0.82f, h * 0.24f, w * 0.50f, h * 0.10f)
            close()
        }
        drawPath(path, color)
    }
}

/** Иконка Telegram — сплошной силуэт бумажного самолётика */
@Composable
fun TelegramPaperPlaneIcon(sizeDp: Int = 22, tint: Color = Color.White, modifier: Modifier = Modifier) {
    Canvas(modifier = modifier.size(sizeDp.dp)) {
        val w = size.width
        val h = size.height
        val plane = Path().apply {
            moveTo(w * 0.06f, h * 0.52f)
            lineTo(w * 0.94f, h * 0.10f)
            lineTo(w * 0.62f, h * 0.92f)
            lineTo(w * 0.47f, h * 0.60f)
            close()
        }
        drawPath(plane, tint)
    }
}

/** Иконка наушников (поддержка) — сплошные детали, дуга — толстая заливка вместо обводки */
@Composable
fun HeadsetGlyph(sizeDp: Int = 22, tint: Color = Color.Black, modifier: Modifier = Modifier) {
    Canvas(modifier = modifier.size(sizeDp.dp)) {
        val w = size.width
        val h = size.height

        // дуга оголовья — сплошная заливка (кольцо через evenOdd), не обводка
        val band = Path().apply {
            fillType = PathFillType.EvenOdd
            addArc(Rect(w * 0.10f, h * 0.02f, w * 0.90f, h * 0.86f), startAngleDegrees = 180f, sweepAngleDegrees = 180f)
            lineTo(w * 0.90f, h * 0.5f)
            addArc(Rect(w * 0.24f, h * 0.16f, w * 0.76f, h * 0.86f), startAngleDegrees = 0f, sweepAngleDegrees = -180f)
            close()
        }
        drawPath(band, tint)

        drawRoundRect(
            tint,
            topLeft = Offset(w * 0.06f, h * 0.55f),
            size = Size(w * 0.22f, h * 0.38f),
            cornerRadius = CornerRadius(w * 0.09f)
        )
        drawRoundRect(
            tint,
            topLeft = Offset(w * 0.72f, h * 0.55f),
            size = Size(w * 0.22f, h * 0.38f),
            cornerRadius = CornerRadius(w * 0.09f)
        )
    }
}

/** "Праздничная" иконка — сплошной конус + сплошные конфетти-фигурки (без линий-штрихов) */
@Composable
fun PartyIcon(sizeDp: Int, alpha: Float, modifier: Modifier = Modifier) {
    val dy by rememberFloatOffset(periodMs = 6800, amplitude = 8f)
    Canvas(
        modifier = modifier
            .size(sizeDp.dp)
            .offset(y = dy.dp)
    ) {
        val w = size.width
        val h = size.height
        val color = DesignGrey.copy(alpha = alpha)

        val cone = Path().apply {
            moveTo(w * 0.09f, h * 0.94f)
            lineTo(w * 0.46f, h * 0.38f)
            lineTo(w * 0.72f, h * 0.64f)
            close()
        }
        drawPath(cone, color)

        // конфетти — сплошные фигурки (кружки и квадратики), не линии
        drawCircle(color, radius = w * 0.035f, center = Offset(w * 0.72f, h * 0.20f))
        drawCircle(color, radius = w * 0.026f, center = Offset(w * 0.55f, h * 0.10f))
        drawCircle(color, radius = w * 0.03f, center = Offset(w * 0.92f, h * 0.30f))

        rotate(degrees = 20f, pivot = Offset(w * 0.85f, h * 0.52f)) {
            drawRect(
                color,
                topLeft = Offset(w * 0.80f, h * 0.47f),
                size = Size(w * 0.10f, h * 0.10f)
            )
        }
        rotate(degrees = -15f, pivot = Offset(w * 0.62f, h * 0.72f)) {
            drawRect(
                color,
                topLeft = Offset(w * 0.58f, h * 0.68f),
                size = Size(w * 0.08f, h * 0.08f)
            )
        }
    }
}

