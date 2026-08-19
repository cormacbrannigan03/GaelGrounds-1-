package ie.gaelgrounds.app.ui.leaderboard

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import ie.gaelgrounds.app.data.model.AchievementTier
import ie.gaelgrounds.app.data.model.Province
import ie.gaelgrounds.app.data.service.LeaderboardService
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

enum class LeaderboardTab { OVERALL, MY_COUNTY, ULSTER, MUNSTER, LEINSTER, CONNACHT, BRONZE, SILVER, GOLD }
enum class SortKey { MATCHES, GROUNDS }
enum class Scope { EVERYONE, FRIENDS }

val tabProvince = mapOf(
    LeaderboardTab.ULSTER to Province.ULSTER,
    LeaderboardTab.MUNSTER to Province.MUNSTER,
    LeaderboardTab.LEINSTER to Province.LEINSTER,
    LeaderboardTab.CONNACHT to Province.CONNACHT,
)

private val tabTier = mapOf(
    LeaderboardTab.BRONZE to AchievementTier.BRONZE,
    LeaderboardTab.SILVER to AchievementTier.SILVER,
    LeaderboardTab.GOLD to AchievementTier.GOLD,
)

data class LeaderboardUiState(
    val isLoading: Boolean = true,
    val result: LeaderboardService.Result = LeaderboardService.Result(emptyList(), null, null, emptySet()),
    val activeTab: LeaderboardTab = LeaderboardTab.OVERALL,
    val sortBy: SortKey = SortKey.MATCHES,
    val scope: Scope = Scope.EVERYONE,
    val currentUserId: String? = null,
) {
    private val scoped: List<LeaderboardService.Entry>
        get() {
            if (scope != Scope.FRIENDS) return result.entries
            return result.entries.filter { it.id == currentUserId || result.friendIds.contains(it.id) }
        }

    private fun sortedOverall(entries: List<LeaderboardService.Entry>): List<LeaderboardService.Entry> {
        return when (sortBy) {
            SortKey.MATCHES -> entries.sortedWith(compareByDescending<LeaderboardService.Entry> { it.matchCount }.thenByDescending { it.groundCount })
            SortKey.GROUNDS -> entries.sortedWith(compareByDescending<LeaderboardService.Entry> { it.groundCount }.thenByDescending { it.matchCount })
        }
    }

    val displayed: List<LeaderboardService.Entry>
        get() {
            if (activeTab == LeaderboardTab.MY_COUNTY) {
                val countyId = result.supportedCountyId ?: return emptyList()
                return sortedOverall(scoped.filter { it.supportedCountyId == countyId })
            }
            val province = tabProvince[activeTab]
            if (province != null) {
                return scoped
                    .filter { (it.provinceMatchCounts[province] ?: 0) > 0 }
                    .sortedByDescending { it.provinceMatchCounts[province] ?: 0 }
            }
            val tier = tabTier[activeTab]
            if (tier != null) {
                return scoped
                    .filter { (it.tierCounts[tier] ?: 0) > 0 }
                    .sortedByDescending { it.tierCounts[tier] ?: 0 }
            }
            return sortedOverall(scoped)
        }
}

/** Port of ios/GaelGrounds/Views/Leaderboard/LeaderboardView.swift. */
class LeaderboardViewModel : ViewModel() {
    private val _uiState = MutableStateFlow(LeaderboardUiState())
    val uiState: StateFlow<LeaderboardUiState> = _uiState.asStateFlow()

    fun load(userId: String?) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, currentUserId = userId)
            try {
                val result = LeaderboardService.fetch(userId)
                _uiState.value = _uiState.value.copy(result = result, isLoading = false)
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(isLoading = false)
            }
        }
    }

    fun setTab(tab: LeaderboardTab) { _uiState.value = _uiState.value.copy(activeTab = tab) }
    fun setSort(sort: SortKey) { _uiState.value = _uiState.value.copy(sortBy = sort) }
    fun setScope(scope: Scope) { _uiState.value = _uiState.value.copy(scope = scope) }
}
