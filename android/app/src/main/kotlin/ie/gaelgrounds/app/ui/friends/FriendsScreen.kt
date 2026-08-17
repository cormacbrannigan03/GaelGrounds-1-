package ie.gaelgrounds.app.ui.friends

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.item
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
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
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel

@Composable
fun FriendsScreen(userId: String?, onBack: () -> Unit, viewModel: FriendsViewModel = viewModel()) {
    val uiState by viewModel.uiState.collectAsState()

    LaunchedEffect(userId) { viewModel.load(userId) }

    if (userId == null) {
        Text("Sign in to add friends.", modifier = Modifier.padding(16.dp))
        return
    }

    LazyColumn(modifier = Modifier.fillMaxSize().padding(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        item {
            OutlinedTextField(
                value = uiState.searchQuery,
                onValueChange = viewModel::setSearchQuery,
                label = { Text("Search by display name…") },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
            )
        }

        if (uiState.searchResults.isNotEmpty()) {
            item { Text("Results", style = MaterialTheme.typography.titleMedium) }
            items(uiState.searchResults) { profile ->
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(profile.displayName ?: "Anonymous")
                    Button(onClick = { viewModel.sendRequest(profile.id) }) { Text("Add") }
                }
            }
        }

        if (uiState.isLoading) {
            item { CircularProgressIndicator() }
        } else {
            if (uiState.pendingRequests.isNotEmpty()) {
                item { Text("Requests", style = MaterialTheme.typography.titleMedium) }
                items(uiState.pendingRequests) { request ->
                    Card(modifier = Modifier.fillMaxWidth()) {
                        Row(
                            modifier = Modifier.padding(12.dp).fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Text(request.profile.displayName ?: "Anonymous")
                            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                OutlinedButton(onClick = { viewModel.respond(request.friendshipId, accept = false) }) { Text("Decline") }
                                Button(onClick = { viewModel.respond(request.friendshipId, accept = true) }) { Text("Accept") }
                            }
                        }
                    }
                }
            }

            if (uiState.sentRequests.isNotEmpty()) {
                item { Text("Sent requests", style = MaterialTheme.typography.titleMedium) }
                items(uiState.sentRequests) { request ->
                    Text(request.profile.displayName ?: "Anonymous", style = MaterialTheme.typography.bodyMedium)
                }
            }

            item { Text("Friends (${uiState.friends.size})", style = MaterialTheme.typography.titleMedium) }
            if (uiState.friends.isEmpty()) {
                item { Text("No friends yet -- search above to add some.", style = MaterialTheme.typography.bodyMedium) }
            } else {
                items(uiState.friends) { friend ->
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(friend.profile.displayName ?: "Anonymous")
                        TextButton(onClick = { viewModel.removeFriend(friend.friendshipId) }) { Text("Remove") }
                    }
                }
            }
        }
    }

    val error = uiState.errorMessage
    if (error != null) {
        AlertDialog(
            onDismissRequest = viewModel::dismissError,
            confirmButton = { TextButton(onClick = viewModel::dismissError) { Text("OK") } },
            title = { Text("Couldn't send request") },
            text = { Text(error) },
        )
    }
}
