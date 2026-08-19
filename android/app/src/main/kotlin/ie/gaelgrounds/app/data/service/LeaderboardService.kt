package ie.gaelgrounds.app.data.service

import ie.gaelgrounds.app.data.Supa
import ie.gaelgrounds.app.data.model.AchievementDefinition
import ie.gaelgrounds.app.data.model.AchievementTier
import ie.gaelgrounds.app.data.model.Province
import ie.gaelgrounds.app.data.model.SportCode
import ie.gaelgrounds.app.data.model.UserAchievement
import ie.gaelgrounds.app.data.model.UserProfile
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.query.Columns
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Ranks premium profiles by matches attended / grounds visited, overall,
 * per-province, for the signed-in user's supported county, and by
 * achievement tier (Most Bronze / Most Silver / Top Gold). Mirrors the
 * `load()` function in ios/GaelGrounds/Views/Leaderboard/LeaderboardView.swift.
 */
object LeaderboardService {
    data class Entry(
        val id: String,
        val displayName: String,
        val matchCount: Int,
        val groundCount: Int,
        val provinceMatchCounts: Map<Province, Int>,
        val tierCounts: Map<AchievementTier, Int>,
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
        @SerialName("ground_id") val groundId: String? = null,
    )

    @Serializable
    private data class CountyTeamRef(
        val id: String,
        @SerialName("county_id") val countyId: String,
        @SerialName("sport_code") val sportCode: SportCode,
    )

    @Serializable
    private data class CountyProvinceRef(
        val id: String,
        val name: String,
        val province: Province,
    )

    @Serializable
    private data class GroundCountyRef(
        val id: String,
        @SerialName("county_id") val countyId: String,
    )

    @Serializable
    private data class UserAchievementRef(
        @SerialName("user_id") val userId: String,
        @SerialName("achievement_id") val achievementId: String,
    )

    private data class TierKey(val userId: String, val countyId: String, val sportCode: SportCode)

    suspend fun fetch(currentUserId: String?): Result {
        val profiles = Supa.client.from("user_profiles").select().decodeList<UserProfile>()
        val attendance = Supa.client.from("user_match_attendance")
            .select(columns = Columns.raw("user_id, match_id"))
            .decodeList<AttendanceRecord>()
        val visits = Supa.client.from("user_visits")
            .select(columns = Columns.raw("user_id, ground_id"))
            .decodeList<VisitGroundRef>()
        val matchTeams = Supa.client.from("matches")
            .select(columns = Columns.raw("id, home_county_team_id, away_county_team_id, ground_id"))
            .decodeList<MatchTeamRef>()
        val countyTeams = Supa.client.from("county_teams")
            .select(columns = Columns.raw("id, county_id, sport_code"))
            .decodeList<CountyTeamRef>()
        val counties = Supa.client.from("counties")
            .select(columns = Columns.raw("id, name, province"))
            .decodeList<CountyProvinceRef>()
        val grounds = Supa.client.from("grounds")
            .select(columns = Columns.raw("id, county_id"))
            .decodeList<GroundCountyRef>()
        val userAchievements = Supa.client.from("user_achievements")
            .select(columns = Columns.raw("user_id, achievement_id"))
            .decodeList<UserAchievementRef>()
        val achievementDefs = Supa.client.from("achievement_definitions").select().decodeList<AchievementDefinition>()

        val teamToCounty = countyTeams.associate { it.id to it.countyId }
        val teamToSport = countyTeams.associate { it.id to it.sportCode }
        val groundToCounty = grounds.associate { it.id to it.countyId }
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

        // Home/road match counts per user, per (county, sport) -- the same
        // basis county_home_match/county_away_match achievements are tiered
        // on in AchievementsService, computed here globally across every
        // user instead of one at a time.
        val matchById = matchTeams.associateBy { it.id }
        val homeCountsByUser = mutableMapOf<TierKey, Int>()
        val roadCountsByUser = mutableMapOf<TierKey, Int>()
        for (a in attendance) {
            val match = matchById[a.matchId] ?: continue
            val groundId = match.groundId ?: continue
            val groundCountyId = groundToCounty[groundId] ?: continue
            val participatingTeamIds = listOfNotNull(match.homeCountyTeamId, match.awayCountyTeamId)
            for (teamId in participatingTeamIds) {
                val teamCountyId = teamToCounty[teamId] ?: continue
                val sportCode = teamToSport[teamId] ?: continue
                val key = TierKey(a.userId, teamCountyId, sportCode)
                if (teamCountyId == groundCountyId) {
                    homeCountsByUser[key] = (homeCountsByUser[key] ?: 0) + 1
                } else {
                    roadCountsByUser[key] = (roadCountsByUser[key] ?: 0) + 1
                }
            }
        }

        // Tally each user's unlocked county_home_match/county_away_match
        // achievements into bronze/silver/gold buckets.
        val defById = achievementDefs.associateBy { it.id }
        val tierCountsByUser = mutableMapOf<String, MutableMap<AchievementTier, Int>>()
        for (ua in userAchievements) {
            val def = defById[ua.achievementId] ?: continue
            if (def.ruleType != "county_home_match" && def.ruleType != "county_away_match") continue
            val countyId = def.ruleParams.countyId ?: continue
            val sportCode = def.ruleParams.sportCode ?: continue
            val key = TierKey(ua.userId, countyId, sportCode)
            val count = if (def.ruleType == "county_home_match") homeCountsByUser[key] ?: 0 else roadCountsByUser[key] ?: 0
            val tier = AchievementTier.forHomeMatchCount(count)
            if (tier == AchievementTier.STANDARD) continue
            val userTiers = tierCountsByUser.getOrPut(ua.userId) { mutableMapOf() }
            userTiers[tier] = (userTiers[tier] ?: 0) + 1
        }

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
                tierCounts = tierCountsByUser[uid].orEmpty(),
                supportedCountyId = profile.supportedCountyId,
            )
        }

        return Result(entries, supportedCountyId, supportedCountyName, friendIds)
    }
}
