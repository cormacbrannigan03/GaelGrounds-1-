package ie.gaelgrounds.app.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** Mirrors ios/GaelGrounds/Models/County.swift. */
@Serializable
data class County(
    val id: String,
    val name: String,
    val province: Province,
    @SerialName("crest_url") val crestUrl: String? = null,
    @SerialName("primary_colour") val primaryColour: String? = null,
    @SerialName("secondary_colour") val secondaryColour: String? = null,
    @SerialName("created_at") val createdAt: String? = null,
    val nickname: String? = null,
) {
    val colours: CountyColours?
        get() {
            val primary = primaryColour ?: return null
            val secondary = secondaryColour ?: return null
            return CountyColours(primary, secondary)
        }
}

/**
 * A county's two jersey colours, hex strings straight from the database
 * (e.g. "#00703C"). Used to wash match banners with each side's colours.
 */
data class CountyColours(val primary: String, val secondary: String)

@Serializable
data class CountyTeam(
    val id: String,
    @SerialName("county_id") val countyId: String,
    @SerialName("sport_code") val sportCode: SportCode,
    @SerialName("founded_year") val foundedYear: Int? = null,
    val history: String? = null,
    @SerialName("current_manager") val currentManager: String? = null,
    @SerialName("created_at") val createdAt: String? = null,
)
