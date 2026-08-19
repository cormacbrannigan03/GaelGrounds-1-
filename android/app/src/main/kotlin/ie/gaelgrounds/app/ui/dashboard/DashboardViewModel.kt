package ie.gaelgrounds.app.ui.dashboard

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import ie.gaelgrounds.app.data.Supa
import ie.gaelgrounds.app.data.model.MatchSummary
import ie.gaelgrounds.app.data.model.UserVisit
import ie.gaelgrounds.app.data.service.MatchService
import ie.gaelgrounds.app.data.service.RealtimeWatcher
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.query.Columns
import io.github.jan.supabase.realtime.RealtimeChannel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

data class DashboardUiState(
    val isLoading: Boolean = true,
    val upcoming: List<MatchSummary> = emptyList(),
    val groundsVisited: Int = 0,
    val matchesAttended: Int = 0,
    val achievementsUnlocked: Int = 0,
)

/** Mirrors ios/GaelGrounds/Views/Dashboard/DashboardView.swift (minus avatar upload, which lives on Profile instead here). */
class DashboardViewModel : ViewModel() {
    private val _uiState = MutableStateFlow(DashboardUiState())
    val uiState: StateFlow<DashboardUiState> = _uiState.asStateFlow()

    private var watchChannel: RealtimeChannel? = null
    private var hasStartedWatching = false

    @Serializable
    private data class GroundIdOnly(@SerialName("ground_id") val groundId: String)

    override fun onCleared() {
        RealtimeWatcher.stop(watchChannel)
        super.onCleared()
    }

    fun load(userId: String?) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true)
            try {
                val matches = MatchService.fetchUpcomingAndLive()
                val summaries = MatchService.resolveSummaries(matches)
                _uiState.value = _uiState.value.copy(upcoming = summaries)
            } catch (e: Exception) {
                // Public fixtures failing to load isn't fatal to the rest of the dashboard.
            }

            if (!hasStartedWatching) {
                hasStartedWatching = true
                watchChannel = RealtimeWatcher.watch(scope = viewModelScope, table = "matches") {
                    viewModelScope.launch { reloadUpcoming() }
                }
            }

            if (userId != null) {
                val groundsVisited = try {
                    Supa.client.from("user_visits")
                        .select(columns = Columns.raw("ground_id")) { filter { eq("user_id", userId) } }
                        .decodeList<GroundIdOnly>()
                        .map { it.groundId }
                        .toSet()
                        .size
                } catch (e: Exception) { 0 }

                val matchesAttended = countRows("user_match_attendance", userId)
                val achievementsUnlocked = countRows("user_achievements", userId)

                _uiState.value = _uiState.value.copy(
                    groundsVisited = groundsVisited,
                    matchesAttended = matchesAttended,
                    achievementsUnlocked = achievementsUnlocked,
                )
            }

            _uiState.value = _uiState.value.copy(isLoading = false)
        }
    }

    private suspend fun reloadUpcoming() {
        try {
            val matches = MatchService.fetchUpcomingAndLive()
            val summaries = MatchService.resolveSummaries(matches)
            _uiState.value = _uiState.value.copy(upcoming = summaries)
        } catch (e: Exception) {
            // Leave upcoming as-is on failure.
        }
    }

    @Serializable
    private data class IdOnly(val id: String)

    private suspend fun countRows(table: String, userId: String): Int {
        return try {
            Supa.client.from(table)
                .select(columns = Columns.raw("id")) { filter { eq("user_id", userId) } }
                .decodeList<IdOnly>()
                .size
        } catch (e: Exception) {
            0
        }
    }
}
