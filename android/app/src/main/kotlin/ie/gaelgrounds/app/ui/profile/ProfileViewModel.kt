package ie.gaelgrounds.app.ui.profile

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import ie.gaelgrounds.app.data.Supa
import ie.gaelgrounds.app.data.model.AchievementDefinition
import ie.gaelgrounds.app.data.model.County
import ie.gaelgrounds.app.data.model.Ground
import ie.gaelgrounds.app.data.model.Match
import ie.gaelgrounds.app.data.model.SupportedCountyUpdate
import ie.gaelgrounds.app.data.model.UserAchievement
import ie.gaelgrounds.app.data.model.UserAchievementPinnedUpdate
import ie.gaelgrounds.app.data.model.UserMatchAttendance
import ie.gaelgrounds.app.data.model.UserProfile
import ie.gaelgrounds.app.data.model.UserProfileAvatarUpdate
import ie.gaelgrounds.app.data.model.UserProfileBestMatchUpdate
import ie.gaelgrounds.app.data.model.UserProfileUpdate
import ie.gaelgrounds.app.data.model.UserVisit
import ie.gaelgrounds.app.data.service.AvatarService
import ie.gaelgrounds.app.data.service.MatchService
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.functions.functions
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.query.Order
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

data class AttendedMatchRow(
    val attendanceId: String,
    val matchId: String,
    val competition: String?,
    val playedAt: String,
    val homeName: String,
    val awayName: String,
    val groundName: String?,
)

data class VisitedGroundRow(
    val groundId: String,
    val name: String,
    val visitCount: Int,
)

data class ProfileUiState(
    val isLoading: Boolean = true,
    val profile: UserProfile? = null,
    val counties: List<County> = emptyList(),
    val groundsVisited: List<VisitedGroundRow> = emptyList(),
    val matchesAttended: List<AttendedMatchRow> = emptyList(),
    val achievements: List<AchievementRow> = emptyList(),
    val bestMatchId: String? = null,
    val displayName: String = "",
    val isSavingName: Boolean = false,
    val isUploadingAvatar: Boolean = false,
    val avatarError: String? = null,
    val pinLimitMessage: String? = null,
    val isDeleting: Boolean = false,
    val deleteError: String? = null,
) {
    val bestMatch: AttendedMatchRow?
        get() = matchesAttended.firstOrNull { it.matchId == bestMatchId }
}

/**
 * Mirrors ios/GaelGrounds/Views/Profile/ProfileView.swift -- realtime
 * auto-refresh and the locked-achievements browser aren't ported yet, see
 * android/README.md.
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

                val counties = Supa.client.from("counties").select {
                    order("name", Order.ASCENDING)
                }.decodeList<County>()

                val visits = Supa.client.from("user_visits").select {
                    filter { eq("user_id", userId) }
                    order("visited_at", Order.DESCENDING)
                }.decodeList<UserVisit>()
                val groundIds = visits.map { it.groundId }.distinct()
                val groundRows = if (groundIds.isEmpty()) {
                    emptyList()
                } else {
                    Supa.client.from("grounds").select {
                        filter { isIn("id", groundIds) }
                    }.decodeList<Ground>()
                }
                val groundNameById = groundRows.associate { it.id to it.name }
                val groundsVisited = visits.groupBy { it.groundId }.map { (groundId, visitsHere) ->
                    VisitedGroundRow(
                        groundId = groundId,
                        name = groundNameById[groundId] ?: "Unknown ground",
                        visitCount = visitsHere.size,
                    )
                }.sortedByDescending { it.visitCount }

                val attendance = Supa.client.from("user_match_attendance").select {
                    filter { eq("user_id", userId) }
                    order("created_at", Order.DESCENDING)
                }.decodeList<UserMatchAttendance>()
                val matchIds = attendance.map { it.matchId }.distinct()
                val matchesAttended = if (matchIds.isEmpty()) {
                    emptyList()
                } else {
                    val matchRows = Supa.client.from("matches").select {
                        filter { isIn("id", matchIds) }
                    }.decodeList<Match>()
                    val summaries = MatchService.resolveSummaries(matchRows)
                    val summaryById = summaries.associateBy { it.id }
                    attendance.mapNotNull { a ->
                        val s = summaryById[a.matchId] ?: return@mapNotNull null
                        val playedAt = s.playedAt ?: return@mapNotNull null
                        AttendedMatchRow(
                            attendanceId = a.id,
                            matchId = a.matchId,
                            competition = s.competition,
                            playedAt = playedAt,
                            homeName = s.homeName,
                            awayName = s.awayName,
                            groundName = s.groundName,
                        )
                    }
                }

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
                    matchesAttended = matchesAttended,
                    achievements = achievements,
                    bestMatchId = profile.bestMatchId,
                    displayName = profile.displayName ?: "",
                    isLoading = false,
                )
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(isLoading = false)
            }
        }
    }

    fun setDisplayName(name: String) {
        _uiState.value = _uiState.value.copy(displayName = name)
    }

    fun saveDisplayName(userId: String) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isSavingName = true)
            try {
                val trimmed = _uiState.value.displayName.trim()
                Supa.client.from("user_profiles").update(UserProfileUpdate(displayName = trimmed)) {
                    filter { eq("id", userId) }
                }
                _uiState.value = _uiState.value.copy(profile = _uiState.value.profile?.copy(displayName = trimmed))
            } catch (e: Exception) {
                // Swallow -- the field just doesn't persist on failure.
            }
            _uiState.value = _uiState.value.copy(isSavingName = false)
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

    fun uploadAvatar(userId: String, jpegBytes: ByteArray) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isUploadingAvatar = true, avatarError = null)
            try {
                val url = AvatarService.upload(jpegBytes, userId)
                Supa.client.from("user_profiles").update(UserProfileAvatarUpdate(avatarUrl = url)) {
                    filter { eq("id", userId) }
                }
                _uiState.value = _uiState.value.copy(profile = _uiState.value.profile?.copy(avatarUrl = url))
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(avatarError = "Couldn't upload that photo -- try again.")
            }
            _uiState.value = _uiState.value.copy(isUploadingAvatar = false)
        }
    }

    fun toggleBestGame(userId: String, matchId: String) {
        val previous = _uiState.value.bestMatchId
        val newValue = if (previous == matchId) null else matchId
        _uiState.value = _uiState.value.copy(bestMatchId = newValue)
        viewModelScope.launch {
            try {
                Supa.client.from("user_profiles").update(UserProfileBestMatchUpdate(bestMatchId = newValue)) {
                    filter { eq("id", userId) }
                }
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(bestMatchId = previous)
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
