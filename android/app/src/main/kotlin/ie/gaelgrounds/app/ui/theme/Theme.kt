package ie.gaelgrounds.app.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable

private val LightColors = lightColorScheme(
    primary = BrandGreen,
    secondary = BrandGold,
    background = BrandCanvasLight,
    surface = BrandSurfaceLight,
    error = BrandLive,
)

private val DarkColors = darkColorScheme(
    primary = BrandGreenLight,
    secondary = BrandGold,
    background = BrandCanvasDark,
    surface = BrandSurfaceDark,
    error = BrandLive,
)

@Composable
fun GaelGroundsTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    val colors = if (darkTheme) DarkColors else LightColors
    MaterialTheme(
        colorScheme = colors,
        content = content,
    )
}
