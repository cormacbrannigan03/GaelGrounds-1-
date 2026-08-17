package ie.gaelgrounds.app.ui.friends

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import ie.gaelgrounds.app.data.model.UserProfile
import ie.gaelgrounds.app.data.service.FriendService
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class FriendsUiState(
    val isLoading: Boolean = true,
    val friends: List<FriendService.FriendEntry> = emptyList(),
    val pendingRequests: List<FriendService.FriendRequest> = emptyList(),
    val sentRequests: List<FriendService.FriendRequest> = emptyList(),
    val searchQuery: String = "",
    val searchResults: List<UserProfile> = emptyList(),
    val errorMessage: String? = null,
)

/** Mirrors ios/GaelGrounds/Views/Friends/FriendsView.swift (premium gate enforced server-side by RLS, not re-checked client-side here yet). */
class FriendsViewModel : ViewModel() {
    private val _uiState = MutableStateFlow(FriendsUiState())
    val uiState: StateFlow<FriendsUiState> = _uiState.asStateFlow()

    private var currentUserId: String? = null

    fun load(userId: String?) {
        currentUserId = userId
        if (userId == null) return
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true)
            try {
                val friends = FriendService.fetchFriends(userId)
                val pending = FriendService.fetchPendingRequests(userId)
                val sent = FriendService.fetchSentRequests(userId)
                _uiState.value = _uiState.value.copy(friends = friends, pendingRequests = pending, sentRequests = sent, isLoading = false)
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(isLoading = false)
            }
        }
    }

    fun setSearchQuery(query: String) {
        _uiState.value = _uiState.value.copy(searchQuery = query)
        val userId = currentUserId ?: return
        viewModelScope.launch {
            try {
                val results = FriendService.searchUsers(query, excludingUserId = userId)
                _uiState.value = _uiState.value.copy(searchResults = results)
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(searchResults = emptyList())
            }
        }
    }

    fun sendRequest(addresseeId: String) {
        val userId = currentUserId ?: return
        viewModelScope.launch {
            try {
                FriendService.sendRequest(requesterId = userId, addresseeId = addresseeId)
                load(userId)
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(errorMessage = "Couldn't send that request -- Premium is required to add friends.")
            }
        }
    }

    fun respond(friendshipId: String, accept: Boolean) {
        val userId = currentUserId
        viewModelScope.launch {
            try {
                FriendService.respondToRequest(friendshipId, accept)
                load(userId)
            } catch (e: Exception) {
                // Swallow -- the list just doesn't update on failure.
            }
        }
    }

    fun removeFriend(friendshipId: String) {
        val userId = currentUserId
        viewModelScope.launch {
            try {
                FriendService.removeFriendship(friendshipId)
                load(userId)
            } catch (e: Exception) {
                // Swallow -- the list just doesn't update on failure.
            }
        }
    }

    fun dismissError() {
        _uiState.value = _uiState.value.copy(errorMessage = null)
    }
}
