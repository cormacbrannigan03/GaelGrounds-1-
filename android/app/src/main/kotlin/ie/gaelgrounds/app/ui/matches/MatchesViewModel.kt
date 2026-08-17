package ie.gaelgrounds.app.ui.matches

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import ie.gaelgrounds.app.data.model.MatchSummary
import ie.gaelgrounds.app.data.model.SportCode
import ie.gaelgrounds.app.data.service.MatchService
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

enum class MatchesTab { UPCOMING, FIXTURES, RESULTS }

data class MatchesUiState(
    val isLoading: Boolean = true,
    val allMatches: List<MatchSummary> = emptyList(),
    val selectedSport: SportCode = SportCode.GAELIC_FOOTBALL,
    val tab: MatchesTab = MatchesTab.UPCOMING,
    val search: String = "",
) {
    private val sportFiltered get() = allMatches.filter { it.sportCode == selectedSport }

    private val searchFiltered: List<MatchSummary>
        get() {
            val q = search.trim().lowercase()
            if (q.isEmpty()) return sportFiltered
            return sportFiltered.filter { m ->
                m.homeName.lowercase().contains(q) ||
                    m.awayName.lowercase().contains(q) ||
                    (m.competition ?: "").lowercase().contains(q) ||
                    (m.groundName ?: "").lowercase().contains(q) ||
                    (m.round ?: "").lowercase().contains(q)
            }
        }

    val upcomingList: List<MatchSummary>
        get() = searchFiltered.filter { it.isUpcoming || it.isLive }.sortedBy { it.playedAt ?: "9999" }

    val resultsList: List<MatchSummary>
        get() = searchFiltered.filter { it.isPast }.sortedByDescending { it.playedAt ?: "" }

    val displayedList: List<MatchSummary>
        get() = when (tab) {
            MatchesTab.UPCOMING, MatchesTab.FIXTURES -> upcomingList
            MatchesTab.RESULTS -> resultsList
        }
}

/** Simplified port of ios/GaelGrounds/Views/Matches/MatchesView.swift -- filters/personal matches/add-match not yet ported, see android/README.md. */
class MatchesViewModel : ViewModel() {
    private val _uiState = MutableStateFlow(MatchesUiState())
    val uiState: StateFlow<MatchesUiState> = _uiState.asStateFlow()

    fun load() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true)
            try {
                val rows = MatchService.fetchAll()
                val summaries = MatchService.resolveSummaries(rows)
                _uiState.value = _uiState.value.copy(allMatches = summaries, isLoading = false)
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(isLoading = false)
            }
        }
    }

    fun setSport(sport: SportCode) {
        _uiState.value = _uiState.value.copy(selectedSport = sport)
    }

    fun setTab(tab: MatchesTab) {
        _uiState.value = _uiState.value.copy(tab = tab)
    }

    fun setSearch(query: String) {
        _uiState.value = _uiState.value.copy(search = query)
    }
}
