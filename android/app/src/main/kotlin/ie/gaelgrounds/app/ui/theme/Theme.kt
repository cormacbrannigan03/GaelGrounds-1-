package ie.gaelgrounds.app.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

// Every token filled explicitly from the brand palette rather than left to
// Material3's algorithmic defaults, so buttons/chips/nav bar/etc. read as
// on-brand green-and-gold instead of generic Material purple.
private val LightColors = lightColorScheme(
    primary = BrandGreen,
    onPrimary = Color.White,
    primaryContainer = Color(0xFFCFE3D8),
    onPrimaryContainer = BrandGreen,
    secondary = BrandGold,
    onSecondary = BrandGreen,
    secondaryContainer = Color(0xFFF4E3C1),
    onSecondaryContainer = Color(0xFF4A360F),
    background = BrandCanvasLight,
    onBackground = Color(0xFF14201A),
    surface = BrandSurfaceLight,
    onSurface = Color(0xFF14201A),
    surfaceVariant = BrandSurfaceRaisedLight,
    onSurfaceVariant = Color(0xFF3C4A43),
    outline = BrandGreenLight.copy(alpha = 0.35f),
    outlineVariant = BrandGreenLight.copy(alpha = 0.16f),
    error = BrandLive,
    onError = Color.White,
)

private val DarkColors = darkColorScheme(
    primary = BrandGreenLight,
    onPrimary = Color.White,
    primaryContainer = Color(0xFF1E3A2C),
    onPrimaryContainer = Color(0xFFB9DECA),
    secondary = BrandGold,
    onSecondary = Color(0xFF2A1F08),
    secondaryContainer = Color(0xFF4A360F),
    onSecondaryContainer = Color(0xFFF4E3C1),
    background = BrandCanvasDark,
    onBackground = Color(0xFFE7EEE9),
    surface = BrandSurfaceDark,
    onSurface = Color(0xFFE7EEE9),
    surfaceVariant = BrandSurfaceRaisedDark,
    onSurfaceVariant = Color(0xFFC3D0C9),
    outline = BrandGreenLight.copy(alpha = 0.45f),
    outlineVariant = BrandGreenLight.copy(alpha = 0.22f),
    error = BrandLive,
    onError = Color.White,
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
