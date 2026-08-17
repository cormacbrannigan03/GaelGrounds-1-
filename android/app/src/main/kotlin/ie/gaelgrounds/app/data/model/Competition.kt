package ie.gaelgrounds.app.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** Mirrors ios/GaelGrounds/Models/Competition.swift. */
@Serializable
data class Competition(
    val id: String,
    val code: String,
    val name: String,
    @SerialName("sport_code") val sportCode: SportCode,
    @SerialName("competition_type") val competitionType: CompetitionType,
    val tier: Int,
    val province: Province? = null,
    @SerialName("created_at") val createdAt: String? = null,
)

/** Mirrors ios/GaelGrounds/Models/Honour.swift. */
@Serializable
data class Honour(
    val id: String,
    @SerialName("team_type") val teamType: TeamType,
    @SerialName("county_team_id") val countyTeamId: String? = null,
    @SerialName("club_id") val clubId: String? = null,
    @SerialName("honour_type") val honourType: HonourType,
    @SerialName("competition_name") val competitionName: String,
    val year: Int,
)
