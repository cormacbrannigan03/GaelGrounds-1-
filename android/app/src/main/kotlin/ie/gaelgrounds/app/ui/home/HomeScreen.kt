package ie.gaelgrounds.app.ui.home

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

/**
 * Placeholder proving the pipeline end-to-end: Gradle -> Compose ->
 * Supabase auth -> authenticated state. Dashboard, Matches, Grounds,
 * Counties, Leaderboard, Profile screens land in follow-up commits,
 * mirroring the iOS tab set in MainTabView.swift.
 */
@Composable
fun HomeScreen(email: String?, onSignOut: () -> Unit) {
    Column(modifier = Modifier
        .fillMaxSize()
        .padding(24.dp)) {
        Text("GaelGrounds", style = MaterialTheme.typography.headlineMedium)
        Spacer(Modifier.height(8.dp))
        Text("Signed in as ${email ?: "unknown"}")
        Spacer(Modifier.height(24.dp))
        Button(onClick = onSignOut) {
            Text("Sign out")
        }
    }
}
