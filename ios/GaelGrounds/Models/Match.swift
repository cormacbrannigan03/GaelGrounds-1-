import Foundation

struct Match: Codable, Identifiable, Hashable {
    let id: UUID
    let matchType: MatchType
    let homeCountyTeamId: UUID?
    let awayCountyTeamId: UUID?
    let homeClubId: UUID?
    let awayClubId: UUID?
    let groundId: UUID?
    let competition: String?
    let round: String?
    let playedAt: Date?
    let homeScore: String?
    let awayScore: String?
    let createdAt: Date?

    var hasScore: Bool {
        homeScore != nil && awayScore != nil
    }

    /// A match counts as "live" if it kicked off in the last ~2.5 hours and hasn't been scored yet.
    var isLive: Bool {
        guard !hasScore, let playedAt else { return false }
        let elapsed = Date().timeIntervalSince(playedAt)
        return elapsed >= 0 && elapsed <= 2.5 * 60 * 60
    }

    var isUpcoming: Bool {
        guard !hasScore, let playedAt else { return false }
        return playedAt > Date()
    }

    /// True once the fixture is in the past (whether or not a score was recorded) —
    /// used to switch check-in copy to "log that you were there" language.
    var isPast: Bool {
        guard let playedAt else { return hasScore }
        return hasScore || (!isLive && playedAt < Date())
    }
}
