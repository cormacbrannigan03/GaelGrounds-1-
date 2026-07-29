import Foundation

/// Resolves raw `matches` rows into display-ready `MatchSummary`s by joining
/// county_teams → counties for the team names and grounds for the venue,
/// plus a live count of check-ins per match. Centralised here since three
/// different screens (Dashboard, Matches, MatchDetail) all need it.
enum MatchService {
    static func fetchAll() async throws -> [Match] {
        try await Supa.client
            .from("matches")
            .select()
            .order("match_date", ascending: false, nullsFirst: false)
            .execute()
            .value
    }

    /// The next handful of upcoming fixtures — status is set server-side by
    /// the sync pipeline, so this is a plain query, not a time-window guess.
    static func fetchUpcoming(limit: Int = 6) async throws -> [Match] {
        try await Supa.client
            .from("matches")
            .select()
            .eq("status", value: "scheduled")
            .order("match_date", ascending: true, nullsFirst: false)
            .limit(limit)
            .execute()
            .value
    }

    static func resolveSummaries(_ matches: [Match]) async throws -> [MatchSummary] {
        guard !matches.isEmpty else { return [] }

        let teamIds = Array(Set(matches.compactMap { $0.homeCountyTeamId } + matches.compactMap { $0.awayCountyTeamId }))
        let groundIds = Array(Set(matches.compactMap(\.groundId)))
        let matchIds = matches.map(\.id)

        async let teamsTask: [CountyTeam] = teamIds.isEmpty ? [] : Supa.client
            .from("county_teams").select().in("id", values: teamIds).execute().value
        async let groundsTask: [Ground] = groundIds.isEmpty ? [] : Supa.client
            .from("grounds").select().in("id", values: groundIds).execute().value
        async let attendanceTask: [UserMatchAttendance] = Supa.client
            .from("user_match_attendance").select().in("match_id", values: matchIds).execute().value

        let teams = try await teamsTask
        let grounds = try await groundsTask
        let attendance = try await attendanceTask

        let countyIds = Array(Set(teams.map(\.countyId)))
        let counties: [County] = countyIds.isEmpty ? [] : try await Supa.client
            .from("counties").select().in("id", values: countyIds).execute().value

        let countyById = Dictionary(uniqueKeysWithValues: counties.map { ($0.id, $0) })
        let teamById = Dictionary(uniqueKeysWithValues: teams.map { ($0.id, $0) })
        let groundNameById = Dictionary(uniqueKeysWithValues: grounds.map { ($0.id, $0.name) })

        var attendanceCountByMatch: [UUID: Int] = [:]
        for a in attendance { attendanceCountByMatch[a.matchId, default: 0] += 1 }

        func county(_ teamId: UUID?) -> County? {
            guard let teamId, let team = teamById[teamId] else { return nil }
            return countyById[team.countyId]
        }
        func teamName(_ teamId: UUID?) -> String {
            county(teamId)?.name ?? "TBC"
        }

        return matches.map { match in
            MatchSummary(
                id: match.id,
                competition: match.competition,
                season: match.season,
                round: match.round,
                matchDate: match.matchDate,
                throwInTime: match.throwInTime,
                homeScore: match.homeScore,
                awayScore: match.awayScore,
                winner: match.winner,
                status: match.status,
                homeName: teamName(match.homeCountyTeamId),
                awayName: teamName(match.awayCountyTeamId),
                homeColours: county(match.homeCountyTeamId)?.colours,
                awayColours: county(match.awayCountyTeamId)?.colours,
                groundName: match.groundId.flatMap { groundNameById[$0] },
                province: match.province,
                attendeeCount: attendanceCountByMatch[match.id] ?? 0
            )
        }
    }
}
