package ie.gaelgrounds.app.ui.matches

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
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
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel

@Composable
fun MatchDetailScreen(matchId: String, userId: String?, onBack: () -> Unit, viewModel: MatchDetailViewModel = viewModel()) {
    val uiState by viewModel.uiState.collectAsState()

    LaunchedEffect(matchId) { viewModel.load(matchId, userId) }

    if (uiState.isLoading) {
        CircularProgressIndicator(modifier = Modifier.padding(24.dp))
        return
    }

    val summary = uiState.summary
    val isPast = summary?.isPast ?: false

    Column(modifier = Modifier.fillMaxSize().padding(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        if (summary == null) {
            Text("Match not found.", style = MaterialTheme.typography.bodyMedium)
        } else {
            Text("${summary.sportCode.icon} ${summary.competition ?: summary.sportCode.label}", style = MaterialTheme.typography.labelMedium)
            val scoreline = if (summary.hasScore) {
                "${summary.homeName} ${summary.homeScore} - ${summary.awayScore} ${summary.awayName}"
            } else {
                "${summary.homeName} v ${summary.awayName}"
            }
            Text(scoreline, style = MaterialTheme.typography.headlineSmall)
            summary.groundName?.let { Text(it, style = MaterialTheme.typography.bodyMedium) }
        }

        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(horizontalArrangement = Arrangement.SpaceBetween, modifier = Modifier.fillMaxWidth()) {
                Column {
                    Text(if (isPast) "Who was there" else "Who's here", style = MaterialTheme.typography.titleMedium)
                    Text(
                        if (isPast) "Check in any time, even after the final whistle" else "See who's checked in",
                        style = MaterialTheme.typography.labelSmall,
                    )
                }
                if (userId != null) {
                    val myAttendanceId = uiState.myAttendanceId
                    if (myAttendanceId != null) {
                        OutlinedButton(
                            onClick = { viewModel.checkOut(matchId, myAttendanceId, userId) },
                            enabled = !uiState.isBusy,
                        ) {
                            Text(if (isPast) "Logged — undo" else "Checked in — undo")
                        }
                    } else {
                        Button(
                            onClick = { viewModel.checkIn(matchId, userId) },
                            enabled = !uiState.isBusy,
                        ) {
                            Text(if (isPast) "I was there" else "Check in")
                        }
                    }
                }
            }

            if (uiState.attendees.isEmpty()) {
                Text("No one's checked in yet — be the first!", style = MaterialTheme.typography.bodyMedium)
            } else {
                LazyColumn(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    items(uiState.attendees) { attendee ->
                        Row(horizontalArrangement = Arrangement.SpaceBetween, modifier = Modifier.fillMaxWidth()) {
                            Text(attendee.displayName ?: "A fan")
                            if (attendee.userId == userId) {
                                Text("YOU", style = MaterialTheme.typography.labelSmall)
                            }
                        }
                    }
                }
            }
        }
    }

    val evaluation = uiState.lastEvaluation
    if (evaluation != null && (evaluation.unlocks.isNotEmpty() || evaluation.progress != null)) {
        AlertDialog(
            onDismissRequest = viewModel::dismissEvaluation,
            confirmButton = {
                TextButton(onClick = viewModel::dismissEvaluation) { Text("Done") }
            },
            title = { Text(if (evaluation.unlocks.isEmpty()) "Good work!" else "Congratulations!") },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    evaluation.unlocks.forEach { unlock ->
                        Text("${unlock.title}\n${unlock.description}", style = MaterialTheme.typography.bodyMedium)
                    }
                    evaluation.progress?.let { progress ->
                        Text(progress.message, style = MaterialTheme.typography.bodySmall)
                    }
                }
            },
        )
    }
}
