import Foundation

struct UserPersonalMatch: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let homeTeam: String
    let awayTeam: String
    let competition: String?
    let round: String?
    let venue: String?
    let playedAt: Date
    let homeScore: String?
    let awayScore: String?
    let createdAt: Date?

    var hasScore: Bool { homeScore != nil && awayScore != nil }
    var isPast: Bool { playedAt < Date() }
}

struct UserPersonalMatchInsert: Encodable {
    let userId: UUID
    let homeTeam: String
    let awayTeam: String
    let competition: String?
    let round: String?
    let venue: String?
    let playedAt: Date
    let homeScore: String?
    let awayScore: String?
}
