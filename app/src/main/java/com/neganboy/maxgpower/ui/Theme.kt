package com.neganboy.maxgpower.ui

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

/**
 * Tema CLARO neumórfico, copiado del diseño de la WebUI del módulo
 * (webroot/index.html): fondo gris azulado, tarjetas con degradado claro
 * y sombras suaves, acento azul #2A52FF -> #4F9BFF, texto azul oscuro.
 */
object NeuColors {
    val Bg = Color(0xFFE4E9EF)
    val CardTop = Color(0xFFF7FAFD)
    val CardBottom = Color(0xFFE5EAF0)
    val Text = Color(0xFF2B3350)
    val Muted = Color(0xFF7B86A1)
    val Blue1 = Color(0xFF4F9BFF)
    val Blue2 = Color(0xFF2A52FF)
    val Ok = Color(0xFF2FB98F)
    val Bad = Color(0xFFE0586F)
    val Warn = Color(0xFFE89A3C)
    val Hairline = Color(0x291E2832)
    val Track = Color(0x2E8C9BB4)
    val RingGray = Color(0xFFA9B2C4)
    val SwitchOffTop = Color(0xFFDFE5EC)
    val SwitchOffBottom = Color(0xFFF3F6FA)
}

private val MaxGScheme = lightColorScheme(
    primary = NeuColors.Blue2,
    secondary = NeuColors.Blue1,
    background = NeuColors.Bg,
    surface = NeuColors.CardTop,
    onBackground = NeuColors.Text,
    onSurface = NeuColors.Text,
    error = NeuColors.Bad
)

@Composable
fun MaxGTheme(content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = MaxGScheme, content = content)
}
