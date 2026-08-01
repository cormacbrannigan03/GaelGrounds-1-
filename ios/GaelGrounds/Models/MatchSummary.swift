import Foundation

/// A `Match` row with its team/ground names already resolved — the shape
/// every match-listing view in the app actually renders.
struct MatchSummary: Identifiable, Hashable {
    let id: UUID
    let competition: String?
    let playedAt: Date?
    let homeScore: String?
    let awayScore: String?
    let homeName: String
    let awayName: String
    let sportCode: SportCode
    let groundId: UUID?
    let groundName: String?
    let round: String?
    let attendeeCount: Int

    var hasScore: Bool { homeScore != nil && awayScore != nil }

    var isLive: Bool {
        guard !hasScore, let playedAt else { return false }
        let elapsed = Date().timeIntervalSince(playedAt)
        return elapsed >= 0 && elapsed <= 2.5 * 60 * 60
    }

    var isUpcoming: Bool {
        guard !hasScore, let playedAt else { return false }
        return playedAt > Date()
    }

    var isPast: Bool {
        guard let playedAt else { return true }
        return hasScore || (!isLive && playedAt < Date())
    }

    var isFinal: Bool {
        let text = "\(competition ?? "") \(round ?? "")".lowercased()
        return text.contains("final")
    }

    // Returns the winning team name, or nil if no score or a draw.
    // Parses GAA format "goals-points" where a goal = 3 points.
    var winnerName: String? {
        guard hasScore,
              let homeStr = homeScore,
              let awayStr = awayScore else { return nil }
        func parse(_ s: String) -> Int {
            let p = s.split(separator: "-")
            guard p.count == 2,
                  let g = Int(p[0].trimmingCharacters(in: .whitespaces)),
                  let pts = Int(p[1].trimmingCharacters(in: .whitespaces)) else { return 0 }
            return g * 3 + pts
        }
        let home = parse(homeStr)
        let away = parse(awayStr)
        if home > away { return homeName }
        if away > home { return awayName }
        return nil
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
    let isPrimary: Bool
}
