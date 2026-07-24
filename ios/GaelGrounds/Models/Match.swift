import Foundation

/// This app does not track live in-play scores. A row is either an
/// upcoming fixture (status .scheduled/.postponed/.cancelled, no score) or
/// a completed result (status .completed, final score + winner). `status`
/// and `winner` are set server-side by the sync-matches ingestion pipeline
/// (see supabase/functions/sync-matches), not computed on-device.
struct Match: Codable, Identifiable, Hashable {
    let id: UUID
    let matchType: MatchType
    let competitionId: UUID?
    /// Free-text fallback for the competition name — set for every row, even
    /// ones not yet linked to a `competitions` row via competitionId.
    let competition: String?
    let season: Int?
    /// e.g. "Final", "Semi-Final", "Round 3", "Division 1 Final".
    let round: String?
    let homeCountyTeamId: UUID?
    let awayCountyTeamId: UUID?
    let homeClubId: UUID?
    let awayClubId: UUID?
    let groundId: UUID?
    let province: Province?
    /// Nil when a result/fixture is confirmed to exist but no exact date has
    /// been verified yet — deliberately not backfilled with a guess.
    let matchDate: Date?
    /// Raw 'HH:MM:SS' from Postgres `time`, nil if not yet confirmed.
    let throwInTime: String?
    /// Convenience combined instant for sorting/display; nil whenever matchDate is nil.
    let playedAt: Date?
    let status: MatchStatus
    let homeScore: String?
    let awayScore: String?
    let winner: MatchWinner?
    let createdAt: Date?

    var hasScore: Bool { homeScore != nil && awayScore != nil }
    var isUpcoming: Bool { status == .scheduled }
    var isPast: Bool { status == .completed }
}
