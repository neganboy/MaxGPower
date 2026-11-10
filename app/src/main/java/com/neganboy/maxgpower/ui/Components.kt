package com.neganboy.maxgpower.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Divider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/** Tarjeta neumórfica clara de la WebUI: radio 32dp, degradado, sombra suave. */
@Composable
fun NeuCard(modifier: Modifier = Modifier, content: @Composable ColumnScope.() -> Unit) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .shadow(10.dp, RoundedCornerShape(32.dp), ambientColor = NeuColors.Shadow, spotColor = NeuColors.Shadow)
            .background(
                Brush.verticalGradient(listOf(NeuColors.CardTop, NeuColors.CardBottom)),
                RoundedCornerShape(32.dp)
            )
            .padding(20.dp),
        content = content
    )
}

/** Título de grupo en mayúsculas, igual que .grp de la WebUI. */
@Composable
fun GroupHeader(text: String) {
    Text(
        text.uppercase(),
        fontSize = 11.5.sp,
        fontWeight = FontWeight.Bold,
        letterSpacing = 1.4.sp,
        color = NeuColors.Muted,
        modifier = Modifier.padding(start = 8.dp, top = 26.dp, bottom = 12.dp)
    )
}

/** Fila con título + descripción y un control a la derecha (.line / .rule). */
@Composable
fun RuleRow(title: String, desc: String? = null, right: @Composable () -> Unit) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f)) {
            Text(title, fontSize = 14.5.sp, fontWeight = FontWeight.Bold, color = NeuColors.Text)
            if (desc != null) Text(desc, fontSize = 12.5.sp, color = NeuColors.Muted, modifier = Modifier.padding(top = 2.dp))
        }
        right()
    }
}

/** Interruptor grande de la WebUI (112x56dp) con texto ON/OFF y perilla. */
@Composable
fun NeuSwitch(checked: Boolean, enabled: Boolean = true, modifier: Modifier = Modifier, onToggle: () -> Unit) {
    val bg = if (checked) Brush.linearGradient(listOf(NeuColors.Blue1, NeuColors.Blue2))
    else Brush.verticalGradient(listOf(NeuColors.SwitchOffTop, NeuColors.SwitchOffBottom))
    Box(
        modifier = modifier
            .size(112.dp, 56.dp)
            .shadow(if (checked) 4.dp else 0.dp, RoundedCornerShape(30.dp))
            .background(bg, RoundedCornerShape(30.dp))
            .clickable(enabled = enabled) { onToggle() },
        contentAlignment = Alignment.Center
    ) {
        Text(
            if (checked) "ON" else "OFF",
            fontSize = 14.sp,
            fontWeight = FontWeight.Bold,
            color = if (checked) Color.White else NeuColors.Muted,
            modifier = Modifier.align(if (checked) Alignment.CenterStart else Alignment.CenterEnd)
                .padding(horizontal = 18.dp)
        )
        Box(
            modifier = Modifier
                .size(50.dp, 46.dp)
                .align(Alignment.CenterStart)
                .offset(x = if (checked) 57.dp else 5.dp)
                .shadow(6.dp, RoundedCornerShape(24.dp))
                .background(Brush.verticalGradient(listOf(NeuColors.KnobTop, NeuColors.KnobBottom)), RoundedCornerShape(24.dp)),
            contentAlignment = Alignment.Center
        ) {
            Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                repeat(3) { Box(Modifier.size(3.dp, 22.dp).background(NeuColors.KnobLine, RoundedCornerShape(2.dp))) }
            }
        }
    }
}

/** Anillo doble de la WebUI: arco exterior azul (pctA) e interior gris (pctB). */
@Composable
fun RingGauge(
    pctA: Float,
    pctB: Float?,
    centerText: String,
    centerSub: String,
    ringSize: Dp = 132.dp,
    modifier: Modifier = Modifier
) {
    // Los colores se leen aquí (contexto @Composable): dentro del Canvas no se puede.
    val track = NeuColors.Track
    val blue1 = NeuColors.Blue1
    val blue2 = NeuColors.Blue2
    val innerTrack = NeuColors.InnerTrack
    val ringGray = NeuColors.RingGray
    Box(modifier = modifier.size(ringSize), contentAlignment = Alignment.Center) {
        Canvas(Modifier.size(ringSize)) {
            val strokeA = 7.dp.toPx()
            val strokeB = 6.dp.toPx()
            val rA = (size.minDimension - strokeA) / 2f
            val rB = rA - 11.dp.toPx()
            val grad = Brush.sweepGradient(listOf(blue1, blue2), center)
            drawArc(track, -90f, 360f, false, topLeft = center - Offset(rA, rA), size = androidx.compose.ui.geometry.Size(rA * 2, rA * 2), style = Stroke(strokeA, cap = StrokeCap.Round))
            drawArc(grad, -90f, (pctA.coerceIn(0f, 100f) * 3.6f), false, topLeft = center - Offset(rA, rA), size = androidx.compose.ui.geometry.Size(rA * 2, rA * 2), style = Stroke(strokeA, cap = StrokeCap.Round))
            if (pctB != null) {
                drawArc(innerTrack, -90f, 360f, false, topLeft = center - Offset(rB, rB), size = androidx.compose.ui.geometry.Size(rB * 2, rB * 2), style = Stroke(strokeB, cap = StrokeCap.Round))
                drawArc(ringGray, -90f, (pctB.coerceIn(0f, 100f) * 3.6f), false, topLeft = center - Offset(rB, rB), size = androidx.compose.ui.geometry.Size(rB * 2, rB * 2), style = Stroke(strokeB, cap = StrokeCap.Round))
            }
        }
        Box(
            Modifier.size(ringSize - 52.dp)
                .shadow(6.dp, CircleShape)
                .background(Brush.verticalGradient(listOf(NeuColors.KnobTop, NeuColors.KnobBottom)), CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(centerText, fontSize = 21.sp, fontWeight = FontWeight.SemiBold, color = NeuColors.RingCenterText)
                Text(centerSub, fontSize = 10.sp, color = NeuColors.Muted)
            }
        }
    }
}

/** Fila de perfil con círculo de radio, como .prow de la WebUI. */
@Composable
fun ProfileRow(
    selected: Boolean,
    title: String,
    desc: String,
    right: String? = null,
    enabled: Boolean = true,
    divider: Boolean = true,
    onClick: () -> Unit
) {
    Column(Modifier.fillMaxWidth()) {
        if (divider) Divider(color = NeuColors.Hairline, thickness = 1.dp)
        Row(
            Modifier.fillMaxWidth().clickable(enabled = enabled) { onClick() }.padding(vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(
                Modifier.size(26.dp)
                    .shadow(if (selected) 5.dp else 0.dp, CircleShape)
                    .background(
                        if (selected) Brush.linearGradient(listOf(NeuColors.Blue1, NeuColors.Blue2))
                        else Brush.verticalGradient(listOf(NeuColors.SwitchOffTop, NeuColors.SwitchOffBottom)),
                        CircleShape
                    )
            )
            Column(Modifier.weight(1f).padding(horizontal = 10.dp)) {
                Text(title, fontSize = 14.sp, fontWeight = FontWeight.Medium, color = if (selected) NeuColors.Blue2 else NeuColors.Text)
                Text(desc, fontSize = 12.sp, color = NeuColors.Muted)
            }
            if (right != null) Text(right, fontSize = 12.sp, color = NeuColors.Muted, textAlign = TextAlign.End)
        }
    }
}

/** Chip seleccionable: degradado azul cuando está activo. */
@Composable
fun NeuChip(text: String, selected: Boolean, enabled: Boolean = true, onClick: (() -> Unit)? = null) {
    val bg = if (selected) Brush.linearGradient(listOf(NeuColors.Blue1, NeuColors.Blue2))
    else Brush.verticalGradient(listOf(NeuColors.ChipOffTop, NeuColors.ChipOffBottom))
    Box(
        Modifier
            .shadow(if (selected) 6.dp else 4.dp, RoundedCornerShape(99.dp))
            .background(bg, RoundedCornerShape(99.dp))
            .then(if (onClick != null) Modifier.clickable(enabled = enabled) { onClick() } else Modifier)
            .padding(horizontal = 15.dp, vertical = 9.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(text, fontSize = 12.5.sp, fontWeight = FontWeight.SemiBold, color = if (selected) Color.White else NeuColors.Muted)
    }
}

/** Chip informativo (no clicable), azul tenue como .chip de la WebUI. */
@Composable
fun InfoChip(text: String, gray: Boolean = false) {
    Box(
        Modifier.background(
            if (gray) Color(0x23787D96) else Color(0x172A52FF),
            RoundedCornerShape(99.dp)
        ).padding(horizontal = 10.dp, vertical = 4.dp)
    ) {
        Text(text, fontSize = 11.sp, fontWeight = FontWeight.SemiBold, color = if (gray) NeuColors.Muted else NeuColors.Blue2)
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun ChipFlow(options: List<Pair<String, String>>, selected: String, onSelect: (String) -> Unit) {
    FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        for ((id, label) in options) NeuChip(label, id == selected) { onSelect(id) }
    }
}

/** Botón píldora 48dp: primario degradado azul, secundario claro con borde. */
@Composable
fun NeuButton(text: String, primary: Boolean = false, enabled: Boolean = true, modifier: Modifier = Modifier, onClick: () -> Unit) {
    val bg = if (primary) Brush.linearGradient(listOf(NeuColors.Blue1, NeuColors.Blue2))
    else Brush.verticalGradient(listOf(NeuColors.CardTop, NeuColors.CardBottom))
    Box(
        modifier
            .height(48.dp)
            .shadow(if (primary) 10.dp else 6.dp, RoundedCornerShape(99.dp))
            .background(bg, RoundedCornerShape(99.dp))
            .then(if (!primary) Modifier.border(1.5.dp, NeuColors.ButtonBorder, RoundedCornerShape(99.dp)) else Modifier)
            .clickable(enabled = enabled) { onClick() }
            .padding(horizontal = 24.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(text, fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = if (primary) Color.White else NeuColors.Text)
    }
}

/** Slider con acento azul, como .rg de la WebUI. */
@Composable
fun SliderRow(label: String, value: Int, range: IntRange, onChange: (Int) -> Unit, format: (Int) -> String = { "$it" }) {
    Column(Modifier.fillMaxWidth().padding(vertical = 8.dp)) {
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Text(label, fontSize = 14.sp, fontWeight = FontWeight.Medium, color = NeuColors.Text, modifier = Modifier.weight(1f))
            Text(format(value), fontSize = 13.sp, fontWeight = FontWeight.Bold, color = NeuColors.Blue2)
        }
        Slider(
            value = value.toFloat(),
            onValueChange = { onChange(it.toInt()) },
            valueRange = range.first.toFloat()..range.last.toFloat(),
            steps = (range.last - range.first - 1).coerceAtLeast(0),
            colors = SliderDefaults.colors(
                thumbColor = NeuColors.Blue2,
                activeTrackColor = NeuColors.Blue2,
                inactiveTrackColor = Color(0x338C9BB4)
            )
        )
    }
}

@Composable
fun SectionTitle(text: String) {
    Text(text, fontSize = 16.sp, fontWeight = FontWeight.Bold, color = NeuColors.Text)
}

@Composable
fun SectionSub(text: String) {
    Text(text, fontSize = 12.5.sp, color = NeuColors.Muted, modifier = Modifier.padding(top = 4.dp))
}

/** Iconos del nav superior, iguales a los SVG de la WebUI (24x24). */
enum class NavIconKind { Bolt, Sliders, Chip, Gamepad, Sparkle }

@Composable
fun NavIcon(kind: NavIconKind, tint: Color, modifier: Modifier = Modifier) {
    Canvas(modifier.size(24.dp)) {
        val s = size.minDimension / 24f
        val stroke = 1.8f * s
        when (kind) {
            NavIconKind.Bolt -> {
                val p = androidx.compose.ui.graphics.Path().apply {
                    moveTo(13f * s, 2f * s); lineTo(4f * s, 14f * s); lineTo(11f * s, 14f * s)
                    lineTo(10f * s, 22f * s); lineTo(20f * s, 10f * s); lineTo(13f * s, 10f * s); close()
                }
                drawPath(p, tint, style = Stroke(stroke, cap = StrokeCap.Round, join = androidx.compose.ui.graphics.StrokeJoin.Round))
            }
            NavIconKind.Sliders -> {
                drawLine(tint, Offset(4f * s, 7f * s), Offset(14f * s, 7f * s), strokeWidth = stroke, cap = StrokeCap.Round)
                drawLine(tint, Offset(18f * s, 7f * s), Offset(20f * s, 7f * s), strokeWidth = stroke, cap = StrokeCap.Round)
                drawCircle(tint, 2f * s, Offset(16f * s, 7f * s), style = Stroke(stroke))
                drawLine(tint, Offset(4f * s, 17f * s), Offset(6f * s, 17f * s), strokeWidth = stroke, cap = StrokeCap.Round)
                drawLine(tint, Offset(10f * s, 17f * s), Offset(20f * s, 17f * s), strokeWidth = stroke, cap = StrokeCap.Round)
                drawCircle(tint, 2f * s, Offset(8f * s, 17f * s), style = Stroke(stroke))
            }
            NavIconKind.Chip -> {
                drawRoundRect(tint, Offset(5f * s, 5f * s), androidx.compose.ui.geometry.Size(14f * s, 14f * s), androidx.compose.ui.geometry.CornerRadius(3f * s, 3f * s), style = Stroke(stroke))
                drawLine(tint, Offset(9f * s, 12f * s), Offset(15f * s, 12f * s), strokeWidth = stroke, cap = StrokeCap.Round)
                for (x in listOf(9f, 15f)) {
                    drawLine(tint, Offset(x * s, 2f * s), Offset(x * s, 5f * s), strokeWidth = stroke, cap = StrokeCap.Round)
                    drawLine(tint, Offset(x * s, 19f * s), Offset(x * s, 22f * s), strokeWidth = stroke, cap = StrokeCap.Round)
                }
                for (y in listOf(9f, 15f)) {
                    drawLine(tint, Offset(2f * s, y * s), Offset(5f * s, y * s), strokeWidth = stroke, cap = StrokeCap.Round)
                    drawLine(tint, Offset(19f * s, y * s), Offset(22f * s, y * s), strokeWidth = stroke, cap = StrokeCap.Round)
                }
            }
            NavIconKind.Gamepad -> {
                drawRoundRect(tint, Offset(2.5f * s, 7f * s), androidx.compose.ui.geometry.Size(19f * s, 11f * s), androidx.compose.ui.geometry.CornerRadius(5f * s, 5f * s), style = Stroke(stroke))
                drawLine(tint, Offset(7.5f * s, 10f * s), Offset(7.5f * s, 15f * s), strokeWidth = stroke, cap = StrokeCap.Round)
                drawLine(tint, Offset(5f * s, 12.5f * s), Offset(10f * s, 12.5f * s), strokeWidth = stroke, cap = StrokeCap.Round)
                drawCircle(tint, 0.8f * s, Offset(16f * s, 11.5f * s))
                drawCircle(tint, 0.8f * s, Offset(18f * s, 13.5f * s))
            }
            NavIconKind.Sparkle -> {
                val p = androidx.compose.ui.graphics.Path().apply {
                    moveTo(12f * s, 3f * s); lineTo(13.8f * s, 10.2f * s); lineTo(21f * s, 12f * s)
                    lineTo(13.8f * s, 13.8f * s); lineTo(12f * s, 21f * s); lineTo(10.2f * s, 13.8f * s)
                    lineTo(3f * s, 12f * s); lineTo(10.2f * s, 10.2f * s); close()
                }
                drawPath(p, tint, style = Stroke(stroke, cap = StrokeCap.Round, join = androidx.compose.ui.graphics.StrokeJoin.Round))
            }
        }
    }
}

@Composable
fun Spacer8() = Spacer(Modifier.height(8.dp))
@Composable
fun SpacerW8() = Spacer(Modifier.width(8.dp))
