package ie.gaelgrounds.app.ui.counties

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import ie.gaelgrounds.app.data.Supa
import ie.gaelgrounds.app.data.model.County
import ie.gaelgrounds.app.data.model.CountyTeam
import ie.gaelgrounds.app.data.model.Match
import ie.gaelgrounds.app.data.model.MatchSummary
import ie.gaelgrounds.app.data.service.MatchService
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.query.Order
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class TeamDetailUiState(
    val isLoading: Boolean = true,
    val team: CountyTeam? = null,
    val countyName: String? = null,
    val upcoming: List<MatchSummary> = emptyList(),
    val results: List<MatchSummary> = emptyList(),
)

/** Mirrors ios/GaelGrounds/Views/Counties/TeamDetailView.swift (alternate grounds not yet ported). */
class TeamDetailViewModel : ViewModel() {
    private val _uiState = MutableStateFlow(TeamDetailUiState())
    val uiState: StateFlow<TeamDetailUiState> = _uiState.asStateFlow()

    fun load(teamId: String) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true)
            try {
                val team = Supa.client.from("county_teams").select {
                    filter { eq("id", teamId) }
                    single()
                }.decodeSingle<CountyTeam>()
                val county = Supa.client.from("counties").select {
                    filter { eq("id", team.countyId) }
                    single()
                }.decodeSingle<County>()

                val matches = coroutineScope {
                    val homeDeferred = async {
                        Supa.client.from("matches").select {
                            filter { eq("home_county_team_id", teamId) }
                            order("played_at", Order.DESCENDING)
                            limit(20)
                        }.decodeList<Match>()
                    }
                    val awayDeferred = async {
                        Supa.client.from("matches").select {
                            filter { eq("away_county_team_id", teamId) }
                            order("played_at", Order.DESCENDING)
                            limit(20)
                        }.decodeList<Match>()
                    }
                    (homeDeferred.await() + awayDeferred.await()).sortedByDescending { it.playedAt ?: "" }
                }

                val summaries = MatchService.resolveSummaries(matches)
                val upcoming = summaries.filter { it.isUpcoming || it.isLive }.sortedBy { it.playedAt ?: "" }
                val results = summaries.filter { it.isPast }.sortedByDescending { it.playedAt ?: "" }

                _uiState.value = _uiState.value.copy(
                    team = team,
                    countyName = county.name,
                    upcoming = upcoming,
                    results = results,
                    isLoading = false,
                )
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(isLoading = false)
            }
        }
    }
}
