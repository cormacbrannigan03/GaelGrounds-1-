package ie.gaelgrounds.app.ui.matches

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Tab
import androidx.compose.material3.TabRow
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import ie.gaelgrounds.app.data.model.SportCode
import ie.gaelgrounds.app.ui.components.MatchSummaryCard

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MatchesScreen(userId: String?, onOpenMatch: (String) -> Unit, viewModel: MatchesViewModel = viewModel()) {
    val uiState by viewModel.uiState.collectAsState()

    LaunchedEffect(Unit) { viewModel.load() }

    Column(modifier = Modifier.fillMaxSize().padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        OutlinedTextField(
            value = uiState.search,
            onValueChange = viewModel::setSearch,
            label = { Text("Search by team, competition, ground…") },
            modifier = Modifier.fillMaxWidth(),
            singleLine = true,
        )

        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            FilterChip(
                selected = uiState.selectedSport == SportCode.GAELIC_FOOTBALL,
                onClick = { viewModel.setSport(SportCode.GAELIC_FOOTBALL) },
                label = { Text("Football") },
            )
            FilterChip(
                selected = uiState.selectedSport == SportCode.HURLING,
                onClick = { viewModel.setSport(SportCode.HURLING) },
                label = { Text("Hurling") },
            )
        }

        val tabIndex = when (uiState.tab) {
            MatchesTab.UPCOMING -> 0
            MatchesTab.FIXTURES -> 1
            MatchesTab.RESULTS -> 2
        }
        TabRow(selectedTabIndex = tabIndex) {
            Tab(selected = tabIndex == 0, onClick = { viewModel.setTab(MatchesTab.UPCOMING) }, text = { Text("Upcoming") })
            Tab(selected = tabIndex == 1, onClick = { viewModel.setTab(MatchesTab.FIXTURES) }, text = { Text("Fixtures") })
            Tab(selected = tabIndex == 2, onClick = { viewModel.setTab(MatchesTab.RESULTS) }, text = { Text("Results") })
        }

        if (uiState.isLoading) {
            CircularProgressIndicator()
        } else if (uiState.displayedList.isEmpty()) {
            Text("No matches found.", style = MaterialTheme.typography.bodyMedium)
        } else {
            LazyColumn(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                items(uiState.displayedList) { match ->
                    MatchSummaryCard(match = match, onClick = { onOpenMatch(match.id) })
                }
            }
        }
    }
}
