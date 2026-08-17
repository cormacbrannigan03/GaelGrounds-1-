package ie.gaelgrounds.app.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** Mirrors ios/GaelGrounds/Models/Enums.swift. */
@Serializable
enum class Province {
    @SerialName("Connacht") CONNACHT,
    @SerialName("Leinster") LEINSTER,
    @SerialName("Munster") MUNSTER,
    @SerialName("Ulster") ULSTER,
}

@Serializable
enum class SportCode {
    @SerialName("gaelic_football") GAELIC_FOOTBALL,
    @SerialName("hurling") HURLING,
    @SerialName("camogie") CAMOGIE,
    @SerialName("ladies_football") LADIES_FOOTBALL;

    val label: String
        get() = when (this) {
            GAELIC_FOOTBALL -> "Gaelic Football"
            HURLING -> "Hurling"
            CAMOGIE -> "Camogie"
            LADIES_FOOTBALL -> "Ladies' Football"
        }

    val icon: String
        get() = when (this) {
            GAELIC_FOOTBALL -> "🏐"
            HURLING -> "🏑"
            CAMOGIE -> "🏑"
            LADIES_FOOTBALL -> "🏐"
        }
}

@Serializable
enum class MatchType {
    @SerialName("county") COUNTY,
    @SerialName("club") CLUB,
}

@Serializable
enum class HonourType {
    @SerialName("all_ireland") ALL_IRELAND,
    @SerialName("provincial") PROVINCIAL,
    @SerialName("league") LEAGUE,
    @SerialName("county_championship") COUNTY_CHAMPIONSHIP,
    @SerialName("club_all_ireland") CLUB_ALL_IRELAND,
}

@Serializable
enum class TeamType {
    @SerialName("county") COUNTY,
    @SerialName("club") CLUB,
}

/**
 * This app does not track live in-play scores -- a match is either an
 * upcoming fixture (no score) or a completed result (final score), so
 * there is deliberately no "live" status here. Set server-side by the
 * sync-matches ingestion pipeline (or defaulted to SCHEDULED for
 * hand-seeded rows). Mirrors ios/GaelGrounds/Models/Enums.swift exactly.
 */
@Serializable
enum class MatchStatus {
    @SerialName("scheduled") SCHEDULED,
    @SerialName("postponed") POSTPONED,
    @SerialName("cancelled") CANCELLED,
    @SerialName("completed") COMPLETED,
}

@Serializable
enum class MatchWinner {
    @SerialName("home") HOME,
    @SerialName("away") AWAY,
    @SerialName("draw") DRAW,
}

@Serializable
enum class CompetitionType {
    @SerialName("league") LEAGUE,
    @SerialName("championship") CHAMPIONSHIP,
    @SerialName("provincial") PROVINCIAL,
    @SerialName("tier_cup") TIER_CUP,
}
