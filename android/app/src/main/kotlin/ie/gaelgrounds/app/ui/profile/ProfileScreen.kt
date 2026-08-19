package ie.gaelgrounds.app.ui.profile

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.item
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.IconButton
import androidx.compose.material3.Icon
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.StarBorder
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import ie.gaelgrounds.app.ui.auth.AuthScreen
import ie.gaelgrounds.app.ui.auth.AuthViewModel
import ie.gaelgrounds.app.ui.theme.BrandGold
import ie.gaelgrounds.app.ui.theme.gaelCard

@Composable
fun ProfileScreen(
    userEmail: String?,
    userId: String?,
    onSignOut: () -> Unit,
    onOpenFriends: () -> Unit,
    viewModel: ProfileViewModel = viewModel(),
    authViewModel: AuthViewModel = viewModel(),
) {
    if (userId == null) {
        AuthScreen(viewModel = authViewModel)
        return
    }

    val uiState by viewModel.uiState.collectAsState()
    var showCountyMenu by remember { mutableStateOf(false) }
    var showDeleteConfirm by remember { mutableStateOf(false) }

    LaunchedEffect(userId) { viewModel.load(userId) }

    if (uiState.isLoading) {
        CircularProgressIndicator(modifier = Modifier.padding(24.dp))
        return
    }

    LazyColumn(modifier = Modifier.fillMaxSize().padding(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        item {
            Column {
                Text(uiState.profile?.displayName ?: "Your profile", style = MaterialTheme.typography.headlineSmall)
                userEmail?.let { Text(it, style = MaterialTheme.typography.bodyMedium) }
            }
        }

        item {
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.fillMaxWidth()) {
                StatTile(uiState.groundsVisited, "Grounds visited", Modifier.weight(1f))
                StatTile(uiState.matchesAttended, "Matches attended", Modifier.weight(1f))
                StatTile(uiState.achievements.size, "Achievements", Modifier.weight(1f))
            }
        }

        item {
            val supportedCountyName = uiState.counties.firstOrNull { it.id == uiState.profile?.supportedCountyId }?.name
            Column {
                Text("Supported county", style = MaterialTheme.typography.titleMedium)
                Row(verticalAlignment = Alignment.CenterVertically) {
                    OutlinedButton(onClick = { showCountyMenu = true }) {
                        Text(supportedCountyName ?: "Choose a county")
                    }
                    DropdownMenu(expanded = showCountyMenu, onDismissRequest = { showCountyMenu = false }) {
                        uiState.counties.sortedBy { it.name }.forEach { county ->
                            DropdownMenuItem(
                                text = { Text(county.name) },
                                onClick = {
                                    viewModel.setSupportedCounty(userId, county.id)
                                    showCountyMenu = false
                                },
                            )
                        }
                    }
                }
            }
        }

        item {
            Box(modifier = Modifier.fillMaxWidth().gaelCard()) {
                Row(
                    modifier = Modifier.padding(14.dp).fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text("Friends", style = MaterialTheme.typography.titleMedium)
                    TextButton(onClick = onOpenFriends) { Text("View →") }
                }
            }
        }

        item { Text("Achievements", style = MaterialTheme.typography.titleMedium) }
        if (uiState.achievements.isEmpty()) {
            item { Text("No achievements unlocked yet — check in somewhere to get started.", style = MaterialTheme.typography.bodyMedium) }
        } else {
            items(uiState.achievements) { achievement ->
                Box(modifier = Modifier.fillMaxWidth().gaelCard()) {
                    Row(
                        modifier = Modifier.padding(12.dp).fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text(achievement.title, style = MaterialTheme.typography.titleSmall)
                            Text(achievement.description, style = MaterialTheme.typography.labelSmall)
                        }
                        IconButton(onClick = { viewModel.togglePinned(achievement) }) {
                            Icon(
                                imageVector = if (achievement.pinned) Icons.Filled.Star else Icons.Filled.StarBorder,
                                contentDescription = if (achievement.pinned) "Unpin achievement" else "Pin achievement",
                                tint = if (achievement.pinned) BrandGold else MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                    }
                }
            }
        }

        item {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedButton(onClick = { onSignOut() }, modifier = Modifier.fillMaxWidth()) {
                    Text("Sign out")
                }
                TextButton(onClick = { showDeleteConfirm = true }, modifier = Modifier.fillMaxWidth()) {
                    Text("Delete account")
                }
                uiState.deleteError?.let { Text(it, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.labelSmall) }
            }
        }
    }

    val pinLimitMessage = uiState.pinLimitMessage
    if (pinLimitMessage != null) {
        AlertDialog(
            onDismissRequest = viewModel::dismissPinLimitMessage,
            confirmButton = { TextButton(onClick = viewModel::dismissPinLimitMessage) { Text("OK") } },
            title = { Text("Featured achievements full") },
            text = { Text(pinLimitMessage) },
        )
    }

    if (showDeleteConfirm) {
        AlertDialog(
            onDismissRequest = { showDeleteConfirm = false },
            title = { Text("Delete your account?") },
            text = { Text("This permanently deletes your account and all your data. This can't be undone.") },
            confirmButton = {
                TextButton(
                    onClick = {
                        showDeleteConfirm = false
                        viewModel.deleteAccount(onDeleted = onSignOut)
                    },
                ) { Text("Delete", color = MaterialTheme.colorScheme.error) }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteConfirm = false }) { Text("Cancel") }
            },
        )
    }
}

@Composable
private fun StatTile(value: Int, label: String, modifier: Modifier = Modifier) {
    Box(modifier = modifier.gaelCard()) {
        Column(
            modifier = Modifier.padding(12.dp).fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text("$value", style = MaterialTheme.typography.headlineMedium)
            Text(label, style = MaterialTheme.typography.labelSmall)
        }
    }
}
