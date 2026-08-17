package ie.gaelgrounds.app.ui.profile

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import ie.gaelgrounds.app.data.Supa
import ie.gaelgrounds.app.data.model.AchievementDefinition
import ie.gaelgrounds.app.data.model.County
import ie.gaelgrounds.app.data.model.SupportedCountyUpdate
import ie.gaelgrounds.app.data.model.UserAchievement
import ie.gaelgrounds.app.data.model.UserAchievementPinnedUpdate
import ie.gaelgrounds.app.data.model.UserMatchAttendance
import ie.gaelgrounds.app.data.model.UserProfile
import ie.gaelgrounds.app.data.model.UserVisit
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.functions.functions
import io.github.jan.supabase.postgrest.from
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

const val MAX_PINNED_ACHIEVEMENTS = 4

data class AchievementRow(
    val userAchievementId: String,
    val achievementId: String,
    val title: String,
    val description: String,
    val icon: String?,
    val pinned: Boolean,
)

data class ProfileUiState(
    val isLoading: Boolean = true,
    val profile: UserProfile? = null,
    val counties: List<County> = emptyList(),
    val groundsVisited: Int = 0,
    val matchesAttended: Int = 0,
    val achievements: List<AchievementRow> = emptyList(),
    val pinLimitMessage: String? = null,
    val isDeleting: Boolean = false,
    val deleteError: String? = null,
)

/**
 * Simplified port of ios/GaelGrounds/Views/Profile/ProfileView.swift --
 * Best Game Ever and avatar upload aren't ported yet, see android/README.md.
 */
class ProfileViewModel : ViewModel() {
    private val _uiState = MutableStateFlow(ProfileUiState())
    val uiState: StateFlow<ProfileUiState> = _uiState.asStateFlow()

    fun load(userId: String?) {
        if (userId == null) return
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true)
            try {
                val profile = Supa.client.from("user_profiles").select {
                    filter { eq("id", userId) }
                    single()
                }.decodeSingle<UserProfile>()

                val counties = Supa.client.from("counties").select().decodeList<County>()

                val visits = Supa.client.from("user_visits").select {
                    filter { eq("user_id", userId) }
                }.decodeList<UserVisit>()
                val groundsVisited = visits.map { it.groundId }.toSet().size

                val attendance = Supa.client.from("user_match_attendance").select {
                    filter { eq("user_id", userId) }
                }.decodeList<UserMatchAttendance>()

                val defs = Supa.client.from("achievement_definitions").select().decodeList<AchievementDefinition>()
                val unlocked = Supa.client.from("user_achievements").select {
                    filter { eq("user_id", userId) }
                }.decodeList<UserAchievement>()
                val defById = defs.associateBy { it.id }
                val achievements = unlocked.mapNotNull { ua ->
                    val def = defById[ua.achievementId] ?: return@mapNotNull null
                    AchievementRow(ua.id, def.id, def.title, def.description, def.icon, ua.pinned)
                }.sortedByDescending { it.pinned }

                _uiState.value = _uiState.value.copy(
                    profile = profile,
                    counties = counties,
                    groundsVisited = groundsVisited,
                    matchesAttended = attendance.size,
                    achievements = achievements,
                    isLoading = false,
                )
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(isLoading = false)
            }
        }
    }

    fun setSupportedCounty(userId: String, countyId: String) {
        viewModelScope.launch {
            try {
                Supa.client.from("user_profiles").update(SupportedCountyUpdate(supportedCountyId = countyId)) {
                    filter { eq("id", userId) }
                }
                _uiState.value = _uiState.value.copy(
                    profile = _uiState.value.profile?.copy(supportedCountyId = countyId),
                )
            } catch (e: Exception) {
                // Swallow -- the picker just doesn't update on failure.
            }
        }
    }

    fun togglePinned(achievement: AchievementRow) {
        val currentlyPinned = _uiState.value.achievements.count { it.pinned }
        val newValue = !achievement.pinned
        if (newValue && currentlyPinned >= MAX_PINNED_ACHIEVEMENTS) {
            _uiState.value = _uiState.value.copy(
                pinLimitMessage = "You can only feature $MAX_PINNED_ACHIEVEMENTS achievements on your profile — unstar one first.",
            )
            return
        }

        _uiState.value = _uiState.value.copy(
            achievements = _uiState.value.achievements.map {
                if (it.userAchievementId == achievement.userAchievementId) it.copy(pinned = newValue) else it
            },
        )
        viewModelScope.launch {
            try {
                Supa.client.from("user_achievements").update(UserAchievementPinnedUpdate(pinned = newValue)) {
                    filter { eq("id", achievement.userAchievementId) }
                }
            } catch (e: Exception) {
                // Revert on failure.
                _uiState.value = _uiState.value.copy(
                    achievements = _uiState.value.achievements.map {
                        if (it.userAchievementId == achievement.userAchievementId) it.copy(pinned = achievement.pinned) else it
                    },
                )
            }
        }
    }

    fun dismissPinLimitMessage() {
        _uiState.value = _uiState.value.copy(pinLimitMessage = null)
    }

    fun deleteAccount(onDeleted: () -> Unit) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isDeleting = true, deleteError = null)
            try {
                Supa.client.functions.invoke("delete-account")
                Supa.client.auth.signOut()
                onDeleted()
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(deleteError = "Couldn't delete your account — try again.")
            }
            _uiState.value = _uiState.value.copy(isDeleting = false)
        }
    }
}
