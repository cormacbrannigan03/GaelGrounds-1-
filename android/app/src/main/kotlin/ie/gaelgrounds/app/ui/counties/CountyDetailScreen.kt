package ie.gaelgrounds.app.ui.counties

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
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
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel

@Composable
fun CountyDetailScreen(
    countyId: String,
    onOpenTeam: (String) -> Unit,
    onOpenGround: (String) -> Unit,
    onBack: () -> Unit,
    viewModel: CountyDetailViewModel = viewModel(),
) {
    val uiState by viewModel.uiState.collectAsState()

    LaunchedEffect(countyId) { viewModel.load(countyId) }

    if (uiState.isLoading) {
        CircularProgressIndicator(modifier = Modifier.padding(24.dp))
        return
    }

    val detail = uiState.detail
    if (detail == null) {
        Text("County not found.", modifier = Modifier.padding(16.dp))
        return
    }

    LazyColumn(modifier = Modifier.fillMaxSize().padding(16.dp), verticalArrangement = Arrangement.spacedBy(20.dp)) {
        item {
            Column {
                Text(detail.county.name, style = MaterialTheme.typography.headlineSmall)
                Text(detail.county.province.name.lowercase().replaceFirstChar { it.uppercase() }, style = MaterialTheme.typography.bodyMedium)
                detail.county.nickname?.let { Text(it, style = MaterialTheme.typography.labelMedium) }
            }
        }

        item { Text("Intercounty teams", style = MaterialTheme.typography.titleMedium) }
        items(detail.teams) { team ->
            Card(modifier = Modifier.fillMaxWidth().clickable { onOpenTeam(team.id) }) {
                Column(modifier = Modifier.padding(12.dp)) {
                    Text("${team.sportCode.icon} ${team.sportCode.label}", style = MaterialTheme.typography.titleSmall)
                    team.foundedYear?.let { Text("Founded $it", style = MaterialTheme.typography.labelSmall) }
                    team.currentManager?.let { Text("Manager: $it", style = MaterialTheme.typography.labelSmall) }
                }
            }
        }

        item { Text("Home grounds", style = MaterialTheme.typography.titleMedium) }
        items(detail.grounds) { ground ->
            Card(modifier = Modifier.fillMaxWidth().clickable { onOpenGround(ground.id) }) {
                Column(modifier = Modifier.padding(12.dp)) {
                    Text(ground.name, style = MaterialTheme.typography.titleSmall)
                    ground.capacity?.let { Text("Capacity: $it", style = MaterialTheme.typography.labelSmall) }
                }
            }
        }

        if (detail.honours.isNotEmpty()) {
            item { Text("Roll of honour", style = MaterialTheme.typography.titleMedium) }
            items(detail.honours) { honour ->
                Text("${honour.year} — ${honour.competitionName}", style = MaterialTheme.typography.bodyMedium)
            }
        }
    }
}
