package com.neganboy.maxgpower.ui

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val Bg = Color(0xFF0B0F1A)
private val Surface = Color(0xFF151B2A)
private val Surface2 = Color(0xFF1C2438)
private val Primary = Color(0xFF4F9BFF)
private val PrimaryDeep = Color(0xFF2A52FF)
private val OnBg = Color(0xFFE8ECF5)
private val Muted = Color(0xFF9AA5BD)
private val Good = Color(0xFF3ECF6E)
private val Warn = Color(0xFFFFB020)
private val Bad = Color(0xFFFF5A5A)

val MaxGColors = darkColorScheme(
    primary = Primary,
    secondary = PrimaryDeep,
    background = Bg,
    surface = Surface,
    surfaceVariant = Surface2,
    onBackground = OnBg,
    onSurface = OnBg,
    onSurfaceVariant = Muted,
    error = Bad
)

val GoodGreen get() = Good
val WarnAmber get() = Warn
val BadRed get() = Bad
val MutedText get() = Muted

@Composable
fun MaxGTheme(content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = MaxGColors, content = content)
}
