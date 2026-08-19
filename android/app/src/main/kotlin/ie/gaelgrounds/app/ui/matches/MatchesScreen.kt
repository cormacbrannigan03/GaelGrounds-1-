package ie.gaelgrounds.app.ui.matches

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.combinedClickable
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
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Tab
import androidx.compose.material3.TabRow
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import ie.gaelgrounds.app.data.model.SportCode
import ie.gaelgrounds.app.data.model.UserPersonalMatch
import ie.gaelgrounds.app.ui.components.MatchSummaryCard
import ie.gaelgrounds.app.ui.theme.gaelCard

@OptIn(ExperimentalMaterial3Api::class, ExperimentalComposeUiApi::class)
@Composable
fun MatchesScreen(userId: String?, onOpenMatch: (String) -> Unit, viewModel: MatchesViewModel = viewModel()) {
    val uiState by viewModel.uiState.collectAsState()
    var showFilters by remember { mutableStateOf(false) }
    var showAddMatch by remember { mutableStateOf(false) }

    LaunchedEffect(userId) { viewModel.load(userId) }

    Column(modifier = Modifier.fillMaxSize().padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            OutlinedTextField(
                value = uiState.search,
                onValueChange = viewModel::setSearch,
                label = { Text("Search…") },
                modifier = Modifier.weight(1f),
                singleLine = true,
            )
            val activeFilters = listOf(uiState.selectedCounty, uiState.selectedCompetition, uiState.selectedVenue).count { it.isNotEmpty() }
            OutlinedButton(onClick = { showFilters = true }) {
                Text(if (activeFilters > 0) "Filters ($activeFilters)" else "Filters")
            }
        }

        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            FilterChip(selected = uiState.selectedSport == SportCode.GAELIC_FOOTBALL, onClick = { viewModel.setSport(SportCode.GAELIC_FOOTBALL) }, label = { Text("Football") })
            FilterChip(selected = uiState.selectedSport == SportCode.HURLING, onClick = { viewModel.setSport(SportCode.HURLING) }, label = { Text("Hurling") })
            if (userId != null) {
                FilterChip(selected = false, onClick = { showAddMatch = true }, label = { Text("+ Add match") })
            }
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
        } else if (uiState.tab == MatchesTab.RESULTS) {
            ResultsContent(uiState = uiState, userId = userId, onOpenMatch = onOpenMatch, viewModel = viewModel)
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

    if (showFilters) {
        FiltersDialog(uiState = uiState, viewModel = viewModel, onDismiss = { showFilters = false })
    }

    if (showAddMatch && userId != null) {
        AddMatchDialog(
            userId = userId,
            isSaving = uiState.isAddingMatch,
            error = uiState.addMatchError,
            onDismiss = { showAddMatch = false },
            onSave = { home, away, competition, round, venue, homeScore, awayScore ->
                viewModel.addPersonalMatch(userId, home, away, competition, round, venue, nowAsIso(), homeScore, awayScore)
                showAddMatch = false
            },
        )
    }
}

@Composable
private fun ResultsContent(
    uiState: MatchesUiState,
    userId: String?,
    onOpenMatch: (String) -> Unit,
    viewModel: MatchesViewModel,
) {
    val hasPersonal = uiState.filteredPersonalMatches.isNotEmpty()
    val hasOfficial = uiState.yearGroups.isNotEmpty()

    if (!hasPersonal && !hasOfficial) {
        Text("No results yet — check back once games have been played.", style = MaterialTheme.typography.bodyMedium)
        return
    }

    LazyColumn(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        if (hasPersonal) {
            item { Text("My Matches (${uiState.filteredPersonalMatches.size})", style = MaterialTheme.typography.titleMedium) }
            items(uiState.filteredPersonalMatches) { match ->
                PersonalMatchCard(match = match, onDelete = { userId?.let { viewModel.deletePersonalMatch(it, match.id) } })
            }
        }
        uiState.yearGroups.forEach { (year, matches) ->
            item { Text("$year (${matches.size})", style = MaterialTheme.typography.titleMedium) }
            items(matches) { match ->
                MatchSummaryCard(match = match, onClick = { onOpenMatch(match.id) })
            }
        }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun PersonalMatchCard(match: UserPersonalMatch, onDelete: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .gaelCard()
            .combinedClickable(onClick = {}, onLongClick = onDelete)
            .padding(14.dp),
    ) {
        Text(match.competition ?: "Personal Match", style = MaterialTheme.typography.labelSmall)
        val scoreline = if (match.hasScore) {
            "${match.homeTeam} ${match.homeScore} - ${match.awayScore} ${match.awayTeam}"
        } else {
            "${match.homeTeam} v ${match.awayTeam}"
        }
        Text(scoreline, style = MaterialTheme.typography.titleMedium)
        match.venue?.let { Text(it, style = MaterialTheme.typography.bodySmall) }
        Text("Long-press to delete", style = MaterialTheme.typography.labelSmall)
    }
}

@Composable
private fun FiltersDialog(uiState: MatchesUiState, viewModel: MatchesViewModel, onDismiss: () -> Unit) {
    AlertDialog(
        onDismissRequest = onDismiss,
        confirmButton = { TextButton(onClick = onDismiss) { Text("Done") } },
        dismissButton = { TextButton(onClick = { viewModel.clearFilters() }) { Text("Reset") } },
        title = { Text("Filter matches") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                FilterOptionRow("County", uiState.selectedCounty, uiState.countyOptions, viewModel::setCountyFilter)
                FilterOptionRow("Competition", uiState.selectedCompetition, uiState.competitionOptions, viewModel::setCompetitionFilter)
                FilterOptionRow("Venue", uiState.selectedVenue, uiState.venueOptions, viewModel::setVenueFilter)
            }
        },
    )
}

@Composable
private fun FilterOptionRow(label: String, selected: String, options: List<String>, onSelect: (String) -> Unit) {
    Column {
        Text(label, style = MaterialTheme.typography.labelLarge)
        androidx.compose.foundation.layout.FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            FilterChip(selected = selected.isEmpty(), onClick = { onSelect("") }, label = { Text("Any") })
            options.take(20).forEach { option ->
                FilterChip(selected = selected == option, onClick = { onSelect(option) }, label = { Text(option) })
            }
        }
    }
}

@Composable
private fun AddMatchDialog(
    userId: String,
    isSaving: Boolean,
    error: String?,
    onDismiss: () -> Unit,
    onSave: (home: String, away: String, competition: String, round: String, venue: String, homeScore: String, awayScore: String) -> Unit,
) {
    var homeTeam by remember { mutableStateOf("") }
    var awayTeam by remember { mutableStateOf("") }
    var competition by remember { mutableStateOf("") }
    var round by remember { mutableStateOf("") }
    var venue by remember { mutableStateOf("") }
    var homeScore by remember { mutableStateOf("") }
    var awayScore by remember { mutableStateOf("") }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Add match") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(value = homeTeam, onValueChange = { homeTeam = it }, label = { Text("Home team") }, singleLine = true, modifier = Modifier.fillMaxWidth())
                OutlinedTextField(value = awayTeam, onValueChange = { awayTeam = it }, label = { Text("Away team") }, singleLine = true, modifier = Modifier.fillMaxWidth())
                OutlinedTextField(value = competition, onValueChange = { competition = it }, label = { Text("Competition") }, singleLine = true, modifier = Modifier.fillMaxWidth())
                OutlinedTextField(value = round, onValueChange = { round = it }, label = { Text("Round") }, singleLine = true, modifier = Modifier.fillMaxWidth())
                OutlinedTextField(value = venue, onValueChange = { venue = it }, label = { Text("Venue") }, singleLine = true, modifier = Modifier.fillMaxWidth())
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedTextField(value = homeScore, onValueChange = { homeScore = it }, label = { Text("Home score") }, singleLine = true, modifier = Modifier.weight(1f))
                    OutlinedTextField(value = awayScore, onValueChange = { awayScore = it }, label = { Text("Away score") }, singleLine = true, modifier = Modifier.weight(1f))
                }
                Text("Logged as happening now. Goals-points format, e.g. 1-14.", style = MaterialTheme.typography.labelSmall)
                error?.let { Text(it, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.labelSmall) }
            }
        },
        confirmButton = {
            Button(
                onClick = { onSave(homeTeam, awayTeam, competition, round, venue, homeScore, awayScore) },
                enabled = !isSaving && homeTeam.isNotBlank() && awayTeam.isNotBlank(),
            ) {
                Text(if (isSaving) "Saving…" else "Save")
            }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel") } },
    )
}
