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
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.unit.dp
import kotlin.math.sin

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

        val ringOuterR = h * 0.42f
        val ringInnerR = h * 0.24f
        val ringCenter = Offset(w * 0.25f, h * 0.5f)

        val ring = Path().apply {
            fillType = PathFillType.EvenOdd
            addOval(Rect(center = ringCenter, radius = ringOuterR))
            addOval(Rect(center = ringCenter, radius = ringInnerR))
        }
        drawPath(ring, DesignGrey.copy(alpha = alpha * 0.9f))

        val shaftTop = h * 0.5f - h * 0.085f
        val shaftBottom = h * 0.5f + h * 0.085f
        val shaft = Path().apply {
            moveTo(ringCenter.x + ringOuterR * 0.58f, shaftTop)
            lineTo(w * 0.94f, shaftTop)
            lineTo(w * 0.94f, h * 0.5f + h * 0.36f)
            lineTo(w * 0.845f, h * 0.5f + h * 0.36f)
            lineTo(w * 0.845f, shaftBottom)
            lineTo(w * 0.72f, shaftBottom)
            lineTo(w * 0.72f, h * 0.5f + h * 0.24f)
            lineTo(w * 0.655f, h * 0.5f + h * 0.24f)
            lineTo(w * 0.655f, shaftBottom)
            lineTo(ringCenter.x + ringOuterR * 0.58f, shaftBottom)
            close()
        }
        drawPath(shaft, DesignGrey.copy(alpha = (alpha * 1.1f).coerceAtMost(1f)))
    }
}

@Composable
fun GiftIcon(sizeDp: Int, alpha: Float, modifier: Modifier = Modifier) {
    val dy by rememberFloatOffset(periodMs = 7200, amplitude = 9f)
    Canvas(
        modifier = modifier
            .size(sizeDp.dp)
            .offset(y = dy.dp)
    ) {
        drawGiftSilhouette(this, alpha)
    }
}

@Composable
fun GiftGlyph(sizeDp: Int = 22, tint: Color = Color.Black, modifier: Modifier = Modifier) {
    Canvas(modifier = modifier.size(sizeDp.dp)) {
        drawGiftGlyphSolid(this, tint)
    }
}

private fun drawGiftSilhouette(scope: DrawScope, alpha: Float) {
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
        drawPath(box, DesignGrey.copy(alpha = alpha * 0.85f))

        val lid = Path().apply {
            addRoundRect(
                RoundRect(
                    left = w * 0.06f, top = h * 0.32f, right = w * 0.94f, bottom = h * 0.45f,
                    cornerRadius = CornerRadius(w * 0.03f)
                )
            )
        }
        drawPath(lid, DesignGrey.copy(alpha = (alpha * 1.05f).coerceAtMost(1f)))

        val leftPetal = Path().apply {
            moveTo(w * 0.5f, h * 0.35f)
            cubicTo(w * 0.5f, h * 0.14f, w * 0.24f, h * 0.04f, w * 0.19f, h * 0.19f)
            cubicTo(w * 0.15f, h * 0.31f, w * 0.34f, h * 0.35f, w * 0.5f, h * 0.35f)
            close()
        }
        drawPath(leftPetal, DesignGrey.copy(alpha = (alpha * 1.15f).coerceAtMost(1f)))
        val rightPetal = Path().apply {
            moveTo(w * 0.5f, h * 0.35f)
            cubicTo(w * 0.5f, h * 0.14f, w * 0.76f, h * 0.04f, w * 0.81f, h * 0.19f)
            cubicTo(w * 0.85f, h * 0.31f, w * 0.66f, h * 0.35f, w * 0.5f, h * 0.35f)
            close()
        }
        drawPath(rightPetal, DesignGrey.copy(alpha = (alpha * 1.15f).coerceAtMost(1f)))

        drawCircle(DesignGrey.copy(alpha = alpha), radius = w * 0.045f, center = Offset(w * 0.5f, h * 0.35f))
    }
}

private fun drawGiftGlyphSolid(scope: DrawScope, tint: Color) {
    with(scope) {
        val w = size.width
        val h = size.height
        val ribbonW = w * 0.16f

        val box = Path().apply {
            fillType = PathFillType.EvenOdd
            addRoundRect(
                RoundRect(
                    left = w * 0.14f, top = h * 0.42f, right = w * 0.86f, bottom = h * 0.92f,
                    cornerRadius = CornerRadius(w * 0.04f)
                )
            )
            addRect(Rect(left = w * 0.5f - ribbonW / 2, top = h * 0.42f, right = w * 0.5f + ribbonW / 2, bottom = h * 0.92f))
        }
        drawPath(box, tint)

        val lid = Path().apply {
            addRoundRect(
                RoundRect(
                    left = w * 0.08f, top = h * 0.32f, right = w * 0.92f, bottom = h * 0.44f,
                    cornerRadius = CornerRadius(w * 0.025f)
                )
            )
        }
        drawPath(lid, tint)

        val leftPetal = Path().apply {
            moveTo(w * 0.5f, h * 0.34f)
            cubicTo(w * 0.5f, h * 0.18f, w * 0.28f, h * 0.1f, w * 0.24f, h * 0.22f)
            cubicTo(w * 0.21f, h * 0.32f, w * 0.36f, h * 0.34f, w * 0.5f, h * 0.34f)
            close()
        }
        drawPath(leftPetal, tint)
        val rightPetal = Path().apply {
            moveTo(w * 0.5f, h * 0.34f)
            cubicTo(w * 0.5f, h * 0.18f, w * 0.72f, h * 0.1f, w * 0.76f, h * 0.22f)
            cubicTo(w * 0.79f, h * 0.32f, w * 0.64f, h * 0.34f, w * 0.5f, h * 0.34f)
            close()
        }
        drawPath(rightPetal, tint)
    }
}

@Composable
fun CurvedArrow(widthDp: Int, heightDp: Int, alpha: Float, modifier: Modifier = Modifier) {
    Canvas(modifier = modifier.size(width = widthDp.dp, height = heightDp.dp)) {
        val sw = size.width * 0.075f
        val stroke = Stroke(width = sw, cap = StrokeCap.Round, join = StrokeJoin.Round)
        val color = DesignGrey.copy(alpha = alpha)
        val w = size.width
        val h = size.height

        val path = Path().apply {
            moveTo(w * 0.77f, h * 0.055f)
            cubicTo(w * 1.0f, h * 0.28f, w * 0.92f, h * 0.53f, w * 0.58f, h * 0.69f)
            cubicTo(w * 0.365f, h * 0.8f, w * 0.27f, h * 0.83f, w * 0.26f, h * 0.945f)
        }
        drawPath(path, color, style = stroke)

        val tip = Path().apply {
            moveTo(w * 0.15f, h * 0.885f)
            lineTo(w * 0.26f, h * 0.97f)
            lineTo(w * 0.37f, h * 0.878f)
        }
        drawPath(tip, color, style = stroke)
    }
}

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

@Composable
fun HeadsetGlyph(sizeDp: Int = 22, tint: Color = Color.Black, modifier: Modifier = Modifier) {
    Canvas(modifier = modifier.size(sizeDp.dp)) {
        val w = size.width
        val h = size.height
        val sw = w * 0.14f

        val headband = Path().apply {
            addArc(Rect(w * 0.12f, h * 0.05f, w * 0.88f, h * 0.85f), startAngleDegrees = 180f, sweepAngleDegrees = 180f)
        }
        drawPath(headband, tint, style = Stroke(width = sw, cap = StrokeCap.Round))

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
        drawPath(cone, color.copy(alpha = (alpha * 1.05f).coerceAtMost(1f)))

        val sw = w * 0.05f
        val cap = StrokeCap.Round
        drawLine(color, Offset(w * 0.60f, h * 0.28f), Offset(w * 0.80f, h * 0.12f), sw, cap)
        drawLine(color, Offset(w * 0.80f, h * 0.48f), Offset(w * 1.0f, h * 0.40f), sw, cap)
        drawLine(color, Offset(w * 0.66f, h * 0.70f), Offset(w * 0.88f, h * 0.78f), sw, cap)
        drawCircle(color, radius = w * 0.032f, center = Offset(w * 0.92f, h * 0.22f))
        drawCircle(color, radius = w * 0.024f, center = Offset(w * 0.55f, h * 0.10f))
        drawCircle(color, radius = w * 0.02f, center = Offset(w * 0.30f, h * 0.20f))
        drawCircle(color, radius = w * 0.026f, center = Offset(w * 0.95f, h * 0.62f))
    }
}

