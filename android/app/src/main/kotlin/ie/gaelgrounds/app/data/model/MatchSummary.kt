package ie.gaelgrounds.app.data.model

import java.time.Instant
import java.time.format.DateTimeParseException

/**
 * A `Match` row with its team/ground names already resolved -- the shape
 * every match-listing screen in the app actually renders.
 * Mirrors ios/GaelGrounds/Models/MatchSummary.swift.
 */
data class MatchSummary(
    val id: String,
    val competition: String?,
    val playedAt: String?,
    val homeScore: String?,
    val awayScore: String?,
    val homeName: String,
    val awayName: String,
    val sportCode: SportCode,
    val groundId: String?,
    val groundName: String?,
    val round: String?,
    val attendeeCount: Int,
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

    val isPast: Boolean
        get() {
            val played = playedAtInstant ?: return true
            return hasScore || (!isLive && played.isBefore(Instant.now()))
        }

    val isFinal: Boolean
        get() {
            val text = "${competition.orEmpty()} ${round.orEmpty()}".lowercase()
            return text.contains("final")
        }

    /**
     * Returns the winning team name, or null if no score or a draw.
     * Parses "goals-points" scoring format where a goal = 3 points.
     */
    val winnerName: String?
        get() {
            if (!hasScore) return null
            val home = parseScore(homeScore) ?: return null
            val away = parseScore(awayScore) ?: return null
            return when {
                home > away -> homeName
                away > home -> awayName
                else -> null
            }
        }

    private fun parseScore(score: String?): Int? {
        val parts = score?.split("-") ?: return null
        if (parts.size != 2) return 0
        val goals = parts[0].trim().toIntOrNull() ?: return 0
        val points = parts[1].trim().toIntOrNull() ?: return 0
        return goals * 3 + points
    }
}
