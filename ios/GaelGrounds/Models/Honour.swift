import Foundation

struct Honour: Codable, Identifiable, Hashable {
    let id: UUID
    let teamType: TeamType
    let countyTeamId: UUID?
    let clubId: UUID?
    let honourType: HonourType
    let competitionName: String
    let year: Int
}
