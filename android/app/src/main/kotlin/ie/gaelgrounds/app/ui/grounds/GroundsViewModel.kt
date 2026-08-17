package ie.gaelgrounds.app.ui.grounds

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import ie.gaelgrounds.app.data.model.GroundSummary
import ie.gaelgrounds.app.data.service.GroundService
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class GroundsUiState(
    val isLoading: Boolean = true,
    val grounds: List<GroundSummary> = emptyList(),
    val search: String = "",
) {
    val filtered: List<GroundSummary>
        get() {
            val q = search.trim().lowercase()
            val primaryOnly = grounds.filter { it.isPrimary }
            if (q.isEmpty()) return primaryOnly
            return primaryOnly.filter { it.name.lowercase().contains(q) || it.countyName.lowercase().contains(q) }
        }

    val visitedCount: Int get() = grounds.count { it.visited }
}

/** Mirrors ios/GaelGrounds/Views/Grounds/GroundsView.swift (map view not yet ported). */
class GroundsViewModel : ViewModel() {
    private val _uiState = MutableStateFlow(GroundsUiState())
    val uiState: StateFlow<GroundsUiState> = _uiState.asStateFlow()

    fun load(userId: String?) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true)
            try {
                val summaries = GroundService.fetchSummaries(userId)
                _uiState.value = _uiState.value.copy(grounds = summaries, isLoading = false)
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(isLoading = false)
            }
        }
    }

    fun setSearch(query: String) {
        _uiState.value = _uiState.value.copy(search = query)
    }
}
