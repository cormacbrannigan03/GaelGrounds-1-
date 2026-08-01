import Foundation

struct Competition: Codable, Identifiable, Hashable {
    let id: UUID
    let code: String
    let name: String
    let sportCode: SportCode
    let competitionType: CompetitionType
    let tier: Int
    let province: Province?
    let createdAt: Date?
}
