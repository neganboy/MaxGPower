package com.neganboy.maxgpower.ui

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color

/**
 * Tema neumórfico, copiado del diseño de la WebUI del módulo
 * (webroot/index.html): fondo gris azulado, tarjetas con degradado
 * y sombras suaves, acento azul #2A52FF -> #4F9BFF, texto azul oscuro.
 * Hay paleta clara y paleta oscura: el modo noche sigue al sistema
 * o se fija a mano desde la pestaña Auto.
 */
data class NeuPalette(
    val bg: Color,
    val cardTop: Color,
    val cardBottom: Color,
    val text: Color,
    val muted: Color,
    val blue1: Color,
    val blue2: Color,
    val ok: Color,
    val bad: Color,
    val warn: Color,
    val hairline: Color,
    val track: Color,
    val ringGray: Color,
    val switchOffTop: Color,
    val switchOffBottom: Color,
    /** Sombra ambiental y de foco de las tarjetas. */
    val shadow: Color,
    /** Perilla del interruptor y centro del anillo. */
    val knobTop: Color,
    val knobBottom: Color,
    val knobLine: Color,
    /** Pista interior del anillo (segundo arco). */
    val innerTrack: Color,
    val ringCenterText: Color,
    /** Chip sin seleccionar y pestaña seleccionada del nav. */
    val chipOffTop: Color,
    val chipOffBottom: Color,
    val navTop: Color,
    val navBottom: Color,
    /** Borde claro del botón secundario. */
    val buttonBorder: Color
)

private val LightPalette = NeuPalette(
    bg = Color(0xFFE4E9EF),
    cardTop = Color(0xFFF7FAFD),
    cardBottom = Color(0xFFE5EAF0),
    text = Color(0xFF2B3350),
    muted = Color(0xFF7B86A1),
    blue1 = Color(0xFF4F9BFF),
    blue2 = Color(0xFF2A52FF),
    ok = Color(0xFF2FB98F),
    bad = Color(0xFFE0586F),
    warn = Color(0xFFE89A3C),
    hairline = Color(0x291E2832),
    track = Color(0x2E8C9BB4),
    ringGray = Color(0xFFA9B2C4),
    switchOffTop = Color(0xFFDFE5EC),
    switchOffBottom = Color(0xFFF3F6FA),
    shadow = Color(0xFF92A0B8),
    knobTop = Color(0xFFFFFFFF),
    knobBottom = Color(0xFFE3E8EF),
    knobLine = Color(0x598C9BB4),
    innerTrack = Color(0x1F8C9BB4),
    ringCenterText = Color(0xFF5B6479),
    chipOffTop = Color(0xFFFFFFFF),
    chipOffBottom = Color(0xFFE6EBF1),
    navTop = Color(0xFFFFFFFF),
    navBottom = Color(0xFFEEF2F7),
    buttonBorder = Color(0xB3FFFFFF)
)

private val DarkPalette = NeuPalette(
    bg = Color(0xFF171A1F),
    cardTop = Color(0xFF24282F),
    cardBottom = Color(0xFF1B1F25),
    text = Color(0xFFE9EBF0),
    muted = Color(0xFF9AA3B2),
    blue1 = Color(0xFF6EA8FF),
    blue2 = Color(0xFF4D7CFE),
    ok = Color(0xFF2FB98F),
    bad = Color(0xFFE0586F),
    warn = Color(0xFFE89A3C),
    hairline = Color(0x33FFFFFF),
    track = Color(0x338C9BB4),
    ringGray = Color(0xFF6B7484),
    switchOffTop = Color(0xFF12151A),
    switchOffBottom = Color(0xFF23272E),
    shadow = Color(0xFF000000),
    knobTop = Color(0xFF3A4048),
    knobBottom = Color(0xFF262B32),
    knobLine = Color(0xFF8A94A6),
    innerTrack = Color(0x338C9BB4),
    ringCenterText = Color(0xFFC9D1DE),
    chipOffTop = Color(0xFF2A2F37),
    chipOffBottom = Color(0xFF1E2228),
    navTop = Color(0xFF2A2F37),
    navBottom = Color(0xFF1E2228),
    buttonBorder = Color(0x40FFFFFF)
)

private val LocalNeuPalette = staticCompositionLocalOf { LightPalette }

/**
 * Los colores de la app. Se leen de la paleta activa (clara u oscura),
 * así todo el código que ya usa `NeuColors.X` cambia solo con el tema.
 */
object NeuColors {
    val Bg: Color @Composable get() = LocalNeuPalette.current.bg
    val CardTop: Color @Composable get() = LocalNeuPalette.current.cardTop
    val CardBottom: Color @Composable get() = LocalNeuPalette.current.cardBottom
    val Text: Color @Composable get() = LocalNeuPalette.current.text
    val Muted: Color @Composable get() = LocalNeuPalette.current.muted
    val Blue1: Color @Composable get() = LocalNeuPalette.current.blue1
    val Blue2: Color @Composable get() = LocalNeuPalette.current.blue2
    val Ok: Color @Composable get() = LocalNeuPalette.current.ok
    val Bad: Color @Composable get() = LocalNeuPalette.current.bad
    val Warn: Color @Composable get() = LocalNeuPalette.current.warn
    val Hairline: Color @Composable get() = LocalNeuPalette.current.hairline
    val Track: Color @Composable get() = LocalNeuPalette.current.track
    val RingGray: Color @Composable get() = LocalNeuPalette.current.ringGray
    val SwitchOffTop: Color @Composable get() = LocalNeuPalette.current.switchOffTop
    val SwitchOffBottom: Color @Composable get() = LocalNeuPalette.current.switchOffBottom
    val Shadow: Color @Composable get() = LocalNeuPalette.current.shadow
    val KnobTop: Color @Composable get() = LocalNeuPalette.current.knobTop
    val KnobBottom: Color @Composable get() = LocalNeuPalette.current.knobBottom
    val KnobLine: Color @Composable get() = LocalNeuPalette.current.knobLine
    val InnerTrack: Color @Composable get() = LocalNeuPalette.current.innerTrack
    val RingCenterText: Color @Composable get() = LocalNeuPalette.current.ringCenterText
    val ChipOffTop: Color @Composable get() = LocalNeuPalette.current.chipOffTop
    val ChipOffBottom: Color @Composable get() = LocalNeuPalette.current.chipOffBottom
    val NavTop: Color @Composable get() = LocalNeuPalette.current.navTop
    val NavBottom: Color @Composable get() = LocalNeuPalette.current.navBottom
    val ButtonBorder: Color @Composable get() = LocalNeuPalette.current.buttonBorder
}

private fun lightScheme(p: NeuPalette) = lightColorScheme(
    primary = p.blue2,
    secondary = p.blue1,
    background = p.bg,
    surface = p.cardTop,
    surfaceVariant = p.cardBottom,
    onBackground = p.text,
    onSurface = p.text,
    onSurfaceVariant = p.muted,
    error = p.bad
)

private fun darkScheme(p: NeuPalette) = darkColorScheme(
    primary = p.blue2,
    secondary = p.blue1,
    background = p.bg,
    surface = p.cardTop,
    surfaceVariant = p.cardBottom,
    onBackground = p.text,
    onSurface = p.text,
    onSurfaceVariant = p.muted,
    error = p.bad
)

@Composable
fun MaxGTheme(dark: Boolean, content: @Composable () -> Unit) {
    val palette = if (dark) DarkPalette else LightPalette
    androidx.compose.runtime.CompositionLocalProvider(LocalNeuPalette provides palette) {
        MaterialTheme(colorScheme = if (dark) darkScheme(palette) else lightScheme(palette), content = content)
    }
}
