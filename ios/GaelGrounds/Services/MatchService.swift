import Foundation

/// Resolves raw `matches` rows into display-ready `MatchSummary`s by joining
/// county_teams → counties for the team names and grounds for the venue,
/// plus a live count of check-ins per match. Centralised here since three
/// different screens (Dashboard, Matches, MatchDetail) all need it.
enum MatchService {
    // MARK: - Reference data

    /// counties/county_teams/grounds are small, slow-changing tables (a few
    /// hundred rows total) reused by every screen's `resolveSummaries` call.
    /// Cached in-process for the app's lifetime instead of re-fetched on
    /// every match list load.
    private static var cachedReferenceData: (counties: [County], teams: [CountyTeam], grounds: [Ground])?

    private static func referenceData() async throws -> (counties: [County], teams: [CountyTeam], grounds: [Ground]) {
        if let cachedReferenceData { return cachedReferenceData }

        async let countiesTask: [County] = Supa.client.from("counties").select().execute().value
        async let teamsTask: [CountyTeam] = Supa.client.from("county_teams").select().execute().value
        async let groundsTask: [Ground] = Supa.client.from("grounds").select().execute().value
        let data = (counties: try await countiesTask, teams: try await teamsTask, grounds: try await groundsTask)
        cachedReferenceData = data
        return data
    }

    // MARK: - Match queries

    /// Most recent matches first (upcoming fixtures sort ahead of everything
    /// since their dates are in the future), bounded so this stays fast as
    /// the historical archive grows -- this app has ~8,000 seeded results,
    /// and fetching all of them on every tab visit is what made the Matches
    /// screen slow to load. Use `search(_:)` to reach further back.
    static func fetchRecent(limit: Int = 150) async throws -> [Match] {
        try await Supa.client
            .from("matches")
            .select()
            .order("match_date", ascending: false, nullsFirst: false)
            .limit(limit)
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

    /// Server-side search across the *full* historical archive (not just
    /// the `fetchRecent` window) by competition text, season year, team
    /// name, or ground name -- team/ground name matching resolves against
    /// the cached reference data first, since `matches` only stores team
    /// and ground IDs.
    static func search(_ query: String, limit: Int = 200) async throws -> [Match] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return try await fetchRecent() }

        // Strip characters that are structurally significant in PostgREST's
        // `or=(...)` filter syntax so a stray comma/paren can't malform the
        // query -- ordinary punctuation like hyphens/apostrophes is fine.
        let term = trimmed.filter { !",()*".contains($0) }
        guard !term.isEmpty else { return try await fetchRecent() }

        let (counties, teams, grounds) = try await referenceData()
        let matchingCountyIds = Set(counties.filter { $0.name.localizedCaseInsensitiveContains(term) }.map(\.id))
        let matchingTeamIds = teams.filter { matchingCountyIds.contains($0.countyId) }.map(\.id)
        let matchingGroundIds = grounds.filter { $0.name.localizedCaseInsensitiveContains(term) }.map(\.id)

        var orClauses = ["competition.ilike.*\(term)*"]
        if let year = Int(term) {
            orClauses.append("season.eq.\(year)")
        }
        if !matchingTeamIds.isEmpty {
            let idList = matchingTeamIds.map(\.uuidString).joined(separator: ",")
            orClauses.append("home_county_team_id.in.(\(idList))")
            orClauses.append("away_county_team_id.in.(\(idList))")
        }
        if !matchingGroundIds.isEmpty {
            let idList = matchingGroundIds.map(\.uuidString).joined(separator: ",")
            orClauses.append("ground_id.in.(\(idList))")
        }

        return try await Supa.client
            .from("matches")
            .select()
            .or(orClauses.joined(separator: ","))
            .order("match_date", ascending: false, nullsFirst: false)
            .limit(limit)
            .execute()
            .value
    }

    // MARK: - Summary resolution

    static func resolveSummaries(_ matches: [Match]) async throws -> [MatchSummary] {
        guard !matches.isEmpty else { return [] }

        let (counties, teams, grounds) = try await referenceData()
        let matchIds = matches.map(\.id)

        let attendance: [UserMatchAttendance] = try await Supa.client
            .from("user_match_attendance").select().in("match_id", values: matchIds).execute().value

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
