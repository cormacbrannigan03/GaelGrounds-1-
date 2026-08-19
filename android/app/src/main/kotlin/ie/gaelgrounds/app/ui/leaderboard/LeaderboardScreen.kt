package ie.gaelgrounds.app.ui.leaderboard

import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import ie.gaelgrounds.app.data.model.AchievementTier
import ie.gaelgrounds.app.ui.theme.gaelCard

private val tabLabels = mapOf(
    LeaderboardTab.OVERALL to "Overall",
    LeaderboardTab.MY_COUNTY to "My County",
    LeaderboardTab.ULSTER to "Ulster",
    LeaderboardTab.MUNSTER to "Munster",
    LeaderboardTab.LEINSTER to "Leinster",
    LeaderboardTab.CONNACHT to "Connacht",
    LeaderboardTab.BRONZE to "Most Bronze",
    LeaderboardTab.SILVER to "Most Silver",
    LeaderboardTab.GOLD to "Top Gold",
)

@Composable
fun LeaderboardScreen(userId: String?, viewModel: LeaderboardViewModel = viewModel()) {
    val uiState by viewModel.uiState.collectAsState()

    LaunchedEffect(userId) { viewModel.load(userId) }

    Column(modifier = Modifier.fillMaxSize().padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(
            horizontalArrangement = Arrangement.spacedBy(6.dp),
            modifier = Modifier.horizontalScroll(rememberScrollState()),
        ) {
            LeaderboardTab.entries.forEach { tab ->
                FilterChip(
                    selected = uiState.activeTab == tab,
                    onClick = { viewModel.setTab(tab) },
                    label = { Text(tabLabels.getValue(tab)) },
                )
            }
        }

        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            FilterChip(selected = uiState.scope == Scope.EVERYONE, onClick = { viewModel.setScope(Scope.EVERYONE) }, label = { Text("Everyone") })
            FilterChip(selected = uiState.scope == Scope.FRIENDS, onClick = { viewModel.setScope(Scope.FRIENDS) }, label = { Text("Friends") })
        }

        if (uiState.activeTab == LeaderboardTab.OVERALL || uiState.activeTab == LeaderboardTab.MY_COUNTY) {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                FilterChip(selected = uiState.sortBy == SortKey.MATCHES, onClick = { viewModel.setSort(SortKey.MATCHES) }, label = { Text("Matches") })
                FilterChip(selected = uiState.sortBy == SortKey.GROUNDS, onClick = { viewModel.setSort(SortKey.GROUNDS) }, label = { Text("Grounds") })
            }
        }

        if (uiState.isLoading) {
            CircularProgressIndicator()
        } else if (uiState.displayed.isEmpty()) {
            Text("No activity yet. Be the first to check in!", style = MaterialTheme.typography.bodyMedium)
        } else {
            LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                itemsIndexed(uiState.displayed) { index, entry ->
                    val rankLabel = when (index) {
                        0 -> "🥇"
                        1 -> "🥈"
                        2 -> "🥉"
                        else -> "${index + 1}"
                    }
                    val tab = uiState.activeTab
                    val primaryCount = when {
                        tab == LeaderboardTab.BRONZE -> entry.tierCounts[AchievementTier.BRONZE] ?: 0
                        tab == LeaderboardTab.SILVER -> entry.tierCounts[AchievementTier.SILVER] ?: 0
                        tab == LeaderboardTab.GOLD -> entry.tierCounts[AchievementTier.GOLD] ?: 0
                        tab == LeaderboardTab.ULSTER || tab == LeaderboardTab.MUNSTER || tab == LeaderboardTab.LEINSTER || tab == LeaderboardTab.CONNACHT ->
                            entry.provinceMatchCounts.entries.firstOrNull { (province, _) -> tabProvince[tab] == province }?.value ?: 0
                        uiState.sortBy == SortKey.MATCHES -> entry.matchCount
                        else -> entry.groundCount
                    }
                    val primaryLabel = when (tab) {
                        LeaderboardTab.BRONZE, LeaderboardTab.SILVER, LeaderboardTab.GOLD -> "achievements"
                        LeaderboardTab.ULSTER, LeaderboardTab.MUNSTER, LeaderboardTab.LEINSTER, LeaderboardTab.CONNACHT -> "matches"
                        else -> if (uiState.sortBy == SortKey.MATCHES) "matches" else "grounds"
                    }
                    Box(modifier = Modifier.fillMaxWidth().gaelCard()) {
                        Row(
                            modifier = Modifier.padding(12.dp).fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                        ) {
                            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                                Text(rankLabel, style = MaterialTheme.typography.titleMedium)
                                Column {
                                    Text(entry.displayName, style = MaterialTheme.typography.titleSmall)
                                    Text("${entry.matchCount} matches · ${entry.groundCount} grounds", style = MaterialTheme.typography.labelSmall)
                                }
                            }
                            Column(horizontalAlignment = androidx.compose.ui.Alignment.End) {
                                Text("$primaryCount", style = MaterialTheme.typography.titleMedium)
                                Text(primaryLabel, style = MaterialTheme.typography.labelSmall)
                            }
                        }
                    }
                }
            }
        }
    }
}
