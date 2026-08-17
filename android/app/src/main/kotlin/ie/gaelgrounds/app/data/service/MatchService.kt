package ie.gaelgrounds.app.data.service

import ie.gaelgrounds.app.data.Supa
import ie.gaelgrounds.app.data.model.AchievementEvaluation
import ie.gaelgrounds.app.data.model.County
import ie.gaelgrounds.app.data.model.CountyTeam
import ie.gaelgrounds.app.data.model.Ground
import ie.gaelgrounds.app.data.model.Match
import ie.gaelgrounds.app.data.model.MatchReportInsert
import ie.gaelgrounds.app.data.model.MatchSummary
import ie.gaelgrounds.app.data.model.UserMatchAttendance
import ie.gaelgrounds.app.data.model.UserMatchAttendanceInsert
import ie.gaelgrounds.app.data.model.UserPersonalMatch
import ie.gaelgrounds.app.data.model.UserPersonalMatchInsert
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.query.Order
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import java.time.Instant

/**
 * Resolves raw `matches` rows into display-ready `MatchSummary`s by joining
 * county_teams -> counties for the team names and grounds for the venue,
 * plus a live count of check-ins per match. Mirrors
 * ios/GaelGrounds/Services/MatchService.swift.
 */
object MatchService {
    private const val PAGE_SIZE = 500L
    private const val LOOKUP_BATCH_SIZE = 100

    suspend fun fetchAll(): List<Match> {
        val all = mutableListOf<Match>()
        var from = 0L
        while (true) {
            val page = Supa.client.from("matches").select {
                order("played_at", Order.DESCENDING)
                range(from, from + PAGE_SIZE - 1)
            }.decodeList<Match>()
            all.addAll(page)
            if (page.size.toLong() != PAGE_SIZE) break
            from += PAGE_SIZE
        }
        return all
    }

    suspend fun fetchUpcomingAndLive(sinceHoursAgo: Double = 2.5): List<Match> {
        val cutoff = Instant.now().minusSeconds((sinceHoursAgo * 60 * 60).toLong())
        return Supa.client.from("matches").select {
            filter { gte("played_at", cutoff.toString()) }
            order("played_at", Order.ASCENDING)
            limit(6)
        }.decodeList()
    }

    /** Which of the given matches this user has already checked in to. */
    suspend fun attendedMatchIds(userId: String, matchIds: List<String>): Set<String> {
        if (matchIds.isEmpty()) return emptySet()
        val rows = Supa.client.from("user_match_attendance").select {
            filter {
                eq("user_id", userId)
                isIn("match_id", matchIds)
            }
        }.decodeList<UserMatchAttendance>()
        return rows.map { it.matchId }.toSet()
    }

    /**
     * Records a check-in and evaluates achievements -- the one place this
     * happens, shared by the manual check-in button and the proximity
     * prompt.
     */
    suspend fun checkIn(matchId: String, userId: String): AchievementEvaluation {
        Supa.client.from("user_match_attendance")
            .insert(UserMatchAttendanceInsert(matchId = matchId, userId = userId))
        return AchievementsService.evaluate(userId = userId, checkedInMatchId = matchId)
    }

    suspend fun resolveSummaries(matches: List<Match>): List<MatchSummary> {
        if (matches.isEmpty()) return emptyList()

        val teamIds = (matches.mapNotNull { it.homeCountyTeamId } + matches.mapNotNull { it.awayCountyTeamId }).distinct()
        val groundIds = matches.mapNotNull { it.groundId }.distinct()
        val matchIds = matches.map { it.id }

        return coroutineScope {
            val teamsDeferred = async { fetchCountyTeams(teamIds) }
            val groundsDeferred = async { fetchGrounds(groundIds) }
            val countiesDeferred = async {
                Supa.client.from("counties").select().decodeList<County>()
            }
            // Attendance is supplementary social data. A signed-out user
            // can't read it, but that must never block public fixtures and
            // results from rendering.
            val attendanceDeferred = async {
                try {
                    fetchAttendance(matchIds)
                } catch (e: Exception) {
                    emptyList()
                }
            }

            val teams = teamsDeferred.await()
            val grounds = groundsDeferred.await()
            val counties = countiesDeferred.await()
            val attendance = attendanceDeferred.await()

            val countyNameById = counties.associate { it.id to it.name }
            val teamById = teams.associateBy { it.id }
            val groundNameById = grounds.associate { it.id to it.name }

            val attendanceCountByMatch = mutableMapOf<String, Int>()
            for (a in attendance) attendanceCountByMatch[a.matchId] = (attendanceCountByMatch[a.matchId] ?: 0) + 1

            matches.mapNotNull { match ->
                val homeTeamId = match.homeCountyTeamId ?: return@mapNotNull null
                val awayTeamId = match.awayCountyTeamId ?: return@mapNotNull null
                val homeTeam = teamById[homeTeamId] ?: return@mapNotNull null
                val awayTeam = teamById[awayTeamId] ?: return@mapNotNull null
                if (homeTeam.sportCode != awayTeam.sportCode) return@mapNotNull null
                val home = countyNameById[homeTeam.countyId] ?: return@mapNotNull null
                val away = countyNameById[awayTeam.countyId] ?: return@mapNotNull null

                MatchSummary(
                    id = match.id,
                    competition = match.competition,
                    playedAt = match.playedAt,
                    homeScore = match.homeScore,
                    awayScore = match.awayScore,
                    homeName = home,
                    awayName = away,
                    sportCode = homeTeam.sportCode,
                    groundId = match.groundId,
                    groundName = match.groundId?.let { groundNameById[it] },
                    round = match.round,
                    attendeeCount = attendanceCountByMatch[match.id] ?: 0,
                )
            }
        }
    }

    private suspend fun fetchCountyTeams(ids: List<String>): List<CountyTeam> {
        if (ids.isEmpty()) return emptyList()
        return coroutineScope {
            ids.chunked(LOOKUP_BATCH_SIZE).map { batch ->
                async {
                    Supa.client.from("county_teams").select {
                        filter {
                            isIn("id", batch)
                            isIn("sport_code", listOf("gaelic_football", "hurling"))
                        }
                    }.decodeList<CountyTeam>()
                }
            }.awaitAll().flatten()
        }
    }

    suspend fun fetchGrounds(ids: List<String>): List<Ground> {
        if (ids.isEmpty()) return emptyList()
        return coroutineScope {
            ids.chunked(LOOKUP_BATCH_SIZE).map { batch ->
                async {
                    Supa.client.from("grounds").select {
                        filter { isIn("id", batch) }
                    }.decodeList<Ground>()
                }
            }.awaitAll().flatten()
        }
    }

    private suspend fun fetchAttendance(matchIds: List<String>): List<UserMatchAttendance> {
        if (matchIds.isEmpty()) return emptyList()
        if (Supa.client.auth.currentSessionOrNull() == null) return emptyList()
        return coroutineScope {
            matchIds.chunked(LOOKUP_BATCH_SIZE).map { batch ->
                async {
                    Supa.client.from("user_match_attendance").select {
                        filter { isIn("match_id", batch) }
                    }.decodeList<UserMatchAttendance>()
                }
            }.awaitAll().flatten()
        }
    }

    // MARK: - Personal matches

    suspend fun fetchPersonalMatches(userId: String): List<UserPersonalMatch> {
        return Supa.client.from("user_personal_matches").select {
            filter { eq("user_id", userId) }
            order("played_at", Order.DESCENDING)
        }.decodeList()
    }

    suspend fun insertPersonalMatch(match: UserPersonalMatchInsert) {
        Supa.client.from("user_personal_matches").insert(match)
    }

    suspend fun deletePersonalMatch(id: String) {
        Supa.client.from("user_personal_matches").delete {
            filter { eq("id", id) }
        }
    }

    // MARK: - Match reports

    suspend fun submitReport(report: MatchReportInsert) {
        Supa.client.from("match_reports").insert(report)
    }
}
