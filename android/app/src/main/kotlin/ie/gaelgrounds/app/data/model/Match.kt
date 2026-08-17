package ie.gaelgrounds.app.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.time.Instant
import java.time.format.DateTimeParseException

/** Mirrors ios/GaelGrounds/Models/Match.swift. */
@Serializable
data class Match(
    val id: String,
    @SerialName("match_type") val matchType: MatchType,
    @SerialName("home_county_team_id") val homeCountyTeamId: String? = null,
    @SerialName("away_county_team_id") val awayCountyTeamId: String? = null,
    @SerialName("home_club_id") val homeClubId: String? = null,
    @SerialName("away_club_id") val awayClubId: String? = null,
    @SerialName("ground_id") val groundId: String? = null,
    val competition: String? = null,
    val round: String? = null,
    @SerialName("played_at") val playedAt: String? = null,
    @SerialName("home_score") val homeScore: String? = null,
    @SerialName("away_score") val awayScore: String? = null,
    @SerialName("created_at") val createdAt: String? = null,
) {
    val hasScore: Boolean
        get() = homeScore != null && awayScore != null

    private val playedAtInstant: Instant?
        get() = playedAt?.let {
            try {
                Instant.parse(it)
            } catch (e: DateTimeParseException) {
                null
            }
        }

    /** A match counts as "live" if it kicked off in the last ~2.5 hours and hasn't been scored yet. */
    val isLive: Boolean
        get() {
            if (hasScore) return false
            val played = playedAtInstant ?: return false
            val elapsedSeconds = Instant.now().epochSecond - played.epochSecond
            return elapsedSeconds in 0..(2.5 * 60 * 60).toLong()
        }

    val isUpcoming: Boolean
        get() {
            if (hasScore) return false
            val played = playedAtInstant ?: return false
            return played.isAfter(Instant.now())
        }

    /**
     * True once the fixture is in the past (whether or not a score was recorded) --
     * used to switch check-in copy to "log that you were there" language.
     */
    val isPast: Boolean
        get() {
            val played = playedAtInstant ?: return hasScore
            return hasScore || (!isLive && played.isBefore(Instant.now()))
        }
}
