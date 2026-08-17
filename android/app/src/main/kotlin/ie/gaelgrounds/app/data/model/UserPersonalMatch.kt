package ie.gaelgrounds.app.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.time.Instant
import java.time.format.DateTimeParseException

/** Mirrors ios/GaelGrounds/Models/UserPersonalMatch.swift. */
@Serializable
data class UserPersonalMatch(
    val id: String,
    @SerialName("user_id") val userId: String,
    @SerialName("home_team") val homeTeam: String,
    @SerialName("away_team") val awayTeam: String,
    val competition: String? = null,
    val round: String? = null,
    val venue: String? = null,
    @SerialName("played_at") val playedAt: String,
    @SerialName("home_score") val homeScore: String? = null,
    @SerialName("away_score") val awayScore: String? = null,
    @SerialName("created_at") val createdAt: String? = null,
) {
    val hasScore: Boolean
        get() = homeScore != null && awayScore != null

    val isPast: Boolean
        get() = try {
            Instant.parse(playedAt).isBefore(Instant.now())
        } catch (e: DateTimeParseException) {
            false
        }
}

@Serializable
data class UserPersonalMatchInsert(
    @SerialName("user_id") val userId: String,
    @SerialName("home_team") val homeTeam: String,
    @SerialName("away_team") val awayTeam: String,
    val competition: String? = null,
    val round: String? = null,
    val venue: String? = null,
    @SerialName("played_at") val playedAt: String,
    @SerialName("home_score") val homeScore: String? = null,
    @SerialName("away_score") val awayScore: String? = null,
)
