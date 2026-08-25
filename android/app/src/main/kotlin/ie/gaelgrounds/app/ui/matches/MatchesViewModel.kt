package ie.gaelgrounds.app.ui.matches

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import ie.gaelgrounds.app.data.model.MatchSummary
import ie.gaelgrounds.app.data.model.SportCode
import ie.gaelgrounds.app.data.model.UserPersonalMatch
import ie.gaelgrounds.app.data.model.UserPersonalMatchInsert
import ie.gaelgrounds.app.data.service.MatchService
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.ZoneId

enum class MatchesTab { UPCOMING, FIXTURES, RESULTS }

data class MonthGroup(val month: Int, val matches: List<MatchSummary>)
data class YearGroup(val year: Int, val months: List<MonthGroup>)

data class MatchesUiState(
    val isLoading: Boolean = true,
    val allMatches: List<MatchSummary> = emptyList(),
    val personalMatches: List<UserPersonalMatch> = emptyList(),
    val selectedSport: SportCode = SportCode.GAELIC_FOOTBALL,
    val tab: MatchesTab = MatchesTab.UPCOMING,
    val search: String = "",
    val selectedCounty: String = "",
    val selectedCompetition: String = "",
    val selectedVenue: String = "",
    val isAddingMatch: Boolean = false,
    val addMatchError: String? = null,
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

    private val filtered: List<MatchSummary>
        get() = searchFiltered.filter { m ->
            (selectedCounty.isEmpty() || m.homeName == selectedCounty || m.awayName == selectedCounty) &&
                (selectedCompetition.isEmpty() || matchesCompetition(m.competition)) &&
                (selectedVenue.isEmpty() || m.groundName == selectedVenue)
        }

    private fun matchesCompetition(competition: String?): Boolean {
        if (umbrellaCompetitions.contains(selectedCompetition)) {
            return competition?.startsWith(selectedCompetition) == true
        }
        return competition == selectedCompetition
    }

    val upcomingList: List<MatchSummary>
        get() = filtered.filter { it.isUpcoming || it.isLive }.sortedBy { it.playedAt ?: "9999" }

    val resultsList: List<MatchSummary>
        get() = filtered.filter { it.isPast }.sortedByDescending { it.playedAt ?: "" }

    val yearGroups: List<YearGroup>
        get() = resultsList
            .mapNotNull { m -> m.playedAt?.let { it to m } }
            .groupBy { (playedAt, _) -> yearOf(playedAt) }
            .map { (year, pairs) ->
                val months = pairs
                    .groupBy { (playedAt, _) -> monthOf(playedAt) }
                    .map { (month, monthPairs) ->
                        MonthGroup(
                            month = month,
                            matches = monthPairs.map { it.second }.sortedByDescending { it.playedAt ?: "" },
                        )
                    }
                    .sortedByDescending { it.month }
                YearGroup(year = year, months = months)
            }
            .sortedByDescending { it.year }

    /** Results with no confirmed date -- mirrors iOS's `undatedResults`, shown in their own section instead of silently dropped from `yearGroups`. */
    val undatedResults: List<MatchSummary>
        get() = resultsList
            .filter { it.playedAt == null }
            .sortedWith(compareBy({ it.competition ?: "" }, { it.homeName }, { it.awayName }))

    val filteredPersonalMatches: List<UserPersonalMatch>
        get() {
            val q = search.trim().lowercase()
            return personalMatches.filter { m ->
                val matchesSearch = q.isEmpty() ||
                    m.homeTeam.lowercase().contains(q) ||
                    m.awayTeam.lowercase().contains(q) ||
                    (m.competition ?: "").lowercase().contains(q)
                val matchesCounty = selectedCounty.isEmpty() || m.homeTeam == selectedCounty || m.awayTeam == selectedCounty
                val matchesVenue = selectedVenue.isEmpty() || m.venue == selectedVenue
                matchesSearch && matchesCounty && matchesVenue
            }
        }

    val countyOptions: List<String>
        get() = (sportFiltered.flatMap { listOf(it.homeName, it.awayName) } + personalMatches.flatMap { listOf(it.homeTeam, it.awayTeam) })
            .distinct().sorted()

    val competitionOptions: List<String>
        get() = (sportFiltered.mapNotNull { it.competition } + personalMatches.mapNotNull { it.competition }).distinct().sorted()

    val venueOptions: List<String>
        get() = (sportFiltered.mapNotNull { it.groundName } + personalMatches.mapNotNull { it.venue }).distinct().sorted()

    val displayedList: List<MatchSummary>
        get() = when (tab) {
            MatchesTab.UPCOMING, MatchesTab.FIXTURES -> upcomingList
            MatchesTab.RESULTS -> resultsList
        }

    companion object {
        // National Football/Hurling League matches tag divisions separately
        // but promotion-relegation/final rounds just use the bare league
        // name -- filtering by the bare name should catch every division.
        private val umbrellaCompetitions = setOf("National Football League", "National Hurling League")

        private fun yearOf(iso: String): Int = try {
            Instant.parse(iso).atZone(ZoneId.systemDefault()).year
        } catch (e: Exception) {
            0
        }

        private fun monthOf(iso: String): Int = try {
            Instant.parse(iso).atZone(ZoneId.systemDefault()).monthValue
        } catch (e: Exception) {
            0
        }
    }
}

/** Port of ios/GaelGrounds/Views/Matches/MatchesView.swift's Results tab -- year groups sub-grouped by month, most-recent-first, matching `yearGroups` in the Swift view. */
class MatchesViewModel : ViewModel() {
    private val _uiState = MutableStateFlow(MatchesUiState())
    val uiState: StateFlow<MatchesUiState> = _uiState.asStateFlow()

    fun load(userId: String?) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true)
            try {
                val rows = MatchService.fetchAll()
                val summaries = MatchService.resolveSummaries(rows)
                _uiState.value = _uiState.value.copy(allMatches = summaries)
            } catch (e: Exception) {
                // Leave allMatches as-is; public fixtures failing isn't fatal.
            }
            if (userId != null) {
                try {
                    val personal = MatchService.fetchPersonalMatches(userId)
                    _uiState.value = _uiState.value.copy(personalMatches = personal)
                } catch (e: Exception) {
                    // Leave personalMatches as-is.
                }
            }
            _uiState.value = _uiState.value.copy(isLoading = false)
        }
    }

    fun setSport(sport: SportCode) { _uiState.value = _uiState.value.copy(selectedSport = sport) }
    fun setTab(tab: MatchesTab) { _uiState.value = _uiState.value.copy(tab = tab) }
    fun setSearch(query: String) { _uiState.value = _uiState.value.copy(search = query) }
    fun setCountyFilter(value: String) { _uiState.value = _uiState.value.copy(selectedCounty = value) }
    fun setCompetitionFilter(value: String) { _uiState.value = _uiState.value.copy(selectedCompetition = value) }
    fun setVenueFilter(value: String) { _uiState.value = _uiState.value.copy(selectedVenue = value) }
    fun clearFilters() {
        _uiState.value = _uiState.value.copy(selectedCounty = "", selectedCompetition = "", selectedVenue = "")
    }

    fun addPersonalMatch(
        userId: String,
        homeTeam: String,
        awayTeam: String,
        competition: String,
        round: String,
        venue: String,
        playedAtIso: String,
        homeScore: String,
        awayScore: String,
    ) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isAddingMatch = true, addMatchError = null)
            try {
                MatchService.insertPersonalMatch(
                    UserPersonalMatchInsert(
                        userId = userId,
                        homeTeam = homeTeam.trim(),
                        awayTeam = awayTeam.trim(),
                        competition = competition.trim().ifEmpty { null },
                        round = round.trim().ifEmpty { null },
                        venue = venue.trim().ifEmpty { null },
                        playedAt = playedAtIso,
                        homeScore = homeScore.trim().ifEmpty { null },
                        awayScore = awayScore.trim().ifEmpty { null },
                    ),
                )
                val personal = MatchService.fetchPersonalMatches(userId)
                _uiState.value = _uiState.value.copy(personalMatches = personal, isAddingMatch = false)
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(isAddingMatch = false, addMatchError = "Couldn't save that match — try again.")
            }
        }
    }

    fun deletePersonalMatch(userId: String, matchId: String) {
        viewModelScope.launch {
            try {
                MatchService.deletePersonalMatch(matchId)
                val personal = MatchService.fetchPersonalMatches(userId)
                _uiState.value = _uiState.value.copy(personalMatches = personal)
            } catch (e: Exception) {
                // Swallow -- the list just doesn't update on failure.
            }
        }
    }

    fun dismissAddMatchError() {
        _uiState.value = _uiState.value.copy(addMatchError = null)
    }
}

fun nowAsIso(): String = Instant.now().toString()
