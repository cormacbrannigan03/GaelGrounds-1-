import Foundation
import Supabase

/// Resolves raw `matches` rows into display-ready `MatchSummary`s by joining
/// county_teams → counties for the team names and grounds for the venue,
/// plus a live count of check-ins per match. Centralised here since three
/// different screens (Dashboard, Matches, MatchDetail) all need it.
enum MatchService {
    private static let pageSize = 500
    private static let lookupBatchSize = 100

    static func fetchAll() async throws -> [Match] {
        var allMatches: [Match] = []
        var from = 0

        while true {
            let page: [Match] = try await Supa.client
                .from("matches")
                .select()
                .order("played_at", ascending: false)
                .range(from: from, to: from + pageSize - 1)
                .execute()
                .value

            allMatches.append(contentsOf: page)

            guard page.count == pageSize else { break }
            from += pageSize
        }

        return allMatches
    }

    static func fetchUpcomingAndLive(sinceHoursAgo: Double = 2.5) async throws -> [Match] {
        let cutoff = Date().addingTimeInterval(-sinceHoursAgo * 60 * 60)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return try await Supa.client
            .from("matches")
            .select()
            .gte("played_at", value: formatter.string(from: cutoff))
            .order("played_at", ascending: true)
            .limit(6)
            .execute()
            .value
    }

    /// All matches scheduled for today (device-local calendar day) that have
    /// a ground attached — used by ProximityCheckInService to find matches
    /// near the user's current location.
    static func fetchTodaysMatches() async throws -> [Match] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return [] }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        let matches: [Match] = try await Supa.client
            .from("matches")
            .select()
            .gte("played_at", value: formatter.string(from: startOfDay))
            .lt("played_at", value: formatter.string(from: endOfDay))
            .execute()
            .value
        return matches.filter { $0.groundId != nil }
    }

    /// Which of the given matches this user has already checked in to.
    static func attendedMatchIds(userId: UUID, matchIds: [UUID]) async throws -> Set<UUID> {
        guard !matchIds.isEmpty else { return [] }
        let rows: [UserMatchAttendance] = try await Supa.client
            .from("user_match_attendance")
            .select()
            .eq("user_id", value: userId)
            .in("match_id", values: matchIds)
            .execute()
            .value
        return Set(rows.map(\.matchId))
    }

    /// Records a check-in and evaluates achievements -- the one place this
    /// happens, shared by the manual check-in button (CheckInPanel) and the
    /// proximity prompt (ProximityCheckInService).
    static func checkIn(matchId: UUID, userId: UUID) async throws -> AchievementEvaluation {
        try await Supa.client
            .from("user_match_attendance")
            .insert(UserMatchAttendanceInsert(matchId: matchId, userId: userId))
            .execute()
        return await AchievementsService.evaluate(userId: userId, checkedInMatchId: matchId)
    }

    static func fetchMatches(forTeamId teamId: UUID, limit: Int = 20) async throws -> [Match] {
        async let homeGames: [Match] = Supa.client
            .from("matches").select()
            .eq("home_county_team_id", value: teamId)
            .order("played_at", ascending: false).limit(limit).execute().value
        async let awayGames: [Match] = Supa.client
            .from("matches").select()
            .eq("away_county_team_id", value: teamId)
            .order("played_at", ascending: false).limit(limit).execute().value
        let all = try await homeGames + awayGames
        return all.sorted { ($0.playedAt ?? .distantPast) > ($1.playedAt ?? .distantPast) }
    }

    static func resolveSummaries(_ matches: [Match]) async throws -> [MatchSummary] {
        guard !matches.isEmpty else { return [] }

        let teamIds = Array(Set(matches.compactMap { $0.homeCountyTeamId } + matches.compactMap { $0.awayCountyTeamId }))
        let groundIds = Array(Set(matches.compactMap(\.groundId)))
        let matchIds = matches.map(\.id)

        // Fire all four lookups concurrently — counties no longer wait behind teamsTask.
        async let teamsTask: [CountyTeam] = fetchCountyTeams(ids: teamIds)
        async let groundsTask: [Ground] = fetchGrounds(ids: groundIds)
        async let attendanceTask: [UserMatchAttendance] = fetchAttendance(matchIds: matchIds)
        async let countiesTask: [County] = Supa.client.from("counties").select().execute().value

        // Attendance is supplementary social data. A signed-out user is not
        // permitted to read it, but that must never prevent public fixtures
        // and results from rendering.
        let (teams, grounds, counties) = try await (teamsTask, groundsTask, countiesTask)
        let attendance = (try? await attendanceTask) ?? []

        let countyNameById = Dictionary(uniqueKeysWithValues: counties.map { ($0.id, $0.name) })
        let teamById = Dictionary(uniqueKeysWithValues: teams.map { ($0.id, $0) })
        let groundNameById = Dictionary(uniqueKeysWithValues: grounds.map { ($0.id, $0.name) })

        var attendanceCountByMatch: [UUID: Int] = [:]
        for a in attendance { attendanceCountByMatch[a.matchId, default: 0] += 1 }

        return matches.compactMap { match -> MatchSummary? in
            guard
                let homeTeamId = match.homeCountyTeamId,
                let awayTeamId = match.awayCountyTeamId,
                let homeTeam = teamById[homeTeamId],
                let awayTeam = teamById[awayTeamId],
                homeTeam.sportCode == awayTeam.sportCode,
                let home = countyNameById[homeTeam.countyId],
                let away = countyNameById[awayTeam.countyId]
            else {
                return nil
            }
            return MatchSummary(
                id: match.id,
                competition: match.competition,
                playedAt: match.playedAt,
                homeScore: match.homeScore,
                awayScore: match.awayScore,
                homeName: home,
                awayName: away,
                sportCode: homeTeam.sportCode,
                groundId: match.groundId,
                groundName: match.groundId.flatMap { groundNameById[$0] },
                round: match.round,
                attendeeCount: attendanceCountByMatch[match.id] ?? 0
            )
        }
    }

    private static func fetchCountyTeams(ids: [UUID]) async throws -> [CountyTeam] {
        guard !ids.isEmpty else { return [] }
        return try await withThrowingTaskGroup(of: [CountyTeam].self) { group in
            for batch in ids.chunked(into: lookupBatchSize) {
                group.addTask {
                    try await Supa.client
                        .from("county_teams")
                        .select()
                        .in("id", values: batch)
                        .in("sport_code", values: ["gaelic_football", "hurling"])
                        .execute()
                        .value
                }
            }
            var all: [CountyTeam] = []
            for try await page in group { all.append(contentsOf: page) }
            return all
        }
    }

    static func fetchGrounds(ids: [UUID]) async throws -> [Ground] {
        guard !ids.isEmpty else { return [] }
        return try await withThrowingTaskGroup(of: [Ground].self) { group in
            for batch in ids.chunked(into: lookupBatchSize) {
                group.addTask {
                    try await Supa.client
                        .from("grounds")
                        .select()
                        .in("id", values: batch)
                        .execute()
                        .value
                }
            }
            var all: [Ground] = []
            for try await page in group { all.append(contentsOf: page) }
            return all
        }
    }

    private static func fetchAttendance(matchIds: [UUID]) async throws -> [UserMatchAttendance] {
        guard !matchIds.isEmpty else { return [] }
        guard Supa.client.auth.currentSession != nil else { return [] }
        return try await withThrowingTaskGroup(of: [UserMatchAttendance].self) { group in
            for batch in matchIds.chunked(into: lookupBatchSize) {
                group.addTask {
                    try await Supa.client
                        .from("user_match_attendance")
                        .select()
                        .in("match_id", values: batch)
                        .execute()
                        .value
                }
            }
            var all: [UserMatchAttendance] = []
            for try await page in group { all.append(contentsOf: page) }
            return all
        }
    }

    // MARK: - Personal matches

    static func fetchPersonalMatches(userId: UUID) async throws -> [UserPersonalMatch] {
        try await Supa.client
            .from("user_personal_matches")
            .select()
            .eq("user_id", value: userId)
            .order("played_at", ascending: false)
            .execute()
            .value
    }

    static func insertPersonalMatch(_ match: UserPersonalMatchInsert) async throws {
        try await Supa.client
            .from("user_personal_matches")
            .insert(match)
            .execute()
    }

    static func deletePersonalMatch(_ id: UUID) async throws {
        try await Supa.client
            .from("user_personal_matches")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Free-tier limits

    private static let freeMatchLimit = 10
    static let freeHistoryCutoff = ISO8601DateFormatter().date(from: "2019-01-01T00:00:00Z")!

    /// Combined count of official check-ins + personal matches for one
    /// user, via the `total_match_count` Postgres function — the same
    /// count the free-tier RLS policies enforce server-side
    /// (supabase/migrations/20260801023511_free_tier_match_limits.sql).
    static func matchCount(userId: UUID) async throws -> Int {
        struct Params: Encodable { let pUserId: UUID }
        return try await Supa.client
            .rpc("total_match_count", params: Params(pUserId: userId))
            .execute()
            .value
    }

    /// Client-side mirror of the RLS free-tier check, so the UI can show a
    /// paywall proactively instead of only after a failed insert. The RLS
    /// policies remain the real enforcement regardless of what this returns.
    static func canLogAnotherMatch(userId: UUID, isPremium: Bool) async -> Bool {
        guard !isPremium else { return true }
        let count = (try? await matchCount(userId: userId)) ?? freeMatchLimit
        return count < freeMatchLimit
    }

    static func isDateAllowedForFreeTier(_ date: Date) -> Bool {
        date >= freeHistoryCutoff
    }

    // MARK: - Match reports

    static func submitReport(_ report: MatchReportInsert) async throws {
        try await Supa.client
            .from("match_reports")
            .insert(report)
            .execute()
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
