package ie.gaelgrounds.app.ui.theme

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/**
 * Mirrors `.gaelCard(cornerRadius:)` in ios/GaelGrounds/Utilities/Theme.swift --
 * a raised surface fill, a hairline brand-green border, and a soft green-tinted
 * shadow. Used for every card-shaped block across the app on iOS; apply the
 * same way here instead of a plain Material `Card`.
 */
fun Modifier.gaelCard(cornerRadius: Dp = 14.dp): Modifier = composed {
    val raised = if (isSystemInDarkTheme()) BrandSurfaceRaisedDark else BrandSurfaceRaisedLight
    val shape = RoundedCornerShape(cornerRadius)
    this
        .shadow(
            elevation = 8.dp,
            shape = shape,
            ambientColor = BrandGreen.copy(alpha = 0.07f),
            spotColor = BrandGreen.copy(alpha = 0.07f),
        )
        .background(raised, shape)
        .border(1.dp, BrandGreenLight.copy(alpha = 0.16f), shape)
}

/**
 * Mirrors `.gaelInsetCard(cornerRadius:)` -- a subtler, flatter fill used for
 * nested content inside a `gaelCard`, with no shadow of its own.
 */
fun Modifier.gaelInsetCard(cornerRadius: Dp = 12.dp): Modifier = composed {
    val shape = RoundedCornerShape(cornerRadius)
    this
        .background(BrandGreenLight.copy(alpha = 0.065f), shape)
        .border(1.dp, BrandGreenLight.copy(alpha = 0.128f), shape)
}
