package ie.gaelgrounds.app.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// Mirrors the update payload structs in ios/GaelGrounds/Models/UserData.swift --
// small Encodable shapes used for targeted .update() calls rather than
// resending the whole row.

@Serializable
data class UserProfilePremiumUpdate(
    @SerialName("is_premium") val isPremium: Boolean,
    @SerialName("premium_expires_at") val premiumExpiresAt: String?,
)

@Serializable
data class UserProfileUpdate(
    @SerialName("display_name") val displayName: String,
)

@Serializable
data class UserProfileAvatarUpdate(
    @SerialName("avatar_url") val avatarUrl: String,
)

@Serializable
data class UserProfileBestMatchUpdate(
    @SerialName("best_match_id") val bestMatchId: String?,
)

@Serializable
data class SupportedCountyUpdate(
    @SerialName("supported_county_id") val supportedCountyId: String,
)

@Serializable
data class UserVisit(
    val id: String,
    @SerialName("user_id") val userId: String,
    @SerialName("ground_id") val groundId: String,
    @SerialName("visited_at") val visitedAt: String,
    val notes: String? = null,
    @SerialName("photo_urls") val photoUrls: List<String> = emptyList(),
    @SerialName("created_at") val createdAt: String? = null,
)

@Serializable
data class UserVisitInsert(
    @SerialName("ground_id") val groundId: String,
    @SerialName("user_id") val userId: String,
    val notes: String? = null,
    @SerialName("photo_urls") val photoUrls: List<String>? = null,
)

@Serializable
data class UserVisitPhotoUpdate(
    @SerialName("photo_urls") val photoUrls: List<String>,
)

@Serializable
data class UserMatchAttendance(
    val id: String,
    @SerialName("user_id") val userId: String,
    @SerialName("match_id") val matchId: String,
    val notes: String? = null,
    @SerialName("photo_urls") val photoUrls: List<String> = emptyList(),
    @SerialName("created_at") val createdAt: String? = null,
)

@Serializable
data class UserMatchAttendanceInsert(
    @SerialName("match_id") val matchId: String,
    @SerialName("user_id") val userId: String,
)

@Serializable
data class AchievementRuleParams(
    val count: Int? = null,
    @SerialName("county_id") val countyId: String? = null,
    @SerialName("sport_code") val sportCode: SportCode? = null,
    val province: Province? = null,
)

@Serializable
data class AchievementDefinition(
    val id: String,
    val code: String,
    val title: String,
    val description: String,
    val icon: String? = null,
    @SerialName("rule_type") val ruleType: String,
    @SerialName("rule_params") val ruleParams: AchievementRuleParams,
    @SerialName("created_at") val createdAt: String? = null,
)

data class HomeAchievementKey(val countyId: String, val sportCode: SportCode)

data class AchievementUnlock(
    val id: String,
    val title: String,
    val description: String,
    val icon: String?,
    val tier: AchievementTier?,
)

enum class AchievementTier {
    STANDARD, BRONZE, SILVER, GOLD;

    val label: String
        get() = when (this) {
            STANDARD -> ""
            BRONZE -> "Bronze"
            SILVER -> "Silver"
            GOLD -> "Gold"
        }

    companion object {
        fun forHomeMatchCount(count: Int): AchievementTier = when {
            count >= 50 -> GOLD
            count >= 25 -> SILVER
            count >= 10 -> BRONZE
            else -> STANDARD
        }
    }
}

data class AchievementProgress(
    val title: String,
    val message: String,
    val icon: String?,
    val tier: AchievementTier,
    val homeGameCount: Int,
)

data class AchievementEvaluation(
    val unlocks: List<AchievementUnlock>,
    val progress: AchievementProgress?,
)

@Serializable
data class UserAchievement(
    val id: String,
    @SerialName("user_id") val userId: String,
    @SerialName("achievement_id") val achievementId: String,
    @SerialName("unlocked_at") val unlockedAt: String,
    val pinned: Boolean = false,
)

@Serializable
data class UserAchievementInsert(
    @SerialName("achievement_id") val achievementId: String,
    @SerialName("user_id") val userId: String,
)

@Serializable
data class UserAchievementPinnedUpdate(
    val pinned: Boolean,
)

@Serializable
data class Friendship(
    val id: String,
    @SerialName("requester_id") val requesterId: String,
    @SerialName("addressee_id") val addresseeId: String,
    val status: String,
    @SerialName("created_at") val createdAt: String? = null,
)

@Serializable
data class FriendshipInsert(
    @SerialName("requester_id") val requesterId: String,
    @SerialName("addressee_id") val addresseeId: String,
)

@Serializable
data class FriendshipStatusUpdate(
    val status: String,
)

@Serializable
data class DevicePushTokenUpsert(
    @SerialName("user_id") val userId: String,
    val token: String,
    @SerialName("updated_at") val updatedAt: String,
)

@Serializable
data class MatchReport(
    val id: String,
    @SerialName("match_id") val matchId: String,
    @SerialName("user_id") val userId: String,
    @SerialName("issue_types") val issueTypes: List<String>,
    val details: String? = null,
    val status: String,
    @SerialName("created_at") val createdAt: String? = null,
)

@Serializable
data class MatchReportInsert(
    @SerialName("match_id") val matchId: String,
    @SerialName("user_id") val userId: String,
    @SerialName("issue_types") val issueTypes: List<String>,
    val details: String? = null,
)
