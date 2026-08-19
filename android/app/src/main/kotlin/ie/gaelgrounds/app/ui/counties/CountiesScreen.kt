package ie.gaelgrounds.app.ui.counties

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.item
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import ie.gaelgrounds.app.data.model.County
import ie.gaelgrounds.app.data.model.Province

private val provinceOrder = listOf(Province.LEINSTER, Province.MUNSTER, Province.CONNACHT, Province.ULSTER)

@Composable
fun CountiesScreen(onOpenCounty: (String) -> Unit, viewModel: CountiesViewModel = viewModel()) {
    val uiState by viewModel.uiState.collectAsState()

    LaunchedEffect(Unit) { viewModel.load() }

    LazyColumn(modifier = Modifier.fillMaxSize().padding(16.dp), verticalArrangement = Arrangement.spacedBy(20.dp)) {
        item {
            Column {
                Text("All counties", style = MaterialTheme.typography.headlineSmall)
                Text(
                    "Every county competing at intercounty level, across Gaelic football, hurling, camogie and ladies' football.",
                    style = MaterialTheme.typography.bodyMedium,
                )
            }
        }

        if (uiState.isLoading) {
            item { CircularProgressIndicator() }
        } else {
            for (province in provinceOrder) {
                val inProvince = uiState.byProvince[province].orEmpty()
                if (inProvince.isNotEmpty()) {
                    item {
                        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            Text(province.name.lowercase().replaceFirstChar { it.uppercase() }, style = MaterialTheme.typography.titleMedium)
                            CountyChips(counties = inProvince, onOpenCounty = onOpenCounty)
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun CountyChips(counties: List<County>, onOpenCounty: (String) -> Unit) {
    FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        counties.sortedBy { it.name }.forEach { county ->
            Surface(
                onClick = { onOpenCounty(county.id) },
                shape = RoundedCornerShape(50),
                color = MaterialTheme.colorScheme.surfaceVariant,
                border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant),
            ) {
                Text(
                    text = county.name,
                    style = MaterialTheme.typography.labelLarge,
                    modifier = Modifier.padding(horizontal = 14.dp, vertical = 8.dp),
                )
            }
        }
    }
}
