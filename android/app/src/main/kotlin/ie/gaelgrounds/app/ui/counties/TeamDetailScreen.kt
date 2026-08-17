package ie.gaelgrounds.app.ui.counties

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.item
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import ie.gaelgrounds.app.ui.components.MatchSummaryCard

@Composable
fun TeamDetailScreen(teamId: String, onBack: () -> Unit, viewModel: TeamDetailViewModel = viewModel()) {
    val uiState by viewModel.uiState.collectAsState()

    LaunchedEffect(teamId) { viewModel.load(teamId) }

    if (uiState.isLoading) {
        CircularProgressIndicator(modifier = Modifier.padding(24.dp))
        return
    }

    val team = uiState.team
    if (team == null) {
        Text("Team not found.", modifier = Modifier.padding(16.dp))
        return
    }

    LazyColumn(modifier = Modifier.fillMaxSize().padding(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        item {
            Column {
                Text(uiState.countyName ?: "", style = MaterialTheme.typography.headlineSmall)
                Text("${team.sportCode.icon} ${team.sportCode.label}", style = MaterialTheme.typography.bodyMedium)
                team.foundedYear?.let { Text("Founded $it", style = MaterialTheme.typography.labelSmall) }
                team.currentManager?.let { Text("Manager: $it", style = MaterialTheme.typography.labelSmall) }
            }
        }

        if (uiState.upcoming.isNotEmpty()) {
            item { Text("Upcoming fixtures", style = MaterialTheme.typography.titleMedium) }
            items(uiState.upcoming) { match -> MatchSummaryCard(match = match, onClick = {}) }
        }

        if (uiState.results.isNotEmpty()) {
            item { Text("Recent results", style = MaterialTheme.typography.titleMedium) }
            items(uiState.results) { match -> MatchSummaryCard(match = match, onClick = {}) }
        }
    }
}
