package ie.gaelgrounds.app.ui.matches

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import ie.gaelgrounds.app.data.Supa
import ie.gaelgrounds.app.data.model.AchievementEvaluation
import ie.gaelgrounds.app.data.model.Match
import ie.gaelgrounds.app.data.model.MatchSummary
import ie.gaelgrounds.app.data.model.UserMatchAttendance
import ie.gaelgrounds.app.data.model.UserProfile
import ie.gaelgrounds.app.data.service.MatchService
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.query.Order
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class Attendee(val attendanceId: String, val userId: String, val displayName: String?)

data class MatchDetailUiState(
    val isLoading: Boolean = true,
    val match: Match? = null,
    val summary: MatchSummary? = null,
    val attendees: List<Attendee> = emptyList(),
    val myAttendanceId: String? = null,
    val isBusy: Boolean = false,
    val lastEvaluation: AchievementEvaluation? = null,
)

/** Simplified port of ios/GaelGrounds/Views/Matches/MatchDetailView.swift + CheckInPanel.swift (no realtime, no premium gating yet). */
class MatchDetailViewModel : ViewModel() {
    private val _uiState = MutableStateFlow(MatchDetailUiState())
    val uiState: StateFlow<MatchDetailUiState> = _uiState.asStateFlow()

    fun load(matchId: String, userId: String?) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true)
            try {
                val match = Supa.client.from("matches").select {
                    filter { eq("id", matchId) }
                    single()
                }.decodeSingle<Match>()
                val summaries = MatchService.resolveSummaries(listOf(match))
                _uiState.value = _uiState.value.copy(match = match, summary = summaries.firstOrNull())
            } catch (e: Exception) {
                // Leave match/summary null; UI shows a not-found state.
            }
            loadAttendees(matchId, userId)
            _uiState.value = _uiState.value.copy(isLoading = false)
        }
    }

    private suspend fun loadAttendees(matchId: String, userId: String?) {
        try {
            val rows = Supa.client.from("user_match_attendance").select {
                filter { eq("match_id", matchId) }
                order("created_at", Order.DESCENDING)
            }.decodeList<UserMatchAttendance>()

            val userIds = rows.map { it.userId }.distinct()
            val profiles = if (userIds.isEmpty()) {
                emptyList()
            } else {
                Supa.client.from("user_profiles").select {
                    filter { isIn("id", userIds) }
                }.decodeList<UserProfile>()
            }
            val nameById = profiles.associate { it.id to it.displayName }

            _uiState.value = _uiState.value.copy(
                attendees = rows.map { Attendee(it.id, it.userId, nameById[it.userId]) },
                myAttendanceId = rows.firstOrNull { it.userId == userId }?.id,
            )
        } catch (e: Exception) {
            // Leave attendees as-is on failure.
        }
    }

    fun checkIn(matchId: String, userId: String) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isBusy = true)
            try {
                val evaluation = MatchService.checkIn(matchId, userId)
                _uiState.value = _uiState.value.copy(lastEvaluation = evaluation)
                loadAttendees(matchId, userId)
            } catch (e: Exception) {
                // Swallow -- the button re-enables and the user can retry.
            }
            _uiState.value = _uiState.value.copy(isBusy = false)
        }
    }

    fun checkOut(matchId: String, attendanceId: String, userId: String?) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isBusy = true)
            try {
                Supa.client.from("user_match_attendance").delete {
                    filter { eq("id", attendanceId) }
                }
                loadAttendees(matchId, userId)
            } catch (e: Exception) {
                // Swallow -- the button re-enables and the user can retry.
            }
            _uiState.value = _uiState.value.copy(isBusy = false)
        }
    }

    fun dismissEvaluation() {
        _uiState.value = _uiState.value.copy(lastEvaluation = null)
    }
}
