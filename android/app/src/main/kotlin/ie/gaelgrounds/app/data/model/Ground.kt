package ie.gaelgrounds.app.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** Mirrors ios/GaelGrounds/Models/Ground.swift. */
@Serializable
data class Ground(
    val id: String,
    val name: String,
    @SerialName("county_id") val countyId: String,
    val latitude: Double,
    val longitude: Double,
    val capacity: Int? = null,
    @SerialName("photo_url") val photoUrl: String? = null,
    @SerialName("created_at") val createdAt: String? = null,
    @SerialName("is_primary") val isPrimary: Boolean = false,
)

/**
 * A `Ground` row with its county name resolved and the signed-in user's
 * visited status already joined in -- the shape GroundsScreen renders.
 * Mirrors `GroundSummary` in ios/GaelGrounds/Models/MatchSummary.swift.
 */
data class GroundSummary(
    val id: String,
    val name: String,
    val countyName: String,
    val capacity: Int?,
    val visited: Boolean,
    val latitude: Double,
    val longitude: Double,
    val isPrimary: Boolean,
)
