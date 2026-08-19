package ie.gaelgrounds.app.ui.grounds

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.google.android.gms.maps.model.CameraPosition
import com.google.android.gms.maps.model.LatLng
import com.google.android.gms.maps.model.MapStyleOptions
import com.google.maps.android.compose.GoogleMap
import com.google.maps.android.compose.MapProperties
import com.google.maps.android.compose.MapUiSettings
import com.google.maps.android.compose.MarkerComposable
import com.google.maps.android.compose.rememberCameraPositionState
import com.google.maps.android.compose.rememberMarkerState

/**
 * Mirrors ios/GaelGrounds/Views/Grounds/GroundsMapView.swift -- a map of
 * every ground, coloured dots for visited vs not, bigger for a county's
 * primary ground.
 *
 * Needs `MAPS_API_KEY` set in `local.properties` (see android/README.md)
 * to actually render tiles -- without it the map surface stays blank, same
 * as any Google Maps SDK integration without a configured key.
 */
@Composable
fun GroundsMapScreen(userId: String?, onBack: () -> Unit, viewModel: GroundsViewModel = viewModel()) {
    val uiState by viewModel.uiState.collectAsState()
    LaunchedEffect(userId) { viewModel.load(userId) }
    val grounds = uiState.grounds

    val ireland = LatLng(53.5, -8.0)
    val cameraPositionState = rememberCameraPositionState {
        position = CameraPosition.fromLatLngZoom(ireland, 6.3f)
    }
    val visitedCount = grounds.count { it.visited }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Grounds Map") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
            )
        },
        bottomBar = {
            Text(
                text = if (visitedCount == 0) "Check in at grounds to light them up" else "$visitedCount of ${grounds.size} grounds visited",
                style = MaterialTheme.typography.labelSmall,
                modifier = Modifier.padding(12.dp),
            )
        },
    ) { padding ->
        GoogleMap(
            modifier = Modifier.fillMaxSize().padding(padding),
            cameraPositionState = cameraPositionState,
            properties = remember {
                MapProperties(mapStyleOptions = MapStyleOptions(POINTS_OF_INTEREST_HIDDEN_STYLE))
            },
            uiSettings = remember { MapUiSettings(zoomControlsEnabled = false) },
        ) {
            grounds.forEach { ground ->
                MarkerComposable(
                    state = rememberMarkerState(position = LatLng(ground.latitude, ground.longitude)),
                    title = if (ground.visited) ground.name else null,
                ) {
                    GroundMapPin(visited = ground.visited, isPrimary = ground.isPrimary)
                }
            }
        }
    }
}

@Composable
private fun GroundMapPin(visited: Boolean, isPrimary: Boolean) {
    val diameter = if (isPrimary) 16.dp else 6.dp
    var modifier = Modifier
        .size(diameter)
        .background(if (visited) Color(0xFF34C759) else Color(0xFFAEAEB2), CircleShape)
    if (isPrimary) {
        modifier = modifier.border(2.dp, Color.Black, CircleShape)
    }
    Box(modifier = modifier)
}

private const val POINTS_OF_INTEREST_HIDDEN_STYLE = """
[
  { "featureType": "poi", "stylers": [ { "visibility": "off" } ] },
  { "featureType": "transit", "stylers": [ { "visibility": "off" } ] }
]
"""
