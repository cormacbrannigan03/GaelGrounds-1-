package ie.gaelgrounds.app.ui.grounds

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel

@Composable
fun GroundDetailScreen(groundId: String, userId: String?, onBack: () -> Unit, viewModel: GroundDetailViewModel = viewModel()) {
    val uiState by viewModel.uiState.collectAsState()
    var notes by remember { mutableStateOf("") }

    LaunchedEffect(groundId) { viewModel.load(groundId, userId) }

    if (uiState.isLoading) {
        CircularProgressIndicator(modifier = Modifier.padding(24.dp))
        return
    }

    val ground = uiState.ground
    Column(modifier = Modifier.fillMaxSize().padding(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        if (ground == null) {
            Text("Ground not found.", style = MaterialTheme.typography.bodyMedium)
        } else {
            Text(ground.name, style = MaterialTheme.typography.headlineSmall)
            uiState.countyName?.let { Text(it, style = MaterialTheme.typography.bodyMedium) }
            ground.capacity?.let { Text("Capacity: $it", style = MaterialTheme.typography.labelSmall) }

            if (uiState.gamesSeenHere.isNotEmpty()) {
                Text("Games you've seen here (${uiState.gamesSeenHere.size})", style = MaterialTheme.typography.titleMedium)
                LazyColumn(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    items(uiState.gamesSeenHere) { game ->
                        Text("${game.homeName} v ${game.awayName} — ${game.competition ?: "Gaelic Games"}", style = MaterialTheme.typography.bodyMedium)
                    }
                }
            }

            Text("Visitors (${uiState.visitors.size})", style = MaterialTheme.typography.titleMedium)

            if (userId != null) {
                val myVisitId = uiState.myVisitId
                if (myVisitId != null) {
                    OutlinedButton(onClick = { viewModel.undoCheckIn(groundId, myVisitId, userId) }, enabled = !uiState.isBusy) {
                        Text("Checked in — undo")
                    }
                } else {
                    OutlinedTextField(
                        value = notes,
                        onValueChange = { notes = it },
                        label = { Text("Add a note (optional)") },
                        modifier = Modifier.fillMaxWidth(),
                        singleLine = true,
                    )
                    Button(
                        onClick = { viewModel.checkIn(groundId, userId, notes); notes = "" },
                        enabled = !uiState.isBusy,
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Text("Check in here")
                    }
                }
            }
        }
    }

    val unlocks = uiState.unlockedTitles
    if (unlocks != null) {
        AlertDialog(
            onDismissRequest = viewModel::dismissUnlocks,
            confirmButton = { TextButton(onClick = viewModel::dismissUnlocks) { Text("Done") } },
            title = { Text("Achievement unlocked!") },
            text = { Text(unlocks.joinToString("\n")) },
        )
    }
}
