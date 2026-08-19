package ie.gaelgrounds.app.ui.grounds

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import ie.gaelgrounds.app.data.Supa
import ie.gaelgrounds.app.data.model.County
import ie.gaelgrounds.app.data.model.Ground
import ie.gaelgrounds.app.data.model.Match
import ie.gaelgrounds.app.data.model.UserMatchAttendance
import ie.gaelgrounds.app.data.model.UserVisit
import ie.gaelgrounds.app.data.model.UserVisitInsert
import ie.gaelgrounds.app.data.service.AchievementsService
import ie.gaelgrounds.app.data.service.MatchService
import ie.gaelgrounds.app.data.service.RealtimeWatcher
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.realtime.RealtimeChannel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class GameSeenHere(val matchId: String, val competition: String?, val playedAt: String?, val homeName: String, val awayName: String)

data class GroundDetailUiState(
    val isLoading: Boolean = true,
    val ground: Ground? = null,
    val countyName: String? = null,
    val gamesSeenHere: List<GameSeenHere> = emptyList(),
    val visitors: List<UserVisit> = emptyList(),
    val myVisitId: String? = null,
    val isBusy: Boolean = false,
    val unlockedTitles: List<String>? = null,
)

/** Mirrors ios/GaelGrounds/Views/Grounds/GroundDetailView.swift + GroundCheckInPanel.swift (no photo upload yet). */
class GroundDetailViewModel : ViewModel() {
    private val _uiState = MutableStateFlow(GroundDetailUiState())
    val uiState: StateFlow<GroundDetailUiState> = _uiState.asStateFlow()

    private var watchChannel: RealtimeChannel? = null
    private var watchedGroundId: String? = null

    override fun onCleared() {
        RealtimeWatcher.stop(watchChannel)
        super.onCleared()
    }

    fun load(groundId: String, userId: String?) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true)
            try {
                val ground = Supa.client.from("grounds").select {
                    filter { eq("id", groundId) }
                    single()
                }.decodeSingle<Ground>()
                val county = Supa.client.from("counties").select {
                    filter { eq("id", ground.countyId) }
                    single()
                }.decodeSingle<County>()

                var gamesSeenHere = emptyList<GameSeenHere>()
                if (userId != null) {
                    val matchesHere = Supa.client.from("matches").select {
                        filter { eq("ground_id", groundId) }
                    }.decodeList<Match>()
                    val matchIdsHere = matchesHere.map { it.id }.toSet()
                    if (matchIdsHere.isNotEmpty()) {
                        val attendance = Supa.client.from("user_match_attendance").select {
                            filter { eq("user_id", userId) }
                        }.decodeList<UserMatchAttendance>()
                        val myAttendanceHere = attendance.filter { matchIdsHere.contains(it.matchId) }
                        if (myAttendanceHere.isNotEmpty()) {
                            val attendedMatches = matchesHere.filter { m -> myAttendanceHere.any { it.matchId == m.id } }
                            val summaries = MatchService.resolveSummaries(attendedMatches)
                            val summaryById = summaries.associateBy { it.id }
                            gamesSeenHere = myAttendanceHere
                                .mapNotNull { a ->
                                    val summary = summaryById[a.matchId] ?: return@mapNotNull null
                                    val playedAt = summary.playedAt ?: return@mapNotNull null
                                    GameSeenHere(a.matchId, summary.competition, playedAt, summary.homeName, summary.awayName)
                                }
                                .sortedByDescending { it.playedAt }
                        }
                    }
                }

                _uiState.value = _uiState.value.copy(ground = ground, countyName = county.name, gamesSeenHere = gamesSeenHere)
            } catch (e: Exception) {
                // Leave ground null; UI shows a not-found state.
            }
            loadVisitors(groundId, userId)
            _uiState.value = _uiState.value.copy(isLoading = false)

            if (watchedGroundId != groundId) {
                RealtimeWatcher.stop(watchChannel)
                watchedGroundId = groundId
                watchChannel = RealtimeWatcher.watch(
                    scope = viewModelScope,
                    table = "user_visits",
                    filterColumn = "ground_id",
                    filterValue = groundId,
                ) { viewModelScope.launch { loadVisitors(groundId, userId) } }
            }
        }
    }

    private suspend fun loadVisitors(groundId: String, userId: String?) {
        try {
            val rows = Supa.client.from("user_visits").select {
                filter { eq("ground_id", groundId) }
            }.decodeList<UserVisit>()
            _uiState.value = _uiState.value.copy(
                visitors = rows,
                myVisitId = rows.firstOrNull { it.userId == userId }?.id,
            )
        } catch (e: Exception) {
            // Leave visitors as-is on failure.
        }
    }

    fun checkIn(groundId: String, userId: String, notes: String) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isBusy = true)
            try {
                val trimmed = notes.trim()
                Supa.client.from("user_visits").insert(
                    UserVisitInsert(groundId = groundId, userId = userId, notes = trimmed.ifEmpty { null })
                )
                val evaluation = AchievementsService.evaluate(userId = userId)
                if (evaluation.unlocks.isNotEmpty()) {
                    _uiState.value = _uiState.value.copy(unlockedTitles = evaluation.unlocks.map { it.title })
                }
                loadVisitors(groundId, userId)
            } catch (e: Exception) {
                // Swallow -- the button re-enables and the user can retry.
            }
            _uiState.value = _uiState.value.copy(isBusy = false)
        }
    }

    fun undoCheckIn(groundId: String, visitId: String, userId: String?) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isBusy = true)
            try {
                Supa.client.from("user_visits").delete {
                    filter { eq("id", visitId) }
                }
                loadVisitors(groundId, userId)
            } catch (e: Exception) {
                // Swallow -- the button re-enables and the user can retry.
            }
            _uiState.value = _uiState.value.copy(isBusy = false)
        }
    }

    fun dismissUnlocks() {
        _uiState.value = _uiState.value.copy(unlockedTitles = null)
    }
}
