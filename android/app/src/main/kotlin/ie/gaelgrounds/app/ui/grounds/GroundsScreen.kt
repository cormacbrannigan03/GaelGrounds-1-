package ie.gaelgrounds.app.ui.grounds

import androidx.compose.foundation.clickable
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
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import ie.gaelgrounds.app.data.model.GroundSummary
import ie.gaelgrounds.app.ui.theme.BrandGold

@Composable
fun GroundsScreen(userId: String?, onOpenGround: (String) -> Unit, viewModel: GroundsViewModel = viewModel()) {
    val uiState by viewModel.uiState.collectAsState()

    LaunchedEffect(userId) { viewModel.load(userId) }

    Column(modifier = Modifier.fillMaxSize().padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(
            if (uiState.visitedCount > 0) {
                "You've visited ${uiState.visitedCount} of ${uiState.grounds.size} grounds."
            } else {
                "Browse every intercounty ground and check in when you visit."
            },
            style = MaterialTheme.typography.bodyMedium,
        )

        OutlinedTextField(
            value = uiState.search,
            onValueChange = viewModel::setSearch,
            label = { Text("Search grounds or counties…") },
            modifier = Modifier.fillMaxWidth(),
            singleLine = true,
        )

        if (uiState.isLoading) {
            CircularProgressIndicator()
        } else {
            LazyColumn(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                items(uiState.filtered) { ground ->
                    GroundCard(ground = ground, onClick = { onOpenGround(ground.id) })
                }
            }
        }
    }
}

@Composable
private fun GroundCard(ground: GroundSummary, onClick: () -> Unit) {
    Card(modifier = Modifier.fillMaxWidth().clickable(onClick = onClick)) {
        Column(modifier = Modifier.padding(14.dp)) {
            Row(horizontalArrangement = Arrangement.SpaceBetween, modifier = Modifier.fillMaxWidth()) {
                Text(ground.name, style = MaterialTheme.typography.titleMedium)
                if (ground.visited) {
                    Text("✓ Visited", color = BrandGold, style = MaterialTheme.typography.labelSmall)
                }
            }
            Text(ground.countyName, style = MaterialTheme.typography.bodySmall)
            ground.capacity?.let {
                Text("Capacity: $it", style = MaterialTheme.typography.labelSmall)
            }
        }
    }
}
