package ie.gaelgrounds.app.data.service

import ie.gaelgrounds.app.data.Supa
import ie.gaelgrounds.app.data.model.Province
import ie.gaelgrounds.app.data.model.UserProfile
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.query.Columns
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Ranks premium profiles by matches attended / grounds visited, overall,
 * per-province, and for the signed-in user's supported county. Mirrors the
 * `load()` function in ios/GaelGrounds/Views/Leaderboard/LeaderboardView.swift,
 * with the "Most Bronze / Most Silver / Top Gold" achievement-tier tabs not
 * yet ported -- see android/README.md.
 */
object LeaderboardService {
    data class Entry(
        val id: String,
        val displayName: String,
        val matchCount: Int,
        val groundCount: Int,
        val provinceMatchCounts: Map<Province, Int>,
        val supportedCountyId: String?,
    )

    data class Result(
        val entries: List<Entry>,
        val supportedCountyId: String?,
        val supportedCountyName: String?,
        val friendIds: Set<String>,
    )

    @Serializable
    private data class AttendanceRecord(
        @SerialName("user_id") val userId: String,
        @SerialName("match_id") val matchId: String,
    )

    @Serializable
    private data class VisitGroundRef(
        @SerialName("user_id") val userId: String,
        @SerialName("ground_id") val groundId: String,
    )

    @Serializable
    private data class MatchTeamRef(
        val id: String,
        @SerialName("home_county_team_id") val homeCountyTeamId: String? = null,
        @SerialName("away_county_team_id") val awayCountyTeamId: String? = null,
    )

    @Serializable
    private data class CountyTeamRef(
        val id: String,
        @SerialName("county_id") val countyId: String,
    )

    @Serializable
    private data class CountyProvinceRef(
        val id: String,
        val name: String,
        val province: Province,
    )

    suspend fun fetch(currentUserId: String?): Result {
        val profiles = Supa.client.from("user_profiles").select().decodeList<UserProfile>()
        val attendance = Supa.client.from("user_match_attendance")
            .select(columns = Columns.raw("user_id, match_id"))
            .decodeList<AttendanceRecord>()
        val visits = Supa.client.from("user_visits")
            .select(columns = Columns.raw("user_id, ground_id"))
            .decodeList<VisitGroundRef>()
        val matchTeams = Supa.client.from("matches")
            .select(columns = Columns.raw("id, home_county_team_id, away_county_team_id"))
            .decodeList<MatchTeamRef>()
        val countyTeams = Supa.client.from("county_teams")
            .select(columns = Columns.raw("id, county_id"))
            .decodeList<CountyTeamRef>()
        val counties = Supa.client.from("counties")
            .select(columns = Columns.raw("id, name, province"))
            .decodeList<CountyProvinceRef>()

        val teamToCounty = countyTeams.associate { it.id to it.countyId }
        val countyToProvince = counties.associate { it.id to it.province }
        val countyNames = counties.associate { it.id to it.name }
        val currentProfile = profiles.firstOrNull { it.id == currentUserId }
        val supportedCountyId = currentProfile?.supportedCountyId
        val supportedCountyName = supportedCountyId?.let { countyNames[it] }

        val friendIds: Set<String> = if (currentUserId != null) {
            FriendService.fetchFriends(currentUserId).map { it.id }.toSet()
        } else {
            emptySet()
        }

        val matchProvinces = mutableMapOf<String, MutableSet<Province>>()
        for (m in matchTeams) {
            val provs = mutableSetOf<Province>()
            m.homeCountyTeamId?.let { teamToCounty[it] }?.let { countyToProvince[it] }?.let { provs.add(it) }
            m.awayCountyTeamId?.let { teamToCounty[it] }?.let { countyToProvince[it] }?.let { provs.add(it) }
            matchProvinces[m.id] = provs
        }

        val overallMatchCounts = mutableMapOf<String, Int>()
        val provinceCounts = Province.entries.associateWith { mutableMapOf<String, Int>() }
        for (a in attendance) {
            overallMatchCounts[a.userId] = (overallMatchCounts[a.userId] ?: 0) + 1
            for (p in matchProvinces[a.matchId].orEmpty()) {
                val map = provinceCounts.getValue(p)
                map[a.userId] = (map[a.userId] ?: 0) + 1
            }
        }

        // Distinct grounds per user, not raw visit rows -- checking into the
        // same ground for multiple matches is multiple rows but one ground.
        val groundIdsByUser = mutableMapOf<String, MutableSet<String>>()
        for (v in visits) groundIdsByUser.getOrPut(v.userId) { mutableSetOf() }.add(v.groundId)
        val groundCounts = groundIdsByUser.mapValues { it.value.size }

        val profileById = profiles.associateBy { it.id }
        val allIds = overallMatchCounts.keys + groundCounts.keys

        // Free accounts can browse the leaderboard but never appear on it --
        // only premium profiles are ranked.
        val entries = allIds.mapNotNull { uid ->
            val profile = profileById[uid] ?: return@mapNotNull null
            if (!profile.isPremium) return@mapNotNull null
            val provMap = Province.entries.associateWith { provinceCounts.getValue(it)[uid] ?: 0 }
            Entry(
                id = uid,
                displayName = profile.displayName ?: "Anonymous",
                matchCount = overallMatchCounts[uid] ?: 0,
                groundCount = groundCounts[uid] ?: 0,
                provinceMatchCounts = provMap,
                supportedCountyId = profile.supportedCountyId,
            )
        }

        return Result(entries, supportedCountyId, supportedCountyName, friendIds)
    }
}
