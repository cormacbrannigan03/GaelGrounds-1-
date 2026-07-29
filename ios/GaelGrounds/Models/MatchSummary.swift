import Foundation

/// A `Match` row with its team/ground names already resolved — the shape
/// every match-listing view in the app actually renders. `status` (set
/// server-side, not guessed on-device) drives all badge/copy logic; there's
/// no "live" concept since this app doesn't track in-play scores.
struct MatchSummary: Identifiable, Hashable {
    let id: UUID
    let competition: String?
    let season: Int?
    let round: String?
    /// Nil when the fixture/result exists but no exact date is confirmed yet.
    let matchDate: Date?
    let throwInTime: String?
    let homeScore: String?
    let awayScore: String?
    let winner: MatchWinner?
    let status: MatchStatus
    let homeName: String
    let awayName: String
    /// Nil for club fixtures (no colours tracked for clubs) or if either
    /// county is missing colour data.
    let homeColours: CountyColours?
    let awayColours: CountyColours?
    let groundName: String?
    let province: Province?
    let attendeeCount: Int

    var hasScore: Bool { homeScore != nil && awayScore != nil }
    var isUpcoming: Bool { status == .scheduled }
    var isPast: Bool { status == .completed }
}

struct GroundSummary: Identifiable, Hashable {
    let id: UUID
    let name: String
    let countyName: String
    let capacity: Int?
    let visited: Bool
}
