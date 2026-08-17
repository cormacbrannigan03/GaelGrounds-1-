package ie.gaelgrounds.app.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** Mirrors the `user_profiles` table (see src/lib/database.types.ts / iOS UserData.swift). */
@Serializable
data class UserProfile(
    val id: String,
    @SerialName("display_name") val displayName: String? = null,
    @SerialName("avatar_url") val avatarUrl: String? = null,
    @SerialName("supported_county_id") val supportedCountyId: String? = null,
    @SerialName("is_premium") val isPremium: Boolean = false,
    @SerialName("premium_expires_at") val premiumExpiresAt: String? = null,
    @SerialName("best_match_id") val bestMatchId: String? = null,
    @SerialName("created_at") val createdAt: String? = null,
)
