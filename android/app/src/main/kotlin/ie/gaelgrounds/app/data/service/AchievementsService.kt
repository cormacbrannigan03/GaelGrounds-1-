package ie.gaelgrounds.app.data.service

import ie.gaelgrounds.app.data.Supa
import ie.gaelgrounds.app.data.model.AchievementDefinition
import ie.gaelgrounds.app.data.model.AchievementEvaluation
import ie.gaelgrounds.app.data.model.AchievementProgress
import ie.gaelgrounds.app.data.model.AchievementTier
import ie.gaelgrounds.app.data.model.AchievementUnlock
import ie.gaelgrounds.app.data.model.County
import ie.gaelgrounds.app.data.model.CountyTeam
import ie.gaelgrounds.app.data.model.Ground
import ie.gaelgrounds.app.data.model.HomeAchievementKey
import ie.gaelgrounds.app.data.model.Match
import ie.gaelgrounds.app.data.model.Province
import ie.gaelgrounds.app.data.model.UserAchievement
import ie.gaelgrounds.app.data.model.UserAchievementInsert
import ie.gaelgrounds.app.data.model.UserMatchAttendance
import ie.gaelgrounds.app.data.model.UserVisit
import io.github.jan.supabase.postgrest.from
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import java.util.UUID

/**
 * Evaluates achievement_definitions.rule_type against the signed-in user's
 * current stats and inserts any newly-earned rows into user_achievements.
 * Safe to call after every check-in -- RLS still enforces user_id =
 * auth.uid() on the insert, and this only ever adds achievements the user
 * doesn't have yet. Mirrors
 * ios/GaelGrounds/Services/AchievementsService.swift.
 */
object AchievementsService {

    suspend fun evaluate(userId: String, checkedInMatchId: String? = null): AchievementEvaluation {
        return try {
            coroutineScope {
                val definitionsDeferred = async {
                    Supa.client.from("achievement_definitions").select().decodeList<AchievementDefinition>()
                }
                val unlockedDeferred = async {
                    Supa.client.from("user_achievements").select {
                        filter { eq("user_id", userId) }
                    }.decodeList<UserAchievement>()
                }
                val visitsDeferred = async {
                    Supa.client.from("user_visits").select {
                        filter { eq("user_id", userId) }
                    }.decodeList<UserVisit>()
                }
                val attendanceDeferred = async {
                    Supa.client.from("user_match_attendance").select {
                        filter { eq("user_id", userId) }
                    }.decodeList<UserMatchAttendance>()
                }
                // Full grounds/counties tables, not just the user's own
                // visited subset -- needed as the denominator for the
                // county/province/country "visit every ground" achievements.
                val allGroundsDeferred = async { Supa.client.from("grounds").select().decodeList<Ground>() }
                val allCountiesDeferred = async { Supa.client.from("counties").select().decodeList<County>() }

                val defs = definitionsDeferred.await()
                val unlockedIds = unlockedDeferred.await().map { it.achievementId }.toSet()
                val visitRows = visitsDeferred.await()
                val attendanceRows = attendanceDeferred.await()
                val matchCount = attendanceRows.size
                val allGrounds = allGroundsDeferred.await()
                val allCounties = allCountiesDeferred.await()

                val visitedGroundIds = visitRows.map { it.groundId }.toSet()
                val groundCount = visitedGroundIds.size

                val groundById = allGrounds.associateBy { it.id }
                val provinceByCountyId = allCounties.associate { it.id to it.province }
                val provinces = visitedGroundIds.mapNotNull { groundById[it]?.countyId }
                    .mapNotNull { provinceByCountyId[it] }.toSet()

                val groundsByCounty = allGrounds.groupBy { it.countyId }
                val groundsByProvince = mutableMapOf<Province, MutableList<Ground>>()
                for (g in allGrounds) {
                    val province = provinceByCountyId[g.countyId] ?: continue
                    groundsByProvince.getOrPut(province) { mutableListOf() }.add(g)
                }

                // County achievements only count when the county is both the
                // designated home team and the venue belongs to that county.
                // This excludes neutral championship venues even if the
                // county happens to be listed first.
                val homeCounts = homeMatchCounts(attendanceRows)
                // "Road Traveller" -- the inverse: any match a county's team
                // plays (home or away side of the fixture) at a ground that
                // isn't their own county's, which deliberately includes
                // neutral championship venues as away games.
                val roadCounts = roadMatchCounts(attendanceRows)

                var eligibleHomeKey: HomeAchievementKey? = null
                if (checkedInMatchId != null) {
                    val checkedInMatch = Supa.client.from("matches").select {
                        filter { eq("id", checkedInMatchId) }
                        single()
                    }.decodeSingle<Match>()

                    val homeTeamId = checkedInMatch.homeCountyTeamId
                    val groundId = checkedInMatch.groundId
                    if (homeTeamId != null && groundId != null) {
                        val homeTeamDeferred = async {
                            Supa.client.from("county_teams").select {
                                filter { eq("id", homeTeamId) }
                                single()
                            }.decodeSingle<CountyTeam>()
                        }
                        val groundDeferred = async {
                            Supa.client.from("grounds").select {
                                filter { eq("id", groundId) }
                                single()
                            }.decodeSingle<Ground>()
                        }
                        val homeTeam = homeTeamDeferred.await()
                        val ground = groundDeferred.await()
                        if (homeTeam.countyId == ground.countyId) {
                            eligibleHomeKey = HomeAchievementKey(homeTeam.countyId, homeTeam.sportCode)
                        }
                    }
                }

                val newlyUnlocked = mutableListOf<UserAchievementInsert>()
                val unlocks = mutableListOf<AchievementUnlock>()

                for (def in defs) {
                    if (unlockedIds.contains(def.id)) continue
                    val earned = when (def.ruleType) {
                        "ground_visit_count" -> groundCount >= (def.ruleParams.count ?: 1)
                        "match_attendance_count" -> matchCount >= (def.ruleParams.count ?: 1)
                        "all_provinces_visited" -> provinces.size >= 4
                        "county_home_match" -> {
                            val countyId = def.ruleParams.countyId
                            val sportCode = def.ruleParams.sportCode
                            if (countyId != null && sportCode != null) {
                                (homeCounts[HomeAchievementKey(countyId, sportCode)] ?: 0) >= 1
                            } else false
                        }
                        "county_away_match" -> {
                            val countyId = def.ruleParams.countyId
                            val sportCode = def.ruleParams.sportCode
                            if (countyId != null && sportCode != null) {
                                (roadCounts[HomeAchievementKey(countyId, sportCode)] ?: 0) >= 1
                            } else false
                        }
                        "county_grounds_complete" -> {
                            val countyId = def.ruleParams.countyId
                            val countyGrounds = countyId?.let { groundsByCounty[it] }
                            !countyGrounds.isNullOrEmpty() && countyGrounds.all { visitedGroundIds.contains(it.id) }
                        }
                        "province_grounds_complete" -> {
                            val province = def.ruleParams.province
                            val provinceGrounds = province?.let { groundsByProvince[it] }
                            !provinceGrounds.isNullOrEmpty() && provinceGrounds.all { visitedGroundIds.contains(it.id) }
                        }
                        "country_grounds_complete" -> allGrounds.isNotEmpty() && allGrounds.all { visitedGroundIds.contains(it.id) }
                        else -> false
                    }

                    if (earned) {
                        newlyUnlocked.add(UserAchievementInsert(achievementId = def.id, userId = userId))
                        unlocks.add(
                            AchievementUnlock(
                                id = def.id,
                                title = def.title,
                                description = def.description,
                                icon = def.icon,
                                tier = if (def.ruleType == "county_home_match" || def.ruleType == "county_away_match") AchievementTier.STANDARD else null,
                            )
                        )
                    }
                }

                if (newlyUnlocked.isNotEmpty()) {
                    Supa.client.from("user_achievements").insert(newlyUnlocked)
                }

                var progress: AchievementProgress? = null
                val key = eligibleHomeKey
                if (key != null) {
                    val definition = defs.firstOrNull {
                        it.ruleType == "county_home_match" &&
                            it.ruleParams.countyId == key.countyId &&
                            it.ruleParams.sportCode == key.sportCode
                    }
                    if (definition != null) {
                        val count = homeCounts[key] ?: 0
                        val tier = AchievementTier.forHomeMatchCount(count)

                        if (count == 10 || count == 25 || count == 50) {
                            unlocks.add(
                                AchievementUnlock(
                                    id = UUID.randomUUID().toString(),
                                    title = "${definition.title} — ${tier.label}",
                                    description = "Attend $count verified home games.",
                                    icon = definition.icon,
                                    tier = tier,
                                )
                            )
                        }

                        progress = AchievementProgress(
                            title = definition.title,
                            message = progressMessage(count),
                            icon = definition.icon,
                            tier = tier,
                            homeGameCount = count,
                        )
                    }
                }

                AchievementEvaluation(unlocks = unlocks, progress = progress)
            }
        } catch (e: Exception) {
            AchievementEvaluation(unlocks = emptyList(), progress = null)
        }
    }

    suspend fun homeMatchCounts(userId: String): Map<HomeAchievementKey, Int> {
        val attendance = Supa.client.from("user_match_attendance").select {
            filter { eq("user_id", userId) }
        }.decodeList<UserMatchAttendance>()
        return homeMatchCounts(attendance)
    }

    suspend fun roadMatchCounts(userId: String): Map<HomeAchievementKey, Int> {
        val attendance = Supa.client.from("user_match_attendance").select {
            filter { eq("user_id", userId) }
        }.decodeList<UserMatchAttendance>()
        return roadMatchCounts(attendance)
    }

    private suspend fun homeMatchCounts(attendance: List<UserMatchAttendance>): Map<HomeAchievementKey, Int> {
        val matchIds = attendance.map { it.matchId }.distinct()
        if (matchIds.isEmpty()) return emptyMap()

        val matches = Supa.client.from("matches").select {
            filter { isIn("id", matchIds) }
        }.decodeList<Match>()
        val homeTeamIds = matches.mapNotNull { it.homeCountyTeamId }.distinct()
        val groundIds = matches.mapNotNull { it.groundId }.distinct()
        if (homeTeamIds.isEmpty() || groundIds.isEmpty()) return emptyMap()

        return coroutineScope {
            val teamsDeferred = async {
                Supa.client.from("county_teams").select {
                    filter { isIn("id", homeTeamIds) }
                }.decodeList<CountyTeam>()
            }
            val groundsDeferred = async {
                Supa.client.from("grounds").select {
                    filter { isIn("id", groundIds) }
                }.decodeList<Ground>()
            }
            val teamById = teamsDeferred.await().associateBy { it.id }
            val groundById = groundsDeferred.await().associateBy { it.id }

            val counts = mutableMapOf<HomeAchievementKey, Int>()
            for (match in matches) {
                val teamId = match.homeCountyTeamId ?: continue
                val groundId = match.groundId ?: continue
                val team = teamById[teamId] ?: continue
                val ground = groundById[groundId] ?: continue
                if (team.countyId != ground.countyId) continue
                val key = HomeAchievementKey(team.countyId, team.sportCode)
                counts[key] = (counts[key] ?: 0) + 1
            }
            counts
        }
    }

    /**
     * "Road Traveller" counts: for each attended match, every participating
     * team (home or away side of the fixture) whose own county doesn't
     * match the ground's county gets a road-game credit -- this naturally
     * includes neutral championship venues as away games for both sides,
     * not just fixtures played at the true opposing county's ground.
     */
    private suspend fun roadMatchCounts(attendance: List<UserMatchAttendance>): Map<HomeAchievementKey, Int> {
        val matchIds = attendance.map { it.matchId }.distinct()
        if (matchIds.isEmpty()) return emptyMap()

        val matches = Supa.client.from("matches").select {
            filter { isIn("id", matchIds) }
        }.decodeList<Match>()
        val teamIds = (matches.mapNotNull { it.homeCountyTeamId } + matches.mapNotNull { it.awayCountyTeamId }).distinct()
        val groundIds = matches.mapNotNull { it.groundId }.distinct()
        if (teamIds.isEmpty() || groundIds.isEmpty()) return emptyMap()

        return coroutineScope {
            val teamsDeferred = async {
                Supa.client.from("county_teams").select {
                    filter { isIn("id", teamIds) }
                }.decodeList<CountyTeam>()
            }
            val groundsDeferred = async {
                Supa.client.from("grounds").select {
                    filter { isIn("id", groundIds) }
                }.decodeList<Ground>()
            }
            val teamById = teamsDeferred.await().associateBy { it.id }
            val groundById = groundsDeferred.await().associateBy { it.id }

            val counts = mutableMapOf<HomeAchievementKey, Int>()
            for (match in matches) {
                val groundId = match.groundId ?: continue
                val ground = groundById[groundId] ?: continue
                val participatingTeamIds = listOfNotNull(match.homeCountyTeamId, match.awayCountyTeamId)
                for (teamId in participatingTeamIds) {
                    val team = teamById[teamId] ?: continue
                    if (team.countyId == ground.countyId) continue
                    val key = HomeAchievementKey(team.countyId, team.sportCode)
                    counts[key] = (counts[key] ?: 0) + 1
                }
            }
            counts
        }
    }

    fun progressMessage(count: Int, kind: String = "home"): String {
        val next: Pair<Int, String>? = when {
            count < 10 -> 10 to "Bronze"
            count < 25 -> 25 to "Silver"
            count < 50 -> 50 to "Gold"
            else -> null
        }

        if (next == null) {
            return "Outstanding — you've earned Gold level with $count $kind games."
        }
        val remaining = next.first - count
        val noun = if (remaining == 1) "game" else "games"
        return "Good work — you're only $remaining $noun away from earning ${next.second} level."
    }
}
