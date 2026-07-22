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
            .order("played_at", ascending: false)
            .execute()
            .value
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

        let countyNameById = Dictionary(uniqueKeysWithValues: counties.map { ($0.id, $0.name) })
        let teamById = Dictionary(uniqueKeysWithValues: teams.map { ($0.id, $0) })
        let groundNameById = Dictionary(uniqueKeysWithValues: grounds.map { ($0.id, $0.name) })

        var attendanceCountByMatch: [UUID: Int] = [:]
        for a in attendance { attendanceCountByMatch[a.matchId, default: 0] += 1 }

        func teamName(_ teamId: UUID?) -> String {
            guard let teamId, let team = teamById[teamId], let name = countyNameById[team.countyId] else {
                return "TBC"
            }
            return name
        }

        return matches.map { match in
            MatchSummary(
                id: match.id,
                competition: match.competition,
                playedAt: match.playedAt,
                homeScore: match.homeScore,
                awayScore: match.awayScore,
                homeName: teamName(match.homeCountyTeamId),
                awayName: teamName(match.awayCountyTeamId),
                groundName: match.groundId.flatMap { groundNameById[$0] },
                attendeeCount: attendanceCountByMatch[match.id] ?? 0
            )
        }
    }
}
