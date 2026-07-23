import Foundation

/// A `Match` row with its team/ground names already resolved — the shape
/// every match-listing view in the app actually renders.
struct MatchSummary: Identifiable, Hashable {
    let id: UUID
    let competition: String?
    let playedAt: Date
    let homeScore: String?
    let awayScore: String?
    let homeName: String
    let awayName: String
    let groundId: UUID?
    let groundName: String?
    let attendeeCount: Int

    var hasScore: Bool { homeScore != nil && awayScore != nil }

    var isLive: Bool {
        guard !hasScore else { return false }
        let elapsed = Date().timeIntervalSince(playedAt)
        return elapsed >= 0 && elapsed <= 2.5 * 60 * 60
    }

    var isUpcoming: Bool {
        guard !hasScore else { return false }
        return playedAt > Date()
    }

    var isPast: Bool {
        hasScore || (!isLive && playedAt < Date())
    }
}

struct GroundSummary: Identifiable, Hashable {
    let id: UUID
    let name: String
    let countyName: String
    let capacity: Int?
    let visited: Bool
    let latitude: Double
    let longitude: Double
}
