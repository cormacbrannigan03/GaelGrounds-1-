package ie.gaelgrounds.app.ui.dashboard

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import ie.gaelgrounds.app.ui.components.MatchSummaryCard

@Composable
fun DashboardScreen(userId: String?, onOpenMatch: (String) -> Unit, viewModel: DashboardViewModel = viewModel()) {
    val uiState by viewModel.uiState.collectAsState()

    LaunchedEffect(userId) { viewModel.load(userId) }

    LazyColumn(modifier = Modifier.fillMaxSize().padding(16.dp), verticalArrangement = Arrangement.spacedBy(20.dp)) {
        item {
            Column {
                Text("Every ground. Every code. Every county.", style = MaterialTheme.typography.headlineSmall)
                Text(
                    "Check in at Gaelic football, hurling, camogie and ladies' football matches in real time, " +
                        "and build your own record of the grounds you've stood in across all 32 counties.",
                    style = MaterialTheme.typography.bodyMedium,
                    modifier = Modifier.padding(top = 8.dp),
                )
            }
        }

        if (userId != null) {
            item {
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.fillMaxWidth()) {
                    StatTile(uiState.groundsVisited, "Grounds visited", Modifier.weight(1f))
                    StatTile(uiState.matchesAttended, "Matches attended", Modifier.weight(1f))
                    StatTile(uiState.achievementsUnlocked, "Achievements", Modifier.weight(1f))
                }
            }
        }

        item {
            Text("Upcoming fixtures", style = MaterialTheme.typography.titleLarge)
        }

        if (uiState.isLoading) {
            item { CircularProgressIndicator() }
        } else if (uiState.upcoming.isEmpty()) {
            item { Text("No upcoming fixtures right now — check back soon.", style = MaterialTheme.typography.bodyMedium) }
        } else {
            items(uiState.upcoming) { match ->
                MatchSummaryCard(match = match, onClick = { onOpenMatch(match.id) })
            }
        }
    }
}

@Composable
private fun StatTile(value: Int, label: String, modifier: Modifier = Modifier) {
    Card(modifier = modifier) {
        Column(
            modifier = Modifier.padding(12.dp).fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text("$value", style = MaterialTheme.typography.headlineMedium)
            Text(label, style = MaterialTheme.typography.labelSmall)
        }
    }
}
